--!strict
--[[
	DefinicionesMejoras
	Las 7 mejoras de KOTAMON, renombradas (Bag, Energy, Buzz, Capacity, Speed,
	Range, Magnet). Nivel 0 = sin comprar; 10 compras por mejora.

	Coste del siguiente nivel = costeBase * FACTOR ^ nivelActual, redondeado a
	decenas. Con FACTOR 1.6 maxear las 7 cuesta ~230k $: a calibrar en pruebas.

	El VALOR efectivo de cada mejora se calcula aqui (y solo aqui) a partir de
	GameConfig, para que la tienda muestre exactamente lo que el servidor aplica.
	Los bonus de los Game Passes (velocidad, iman) se aplican encima, en
	Services/Mejoras.
]]

local GameConfig = require(script.Parent.GameConfig)

export type Mejora = {
	id: string,
	nombre: string,
	descripcion: string,
	costeBase: number,
	unidad: string,
	original: string, -- nombre en KOTAMON, por trazabilidad con el GDD
}

local DefinicionesMejoras = {}

DefinicionesMejoras.LISTA = {
	{ id = "Mochila", nombre = "Mochila", descripcion = "Cuánto cargas por viaje", costeBase = 150, unidad = "objetos", original = "Bag" },
	{ id = "Energia", nombre = "Energía", descripcion = "Cuánto puedes excavar antes de necesitar un refresco", costeBase = 200, unidad = "energía", original = "Energy" },
	{ id = "Chispa", nombre = "Chispa", descripcion = "Cuánta energía restaura cada refresco", costeBase = 120, unidad = "energía", original = "Buzz" },
	{ id = "Almacen", nombre = "Almacén", descripcion = "Cuántas mascotas caben en tu base", costeBase = 180, unidad = "mascotas", original = "Capacity" },
	{ id = "Velocidad", nombre = "Velocidad", descripcion = "Velocidad de movimiento", costeBase = 250, unidad = "studs/s", original = "Speed" },
	{ id = "Alcance", nombre = "Alcance", descripcion = "Distancia para agarrar basura", costeBase = 160, unidad = "studs", original = "Range" },
	{ id = "Iman", nombre = "Imán", descripcion = "Radio de atracción de objetos", costeBase = 220, unidad = "studs", original = "Magnet" },
}

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
	local bruto = def.costeBase * GameConfig.FACTOR_COSTE_MEJORA ^ nivelActual
	return math.floor(bruto / 10 + 0.5) * 10
end

-- Valor efectivo SIN pases. nivel 0..10.
function DefinicionesMejoras.valor(id: string, nivel: number): number
	if id == "Mochila" then
		return GameConfig.BOLSA_BASE + GameConfig.BOLSA_POR_NIVEL * nivel
	elseif id == "Energia" then
		return GameConfig.ENERGIA_BASE + GameConfig.ENERGIA_POR_NIVEL * nivel
	elseif id == "Chispa" then
		return GameConfig.REFRESCO_BASE + GameConfig.REFRESCO_POR_NIVEL * nivel
	elseif id == "Almacen" then
		return GameConfig.ALMACEN_BASE + GameConfig.ALMACEN_POR_NIVEL * nivel
	elseif id == "Velocidad" then
		return GameConfig.VELOCIDAD_BASE + GameConfig.VELOCIDAD_POR_NIVEL * nivel
	elseif id == "Alcance" then
		return GameConfig.ALCANCE_BASE + GameConfig.ALCANCE_POR_NIVEL * nivel
	elseif id == "Iman" then
		return GameConfig.IMAN_POR_NIVEL * nivel
	end
	return 0
end

function DefinicionesMejoras.textoValor(id: string, nivel: number): string
	local def = DefinicionesMejoras.POR_ID[id]
	local v = DefinicionesMejoras.valor(id, nivel)
	if not def then
		return tostring(v)
	end
	if id == "Velocidad" then
		return string.format("%.1f %s", v, def.unidad)
	end
	return string.format("%d %s", v, def.unidad)
end

-- Coste total de llevar las 7 de 0 a 10 (dato de calibracion para CONTEXTO.md)
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
