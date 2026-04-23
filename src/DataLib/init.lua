local SessionManager = require(script.SessionManager)

local DataLib = {}

function DataLib:GetProfile(player)
    if not player or not player.UserId then
        error("Invalid player")
    end
    return SessionManager:GetSession(player)
end

return DataLib