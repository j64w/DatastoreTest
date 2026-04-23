-- DataLib/init.lua
-- Public API. The only module users ever touch.
--
-- USAGE:
--
--   local DataLib = require(game.ServerScriptService.DataLib)
--
--   -- Async load (recommended)
--   DataLib:LoadProfile(player):andThen(function(profile)
--       profile.Data.coins += 100
--       profile.Data.inventory.pets[1] = { name = "Dragon", ... }
--   end)
--
--   -- Or await inside a task (also fine)
--   local profile = DataLib:LoadProfile(player):await()
--
--   -- Events
--   DataLib.ProfileLoaded:Connect(function(player, profile) end)
--   DataLib.ProfileReleased:Connect(function(player) end)
--   DataLib.SaveFailed:Connect(function(player, err) end)
--
--   -- Manual save → Promise
--   profile:Save():andThen(function() print("saved!") end)
--
--   -- Release → Promise (called automatically on PlayerRemoving)
--   profile:Release()

local Players       = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages       = ReplicatedStorage:WaitForChild("Packages")
local Promise        = require(Packages.Promise)
local Signal         = require(Packages.Signal)

local SessionManager = require(script.SessionManager)

-- ─────────────────────────────────────────────
--  DataLib
-- ─────────────────────────────────────────────
local DataLib = {}

-- ─────────────────────────────────────────────
--  PUBLIC SIGNALS
-- ─────────────────────────────────────────────
DataLib.ProfileLoaded   = Signal.new()   -- (player, profile)
DataLib.ProfileReleased = Signal.new()   -- (player)
DataLib.SaveFailed      = Signal.new()   -- (player, errorMessage)

-- ─────────────────────────────────────────────
--  LoadProfile(player) → Promise<profile>
--
--  Loads and returns the session for a player.
--  Resolves immediately if already cached.
--  Fires ProfileLoaded on success.
-- ─────────────────────────────────────────────
function DataLib:LoadProfile(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"),
		"[DataLib] LoadProfile expects a Player instance.")

	-- Return cached session immediately
	local existing = SessionManager.GetSession(player)
	if existing then
		return Promise.resolve(existing)
	end

	return SessionManager.LoadSession(player)
		:andThen(function(profile)
			-- Wire SaveFailed signal into the session
			local originalFlush = profile._flush
			profile._flush = function(self)
				return originalFlush(self):catch(function(err)
					DataLib.SaveFailed:Fire(player, tostring(err))
					return Promise.reject(err)
				end)
			end

			DataLib.ProfileLoaded:Fire(player, profile)
			return profile
		end)
		:catch(function(err)
			warn(("[DataLib] LoadProfile failed for %s: %s"):format(player.Name, tostring(err)))
			return Promise.reject(err)
		end)
end

-- ─────────────────────────────────────────────
--  GetProfile(player) → profile?
--
--  Synchronous. Returns cached profile or nil.
--  Use LoadProfile() if you need to wait for load.
-- ─────────────────────────────────────────────
function DataLib:GetProfile(player)
	return SessionManager.GetSession(player)
end

-- ─────────────────────────────────────────────
--  ReleaseProfile(player) → Promise
--
--  Saves and clears the session.
--  Called automatically on PlayerRemoving.
-- ─────────────────────────────────────────────
function DataLib:ReleaseProfile(player)
	local session = SessionManager.GetSession(player)
	if not session then
		return Promise.resolve()
	end

	return session:Release():andThen(function()
		DataLib.ProfileReleased:Fire(player)
	end)
end

-- ─────────────────────────────────────────────
--  Pre-warm sessions when players join so the
--  profile is ready by the time game code needs it.
-- ─────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	DataLib:LoadProfile(player):catch(function(err)
		warn(("[DataLib] Could not load profile for %s: %s"):format(player.Name, tostring(err)))
	end)
end)

-- Handle players who joined before this module loaded
for _, player in ipairs(Players:GetPlayers()) do
	DataLib:LoadProfile(player):catch(function(err)
		warn(("[DataLib] Could not load profile for %s: %s"):format(player.Name, tostring(err)))
	end)
end

return DataLib