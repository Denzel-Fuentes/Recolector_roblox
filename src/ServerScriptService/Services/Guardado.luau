--!strict
--[[
	Guardado (ModuleScript)
	Unica responsabilidad: que el progreso sobreviva a la sesion. Es lo unico
	que habla con el DataStore de perfiles. Perfiles lleva los datos en
	memoria; DataService.server solo conecta los eventos (entrar, salir,
	autoguardado, cierre) con las funciones de aqui.

	=== Las reglas que evitan perder datos ===
	1. TODA llamada al DataStore va en pcall con reintentos
	   (GameConfig.REINTENTOS_DATASTORE) y los fallos se avisan con warn, nunca
	   con error: un DataStore caido no puede impedir jugar.
	2. UN PERFIL QUE NO SE PUDO LEER NUNCA SE GUARDA (Perfiles.estaCargado):
	   escribir el perfil por defecto encima del real seria destruirlo. Se
	   juega con el por defecto, se avisa, y se reintenta cargar en segundo
	   plano; si entra, el perfil real sustituye al provisional.
	3. COLA POR CLAVE: en este servidor nunca hay dos operaciones de la misma
	   clave a la vez (cargar, guardar, liberar van por turno). Lo que se pide
	   guardar mientras otro guardado esta en curso espera y se junta en UNA
	   ronda siguiente, que escribe el estado mas nuevo: el perfil se lee
	   dentro de UpdateAsync, al escribir. El guardado de salida nunca se
	   descarta: espera su turno (antes devolvia false si habia otro).
	4. Al cerrar el servidor (BindToClose) cada jugador que siga sale como si
	   se fuera (Perfiles.alSalir y guardado soltando la sesion; una sola vez
	   aunque luego llegue su PlayerRemoving) y se espera, hasta 25 s, a TODO
	   lo que este en vuelo (enVuelo cuenta cargas, guardados y
	   liberaciones): tambien a lo que ya habia empezado antes del cierre.
	   En Studio, "Stop" vuelve antes de que acabe: el registro se ve al dia
	   unos segundos despues.

	=== Bloqueo de sesion (propio, sin dependencias) ===
	Cada clave guarda un registro
	    { perfil = <Perfil>, sesion = { servidor = <id>, latido = os.time() } }
	La sesion dice que servidor tiene al jugador, y todo se decide DENTRO de
	UpdateAsync (leer y escribir en un paso atomico):
	  - Al cargar: sin sesion, o la nuestra -> se toma. De otro servidor con
	    el latido de hace SESION_CADUCA s o mas -> ese servidor murio sin
	    liberarla: se toma. De otro servidor y viva -> el jugador viene de alli
	    y aun se esta guardando su salida: se reintenta cada SESION_REINTENTO s
	    sin escribir y, pasados SESION_ESPERA_ROBO s, se roba.
	  - Al guardar: si la sesion ya no es la nuestra (otro servidor la robo),
	    NO se escribe y se expulsa al jugador con
	    NOTIFICACIONES.sesionEnOtroServidor en su idioma (Kick solo admite texto
	    plano: se resuelve aqui). Cada escritura renueva el latido; la de
	    salida y la de cierre lo liberan (sesion = nil).
	  - La sesion va al lado del perfil, no dentro: nunca viaja al cliente.
	El id del servidor es game.JobId; en Studio esta vacio y se usa un GUID por
	servidor.

	=== Contexto inyectable ===
	El almacen (un DataStore o cualquier objeto con UpdateAsync), el reloj, la
	espera, la expulsion y los tiempos van en un Contexto. El juego usa el
	principal; las pruebas (PruebasDefinidas/Datos) crean otros con un almacen
	en memoria y claves de prueba, o cambian el principal un momento
	(usarContexto) sin tocar el registro real del jugador.

	En Studio el store lleva "_Studio" (nombreStore). Sin "Enable Studio
	Access to API Services" todo falla con warn y se juega sin guardar: es lo
	esperado.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Idioma = require(Shared:WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Perfiles = require(script.Parent:WaitForChild("Perfiles"))

local NotificacionEvent = Red.evento("NotificacionEvent")

export type Sesion = { servidor: string, latido: number }
export type Registro = { perfil: any, sesion: Sesion? }

-- Lo que devuelve tomarSesion. estado: nueva (no habia nada) | libre (habia
-- perfil y nadie lo tenia) | propia | caducada | robada | error | sinAlmacen
export type Carga = {
	ok: boolean,
	estado: string,
	perfil: any, -- lo guardado (nil si no habia nada)
	ajena: string?, -- el servidor que tenia la sesion (caducada o robada)
	intentos: number,
}

-- Una ronda de guardado: las peticiones que esperaban turno juntas
type Ronda = { motivos: { string }, liberar: boolean, perfil: () -> any, esperando: { thread } }
type Cola = { ocupada: boolean, esperando: { thread }, pendiente: Ronda? }

export type Contexto = {
	almacen: any?, -- DataStore u objeto con UpdateAsync(clave, fn)
	servidor: string,
	reloj: () -> number, -- segundos, como os.time
	espera: (number) -> (),
	expulsar: (Player, string) -> (),
	caduca: number,
	esperaRobo: number,
	reintento: number,
	reintentos: number,
	colas: { [string]: Cola },
	perdidas: { [Player]: boolean }, -- jugadores cuya sesion robo otro servidor
	salidas: { [Player]: boolean }, -- su salida (alSalir + guardado) ya empezo
}

local Guardado = {}

local SERVIDOR = if game.JobId ~= "" then game.JobId else "Studio-" .. HttpService:GenerateGUID(false)

function Guardado.servidor(): string
	return SERVIDOR
end

-- Por UserId, nunca por nombre: el nombre puede cambiar.
function Guardado.claveDe(jugador: Player): string
	return "Perfil_" .. jugador.UserId
end

function Guardado.nombreStore(enStudio: boolean?): string
	local studio = if enStudio == nil then RunService:IsStudio() else enStudio
	return GameConfig.NOMBRE_DATASTORE .. (if studio then "_Studio" else "")
end

-- ===========================================================================
-- Contextos
-- ===========================================================================

function Guardado.nuevoContexto(opciones: { [string]: any }?): Contexto
	local o = opciones or {}
	return {
		almacen = o.almacen,
		servidor = o.servidor or SERVIDOR,
		reloj = o.reloj or os.time,
		espera = o.espera or function(segundos: number)
			task.wait(segundos)
		end,
		expulsar = o.expulsar or function(jugador: Player, texto: string)
			jugador:Kick(texto)
		end,
		caduca = o.caduca or GameConfig.SESION_CADUCA,
		esperaRobo = o.esperaRobo or GameConfig.SESION_ESPERA_ROBO,
		reintento = o.reintento or GameConfig.SESION_REINTENTO,
		reintentos = o.reintentos or GameConfig.REINTENTOS_DATASTORE,
		colas = {},
		perdidas = {},
		salidas = {},
	}
end

-- GetDataStore no falla aunque el acceso a la API este desactivado; el error
-- aparece al leer o escribir. Por eso tambien va con pcall.
local function abrirStore(): any?
	local ok, resultado = pcall(function()
		return DataStoreService:GetDataStore(Guardado.nombreStore())
	end)
	if not ok then
		warn("Guardado: no se pudo abrir el DataStore. La sesion no se guardara. " .. tostring(resultado))
		return nil
	end
	return resultado
end

local principal = Guardado.nuevoContexto({ almacen = abrirStore() })
local actual = principal

-- El contexto con el que trabajan las funciones por jugador
function Guardado.contexto(): Contexto
	return actual
end

-- Cambia el contexto de las funciones por jugador (nil = el principal) y
-- devuelve el que habia. Solo pruebas: lo que ya estaba en vuelo sigue en
-- el suyo.
function Guardado.usarContexto(ctx: Contexto?): Contexto
	local previo = actual
	actual = ctx or principal
	return previo
end

-- ===========================================================================
-- En vuelo (lo que espera el cierre)
-- ===========================================================================

local enVuelo = 0

function Guardado.enVuelo(): number
	return enVuelo
end

-- Espera a que no quede nada en vuelo, como mucho `limite` segundos.
-- Devuelve si termino todo.
function Guardado.esperarTodos(limite: number): boolean
	local fin = os.clock() + limite
	while enVuelo > 0 and os.clock() < fin do
		task.wait(0.1)
	end
	return enVuelo == 0
end

-- ===========================================================================
-- Turnos por clave
-- ===========================================================================

local function colaDe(ctx: Contexto, clave: string): Cola
	local cola = ctx.colas[clave]
	if not cola then
		cola = { ocupada = false, esperando = {}, pendiente = nil }
		ctx.colas[clave] = cola
	end
	return cola
end

local function tomarTurno(cola: Cola)
	if cola.ocupada then
		table.insert(cola.esperando, coroutine.running())
		coroutine.yield()
	else
		cola.ocupada = true
	end
end

-- El turno pasa al siguiente que espera (la cola sigue ocupada) o se libera
local function soltarTurno(ctx: Contexto, clave: string, cola: Cola)
	local siguiente = table.remove(cola.esperando, 1)
	if siguiente then
		task.spawn(siguiente)
		return
	end
	cola.ocupada = false
	if cola.pendiente == nil and ctx.colas[clave] == cola then
		ctx.colas[clave] = nil
	end
end

-- ===========================================================================
-- Registro y reintentos
-- ===========================================================================

-- El registro de una clave tal y como llega del almacen. Un perfil suelto
-- (sin sobre: el formato de antes de la v4) se lee como perfil sin sesion.
local function normalizar(guardado: any): Registro
	if typeof(guardado) ~= "table" then
		return { perfil = nil, sesion = nil }
	end
	if guardado.perfil == nil and guardado.sesion == nil and next(guardado) ~= nil then
		return { perfil = guardado, sesion = nil }
	end
	local s = guardado.sesion
	local sesion: Sesion? = nil
	if typeof(s) == "table" and typeof(s.servidor) == "string" then
		sesion = { servidor = s.servidor, latido = tonumber(s.latido) or 0 }
	end
	return { perfil = guardado.perfil, sesion = sesion }
end

local function conReintentos(ctx: Contexto, descripcion: string, fn: () -> ()): boolean
	local ultimoError: any = nil
	for intento = 1, ctx.reintentos do
		local ok, err = pcall(fn)
		if ok then
			return true
		end
		ultimoError = err
		if intento < ctx.reintentos then
			ctx.espera(1 + intento)
		end
	end
	warn(string.format("Guardado: %s fallo tras %d intentos: %s", descripcion, ctx.reintentos, tostring(ultimoError)))
	return false
end

-- ===========================================================================
-- Cargar: tomar la sesion
-- ===========================================================================

local function cargaFallida(estado: string, intentos: number): Carga
	return { ok = false, estado = estado, perfil = nil, ajena = nil, intentos = intentos }
end

local function tomarSinTurno(ctx: Contexto, clave: string): Carga
	local almacen = ctx.almacen
	if not almacen then
		return cargaFallida("sinAlmacen", 0)
	end
	local fallos, esperado, intentos = 0, 0, 0
	local robar = false
	while true do
		intentos += 1
		local estado: string, perfil: any, ajena: string? = "error", nil, nil
		local ok, err = pcall(function()
			-- La funcion puede correr mas de una vez: lo que cuenta es la ultima
			almacen:UpdateAsync(clave, function(guardado: any): any
				local registro = normalizar(guardado)
				local sesion = registro.sesion
				local ahora = ctx.reloj()
				perfil, ajena = registro.perfil, nil
				if sesion == nil then
					estado = if registro.perfil == nil then "nueva" else "libre"
				elseif sesion.servidor == ctx.servidor then
					estado = "propia"
				else
					ajena = sesion.servidor
					if ahora - sesion.latido >= ctx.caduca then
						estado = "caducada"
					elseif robar then
						estado = "robada"
					else
						estado = "ajena"
						return nil -- no se escribe
					end
				end
				registro.sesion = { servidor = ctx.servidor, latido = ahora }
				return registro
			end)
		end)
		if not ok then
			fallos += 1
			if fallos >= ctx.reintentos then
				warn(string.format("Guardado: leer %s fallo tras %d intentos: %s", clave, fallos, tostring(err)))
				return cargaFallida("error", intentos)
			end
			ctx.espera(1 + fallos)
		elseif estado == "ajena" then
			-- Viva y de otro servidor: esperar sin escribir y, pasado el
			-- plazo, robarla en el siguiente intento
			ctx.espera(ctx.reintento)
			esperado += ctx.reintento
			robar = esperado >= ctx.esperaRobo
		else
			return { ok = true, estado = estado, perfil = perfil, ajena = ajena, intentos = intentos }
		end
	end
end

-- Toma la sesion de `clave` (por turno) y devuelve lo que habia guardado
function Guardado.tomarSesion(ctx: Contexto, clave: string): Carga
	enVuelo += 1
	local cola = colaDe(ctx, clave)
	tomarTurno(cola)
	local exito, carga = pcall(tomarSinTurno, ctx, clave)
	soltarTurno(ctx, clave, cola)
	enVuelo -= 1
	if not exito then
		warn("Guardado: tomarSesion " .. clave .. ": " .. tostring(carga))
		return cargaFallida("error", 0)
	end
	return carga
end

-- Devuelve la sesion de `clave` si sigue siendo nuestra, sin tocar el perfil
-- (un jugador que se fue mientras cargaba)
function Guardado.liberarSesion(ctx: Contexto, clave: string): boolean
	enVuelo += 1
	local cola = colaDe(ctx, clave)
	tomarTurno(cola)
	local exito, ok = pcall(function(): boolean
		local almacen = ctx.almacen
		if not almacen then
			return false
		end
		return conReintentos(ctx, "liberar " .. clave, function()
			almacen:UpdateAsync(clave, function(guardado: any): any
				local registro = normalizar(guardado)
				if not registro.sesion or registro.sesion.servidor ~= ctx.servidor then
					return nil
				end
				registro.sesion = nil
				return registro
			end)
		end)
	end)
	soltarTurno(ctx, clave, cola)
	enVuelo -= 1
	return exito and ok == true
end

-- ===========================================================================
-- Guardar: rondas por turno
-- ===========================================================================

-- (ok, estado): guardada | liberada | perdida (la sesion es de otro) |
-- sinPerfil | error | sinAlmacen
local function ejecutarRonda(ctx: Contexto, clave: string, ronda: Ronda): (boolean, string)
	local almacen = ctx.almacen
	if not almacen then
		return false, "sinAlmacen"
	end
	local estado = "error"
	local escrito = conReintentos(ctx, "guardar " .. clave .. " (" .. table.concat(ronda.motivos, "+") .. ")", function()
		almacen:UpdateAsync(clave, function(guardado: any): any
			local registro = normalizar(guardado)
			local sesion = registro.sesion
			if not sesion or sesion.servidor ~= ctx.servidor then
				estado = "perdida"
				return nil -- no es nuestra: no se escribe
			end
			-- El estado mas nuevo: se lee ahora, no cuando se pidio
			local perfil = ronda.perfil()
			if perfil == nil then
				estado = "sinPerfil"
				return nil
			end
			registro.perfil = perfil
			registro.sesion = if ronda.liberar then nil else { servidor = ctx.servidor, latido = ctx.reloj() }
			estado = if ronda.liberar then "liberada" else "guardada"
			return registro
		end)
	end)
	if not escrito then
		return false, "error"
	end
	return estado == "guardada" or estado == "liberada", estado
end

-- Guarda `clave` con lo que devuelva `perfil` (leido al escribir). Si hay un
-- guardado en curso, espera y se junta con los demas que lleguen mientras en
-- una ronda; liberar = soltar la sesion (salida o cierre), y gana si alguno
-- de la ronda lo pide. Devuelve (escrito, estado) de la ronda que lo cubrio.
function Guardado.escribir(ctx: Contexto, clave: string, perfil: () -> any, motivo: string, liberar: boolean?): (boolean, string)
	enVuelo += 1
	local cola = colaDe(ctx, clave)
	local pendiente = cola.pendiente
	if pendiente then
		table.insert(pendiente.motivos, motivo)
		pendiente.liberar = pendiente.liberar or liberar == true
		pendiente.perfil = perfil
		table.insert(pendiente.esperando, coroutine.running())
		local ok, estado = coroutine.yield()
		enVuelo -= 1
		return ok == true, tostring(estado)
	end
	local ronda: Ronda = { motivos = { motivo }, liberar = liberar == true, perfil = perfil, esperando = {} }
	cola.pendiente = ronda
	tomarTurno(cola)
	cola.pendiente = nil
	local exito, ok, estado = pcall(ejecutarRonda, ctx, clave, ronda)
	if not exito then
		warn("Guardado: guardar " .. clave .. ": " .. tostring(ok))
		ok, estado = false, "error"
	end
	soltarTurno(ctx, clave, cola)
	for _, hilo in ronda.esperando do
		task.spawn(hilo, ok, estado)
	end
	enVuelo -= 1
	return ok == true, tostring(estado)
end

-- ===========================================================================
-- Por jugador
-- ===========================================================================

local cargando: { [Player]: boolean } = {}
local salidos: { [Player]: boolean } = {}

local function seFue(jugador: Player): boolean
	return salidos[jugador] == true or jugador.Parent == nil
end

-- El texto con el que se expulsa a quien abrio su partida en otro servidor,
-- en su idioma (en Studio vale el atributo IdiomaStudio, como en el cliente)
function Guardado.textoExpulsion(jugador: Player): string
	local codigo = jugador.LocaleId
	local forzado = if RunService:IsStudio() then ReplicatedStorage:GetAttribute("IdiomaStudio") else nil
	if typeof(forzado) == "string" then
		codigo = forzado
	end
	return Idioma.resolver(Idioma.mensaje("NOTIFICACIONES.sesionEnOtroServidor"), Idioma.normalizar(codigo))
end

local function guardarJugador(jugador: Player, motivo: string, liberar: boolean): boolean
	local ctx = actual
	if ctx.perdidas[jugador] or not Perfiles.estaCargado(jugador) then
		return false
	end
	-- Con su salida (o la del cierre) ya en marcha, la sesion se suelta: un
	-- autoguardado o un recibo que llegue despues ya no tiene donde escribir
	if ctx.salidas[jugador] and not liberar then
		return false
	end
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false
	end
	local clave = Guardado.claveDe(jugador)
	local ok, estado = Guardado.escribir(ctx, clave, function()
		return Perfiles.snapshot(Perfiles.obtener(jugador) or perfil)
	end, motivo, liberar)
	if estado == "perdida" and not ctx.perdidas[jugador] then
		ctx.perdidas[jugador] = true
		if liberar then
			print(string.format("Guardado: %s salio con la sesion en otro servidor: no se guarda", clave))
		else
			warn(string.format("Guardado: la sesion de %s la tiene otro servidor: no se guarda y se expulsa a %s", clave, jugador.Name))
			if jugador.Parent then
				ctx.expulsar(jugador, Guardado.textoExpulsion(jugador))
			end
		end
	end
	return ok
end

-- Guarda ya el perfil del jugador (por turno). true si quedo escrito con la
-- sesion todavia nuestra. Para lo que no puede esperar al autoguardado (un
-- recibo de Robux).
function Guardado.guardarAhora(jugador: Player, motivo: string): boolean
	return guardarJugador(jugador, motivo, false)
end

local function reintentarCargaEnFondo(jugador: Player)
	local espera = GameConfig.REINTENTO_CARGA_FONDO
	while true do
		task.wait(espera)
		if seFue(jugador) or Perfiles.estaCargado(jugador) then
			return
		end
		local ctx = actual
		local clave = Guardado.claveDe(jugador)
		local carga = Guardado.tomarSesion(ctx, clave)
		if carga.ok then
			if seFue(jugador) then
				Guardado.liberarSesion(ctx, clave)
			else
				-- El real sustituye al provisional, que nunca se guardo
				print("Guardado: " .. clave .. " cargo en segundo plano")
				Perfiles.registrar(jugador, Perfiles.completar(carga.perfil), true)
			end
			return
		end
		espera = math.min(espera * 2, 300)
	end
end

function Guardado.cargar(jugador: Player)
	if cargando[jugador] or Perfiles.obtener(jugador) then
		return
	end
	cargando[jugador] = true
	-- Solo Studio: para probar la pantalla de carga
	if RunService:IsStudio() then
		local lenta = ServerStorage:GetAttribute("SimularCargaLenta")
		if typeof(lenta) == "number" and lenta > 0 then
			task.wait(lenta)
			if seFue(jugador) then
				cargando[jugador] = nil
				return
			end
		end
	end
	local ctx = actual
	local clave = Guardado.claveDe(jugador)
	local carga = Guardado.tomarSesion(ctx, clave)
	cargando[jugador] = nil
	if seFue(jugador) then
		-- Se fue mientras cargaba: la sesion se devuelve para que el
		-- siguiente servidor no tenga que esperar a robarla
		if carga.ok then
			Guardado.liberarSesion(ctx, clave)
		end
		return
	end
	if carga.estado == "caducada" or carga.estado == "robada" then
		print(string.format("Guardado: %s cargo con la sesion %s de %s", clave, carga.estado, tostring(carga.ajena)))
	end
	Perfiles.registrar(jugador, Perfiles.completar(carga.perfil), carga.ok)
	if not carga.ok then
		-- El cliente puede no tener aun la UI: se avisa un poco despues
		task.delay(3, function()
			if not seFue(jugador) then
				NotificacionEvent:FireClient(jugador, Idioma.mensaje("NOTIFICACIONES.perfilNoCargado"), "peligro")
			end
		end)
		if ctx.almacen then
			task.spawn(reintentarCargaEnFondo, jugador)
		end
	end
end

-- Dispara Perfiles.alSalir y guarda soltando la sesion; no quita el perfil
-- de memoria (eso es salir). Separado para la prueba salidaAntesDeGuardar.
function Guardado.guardarSalida(jugador: Player, motivo: string?): boolean
	-- Lo que haya que dejar en el perfil al salir, ANTES de guardarlo: los
	-- callbacks corren hasta que ceden, y no deben ceder antes de tocarlo
	Perfiles.alSalir:Fire(jugador, Perfiles.obtener(jugador))
	return guardarJugador(jugador, motivo or "salida", true)
end

-- La salida de un jugador UNA sola vez por contexto, la pida el cierre o
-- PlayerRemoving (en un cierre los dos llegan, en cualquier orden): si el
-- cierre soltara la sesion antes de que alSalir pasara la bolsa al perfil,
-- ese dinero ya no se podria escribir.
local function salidaUnaVez(ctx: Contexto, jugador: Player, motivo: string)
	if ctx.salidas[jugador] then
		return
	end
	ctx.salidas[jugador] = true
	task.delay(120, function()
		ctx.salidas[jugador] = nil
	end)
	Guardado.guardarSalida(jugador, motivo)
end

function Guardado.salir(jugador: Player)
	local ctx = actual
	salidos[jugador] = true
	task.delay(120, function()
		salidos[jugador] = nil
	end)
	-- Si el cierre ya la empezo, su guardado sigue en vuelo (y el cierre lo
	-- espera): quitar el perfil ya no le afecta, lo leyo al pedirlo
	salidaUnaVez(ctx, jugador, "salida")
	Perfiles.quitar(jugador)
	ctx.perdidas[jugador] = nil
end

function Guardado.autoguardar()
	for jugador in Perfiles.todos() do
		if not seFue(jugador) then
			task.spawn(guardarJugador, jugador, "autoguardado", false)
		end
	end
end

-- BindToClose: cada jugador que siga sale como si se fuera (alSalir y
-- guardado soltando la sesion) y se espera a todo lo que este en vuelo,
-- tambien a lo que ya habia empezado. Devuelve si termino todo a tiempo.
function Guardado.cerrar(limite: number?): boolean
	local ctx = actual
	for jugador in Perfiles.todos() do
		task.spawn(salidaUnaVez, ctx, jugador, "cierre")
	end
	return Guardado.esperarTodos(limite or 25)
end

return Guardado
