--!nonstrict
--[[
	Pruebas de persistencia (P1, 22 oct; revision del mismo dia): la cola de
	guardado, la espera del cierre, el bloqueo de sesion (con token por
	carga), las migraciones y las versiones mas nuevas, la carga en segundo
	plano, los reintentos de la salida, el store de Studio y que alSalir
	llegue antes del guardado de salida.

	Usan un almacen EN MEMORIA con la semantica de UpdateAsync (lo que entra y
	sale pasa por JSON, como en un DataStore, y devolver nil cancela; puede
	fallar las N primeras veces, repetir la transformacion o volver sin
	ejecutarla) y claves "Prueba_*", con contextos propios de Guardado que se
	pasan a cada funcion: no tocan el registro real del jugador, ni el
	contexto del juego, ni el alSalir real (cada contexto de prueba trae su
	propia senal), ni gastan el limite de 1 escritura cada 6 s por clave.

	"bloqueoSesion" acepta "real": repite sus tres casos en el store de Studio
	con claves de prueba y otro id de servidor (unos 10 s: entre dos
	escrituras de una misma clave espera 6,5 s).

	Avisos esperados en la consola: "almacenInestable" y "salidaReintenta"
	simulan fallos del DataStore (warn de Guardado) y "bloqueoSesion" una
	expulsion (falsa).
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local DefinicionesRankings = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesRankings"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Guardado = require(Servicios:WaitForChild("Guardado"))
local Rankings = require(Servicios:WaitForChild("Rankings"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador = Comunes.jugador

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

-- Copia como la de un DataStore (JSON ida y vuelta)
local function copiaJson(valor)
	if valor == nil then
		return nil
	end
	return HttpService:JSONDecode(HttpService:JSONEncode(valor))
end

-- Almacen en memoria. opciones:
--   antes / despues   segundos de "red" antes de la transformacion y despues
--   alLlamar(clave)   justo antes de la transformacion
--   fallarHasta = N   las N primeras llamadas lanzan un error
--   repetir           ejecuta la transformacion dos veces (como UpdateAsync
--                     ante un conflicto) y vale la ultima
--   sinTransformar    vuelve sin ejecutarla
-- historial[clave] guarda cada valor escrito, en orden.
local function almacenMemoria(opciones)
	local o = opciones or {}
	local datos, historial = {}, {}
	local registro = { llamadas = 0, escrituras = 0 }
	local almacen = {}
	function almacen:UpdateAsync(clave, fn)
		if o.antes then
			task.wait(o.antes)
		end
		registro.llamadas += 1
		if o.fallarHasta and registro.llamadas <= o.fallarHasta then
			error("fallo simulado del DataStore", 0)
		end
		if o.sinTransformar then
			return nil
		end
		if o.alLlamar then
			o.alLlamar(clave)
		end
		local nuevo = fn(copiaJson(datos[clave]))
		if o.repetir then
			nuevo = fn(copiaJson(datos[clave]))
		end
		if nuevo ~= nil then
			datos[clave] = copiaJson(nuevo)
			registro.escrituras += 1
			historial[clave] = historial[clave] or {}
			table.insert(historial[clave], copiaJson(nuevo))
		end
		if o.despues then
			task.wait(o.despues)
		end
		return nuevo
	end
	function almacen:GetAsync(clave)
		return copiaJson(datos[clave])
	end
	return almacen, datos, registro, historial
end

-- Un contexto de prueba: su propia senal alSalir (no la del juego), sin
-- expulsar ni avisar de verdad, y sin tratar las sesiones "Studio-" aparte
local function contextoPrueba(opciones)
	local o = table.clone(opciones or {})
	if o.alSalir == nil then
		o.alSalir = Senal.nueva()
	end
	if o.expulsar == nil then
		o.expulsar = function() end
	end
	if o.notificar == nil then
		o.notificar = function() end
	end
	if o.sesionesStudioCaducan == nil then
		o.sesionesStudioCaducan = false
	end
	return Guardado.nuevoContexto(o)
end

local function sesionDe(servidor: string, latido: number?, token: string?)
	return { servidor = servidor, latido = latido or os.time(), token = token }
end

-- GetAsync del DataStore real sin la cache de 4 s del servidor: lo que se
-- comprueba es lo que acaba de escribir UpdateAsync
local function leerSinCache(almacen, clave: string): (boolean, any)
	return pcall(function()
		local opciones = Instance.new("DataStoreGetOptions")
		opciones.UseCache = false
		return almacen:GetAsync(clave, opciones)
	end)
end

-- ===========================================================================
-- Cola y cierre
-- ===========================================================================

-- Con un guardado en curso, los que llegan esperan y se juntan en UNA ronda
-- que escribe el estado mas nuevo (leido al escribir, no al pedirlo), y el de
-- salida no se descarta: se junta y suelta la sesion
function Pruebas.guardadoEnCola()
	local almacen, datos, registro, historial = almacenMemoria({ antes = 0.25, despues = 0.25 })
	local ctx = contextoPrueba({ almacen = almacen, servidor = "Prueba-cola" })
	local clave = "Prueba_Cola"
	datos[clave] = { perfil = { n = 0 }, sesion = sesionDe("Prueba-cola") }
	local estado = { n = 1 }
	local function perfil()
		return { n = estado.n }
	end
	local resultados, hechos = {}, 0
	local function pedir(nombre, motivo, liberar)
		task.spawn(function()
			local escrito, est = Guardado.escribir(ctx, clave, perfil, motivo, liberar)
			resultados[nombre] = { escrito = escrito, estado = est }
			hechos += 1
		end)
	end
	local base = Guardado.enVuelo()
	pedir("a", "autoguardado", false) -- empieza ya
	task.wait(0.05)
	estado.n = 2
	pedir("b", "autoguardado", false) -- espera turno: segunda ronda
	pedir("c", "recibo", false) -- se junta a la segunda
	pedir("d", "salida", true) -- la de salida tambien: no se descarta
	local enCola = Guardado.enVuelo() - base
	local fin = os.clock() + 6
	while not resultados.a and os.clock() < fin do
		task.wait()
	end
	-- La primera ya escribio: lo que cambie ahora lo debe llevar la segunda
	estado.n = 5
	while hechos < 4 and os.clock() < fin do
		task.wait(0.05)
	end
	local escritos = {}
	for _, valor in historial[clave] or {} do
		table.insert(escritos, string.format("n=%s%s", tostring(valor.perfil and valor.perfil.n), if valor.sesion then "" else " (suelta)"))
	end
	local function res(nombre)
		local r = resultados[nombre]
		return if r then string.format("%s:%s", tostring(r.escrito), r.estado) else "sin respuesta"
	end
	local final = datos[clave]
	local bien = registro.escrituras == 2 and enCola >= 4
		and resultados.a and resultados.a.escrito and resultados.a.estado == "guardada"
		and resultados.b and resultados.b.escrito and resultados.b.estado == "liberada"
		and resultados.c and resultados.c.escrito and resultados.d and resultados.d.escrito
		and final.perfil.n == 5 and final.sesion == nil
		and (historial[clave][1].perfil.n == 2)
		and Guardado.enVuelo() == base
	return string.format("4 peticiones -> %d escrituras [%s] | a=%s b=%s c=%s d=%s | en vuelo con la cola %d, al acabar %d (antes %d) => %s",
		registro.escrituras, table.concat(escritos, ", "), res("a"), res("b"), res("c"), res("d"),
		enCola, Guardado.enVuelo(), base, ok(bien))
end

-- Guardado.cerrar (BindToClose) espera a todo lo que esta en vuelo: lo que
-- empezo antes del cierre, lo que espera turno detras y la salida del
-- jugador, con su alSalir (el del contexto de prueba: la bolsa real no se
-- toca). Con un limite corto se rinde a tiempo.
function Pruebas.cierreEspera()
	local j = jugador()
	if not Perfiles.estaCargado(j) then
		return "el perfil no cargo del DataStore (no se guardaria) => SIN API"
	end
	local almacen, datos, registro = almacenMemoria({ antes = 0.6, despues = 0.6 })
	local salidas = {}
	local alSalir = Senal.nueva()
	alSalir:Connect(function(quien)
		table.insert(salidas, quien)
	end)
	local ctx = contextoPrueba({ almacen = almacen, alSalir = alSalir })
	local claveJ = Guardado.claveDe(j)
	datos[claveJ] = { perfil = {}, sesion = sesionDe(ctx.servidor) }
	datos.Prueba_Cierre_1 = { sesion = sesionDe(ctx.servidor) }
	datos.Prueba_Cierre_2 = { sesion = sesionDe(ctx.servidor) }
	-- Algo en la bolsa real: si saltara el alSalir del juego, Bolsa lo reciclaria
	Bolsa.vaciar(j)
	Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 1 })
	-- Uno que empezo ANTES del cierre (1,2 s)
	task.spawn(Guardado.escribir, ctx, "Prueba_Cierre_1", function()
		return { n = 1 }
	end, "autoguardado", false)
	task.wait(0.3)
	-- Durante el cierre: otro de la misma clave (espera al primero) y otro aparte
	task.spawn(Guardado.escribir, ctx, "Prueba_Cierre_1", function()
		return { n = 2 }
	end, "cierre", true)
	task.spawn(Guardado.escribir, ctx, "Prueba_Cierre_2", function()
		return { n = 2 }
	end, "cierre", true)
	local t0 = os.clock()
	local terminado = Guardado.cerrar(10, ctx)
	local tardo = os.clock() - t0
	local bolsaIntacta = Bolsa.cuenta(j) == 1
	Bolsa.vaciar(j)
	local registroJ = datos[claveJ]
	local soltadas = datos.Prueba_Cierre_1.sesion == nil and datos.Prueba_Cierre_2.sesion == nil and registroJ.sesion == nil
	local delJugador = typeof(registroJ.perfil) == "table" and registroJ.perfil.version == GameConfig.VERSION_PERFIL
	local ultimoDe1 = datos.Prueba_Cierre_1.perfil and datos.Prueba_Cierre_1.perfil.n
	local juegoIntacto = Guardado.contexto() ~= ctx and Guardado.contexto().cerrando == false

	-- Con un limite corto y uno lento (3 s) en vuelo: se rinde a tiempo
	local lento, datosLento = almacenMemoria({ antes = 1.5, despues = 1.5 })
	local ctxLento = contextoPrueba({ almacen = lento })
	datosLento.Prueba_Cierre_Lento = { sesion = sesionDe(ctxLento.servidor) }
	task.spawn(Guardado.escribir, ctxLento, "Prueba_Cierre_Lento", function()
		return { n = 1 }
	end, "autoguardado", false)
	local t1 = os.clock()
	local aTiempo = Guardado.esperarTodos(0.5)
	local tardoCorto = os.clock() - t1
	Guardado.esperarTodos(6) -- que acabe antes de seguir

	local bien = terminado == true and tardo >= 1.8 and tardo < 5 and registro.escrituras == 4 and soltadas
		and delJugador and ultimoDe1 == 2 and #salidas == 1 and salidas[1] == j and bolsaIntacta and ctx.cerrando
		and juegoIntacto and aTiempo == false and tardoCorto >= 0.45 and tardoCorto < 1.2
	return string.format("cerrar esperó %.1f s (lo empezado antes acababa a +0,9 s y lo de detras a +2,1 s): terminado=%s, %d escrituras, sesiones soltadas=%s, perfil del jugador guardado=%s, ultimo de la clave 1 n=%s | alSalir de prueba %d vez, bolsa real intacta=%s, contexto del juego intacto=%s | limite 0,5 s con uno de 3 s: %s a los %.2f s => %s",
		tardo, tostring(terminado), registro.escrituras, tostring(soltadas), tostring(delJugador), tostring(ultimoDe1),
		#salidas, tostring(bolsaIntacta), tostring(juegoIntacto),
		if aTiempo then "acabo" else "se rindio", tardoCorto, ok(bien))
end

-- Con el servidor cerrando: una sesion ajena viva no se espera ni se roba, y
-- una carga (en segundo plano) que toma la sesion cuando empieza el cierre
-- la suelta en vez de registrar el perfil
function Pruebas.cargaDuranteCierre()
	local j = jugador()
	local almacen, datos = almacenMemoria()
	local ctx = contextoPrueba({ almacen = almacen, esperaRobo = 0.6, reintento = 0.2 })
	datos.Prueba_Cierre_Robo = { perfil = { n = 1 }, sesion = sesionDe("Prueba-otro-servidor") }
	ctx.cerrando = true
	local t0 = os.clock()
	local carga = Guardado.tomarSesion(ctx, "Prueba_Cierre_Robo", function()
		return ctx.cerrando
	end)
	local tardo = os.clock() - t0
	local noRobada = datos.Prueba_Cierre_Robo.sesion.servidor == "Prueba-otro-servidor"

	-- El cierre empieza justo mientras la carga en segundo plano toma la sesion
	local ctx2
	local registros = {}
	local almacen2, datos2 = almacenMemoria({
		alLlamar = function()
			if ctx2 then
				ctx2.cerrando = true
			end
		end,
	})
	ctx2 = contextoPrueba({
		almacen = almacen2,
		registrar = function()
			table.insert(registros, "registrar")
		end,
		marcarCargado = function()
			table.insert(registros, "marcarCargado")
		end,
	})
	local resultado = Guardado.intentoEnFondo(ctx2, j)
	local reg = datos2[Guardado.claveDe(j)]
	local soltada = reg ~= nil and reg.sesion == nil

	local bien = carga.ok == false and carga.estado == "cancelada" and tardo < 0.1 and noRobada
		and resultado == "seFue" and soltada and #registros == 0
	return string.format("cerrando y sesion ajena viva: %s en %.2f s, sigue de %s | carga en segundo plano al empezar el cierre: %s, sesion soltada=%s, registros=%d => %s",
		carga.estado, tardo, datos.Prueba_Cierre_Robo.sesion.servidor, resultado, tostring(soltada), #registros, ok(bien))
end

-- ===========================================================================
-- Bloqueo de sesion
-- ===========================================================================

-- Los tres casos del encargo sobre un almacen (en memoria o el de Studio).
-- preparar(clave, registro) deja el registro; leer(clave) lo devuelve.
local function casosBloqueo(almacen, preparar, leer, servidor: string, tiempos)
	local otro = "Prueba-otro-servidor"
	local ctx = contextoPrueba({
		almacen = almacen,
		servidor = servidor,
		esperaRobo = tiempos.esperaRobo,
		reintento = tiempos.reintento,
	})
	local ahora = os.time()
	local claves = { viva = "Prueba_Bloqueo_Viva", caducada = "Prueba_Bloqueo_Caducada", alGuardar = "Prueba_Bloqueo_AlGuardar" }
	preparar(claves.viva, { perfil = { n = 7 }, sesion = sesionDe(otro, ahora) })
	preparar(claves.caducada, { perfil = { n = 8 }, sesion = sesionDe(otro, ahora - GameConfig.SESION_CADUCA - 5) })
	preparar(claves.alGuardar, { perfil = { n = 9 }, sesion = sesionDe(otro, ahora) })
	if tiempos.entreEscrituras then
		task.wait(tiempos.entreEscrituras)
	end

	local res = {}
	local hechos = 0
	-- 1) Viva y ajena: reintenta sin escribir y, pasado el plazo, la roba
	task.spawn(function()
		local t0 = os.clock()
		res.viva = Guardado.tomarSesion(ctx, claves.viva)
		res.vivaTardo = os.clock() - t0
		hechos += 1
	end)
	-- 2) Caducada: se toma al primer intento
	task.spawn(function()
		res.caducada = Guardado.tomarSesion(ctx, claves.caducada)
		hechos += 1
	end)
	-- 3) Robada antes de guardar: no se escribe
	task.spawn(function()
		res.alGuardar = table.pack(Guardado.escribir(ctx, claves.alGuardar, function()
			return { n = 99 }
		end, "autoguardado", false))
		hechos += 1
	end)
	local fin = os.clock() + 30
	while hechos < 3 and os.clock() < fin do
		task.wait(0.1)
	end

	local partes, bien = {}, hechos == 3
	local viva, regViva = res.viva, leer(claves.viva)
	local vivaOk = viva and viva.ok and viva.estado == "robada" and viva.ajena == otro and viva.perfil and viva.perfil.n == 7
		and viva.intentos > 1 and res.vivaTardo >= tiempos.esperaRobo * 0.9
		and regViva and regViva.sesion and regViva.sesion.servidor == servidor and regViva.sesion.token == viva.token
		and regViva.perfil.n == 7
	bien = bien and vivaOk
	table.insert(partes, string.format("viva: %s tras %d intentos y %.1f s, ahora de %s con el token de la carga=%s",
		viva and viva.estado or "?", viva and viva.intentos or 0, res.vivaTardo or -1,
		regViva and regViva.sesion and (if regViva.sesion.servidor == servidor then "este servidor" else regViva.sesion.servidor) or "nadie",
		tostring(regViva and regViva.sesion and viva and regViva.sesion.token == viva.token)))

	local cad, regCad = res.caducada, leer(claves.caducada)
	local cadOk = cad and cad.ok and cad.estado == "caducada" and cad.intentos == 1 and cad.perfil and cad.perfil.n == 8
		and regCad and regCad.sesion and regCad.sesion.servidor == servidor
	bien = bien and cadOk
	table.insert(partes, string.format("caducada: %s al intento %d", cad and cad.estado or "?", cad and cad.intentos or 0))

	local escrito, estado = (res.alGuardar or {})[1], (res.alGuardar or {})[2]
	local regGuardar = leer(claves.alGuardar)
	local guardarOk = escrito == false and estado == "perdida" and regGuardar and regGuardar.perfil.n == 9
		and regGuardar.sesion and regGuardar.sesion.servidor == otro
	bien = bien and guardarOk
	table.insert(partes, string.format("robada al guardar: escrito=%s (%s), en el almacen sigue n=%s de %s",
		tostring(escrito), tostring(estado), tostring(regGuardar and regGuardar.perfil and regGuardar.perfil.n),
		tostring(regGuardar and regGuardar.sesion and regGuardar.sesion.servidor)))
	return partes, bien
