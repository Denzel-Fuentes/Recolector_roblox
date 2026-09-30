--!strict
--[[
	Rebirths (ModuleScript)
	Unica responsabilidad: renacer. Con las 4 mejoras al maximo y el dinero
	del requisito en mano, el jugador vuelve a empezar mas fuerte: el dinero
	y las mejoras vuelven a 0 y a cambio sube su multiplicador de dinero y se
	abren zonas y sets (Config/DefinicionesRebirths, GameConfig.CUADRANTES,
	DefinicionesMascotas.SETS).

	Se conserva todo lo demas: mascotas, sus niveles y sus fragmentos,
	cuadrantes abiertos (salen de perfil.rebirths), records, logros,
	cosmeticos y pases. Quien necesita enterarse (la bolsa que cambia de
	capacidad, las insignias) escucha alRenacer; el grupo de colision del
	personaje lo cambia Colisiones al ver el perfil nuevo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefinicionesRebirths = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesRebirths"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))

local Rebirths = {}

-- (jugador, rebirths que tiene ahora)
Rebirths.alRenacer = Senal.nueva() :: Senal.Senal<Player, number>

function Rebirths.cuantos(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	return if perfil then perfil.rebirths else 0
end

-- Multiplicador de dinero del jugador (x1 sin rebirths)
function Rebirths.multiplicador(jugador: Player): number
	return DefinicionesRebirths.multiplicador(Rebirths.cuantos(jugador))
end

-- (se puede, motivo): "mejoras" si falta alguna al maximo, "dinero" si no
-- llega al requisito del siguiente
function Rebirths.puede(jugador: Player): (boolean, string)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false, "sinPerfil"
	end
	if not Mejoras.todasAlMaximo(jugador) then
		return false, "mejoras"
	end
	if perfil.dinero < DefinicionesRebirths.rebirth(perfil.rebirths + 1).requisito then
		return false, "dinero"
	end
	return true, ""
end

-- Devuelve (ok, motivo o numero del rebirth hecho)
function Rebirths.renacer(jugador: Player): (boolean, string)
	local puede, motivo = Rebirths.puede(jugador)
	local perfil = Perfiles.obtener(jugador)
	if not puede or not perfil then
		return false, motivo
	end
	perfil.dinero = 0
	for id in perfil.mejoras do
		perfil.mejoras[id] = 0
	end
	perfil.rebirths += 1
	Perfiles.estadisticaMaxima(jugador, "rebirthMaximo", perfil.rebirths)
	Perfiles.marcarSucio(jugador)
	Mejoras.aplicarVelocidad(jugador)
	Rebirths.alRenacer:Fire(jugador, perfil.rebirths)
	return true, tostring(perfil.rebirths)
end

return Rebirths
