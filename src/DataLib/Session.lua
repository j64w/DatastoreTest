local Utils = require(script.Parent.Utils)

local Session = {}
Session.__index = Session

function Session.new(player, data)
    local self = setmetatable({}, Session)

    self.Player = player
    self.UserId = player.UserId

    self._dirty = false
    self._released = false
    self._lastSaveTime = 0

    self._baseData = Utils.DeepCopy(data or {})
    self._delta = {}

    local function markDirty(path, value)
        self._dirty = true
        self._delta[path] = value
    end

    self.Data = Utils.CreateDeltaProxy(data or {}, markDirty)

    return self
end

function Session:Save()
    if self._released then return end
    self._dirty = true
end

function Session:Release()
    if self._released then return end
    self._released = true
    self._dirty = true
end

return Session