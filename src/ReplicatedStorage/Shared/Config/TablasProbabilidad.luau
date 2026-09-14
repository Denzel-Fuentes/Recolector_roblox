--!strict
--[[
	TablasProbabilidad (OddsTables en el GDD)
	UNICA fuente de probabilidades del juego.

	La usa el servidor para otorgar (Services/Botin, TiendaHandler) y el cliente
	para pintar el modal "Ver probabilidades" antes de comprar. Que sea el mismo
	modulo en ReplicatedStorage es lo que garantiza que el numero mostrado y el
	numero real no puedan desincronizarse: la politica de Roblox sobre items
	aleatorios pagados exige mostrar la probabilidad exacta de cada resultado.

	Cada tabla es una lista ORDENADA de { id, peso } cuyos pesos suman 100. El
	orden importa: es el orden en que se muestran en la UI. verificar() falla al
	cargar si alguna no suma 100, para que un error de edicion nunca llegue a
	produccion silenciosamente.
]]

local GameConfig = require(script.Parent.GameConfig)

export type Entrada = { id: string, peso: number }
export type Tabla = { Entrada }

local TablasProbabilidad = {}

-- === Contenido de un monton: que es cada objeto que salta ===
TablasProbabilidad.TIPO_OBJETO = {
	{ id = "basura", peso = 58 },
	{ id = "billete", peso = 15 },
	{ id = "fragmento", peso = 14 },
	{ id = "mascota", peso = 6 },
	{ id = "tesoro", peso = 4 },
	{ id = "coleccionable", peso = 3 },
}

TablasProbabilidad.MATERIAL_BASURA = {
	{ id = "Metal", peso = 25 },
	{ id = "Plastico", peso = 30 },
	{ id = "Papel", peso = 30 },
	{ id = "Organico", peso = 15 },
}

-- Estado de conservacion de una mascota completa encontrada en la basura
TablasProbabilidad.ESTADO_MASCOTA_MONTON = {
	{ id = "1", peso = 30 }, -- Danada
	{ id = "2", peso = 35 }, -- Regular
	{ id = "3", peso = 25 }, -- Buena
	{ id = "4", peso = 8 }, -- Excelente
	{ id = "5", peso = 2 }, -- Perfecta
}
TablasProbabilidad.PROB_SUCIA_MONTON = 0.7

-- Rareza de un FRAGMENTO. Tabla plana, sin pity: los fragmentos son el camino
-- constante hacia las raras; el pity vive en las mascotas completas.
TablasProbabilidad.RAREZA_FRAGMENTO = {
	{ id = "Comun", peso = 70 },
	{ id = "Rara", peso = 22 },
	{ id = "Epica", peso = 8 },
}
-- Probabilidad de que un fragmento sea de una mascota que YA tienes a medias
-- (1-4 piezas). Hace converger el ensamblaje en vez de dispersarlo.
TablasProbabilidad.SESGO_FRAGMENTO_EN_CURSO = 0.5

TablasProbabilidad.COLECCIONABLE = {
	{ id = "figurina", peso = 50 },
	{ id = "cinta", peso = 35 },
	{ id = "traje", peso = 15 },
}

-- === Sobre de Mascotas Premium (149 Gemas) ===
TablasProbabilidad.SOBRE_PREMIUM = {
	rareza = {
		{ id = "Comun", peso = 55 },
		{ id = "Rara", peso = 35 },
		{ id = "Epica", peso = 10 },
	} :: Tabla,
	estado = {
		{ id = "2", peso = 40 },
		{ id = "3", peso = 35 },
		{ id = "4", peso = 20 },
		{ id = "5", peso = 5 },
	} :: Tabla,
}

-- === Contenedor Dorado (endgame, 3 mascotas) ===
TablasProbabilidad.CONTENEDOR_DORADO = {
	rareza = {
		{ id = "Rara", peso = 60 },
		{ id = "Epica", peso = 40 },
	} :: Tabla,
	estado = {
		{ id = "3", peso = 50 },
		{ id = "4", peso = 40 },
		{ id = "5", peso = 10 },
	} :: Tabla,
}

-- === Pity de mascotas completas en montones ===
-- Probabilidad de "Rara o mejor" para una mascota que salta de un monton.
function TablasProbabilidad.probabilidadRara(pity: number, conPase: boolean): number
	local paso = if conPase then GameConfig.PITY_PASO_PASE else GameConfig.PITY_PASO
	return math.min(GameConfig.PITY_TOPE, GameConfig.PITY_BASE + paso * pity)
end

-- Tabla derivada para la UI (que se muestre tambien como suma 100)
function TablasProbabilidad.tablaRarezaMonton(pity: number, conPase: boolean): Tabla
	local rara = TablasProbabilidad.probabilidadRara(pity, conPase)
	local epica = rara * GameConfig.PROB_EPICA_ENTRE_RARAS
	local soloRara = rara - epica
	local comun = 1 - rara
	return {
		{ id = "Comun", peso = comun * 100 },
		{ id = "Rara", peso = soloRara * 100 },
		{ id = "Epica", peso = epica * 100 },
	}
end

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
		TIPO_OBJETO = TablasProbabilidad.TIPO_OBJETO,
		MATERIAL_BASURA = TablasProbabilidad.MATERIAL_BASURA,
		ESTADO_MASCOTA_MONTON = TablasProbabilidad.ESTADO_MASCOTA_MONTON,
		RAREZA_FRAGMENTO = TablasProbabilidad.RAREZA_FRAGMENTO,
		COLECCIONABLE = TablasProbabilidad.COLECCIONABLE,
		SOBRE_PREMIUM_rareza = TablasProbabilidad.SOBRE_PREMIUM.rareza,
		SOBRE_PREMIUM_estado = TablasProbabilidad.SOBRE_PREMIUM.estado,
		CONTENEDOR_DORADO_rareza = TablasProbabilidad.CONTENEDOR_DORADO.rareza,
		CONTENEDOR_DORADO_estado = TablasProbabilidad.CONTENEDOR_DORADO.estado,
	}
	for nombre, tabla in tablas do
		local s = TablasProbabilidad.suma(tabla)
		assert(math.abs(s - 100) < 1e-6, string.format("TablasProbabilidad.%s suma %.3f, no 100", nombre, s))
	end
	local derivada = TablasProbabilidad.suma(TablasProbabilidad.tablaRarezaMonton(5, false))
	assert(math.abs(derivada - 100) < 1e-6, "tablaRarezaMonton no suma 100")
end

TablasProbabilidad.verificar()

return TablasProbabilidad
