--!strict
--[[
	Mejoras (ModuleScript)
	Unica responsabilidad: el nivel de cada una de las 7 mejoras por jugador y
	su VALOR EFECTIVO (incluyendo los bonus de los Game Passes), y aplicar al
	personaje lo que dependa de ellas (Velocidad -> WalkSpeed).

	Los numeros base viven en Config/DefinicionesMejoras para que la tienda pinte
	lo mismo que aqui se aplica. Los pases multiplican encima:
	  PaseVelocidad  x1.25 sobre Velocidad
	  PaseIman       x1.5  sobre Iman

	Comprar cobra y sube de nivel en la misma llamada, o no hace nada.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefinicionesMejoras = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMejoras"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))

local Mejoras = {}

function Mejoras.nivel(jugador: Player, id: string): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0
	end
	return perfil.mejoras[id] or 0
end

-- Valor efectivo con pases. Es lo que usan Energia, Bolsa, Botin, etc.
function Mejoras.valor(jugador: Player, id: string): number
	local base = DefinicionesMejoras.valor(id, Mejoras.nivel(jugador, id))
	if id == "Velocidad" and Monetizacion.tienePase(jugador, "PaseVelocidad") then
		return base * 1.25
	elseif id == "Iman" and Monetizacion.tienePase(jugador, "PaseIman") then
		return base * 1.5
	end
	return base
end

function Mejoras.costeSiguiente(jugador: Player, id: string): number?
	return DefinicionesMejoras.coste(id, Mejoras.nivel(jugador, id))
end

function Mejoras.numMaximas(jugador: Player): number
	local n = 0
	for _, def in DefinicionesMejoras.LISTA do
		if Mejoras.nivel(jugador, def.id) >= DefinicionesMejoras.NIVEL_MAX then
			n += 1
		end
	end
	return n
end

function Mejoras.todasAlMaximo(jugador: Player): boolean
	return Mejoras.numMaximas(jugador) == #DefinicionesMejoras.LISTA
end

function Mejoras.nivelMasAlto(jugador: Player): number
	local mayor = 0
	for _, def in DefinicionesMejoras.LISTA do
		mayor = math.max(mayor, Mejoras.nivel(jugador, def.id))
	end
	return mayor
end

function Mejoras.aplicarVelocidad(jugador: Player)
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if humanoide then
		humanoide.WalkSpeed = Mejoras.valor(jugador, "Velocidad")
	end
end

-- Devuelve (exito, mensaje). El mensaje es una clave para Textos o un texto.
function Mejoras.comprar(jugador: Player, id: string): (boolean, string)
	local def = DefinicionesMejoras.POR_ID[id]
	local perfil = Perfiles.obtener(jugador)
	if not def or not perfil then
		return false, "mejoraDesconocida"
	end
	local nivel = perfil.mejoras[id] or 0
	local coste = DefinicionesMejoras.coste(id, nivel)
	if not coste then
		return false, "maximo"
	end
	if not Economia.gastar(jugador, coste) then
		return false, "sinDinero"
	end
	perfil.mejoras[id] = nivel + 1
	Perfiles.estadistica(jugador, "mejorasCompradas", 1)
	Perfiles.marcarSucio(jugador)
	if id == "Velocidad" then
		Mejoras.aplicarVelocidad(jugador)
	end
	return true, tostring(nivel + 1)
end

-- Velocidad al aparecer el personaje y cuando cambian los pases
local function engancharPersonaje(jugador: Player)
	jugador.CharacterAdded:Connect(function()
		task.defer(Mejoras.aplicarVelocidad, jugador)
	end)
	if jugador.Character then
		task.defer(Mejoras.aplicarVelocidad, jugador)
	end
end

Players.PlayerAdded:Connect(engancharPersonaje)
for _, jugador in Players:GetPlayers() do
	engancharPersonaje(jugador)
end

Perfiles.alCargar:Connect(function(jugador)
	Mejoras.aplicarVelocidad(jugador)
end)

Monetizacion.alCambiarPases:Connect(function(jugador)
	Mejoras.aplicarVelocidad(jugador)
end)

return Mejoras
