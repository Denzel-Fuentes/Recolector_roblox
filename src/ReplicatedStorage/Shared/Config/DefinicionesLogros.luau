--!strict
--[[
	DefinicionesLogros
	40 logros en las mismas 11 categorias de KOTAMON: Reciclaje, Ahorro,
	Mejoras, Sets, Estado Perfecto, Contenedor Dorado, Figuritas, Cintas, Trajes,
	Refrescos y Punteria.

	Punteria (decision del usuario): no hay aro. Se lanzan objetos de la bolsa al
	Contenedor de la caseta y los logros premian acertar desde mas LEJOS
	(mejorDistanciaAcierto) mas uno de volumen (aciertos totales).

	Cada logro tiene una condicion declarativa que evalua Services/Logros:

	  estadistica  perfil.estadisticas[clave] >= umbral
	  set          las 10 mascotas del set con al menos una copia
	  rey          tiene al Rey Reciclon
	  perfectas    N mascotas DISTINTAS con una copia Perfecta
	  mejoraNivel  alguna mejora con nivel >= umbral
	  todasMejoras las 7 mejoras al maximo
	  coleccion    N figurinas / cintas / trajes poseidos

	badgeId = 0 es placeholder: se rellena cuando existan las insignias en el
	Creator Dashboard. Con 0 no se llama a BadgeService.
]]

export type Logro = {
	id: string,
	nombre: string,
	descripcion: string,
	categoria: string,
	tipo: string,
	clave: string?,
	umbral: number?,
	badgeId: number,
}

local DefinicionesLogros = {}

DefinicionesLogros.CATEGORIAS = {
	"Reciclaje",
	"Ahorro",
	"Mejoras",
	"Sets",
	"Estado Perfecto",
	"Contenedor Dorado",
	"Figuritas",
	"Cintas",
	"Trajes",
	"Refrescos",
	"Puntería",
}

local function estadistica(id: string, nombre: string, descripcion: string, categoria: string, clave: string, umbral: number): Logro
	return { id = id, nombre = nombre, descripcion = descripcion, categoria = categoria, tipo = "estadistica", clave = clave, umbral = umbral, badgeId = 0 }
end

local function especial(id: string, nombre: string, descripcion: string, categoria: string, tipo: string, clave: string?, umbral: number?): Logro
	return { id = id, nombre = nombre, descripcion = descripcion, categoria = categoria, tipo = tipo, clave = clave, umbral = umbral, badgeId = 0 }
end

