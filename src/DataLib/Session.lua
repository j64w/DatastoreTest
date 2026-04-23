-- Session.lua
-- Individual player session with state machine, Trove cleanup,
-- and dirty-tracked Data proxy.

local Packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")
local Promise  = require(Packages.Promise)
local Trove    = require(Packages.Trove)

local Utils = require(script.Parent.Utils)

-- ─────────────────────────────────────────────
--  STATES
-- ─────────────────────────────────────────────
local States = {
	LOADING  = "LOADING",   -- acquiring lock, loading data
	ACTIVE   = "ACTIVE",    -- normal operation
	SAVING   = "SAVING",    -- write in progress
	RELEASED = "RELEASED",  -- session closed
	ERROR    = "ERROR",     -- DataStore failed, in-memory only
}

local Session = {}
Session.__index = Session

-- ─────────────────────────────────────────────
--  Session.new(player, rawData)
-- ─────────────────────────────────────────────
function Session.new(player, rawData)
	local self = setmetatable({}, Session)

	self._player       = player
	self._state        = States.LOADING
	self._dirty        = false
	self._lastSaveTime = Utils.Now()
	self._trove        = Trove.new()

	-- Dirty-tracking proxy over the loaded data
	self.Data = Utils.MakeDirtyProxy(rawData, function()
		if self._state == States.ACTIVE or self._state == States.SAVING then
			self._dirty = true
		end
	end)

	self._state = States.ACTIVE
	return self
end

-- ─────────────────────────────────────────────
--  State helpers
-- ─────────────────────────────────────────────
function Session:GetState()
	return self._state
end

function Session:IsActive()
	return self._state == States.ACTIVE
end

-- ─────────────────────────────────────────────
--  Save() → Promise
--  Exposed for manual saves. SessionManager also
--  calls _flush() directly for autosave/shutdown.
-- ─────────────────────────────────────────────
function Session:Save()
	if self._state == States.RELEASED then
		return Promise.reject("Cannot save a released session")
	end
	if self._state == States.ERROR then
		return Promise.reject("Session is in error state — DataStore unavailable")
	end

	-- Delegate to the flush function injected by SessionManager
	if self._flush then
		return self:_flush()
	end
	return Promise.reject("Session not fully initialized")
end

-- ─────────────────────────────────────────────
--  Release() → Promise
--  Saves if dirty, clears lock, destroys Trove.
-- ─────────────────────────────────────────────
function Session:Release()
	if self._state == States.RELEASED then
		return Promise.resolve()
	end

	self._state = States.RELEASED

	local releasePromise
	if self._dirty and self._releaseFn then
		releasePromise = self:_releaseFn()
	else
		releasePromise = Promise.resolve()
	end

	return releasePromise:finally(function()
		self._trove:Destroy()
	end)
end

-- ─────────────────────────────────────────────
--  MarkError()
--  Called by SessionManager when DS is down.
--  Data stays in memory, saves are skipped.
-- ─────────────────────────────────────────────
function Session:MarkError()
	if self._state ~= States.RELEASED then
		self._state = States.ERROR
		warn(("[DataLib] Session for %s entered ERROR state."):format(self._player.Name))
	end
end

-- ─────────────────────────────────────────────
--  AddToTrove(item)
--  Anything added here is cleaned up on Release.
--  e.g. connections, tasks, sub-troves.
-- ─────────────────────────────────────────────
function Session:AddToTrove(item)
	return self._trove:Add(item)
end

Session.States = States
return Session