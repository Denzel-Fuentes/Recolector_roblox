--!strict
--[[
	PatioHandler
	Bucle que decide quien esta dentro del patio (Services/Patio) cada 0.2 s.
	Separado de Botin para que la pose de brazos y la primera persona no
	dependan del estado de los montones. Y guarda la vista elegida en el
	patio (CamaraEvent: "primera" | "tercera"; la aplica el cliente).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Red = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Patio = require(Servicios:WaitForChild("Patio"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))

Red.evento("CamaraEvent").OnServerEvent:Connect(function(jugador, vista)
	local perfil = Perfiles.obtener(jugador)
	if perfil and (vista == "primera" or vista == "tercera") and perfil.camara ~= vista then
		perfil.camara = vista
		Perfiles.marcarSucio(jugador)
	end
end)

local acumulado = 0
RunService.Heartbeat:Connect(function(dt)
	acumulado += dt
	if acumulado >= 0.2 then
		acumulado = 0
		Patio.actualizar()
	end
end)
