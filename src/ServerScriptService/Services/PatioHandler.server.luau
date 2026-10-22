--!strict
--[[
	PatioHandler
	Bucle que decide quien esta dentro del patio (Services/Patio) cada 0.2 s.
	Separado de Botin para que la pose de brazos y la primera persona no
	dependan del estado de los montones. Y pasa a Patio la vista elegida en
	el patio (CamaraEvent: "primera" | "tercera"; la aplica el cliente), que
	la valida y la guarda con cooldown (Patio.elegirVista).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Red = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Patio = require(Servicios:WaitForChild("Patio"))

Red.evento("CamaraEvent").OnServerEvent:Connect(function(jugador, vista)
	Patio.elegirVista(jugador, vista)
end)

local acumulado = 0
RunService.Heartbeat:Connect(function(dt)
	acumulado += dt
	if acumulado >= 0.2 then
		acumulado = 0
		Patio.actualizar()
	end
end)
