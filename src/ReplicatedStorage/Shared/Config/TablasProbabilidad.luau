--!strict
--[[
	TablasProbabilidad (OddsTables en el GDD)
	UNICA fuente de probabilidades del juego.

	La usa el servidor para otorgar (GeneradorBotin). Vive en
	ReplicatedStorage para que cualquier numero que se ensene al jugador sea
	el mismo que se usa de verdad. Nada aleatorio se vende con Robux (las
	mascotas, lo unico que se ensenaba, se quitaron el 3 oct).

	Cada tabla es una lista ORDENADA de { id, peso } cuyos pesos suman 100. El
	orden importa: es el orden en que se muestran en la UI. verificar() falla al
	cargar si alguna no suma 100, para que un error de edicion nunca llegue a
	produccion silenciosamente.
]]

export type Entrada = { id: string, peso: number }
export type Tabla = { Entrada }

local TablasProbabilidad = {}

-- === Contenido de un monton: que es cada pieza ===
-- Una tirada por pieza (diseno v2): 5 % billetes y 1 % tesoros. El grande
-- trae ademas un tesoro garantizado (GameConfig.TAMANOS_MONTON). El 2,5 %
-- de fragmentos de mascota volvio a la basura al quitar las mascotas (3 oct).
TablasProbabilidad.TIPO_PIEZA = {
	{ id = "basura", peso = 94 },
	{ id = "billete", peso = 5 },
	{ id = "tesoro", peso = 1 },
}

-- === Material de cada pieza, segun la zona del patio ===
-- Decision del usuario (29 sep): los montones NO van separados por
-- material; todos traen los cuatro revueltos. Las zonas del norte, tras las
-- barreras de Rebirth 1 y 2, son mas ricas: mas metal y organico, que pagan
-- mas (GameConfig.VALOR_MATERIAL).
-- 5 oct: ya no hay zonas cerradas (todos los cuadrantes son "patio"); los
-- materiales se abren con rebirths (GameConfig.MATERIAL_REBIRTH) y
-- GeneradorBotin quita de esta tabla los que el excavador no tiene (elegir
-- normaliza por el total). Con 0 rebirths: 53 % papel, 47 % plastico.
TablasProbabilidad.MEZCLA = {
	patio = {
		{ id = "Papel", peso = 40 },
		{ id = "Plastico", peso = 35 },
		{ id = "Metal", peso = 15 },
		{ id = "Organico", peso = 10 },
	},
	metal = {
		{ id = "Papel", peso = 15 },
		{ id = "Plastico", peso = 15 },
		{ id = "Metal", peso = 55 },
		{ id = "Organico", peso = 15 },
	},
	organico = {
		{ id = "Papel", peso = 10 },
		{ id = "Plastico", peso = 10 },
		{ id = "Metal", peso = 25 },
		{ id = "Organico", peso = 55 },
	},
} :: { [string]: Tabla }

-- Coleccionables pospuestos (GameConfig.FUNCIONES): con alguna de sus
-- funciones encendida, un monton trae uno de vez en cuando, de este tipo
TablasProbabilidad.COLECCIONABLE = {
	{ id = "figurina", peso = 60 },
	{ id = "cinta", peso = 40 },
}

-- === Utilidades ===
function TablasProbabilidad.elegir(tabla: Tabla, rng: Random?): string
	local total = 0
	for _, e in tabla do
		total += e.peso
	end
	local tiro = if rng then rng:NextNumber(0, total) else math.random() * total
	local acumulado = 0
	for _, e in tabla do
		acumulado += e.peso
		if tiro <= acumulado then
			return e.id
		end
	end
	return tabla[#tabla].id
end

function TablasProbabilidad.suma(tabla: Tabla): number
	local total = 0
	for _, e in tabla do
		total += e.peso
	end
	return total
end

function TablasProbabilidad.verificar()
	local tablas: { [string]: Tabla } = {
		TIPO_PIEZA = TablasProbabilidad.TIPO_PIEZA,
		COLECCIONABLE = TablasProbabilidad.COLECCIONABLE,
	}
	for zona, tabla in TablasProbabilidad.MEZCLA do
		tablas["MEZCLA." .. zona] = tabla
	end
	for nombre, tabla in tablas do
		local s = TablasProbabilidad.suma(tabla)
		assert(math.abs(s - 100) < 1e-6, string.format("TablasProbabilidad.%s suma %.3f, no 100", nombre, s))
	end
end

TablasProbabilidad.verificar()

return TablasProbabilidad