DefinicionesLogros.LISTA = {
	-- Reciclaje (5)
	estadistica("reciclaje_1", "Primer Vistazo", "Recicla tu primer objeto", "Reciclaje", "objetosReciclados", 1),
	estadistica("reciclaje_2", "Manos Sucias", "Recicla 100 objetos", "Reciclaje", "objetosReciclados", 100),
	estadistica("reciclaje_3", "Recolector", "Recicla 1.000 objetos", "Reciclaje", "objetosReciclados", 1000),
	estadistica("reciclaje_4", "Fiebre de Chatarra", "Recicla 10.000 objetos", "Reciclaje", "objetosReciclados", 10000),
	estadistica("reciclaje_5", "Leyenda del Vertedero", "Recicla 100.000 objetos", "Reciclaje", "objetosReciclados", 100000),

	-- Ahorro (4): dinero en caja en un momento dado
	estadistica("ahorro_1", "Primeros Billetes", "Ten $1.000 ahorrados", "Ahorro", "dineroMaximo", 1000),
	estadistica("ahorro_2", "Colchón", "Ten $10.000 ahorrados", "Ahorro", "dineroMaximo", 10000),
	estadistica("ahorro_3", "Reciclador de Oro", "Ten $100.000 ahorrados", "Ahorro", "dineroMaximo", 100000),
	estadistica("ahorro_4", "Magnate de la Basura", "Ten $1.000.000 ahorrados", "Ahorro", "dineroMaximo", 1000000),

	-- Mejoras (4)
	estadistica("mejoras_1", "Primera Mejora", "Compra tu primera mejora", "Mejoras", "mejorasCompradas", 1),
	especial("mejoras_2", "Equipado", "Sube una mejora al nivel 5", "Mejoras", "mejoraNivel", nil, 5),
	especial("mejoras_3", "Al Máximo", "Sube una mejora al nivel 10", "Mejoras", "mejoraNivel", nil, 10),
	especial("mejoras_4", "Todo al Máximo", "Las 7 mejoras al nivel 10", "Mejoras", "todasMejoras"),

	-- Sets (5)
	especial("set_chatarrin", "Coleccionista de Chatarrín", "Consigue las 10 mascotas de Chatarrín", "Sets", "set", "Chatarrin"),
	especial("set_plastin", "Coleccionista de Plastín", "Consigue las 10 mascotas de Plastín", "Sets", "set", "Plastin"),
	especial("set_cartonin", "Coleccionista de Cartonín", "Consigue las 10 mascotas de Cartonín", "Sets", "set", "Cartonin"),
	especial("set_mostrenco", "Coleccionista de Mostrenco", "Consigue las 10 mascotas de Mostrenco", "Sets", "set", "Mostrenco"),
	especial("set_rey", "Coronación", "Obtén al Rey Reciclón completando los 4 sets", "Sets", "rey"),

	-- Estado Perfecto (3)
	especial("perfecta_1", "Brillante", "Ten una mascota en estado Perfecto", "Estado Perfecto", "perfectas", nil, 1),
	especial("perfecta_2", "Vitrina Impecable", "Ten 10 mascotas distintas en estado Perfecto", "Estado Perfecto", "perfectas", nil, 10),
	especial("perfecta_3", "Colección Perfecta", "Las 40 mascotas de los sets en estado Perfecto", "Estado Perfecto", "perfectas", nil, 40),

	-- Contenedor Dorado (3)
	estadistica("dorado_1", "Primer Contenedor", "Abre tu primer Contenedor Dorado", "Contenedor Dorado", "contenedoresDorados", 1),
	estadistica("dorado_2", "Cliente VIP", "Abre 10 Contenedores Dorados", "Contenedor Dorado", "contenedoresDorados", 10),
	estadistica("dorado_3", "Fondo Dorado", "Abre 50 Contenedores Dorados", "Contenedor Dorado", "contenedoresDorados", 50),

	-- Figuritas (3)
	especial("figurinas_1", "Primera Figurita", "Encuentra una figurita", "Figuritas", "coleccion", "figurinas", 1),
	especial("figurinas_2", "Media Estantería", "Encuentra 6 figuritas", "Figuritas", "coleccion", "figurinas", 6),
	especial("figurinas_3", "Estantería Completa", "Encuentra las 12 figuritas", "Figuritas", "coleccion", "figurinas", 12),

	-- Cintas (3)
	especial("cintas_1", "Primera Cinta", "Encuentra una cinta", "Cintas", "coleccion", "cintas", 1),
	especial("cintas_2", "Melómano", "Encuentra 4 cintas", "Cintas", "coleccion", "cintas", 4),
	especial("cintas_3", "Discoteca Completa", "Encuentra las 7 cintas", "Cintas", "coleccion", "cintas", 7),

	-- Trajes (3)
	especial("trajes_1", "Primer Traje", "Encuentra un traje de reciclador", "Trajes", "coleccion", "trajes", 1),
	especial("trajes_2", "Cambio de Look", "Encuentra 2 trajes", "Trajes", "coleccion", "trajes", 2),
	especial("trajes_3", "Armario Completo", "Encuentra los 3 trajes gratuitos", "Trajes", "coleccion", "trajes", 3),

	-- Refrescos (3)
	estadistica("refrescos_1", "Primer Sorbo", "Bebe un refresco", "Refrescos", "refrescos", 1),
	estadistica("refrescos_2", "Sediento", "Bebe 25 refrescos", "Refrescos", "refrescos", 25),
	estadistica("refrescos_3", "Adicto a la Chispa", "Bebe 100 refrescos", "Refrescos", "refrescos", 100),

	-- Puntería (4): lanzar al Contenedor de la caseta desde lejos
	estadistica("punteria_1", "Buen Brazo", "Acierta en el Contenedor desde 15 studs", "Puntería", "mejorDistanciaAcierto", 15),
	estadistica("punteria_2", "Francotirador", "Acierta en el Contenedor desde 25 studs", "Puntería", "mejorDistanciaAcierto", 25),
	estadistica("punteria_3", "Desde la Luna", "Acierta en el Contenedor desde 40 studs", "Puntería", "mejorDistanciaAcierto", 40),
	estadistica("punteria_4", "Ojo de Halcón", "Acierta 50 lanzamientos en total", "Puntería", "aciertos", 50),
}

DefinicionesLogros.POR_ID = {} :: { [string]: Logro }
for _, l in DefinicionesLogros.LISTA do
	assert(DefinicionesLogros.POR_ID[l.id] == nil, "logro duplicado: " .. l.id)
	DefinicionesLogros.POR_ID[l.id] = l
end

function DefinicionesLogros.porCategoria(categoria: string): { Logro }
	local lista = {}
	for _, l in DefinicionesLogros.LISTA do
		if l.categoria == categoria then
			table.insert(lista, l)
		end
	end
	return lista
end

do
	assert(#DefinicionesLogros.LISTA == 40, "deben ser 40 logros, hay " .. #DefinicionesLogros.LISTA)
	assert(#DefinicionesLogros.CATEGORIAS == 11, "deben ser 11 categorias")
	for _, l in DefinicionesLogros.LISTA do
		assert(table.find(DefinicionesLogros.CATEGORIAS, l.categoria), "categoria desconocida en " .. l.id)
	end
end

return DefinicionesLogros
