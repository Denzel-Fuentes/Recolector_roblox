--!nonstrict
--[[
	Pruebas de persistencia (P1, 22 oct): la cola de guardado, la espera del
	cierre, el bloqueo de sesion, las migraciones del perfil, el store de
	Studio y que Perfiles.alSalir llegue antes del guardado de salida.

	Usan un almacen EN MEMORIA con la semantica de UpdateAsync (lo que entra y
	sale pasa por JSON, como en un DataStore, y devolver nil cancela) y claves
	"Prueba_*", con contextos propios de Guardado: no tocan el registro real
	del jugador ni gastan el limite de 1 escritura cada 6 s por clave. Las que
	necesitan al jugador (cierre, expulsion, salida) cambian el contexto de
	Guardado un momento y SIEMPRE lo devuelven.

	"bloqueoSesion" acepta "real": repite sus tres casos en el store de Studio
	con claves de prueba y otro id de servidor (unos 10 s: entre dos
	escrituras de una misma clave espera 6,5 s).
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local DefinicionesRankings = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesRankings"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Guardado = require(Servicios:WaitForChild("Guardado"))
local Rankings = require(Servicios:WaitForChild("Rankings"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Economia = require(Servicios:WaitForChild("Economia"))

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

-- Almacen en memoria. opciones.antes / .despues: segundos de "red" antes de
-- llamar a la funcion de UpdateAsync y despues de escribir; .alLlamar(clave):
-- se llama justo antes de la funcion. historial[clave] guarda cada valor
-- escrito, en orden.
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
		if o.alLlamar then
			o.alLlamar(clave)
		end
		local nuevo = fn(copiaJson(datos[clave]))
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

local function sesionDe(servidor: string, latido: number?)
	return { servidor = servidor, latido = latido or os.time() }
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

-- Corre fn con el contexto de Guardado cambiado y lo devuelve pase lo que pase
local function conContexto(ctx, fn, ...)
	local previo = Guardado.usarContexto(ctx)
	local resultado = table.pack(pcall(fn, ...))
	Guardado.usarContexto(previo)
	if not resultado[1] then
		error(resultado[2], 0)
	end
	return table.unpack(resultado, 2, resultado.n)
end

-- ===========================================================================
-- Cola y cierre
-- ===========================================================================

-- Con un guardado en curso, los que llegan esperan y se juntan en UNA ronda
-- que escribe el estado mas nuevo (leido al escribir, no al pedirlo), y el de
-- salida no se descarta: se junta y suelta la sesion
function Pruebas.guardadoEnCola()
	local almacen, datos, registro, historial = almacenMemoria({ antes = 0.25, despues = 0.25 })
	local ctx = Guardado.nuevoContexto({ almacen = almacen, servidor = "Prueba-cola" })
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
-- empezo antes del cierre, lo que espera turno detras y el guardado de cierre
-- del jugador (en un almacen en memoria: su registro real no se toca). Con un
-- limite corto se rinde a tiempo.
function Pruebas.cierreEspera()
	local j = jugador()
	if not Perfiles.estaCargado(j) then
		return "el perfil no cargo del DataStore (no se guardaria) => SIN API"
	end
	local almacen, datos, registro = almacenMemoria({ antes = 0.6, despues = 0.6 })
	local ctx = Guardado.nuevoContexto({ almacen = almacen, expulsar = function() end })
	local claveJ = Guardado.claveDe(j)
	datos[claveJ] = { perfil = {}, sesion = sesionDe(ctx.servidor) }
	datos.Prueba_Cierre_1 = { sesion = sesionDe(ctx.servidor) }
	datos.Prueba_Cierre_2 = { sesion = sesionDe(ctx.servidor) }
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
	local terminado = conContexto(ctx, Guardado.cerrar, 10)
	local tardo = os.clock() - t0
	local registroJ = datos[claveJ]
	local soltadas = datos.Prueba_Cierre_1.sesion == nil and datos.Prueba_Cierre_2.sesion == nil and registroJ.sesion == nil
	local delJugador = typeof(registroJ.perfil) == "table" and registroJ.perfil.version == GameConfig.VERSION_PERFIL
	local ultimoDe1 = datos.Prueba_Cierre_1.perfil and datos.Prueba_Cierre_1.perfil.n

	-- Con un limite corto y uno lento (3 s) en vuelo: se rinde a tiempo
	local lento, datosLento = almacenMemoria({ antes = 1.5, despues = 1.5 })
	local ctxLento = Guardado.nuevoContexto({ almacen = lento })
	datosLento.Prueba_Cierre_Lento = { sesion = sesionDe(ctxLento.servidor) }
	task.spawn(Guardado.escribir, ctxLento, "Prueba_Cierre_Lento", function()
		return { n = 1 }
	end, "autoguardado", false)
	local t1 = os.clock()
	local aTiempo = Guardado.esperarTodos(0.5)
	local tardoCorto = os.clock() - t1
	Guardado.esperarTodos(6) -- que acabe antes de seguir

	-- (>= 4: si el autoguardado real cae en esos 2 s, tambien escribe aqui)
	local bien = terminado == true and tardo >= 1.8 and tardo < 5 and registro.escrituras >= 4 and soltadas
		and delJugador and ultimoDe1 == 2 and aTiempo == false and tardoCorto >= 0.45 and tardoCorto < 1.2
	return string.format("cerrar esperó %.1f s (lo empezado antes acababa a +0,9 s y lo de detras a +2,1 s): terminado=%s, %d escrituras, sesiones soltadas=%s, perfil del jugador guardado=%s, ultimo de la clave 1 n=%s | limite 0,5 s con uno de 3 s: %s a los %.2f s => %s",
		tardo, tostring(terminado), registro.escrituras, tostring(soltadas), tostring(delJugador), tostring(ultimoDe1),
		if aTiempo then "acabo" else "se rindio", tardoCorto, ok(bien))
end

-- ===========================================================================
-- Bloqueo de sesion
-- ===========================================================================

-- Los tres casos del encargo sobre un almacen (en memoria o el de Studio).
-- preparar(clave, registro) deja el registro; leer(clave) lo devuelve.
local function casosBloqueo(almacen, preparar, leer, servidor: string, tiempos)
	local otro = "Prueba-otro-servidor"
	local ctx = Guardado.nuevoContexto({
		almacen = almacen,
		servidor = servidor,
		esperaRobo = tiempos.esperaRobo,
		reintento = tiempos.reintento,
		expulsar = function() end,
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
		and regViva and regViva.sesion and regViva.sesion.servidor == servidor and regViva.perfil.n == 7
	bien = bien and vivaOk
	table.insert(partes, string.format("viva: %s tras %d intentos y %.1f s, ahora de %s",
		viva and viva.estado or "?", viva and viva.intentos or 0, res.vivaTardo or -1,
		regViva and regViva.sesion and (if regViva.sesion.servidor == servidor then "este servidor" else regViva.sesion.servidor) or "nadie"))

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
-- guardar (no se escribe y se expulsa al jugador con el texto en su idioma).
-- Claves de prueba; ("bloqueoSesion", "real") lo repite en el store de Studio.
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
	local ctx = Guardado.nuevoContexto({ almacen = almacen, servidor = "Prueba-memoria" })
	datos.Prueba_Bloqueo_Libre = { perfil = { n = 1 } }
	datos.Prueba_Bloqueo_Propia = { perfil = { n = 2 }, sesion = sesionDe("Prueba-memoria", os.time() - 100) }
	local nueva = Guardado.tomarSesion(ctx, "Prueba_Bloqueo_Nueva")
	local libre = Guardado.tomarSesion(ctx, "Prueba_Bloqueo_Libre")
	local propia = Guardado.tomarSesion(ctx, "Prueba_Bloqueo_Propia")
	local otrosOk = nueva.estado == "nueva" and libre.estado == "libre" and libre.perfil.n == 1
		and propia.estado == "propia" and os.time() - datos.Prueba_Bloqueo_Propia.sesion.latido <= 1
	bien = bien and otrosOk
	table.insert(partes, string.format("nueva=%s libre=%s propia=%s (latido renovado)", nueva.estado, libre.estado, propia.estado))

	-- La expulsion: el registro del jugador (en memoria) es de otro servidor
	local j = jugador()
	if Perfiles.estaCargado(j) then
		local expulsiones = {}
		local almacenJ, datosJ, registroJ = almacenMemoria()
		datosJ[Guardado.claveDe(j)] = { perfil = { n = 3 }, sesion = sesionDe("Prueba-otro-servidor") }
		local ctxJ = Guardado.nuevoContexto({
			almacen = almacenJ,
			expulsar = function(quien, texto)
				table.insert(expulsiones, { quien = quien, texto = texto })
			end,
		})
		local primero = conContexto(ctxJ, Guardado.guardarAhora, j, "prueba")
		local llamadas = registroJ.llamadas
		local segundo = conContexto(ctxJ, Guardado.guardarAhora, j, "prueba")
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

-- ===========================================================================
-- Versiones y store
-- ===========================================================================

-- completar migra version a version (MIGRACIONES) antes de rellenar, no pisa
-- nada, no baja la version de un perfil mas nuevo
function Pruebas.migracionPerfil()
	local partes, bien = {}, true

	local v3 = { version = 3, dinero = 55, mejoras = { Bolsa = 3 }, mascotas = { "x" }, estadisticas = { aciertos = 4 } }
	local m = Perfiles.completar(v3)
	local caso1 = m.version == 4 and m.dinero == 55 and m.mejoras.Bolsa == 3 and m.mejoras.Brazo == 0
		and m.ajustes.musica == true and m.ajustes.efectos == true and m.mascotas == nil and m.estadisticas.aciertos == 4
	bien = bien and caso1
	table.insert(partes, string.format("v3 -> v%d con ajustes=%s, dinero=%d, sin mascotas=%s", m.version, tostring(typeof(m.ajustes) == "table"), m.dinero, tostring(m.mascotas == nil)))

	-- La cadena, en orden y una version cada vez (5 y 6 de prueba, se quitan al acabar)
	local orden = {}
	Perfiles.MIGRACIONES[5] = function(d)
		table.insert(orden, "5:" .. tostring(d.version))
		d.renombrado = d.dinero
	end
	Perfiles.MIGRACIONES[6] = function(d)
		table.insert(orden, "6:" .. tostring(d.version))
	end
	local exito, m2 = pcall(Perfiles.completar, { version = 4, dinero = 7 }, 6)
	Perfiles.MIGRACIONES[5], Perfiles.MIGRACIONES[6] = nil, nil
	local caso2 = exito and table.concat(orden, ",") == "5:4,6:5" and m2.version == 6 and m2.renombrado == 7
	bien = bien and caso2
	table.insert(partes, string.format("cadena 4 -> 6: [%s] v%s", table.concat(orden, ","), tostring(exito and m2.version)))

	local alDia = Perfiles.completar({ version = 4, dinero = 3, ajustes = { musica = false } })
	local caso3 = alDia.version == 4 and alDia.dinero == 3 and alDia.ajustes.musica == false and alDia.ajustes.efectos == true
	bien = bien and caso3
	table.insert(partes, string.format("al dia: musica=%s efectos=%s", tostring(alDia.ajustes.musica), tostring(alDia.ajustes.efectos)))

	local nueva = Perfiles.completar({ version = 9, dinero = 1, campoFuturo = "x" })
	local caso4 = nueva.version == 9 and nueva.campoFuturo == "x" and typeof(nueva.ajustes) == "table"
	bien = bien and caso4
	table.insert(partes, string.format("mas nueva: v%d, conserva lo desconocido=%s", nueva.version, tostring(nueva.campoFuturo == "x")))

	local vacio = Perfiles.completar(nil)
	local caso5 = vacio.version == GameConfig.VERSION_PERFIL and vacio.dinero == 0
	bien = bien and caso5
	table.insert(partes, "sin datos: v" .. vacio.version)
	return table.concat(partes, " | ") .. " => " .. ok(bien)
end

-- Los stores de Studio llevan "_Studio" (perfiles v4 y rankings v2) y el
-- registro real del jugador es { perfil, sesion } con la sesion de este
-- servidor (se guarda una vez antes de leerlo)
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
	local registroOk = typeof(sesion) == "table" and sesion.servidor == Guardado.servidor() and typeof(sesion.latido) == "number"
		and os.time() - sesion.latido <= 60 and typeof(perfil) == "table" and perfil.version == GameConfig.VERSION_PERFIL
		and perfil.sesion == nil
	return string.format("%s | guardado=%s | registro: sesion de %s (latido hace %s s), perfil v%s sin sesion dentro=%s => %s",
		base, tostring(guardado),
		if typeof(sesion) == "table" then (if sesion.servidor == Guardado.servidor() then "este servidor" else tostring(sesion.servidor)) else "nadie",
		if typeof(sesion) == "table" then tostring(os.time() - (sesion.latido or 0)) else "?",
		tostring(typeof(perfil) == "table" and perfil.version), tostring(typeof(perfil) == "table" and perfil.sesion == nil),
		ok(nombreOk and rankingOk and guardado and registroOk))
end

-- ===========================================================================
-- Salida
-- ===========================================================================

-- Perfiles.alSalir llega ANTES del guardado de salida: lo que sus callbacks
-- dejan en el perfil (una marca de la prueba y el dinero de la bolsa que
-- Bolsa recicla al salir) va en lo que se escribe, y la sesion se suelta.
-- Con un almacen en memoria y sin quitar el perfil (guardarSalida, no salir).
function Pruebas.salidaAntesDeGuardar()
	local j = jugador()
	if not Perfiles.estaCargado(j) then
		return "el perfil no cargo del DataStore (no se guardaria) => SIN API"
	end
	local orden = {}
	local clave = Guardado.claveDe(j)
	local almacen, datos = almacenMemoria({
		antes = 0.1,
		alLlamar = function(c)
			if c == clave then
				table.insert(orden, "guardado")
			end
		end,
	})
	local ctx = Guardado.nuevoContexto({ almacen = almacen, expulsar = function() end })
	datos[clave] = { perfil = {}, sesion = sesionDe(ctx.servidor) }
	local conexion = Perfiles.alSalir:Connect(function(quien, perfil)
		if quien == j and perfil then
			table.insert(orden, "alSalir")
			perfil.estadisticas.pruebaSalida = (perfil.estadisticas.pruebaSalida or 0) + 1
		end
	end)
	Bolsa.vaciar(j)
	Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 10 })
	local dineroEsperado = Economia.dinero(j) + math.floor(10 * Bolsa.multiplicadorDinero(j) + 0.5)
	local marca = (Perfiles.obtener(j).estadisticas.pruebaSalida or 0) + 1
	local exito, escrito = pcall(conContexto, ctx, Guardado.guardarSalida, j)
	conexion:Disconnect()
	local escritoPerfil = datos[clave].perfil
	local bien = exito and escrito == true and table.concat(orden, ",") == "alSalir,guardado"
		and escritoPerfil.estadisticas.pruebaSalida == marca and escritoPerfil.dinero == dineroEsperado
		and datos[clave].sesion == nil and Bolsa.cuenta(j) == 0
	-- Dejar el perfil vivo como estaba (salvo el dinero de la bolsa reciclada)
	Perfiles.obtener(j).estadisticas.pruebaSalida = nil
	Bolsa.vaciar(j)
	return string.format("orden [%s] | escrito=%s: marca=%s (esperada %d), dinero $%s (esperado $%d), sesion soltada=%s, bolsa vacia=%s => %s",
		table.concat(orden, ","), tostring(escrito), tostring(escritoPerfil.estadisticas.pruebaSalida), marca,
		tostring(escritoPerfil.dinero), dineroEsperado, tostring(datos[clave].sesion == nil), tostring(Bolsa.cuenta(j) == 0), ok(bien))
end

return Pruebas