end

-- Sesion ajena viva (se espera y se roba), caducada (se toma) y robada al
-- guardar (no se escribe y se expulsa al jugador con el texto en su idioma);
-- en Studio, la de otro Play de Studio se da por caducada. Claves de
-- prueba; ("bloqueoSesion", "real") repite los tres casos en el store de
-- Studio.
function Pruebas.bloqueoSesion(modo)
	local partes, bien = {}, true
	if modo == "real" then
		local almacen = Guardado.contexto().almacen
		if not almacen then
			return "sin DataStore => SIN API"
		end
		local function preparar(clave, registro)
			local exito, err = pcall(function()
				almacen:UpdateAsync(clave, function()
					return registro
				end)
			end)
			if not exito then
				error("sin acceso al DataStore: " .. tostring(err), 0)
			end
		end
		local function leer(clave)
			local exito, valor = leerSinCache(almacen, clave)
			return if exito then valor else nil
		end
		local exito, p, b = pcall(casosBloqueo, almacen, preparar, leer, "Prueba-real-" .. HttpService:GenerateGUID(false),
			{ esperaRobo = 1.5, reintento = 0.5, entreEscrituras = 6.5 })
		if not exito then
			return tostring(p) .. " => SIN API"
		end
		return "store de Studio | " .. table.concat(p, " | ") .. " => " .. ok(b)
	end

	local almacen, datos = almacenMemoria()
	local p, b = casosBloqueo(almacen, function(clave, registro)
		datos[clave] = copiaJson(registro)
	end, function(clave)
		return copiaJson(datos[clave])
	end, "Prueba-memoria", { esperaRobo = 0.6, reintento = 0.2 })
	for _, parte in p do
		table.insert(partes, parte)
	end
	bien = bien and b

	-- Los otros estados al cargar: nada guardado, perfil sin sesion, la nuestra
	local ctx = contextoPrueba({ almacen = almacen, servidor = "Prueba-memoria" })
	datos.Prueba_Bloqueo_Libre = { perfil = { n = 1 } }
	datos.Prueba_Bloqueo_Propia = { perfil = { n = 2 }, sesion = sesionDe("Prueba-memoria", os.time() - 100, "token-viejo") }
	local nueva = Guardado.tomarSesion(ctx, "Prueba_Bloqueo_Nueva")
	local libre = Guardado.tomarSesion(ctx, "Prueba_Bloqueo_Libre")
	local propia = Guardado.tomarSesion(ctx, "Prueba_Bloqueo_Propia")
	local regPropia = datos.Prueba_Bloqueo_Propia.sesion
	local otrosOk = nueva.estado == "nueva" and datos.Prueba_Bloqueo_Nueva.sesion.token == nueva.token
		and libre.estado == "libre" and libre.perfil.n == 1
		and propia.estado == "propia" and os.time() - regPropia.latido <= 1 and regPropia.token == propia.token
	bien = bien and otrosOk
	table.insert(partes, string.format("nueva=%s libre=%s propia=%s (latido renovado y token nuevo=%s)", nueva.estado, libre.estado, propia.estado,
		tostring(regPropia.token == propia.token and propia.token ~= "token-viejo")))

	-- En Studio: una sesion viva de otro Play de Studio se da por caducada
	local ctxStudio = contextoPrueba({ almacen = almacen, servidor = "Prueba-memoria", sesionesStudioCaducan = true })
	datos.Prueba_Bloqueo_Studio = { perfil = { n = 5 }, sesion = sesionDe("Studio-otro-play") }
	local deStudio = Guardado.tomarSesion(ctxStudio, "Prueba_Bloqueo_Studio")
	local studioOk = deStudio.estado == "caducada" and deStudio.intentos == 1
	bien = bien and studioOk
	table.insert(partes, string.format("sesion viva de otro Play de Studio: %s al intento %d", deStudio.estado, deStudio.intentos))

	-- La expulsion: el registro del jugador (en memoria) es de otro servidor
	local j = jugador()
	if Perfiles.estaCargado(j) then
		local expulsiones = {}
		local almacenJ, datosJ, registroJ = almacenMemoria()
		datosJ[Guardado.claveDe(j)] = { perfil = { n = 3 }, sesion = sesionDe("Prueba-otro-servidor") }
		local ctxJ = contextoPrueba({
			almacen = almacenJ,
			expulsar = function(quien, texto)
				table.insert(expulsiones, { quien = quien, texto = texto })
			end,
		})
		local primero = Guardado.guardarAhora(j, "prueba", ctxJ)
		local llamadas = registroJ.llamadas
		local segundo = Guardado.guardarAhora(j, "prueba", ctxJ)
		local esperado = Guardado.textoExpulsion(j)
		local expulsionOk = primero == false and segundo == false and #expulsiones == 1 and expulsiones[1].quien == j
			and expulsiones[1].texto == esperado and registroJ.llamadas == llamadas and registroJ.escrituras == 0
			and datosJ[Guardado.claveDe(j)].perfil.n == 3
		bien = bien and expulsionOk
		table.insert(partes, string.format("expulsion: guardar=%s, %d expulsion(es) con \"%s\" (LocaleId %s), despues ya no se intenta=%s",
			tostring(primero), #expulsiones, expulsiones[1] and expulsiones[1].texto or "", j.LocaleId, tostring(registroJ.llamadas == llamadas)))
	else
		table.insert(partes, "expulsion: sin perfil cargado, no se prueba")
	end
	return "en memoria | " .. table.concat(partes, " | ") .. " => " .. ok(bien)
end

-- Revision 1: la carga lenta de un jugador que sale y vuelve a entrar en el
-- MISMO servidor. La del Player nuevo toma la sesion ("propia") con su
-- token; lo que queda del viejo (soltar la sesion, su guardado de salida)
-- ya no se la quita, y el nuevo sigue guardando
function Pruebas.reentrarMismoServidor()
	local almacen, datos = almacenMemoria()
	local ctx = contextoPrueba({ almacen = almacen, servidor = "Prueba-reentrar" })
	local clave = "Prueba_Reentrar"
	datos[clave] = { perfil = { n = 1 } }
	local vieja = Guardado.tomarSesion(ctx, clave)
	local nueva = Guardado.tomarSesion(ctx, clave)
	local soltoViejo = Guardado.liberarSesion(ctx, clave, vieja.token)
	local escritoViejo, estadoViejo = Guardado.escribir(ctx, clave, function()
		return { n = 666 }
	end, "salida", true, vieja.token)
	local escritoNuevo, estadoNuevo = Guardado.escribir(ctx, clave, function()
		return { n = 2 }
	end, "autoguardado", false, nueva.token)
	local reg = copiaJson(datos[clave])
	-- Sin token (como antes del arreglo) el Player viejo la habria soltado
	local sinToken = Guardado.liberarSesion(ctx, clave, nil)
	local bien = vieja.ok and nueva.ok and nueva.estado == "propia" and vieja.token ~= nueva.token
		and soltoViejo == false and escritoViejo == false and estadoViejo == "perdida"
		and escritoNuevo and estadoNuevo == "guardada" and reg.perfil.n == 2 and reg.sesion and reg.sesion.token == nueva.token
		and sinToken == true
	return string.format("carga vieja %s, nueva %s (otro token=%s) | el viejo suelta=%s, su salida=%s (%s) | el nuevo guarda=%s (%s), en el almacen n=%s con su token=%s | sin token se soltaba=%s => %s",
		vieja.estado, nueva.estado, tostring(vieja.token ~= nueva.token), tostring(soltoViejo), tostring(escritoViejo), estadoViejo,
		tostring(escritoNuevo), estadoNuevo, tostring(reg.perfil and reg.perfil.n), tostring(reg.sesion and reg.sesion.token == nueva.token),
		tostring(sinToken), ok(bien))
end

-- Revision 2: si el jugador se va mientras se espera para robar una sesion
-- viva, se deja de esperar y no se roba
function Pruebas.seVaEsperandoRobo()
	local almacen, datos = almacenMemoria()
	local ctx = contextoPrueba({ almacen = almacen, esperaRobo = 0.6, reintento = 0.2 })
	local clave = "Prueba_SeVa"
	datos[clave] = { perfil = { n = 4 }, sesion = sesionDe("Prueba-otro-servidor") }
	local seFue = false
	task.delay(0.3, function()
		seFue = true
	end)
	local t0 = os.clock()
	local carga = Guardado.tomarSesion(ctx, clave, function()
		return seFue
	end)
	local tardo = os.clock() - t0
	local de = datos[clave].sesion.servidor
	local bien = carga.ok == false and carga.estado == "cancelada" and carga.intentos >= 2 and tardo < 0.55 and de == "Prueba-otro-servidor"
	return string.format("se va a los 0,3 s (se robaria a los 0,6): %s tras %d intentos y %.2f s, la sesion sigue de %s => %s",
		carga.estado, carga.intentos, tardo, de, ok(bien))
end

-- El DataStore inestable: falla las primeras veces (se reintenta), repite la
-- transformacion (vale la ultima) o vuelve sin ejecutarla (revision 6: no
-- vale como carga; antes daba ok con el estado "error")
function Pruebas.almacenInestable()
	local partes, bien = {}, true
	local instantanea = function() end

	local a, _, regA = almacenMemoria({ fallarHasta = 2 })
	local ctxA = contextoPrueba({ almacen = a, espera = instantanea, reintentos = 3 })
	local cargaA = Guardado.tomarSesion(ctxA, "Prueba_Inestable_A")
	local escritoA, estadoA = Guardado.escribir(ctxA, "Prueba_Inestable_A", function()
		return { n = 1 }
	end, "autoguardado", false, cargaA.token)
	local okA = cargaA.ok and cargaA.intentos == 3 and escritoA and estadoA == "guardada" and regA.llamadas == 4
	bien = bien and okA
	table.insert(partes, string.format("falla 2 veces: carga %s al intento %d, guardado %s (%d llamadas)", cargaA.estado, cargaA.intentos, estadoA, regA.llamadas))

	local b, datosB = almacenMemoria({ repetir = true })
	datosB.Prueba_Inestable_B = { perfil = { n = 1 } }
	local ctxB = contextoPrueba({ almacen = b })
	local cargaB = Guardado.tomarSesion(ctxB, "Prueba_Inestable_B")
	local escritoB, estadoB = Guardado.escribir(ctxB, "Prueba_Inestable_B", function()
		return { n = 2 }
	end, "autoguardado", false, cargaB.token)
	local regB = datosB.Prueba_Inestable_B
	local okB = cargaB.ok and cargaB.estado == "libre" and cargaB.perfil.n == 1 and escritoB and estadoB == "guardada"
		and regB.perfil.n == 2 and regB.sesion.token == cargaB.token
	bien = bien and okB
	table.insert(partes, string.format("repite la transformacion: carga %s (n=%s), guardado %s, n=%s con el token de la carga=%s",
		cargaB.estado, tostring(cargaB.perfil and cargaB.perfil.n), estadoB, tostring(regB.perfil.n), tostring(regB.sesion.token == cargaB.token)))

	local c, _, regC = almacenMemoria({ sinTransformar = true })
	local ctxC = contextoPrueba({ almacen = c, espera = instantanea, reintentos = 3 })
	local cargaC = Guardado.tomarSesion(ctxC, "Prueba_Inestable_C")
	local okC = cargaC.ok == false and cargaC.estado == "error" and regC.llamadas == 3
	bien = bien and okC
	table.insert(partes, string.format("vuelve sin transformar: ok=%s (%s) tras %d llamadas", tostring(cargaC.ok), cargaC.estado, regC.llamadas))
	return table.concat(partes, " | ") .. " => " .. ok(bien)
end

-- ===========================================================================
-- Versiones y store
-- ===========================================================================

-- completar migra version a version (MIGRACIONES) antes de rellenar y no
-- pisa nada; un perfil de una version mas nueva conserva su version y sus
-- campos (ni siquiera se borra lo obsoleto) y no se guarda (revision 4).
-- v5 (economia v4): el Turbo que quedaba (turboHasta) pasa a turboRestante
function Pruebas.migracionPerfil()
	local partes, bien = {}, true
	local actual = GameConfig.VERSION_PERFIL

	local v3 = { version = 3, dinero = 55, mejoras = { Bolsa = 3 }, mascotas = { "x" }, estadisticas = { aciertos = 4 } }
	local m = Perfiles.completar(v3)
	local caso1 = m.version == actual and m.dinero == 55 and m.mejoras.Bolsa == 3 and m.mejoras.Brazo == 0
		and m.ajustes.musica == true and m.ajustes.efectos == true and m.mascotas == nil and m.estadisticas.aciertos == 4
		and m.turboRestante == 0
	bien = bien and caso1
	table.insert(partes, string.format("v3 -> v%d con ajustes=%s, dinero=%d, sin mascotas=%s", m.version, tostring(typeof(m.ajustes) == "table"), m.dinero, tostring(m.mascotas == nil)))

	-- La cadena, en orden y una version cada vez: dos versiones de prueba por
	-- encima de la actual, que se quitan al acabar (las reales no se tocan)
	local orden = {}
	local siguiente, otra = actual + 1, actual + 2
	local previas = { Perfiles.MIGRACIONES[siguiente], Perfiles.MIGRACIONES[otra] }
	Perfiles.MIGRACIONES[siguiente] = function(d)
		table.insert(orden, siguiente .. ":" .. tostring(d.version))
		d.renombrado = d.dinero
	end
	Perfiles.MIGRACIONES[otra] = function(d)
		table.insert(orden, otra .. ":" .. tostring(d.version))
	end
	local exito, m2 = pcall(Perfiles.completar, { version = actual, dinero = 7 }, otra)
	Perfiles.MIGRACIONES[siguiente], Perfiles.MIGRACIONES[otra] = previas[1], previas[2]
	local esperado = string.format("%d:%d,%d:%d", siguiente, actual, otra, siguiente)
	local caso2 = exito and table.concat(orden, ",") == esperado and m2.version == otra and m2.renombrado == 7
	bien = bien and caso2
	table.insert(partes, string.format("cadena %d -> %d: [%s] v%s", actual, otra, table.concat(orden, ","), tostring(exito and m2.version)))

	local alDia = Perfiles.completar({ version = actual, dinero = 3, ajustes = { musica = false } })
	local caso3 = alDia.version == actual and alDia.dinero == 3 and alDia.ajustes.musica == false and alDia.ajustes.efectos == true
	bien = bien and caso3
	table.insert(partes, string.format("al dia: musica=%s efectos=%s", tostring(alDia.ajustes.musica), tostring(alDia.ajustes.efectos)))

	-- v4 -> v5: lo que le quedaba de Turbo al cargar pasa a turboRestante (el
	-- caducado, 0) y turboHasta desaparece (OBSOLETO)
	local ahora = os.time()
	local conTurbo = Perfiles.completar({ version = 4, turboHasta = ahora + 600 })
	local caducado = Perfiles.completar({ version = 4, turboHasta = ahora - 50 })
	local caso7 = conTurbo.version == actual and math.abs(conTurbo.turboRestante - 600) <= 2 and conTurbo.turboHasta == nil
		and caducado.turboRestante == 0 and caducado.turboHasta == nil
	bien = bien and caso7
	table.insert(partes, string.format("v4 -> v5: turboHasta +600 s -> turboRestante=%s, caducado -> %s, sin turboHasta=%s",
		tostring(conTurbo.turboRestante), tostring(caducado.turboRestante), tostring(conTurbo.turboHasta == nil and caducado.turboHasta == nil)))

	local nueva = Perfiles.completar({ version = 9, dinero = 1, campoFuturo = "x", mascotas = { "y" } })
	local caso4 = nueva.version == 9 and nueva.campoFuturo == "x" and typeof(nueva.mascotas) == "table" and typeof(nueva.ajustes) == "table"
	bien = bien and caso4
	table.insert(partes, string.format("mas nueva: v%d, conserva lo desconocido=%s y lo obsoleto=%s",
		nueva.version, tostring(nueva.campoFuturo == "x"), tostring(typeof(nueva.mascotas) == "table")))

	-- Lo que decide Guardado con cada carga
	local _, guardableAlDia, avisoAlDia = Guardado.prepararPerfil({ ok = true, estado = "libre", perfil = { version = actual }, intentos = 1 })
	local perfilNuevo, guardableNuevo, avisoNuevo = Guardado.prepararPerfil({ ok = true, estado = "libre", perfil = { version = 9, mascotas = { "z" } }, intentos = 1 })
	local _, guardableFallo, avisoFallo = Guardado.prepararPerfil({ ok = false, estado = "error", perfil = nil, intentos = 3 })
	local caso5 = guardableAlDia == true and avisoAlDia == nil
		and guardableNuevo == false and avisoNuevo == "NOTIFICACIONES.versionNueva" and perfilNuevo.version == 9 and typeof(perfilNuevo.mascotas) == "table"
		and guardableFallo == false and avisoFallo == "NOTIFICACIONES.perfilNoCargado"
	bien = bien and caso5
	table.insert(partes, string.format("al cargar: v%d guardable=%s | v9 guardable=%s aviso %s | carga fallida guardable=%s aviso %s",
		actual, tostring(guardableAlDia), tostring(guardableNuevo), tostring(avisoNuevo), tostring(guardableFallo), tostring(avisoFallo)))

	local vacio = Perfiles.completar(nil)
	local caso6 = vacio.version == GameConfig.VERSION_PERFIL and vacio.dinero == 0
	bien = bien and caso6
	table.insert(partes, "sin datos: v" .. vacio.version)
	return table.concat(partes, " | ") .. " => " .. ok(bien)
end

-- Revision 5: la carga en segundo plano de quien juega con un perfil
-- provisional. Sin nada guardado, el provisional pasa a guardarse tal cual;
-- con partida guardada, la sustituye y se avisa (progresoRecuperado); con
-- una version mas nueva, se registra sin guardar, se suelta la sesion y se
-- avisa (versionNueva). Con registrar y avisos de prueba: el perfil real
-- no se toca.
function Pruebas.cargaEnFondo()
	local j = jugador()
	local clave = Guardado.claveDe(j)
	local function caso(guardado)
		local almacen, datos = almacenMemoria()
		local r = { registros = {}, marcados = 0, avisos = {} }
		r.ctx = contextoPrueba({
			almacen = almacen,
			registrar = function(quien, perfil, guardable)
				table.insert(r.registros, { quien = quien, perfil = perfil, guardable = guardable })
			end,
			marcarCargado = function(quien)
				if quien == j then
					r.marcados += 1
				end
			end,
			notificar = function(_quien, mensaje, tipo)
				table.insert(r.avisos, { k = mensaje.k, tipo = tipo })
			end,
		})
		datos[clave] = guardado
		r.resultado = Guardado.intentoEnFondo(r.ctx, j)
		r.registro = datos[clave]
		return r
	end

	local a = caso(nil)
	local okA = a.resultado == "provisional" and #a.registros == 0 and a.marcados == 1 and #a.avisos == 0
		and a.registro.sesion and a.registro.sesion.token == a.ctx.tokens[j]
	local b = caso({ perfil = { version = 4, dinero = 12345 } })
	local okB = b.resultado == "recuperado" and #b.registros == 1 and b.registros[1].perfil.dinero == 12345 and b.registros[1].guardable == true
		and b.marcados == 0 and #b.avisos == 1 and b.avisos[1].k == "NOTIFICACIONES.progresoRecuperado" and b.ctx.tokens[j] ~= nil
	local c = caso({ perfil = { version = 9, dinero = 5 } })
	local okC = c.resultado == "versionNueva" and #c.registros == 1 and c.registros[1].guardable == false
		and #c.avisos == 1 and c.avisos[1].k == "NOTIFICACIONES.versionNueva" and c.registro.sesion == nil and c.ctx.tokens[j] == nil
	return string.format("sin nada guardado: %s (marcado como cargado %d, registros %d, avisos %d) | con partida: %s (dinero %s, guardable=%s, aviso %s) | version nueva: %s (guardable=%s, aviso %s, sesion soltada=%s) => %s",
		a.resultado, a.marcados, #a.registros, #a.avisos,
		b.resultado, tostring(b.registros[1] and b.registros[1].perfil.dinero), tostring(b.registros[1] and b.registros[1].guardable), tostring(b.avisos[1] and b.avisos[1].k),
		c.resultado, tostring(c.registros[1] and c.registros[1].guardable), tostring(c.avisos[1] and c.avisos[1].k), tostring(c.registro.sesion == nil),
		ok(okA and okB and okC))
end

-- Los stores de Studio llevan "_Studio" (perfiles v4 y rankings v2) y el
-- registro real del jugador es { perfil, sesion } con la sesion de este
-- servidor y el token de su carga (se guarda una vez antes de leerlo)
function Pruebas.storeStudio()
	local j = jugador()
	local nombre = Guardado.nombreStore()
	local nombreOk = nombre == "ReciclatasPerfiles_v4_Studio" and Guardado.nombreStore(false) == "ReciclatasPerfiles_v4"
	local ranking = Rankings.nombreStore(DefinicionesRankings.LISTA[1], "historico", 0)
	local rankingOk = string.sub(ranking, 1, 18) == "Ranking_v2_Studio_"
	local base = string.format("perfiles '%s' (publicado '%s'), rankings '%s'", nombre, Guardado.nombreStore(false), ranking)
	local almacen = Guardado.contexto().almacen
	if not almacen or not Perfiles.estaCargado(j) then
		return base .. " | el perfil no cargo del DataStore => SIN API"
	end
	local guardado = Guardado.guardarAhora(j, "prueba storeStudio")
	local exito, registro = leerSinCache(almacen, Guardado.claveDe(j))
	local sesion = exito and typeof(registro) == "table" and registro.sesion
	local perfil = exito and typeof(registro) == "table" and registro.perfil
	local token = Guardado.contexto().tokens[j]
	local registroOk = typeof(sesion) == "table" and sesion.servidor == Guardado.servidor() and typeof(sesion.latido) == "number"
		and typeof(token) == "string" and sesion.token == token
		and os.time() - sesion.latido <= 60 and typeof(perfil) == "table" and perfil.version == GameConfig.VERSION_PERFIL
		and perfil.sesion == nil
	return string.format("%s | guardado=%s | registro: sesion de %s con el token de su carga=%s (latido hace %s s), perfil v%s sin sesion dentro=%s => %s",
		base, tostring(guardado),
		if typeof(sesion) == "table" then (if sesion.servidor == Guardado.servidor() then "este servidor" else tostring(sesion.servidor)) else "nadie",
		tostring(typeof(sesion) == "table" and token ~= nil and sesion.token == token),
		if typeof(sesion) == "table" then tostring(os.time() - (sesion.latido or 0)) else "?",
		tostring(typeof(perfil) == "table" and perfil.version), tostring(typeof(perfil) == "table" and perfil.sesion == nil),
		ok(nombreOk and rankingOk and guardado and registroOk))
end

-- ===========================================================================
-- Salida
-- ===========================================================================

-- alSalir llega ANTES del guardado de salida: lo que sus callbacks dejan en
-- el perfil (una marca y $10 de la prueba) va en lo que se escribe, y la
-- sesion se suelta. Con la senal del contexto de prueba (la bolsa real no se
-- recicla) y un almacen sin latencia: la escritura empieza en cuanto alSalir
-- devuelve. Sin quitar el perfil (guardarSalida, no salir).
function Pruebas.salidaAntesDeGuardar()
	local j = jugador()
	if not Perfiles.estaCargado(j) then
		return "el perfil no cargo del DataStore (no se guardaria) => SIN API"
	end
	local orden = {}
	local clave = Guardado.claveDe(j)
	local almacen, datos = almacenMemoria({
		antes = 0,
		alLlamar = function(c)
			if c == clave then
				table.insert(orden, "guardado")
			end
		end,
	})
	local alSalir = Senal.nueva()
	alSalir:Connect(function(quien, perfil)
		if quien == j and perfil then
			table.insert(orden, "alSalir")
			perfil.estadisticas.pruebaSalida = (perfil.estadisticas.pruebaSalida or 0) + 1
			perfil.dinero += 10
		end
	end)
	local ctx = contextoPrueba({ almacen = almacen, alSalir = alSalir })
	datos[clave] = { perfil = {}, sesion = sesionDe(ctx.servidor) }
	Bolsa.vaciar(j)
	Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 1 })
	local vivo = Perfiles.obtener(j)
	local dineroEsperado = vivo.dinero + 10
	local marca = (vivo.estadisticas.pruebaSalida or 0) + 1
	local exito, escrito = pcall(Guardado.guardarSalida, j, "salida", ctx)
	local escritoPerfil = datos[clave].perfil
	local bolsaIntacta = Bolsa.cuenta(j) == 1
	local bien = exito and escrito == true and table.concat(orden, ",") == "alSalir,guardado"
		and escritoPerfil.estadisticas.pruebaSalida == marca and escritoPerfil.dinero == dineroEsperado
		and datos[clave].sesion == nil and bolsaIntacta
	-- Dejar el perfil vivo como estaba
	vivo.estadisticas.pruebaSalida = nil
	vivo.dinero -= 10
	Perfiles.marcarSucio(j)
	Bolsa.vaciar(j)
	return string.format("orden [%s] | escrito=%s: marca=%s (esperada %d), dinero $%s (esperado $%d), sesion soltada=%s, bolsa real intacta=%s => %s",
		table.concat(orden, ","), tostring(escrito), tostring(escritoPerfil.estadisticas.pruebaSalida), marca,
		tostring(escritoPerfil.dinero), dineroEsperado, tostring(datos[clave].sesion == nil), tostring(bolsaIntacta), ok(bien))
