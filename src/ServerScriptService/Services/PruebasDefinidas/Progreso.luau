--!nonstrict
--[[
	Pruebas de progreso y economia: estado y forma del perfil v3, dinero,
	mejoras (las 4 de la v2 y el Brazo), aparicion en la plaza, tutorial,
	coleccionables, pases, y que no quede nada de lo que la v2 quito.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Botin = require(Servicios:WaitForChild("Botin"))
local Mundo = require(Servicios:WaitForChild("Mundo"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Tutorial = require(Servicios:WaitForChild("Tutorial"))
local Lanzamiento = require(Servicios:WaitForChild("Lanzamiento"))
local Pedidos = require(Servicios:WaitForChild("Pedidos"))
local Rebirths = require(Servicios:WaitForChild("Rebirths"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador, teletransportar = Comunes.jugador, Comunes.teletransportar

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

function Pruebas.estado()
	local j = jugador()
	local p = Perfiles.obtener(j)
	if not p then
		return "sin perfil"
	end
	local mejoras = {}
	for _, def in DefinicionesMejoras.LISTA do
		table.insert(mejoras, def.id .. "=" .. (p.mejoras[def.id] or 0))
	end
	return string.format(
		"%s: cargado=%s v%d dinero=%d rebirths=%d bolsa=%d/%d mejoras[%s] tutorial=%d modoDev=%s",
		j.Name, tostring(Perfiles.estaCargado(j)), p.version, p.dinero, p.rebirths,
		Bolsa.cuenta(j), Bolsa.capacidad(j), table.concat(mejoras, " "), p.tutorial, tostring(Monetizacion.modoDev())
	)
end

function Pruebas.dar(cantidad)
	local j = jugador()
	Economia.ganar(j, tonumber(cantidad) or 1000)
	return "dinero: " .. Economia.dinero(j)
end

function Pruebas.comprarMejora(id)
	local j = jugador()
	local coste = Mejoras.costeSiguiente(j, id)
	local antes = Economia.dinero(j)
	local exito, msg = Mejoras.comprar(j, id)
	return string.format("%s: coste=%s ok=%s msg=%s nivel=%d dinero %d->%d valor=%s", id, tostring(coste), tostring(exito), msg, Mejoras.nivel(j, id), antes, Economia.dinero(j), tostring(Mejoras.valor(j, id)))
end

function Pruebas.maxMejoras()
	local j = jugador()
	local p = Perfiles.obtener(j)
	for id in p.mejoras do
		p.mejoras[id] = GameConfig.NIVEL_MAX_MEJORA
	end
	Perfiles.marcarSucio(j)
	Mejoras.aplicarVelocidad(j)
	return "todas al maximo: " .. tostring(Mejoras.todasAlMaximo(j)) .. " walkspeed=" .. tostring(Mejoras.valor(j, "Velocidad"))
end

-- Depuracion: fija el nivel de una mejora (p. ej. "Alcance", 10) sin comprar
function Pruebas.fijarMejora(id, nivel)
	local j = jugador()
	local p = Perfiles.obtener(j)
	p.mejoras[id] = math.clamp(tonumber(nivel) or 0, 0, GameConfig.NIVEL_MAX_MEJORA)
	Perfiles.marcarSucio(j)
	Mejoras.aplicarVelocidad(j)
	return id .. " = " .. p.mejoras[id] .. " (valor " .. Mejoras.valor(j, id) .. ")"
end

function Pruebas.pases(activo)
	Monetizacion.fijarModoDev(activo == true or activo == "on" or activo == "true")
	return "modoDev=" .. tostring(Monetizacion.modoDev())
end

function Pruebas.darColeccionable(tipo, id)
	local j = jugador()
	local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))
	local nuevo = Coleccionables.agregar(j, tipo, id)
	return string.format("%s %s nuevo=%s", tipo, tostring(id), tostring(nuevo))
end

-- El perfil v3 trae el esquema entero de la v2 y completar() rellena sin pisar
function Pruebas.perfilV3()
	local base = Perfiles.porDefecto()
	local claves = {
		"dinero", "mejoras", "rebirths", "pedidos", "racha", "turboHasta", "figurinas",
		"cintas", "logros", "estadisticas", "semana", "recibos", "pasesCache", "tutorial",
	}
	local faltan = {}
	for _, c in claves do
		if base[c] == nil then
			table.insert(faltan, c)
		end
	end
	local sobran = {}
	-- Las mascotas y sus fragmentos se quitaron el 3 oct; los trajes, el 5
	for _, c in {
		"gemas", "exhibidas", "skins", "pity", "montonesExtra", "meGusta", "acompanante", "siguienteUid", "medidores", "capsulasLibres",
		"mascotas", "equipadas", "fragmentos", "pityMascotas", "fragmentosLibres", "trajes", "trajePuesto",
	} do
		if base[c] ~= nil then
			table.insert(sobran, c)
		end
	end
	local nMejoras = 0
	for _ in base.mejoras do
		nMejoras += 1
	end
	local viejo = Perfiles.completar({ dinero = 55, mejoras = { Bolsa = 3 } })
	return string.format("v%d, faltan [%s], sobran [%s], %d mejoras | completar: dinero=%d Bolsa=%d Brazo=%d rebirths=%d => %s",
		base.version, table.concat(faltan, ","), table.concat(sobran, ","), nMejoras,
		viejo.dinero, viejo.mejoras.Bolsa, viejo.mejoras.Brazo, viejo.rebirths,
		ok(base.version == 3 and #faltan == 0 and #sobran == 0 and nMejoras == 4
			and viejo.dinero == 55 and viejo.mejoras.Bolsa == 3 and viejo.mejoras.Brazo == 0 and viejo.rebirths == 0 and viejo.version == 3))
end

-- Las 4 mejoras del diseno v2: valores en 0 y 10, costes y total $118.030
function Pruebas.mejorasV2()
	local esperado = {
		Bolsa = { 10, 40, 150, 10308 },
		Alcance = { 6, 16, 120, 8246 },
		Velocidad = { 16, 28, 200, 13744 },
		Brazo = { 25, 70, 180, 12370 },
	}
	local mal = {}
	for id, e in esperado do
		local v0 = DefinicionesMejoras.valor(id, 0)
		local v10 = DefinicionesMejoras.valor(id, 10)
		local c1 = DefinicionesMejoras.coste(id, 0)
		local c10 = DefinicionesMejoras.coste(id, 9)
		if math.abs(v0 - e[1]) > 1e-6 or math.abs(v10 - e[2]) > 1e-6 or c1 ~= e[3] or c10 ~= e[4] then
			table.insert(mal, string.format("%s(%s,%s,%s,%s)", id, v0, v10, tostring(c1), tostring(c10)))
		end
	end
	local total = DefinicionesMejoras.costeTotal()
	return string.format("%d mejoras, total $%d, mal [%s] => %s", #DefinicionesMejoras.LISTA, total, table.concat(mal, " "),
		ok(#DefinicionesMejoras.LISTA == 4 and total == 118030 and #mal == 0))
end

-- El Brazo limita el alcance: a 40 studs del contenedor, con el Brazo a 0
-- (25 studs) no llega; al 10 (70 studs) entra
function Pruebas.brazoLimita()
	local j = jugador()
	Comunes.yaLanzo(j)
	local p = Perfiles.obtener(j)
	local nivelAntes = p.mejoras.Brazo
	local zona = Mundo.zonaAcierto()
	local function tirar(nivel)
		p.mejoras.Brazo = nivel
		teletransportar(j, zona.Position + Vector3.new(0, 0, -40))
		task.wait(0.6)
		Bolsa.vaciar(j)
		Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 })
		local antes = Perfiles.leerEstadistica(j, "aciertos")
		local lanzo = Botin.lanzarBolsa(j, zona.Position, 1)
		task.wait(4.3)
		for id, obj in Botin.objetos() do
			if obj.item.tipo == "bolsa" and obj.item.duenoId == j.UserId then
				Botin.reclamar(j, id, "toque")
			end
		end
		Bolsa.vaciar(j)
		return lanzo, Perfiles.leerEstadistica(j, "aciertos") > antes
	end
	local lanzo0, entro0 = tirar(0)
	local lanzo10, entro10 = tirar(GameConfig.NIVEL_MAX_MEJORA)
	p.mejoras.Brazo = nivelAntes
	Perfiles.marcarSucio(j)
	return string.format("Brazo 0 (25 studs): lanzo=%s entro=%s | Brazo 10 (70 studs): lanzo=%s entro=%s => %s",
		tostring(lanzo0), tostring(entro0), tostring(lanzo10), tostring(entro10), ok(lanzo0 and not entro0 and lanzo10 and entro10))
end

-- Todos aparecen en la plaza mirando al patio, sin base; el servidor carga
-- los personajes (CharacterAutoLoads apagado)
function Pruebas.aparicion()
	local j = jugador()
	j:LoadCharacter()
	local personaje = j.Character or j.CharacterAdded:Wait()
	task.wait(0.5)
	local root = personaje:WaitForChild("HumanoidRootPart", 5)
	local destino = Mundo.cframeAparicion()
	local d = if root then (root.Position - destino.Position).Magnitude else math.huge
	-- mirando al patio: hacia -Z (el patio esta al norte de la plaza)
	local mira = if root then root.CFrame.LookVector.Z else 0
	return string.format("CharacterAutoLoads=%s | a %.1f studs del punto de aparicion, mirando z=%.2f => %s",
		tostring(Players.CharacterAutoLoads), d, mira, ok(not Players.CharacterAutoLoads and d < 6 and mira < -0.5))
end

-- Los pasos del tutorial avanzan con las senales y solo en orden
function Pruebas.tutorial()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local previo = p.tutorial
	Bolsa.vaciar(j)
	teletransportar(j, Comunes.fueraDelPatio())
	task.wait(0.5)
	Tutorial.fijar(j, 0)
	local pasos = {}
	Tutorial.completar(j, "excavar") -- fuera de orden: no cuenta
	table.insert(pasos, p.tutorial)
	Tutorial.completar(j, "patio")
	table.insert(pasos, p.tutorial)
	Tutorial.completar(j, "excavar")
	table.insert(pasos, p.tutorial)
	while not Bolsa.estaLlena(j) do
		Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 })
	end
	table.insert(pasos, p.tutorial)
	Lanzamiento.alAcertar:Fire(j, 12)
	table.insert(pasos, p.tutorial)
	Mejoras.alComprar:Fire(j, "Bolsa", 1)
	table.insert(pasos, p.tutorial)
	Bolsa.vaciar(j)
	-- Lote 9: separar (3 bien separadas en su contenedor), un pedido y el
	-- Rebirth 1 (sin pedidos ni rebirths previos, para que no se salten)
	local pedidosPrevios = p.estadisticas.pedidosCompletados
	p.estadisticas.pedidosCompletados = 0
	local mal = {}
	for _ = 1, 3 do
		table.insert(mal, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 1 })
	end
	Bolsa.depositarItems(j, mal, 0, "Plastico") -- en el equivocado: no cuenta
	table.insert(pasos, p.tutorial)
	Bolsa.depositarItems(j, mal, 0, "Papel")
	table.insert(pasos, p.tutorial)
	Pedidos.alCumplir:Fire(j, {})
	table.insert(pasos, p.tutorial)
	Rebirths.alRenacer:Fire(j, 1)
	table.insert(pasos, p.tutorial)
	p.estadisticas.pedidosCompletados = pedidosPrevios
	local terminado = Tutorial.terminado(j)
	Tutorial.fijar(j, previo)
	local serie = table.concat(pasos, ",")
	local esperado = "0,1,2,3,4,5,5,6,7,8"
	return string.format("pasos: %s (esperado %s) terminado=%s => %s", serie, esperado, tostring(terminado), ok(serie == esperado and terminado))
end

-- Nada de lo que la v2 quito sigue en el juego
function Pruebas.sinRestos()
	local restos = {}
	local eventos = Shared:WaitForChild("Events")
	for _, nombre in {
		"AdminEvent", "ComprarSobreEvent", "ContenedorDoradoEvent", "EnergiaEvent", "EnsamblajeEvent",
		"EquiparAcompananteEvent", "ExhibirEvent", "FusionarEvent", "LimpiezaEvent", "LogroEvent",
		"MontonExtraEvent", "PonerSkinBaseEvent", "ReproducirCintaEvent", "ResultadoSobreEvent",
		"TeletransporteEvent", "VenderDuplicadosEvent", "VenderMascotaEvent",
		-- Las capsulas del medidor (29 sep: fragmentos en los montones) y los
		-- dialogos de Dona Chatarra (29 sep: su prompt solo abre la tienda)
		"CapsulaEvent", "AbrirCapsulaEvent", "DialogoEvent",
		-- Las mascotas (3 oct: demasiado trabajo para lo que aportaban)
		"EquiparMascotaEvent", "UsarFragmentoEvent", "RevelacionEvent",
		-- Los trajes del avatar (5 oct)
		"PonerTrajeEvent",
	} do
		if eventos:FindFirstChild(nombre) then
			table.insert(restos, nombre)
		end
	end
	for _, nombre in {
		"Parcelas", "ParcelasHandler", "Energia", "Reparacion", "ReparacionHandler", "Tienda", "Acompanante", "AcompananteHandler", "Capsulas",
		"Mascotas", "MascotasHandler", "Fragmentos", "Seguidores", "Iman",
	} do
		if Servicios:FindFirstChild(nombre) then
			table.insert(restos, "Services." .. nombre)
		end
	end
	-- Los logros vuelven en el lote 7 como 16 insignias, no como los 40 de antes
	local logros = Config:FindFirstChild("DefinicionesLogros")
	if logros and #require(logros).LISTA ~= 16 then
		table.insert(restos, "Config.DefinicionesLogros (no son las 16 insignias)")
	end
	if Shared.Utilidades:FindFirstChild("ProgresoLogros") then
		table.insert(restos, "Utilidades.ProgresoLogros")
	end
	for _, nombre in { "DefinicionesMascotas" } do
		if Config:FindFirstChild(nombre) then
			table.insert(restos, "Config." .. nombre)
		end
	end
	if Shared.Utilidades:FindFirstChild("ModelosMascota") then
		table.insert(restos, "Utilidades.ModelosMascota")
	end
	local perfil = Perfiles.obtener(jugador())
	for _, campo in { "mascotas", "equipadas", "fragmentos", "pityMascotas", "fragmentosLibres", "trajes", "trajePuesto" } do
		if perfil and (perfil :: any)[campo] ~= nil then
			table.insert(restos, "perfil." .. campo)
		end
	end
	for nombre in GameConfig.FUNCIONES do
		if nombre ~= "FIGURINAS" and nombre ~= "CINTAS" then
			table.insert(restos, "FUNCIONES." .. nombre)
		end
	end
	return string.format("restos: [%s] => %s", table.concat(restos, ", "), ok(#restos == 0))
end

return Pruebas
