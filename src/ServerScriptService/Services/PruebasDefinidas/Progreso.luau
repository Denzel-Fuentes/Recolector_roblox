--!nonstrict
--[[
	Pruebas de progreso y economia: estado y forma del perfil v5, dinero,
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

-- El perfil v5 (22 oct, economia v4) trae el esquema entero de la v2, los
-- ajustes de sonido (v4) y los campos de la economia v4 (el Turbo en
-- segundos que quedan, recompensas, ofertas y compras; Perfiles, cabecera).
-- completar() migra y rellena sin pisar, tambien dentro de las tablas que se
-- completan por clave; la sesion del bloqueo no esta en el perfil (no viaja
-- al cliente) y cada sesion suma la estadistica sesiones
function Pruebas.perfilV5()
	local base = Perfiles.porDefecto()
	local claves = {
		"dinero", "mejoras", "rebirths", "pedidos", "racha", "turboRestante", "figurinas",
		"cintas", "logros", "estadisticas", "semana", "recibos", "pasesCache", "tutorial", "ajustes",
		"recompensas", "ofertas", "compras",
	}
	local faltan = {}
	for _, c in claves do
		if base[c] == nil then
			table.insert(faltan, c)
		end
	end
	local sobran = {}
	-- Las mascotas y sus fragmentos se quitaron el 3 oct; los trajes, el 5; la
	-- hora de fin del Turbo (turboHasta), con la v5
	for _, c in {
		"gemas", "exhibidas", "skins", "pity", "montonesExtra", "meGusta", "acompanante", "siguienteUid", "medidores", "capsulasLibres",
		"mascotas", "equipadas", "fragmentos", "pityMascotas", "fragmentosLibres", "trajes", "trajePuesto", "turboHasta",
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
	local ajustesOk = base.ajustes.musica == true and base.ajustes.efectos == true
		and typeof(viejo.ajustes) == "table" and viejo.ajustes.musica == true
	-- Los valores por defecto de la economia v4, y que completar rellena lo que
	-- falte dentro de recompensas sin pisar lo que habia
	local r = base.recompensas
	local defectoOk = base.turboRestante == 0 and r.calendario.siguiente == 1 and r.calendario.vueltas == 0
		and r.calendario.ultimoDia == 0 and r.regalos.dia == 0 and r.regalos.minutos == 0 and r.regalos.cobrados == 0
		and r.ultimoDiaJugado == 0 and next(base.ofertas.porId) == nil and #base.ofertas.historial == 0
		and base.compras.packInicio == false and base.compras.ultimaRobux == 0
	local aMedias = Perfiles.completar({
		version = GameConfig.VERSION_PERFIL,
		recompensas = { calendario = { siguiente = 4 }, ultimoDiaJugado = 20000 },
		ofertas = { porId = { VIP = { vistas = 1, ultima = 5, rechazos = 1 } } },
	})
	local anidadoOk = aMedias.recompensas.calendario.siguiente == 4 and aMedias.recompensas.calendario.vueltas == 0
		and aMedias.recompensas.ultimoDiaJugado == 20000 and aMedias.recompensas.regalos.cobrados == 0
		and aMedias.ofertas.porId.VIP.rechazos == 1 and typeof(aMedias.ofertas.historial) == "table"
		and aMedias.compras.packInicio == false
	-- La sesion va en el registro del DataStore, no en el perfil
	local j = Players:GetPlayers()[1]
	local vivo = j and Perfiles.obtener(j)
	local sinSesion = Perfiles.snapshot(base).sesion == nil and (not vivo or Perfiles.snapshot(vivo).sesion == nil)
	-- anterior: copia de como llego (ultimaSesion de la vez anterior, 0 si es
	-- nuevo); la sesion de ahora ya esta contada en el vivo y no en la copia
	local anterior = j and Perfiles.anterior(j)
	local anteriorOk = not vivo or (anterior ~= nil and anterior ~= vivo and anterior.ultimaSesion < vivo.ultimaSesion
		and (vivo.estadisticas.sesiones or 0) == (anterior.estadisticas.sesiones or 0) + 1)
	return string.format("v%d, faltan [%s], sobran [%s], %d mejoras, ajustes=%s, economia v4 por defecto=%s, completa por dentro=%s, sin sesion en el snapshot=%s, anterior.ultimaSesion=%s (ahora %s), sesiones %s -> %s | completar: dinero=%d Bolsa=%d Brazo=%d rebirths=%d turbo=%s v%d => %s",
		base.version, table.concat(faltan, ","), table.concat(sobran, ","), nMejoras, tostring(ajustesOk), tostring(defectoOk), tostring(anidadoOk), tostring(sinSesion),
		tostring(anterior and anterior.ultimaSesion), tostring(vivo and vivo.ultimaSesion),
		tostring(anterior and anterior.estadisticas.sesiones), tostring(vivo and vivo.estadisticas.sesiones),
		viejo.dinero, viejo.mejoras.Bolsa, viejo.mejoras.Brazo, viejo.rebirths, tostring(viejo.turboRestante), viejo.version,
		ok(base.version == 5 and GameConfig.VERSION_PERFIL == 5 and #faltan == 0 and #sobran == 0 and nMejoras == 4 and ajustesOk
			and defectoOk and anidadoOk and sinSesion and anteriorOk
			and viejo.dinero == 55 and viejo.mejoras.Bolsa == 3 and viejo.mejoras.Brazo == 0 and viejo.rebirths == 0
			and viejo.turboRestante == 0 and viejo.version == 5))
end

-- Las 4 mejoras del diseno v2: valores en 0 y 10, el coste del nivel 1 y del
-- 10, y el total. Economia v4 (22 oct, docs/Economia-v4.md §2.1): factor
-- 1,35, total $35.485 (era $118.030 con 1,6)
function Pruebas.mejorasV2()
	local esperado = {
		Bolsa = { 10, 40, 150, 2234 },
		Alcance = { 6, 16, 120, 1787 },
		Velocidad = { 16, 28, 200, 2979 },
		Brazo = { 25, 70, 180, 2681 },
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
	return string.format("%d mejoras, factor %s, total $%d (esperado 35485), mal [%s] => %s", #DefinicionesMejoras.LISTA,
		tostring(GameConfig.FACTOR_COSTE_MEJORA), total, table.concat(mal, " "),
		ok(#DefinicionesMejoras.LISTA == 4 and GameConfig.FACTOR_COSTE_MEJORA == 1.35 and total == 35485 and #mal == 0))
end

-- El Brazo limita el alcance: a 40 studs del contenedor, con el Brazo a 0
-- (25 studs) no llega; al 10 (70 studs) entra
function Pruebas.brazoLimita()
	local j = jugador()
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local p = Perfiles.obtener(j)
	local nivelAntes = p.mejoras.Brazo
	local zona = Mundo.zonaAcierto()
	local function tirar(nivel)
		p.mejoras.Brazo = nivel
		teletransportar(j, zona.Position + Vector3.new(0, 0, -40))
		task.wait(0.6)
		-- Llena: el servidor no lanza una bolsa a medias (P3, 22 oct)
		Comunes.llenarBolsa(j)
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
	-- El copy, los iconos y el glifo sin uso que se borraron el 22 oct: ni en
	-- Textos ni en ninguna traduccion, ni en Config/Iconos ni en
	-- Utilidades/Glifos. Si alguno vuelve a hacer falta de verdad, se quita
	-- de estas listas.
	local Idioma = require(Shared:WaitForChild("Utilidades"):WaitForChild("Idioma"))
	local Glifos = require(Shared:WaitForChild("Utilidades"):WaitForChild("Glifos"))
	local Iconos = require(Config:WaitForChild("Iconos"))
	local Traducciones = require(Config:WaitForChild("Traducciones"))
	local idiomas = { "es" }
	for codigo in Traducciones.IDIOMAS do
		table.insert(idiomas, codigo)
	end
	for _, clave in {
		"HUD.lanzar", "HUD.cerrar", "PATIO.figurinaYaTienes", "TIENDA.comprar", "TIENDA.equipado",
		"NOTIFICACIONES.guardado", "NOTIFICACIONES.tesoro",
	} do
		-- plantilla(clave, codigo) da la traduccion o, si falta, el espanol:
		-- nil en todos = no esta en ningun sitio
		for _, codigo in idiomas do
			if Idioma.plantilla(clave, codigo) ~= nil then
				table.insert(restos, "Textos." .. clave .. " (" .. codigo .. ")")
				break
			end
		end
	end
	for _, clave in { "gema", "sobre", "contenedorDorado", "pocion" } do
		if Iconos.existe(clave) then
			table.insert(restos, "Iconos." .. clave)
		end
	end
	if Glifos.existe("gema") then
		table.insert(restos, "Glifos.gema")
	end
	return string.format("restos: [%s] => %s", table.concat(restos, ", "), ok(#restos == 0))
end

return Pruebas
