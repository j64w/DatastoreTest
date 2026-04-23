local DataStoreService = game:GetService("DataStoreService")
local MessagingService = isServer and game:GetService("MessagingService") or nil
local Players = game:GetService("Players")

local RetryEngine = require(script.Parent.RetryEngine)
local Schema = require(script.Parent.Schema)
local Utils = require(script.Parent.Utils)
local Session = require(script.Parent.Session)
local RunService = game:GetService("RunService")

local isServer = RunService:IsServer()

local store = DataStoreService:GetDataStore("DataLib_god")

local SessionManager = {}

local sessions = {}
local writeQueue = {}

local CONFIG = {
    AutoSave = 30,
    SaveCooldown = 10,
    Topic = "DataSync"
}

local function applyDelta(data, delta)
    for path, value in pairs(delta) do
        local ref = data
        local parts = string.split(path, ".")

        for i = 1, #parts - 1 do
            local k = parts[i]
            ref[k] = ref[k] or {}
            ref = ref[k]
        end

        ref[parts[#parts]] = value
    end
end

local function flush(session)
    if not session._dirty then return end
    if Utils.Now() - session._lastSaveTime < CONFIG.SaveCooldown then return end

    local delta = session._delta
    session._delta = {}

    RetryEngine.Run(function()
        return store:UpdateAsync(session.UserId, function(current)
            current = current or {}
            current.Data = current.Data or {}

            applyDelta(current.Data, delta)

            current._version = (current._version or 0) + 1
            current._lastSaveTime = Utils.Now()

            return current
        end)
    end)

    session._dirty = false
    session._lastSaveTime = Utils.Now()

	if MessagingService then
		pcall(function()
			MessagingService:PublishAsync(CONFIG.Topic, {
				userId = session.UserId,
				delta = delta
			})
		end)
	end
end

local function queue(session)
    writeQueue[session.UserId] = session
end

local function process()
    for _, session in pairs(writeQueue) do
        writeQueue[session.UserId] = nil
        task.spawn(function()
            flush(session)
        end)
    end
end

task.spawn(function()
    while true do
        task.wait(CONFIG.AutoSave)
        process()
    end
end)

if MessagingService then
    MessagingService:SubscribeAsync(CONFIG.Topic, function(msg)
        local data = msg.Data
        local session = sessions[data.userId]

        if session then
            applyDelta(session.Data, data.delta)
        end
    end)
end

function SessionManager:GetSession(player)
    local userId = player.UserId

    if sessions[userId] then return sessions[userId] end

    local data = RetryEngine.Run(function()
        return store:GetAsync(userId)
    end) or {}

    local profileData = data.Data or {}
    Schema.Reconcile(profileData)

    local session = Session.new(player, profileData)

    function session:Save()
        self._dirty = true
        queue(self)
    end

    function session:Release()
        if self._released then return end
        self._released = true
        self._dirty = true

        flush(self)
        sessions[userId] = nil
    end

    sessions[userId] = session
    return session
end

Players.PlayerRemoving:Connect(function(player)
    local s = sessions[player.UserId]
    if s then s:Release() end
end)

game:BindToClose(function()
    for _, s in pairs(sessions) do
        s._dirty = true
        queue(s)
    end

    while next(writeQueue) do
        process()
        task.wait()
    end
end)

function SessionManager._debug_getSessions()
    return sessions
end

return SessionManager