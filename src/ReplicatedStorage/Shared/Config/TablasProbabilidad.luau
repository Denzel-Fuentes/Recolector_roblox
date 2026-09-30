--!strict
--[[
	TablasProbabilidad (OddsTables en el GDD)
	UNICA fuente de probabilidades del juego.

	La usa el servidor para otorgar (GeneradorBotin, Fragmentos) y el cliente
	para pintar las probabilidades en el album de mascotas. Que sea el mismo
	modulo en ReplicatedStorage garantiza que el numero mostrado y el real no
	puedan desincronizarse. En la v2 nada aleatorio se vende con Robux, pero
	las probabilidades de la mascota se ensenan igual ("aunque sea gratis").

	Cada tabla es una lista ORDENADA de { id, peso } cuyos pesos suman 100. El
	orden importa: es el orden en que se muestran en la UI. verificar() falla al
	cargar si alguna no suma 100, para que un error de edicion nunca llegue a
	produccion silenciosamente.
]]

export type Entrada = { id: string, peso: number }
export type Tabla = { Entrada }

local TablasProbabilidad = {}

-- === Contenido de un monton: que es cada pieza ===
-- Una tirada por pieza (diseno v2): 5 % billetes, 1 % tesoros y 2,5 %
-- fragmentos de mascota (decision del usuario, 29 sep: las mascotas se
-- consiguen juntando fragmentos que salen entre la basura). El grande trae
-- ademas un tesoro y un fragmento garantizados (GameConfig.TAMANOS_MONTON).
TablasProbabilidad.TIPO_PIEZA = {
	{ id = "basura", peso = 91.5 },
	{ id = "billete", peso = 5 },
	{ id = "tesoro", peso = 1 },
	{ id = "fragmento", peso = 2.5 },
}

-- === Material de cada pieza, segun la zona del patio ===
-- Decision del usuario (29 sep): los montones NO van separados por
-- material; todos traen los cuatro revueltos. Las zonas del norte, tras las
-- barreras de Rebirth 1 y 2, son mas ricas: mas metal y organico, que pagan
-- mas (GameConfig.VALOR_MATERIAL). Una pieza del patio vale ~$7,8 de media;
-- de la zona de metal ~$13,8; de la de organico ~$18,7.
TablasProbabilidad.MEZCLA = {
	patio = {
		{ id = "Papel", peso = 45 },
		{ id = "Plastico", peso = 40 },
		{ id = "Metal", peso = 10 },
		{ id = "Organico", peso = 5 },
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

-- === Rareza de la mascota que empieza a montar un set ===
-- Al llegar el primer fragmento de un set sin mascota a medias, se decide
-- cual sera: esta rareza (con el pity de DefinicionesMascotas.PITY) y, dentro
-- de ella, una que no tengas (Services/Fragmentos). Se ensena en el album.
TablasProbabilidad.RAREZA_MASCOTA = {
	{ id = "Comun", peso = 67 },
	{ id = "Rara", peso = 28 },
	{ id = "Epica", peso = 5 },
}

-- Coleccionables pospuestos (GameConfig.FUNCIONES): con alguna de sus
-- funciones encendida, un monton trae uno de vez en cuando, de este tipo
TablasProbabilidad.COLECCIONABLE = {
	{ id = "figurina", peso = 50 },
	{ id = "cinta", peso = 35 },
	{ id = "traje", peso = 15 },
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
		RAREZA_MASCOTA = TablasProbabilidad.RAREZA_MASCOTA,
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
