--!strict
--[[
	DefinicionesColeccionables
	Los coleccionables secundarios de KOTAMON, 1:1 en cantidad:

	  12 figurinas   6 en escondites FIJOS del patio + 6 aleatorias de montones.
	                 Decorativas en la estanteria de tu base.
	   7 cintas      salen de montones; se reproducen en la radio de tu base.
	                 sonidoId = 0 es placeholder: la radio muestra el titulo y los
	                 carretes girando hasta que haya audio.
	   3 trajes      CAMBIO frente al original: en Kotamon se regalan a Jenny; aqui
	                 tu propio avatar se los pone. Abre trajes extra de pago.
	   2 skins base  temas decorativos de la parcela (monetizacion cosmetica).
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

export type Traje = {
	id: string,
	nombre: string,
	gratis: boolean,
	colorCuerpo: Color3,
	colorBrazos: Color3,
	colorPiernas: Color3,
	accesorio: string, -- "casco" | "gorra" | "escafandra" | "corona" | "ninguno"
	colorAccesorio: Color3,
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
	{ id = "F1", nombre = "Gnomo Oxidado", fija = true, escondite = "Detrás de la caseta de Doña Chatarra" },
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
	{ id = "F12", nombre = "Doña Chatarra en Miniatura", fija = false },
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

DefinicionesColeccionables.TRAJES = {
	{
		id = "T1",
		nombre = "Mono Naranja",
		gratis = true,
		colorCuerpo = Color3.fromRGB(235, 130, 40),
		colorBrazos = Color3.fromRGB(235, 130, 40),
		colorPiernas = Color3.fromRGB(60, 60, 65),
		accesorio = "gorra",
		colorAccesorio = Color3.fromRGB(235, 130, 40),
	},
	{
		id = "T2",
		nombre = "Chaleco Reflectante",
		gratis = true,
		colorCuerpo = Color3.fromRGB(230, 240, 60),
		colorBrazos = Color3.fromRGB(80, 80, 90),
		colorPiernas = Color3.fromRGB(50, 60, 90),
		accesorio = "casco",
		colorAccesorio = Color3.fromRGB(240, 240, 240),
	},
	{
		id = "T3",
		nombre = "Escafandra de Chatarra",
		gratis = true,
		colorCuerpo = Color3.fromRGB(110, 127, 153),
		colorBrazos = Color3.fromRGB(110, 127, 153),
		colorPiernas = Color3.fromRGB(90, 100, 120),
		accesorio = "escafandra",
		colorAccesorio = Color3.fromRGB(150, 165, 190),
	},
	{
		id = "TP1",
		nombre = "Traje Dorado",
		gratis = false,
		colorCuerpo = Color3.fromRGB(230, 190, 60),
		colorBrazos = Color3.fromRGB(230, 190, 60),
		colorPiernas = Color3.fromRGB(180, 140, 40),
		accesorio = "corona",
		colorAccesorio = Color3.fromRGB(255, 220, 90),
	},
	{
		id = "TP2",
		nombre = "Fantasma del Vertedero",
		gratis = false,
		colorCuerpo = Color3.fromRGB(200, 210, 230),
		colorBrazos = Color3.fromRGB(200, 210, 230),
		colorPiernas = Color3.fromRGB(200, 210, 230),
		accesorio = "ninguno",
		colorAccesorio = Color3.fromRGB(200, 210, 230),
	},
}

DefinicionesColeccionables.SKINS_BASE = {
	{
		id = "S1",
		nombre = "Base Neón",
		colorLosa = Color3.fromRGB(40, 40, 48),
		colorMueble = Color3.fromRGB(190, 255, 60),
		colorBorde = Color3.fromRGB(90, 150, 230),
	},
	{
		id = "S2",
		nombre = "Base Jardín",
		colorLosa = Color3.fromRGB(120, 150, 80),
		colorMueble = Color3.fromRGB(214, 196, 150),
		colorBorde = Color3.fromRGB(150, 110, 70),
	},
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
DefinicionesColeccionables.TRAJE_POR_ID = indexar(DefinicionesColeccionables.TRAJES)
DefinicionesColeccionables.SKIN_POR_ID = indexar(DefinicionesColeccionables.SKINS_BASE)

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

function DefinicionesColeccionables.trajesGratis(): { Traje }
	local lista = {}
	for _, t in DefinicionesColeccionables.TRAJES do
		if t.gratis then
			table.insert(lista, t)
		end
	end
	return lista
end

do
	assert(#DefinicionesColeccionables.FIGURINAS == 12, "deben ser 12 figurinas")
	assert(#DefinicionesColeccionables.figurinasFijas() == 6, "deben ser 6 figurinas fijas")
	assert(#DefinicionesColeccionables.CINTAS == 7, "deben ser 7 cintas")
	assert(#DefinicionesColeccionables.trajesGratis() == 3, "deben ser 3 trajes gratis")
end

return DefinicionesColeccionables
