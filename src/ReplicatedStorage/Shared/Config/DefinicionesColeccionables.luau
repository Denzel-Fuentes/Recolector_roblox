--!strict
--[[
	DefinicionesColeccionables
	Los coleccionables secundarios de KOTAMON, 1:1 en cantidad:

	  12 figurinas   6 en escondites FIJOS del patio + 6 aleatorias de montones.
	   7 cintas      salen de montones. sonidoId = 0 es placeholder.

	Diseno v2 (26 sep): figurinas y cintas SE POSPONEN
	(diluian los premios de los montones y su escaparate era la base, que ya
	no existe). Los datos se quedan para volver en una actualizacion; lo que
	los hace aparecer esta apagado en GameConfig.FUNCIONES. Los trajes del
	avatar (3 del botin y 2 de pago) se quitaron el 5 oct.
]]

export type Figurina = {
	id: string,
	nombre: string,
	fija: boolean,
	escondite: string?, -- pista de donde esta (solo fijas)
}

export type Cinta = {
	id: string,
	nombre: string,
	sonidoId: number,
	duracion: number, -- s, para la animacion de la radio
}

export type SkinBase = {
	id: string,
	nombre: string,
	colorLosa: Color3,
	colorMueble: Color3,
	colorBorde: Color3,
}

local DefinicionesColeccionables = {}

DefinicionesColeccionables.FIGURINAS = {
	{ id = "F1", nombre = "Gnomo Oxidado", fija = true, escondite = "Detrás de la caseta de reciclaje" },
	{ id = "F2", nombre = "Pato de Goma", fija = true, escondite = "Dentro del tubo tumbado" },
	{ id = "F3", nombre = "Robot de Hojalata", fija = true, escondite = "Encima del contenedor azul" },
	{ id = "F4", nombre = "Gatito de Cartón", fija = true, escondite = "Bajo la rampa" },
	{ id = "F5", nombre = "Dinosaurio Sin Cola", fija = true, escondite = "Dentro de la lavadora vieja" },
	{ id = "F6", nombre = "Astronauta Pequeñito", fija = true, escondite = "Sobre la pila de neumáticos" },
	{ id = "F7", nombre = "Sirena de Botella", fija = false },
	{ id = "F8", nombre = "Caballero de Latas", fija = false },
	{ id = "F9", nombre = "Búho de Periódico", fija = false },
	{ id = "F10", nombre = "Rana de Tapitas", fija = false },
	{ id = "F11", nombre = "Payaso Descolorido", fija = false },
	{ id = "F12", nombre = "Reciclador en Miniatura", fija = false },
}

DefinicionesColeccionables.CINTAS = {
	{ id = "C1", nombre = "Ritmo Chatarra", sonidoId = 0, duracion = 95 },
	{ id = "C2", nombre = "Balada del Vertedero", sonidoId = 0, duracion = 120 },
	{ id = "C3", nombre = "Plástico Elástico", sonidoId = 0, duracion = 88 },
	{ id = "C4", nombre = "Noticias de Ayer", sonidoId = 0, duracion = 104 },
	{ id = "C5", nombre = "Compost Nocturno", sonidoId = 0, duracion = 130 },
	{ id = "C6", nombre = "Refresco Burbujeante", sonidoId = 0, duracion = 76 },
	{ id = "C7", nombre = "Marcha del Rey Reciclón", sonidoId = 0, duracion = 150 },
}

local function indexar<T>(lista: { T & { id: string } }): { [string]: T }
	local mapa = {}
	for _, item in lista do
		mapa[item.id] = item
	end
	return mapa
end

DefinicionesColeccionables.FIGURINA_POR_ID = indexar(DefinicionesColeccionables.FIGURINAS)
DefinicionesColeccionables.CINTA_POR_ID = indexar(DefinicionesColeccionables.CINTAS)

function DefinicionesColeccionables.figurinasFijas(): { Figurina }
	local lista = {}
	for _, f in DefinicionesColeccionables.FIGURINAS do
		if f.fija then
			table.insert(lista, f)
		end
	end
	return lista
end

function DefinicionesColeccionables.figurinasAleatorias(): { Figurina }
	local lista = {}
	for _, f in DefinicionesColeccionables.FIGURINAS do
		if not f.fija then
			table.insert(lista, f)
		end
	end
	return lista
end

do
	assert(#DefinicionesColeccionables.FIGURINAS == 12, "deben ser 12 figurinas")
	assert(#DefinicionesColeccionables.figurinasFijas() == 6, "deben ser 6 figurinas fijas")
	assert(#DefinicionesColeccionables.CINTAS == 7, "deben ser 7 cintas")
end

return DefinicionesColeccionables
