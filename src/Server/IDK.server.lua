local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = Instance.new("RemoteFunction")
remote.Name = "DataLib_Debug"
remote.Parent = ReplicatedStorage

local SessionManager = require(script.Parent.DataLib.SessionManager)

remote.OnServerInvoke = function(player, action, payload)
    if action == "getSessions" then
        local result = {}

        for userId, session in pairs(SessionManager._debug_getSessions()) do
            result[userId] = {
                data = session.Data,
                dirty = session._dirty
            }
        end

        return result
    end

    if action == "getMetrics" then
        return SessionManager:GetMetrics()
    end

    if action == "save" then
        local s = SessionManager._debug_getSessions()[payload]
        if s then s:Save() end
    end

    if action == "release" then
        local s = SessionManager._debug_getSessions()[payload]
        if s then s:Release() end
    end
end