--!strict
--[[
	DefinicionesInsignias
	Las 16 insignias del diseno v2 (lote 7): hitos de reciclar, de punteria,
	de separar, de dinero, de mejoras y de rebirths. Son Badges de Roblox y
	ademas se guardan en el perfil (perfil.logros), para ensenarlas en el
	panel aunque el badge aun no exista. Solo datos y la cuenta de si un
	perfil cumple una (servidor y panel la comparten).

	badgeId 0 = placeholder: se crean en el Creator Dashboard (el juego ya
	esta publicado) y se rellenan aqui. Con 0 el servidor no llama a
	BadgeService; al rellenarlos, a quien ya la tenia en el perfil se le da
	al entrar (Services/Insignias).

	Condicion (una de):
	  estadistica = clave de perfil.estadisticas, meta = valor minimo
	  mejorasAlMaximo = cuantas de las 4 mejoras al nivel 10
]]

local GameConfig = require(script.Parent.GameConfig)

export type Insignia = {
	id: string,
	nombre: string,
	descripcion: string,
	icono: string, -- clave de Config/Iconos
	badgeId: number,
	estadistica: string?,
	meta: number?,
	mejorasAlMaximo: number?,
}

local DefinicionesInsignias = {}

DefinicionesInsignias.LISTA = {
	{ id = "primerReciclaje", nombre = "Primer reciclaje", descripcion = "Recicla tu primera bolsa", icono = "bolsa", badgeId = 0, estadistica = "depositos", meta = 1 },
	{ id = "primerAcierto", nombre = "¡Dentro!", descripcion = "Encesta tu primera bolsa", icono = "lanzar", badgeId = 0, estadistica = "aciertos", meta = 1 },
	{ id = "tiro30", nombre = "Brazo fuerte", descripcion = "Encesta desde 30 m", icono = "lanzar", badgeId = 0, estadistica = "mejorDistanciaAcierto", meta = 30 },
	{ id = "tiro60", nombre = "Francotirador", descripcion = "Encesta desde 60 m", icono = "lanzar", badgeId = 0, estadistica = "mejorDistanciaAcierto", meta = 60 },
	{ id = "racha5", nombre = "En racha", descripcion = "Encesta 5 seguidas", icono = "estrella", badgeId = 0, estadistica = "rachaMaxima", meta = 5 },
	{ id = "racha10", nombre = "Imparable", descripcion = "Encesta 10 seguidas", icono = "estrella", badgeId = 0, estadistica = "rachaMaxima", meta = 10 },
	{ id = "piezas1000", nombre = "Reciclador", descripcion = "Recicla 1.000 piezas", icono = "bolsa", badgeId = 0, estadistica = "objetosReciclados", meta = 1000 },
	{ id = "piezas10000", nombre = "Gran reciclador", descripcion = "Recicla 10.000 piezas", icono = "bolsa", badgeId = 0, estadistica = "objetosReciclados", meta = 10000 },
	{ id = "separadas500", nombre = "Separa bien", descripcion = "Recicla 500 piezas en su contenedor de color", icono = "setPapel", badgeId = 0, estadistica = "piezasSeparadas", meta = 500 },
	{ id = "primerTesoro", nombre = "Buscatesoros", descripcion = "Encuentra un tesoro en la basura", icono = "cofre", badgeId = 0, estadistica = "tesorosEncontrados", meta = 1 },
	{ id = "dinero10k", nombre = "Ahorrador", descripcion = "Gana $10.000 en total", icono = "billete", badgeId = 0, estadistica = "dineroGanadoTotal", meta = 10000 },
	{ id = "dinero1M", nombre = "Millonario", descripcion = "Gana $1.000.000 en total", icono = "billete", badgeId = 0, estadistica = "dineroGanadoTotal", meta = 1000000 },
	{ id = "mejoraMax", nombre = "A tope", descripcion = "Lleva una mejora al máximo", icono = "bota", badgeId = 0, mejorasAlMaximo = 1 },
	{ id = "todasMax", nombre = "Equipo completo", descripcion = "Las 4 mejoras al máximo", icono = "bota", badgeId = 0, mejorasAlMaximo = 4 },
	{ id = "rebirth1", nombre = "Renacido", descripcion = "Haz tu primer Rebirth", icono = "estrella", badgeId = 0, estadistica = "rebirthMaximo", meta = 1 },
	{ id = "rebirth3", nombre = "Veterano", descripcion = "Llega al Rebirth 3", icono = "estrella", badgeId = 0, estadistica = "rebirthMaximo", meta = 3 },
} :: { Insignia }

DefinicionesInsignias.POR_ID = {} :: { [string]: Insignia }
for _, i in DefinicionesInsignias.LISTA do
	DefinicionesInsignias.POR_ID[i.id] = i
end

-- Cuanto lleva un perfil hacia la insignia y cuanto pide: (actual, meta)
function DefinicionesInsignias.progreso(def: Insignia, perfil: any): (number, number)
	if def.mejorasAlMaximo then
		local alMaximo = 0
		for _, nivel in perfil.mejoras or {} do
			if nivel >= GameConfig.NIVEL_MAX_MEJORA then
				alMaximo += 1
			end
		end
		return alMaximo, def.mejorasAlMaximo
	end
	local estadisticas = perfil.estadisticas or {}
	return estadisticas[def.estadistica or ""] or 0, def.meta or 1
end

function DefinicionesInsignias.cumple(def: Insignia, perfil: any): boolean
	local actual, meta = DefinicionesInsignias.progreso(def, perfil)
	return actual >= meta
end

return DefinicionesInsignias
