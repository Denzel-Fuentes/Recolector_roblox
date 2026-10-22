--!strict
--[[
	DefinicionesMejoras
	Las 4 mejoras de la v2 (26 sep): Bolsa, Alcance, Velocidad y Brazo.
	Nivel 0 = sin comprar; 10 compras por mejora; todas vuelven a 0 al
	renacer (Rebirths).

	Por que 4 y no 7: Energia y Chispa se fueron con la energia, Almacen con
	las copias de mascota, y el Iman se fue con las mascotas (3 oct). Brazo es nueva: sube el alcance maximo del
	lanzamiento, y con el el techo del bonus por distancia.

	Coste del siguiente nivel = costeBase * FACTOR ^ nivelActual, redondeado a
	la unidad: con FACTOR 1.6 el nivel 10 de Bolsa cuesta $10.308 y llevar las
	4 al maximo, $118.030 (los numeros del diseno).

	Valor = base + porNivel * nivel. Se calcula aqui (y solo aqui); los pases
	que suman (Bolsa XL) van encima, en Services/Mejoras. La tienda no ensena
	valores: el nivel es una barra de 10 cuadros (decision del usuario, 3 oct:
	"no menciones studs").
]]

local GameConfig = require(script.Parent.GameConfig)

export type Mejora = {
	id: string,
	nombre: string,
	descripcion: string,
	costeBase: number,
	base: number, -- valor a nivel 0
	porNivel: number,
}

local DefinicionesMejoras = {}

DefinicionesMejoras.LISTA = {
	{ id = "Bolsa", nombre = "Bolsa", descripcion = "Cabe más basura en la bolsa", costeBase = 150, base = 10, porNivel = 3 },
	{ id = "Alcance", nombre = "Alcance", descripcion = "Recoge desde más lejos", costeBase = 120, base = 6, porNivel = 1 },
	{ id = "Velocidad", nombre = "Velocidad", descripcion = "Corre más rápido", costeBase = 200, base = 16, porNivel = 1.2 },
	{ id = "Brazo", nombre = "Brazo", descripcion = "Lanza la bolsa más lejos", costeBase = 180, base = 25, porNivel = 4.5 },
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
