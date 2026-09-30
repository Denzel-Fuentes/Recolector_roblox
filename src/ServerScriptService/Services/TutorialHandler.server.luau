--!strict
--[[
	TutorialHandler
	Arranca el Tutorial y da la bienvenida a quien lo empieza (el texto de
	bienvenida ya no manda a hablar con Dona Chatarra: manda al patio).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Tutorial = require(Servicios:WaitForChild("Tutorial"))

local NotificacionEvent = Red.evento("NotificacionEvent")

Tutorial.iniciar()

Perfiles.alCargar:Connect(function(jugador, perfil)
	if (perfil.tutorial or 0) == 0 then
		-- El cliente puede no tener aun la UI montada
		task.delay(2, function()
			if jugador.Parent then
				NotificacionEvent:FireClient(jugador, Textos.NOTIFICACIONES.bienvenida, "exito")
			end
		end)
	end
end)
