local DataBridge = {}

local SessionManager = require(game.ServerScriptService.DataLib.SessionManager)

function DataBridge.GetSessions()
    local result = {}

    for userId, session in pairs(SessionManager._debug_getSessions()) do
        table.insert(result, {
            userId = userId,
            data = session.Data,
            delta = session._delta,
            dirty = session._dirty
        })
    end

    return result
end

function DataBridge.GetMetrics()
    return SessionManager:GetMetrics()
end

function DataBridge.ForceSave(userId)
    local s = SessionManager._debug_getSessions()[userId]
    if s then
        s:Save()
    end
end

function DataBridge.Release(userId)
    local s = SessionManager._debug_getSessions()[userId]
    if s then
        s:Release()
    end
end

return DataBridge