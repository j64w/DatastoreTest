local Session = require(script.Parent.MockSession)

local Manager = {}

local sessions = {}

function Manager:GetSession(userId)
    if sessions[userId] then
        return sessions[userId]
    end

    local s = Session.new(userId)
    sessions[userId] = s

    return s
end

function Manager:GetAll()
    return sessions
end

function Manager:GetMetrics()
    return {
        saves = math.random(10, 50),
        fails = math.random(0, 5)
    }
end

return Manager