--!strict
--[[
	DefinicionesRankings
	Unica responsabilidad: que rankings hay (un tablon por ranking en la
	plaza), de que estadistica del perfil sale cada uno y que semana es. Solo
	datos y funciones puras: lo usan el servidor (Services/Rankings, que
	escribe y lee los OrderedDataStores) y el cliente (Client/Tablones, que
	calcula tu propio valor sin esperar a la lectura).

	Cada ranking tiene dos periodos: "historico" (la estadistica tal cual) y
	"semanal" (lo hecho desde el lunes 00:00 UTC). Las SUMAS semanales salen
	de restar la foto de las estadisticas del lunes (perfil.semana.base, la
	toma Perfiles.semanaAlDia); los MAXIMOS (la racha) no se pueden restar y
	se llevan aparte (perfil.semana.maximos).
]]

local Paleta = require(script.Parent:WaitForChild("Paleta"))

export type Ranking = {
	id: string, -- tambien la clave de Textos.RANKING.titulo y el atributo Ranking del tablon
	estadistica: string, -- clave de perfil.estadisticas
	modo: "suma" | "maximo",
	formato: "dinero" | "numero",
	icono: string, -- clave de Config/Iconos
	color: Color3, -- cabecera del tablon
}

local DefinicionesRankings = {}

-- En el orden de los tablones de norte a sur (de izquierda a derecha vistos
-- desde el spawn)
DefinicionesRankings.LISTA = {
	{ id = "dinero", estadistica = "dineroGanadoTotal", modo = "suma", formato = "dinero", icono = "billete", color = Paleta.UI_DINERO },
	{ id = "racha", estadistica = "rachaMaxima", modo = "maximo", formato = "numero", icono = "estrella", color = Paleta.UI_FUERZA },
	{ id = "aciertos", estadistica = "aciertos", modo = "suma", formato = "numero", icono = "lanzar", color = Paleta.UI_CARTAS },
} :: { Ranking }

DefinicionesRankings.POR_ID = {} :: { [string]: Ranking }
for _, def in DefinicionesRankings.LISTA do
	DefinicionesRankings.POR_ID[def.id] = def
end

DefinicionesRankings.PERIODOS = { "historico", "semanal" }

-- Filas de cada columna del tablon, y puestos que se leen: con una sola
-- pagina de 100 cada cliente sabe su puesto aunque no salga en el top 10
DefinicionesRankings.TOP = 10
DefinicionesRankings.LEER = 100
-- Segundos entre lecturas y entre escrituras de cada jugador. Los limites de
-- Roblox: GetSortedAsync 5 + 2 por jugador al minuto, escrituras 60 + 10 por
-- jugador; 6 lecturas cada 2 min caben de sobra
DefinicionesRankings.INTERVALO_LECTURA = 120
DefinicionesRankings.INTERVALO_ESCRITURA = 120
-- Cambiarla empieza rankings nuevos, vacios (los viejos se quedan sin leer).
-- 2 (22 oct): tablones limpios para el lanzamiento, con los perfiles v4
DefinicionesRankings.VERSION = 2

-- La semana de un instante (os.time). El 1 ene 1970 fue jueves: sumar 3 dias
-- hace que cada semana empiece el lunes a las 00:00 UTC
function DefinicionesRankings.semana(t: number): number
	return math.floor((t + 3 * 86400) / 604800)
end

-- El valor de un perfil en un ranking y periodo. ahora: os.time()
function DefinicionesRankings.valor(perfil: any, def: Ranking, periodo: string, ahora: number): number
	local estadisticas = (perfil and perfil.estadisticas) or {}
	local total = math.floor(estadisticas[def.estadistica] or 0)
	if periodo == "historico" then
		return total
	end
	local semana = perfil and perfil.semana
	if typeof(semana) ~= "table" or semana.id ~= DefinicionesRankings.semana(ahora) then
		return 0
	end
	if def.modo == "maximo" then
		return math.floor((semana.maximos or {})[def.estadistica] or 0)
	end
	return math.max(0, total - math.floor((semana.base or {})[def.estadistica] or 0))
end

return DefinicionesRankings
