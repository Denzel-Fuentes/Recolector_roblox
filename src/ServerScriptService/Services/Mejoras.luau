--!strict
--[[
	Mejoras (ModuleScript)
	Unica responsabilidad: el nivel de cada mejora por jugador y
	su VALOR EFECTIVO, y aplicar al personaje lo que dependa de ellas
	(Velocidad -> WalkSpeed).

	Los numeros base viven en Config/DefinicionesMejoras para que la tienda pinte
	lo mismo que aqui se aplica. La v2 no vende velocidad ni iman (servirian
	para quitarle piezas a los demas en el patio compartido); el unico pase que
	toca una mejora sera Bolsa XL (lote 8).

	Comprar cobra y sube de nivel en la misma llamada, o no hace nada. Todas
	vuelven a 0 al renacer (Rebirths); `todasAlMaximo` es su requisito.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefinicionesMejoras = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMejoras"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))

local Mejoras = {}

-- (jugador, id, nivelNuevo) tras cada compra; la escucha el Tutorial
Mejoras.alComprar = Senal.nueva() :: Senal.Senal<Player, string, number>

function Mejoras.nivel(jugador: Player, id: string): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0
	end
	return perfil.mejoras[id] or 0
end

-- Valor efectivo. Es lo que usan Bolsa, ObjetosPatio, Lanzamiento...
function Mejoras.valor(jugador: Player, id: string): number
	return DefinicionesMejoras.valor(id, Mejoras.nivel(jugador, id))
end

function Mejoras.costeSiguiente(jugador: Player, id: string): number?
	return DefinicionesMejoras.coste(id, Mejoras.nivel(jugador, id))
end

function Mejoras.todasAlMaximo(jugador: Player): boolean
	for _, def in DefinicionesMejoras.LISTA do
		if Mejoras.nivel(jugador, def.id) < DefinicionesMejoras.NIVEL_MAX then
			return false
		end
	end
	return true
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
	Mejoras.alComprar:Fire(jugador, id, nivel + 1)
	return true, tostring(nivel + 1)
end

-- Velocidad al aparecer el personaje
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

return Mejoras