end

-- Revision 8: si el guardado de salida falla con la sesion aun nuestra, se
-- reintenta sin soltar el turno de la clave (contado en enVuelo) antes de
-- dar el perfil por perdido; la carga de quien vuelve a entrar mientras
-- tanto espera detras y encuentra la sesion ya suelta
function Pruebas.salidaReintenta()
	local almacen, datos, registro = almacenMemoria({ fallarHasta = 3 })
	local ctx = contextoPrueba({
		almacen = almacen,
		reintentos = 2,
		espera = function(s)
			task.wait(s * 0.1)
		end,
		reintentosSalida = 2,
		esperaSalida = 4, -- 0,4 s con la espera de la prueba
	})
	local clave = "Prueba_Salida"
	datos[clave] = { perfil = { n = 1 }, sesion = sesionDe(ctx.servidor, nil, "T1") }
	local base = Guardado.enVuelo()
	local res = {}
	task.spawn(function()
		res.escrito, res.estado = Guardado.escribir(ctx, clave, function()
			return { n = 2 }
		end, "salida", true, "T1")
	end)
	-- Durante la espera del reintento: vuelve a entrar (otra carga en cola)
	task.wait(0.35)
	local enReintento = Guardado.enVuelo() - base
	local fin = os.clock() + 5
	task.spawn(function()
		res.carga = Guardado.tomarSesion(ctx, clave)
	end)
	while (res.estado == nil or res.carga == nil) and os.clock() < fin do
		task.wait(0.05)
	end
	local reg = datos[clave]
	local bien = res.escrito == true and res.estado == "liberada" and enReintento >= 1
		and res.carga and res.carga.estado == "libre" and res.carga.perfil.n == 2
		and reg.perfil.n == 2 and reg.sesion and reg.sesion.token == res.carga.token
	return string.format("salida con 3 fallos seguidos: %s (%s) en %d llamadas, en vuelo durante el reintento %d | la carga que llega mientras: %s con n=%s => %s",
		tostring(res.escrito), tostring(res.estado), registro.llamadas, enReintento,
		res.carga and res.carga.estado or "?", tostring(res.carga and res.carga.perfil and res.carga.perfil.n), ok(bien))
end

return Pruebas
