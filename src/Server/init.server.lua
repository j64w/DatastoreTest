-- Server/init.server.lua
-- Ejemplo de uso con la nueva API.

local Players = game:GetService("Players")
local DataLib = require(game.ServerScriptService.DataLib)

-- ─────────────────────────────────────────────
--  Eventos globales desacoplados
-- ─────────────────────────────────────────────
DataLib.ProfileLoaded:Connect(function(player, profile)
	print(("[Server] %s cargado — Coins: %d | Level: %d | Rebirths: %d"):format(
		player.Name,
		profile.Data.coins,
		profile.Data.level,
		profile.Data.rebirths
	))
end)

DataLib.ProfileReleased:Connect(function(player)
	print(("[Server] %s — sesión liberada."):format(player.Name))
end)

DataLib.SaveFailed:Connect(function(player, err)
	warn(("[Server] Save falló para %s: %s"):format(player.Name, err))
end)

-- ─────────────────────────────────────────────
--  Ejemplo: lógica al cargar jugador
-- ─────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	DataLib:LoadProfile(player):andThen(function(profile)
		profile.Data.coins += 10

		table.insert(profile.Data.inventory.pets, {
			name     = "Dragon",
			rarity   = "Legendary",
			level    = 1,
			equipped = false,
		})
	end):catch(function(err)
		warn(("No se pudo cargar %s: %s"):format(player.Name, err))
		player:Kick("No pudimos cargar tus datos. Por favor reintentá.")
	end)
end)