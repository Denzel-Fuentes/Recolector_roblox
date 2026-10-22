--!strict
--[[
	Cuadrantes
	Unica responsabilidad: responder, igual en servidor y cliente, en que
	cuadrante del patio esta un punto, de que zona es (la mezcla de
	materiales de sus montones) y si un jugador con N rebirths lo tiene
	abierto (diseno v2: los dos del fondo se abren con el Rebirth 1 y 2).

	Los datos son GameConfig.CUADRANTES (zona y rebirth por cuadrante, en
	orden de lectura desde el noroeste) y GameConfig.PATIO (los bordes): el
	rectangulo del patio partido en COLUMNAS_PATIO x FILAS_PATIO iguales, lo
	mismo que hace el constructor del mundo. Las ranuras horneadas llevan su
	cuadrante como atributo; esto sirve para lo que no lo lleva (el personaje,
	la HUD, un place anterior al mundo v2).

	Los cuadrantes ya no son de un material (decision del usuario, 29 sep):
	cada uno tiene una zona con su mezcla de materiales.
]]

local GameConfig = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("GameConfig"))

export type Cuadrante = { zona: string, rebirth: number }

local Cuadrantes = {}

-- Indice (1..6) del cuadrante bajo un punto, o nil fuera del patio
function Cuadrantes.en(pos: Vector3): number?
	local P = GameConfig.PATIO
	if pos.X < P.oeste or pos.X > P.este or pos.Z < P.norte or pos.Z > P.sur then
		return nil
	end
	local columnas, filas = GameConfig.COLUMNAS_PATIO, GameConfig.FILAS_PATIO
	local columna = math.clamp(math.floor((pos.X - P.oeste) / ((P.este - P.oeste) / columnas)) + 1, 1, columnas)
	local fila = math.clamp(math.floor((pos.Z - P.norte) / ((P.sur - P.norte) / filas)) + 1, 1, filas)
	return (fila - 1) * columnas + columna
end

function Cuadrantes.definicion(indice: number): Cuadrante?
	return GameConfig.CUADRANTES[indice]
end

-- La zona de un cuadrante ("patio" si no existe)
function Cuadrantes.zona(indice: number): string
	local def = GameConfig.CUADRANTES[indice]
	return if def then def.zona else "patio"
end

-- Un cuadrante esta abierto con tantos rebirths como pide (0 = siempre)
function Cuadrantes.abierto(indice: number, rebirths: number): boolean
	local def = GameConfig.CUADRANTES[indice]
	return def ~= nil and rebirths >= def.rebirth
end

return Cuadrantes
