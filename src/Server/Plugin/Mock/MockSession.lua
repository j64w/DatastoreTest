local Session = {}
Session.__index = Session

function Session.new(userId)
    local self = setmetatable({}, Session)

    self.UserId = userId
    self._dirty = false

    self.Data = {
        coins = math.random(0, 1000),
        level = math.random(1, 10),
        inventory = {}
    }

    return self
end

function Session:Save()
    self._dirty = false
end

function Session:Release()
end

return Session