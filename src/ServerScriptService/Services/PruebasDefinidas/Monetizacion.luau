--!nonstrict
--[[
	Pruebas de monetizacion, admin e insignias (P2, 22 oct): los recibos son
	idempotentes (tambien dos a la vez) y solo se confirman ya guardados,
	esperan al perfil, la compra de un pase dispara alComprarPase solo si
	Roblox la confirma, el modo dev de pases y los comandos de admin solo
	existen en Studio, y los Badges se consultan en lotes con cache.

	Usan ids de prueba inyectados un momento (un ProductId para el Turbo, un
	BadgeService falso) y contextos de Guardado con un almacen en memoria:
	no tocan el registro real del jugador ni llaman a Roblox (salvo
	"insigniasLote" con "real", que solo consulta). Todo lo cambiado se
	restaura al acabar, tambien si la prueba falla.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Productos = require(Shared:WaitForChild("Config"):WaitForChild("Productos"))
local DefinicionesInsignias = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesInsignias"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Guardado = require(Servicios:WaitForChild("Guardado"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Admin = require(Servicios:WaitForChild("Admin"))
local Insignias = require(Servicios:WaitForChild("Insignias"))
local Turbo = require(Servicios:WaitForChild("Turbo"))
local Actividad = require(Servicios:WaitForChild("Actividad"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador = Comunes.jugador

local Pruebas = {}

local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
local NO_AUN = Enum.ProductPurchaseDecision.NotProcessedYet
-- ProductId de prueba que se le pone un momento al Turbo 15
local PRODUCTO_PRUEBA = 990000001

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

local function decision(d): string
	return if d == GRANTED then "Granted" elseif d == NO_AUN then "NotProcessedYet" else tostring(d)
end

local function copiaJson(valor)
	if valor == nil then
		return nil
	end
	return HttpService:JSONDecode(HttpService:JSONEncode(valor))
end

-- Almacen en memoria con la semantica de UpdateAsync (como en Datos).
-- opciones.fallar: cada UpdateAsync lanza un error; opciones.alLlamar(clave)
local function almacenMemoria(opciones)
	local o = opciones or {}
	local datos = {}
	local registro = { llamadas = 0, escrituras = 0 }
	local almacen = {}
	function almacen:UpdateAsync(clave, fn)
		registro.llamadas += 1
		if o.fallar then
			error("fallo simulado del DataStore", 0)
		end
		if o.alLlamar then
			o.alLlamar(clave)
		end
		local nuevo = fn(copiaJson(datos[clave]))
		if nuevo ~= nil then
			datos[clave] = copiaJson(nuevo)
			registro.escrituras += 1
		end
		return nuevo
	end
	return almacen, datos, registro
end

-- Un contexto de Guardado donde la clave del jugador es de esta sesion
local function contextoConJugador(j, opciones)
	local almacen, datos, registro = almacenMemoria(opciones)
	local ctx = Guardado.nuevoContexto({
		almacen = almacen,
		expulsar = function() end,
		espera = function() end,
		reintentos = 2,
	})
	datos[Guardado.claveDe(j)] = { perfil = {}, sesion = { servidor = ctx.servidor, latido = os.time() } }
	return ctx, datos, registro
end

-- Corre fn con el contexto de Guardado cambiado y el ProductId de prueba
-- puesto en el Turbo 15; lo devuelve todo como estaba pase lo que pase
local function conPrueba(ctx, fn)
	local producto = Productos.PRODUCTO_POR_ID.Turbo15
	local idAntes = producto.productId
	producto.productId = PRODUCTO_PRUEBA
	local previo = Guardado.usarContexto(ctx)
	local resultado = table.pack(pcall(fn))
	Guardado.usarContexto(previo)
	producto.productId = idAntes
	if not resultado[1] then
		error(resultado[2], 0)
	end
	return table.unpack(resultado, 2, resultado.n)
end

-- Lo que toca un recibo del Turbo, para dejarlo como estaba: el Turbo que
-- queda (economia v4: turboRestante), los recibos, la cuenta de compras y
-- la hora de la ultima compra (compras.ultimaRobux, la regla de 24 h de las
-- ofertas)
local function foto(p)
	return {
		turboRestante = p.turboRestante,
		recibos = table.clone(p.recibos),
		compras = p.estadisticas.comprasRobux,
		ultimaRobux = p.compras.ultimaRobux,
	}
end
local function devolver(j, p, f)
	p.turboRestante = f.turboRestante
	p.recibos = f.recibos
	p.estadisticas.comprasRobux = f.compras
	p.compras.ultimaRobux = f.ultimaRobux
	Turbo.sincronizar(j)
	Perfiles.marcarSucio(j)
end

-- Sin Turbo y quieto (Actividad.olvidar): el Turbo que da el recibo no corre
-- mientras la prueba espera al guardado y la cuenta de 900 s es exacta. Si
-- no, una prueba con depositos en los 2 minutos de antes lo dejaria correr
local function sinTurbo(j, p)
	p.turboRestante = 0
	Actividad.olvidar(j)
	Turbo.sincronizar(j)
end

local function reciboDePrueba(j)
	return {
		PlayerId = j.UserId,
		ProductId = PRODUCTO_PRUEBA,
		PurchaseId = "Prueba-" .. HttpService:GenerateGUID(false),
		CurrencySpent = 49,
		CurrencyType = Enum.CurrencyType.Robux,
		PlaceIdWherePurchased = game.PlaceId,
	}
end

-- ===========================================================================
-- Recibos
-- ===========================================================================

-- El mismo recibo dos veces (Roblox reintenta): se otorga una vez, las dos
-- respuestas son Granted y el recibo queda en el perfil guardado
function Pruebas.reciboIdempotente()
	local j = jugador()
	if not Perfiles.estaCargado(j) then
		return "el perfil no cargo del DataStore (no se podria guardar) => SIN API"
	end
	local p = Perfiles.obtener(j)
	local antes = foto(p)
	local ctx, datos, registro = contextoConJugador(j)
	local recibo = reciboDePrueba(j)
	local r = {}
	local exito, err = pcall(conPrueba, ctx, function()
		sinTurbo(j, p)
		local compras = p.estadisticas.comprasRobux or 0
		r.uno = Monetizacion.procesarRecibo(recibo)
		r.turbo1 = Turbo.restante(j)
		r.compras1 = (p.estadisticas.comprasRobux or 0) - compras
		r.dos = Monetizacion.procesarRecibo(recibo)
		r.turbo2 = Turbo.restante(j)
		r.compras2 = (p.estadisticas.comprasRobux or 0) - compras
	end)
	local guardadoPerfil = datos[Guardado.claveDe(j)].perfil
	local enGuardado = typeof(guardadoPerfil) == "table" and table.find(guardadoPerfil.recibos or {}, recibo.PurchaseId) ~= nil
	devolver(j, p, antes)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local bien = r.uno == GRANTED and r.dos == GRANTED and math.abs(r.turbo1 - 900) <= 1 and math.abs(r.turbo2 - r.turbo1) <= 1
		and r.compras1 == 1 and r.compras2 == 1 and registro.escrituras == 2 and enGuardado
	return string.format("1.a: %s (Turbo %d s, compras +%d) | 2.a (mismo PurchaseId): %s (Turbo %d s, compras +%d) | %d guardados, recibo en lo guardado=%s => %s",
		decision(r.uno), r.turbo1, r.compras1, decision(r.dos), r.turbo2, r.compras2, registro.escrituras, tostring(enGuardado), ok(bien))
end

-- Sin perfil: si el jugador no esta, NotProcessedYet al momento; si esta
-- pero su perfil no llega, espera ESPERA_PERFIL s antes de rendirse (antes
-- se rendia al instante; desde el 23 oct, por defecto lo que puede tardar
-- de verdad una carga: SESION_ESPERA_ROBO + 15); con el perfil ya cargado
-- no espera
function Pruebas.reciboSinPerfil()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = foto(p)
	local esperaDefecto = Monetizacion.ESPERA_PERFIL
	local buscarAntes = Monetizacion.jugadorPorId
	local r = {}
	local exito, err = pcall(function()
		-- 1) No esta en el servidor
		local t0 = os.clock()
		local fuera = reciboDePrueba(j)
		fuera.PlayerId = -424242
		r.fuera = Monetizacion.procesarRecibo(fuera)
		r.fueraTardo = os.clock() - t0
		-- 2) Esta, pero su perfil no llega (un jugador falso sin perfil)
		local falso = { Parent = workspace, UserId = -424243, Name = "PruebaSinPerfil" }
		Monetizacion.jugadorPorId = function()
			return falso
		end
		Monetizacion.ESPERA_PERFIL = 0.6
		local t1 = os.clock()
		r.sinPerfil = Monetizacion.procesarRecibo(reciboDePrueba(j))
		r.sinPerfilTardo = os.clock() - t1
		Monetizacion.jugadorPorId = buscarAntes
		Monetizacion.ESPERA_PERFIL = esperaDefecto
		-- 3) Con el perfil cargado no espera (y se otorga)
		if Perfiles.estaCargado(j) then
			local ctx = contextoConJugador(j)
			local t2 = os.clock()
			r.conPerfil = conPrueba(ctx, function()
				return Monetizacion.procesarRecibo(reciboDePrueba(j))
			end)
			r.conPerfilTardo = os.clock() - t2
		end
	end)
	Monetizacion.jugadorPorId = buscarAntes
	Monetizacion.ESPERA_PERFIL = esperaDefecto
	devolver(j, p, antes)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local bien = r.fuera == NO_AUN and r.fueraTardo < 0.2 and r.sinPerfil == NO_AUN and r.sinPerfilTardo >= 0.55
		and esperaDefecto >= GameConfig.SESION_ESPERA_ROBO and (r.conPerfil == nil or (r.conPerfil == GRANTED and r.conPerfilTardo < 1))
	return string.format("no esta: %s en %.2f s | sin perfil: %s tras esperar %.2f s (por defecto %d s) | con perfil: %s en %.2f s => %s",
		decision(r.fuera), r.fueraTardo, decision(r.sinPerfil), r.sinPerfilTardo, esperaDefecto,
		if r.conPerfil then decision(r.conPerfil) else "sin API", r.conPerfilTardo or 0, ok(bien))
end

-- Si el guardado falla, NotProcessedYet (lo otorgado se queda, con su
-- recibo anotado); el reintento de Roblox, con el DataStore ya bien, no lo
-- vuelve a dar, guarda y SOLO ENTONCES confirma
function Pruebas.reciboGuardaAntes()
	local j = jugador()
	if not Perfiles.estaCargado(j) then
		return "el perfil no cargo del DataStore (no se podria guardar) => SIN API"
	end
	local p = Perfiles.obtener(j)
	local antes = foto(p)
	local recibo = reciboDePrueba(j)
	local ctxMalo, _, registroMalo = contextoConJugador(j, { fallar = true })
	local orden = {}
	local ctxBueno, datosBuenos = contextoConJugador(j, {
		alLlamar = function()
			table.insert(orden, "guardado")
		end,
	})
	local r = {}
	local exito, err = pcall(function()
		sinTurbo(j, p)
		r.uno = conPrueba(ctxMalo, function()
			return Monetizacion.procesarRecibo(recibo)
		end)
		r.turbo1 = Turbo.restante(j)
		r.anotado = table.find(p.recibos, recibo.PurchaseId) ~= nil
		r.dos = conPrueba(ctxBueno, function()
			return Monetizacion.procesarRecibo(recibo)
		end)
		table.insert(orden, "respuesta")
		r.turbo2 = Turbo.restante(j)
	end)
	local guardadoPerfil = datosBuenos[Guardado.claveDe(j)].perfil
	local enGuardado = typeof(guardadoPerfil) == "table" and table.find(guardadoPerfil.recibos or {}, recibo.PurchaseId) ~= nil
	devolver(j, p, antes)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local bien = r.uno == NO_AUN and registroMalo.llamadas == 2 and math.abs(r.turbo1 - 900) <= 1 and r.anotado
		and r.dos == GRANTED and math.abs(r.turbo2 - r.turbo1) <= 1 and table.concat(orden, ",") == "guardado,respuesta" and enGuardado
	return string.format("guardado roto: %s (%d intentos), Turbo %d s, recibo anotado=%s | reintento con el DataStore bien: %s, Turbo %d s (no se da otra vez), orden [%s], recibo en lo guardado=%s => %s",
		decision(r.uno), registroMalo.llamadas, r.turbo1, tostring(r.anotado), decision(r.dos), r.turbo2,
		table.concat(orden, ","), tostring(enGuardado), ok(bien))
end

-- La compra de un pase (PromptGamePassPurchaseFinished con "comprado") solo
-- lo marca y dispara alComprarPase si Roblox confirma que es suyo
-- (UserOwnsGamePassAsync, sustituido aqui por Monetizacion.poseePase):
--   - confirmado a la primera: marcado, alComprarPase con su id;
--   - un evento fingido (Roblox dice que no las 1 + REINTENTOS_PASE veces):
--     nada, ni cache ni senal;
--   - Roblox aun no lo ve y a la segunda si: marcado (reintento);
--   - la consulta falla (pcall) todas las veces: nada;
--   - un gamePassId que no es del catalogo: nada, sin preguntar.
function Pruebas.compraPase()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local pase = Productos.PASE_POR_ID.EstelaArcoiris
	local idAntes, cacheAntes = pase.gamePassId, p.pasesCache.EstelaArcoiris
	-- Una compra confirmada deja compras.ultimaRobux (K1): se devuelve
	local ultimaRobuxAntes = p.compras.ultimaRobux
	local poseeAntes, esperaAntes = Monetizacion.poseePase, Monetizacion.ESPERA_REINTENTO_PASE
	local recibidos = {}
	local conexion = Monetizacion.alComprarPase:Connect(function(quien, idPase)
		table.insert(recibidos, if quien == j then idPase else "otro")
	end)
	local consultas = 0
	local respuestas = {} -- lo que dira Roblox en cada consulta (se van gastando)
	local function respuestaDeRoblox(lista)
		respuestas = lista
		consultas = 0
	end
	local r = {}
	local exito, err = pcall(function()
		pase.gamePassId = 990000002
		Monetizacion.ESPERA_REINTENTO_PASE = 0.05
		Monetizacion.poseePase = function(_userId, gamePassId)
			consultas += 1
			if gamePassId ~= 990000002 then
				return false
			end
			local siguiente = table.remove(respuestas, 1)
			if siguiente == "error" then
				return nil
			end
			return siguiente == true
		end
		-- confirmado a la primera
		respuestaDeRoblox({ true })
		r.pase = Monetizacion.registrarCompraPase(j, 990000002)
		r.marcado = p.pasesCache.EstelaArcoiris == true
		r.consultas1 = consultas
		r.senales1 = #recibidos
		-- fingido: Roblox dice que no siempre
		p.pasesCache.EstelaArcoiris = nil
		respuestaDeRoblox({ false, false, false, false })
		r.fingido = Monetizacion.registrarCompraPase(j, 990000002)
		r.marcadoFingido = p.pasesCache.EstelaArcoiris == true
		r.consultasFingido = consultas
		r.senalesFingido = #recibidos - r.senales1
		-- aun no se ve, a la segunda si
		respuestaDeRoblox({ false, true })
		r.tarde = Monetizacion.registrarCompraPase(j, 990000002)
		r.marcadoTarde = p.pasesCache.EstelaArcoiris == true
		r.consultasTarde = consultas
		-- la consulta falla siempre
		p.pasesCache.EstelaArcoiris = nil
		respuestaDeRoblox({ "error", "error", "error", "error" })
		r.conError = Monetizacion.registrarCompraPase(j, 990000002)
		r.marcadoError = p.pasesCache.EstelaArcoiris == true
		-- ajeno al catalogo
		respuestaDeRoblox({})
		r.desconocido = Monetizacion.registrarCompraPase(j, 990000003)
		r.consultasDesconocido = consultas
	end)
	conexion:Disconnect()
	Monetizacion.poseePase, Monetizacion.ESPERA_REINTENTO_PASE = poseeAntes, esperaAntes
	pase.gamePassId = idAntes
	p.pasesCache.EstelaArcoiris = cacheAntes
	p.compras.ultimaRobux = ultimaRobuxAntes
	Perfiles.marcarSucio(j)
	Monetizacion.alCambiarPases:Fire(j)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local intentos = 1 + Monetizacion.REINTENTOS_PASE
	local bien = r.pase ~= nil and r.pase.id == "EstelaArcoiris" and r.marcado and r.consultas1 == 1
		and r.fingido == nil and not r.marcadoFingido and r.consultasFingido == intentos and r.senalesFingido == 0
		and r.tarde ~= nil and r.marcadoTarde and r.consultasTarde == 2
		and r.conError == nil and not r.marcadoError
		and r.desconocido == nil and r.consultasDesconocido == 0
		and table.concat(recibidos, ",") == "EstelaArcoiris,EstelaArcoiris"
	return string.format("confirmado: %s, en la cache=%s (%d consulta) | fingido: %s, en la cache=%s, %d consultas, senales %d | a la segunda: %s, en la cache=%s (%d consultas) | consulta con error: %s, en la cache=%s | gamePassId ajeno: %s (%d consultas) | alComprarPase [%s] => %s",
		r.pase and r.pase.id or "nil", tostring(r.marcado), r.consultas1,
		tostring(r.fingido), tostring(r.marcadoFingido), r.consultasFingido, r.senalesFingido,
		r.tarde and r.tarde.id or "nil", tostring(r.marcadoTarde), r.consultasTarde,
		tostring(r.conError), tostring(r.marcadoError),
		tostring(r.desconocido), r.consultasDesconocido, table.concat(recibidos, ","), ok(bien))
end

-- Dos procesarRecibo del MISMO recibo a la vez (Roblox lo reintenta mientras
-- el primero aun guarda): se otorga una sola vez, los dos responden Granted y
-- el recibo queda en lo guardado. El guardado tarda (0,3 s en el almacen de
-- prueba) para que el segundo llegue en mitad del primero. Funciona porque
-- mirar perfil.recibos, otorgar y anotar el recibo va sin ceder: el segundo
-- ya lo encuentra anotado y solo espera a que quede guardado.
function Pruebas.reciboConcurrente()
	local j = jugador()
	if not Perfiles.estaCargado(j) then
		return "el perfil no cargo del DataStore (no se podria guardar) => SIN API"
	end
	local p = Perfiles.obtener(j)
	local antes = foto(p)
	local ctx, datos, registro = contextoConJugador(j, {
		alLlamar = function()
			task.wait(0.3)
		end,
	})
	local recibo = reciboDePrueba(j)
	local r = {}
	local exito, err = pcall(conPrueba, ctx, function()
		sinTurbo(j, p)
		local compras = p.estadisticas.comprasRobux or 0
		local listos = 0
		task.spawn(function()
			r.uno = Monetizacion.procesarRecibo(recibo)
			listos += 1
		end)
		task.spawn(function()
			r.dos = Monetizacion.procesarRecibo(recibo)
			listos += 1
		end)
		local limite = os.clock() + 5
		while listos < 2 and os.clock() < limite do
			task.wait(0.05)
		end
		r.turbo = Turbo.restante(j)
		r.compras = (p.estadisticas.comprasRobux or 0) - compras
		r.veces = 0
		for _, id in p.recibos do
			if id == recibo.PurchaseId then
				r.veces += 1
			end
		end
	end)
	local guardadoPerfil = datos[Guardado.claveDe(j)].perfil
	local enGuardado = typeof(guardadoPerfil) == "table" and table.find(guardadoPerfil.recibos or {}, recibo.PurchaseId) ~= nil
	devolver(j, p, antes)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local bien = r.uno == GRANTED and r.dos == GRANTED and math.abs(r.turbo - 900) <= 1 and r.compras == 1 and r.veces == 1
		and enGuardado and registro.escrituras >= 1
	return string.format("a la vez: %s y %s | Turbo %d s (una compra: 900), compras +%d, recibo %d vez en el perfil | %d guardado(s), recibo en lo guardado=%s => %s",
		decision(r.uno), decision(r.dos), r.turbo or -1, r.compras or -1, r.veces or -1, registro.escrituras, tostring(enGuardado), ok(bien))
end

-- ===========================================================================
-- Solo Studio
-- ===========================================================================

-- El modo dev de pases solo cuenta en Studio: fuera, ni fijarModoDev ni
-- /pases cambian nada y nadie tiene pases que no ha comprado
function Pruebas.modoDevSoloStudio()
	local j = jugador()
	local estudioMon, estudioAdmin = Monetizacion.esStudio, Admin.esStudio
	local modoAntes = Monetizacion.modoDev()
	local r = {}
	-- Sin los pases de verdad del creador (Comunes.sinPasesReales): aqui se
	-- mira que el modo dev no de ninguno
	local exito, err = pcall(Comunes.sinPasesReales, j, function()
		r.enStudio = Monetizacion.fijarModoDev(true) and Monetizacion.modoDev()
		-- Como si fuera el juego publicado, con el modo dev pedido
		Monetizacion.esStudio = function()
			return false
		end
		Admin.esStudio = function()
			return false
		end
		r.fuera = Monetizacion.modoDev()
		r.pase = Monetizacion.tienePase(j, "DineroX2")
		r.snapshot = Perfiles.extrasSnapshot(j).modoDev
		r.fijar = Monetizacion.fijarModoDev(true)
		r.comando = Admin.ejecutar(j, "pases", { "on" })
		r.trasComando = Monetizacion.modoDev()
	end)
	Monetizacion.esStudio, Admin.esStudio = estudioMon, estudioAdmin
	Monetizacion.fijarModoDev(modoAntes)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local bien = r.enStudio == true and r.fuera == false and r.pase == false and r.snapshot == false
		and r.fijar == false and r.comando == nil and r.trasComando == false and Monetizacion.modoDev() == modoAntes
	return string.format("en Studio se enciende=%s | publicado: modoDev=%s, DineroX2=%s, al cliente=%s, fijarModoDev aplica=%s, /pases on responde=%s y deja modoDev=%s | restaurado=%s => %s",
		tostring(r.enStudio), tostring(r.fuera), tostring(r.pase), tostring(r.snapshot), tostring(r.fijar),
		tostring(r.comando), tostring(r.trasComando), tostring(Monetizacion.modoDev()), ok(bien))
end

-- Los comandos: en Studio, en el chat sin autocompletar; publicado, ni
-- comandos ni admins. /dar dinero solo numeros finitos con tope y sin contar
-- como dinero ganado; /rebirths acotado
function Pruebas.adminOculto()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local partes, bien = {}, true

	-- En Studio (este Play): todos registrados y ocultos del autocompletado
	local total, ocultos = 0, 0
	for _, hijo in TextChatService:GetChildren() do
		if hijo:IsA("TextChatCommand") and string.sub(hijo.Name, 1, 6) == "Admin_" then
			total += 1
			if hijo.AutocompleteVisible == false then
				ocultos += 1
			end
		end
	end
	local nComandos = 0
	for _ in Admin.COMANDOS do
		nComandos += 1
	end
	bien = bien and total == nComandos and ocultos == total
	table.insert(partes, string.format("Studio: %d/%d comandos en el chat, %d sin autocompletar", total, nComandos, ocultos))

	-- Publicado: ni comandos, ni admins, ni efecto
	local estudioAntes = Admin.esStudio
	local carpeta = Instance.new("Folder")
	local dineroAntes = p.dinero
	local r = {}
	local exito, err = pcall(function()
		Admin.esStudio = function()
			return false
		end
		r.creados = #Admin.crearComandos(carpeta, function() end)
		r.hijos = #carpeta:GetChildren()
		r.esAdmin = Admin.esAdmin(j)
		r.respuesta = Admin.ejecutar(j, "dar", { "dinero", "500" })
		r.dinero = p.dinero - dineroAntes
	end)
	Admin.esStudio = estudioAntes
	carpeta:Destroy()
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local publicadoOk = r.creados == 0 and r.hijos == 0 and r.esAdmin == false and r.respuesta == nil and r.dinero == 0
	bien = bien and publicadoOk
	table.insert(partes, string.format("publicado: %d comandos creados, admin=%s, /dar dinero 500 responde %s y suma $%d",
		r.creados, tostring(r.esAdmin), tostring(r.respuesta), r.dinero))

	-- /dar dinero: solo numeros finitos de 1 al tope, y no es dinero ganado
	local est = p.estadisticas
	local ganadoAntes, maximoAntes = est.dineroGanadoTotal, est.dineroMaximo
	local rechazados = 0
	local malos = { "abc", "1e400", "-1e400", "nan", "-5", "0", "2e9" }
	for _, texto in malos do
		local antes = p.dinero
		Admin.ejecutar(j, "dar", { "dinero", texto })
		if p.dinero == antes then
			rechazados += 1
		end
	end
	local antes = p.dinero
	local respuesta = Admin.ejecutar(j, "dar", { "dinero", "500" })
	local sumo = p.dinero - antes
	local sinEstadisticas = est.dineroGanadoTotal == ganadoAntes and est.dineroMaximo == maximoAntes
	p.dinero = dineroAntes
	local dineroOk = rechazados == #malos and sumo == 500 and sinEstadisticas
	bien = bien and dineroOk
	table.insert(partes, string.format("/dar dinero: %d/%d invalidos rechazados (%s), 500 suma $%d (%s), dineroGanadoTotal y dineroMaximo intactos=%s",
		rechazados, #malos, table.concat(malos, " "), sumo, tostring(respuesta), tostring(sinEstadisticas)))

	-- /rebirths acotado a 0..TOPE
	local rebirthsAntes = p.rebirths
	Admin.ejecutar(j, "rebirths", { "999" })
	local alto = p.rebirths
	Admin.ejecutar(j, "rebirths", { "-3" })
	local bajo = p.rebirths
	local invalido = Admin.ejecutar(j, "rebirths", { "x" })
	local trasInvalido = p.rebirths
	p.rebirths = rebirthsAntes
	Perfiles.marcarSucio(j)
	local rebirthsOk = alto == Admin.TOPE_REBIRTHS and bajo == 0 and trasInvalido == 0 and typeof(invalido) == "string"
	bien = bien and rebirthsOk
	table.insert(partes, string.format("/rebirths 999 -> %d, -3 -> %d, x -> \"%s\"", alto, bajo, tostring(invalido)))
	return table.concat(partes, " | ") .. " => " .. ok(bien)
end

-- ===========================================================================
-- Insignias
-- ===========================================================================

-- CheckUserBadgesAsync en lotes de 10 como mucho, con cache de la sesion, y
-- al entrar se otorgan solo las del perfil que el jugador aun no tiene. Con
-- un BadgeService falso. ("insigniasLote", "real"): ademas pregunta a Roblox
-- por los Badges reales del jugador y ensena lo que respondio al entrar.
function Pruebas.insigniasLote(modo)
	local j = jugador()
	local partes, bien = {}, true
	local llamadas, tamanos, otorgadas = 0, {}, {}
	local poseidos = {}
	local falso = {}
	function falso:CheckUserBadgesAsync(_userId, ids)
		llamadas += 1
		table.insert(tamanos, #ids)
		local tiene = {}
		for _, id in ids do
			if poseidos[id] then
				table.insert(tiene, id)
			end
		end
		return tiene
	end
	function falso:AwardBadge(_userId, id)
		table.insert(otorgadas, id)
		return true
	end

	local servicioAntes = Insignias.servicio
	local exito, err = pcall(function()
		Insignias.servicio = falso
		Insignias.olvidar(j)
		-- 23 ids de prueba, 7 de ellos ya suyos
		local ids = {}
		for i = 1, 23 do
			ids[i] = 880000000 + i
			if i % 3 == 0 then
				poseidos[ids[i]] = true
			end
		end
		local n1 = Insignias.consultarBadges(j, ids)
		local lotes = table.concat(tamanos, "+")
		local n2 = Insignias.consultarBadges(j, ids)
		local cacheOk = Insignias.tieneBadge(j, ids[3]) == true and Insignias.tieneBadge(j, ids[1]) == false
		local loteOk = n1 == 3 and lotes == "10+10+3" and n2 == 0 and cacheOk
		bien = bien and loteOk
		table.insert(partes, string.format("23 ids: %d llamadas (%s), la segunda vez %d (cache)", n1, lotes, n2))

		-- Al entrar con todas las insignias en el perfil: una consulta para
		-- los Badges del juego y solo se otorgan los que no tiene
		Insignias.olvidar(j)
		llamadas, tamanos = 0, {}
		local reales = {}
		for _, def in DefinicionesInsignias.LISTA do
			if def.badgeId ~= 0 then
				table.insert(reales, def.badgeId)
			end
		end
		poseidos = { [reales[1]] = true }
		local logros = {}
		for _, def in DefinicionesInsignias.LISTA do
			logros[def.id] = true
		end
		local consultas = Insignias.alEntrar(j, { logros = logros })
		task.wait(0.3)
		local primera = #otorgadas
		Insignias.alEntrar(j, { logros = logros })
		task.wait(0.3)
		local entrarOk = consultas == math.ceil(#reales / Insignias.LOTE) and primera == #reales - 1
			and #otorgadas == primera and not table.find(otorgadas, reales[1])
		bien = bien and entrarOk
		table.insert(partes, string.format("al entrar con %d Badges reales (1 ya suyo): %d consulta(s), %d otorgados; al volver a entrar, %d mas",
			#reales, consultas, primera, #otorgadas - primera))
	end)
	Insignias.servicio = servicioAntes
	Insignias.olvidar(j)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end

	if modo == "real" then
		local reales = {}
		for _, def in DefinicionesInsignias.LISTA do
			if def.badgeId ~= 0 then
				table.insert(reales, def.badgeId)
			end
		end
		local exitoReal, tiene = pcall(function()
			return Insignias.servicio:CheckUserBadgesAsync(j.UserId, reales)
		end)
		local nombres = {}
		if exitoReal then
			for _, def in DefinicionesInsignias.LISTA do
				if def.badgeId ~= 0 and table.find(tiene, def.badgeId) then
					table.insert(nombres, def.id)
				end
			end
		end
		local logros = {}
		for id, si in (Perfiles.obtener(j) or { logros = {} }).logros do
			if si then
				table.insert(logros, id)
			end
		end
		table.sort(logros)
		table.insert(partes, string.format("Roblox: %s | logros del perfil [%s] | al entrar: [%s]",
			if exitoReal then ("tiene " .. #nombres .. " de " .. #reales .. " [" .. table.concat(nombres, ",") .. "]") else ("error " .. tostring(tiene)),
			table.concat(logros, ","), table.concat(Insignias.diagnostico(), " / ")))
	end
	return table.concat(partes, " | ") .. " => " .. ok(bien)
end

return Pruebas
