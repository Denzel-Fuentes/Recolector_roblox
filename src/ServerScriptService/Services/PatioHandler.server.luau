--!strict
--[[
	PatioHandler
	Bucle que decide quien esta dentro del patio (Services/Patio) cada 0.2 s.
	Separado de Botin para que la pose de brazos y la primera persona no
	dependan del estado de los montones.
]]

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Servicios = ServerScriptService:WaitForChild("Services")
local Patio = require(Servicios:WaitForChild("Patio"))

local acumulado = 0
RunService.Heartbeat:Connect(function(dt)
	acumulado += dt
	if acumulado >= 0.2 then
		acumulado = 0
		Patio.actualizar()
	end
end)
