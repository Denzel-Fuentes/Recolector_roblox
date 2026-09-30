--!strict
--[[
	DefinicionesMejoras
	Las 4 mejoras de la v2 (26 sep): Bolsa, Alcance, Velocidad y Brazo.
	Nivel 0 = sin comprar; 10 compras por mejora; todas vuelven a 0 al
	renacer (Rebirths).

	Por que 4 y no 7: Energia y Chispa se fueron con la energia, Almacen con
	las copias de mascota, y el Iman paso a las mascotas Raras y Epicas (solo
	atrae su material). Brazo es nueva: sube el alcance maximo del
	lanzamiento, y con el el techo del bonus por distancia.

	Coste del siguiente nivel = costeBase * FACTOR ^ nivelActual, redondeado a
	la unidad: con FACTOR 1.6 el nivel 10 de Bolsa cuesta $10.308 y llevar las
	4 al maximo, $118.030 (los numeros del diseno).

	Valor = base + porNivel * nivel. Se calcula aqui (y solo aqui) para que la
	tienda pinte exactamente lo que aplica el servidor; los pases que suman
	(Bolsa XL) van encima, en Services/Mejoras.
]]

local GameConfig = require(script.Parent.GameConfig)

export type Mejora = {
	id: string,
	nombre: string,
	descripcion: string,
	costeBase: number,
	base: number, -- valor a nivel 0
	porNivel: number,
	unidad: string,
	decimales: number,
}

local DefinicionesMejoras = {}

DefinicionesMejoras.LISTA = {
	{ id = "Bolsa", nombre = "Bolsa", descripcion = "Huecos de la bolsa", costeBase = 150, base = 10, porNivel = 3, unidad = "huecos", decimales = 0 },
	{ id = "Alcance", nombre = "Alcance", descripcion = "Distancia para recoger", costeBase = 120, base = 6, porNivel = 1, unidad = "studs", decimales = 0 },
	{ id = "Velocidad", nombre = "Velocidad", descripcion = "Velocidad al andar", costeBase = 200, base = 16, porNivel = 1.2, unidad = "studs/s", decimales = 1 },
	{ id = "Brazo", nombre = "Brazo", descripcion = "Distancia máxima de lanzamiento", costeBase = 180, base = 25, porNivel = 4.5, unidad = "studs", decimales = 1 },
} :: { Mejora }

DefinicionesMejoras.POR_ID = {} :: { [string]: Mejora }
for _, m in DefinicionesMejoras.LISTA do
	DefinicionesMejoras.POR_ID[m.id] = m
end

DefinicionesMejoras.NIVEL_MAX = GameConfig.NIVEL_MAX_MEJORA

function DefinicionesMejoras.coste(id: string, nivelActual: number): number?
	local def = DefinicionesMejoras.POR_ID[id]
	if not def or nivelActual >= DefinicionesMejoras.NIVEL_MAX then
		return nil
	end
	return math.floor(def.costeBase * GameConfig.FACTOR_COSTE_MEJORA ^ nivelActual + 0.5)
end

-- Valor efectivo SIN pases. nivel 0..10.
function DefinicionesMejoras.valor(id: string, nivel: number): number
	local def = DefinicionesMejoras.POR_ID[id]
	if not def then
		return 0
	end
	return def.base + def.porNivel * nivel
end

function DefinicionesMejoras.textoValor(id: string, nivel: number): string
	local def = DefinicionesMejoras.POR_ID[id]
	local v = DefinicionesMejoras.valor(id, nivel)
	if not def then
		return tostring(v)
	end
	-- Sin ",0": 25 studs, 29,5 studs
	local texto = if def.decimales > 0 and v % 1 ~= 0
		then (string.format("%." .. def.decimales .. "f", v):gsub("%.", ","))
		else tostring(math.floor(v + 0.5))
	return texto .. " " .. def.unidad
end

-- Coste total de llevar las 4 de 0 a 10 (dato de calibracion: $118.030)
function DefinicionesMejoras.costeTotal(): number
	local total = 0
	for _, m in DefinicionesMejoras.LISTA do
		for nivel = 0, DefinicionesMejoras.NIVEL_MAX - 1 do
			total += DefinicionesMejoras.coste(m.id, nivel) or 0
		end
	end
	return total
end

return DefinicionesMejoras
