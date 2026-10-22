--!strict
--[[
	AjustesHandler
	Cablea AjustesEvent({ musica, efectos }) a Services/Ajustes, que valida
	(los dos booleanos), aplica el cooldown y lo guarda en el perfil. No
	responde: el cliente ve el resultado en el siguiente perfil (y su panel
	vuelve a lo que diga si se rechazo).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Red = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Red"))

local Ajustes = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Ajustes"))

Red.evento("AjustesEvent").OnServerEvent:Connect(function(jugador: Player, datos: any)
	Ajustes.aplicar(jugador, datos)
end)

Players.PlayerRemoving:Connect(function(jugador)
	Ajustes.olvidar(jugador)
end)
