--!strict
--[[
	Coleccionables (ModuleScript)
	Unica responsabilidad: figurinas y cintas de cada jugador (pospuestas en
	la v2, ver DefinicionesColeccionables).

	Figurinas fijas: el objeto del patio es visible para todos; cada jugador la
	recoge UNA vez (queda en su perfil) y su cliente la oculta localmente.

	Hasta el 5 oct tambien guardaba los trajes y vestia al personaje con el
	puesto; se quitaron los trajes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefinicionesColeccionables = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesColeccionables"))
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))

local Coleccionables = {}

-- (jugador, tipo, id) tipo = "figurina" | "cinta"
Coleccionables.alAgregar = Senal.nueva() :: Senal.Senal<Player, string, string>

local function mapa(perfil: Perfiles.Perfil, tipo: string): { [string]: boolean }
	if tipo == "figurina" then
		return perfil.figurinas
	elseif tipo == "cinta" then
		return perfil.cintas
	end
	return {}
end

function Coleccionables.tiene(jugador: Player, tipo: string, id: string): boolean
	local perfil = Perfiles.obtener(jugador)
	return perfil ~= nil and mapa(perfil, tipo)[id] == true
end

function Coleccionables.cuenta(jugador: Player, tipo: string): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0
	end
	local n = 0
	for _ in mapa(perfil, tipo) do
		n += 1
	end
	return n
end

-- Devuelve true si era nuevo
function Coleccionables.agregar(jugador: Player, tipo: string, id: string): boolean
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false
	end
	local m = mapa(perfil, tipo)
	if m[id] then
		return false
	end
	m[id] = true
	Perfiles.estadistica(jugador, tipo .. "sEncontradas", 1)
	Perfiles.marcarSucio(jugador)
	Coleccionables.alAgregar:Fire(jugador, tipo, id)
	return true
end

-- Ids que le faltan al jugador de un tipo. Para figurinas, solo las aleatorias
-- (las fijas se encuentran en el patio, no en montones).
function Coleccionables.faltantes(jugador: Player, tipo: string): { string }
	local lista = {}
	if tipo == "figurina" then
		for _, f in DefinicionesColeccionables.figurinasAleatorias() do
			if not Coleccionables.tiene(jugador, "figurina", f.id) then
				table.insert(lista, f.id)
			end
		end
	elseif tipo == "cinta" then
		for _, c in DefinicionesColeccionables.CINTAS do
			if not Coleccionables.tiene(jugador, "cinta", c.id) then
				table.insert(lista, c.id)
			end
		end
	end
	return lista
end

-- Color del whitebox de una figurina en la estanteria (para Parcelas)
function Coleccionables.colorFigurina(): Color3
	return Paleta.FIGURINA
end

return Coleccionables
