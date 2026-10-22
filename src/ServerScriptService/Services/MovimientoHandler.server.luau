--!strict
--[[
	MovimientoHandler
	Cablea Services/Movimiento: una muestra cada Movimiento.INTERVALO s y
	olvidar a quien sale. Sin logica: los umbrales y su porque estan en
	Movimiento.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Movimiento = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Movimiento"))

local acumulado = 0
RunService.Heartbeat:Connect(function(dt)
	acumulado += dt
	if acumulado >= Movimiento.INTERVALO then
		acumulado = 0
		Movimiento.muestrear()
	end
end)

Players.PlayerRemoving:Connect(Movimiento.olvidar)
