--!nonstrict
--[[
	Pruebas de los rankings (8 oct): la semana empieza el lunes, el valor
	semanal sale de la foto del lunes (sumas) o de los maximos de la semana
	(racha), los tablones estan en el mundo, y una ida y vuelta real por los
	OrderedDataStores de Studio (si hay acceso a la API).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefinicionesRankings = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesRankings"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Rankings = require(Servicios:WaitForChild("Rankings"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador = Comunes.jugador

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

-- Semana, valores semanales (suma y maximo) y el cambio de semana
function Pruebas.rankings()
	local partes, bien = {}, true

	-- Lunes 5 ene 1970 00:00 UTC = 4 dias; el domingo anterior a las 23:59 es
	-- la semana de antes
	local lunes = 4 * 86400
	local semanaOk = DefinicionesRankings.semana(lunes) == DefinicionesRankings.semana(lunes - 60) + 1
		and DefinicionesRankings.semana(lunes) == DefinicionesRankings.semana(lunes + 6 * 86400 + 86399)
	bien = bien and semanaOk
	table.insert(partes, "semana lunes=" .. tostring(semanaOk))

	local j = jugador()
	local p = Perfiles.obtener(j)
	local guardadoEst, guardadoSemana = table.clone(p.estadisticas), p.semana
	local ahora = os.time()
	local dinero, racha = DefinicionesRankings.POR_ID.dinero, DefinicionesRankings.POR_ID.racha

	-- Una semana vieja: al ponerla al dia, la base es lo de ahora
	p.estadisticas.dineroGanadoTotal = 1000
	p.estadisticas.rachaMaxima = 9
	p.semana = { id = 1, base = {}, maximos = { rachaMaxima = 50 } }
	local antes = DefinicionesRankings.valor(p, dinero, "semanal", ahora)
	Perfiles.semanaAlDia(p)
	local tras = DefinicionesRankings.valor(p, dinero, "semanal", ahora)
	p.estadisticas.dineroGanadoTotal += 250
	local sumado = DefinicionesRankings.valor(p, dinero, "semanal", ahora)
	local historico = DefinicionesRankings.valor(p, dinero, "historico", ahora)
	local cambioOk = antes == 0 and tras == 0 and sumado == 250 and historico == 1250
	bien = bien and cambioOk
	table.insert(partes, string.format("dinero semanal: vieja=%d al dia=%d +250=%d historico=%d", antes, tras, sumado, historico))

	-- La racha semanal es el maximo de ESTA semana, no el historico
	Perfiles.estadisticaMaxima(j, "rachaMaxima", 4)
	local r1 = DefinicionesRankings.valor(p, racha, "semanal", ahora)
	Perfiles.estadisticaMaxima(j, "rachaMaxima", 3)
	local r2 = DefinicionesRankings.valor(p, racha, "semanal", ahora)
	local rh = DefinicionesRankings.valor(p, racha, "historico", ahora)
	local rachaOk = r1 == 4 and r2 == 4 and rh == 9
	bien = bien and rachaOk
	table.insert(partes, string.format("racha semanal %d,%d historica %d", r1, r2, rh))

	p.estadisticas, p.semana = guardadoEst, guardadoSemana

	-- Stores separados de Studio y un tablon por ranking en el mundo
	local nombre = Rankings.nombreStore(dinero, "semanal", 2900)
	local nombreOk = string.find(nombre, "Studio", 1, true) ~= nil and string.find(nombre, "_S2900", 1, true) ~= nil
	local pantallas = {}
	for _, pantalla in CollectionService:GetTagged("PantallaRanking") do
		pantallas[pantalla:GetAttribute("Ranking")] = true
	end
	local tablonesOk = true
	for _, def in DefinicionesRankings.LISTA do
		tablonesOk = tablonesOk and pantallas[def.id] == true
	end
	bien = bien and nombreOk and tablonesOk
	table.insert(partes, string.format("store '%s' tablones=%s", nombre, tostring(tablonesOk)))

	return table.concat(partes, " | ") .. " => " .. ok(bien)
end

-- Ida y vuelta real: publica al jugador y lee. Sin acceso a la API de
-- DataStores (place sin publicar) no es un fallo del juego: lo dice.
function Pruebas.rankingsDatastore()
	local j = jugador()
	if not Perfiles.estaCargado(j) then
		return "el perfil no cargo del DataStore: sin acceso a la API => SIN API"
	end
	local escritas = Rankings.publicar(j)
	local datos = Rankings.leer()
	if not datos.disponible then
		return string.format("escritas=%d, lectura no disponible (sin API o sin presupuesto) => SIN API", escritas)
	end
	local partes, aparece = {}, true
	for _, def in DefinicionesRankings.LISTA do
		local valor = DefinicionesRankings.valor(Perfiles.obtener(j), def, "historico", os.time())
		local puesto = 0
		for i, fila in datos.listas[def.id].historico do
			if fila.u == j.UserId then
				puesto = i
				break
			end
		end
		if valor > 0 and puesto == 0 then
			aparece = false
		end
		table.insert(partes, string.format("%s: %d filas, tu=%d (#%d)", def.id, #datos.listas[def.id].historico, valor, puesto))
	end
	return string.format("escritas=%d | %s | nombre=%s", escritas, table.concat(partes, ", "), tostring(datos.nombres[tostring(j.UserId)]))
		.. " => " .. ok(aparece)
end

return Pruebas
