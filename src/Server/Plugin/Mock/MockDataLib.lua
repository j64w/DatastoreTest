local Manager = require(script.Parent.MockSessionManager)

local Data = {}

function Data:GetProfile(player)
    return Manager:GetSession(player.UserId or player)
end

function Data:_debug_getSessions()
    return Manager:GetAll()
end

function Data:GetMetrics()
    return Manager:GetMetrics()
end

return Data