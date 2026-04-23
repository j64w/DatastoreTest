-- SessionManager.lua
-- Manages loading, caching, saving, and releasing player sessions.
-- All DataStore operations return Promises.

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local Packages     = game:GetService("ReplicatedStorage"):WaitForChild("Packages")
local Promise      = require(Packages.Promise)

local RetryEngine  = require(script.Parent.RetryEngine)
local Schema       = require(script.Parent.Schema)
local Session      = require(script.Parent.Session)
local Utils        = require(script.Parent.Utils)

local SessionManager = {}

-- ─────────────────────────────────────────────
--  CONFIG
-- ─────────────────────────────────────────────
local CONFIG = {
	DataStoreName    = "PlayerData_v1",
	LockTimeout      = 60,
	LockRetries      = 5,
	ForceLoad        = false,
	AutosaveInterval = 45,
}

local DS = DataStoreService:GetDataStore(CONFIG.DataStoreName)

-- ─────────────────────────────────────────────
--  INTERNAL STATE
-- ─────────────────────────────────────────────
local sessions   = {}  -- [userId] = Session
local writeQueue = {}  -- [userId] = true

-- ─────────────────────────────────────────────
--  PRIVATE: player key
-- ─────────────────────────────────────────────
local function playerKey(player)
	return "Player_" .. tostring(player.UserId)
end

-- ─────────────────────────────────────────────
--  PRIVATE: acquire lock → Promise<rawData>
-- ─────────────────────────────────────────────
local function acquireLock(player)
	local key    = playerKey(player)
	local loaded = nil

	local function attempt()
		return RetryEngine.Retry(function()
			DS:UpdateAsync(key, function(current)
				current = current or {}
				local lock         = current._lock
				local lastSaveTime = current._lastSaveTime or 0
				local expired      = (Utils.Now() - lastSaveTime) > CONFIG.LockTimeout

				if lock and lock ~= "" and lock ~= game.JobId and not expired then
					return nil  -- another server owns a live lock
				end

				current._lock         = game.JobId
				current._lastSaveTime = Utils.Now()
				loaded = current
				return current
			end)
		end, "AcquireLock:" .. key)
	end

	-- Try LockRetries times with exponential backoff between attempts
	local function tryAcquire(attemptsLeft)
		return attempt():andThen(function()
			if loaded then
				return loaded
			end
			-- Lock was held by another server
			if attemptsLeft <= 1 then
				if CONFIG.ForceLoad then
					warn(("[DataLib] ForceLoad — stealing session for %s"):format(key))
					loaded = nil
					return RetryEngine.Retry(function()
						DS:UpdateAsync(key, function(current)
							current = current or {}
							current._lock         = game.JobId
							current._lastSaveTime = Utils.Now()
							loaded = current
							return current
						end)
					end, "ForceLoad:" .. key):andThen(function()
						if not loaded then
							return Promise.reject("ForceLoad failed")
						end
						return loaded
					end)
				end
				return Promise.reject("Session locked by another server")
			end
			return Promise.delay(math.min(2 ^ (CONFIG.LockRetries - attemptsLeft + 1), 20))
				:andThen(function()
					return tryAcquire(attemptsLeft - 1)
				end)
		end)
	end

	return tryAcquire(CONFIG.LockRetries)
end

-- ─────────────────────────────────────────────
--  PRIVATE: flush one session → Promise
-- ─────────────────────────────────────────────
local function flushSession(session)
	if not session._dirty then
		return Promise.resolve()
	end

	local key     = playerKey(session._player)
	local plain   = Utils.StripProxy(session.Data)
	local now     = Utils.Now()

	-- Validate before writing
	local valid, validErr = Schema.Validate(plain)
	if not valid then
		warn(("[DataLib] Validation failed for %s — skipping save: %s"):format(key, tostring(validErr)))
		return Promise.reject(validErr)
	end

	session._state = Session.States.SAVING

	return RetryEngine.Retry(function()
		DS:UpdateAsync(key, function(current)
			if plain == nil then return current end
			current = current or {}
			current.data          = Utils.DeepCopy(plain)
			current._lock         = game.JobId
			current._lastSaveTime = now
			return current
		end)
	end, "Save:" .. key)
	:andThen(function()
		session._dirty        = false
		session._lastSaveTime = now
		if session._state == Session.States.SAVING then
			session._state = Session.States.ACTIVE
		end
	end)
	:catch(function(err)
		warn(("[DataLib] Save failed for %s: %s"):format(key, tostring(err)))
		if session._state == Session.States.SAVING then
			session._state = Session.States.ACTIVE
		end
		return Promise.reject(err)
	end)
end

-- ─────────────────────────────────────────────
--  PRIVATE: clear lock in DataStore
-- ─────────────────────────────────────────────
local function clearLock(player)
	local key = playerKey(player)
	return RetryEngine.Retry(function()
		DS:UpdateAsync(key, function(current)
			if current and current._lock == game.JobId then
				current._lock = ""
			end
			return current
		end)
	end, "ClearLock:" .. key)
end

-- ─────────────────────────────────────────────
--  PRIVATE: process write queue → Promise
-- ─────────────────────────────────────────────
local function processWriteQueue()
	local toFlush = writeQueue
	writeQueue = {}

	local promises = {}
	for userId in pairs(toFlush) do
		local session = sessions[userId]
		if session and session._dirty and session:IsActive() then
			table.insert(promises, flushSession(session))
		end
	end

	return Promise.all(promises)
end

-- ─────────────────────────────────────────────
--  AUTOSAVE LOOP
-- ─────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(CONFIG.AutosaveInterval)
		processWriteQueue():catch(function(err)
			warn("[DataLib] Autosave error:", err)
		end)
	end
end)

-- ─────────────────────────────────────────────
--  PUBLIC: LoadSession(player) → Promise<Session>
-- ─────────────────────────────────────────────
function SessionManager.LoadSession(player)
	local userId = player.UserId

	if sessions[userId] then
		return Promise.resolve(sessions[userId])
	end

	return acquireLock(player):andThen(function(raw)
		-- Migrate, reconcile
		local data = raw.data or {}
		Schema.Migrate(data)
		Schema.Reconcile(data)

		local session = Session.new(player, data)

		-- Inject flush function into session
		session._flush = function(self)
			writeQueue[userId] = true
			return flushSession(self)
		end

		-- Inject release function
		session._releaseFn = function(self)
			return flushSession(self):finally(function()
				clearLock(player)
				sessions[userId]   = nil
				writeQueue[userId] = nil
			end)
		end

		sessions[userId] = session
		return session
	end)
	:catch(function(err)
		warn(("[DataLib] Failed to load session for %s: %s"):format(player.Name, tostring(err)))
		return Promise.reject(err)
	end)
end

-- ─────────────────────────────────────────────
--  PUBLIC: GetSession(player) → Session?
-- ─────────────────────────────────────────────
function SessionManager.GetSession(player)
	return sessions[player.UserId]
end

-- ─────────────────────────────────────────────
--  GRACEFUL SHUTDOWN
-- ─────────────────────────────────────────────
game:BindToClose(function()
	for userId, session in pairs(sessions) do
		if session._dirty then
			writeQueue[userId] = true
		end
	end
	-- Block until all saves complete (Roblox gives ~30s)
	processWriteQueue():await()
end)

-- ─────────────────────────────────────────────
--  PLAYER REMOVING
-- ─────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	local session = SessionManager.GetSession(player)
	if session then
		session:Release():catch(function(err)
			warn(("[DataLib] Release error for %s: %s"):format(player.Name, tostring(err)))
		end)
	end
end)

return SessionManager