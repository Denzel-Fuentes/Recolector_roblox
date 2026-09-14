--!strict
--[[
	Energia (ModuleScript)
	Unica responsabilidad: cuanta energia tiene cada jugador ahora mismo.

	Es estado de SESION (no persiste): al entrar se empieza con la barra llena,
	como en KOTAMON tras dormir. Excavar cuesta COSTE_EXCAVAR; el refresco de la
	maquina restaura lo que diga la mejora Chispa; el maximo lo da la mejora
	Energia.

	Regeneracion pasiva lenta (1 punto cada REGEN_ENERGIA_CADA s): existe para
	que nadie quede bloqueado sin dinero para refrescos. Es deliberadamente
	lenta para que el refresco siga teniendo sentido.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))

local EnergiaEvent = Red.evento("EnergiaEvent")

local Energia = {}

local actual: { [Player]: number } = {}

function Energia.maxima(jugador: Player): number
	return Mejoras.valor(jugador, "Energia")
end

function Energia.actual(jugador: Player): number
	return actual[jugador] or 0
end

function Energia.publicar(jugador: Player)
	if jugador.Parent then
		EnergiaEvent:FireClient(jugador, Energia.actual(jugador), Energia.maxima(jugador))
	end
end

function Energia.fijar(jugador: Player, valor: number)
	actual[jugador] = math.clamp(valor, 0, Energia.maxima(jugador))
	Energia.publicar(jugador)
end

function Energia.puedeGastar(jugador: Player, cantidad: number): boolean
	return Energia.actual(jugador) >= cantidad
end

function Energia.gastar(jugador: Player, cantidad: number): boolean
	if not Energia.puedeGastar(jugador, cantidad) then
		return false
	end
	Energia.fijar(jugador, Energia.actual(jugador) - cantidad)
	return true
end

function Energia.restaurar(jugador: Player, cantidad: number): number
	local antes = Energia.actual(jugador)
	Energia.fijar(jugador, antes + cantidad)
	return Energia.actual(jugador) - antes
end

-- Un refresco: lo que diga Chispa
function Energia.refresco(jugador: Player): number
	return Energia.restaurar(jugador, Mejoras.valor(jugador, "Chispa"))
end

Perfiles.alCargar:Connect(function(jugador)
	Energia.fijar(jugador, Energia.maxima(jugador))
end)

Players.PlayerRemoving:Connect(function(jugador)
	actual[jugador] = nil
end)

task.spawn(function()
	while true do
		task.wait(GameConfig.REGEN_ENERGIA_CADA)
		for jugador, valor in actual do
			if jugador.Parent and valor < Energia.maxima(jugador) then
				Energia.fijar(jugador, valor + 1)
			end
		end
	end
end)

return Energia
