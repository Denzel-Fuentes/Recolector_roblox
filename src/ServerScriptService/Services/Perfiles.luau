--!strict
--[[
	Perfiles (ModuleScript)
	Unica responsabilidad: el perfil de cada jugador EN MEMORIA y su
	publicacion al cliente. No sabe nada de DataStore: eso es Guardado, que
	llama a registrar() al entrar, lee snapshot() al guardar y quitar() tras
	el guardado de salida.

	=== Dos banderas distintas (leccion de Fly_Roblox) ===

	  cargado    la lectura del DataStore tuvo exito. Solo entonces se puede
	             GUARDAR: escribir un perfil por defecto encima del real seria
	             destruir el progreso. Un perfil no cargado se juega igual, pero
	             Guardado se niega a persistirlo. Se publica en el atributo
	             PerfilListo del Player (nil mientras carga: la pantalla de
	             carga espera a que exista, sea true o false).
	  sucio      hubo cambios desde la ultima publicacion al cliente. Se vacia en
	             el siguiente Heartbeat (maximo 4 envios/s por jugador).

	Se envia el perfil ENTERO cada vez (PerfilEvent): son unos pocos KB y el
	cliente nunca puede quedarse desincronizado por un parche perdido. La
	sesion del bloqueo (Guardado) va en el registro del DataStore, fuera del
	perfil: nunca viaja al cliente.

	Lo que NO esta en el perfil porque no persiste: la bolsa y lo que vuela.

	=== Al salir: alSalir ===
	Guardado dispara alSalir ANTES del guardado de salida (antes se esperaban
	0,2 s a que los demas tocaran el perfil). Quien tenga que dejar algo en el
	perfil al salir (Bolsa recicla lo que llevaba, los rankings publican) se
	conecta aqui y lo hace SIN ceder antes: Senal arranca cada callback en su
	hilo y el guardado empieza en cuanto todos ceden o acaban.

	=== Versiones ===
	v3 (diseno v2, 26 sep): el esquema entero de la v2. v4 (22 oct): store
	nuevo y perfiles desde cero (GameConfig), mas los ajustes de sonido.
	v5 (22 oct, economia v4, docs/Economia-v4.md): el Turbo deja de ser una
	hora de fin (turboHasta, un os.time()) y pasa a los segundos que quedan
	(turboRestante), que solo bajan mientras se juega: la migracion pasa lo
	que quedaba y turboHasta es OBSOLETO. Mas los campos nuevos de abajo.
	`completar` primero MIGRA (MIGRACIONES[v] lleva un perfil de v-1 a v, una
	version tras otra) y despues rellena las claves que falten y borra las
	OBSOLETAS (campos de sistemas quitados: las mascotas el 3 oct, los trajes
	el 5). Rellenar ya cubre los campos nuevos: una migracion solo hace falta
	cuando algo cambia de forma o de sentido.

	=== Campos de la economia v4 (contrato del paquete C3) ===
	Los deja preparados C3 para que E1, R1 y K1 trabajen sin tocar este
	modulo. Los dias son numeros de dia de DefinicionesPedidos.dia (el mismo
	reloj que los pedidos, que con la economia v4 cambia a las 06:00 UTC).
	  turboRestante     s de Turbo (dinero x2) que quedan. Los descuenta
	                    Services/Turbo solo mientras se juega (K1); mientras
	                    no corre, el Player lleva el atributo TurboPausado
	                    (el HUD dice "x2 en pausa")
	  recompensas       R1 (Services/Recompensas):
	    .calendario     siguiente = casilla por cobrar (1..7), vueltas =
	                    semanas completas (tras la 7.a se vuelve a la 1),
	                    ultimoDia = dia de la ultima cobrada (una por dia
	                    jugado; saltarse un dia no reinicia nada)
	    .regalos        dia = el de la cuenta, minutos = minutos activos de
	                    ese dia, cobrados = tramos de REGALOS ya dados ese dia
	    .ultimoDiaJugado  dia del ultimo minuto activo (o del ultimo bono de
	                    regreso): el bono de regreso mira cuanto hace. No es
	                    ultimaSesion, que se escribe al entrar y no al jugar
	  ofertas           K1 (Services/Ofertas): porId[id de la oferta] =
	                    { vistas, ultima (os.time), rechazos } e historial =
	                    os.time() de cada una ensenada (el tope de 3 por
	                    semana; K1 lo recorta a 7 dias)
	  compras           K1: packInicio = ya se dio el Turbo del Pack de inicio
	                    (una sola vez aunque se recargue el perfil);
	                    ultimaRobux = os.time() de la ultima compra con Robux
	                    (24 h sin ofertas). El documento ponia la marca del
	                    pack en recompensas.packOtorgado: es una compra
	  pedidos.lista[i].vip  el 4.o pedido del dia, solo con el pase VIP (K1)
	  estadisticas      claves nuevas (sin entrada = 0): sesiones (la suma
	                    registrar al entrar; las ofertas no salen en la
	                    primera), minutosActivos y diasCalendario (casillas
	                    cobradas: la insignia semanaCompleta) las suma R1
	Y la senal alMinuto: el tic de 60 s de tiempoJugado, por jugador, para
	que R1 cuente ahi los minutos activos. Lo que hace activo un minuto (y
	lo que pausa el Turbo) lo dice Services/Actividad.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local DefinicionesMejoras = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMejoras"))
local DefinicionesRankings = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesRankings"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

-- Pedidos de Dona Chatarra del dia (Services/Pedidos)
export type Pedido = {
	id: string, -- plantilla (Config/DefinicionesPedidos)
	objetivo: number,
	progreso: number,
	parametro: any?, -- material, distancia...
	cobrado: boolean,
	-- $ al cumplirlo, fijado al generarlo. En la economia v4 el premio se
	-- calcula al cobrar (E1); se queda opcional por los pedidos ya guardados
	recompensa: number?,
	vip: boolean?, -- el 4.o pedido del dia, el del pase VIP (ver cabecera)
}

-- Economia v4 (ver cabecera)
export type Recompensas = {
	calendario: { siguiente: number, vueltas: number, ultimoDia: number },
	regalos: { dia: number, minutos: number, cobrados: number },
	ultimoDiaJugado: number,
}
export type Oferta = { vistas: number, ultima: number, rechazos: number }
export type Ofertas = { porId: { [string]: Oferta }, historial: { number } }
export type Compras = { packInicio: boolean, ultimaRobux: number }

export type Perfil = {
	version: number,
	dinero: number,
	mejoras: { [string]: number },
	rebirths: number,
	pedidos: { dia: number, lista: { Pedido }, premioCobrado: boolean },
	racha: number, -- aciertos seguidos al contenedor
	-- Cosmeticos (los de pago se validan contra el pase)
	estela: string?, -- DefinicionesCosmeticos.ESTELAS
	disenoBolsa: string?, -- DefinicionesCosmeticos.BOLSAS
	camara: string?, -- "primera" | "tercera" en el patio (Client/Camara)
	turboRestante: number, -- s de Turbo de dinero que quedan (v5; solo bajan jugando)
	-- OBSOLETO desde v5 (completar lo borra al cargar): la hora de fin del
	-- Turbo antiguo. Sigue en el tipo mientras Services/Turbo lo use (K1 lo
	-- pasa a turboRestante)
	turboHasta: number?,
	-- Pospuesto (GameConfig.FUNCIONES): se guarda para no migrar al volver
	figurinas: { [string]: boolean },
	cintas: { [string]: boolean },
	logros: { [string]: boolean },
	estadisticas: { [string]: number },
	-- Para los rankings semanales (DefinicionesRankings): la semana, la foto de
	-- las estadisticas al empezarla (las sumas se restan) y los maximos de la
	-- semana (la racha no se puede restar)
	semana: { id: number, base: { [string]: number }, maximos: { [string]: number } },
	recibos: { string },
	pasesCache: { [string]: boolean },
	tiempoJugado: number,
	ultimaSesion: number,
	tutorial: number, -- pasos completados (DefinicionesTutorial)
	ajustes: { musica: boolean, efectos: boolean }, -- sonido (v4)
	-- Economia v4 (v5; ver cabecera)
	recompensas: Recompensas,
	ofertas: Ofertas,
	compras: Compras,
}

local Perfiles = {}

-- Datos de sesion que viajan con el snapshot pero NO se guardan (p. ej. si el
-- modo dev de pases esta activo). Lo fija Monetizacion para evitar un require
-- circular.
Perfiles.extrasSnapshot = nil :: ((Player) -> any)?

Perfiles.alCargar = Senal.nueva() :: Senal.Senal<Player, Perfil>
Perfiles.alCambiar = Senal.nueva() :: Senal.Senal<Player, Perfil>
-- Lo dispara Guardado al salir cada jugador, ANTES de su guardado de salida
-- (ver cabecera). El perfil es nil si se fue antes de que cargara.
Perfiles.alSalir = Senal.nueva() :: Senal.Senal<Player, Perfil?>
-- Cada tic de 60 s de tiempoJugado, por jugador con perfil (economia v4: R1
-- cuenta ahi los minutos activos). Cada oyente va en su hilo (Senal)
Perfiles.alMinuto = Senal.nueva() :: Senal.Senal<Player, Perfil>

local perfiles: { [Player]: Perfil } = {}
local cargados: { [Player]: boolean } = {}
local sucios: { [Player]: boolean } = {}
local ultimoEnvio: { [Player]: number } = {}
-- Copia del perfil tal y como llego del DataStore, antes de que registrar lo
-- toque (ultimaSesion, la semana): el bono de regreso mira cuando jugo antes
local anteriores: { [Player]: Perfil } = {}

local function copiaProfunda(valor: any): any
	if typeof(valor) ~= "table" then
		return valor
	end
	local copia = {}
	for clave, v in valor do
		copia[clave] = copiaProfunda(v)
	end
	return copia
end

local PerfilEvent = Red.evento("PerfilEvent")

function Perfiles.porDefecto(): Perfil
	local mejoras = {}
	for _, def in DefinicionesMejoras.LISTA do
		mejoras[def.id] = 0
	end
	return {
		version = GameConfig.VERSION_PERFIL,
		dinero = 0,
		mejoras = mejoras,
		rebirths = 0,
		pedidos = { dia = 0, lista = {}, premioCobrado = false },
		racha = 0,
		estela = nil,
		disenoBolsa = nil,
		turboRestante = 0,
		figurinas = {},
		cintas = {},
		logros = {},
		estadisticas = {},
		semana = { id = 0, base = {}, maximos = {} },
		recibos = {},
		pasesCache = {},
		tiempoJugado = 0,
		ultimaSesion = 0,
		tutorial = 0,
		ajustes = { musica = true, efectos = true },
		recompensas = {
			calendario = { siguiente = 1, vueltas = 0, ultimoDia = 0 },
			regalos = { dia = 0, minutos = 0, cobrados = 0 },
			ultimoDiaJugado = 0,
		},
		ofertas = { porId = {}, historial = {} },
		compras = { packInicio = false, ultimaRobux = 0 },
	}
end

-- Campos de sistemas quitados (las mascotas, 3 oct; los trajes, 5 oct) o
-- sustituidos (turboHasta por turboRestante, v5)
local OBSOLETOS = { "mascotas", "equipadas", "fragmentos", "pityMascotas", "fragmentosLibres", "trajes", "trajePuesto", "turboHasta" }

-- Tablas cuyas claves se completan una a una, a cualquier profundidad (una
-- mejora, un ajuste o un campo de las recompensas nuevo en un perfil que ya
-- tenia la tabla). Las demas tablas son datos del jugador (listas,
-- contadores) y se dejan como estan; dentro de estas, lo que por defecto es
-- una tabla vacia (ofertas.porId, ofertas.historial) tambien es de datos y no
-- hay nada que completar.
local COMPLETAR_POR_CLAVE = { "mejoras", "ajustes", "recompensas", "ofertas", "compras" }

local function completarClaves(destino: { [any]: any }, defecto: { [any]: any })
	for clave, valor in pairs(defecto) do
		local actual = destino[clave]
		if actual == nil then
			destino[clave] = valor
		elseif typeof(actual) == "table" and typeof(valor) == "table" then
			completarClaves(actual, valor)
		end
	end
end

-- MIGRACIONES[v](datos): lleva un perfil de la version v-1 a la v. Solo para
-- lo que cambia de forma o de sentido: los campos nuevos los pone completar.
-- No hay perfiles v3 en el store v4 (empieza de cero), pero la cadena queda
-- lista para la siguiente version y la prueba "migracionPerfil" la recorre.
Perfiles.MIGRACIONES = {
	-- v4: los ajustes de sonido existen y arrancan encendidos
	[4] = function(datos: any)
		if typeof(datos.ajustes) ~= "table" then
			datos.ajustes = { musica = true, efectos = true }
		end
	end,
	-- v5 (economia v4): el Turbo que le quedaba al cargar (turboHasta era la
	-- hora de fin; el tiempo fuera del juego ya corrio) pasa entero a
	-- turboRestante, que desde ahora solo baja jugando. turboHasta lo borra
	-- despues OBSOLETOS
	[5] = function(datos: any)
		local quedaba = math.max(0, (tonumber(datos.turboHasta) or 0) - os.time())
		datos.turboRestante = math.max(0, tonumber(datos.turboRestante) or 0) + quedaba
	end,
} :: { [number]: (datos: any) -> () }

-- Migra (version a version, hasta `hasta`; por defecto VERSION_PERFIL),
-- rellena lo que falte con el perfil por defecto sin tocar lo que ya hay y
-- borra lo OBSOLETO. Un perfil de una version MAS NUEVA (lo escribio un
-- servidor con codigo mas reciente) conserva su version y no se le borra
-- nada (lo que aqui es obsoleto alli puede volver a usarse): solo se
-- rellena para poder jugarlo. Guardado no lo guarda (prepararPerfil).
function Perfiles.completar(datos: any, hasta: number?): Perfil
	local objetivo = hasta or GameConfig.VERSION_PERFIL
	local base = Perfiles.porDefecto()
	if typeof(datos) ~= "table" then
		base.version = objetivo
		return base
	end
	local desde = tonumber(datos.version) or 1
	for v = desde + 1, objetivo do
		local migrar = Perfiles.MIGRACIONES[v]
		if migrar then
			migrar(datos)
		end
		datos.version = v
	end
	if desde <= objetivo then
		for _, clave in OBSOLETOS do
			datos[clave] = nil
		end
	end
	for clave, valorDefecto in pairs(base :: any) do
		local v = datos[clave]
		if v == nil then
			(datos :: any)[clave] = valorDefecto
		elseif typeof(v) == "table" and typeof(valorDefecto) == "table" and table.find(COMPLETAR_POR_CLAVE, clave) then
			completarClaves(v, valorDefecto)
		end
	end
	datos.version = math.max(desde, objetivo)
	return datos :: Perfil
end

-- La semana de los rankings al dia: si empezo otra, la base de las sumas
-- son las estadisticas de ahora y los maximos vuelven a 0. Lo que se gane
-- entre el cambio de semana y la primera llamada cuenta para la anterior
-- (minutos como mucho: la llaman registrar, estadisticaMaxima y Rankings).
function Perfiles.semanaAlDia(perfil: Perfil): { id: number, base: { [string]: number }, maximos: { [string]: number } }
	local id = DefinicionesRankings.semana(os.time())
	if typeof(perfil.semana) ~= "table" or perfil.semana.id ~= id then
		perfil.semana = { id = id, base = table.clone(perfil.estadisticas), maximos = {} }
	end
	return perfil.semana
end

function Perfiles.registrar(jugador: Player, perfil: Perfil, cargado: boolean)
	anteriores[jugador] = copiaProfunda(perfil)
	perfiles[jugador] = perfil
	cargados[jugador] = cargado
	perfil.ultimaSesion = os.time()
	-- Una sesion mas (estadistica sesiones, ver cabecera). Si un provisional
	-- se sustituye por el guardado, cuenta en los dos, pero solo el guardado
	-- persiste: una vez por sesion
	perfil.estadisticas.sesiones = (perfil.estadisticas.sesiones or 0) + 1
	Perfiles.semanaAlDia(perfil)
	sucios[jugador] = true
	jugador:SetAttribute("PerfilListo", cargado)
	Perfiles.alCargar:Fire(jugador, perfil)
end

function Perfiles.obtener(jugador: Player): Perfil?
	return perfiles[jugador]
end

-- El perfil como llego al entrar (antes de que registrar pisara ultimaSesion
-- y pusiera la semana al dia). Copia: cambiarla no toca el perfil vivo.
function Perfiles.anterior(jugador: Player): Perfil?
	return anteriores[jugador]
end

function Perfiles.esperar(jugador: Player, tiempoMax: number?): Perfil?
	local limite = os.clock() + (tiempoMax or 15)
	while not perfiles[jugador] and os.clock() < limite and jugador.Parent do
		task.wait(0.1)
	end
	return perfiles[jugador]
end

function Perfiles.estaCargado(jugador: Player): boolean
	return cargados[jugador] == true
end

-- Un perfil provisional (no se pudo leer el DataStore al entrar) pasa a
-- guardable sin sustituirlo: la carga en segundo plano vio que no habia
-- nada guardado, asi que lo jugado mientras tanto es su partida
function Perfiles.marcarCargado(jugador: Player)
	if not perfiles[jugador] then
		return
	end
	cargados[jugador] = true
	sucios[jugador] = true
	jugador:SetAttribute("PerfilListo", true)
end

function Perfiles.quitar(jugador: Player)
	perfiles[jugador] = nil
	cargados[jugador] = nil
	sucios[jugador] = nil
	ultimoEnvio[jugador] = nil
	anteriores[jugador] = nil
end

function Perfiles.todos(): { [Player]: Perfil }
	return perfiles
end

-- Copia plana para enviar o guardar. El perfil ya es data pura (sin Instances
-- ni funciones), asi que basta con devolverlo; existe como punto unico por si
-- algun dia hay que filtrar campos. La sesion del bloqueo no esta aqui: va en
-- el registro del DataStore, al lado del perfil (Guardado).
function Perfiles.snapshot(perfil: Perfil): Perfil
	return perfil
end

function Perfiles.marcarSucio(jugador: Player)
	if perfiles[jugador] then
		sucios[jugador] = true
	end
end

-- Suma delta a una estadistica y devuelve el valor nuevo.
function Perfiles.estadistica(jugador: Player, clave: string, delta: number): number
	local perfil = perfiles[jugador]
	if not perfil then
		return 0
	end
	local nuevo = (perfil.estadisticas[clave] or 0) + delta
	perfil.estadisticas[clave] = nuevo
	sucios[jugador] = true
	return nuevo
end

-- Fija una estadistica al maximo entre lo que habia y el valor dado.
function Perfiles.estadisticaMaxima(jugador: Player, clave: string, valor: number): number
	local perfil = perfiles[jugador]
	if not perfil then
		return 0
	end
	local semana = Perfiles.semanaAlDia(perfil)
	if valor > (semana.maximos[clave] or 0) then
		semana.maximos[clave] = valor
		sucios[jugador] = true
	end
	local actual = perfil.estadisticas[clave] or 0
	if valor > actual then
		perfil.estadisticas[clave] = valor
		sucios[jugador] = true
		return valor
	end
	return actual
end

function Perfiles.leerEstadistica(jugador: Player, clave: string): number
	local perfil = perfiles[jugador]
	return if perfil then (perfil.estadisticas[clave] or 0) else 0
end

local function publicar(jugador: Player)
	local perfil = perfiles[jugador]
	if not perfil then
		return
	end
	sucios[jugador] = nil
	ultimoEnvio[jugador] = os.clock()
	local extras = if Perfiles.extrasSnapshot then Perfiles.extrasSnapshot(jugador) else nil
	PerfilEvent:FireClient(jugador, Perfiles.snapshot(perfil), cargados[jugador] == true, extras)
	Perfiles.alCambiar:Fire(jugador, perfil)
end

function Perfiles.publicarAhora(jugador: Player)
	publicar(jugador)
end

RunService.Heartbeat:Connect(function()
	local ahora = os.clock()
	for jugador in sucios do
		if not jugador.Parent then
			sucios[jugador] = nil
		elseif ahora - (ultimoEnvio[jugador] or 0) >= 0.25 then
			publicar(jugador)
		end
	end
end)

-- Tiempo jugado: un tick por minuto (y alMinuto, ver arriba)
task.spawn(function()
	while true do
		task.wait(60)
		for jugador, perfil in perfiles do
			perfil.tiempoJugado += 60
			Perfiles.alMinuto:Fire(jugador, perfil)
		end
	end
end)

-- La limpieza al salir la hace Guardado (quitar) DESPUES del guardado de
-- salida, para que el guardado siempre vea el perfil.

return Perfiles
