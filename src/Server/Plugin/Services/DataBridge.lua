local RunService = game:GetService("RunService")

local DataBridge = {}

local isPlay = RunService:IsRunning()

local Data

if isPlay then
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remote = ReplicatedStorage:WaitForChild("DataLib_Debug")

    function DataBridge.GetSessions()
        return remote:InvokeServer("getSessions")
    end

    function DataBridge.GetMetrics()
        return remote:InvokeServer("getMetrics")
    end

    function DataBridge.ForceSave(userId)
        remote:InvokeServer("save", userId)
    end

    function DataBridge.Release(userId)
        remote:InvokeServer("release", userId)
    end

else
    Data = require(script.Parent.Parent.Mock.MockDataLib)

    function DataBridge.GetSessions()
        local result = {}

        for userId, session in pairs(Data:_debug_getSessions()) do
            result[userId] = {
                data = session.Data,
                dirty = session._dirty
            }
        end

        return result
    end

    function DataBridge.GetMetrics()
        return Data:GetMetrics()
    end

    function DataBridge.ForceSave(userId)
        local s = Data:_debug_getSessions()[userId]
        if s then s:Save() end
    end

    function DataBridge.Release(userId)
        local s = Data:_debug_getSessions()[userId]
        if s then s:Release() end
    end

end

return DataBridge