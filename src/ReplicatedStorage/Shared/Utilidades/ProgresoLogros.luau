--!strict
--[[
	ProgresoLogros
	Calcula el progreso (actual, umbral) de cada logro a partir de un PERFIL
	(tabla pura, sin Instances). Es compartido: el servidor lo usa para
	desbloquear (Services/Logros) y el cliente para pintar las barras del panel,
	asi que ambos ven exactamente el mismo numero.

	Tipos de condicion (Config/DefinicionesLogros):
	  estadistica   perfil.estadisticas[clave] >= umbral
	  set           las 10 mascotas del set con al menos una copia
	  rey           tiene al Rey Reciclon
	  perfectas     N mascotas distintas con una copia Perfecta
	  mejoraNivel   alguna mejora con nivel >= umbral
	  todasMejoras  las 7 al maximo
	  coleccion     N figurinas / cintas / trajes (solo los 3 gratis)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local DefinicionesLogros = require(Config:WaitForChild("DefinicionesLogros"))
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))

local ProgresoLogros = {}

local function tieneMascota(perfil: any, id: string): boolean
	for _, copia in perfil.mascotas do
		if copia.id == id then
			return true
		end
	end
	return false
end

local function mascotasDelSet(perfil: any, setId: string): number
	local n = 0
	for _, def in DefinicionesMascotas.porSet(setId) do
		if tieneMascota(perfil, def.id) then
			n += 1
		end
	end
	return n
end

local function perfectasDistintas(perfil: any): number
	local vistas = {}
	for _, copia in perfil.mascotas do
		if copia.estado >= DefinicionesMascotas.ESTADO_MAX and copia.id ~= DefinicionesMascotas.ID_REY then
			vistas[copia.id] = true
		end
	end
	local n = 0
	for _ in vistas do
		n += 1
	end
	return n
end

local function cuenta(mapa: { [string]: boolean }?, soloIds: { [string]: boolean }?): number
	local n = 0
	if mapa then
		for id in mapa do
			if not soloIds or soloIds[id] then
				n += 1
			end
		end
	end
	return n
end

local TRAJES_GRATIS: { [string]: boolean } = {}
for _, t in DefinicionesColeccionables.trajesGratis() do
	TRAJES_GRATIS[t.id] = true
end

-- Devuelve (actual, umbral). Completado cuando actual >= umbral.
function ProgresoLogros.progreso(perfil: any, logro: DefinicionesLogros.Logro): (number, number)
	local tipo = logro.tipo
	if tipo == "estadistica" then
		local stats = perfil.estadisticas or {}
		return stats[logro.clave or ""] or 0, logro.umbral or 1
	elseif tipo == "set" then
		return mascotasDelSet(perfil, logro.clave or ""), #DefinicionesMascotas.porSet(logro.clave or "")
	elseif tipo == "rey" then
		return if tieneMascota(perfil, DefinicionesMascotas.ID_REY) then 1 else 0, 1
	elseif tipo == "perfectas" then
		return perfectasDistintas(perfil), logro.umbral or 1
	elseif tipo == "mejoraNivel" then
		local mayor = 0
		for _, def in DefinicionesMejoras.LISTA do
			mayor = math.max(mayor, (perfil.mejoras or {})[def.id] or 0)
		end
		return mayor, logro.umbral or 1
	elseif tipo == "todasMejoras" then
		local n = 0
		for _, def in DefinicionesMejoras.LISTA do
			if ((perfil.mejoras or {})[def.id] or 0) >= GameConfig.NIVEL_MAX_MEJORA then
				n += 1
			end
		end
		return n, #DefinicionesMejoras.LISTA
	elseif tipo == "coleccion" then
		local clave = logro.clave
		if clave == "figurinas" then
			return cuenta(perfil.figurinas), logro.umbral or 1
		elseif clave == "cintas" then
			return cuenta(perfil.cintas), logro.umbral or 1
		elseif clave == "trajes" then
			return cuenta(perfil.trajes, TRAJES_GRATIS), logro.umbral or 1
		end
	end
	return 0, 1
end

function ProgresoLogros.completado(perfil: any, logro: DefinicionesLogros.Logro): boolean
	local actual, umbral = ProgresoLogros.progreso(perfil, logro)
	return actual >= umbral
end

return ProgresoLogros
