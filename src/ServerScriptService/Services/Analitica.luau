--!strict
--[[
	Analitica (ModuleScript)
	Unica responsabilidad: contarle a AnalyticsService de Roblox lo que pasa
	en el juego, en tramos que se puedan agregar. No decide nada ni toca el
	perfil: traduce lo que avisan las Senales de los modulos de abajo (el
	cableado esta en AnaliticaHandler).

	Para que: calibrar la economia v4 con los primeros jugadores
	(docs/Economia-v4.md §7: minutos hasta cada rebirth, acierto por
	distancia, de donde sale y a donde va el dinero, en que paso se van).

	=== Que se envia (campos = CustomField01..03) ===
	Embudo de inicio (LogOnboardingFunnelStepEvent), campo: plataforma
	  1 Entrar        al cargar un perfil con el tutorial a 0
	  2..9            los 8 pasos del tutorial (Tutorial.alCompletar); el 9
	                  es el Rebirth 1
	Economia, moneda "Dinero" (LogEconomyEvent, siempre con el saldo final),
	campos: plataforma, rebirths, nivel medio de las mejoras
	  fuente   Gameplay  Deposito_<General|Papel|Plastico|Metal|Organico>
	  fuente   Gameplay  Pedido_<facil|medio|dificil>
	  fuente   Gameplay  Reciclaje_SinBonus (al salir: lo que entro sin
	                     senal en la sesion, ver "Decisiones")
	  sumidero Shop      Mejora_<id>_<nivel>
	  sumidero Gameplay  Rebirth_<n> (todo el dinero que se pierde)
	Progresion (LogProgressionCompleteEvent): ruta "Rebirth", nivel n;
	  campos: plataforma, minutos jugados (tramo), Dinero x2 si/no
	Propios (LogCustomEvent)              valor            campos
	  Acierto         alAcertar          distancia        tramo, contenedor, plataforma
	  Fallo           alFallar           distancia        tramo, contenedor, plataforma
	  Rebirth         alRenacer          minutos jugados  rebirth, plataforma, Dinero x2
	  Insignia        alConseguir        minutos jugados  insignia, plataforma
	  CompraPase      alComprarPase      minutos jugados  pase, plataforma, rebirths
	  CompraProducto  alComprarProducto  minutos jugados  producto, plataforma, rebirths
	  Sesion          alSalir            minutos sesion   plataforma, rebirths, tutorial
	  PerfilNoCargado alCargar sin cargar 1               motivo, plataforma
	  Sospecha        Movimiento.alSospechar (1 cada SOSPECHA_CADA s por jugador)
	                                     studs de exceso  velocidad / limite (tramo), en el patio, plataforma

	=== AnalyticsService nunca rompe el juego ===
	Cada llamada va en pcall: si falla se cuenta y se avisa con warn como
	mucho una vez por minuto (una caida del servicio no puede llenar la
	consola). Lo que se cablea a las Senales va ademas envuelto (protegido):
	un fallo de esta capa es un aviso, nunca un error en el hilo de quien
	disparo la senal. El servicio es sustituible (usarServicio) para la
	prueba analiticaSinServicio.

	=== Studio ===
	Roblox solo recoge eventos del servidor de un juego publicado: desde
	Studio no llega nada al Creator Dashboard. Cada evento queda en
	Analitica.registro (los ultimos MAX_REGISTRO, solo en Studio) para las
	pruebas (PruebasDefinidas/Analitica). En Studio el AnalyticsService de
	verdad acepta las llamadas pero escribe una linea por cada una
	("AnalyticsService: LogEconomyEvent event fired.", medido el 22 oct: 49
	en una tanda de pruebas): por eso ENVIAR_EN_STUDIO va apagado y la
	prueba analiticaEmbudo lo enciende para comprobar las cuatro firmas
	contra el servicio de verdad.

	=== Limites de Roblox (guia "Event types" y la referencia de la clase) ===
	- 120 + 20 x jugadores peticiones por minuto: se cuentan aqui en ventanas
	  de VENTANA s; se descarta lo que pase de FRACCION_LIMITE de ese cupo y
	  lo que pase de MAX_POR_JUGADOR de un mismo jugador (alguien que lanza
	  bolsas de una pieza a quemarropa no puede gastar el cupo de los
	  demas). El embudo y la progresion solo cuentan para el total: son
	  pocos y valen mas.
	- 3 campos propios (solo texto) y 8.000 combinaciones en toda la
	  experiencia: nada de numeros sueltos, todo en tramos (distancia por los
	  tramos del bonus, minutos de 10 en 10 las tres primeras horas, rebirths
	  hasta 10 y "11+", nivel medio 0..10). Entre todos los eventos de aqui
	  salen ~2.500 combinaciones como mucho en teoria (economia ~530,
	  sesion ~520, lanzamientos ~450, progresion ~320, compras ~480...); las
	  que se vean de verdad, muchas menos.
	- 100 nombres de evento propio, 100 sku, 20 tipos de transaccion y 5-10
	  monedas: todo sale de Config (un id desconocido va a "otro") y queda
	  acotado (~70 sku, 9 eventos, 2 tipos, 1 moneda).

	=== Decisiones no obvias ===
	- Roblox desglosa un embudo con los campos de su PRIMER paso: el paso 1
	  espera a la plataforma del cliente (como mucho ESPERA_PLATAFORMA s) y
	  sale siempre antes que el 2. Un paso no se repite por jugador en la
	  sesion (Roblox ignora el repetido, pero gasta cupo); entre sesiones no
	  hace falta: cada paso del tutorial se completa una vez por perfil.
	- Rebirths pone el dinero a 0 antes de avisar: lo que se pierde al
	  renacer es el ultimo saldo visto (cada evento de dinero de aqui y cada
	  publicacion del perfil, Perfiles.alCambiar), y como poco el requisito.
	- Lo que Bolsa recicla sin bonus no avisa (Bolsa.reciclarSinBonus): la
	  bolsa en la mano, las caidas y las que estan en el aire al salir (Bolsa
	  y Lanzamiento.cobrarAlSalir, en alSalir) y la caida mas vieja cuando se
	  pasa del tope de Lanzamiento. Se cuenta al salir (cuadrar, un instante
	  despues de alSalir: task.defer, para ir detras de esos callbacks de la
	  misma senal) como lo que subio dineroGanadoTotal en la sesion menos lo
	  que ya explicaron los depositos y los pedidos de aqui. Una fuente de
	  dinero nueva tiene que pasar por una funcion de aqui que la sume a
	  `contado`; si no, saldra al salir como Reciclaje_SinBonus.
	- LogProgressionCompleteEvent aun no sale en ningun grafico de Roblox: el
	  mismo rebirth va tambien como evento propio "Rebirth" con los minutos
	  jugados de valor (la media por rebirth se ve en Explore).
	- Fallo: alFallar solo dice quien. El origen es donde estaba el jugador
	  cuando su bolsa se vacio (Bolsa.alCambiar, en el mismo instante que el
	  lanzamiento) y el contenedor, el mas cercano a donde cayo la bolsa (la
	  diana junto a la que Lanzamiento la deja): el acierto por tramo se
	  mide igual para los dos. Acierto: Bolsa avisa del deposito (con su
	  contenedor) justo antes que Lanzamiento del acierto. El primer
	  lanzamiento siempre entra: su tramo es "primero", para no inflar el
	  acierto de nadie.
	- La plataforma la manda el cliente una vez (Telemetria.client); aqui se
	  valida (lista blanca, enfriamiento, pocos cambios) y solo sirve para
	  los campos. Nada que llegue del cliente se reenvia a AnalyticsService:
	  un cliente que mienta solo ensucia sus propios datos.
	- tiempoJugado cuenta los minutos con la sesion abierta (tambien parado):
	  los "minutos activos" de la economia v4 llegaran con las recompensas.
	- Sospecha (P3): Movimiento avisa como mucho cada 2 s mientras dura; aqui
	  sale una cada SOSPECHA_CADA s por jugador (lo que importa es cuantos y
	  cuanto se pasan, y un tramposo no debe gastar el cupo). La velocidad
	  va en veces el limite: "<2x" suele ser lag; "10x+", un teletransporte.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local DefinicionesInsignias = require(Config:WaitForChild("DefinicionesInsignias"))
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local DefinicionesPedidos = require(Config:WaitForChild("DefinicionesPedidos"))
local DefinicionesPunteria = require(Config:WaitForChild("DefinicionesPunteria"))
local DefinicionesRebirths = require(Config:WaitForChild("DefinicionesRebirths"))
local DefinicionesTutorial = require(Config:WaitForChild("DefinicionesTutorial"))
local Productos = require(Config:WaitForChild("Productos"))
local Contenedores = require(Shared:WaitForChild("Utilidades"):WaitForChild("Contenedores"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))
local Movimiento = require(Servicios:WaitForChild("Movimiento"))

type Perfil = Perfiles.Perfil
type Flujo = "fuente" | "sumidero"

-- Un evento tal y como se envio (solo en Studio, para las pruebas)
export type Registro = {
	n: number, -- orden: siempre crece (las pruebas miran los de despues de uno)
	tipo: string, -- "embudo" | "economia" | "progresion" | "personalizado"
	usuario: number, -- UserId
	nombre: string, -- el paso, el sku, la ruta o el nombre del evento
	valor: number, -- el numero de paso, la cantidad, el nivel o el valor
	campos: { string }, -- CustomField01..03, en orden
	flujo: string?, -- economia: "fuente" | "sumidero"
	saldo: number?, -- economia: saldo final
	transaccion: string?, -- economia
	ok: boolean, -- llego a AnalyticsService sin error
	motivo: string?, -- si no: el error, o "limite" si se descarto
}

local Analitica = {}

Analitica.MONEDA = "Dinero"
-- El paso 1 del embudo espera a la plataforma del cliente como mucho esto
Analitica.ESPERA_PLATAFORMA = 10
-- Fraccion del cupo de Roblox (120 + 20 por jugador, por minuto) que se usa
Analitica.FRACCION_LIMITE = 0.8
-- Eventos de un jugador por ventana (el embudo y la progresion no cuentan)
Analitica.MAX_POR_JUGADOR = 60
Analitica.VENTANA = 60
-- AnaliticaEvent: un mensaje cada tantos segundos y pocos cambios por sesion
Analitica.ENFRIAMIENTO_CLIENTE = 5
Analitica.MAX_CAMBIOS_PLATAFORMA = 3
Analitica.PLATAFORMAS = { teclado = true, tactil = true, gamepad = true } :: { [string]: boolean }
-- Segundos que se recuerda a un jugador despues de salir (AnaliticaHandler)
Analitica.OLVIDAR_TRAS_SALIR = 30
Analitica.MAX_REGISTRO = 300
-- Como mucho un evento Sospecha por jugador cada tantos segundos
Analitica.SOSPECHA_CADA = 30

-- En Studio, si se llama tambien al AnalyticsService de verdad: no envia
-- nada y escribe una linea por llamada en la consola (ver cabecera), asi
-- que apagado; analiticaEmbudo lo enciende para probar las firmas. Un
-- servicio sustituto (usarServicio) se llama siempre.
Analitica.ENVIAR_EN_STUDIO = false

-- Sustituibles en pruebas
Analitica.servicio = AnalyticsService :: any
Analitica.reloj = os.clock
Analitica.registrando = RunService:IsStudio()
Analitica.registro = {} :: { Registro }

local EN_STUDIO = RunService:IsStudio()

local NOMBRE_ENTRAR = "Entrar"
local SIN_PLATAFORMA = "desconocida"

-- Nombre de un valor de un Enum (los de transaccion y las claves de los
-- campos se pasan como texto); si el Enum no existiera, el nombre a pelo
local function nombreEnum(enumeracion: string, item: string): string
	local ok, nombre = pcall(function()
		return ((Enum :: any)[enumeracion] :: any)[item].Name
	end)
	return if ok and typeof(nombre) == "string" then nombre else item
end

local CLAVES_CAMPO = {
	nombreEnum("AnalyticsCustomFieldKeys", "CustomField01"),
	nombreEnum("AnalyticsCustomFieldKeys", "CustomField02"),
	nombreEnum("AnalyticsCustomFieldKeys", "CustomField03"),
}
local TRANSACCION_JUEGO = nombreEnum("AnalyticsEconomyTransactionType", "Gameplay")
local TRANSACCION_TIENDA = nombreEnum("AnalyticsEconomyTransactionType", "Shop")

local function flujoEnum(flujo: Flujo): any
	local ok, item = pcall(function()
		return if flujo == "fuente" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
	end)
	return if ok then item else nil
end

-- Los contenedores que puede nombrar un sku o un campo (cardinalidad fija)
local CONTENEDORES_VALIDOS: { [string]: boolean } = { General = true }
for _, tipo in GameConfig.TIPOS_BASURA do
	CONTENEDORES_VALIDOS[tipo] = true
end

-- ===========================================================================
-- Estado por jugador (se borra con olvidar)
-- ===========================================================================

local plataformas: { [Player]: string } = {}
local cambiosPlataforma: { [Player]: number } = {}
local ultimoMensaje: { [Player]: number } = {}
local entradas: { [Player]: number } = {} -- reloj() al entrar
local pasosHechos: { [Player]: { [number]: boolean } } = {}
local pendientesEntrar: { [Player]: boolean } = {} -- paso 1 esperando a la plataforma
local saldos: { [Player]: number } = {} -- ultimo saldo visto
-- dineroGanadoTotal al cargar (o en el ultimo cuadre) y lo que explicaron
-- desde entonces los eventos de dinero de aqui (ver cuadrar)
local ganadoInicial: { [Player]: number } = {}
local contado: { [Player]: number } = {}
local ultimasSospechas: { [Player]: number } = {}
local cuentasBolsa: { [Player]: number } = {}
local vaciados: { [Player]: { posicion: Vector3, t: number } } = {} -- donde se vacio la bolsa
local ultimosDepositos: { [Player]: { contenedor: string, t: number } } = {}

-- Cupo (ventanas de VENTANA s)
local porJugador: { [Player]: number } = {}
local ventanaInicio = -math.huge
local enVentana = 0

local contador = 0
local ultimoAviso = -math.huge
-- enviados/fallos: llamadas al servicio; descartados: por el cupo; errores:
-- de esta capa (protegido); rechazados: mensajes de AnaliticaEvent;
-- sinEnviar: en Studio con ENVIAR_EN_STUDIO = false
local estadisticas = { enviados = 0, fallos = 0, descartados = 0, errores = 0, rechazados = 0, sinEnviar = 0 }

-- ===========================================================================
-- Ayudantes
-- ===========================================================================

local function esJugador(jugador: any): boolean
	return typeof(jugador) == "Instance" and jugador:IsA("Player")
end

-- warn como mucho una vez por minuto
local function avisar(texto: string)
	local ahora = os.clock()
	if ahora - ultimoAviso >= 60 then
		ultimoAviso = ahora
		warn("[Analitica] " .. texto .. " (el juego sigue; este aviso sale como mucho una vez por minuto)")
	end
end

-- Envuelve una funcion que se cablea a una Senal: un error dentro es un
-- aviso, no un error en el hilo de quien disparo la senal
local function protegido<A...>(nombre: string, fn: (A...) -> ()): (A...) -> ()
	return function(...: A...)
		local ok, err = pcall(fn, ...)
		if not ok then
			estadisticas.errores += 1
			avisar(nombre .. " fallo: " .. tostring(err))
		end
	end
end

local function aCampos(valores: { string }): { [string]: string }?
	if #valores == 0 then
		return nil
	end
	local campos = {}
	for i, valor in valores do
		if i > #CLAVES_CAMPO then
			break
		end
		campos[CLAVES_CAMPO[i]] = valor
	end
	return campos
end

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function contenedorSeguro(nombre: any): string
	return if typeof(nombre) == "string" and CONTENEDORES_VALIDOS[nombre] then nombre else "otro"
end

local function minutosJugados(perfil: Perfil): number
	return math.floor((tonumber(perfil.tiempoJugado) or 0) / 60 + 0.5)
end

-- ===========================================================================
-- Tramos (para no mandar numeros sueltos a un campo)
-- ===========================================================================

-- Los tramos del bonus por distancia: "<10", "10-19", ..., "45-59", "60+"
function Analitica.tramoDistancia(distancia: number): string
	local tramos = DefinicionesPunteria.BONUS_DISTANCIA
	if #tramos == 0 then
		return "?"
	end
	if distancia < tramos[1].desde then
		return "<" .. tostring(tramos[1].desde)
	end
	for i = #tramos, 1, -1 do
		local desde = tramos[i].desde
		if distancia >= desde then
			local siguiente = tramos[i + 1]
			return if siguiente then string.format("%d-%d", desde, siguiente.desde - 1) else tostring(desde) .. "+"
		end
	end
	return "?"
end

-- Minutos en tramos: de 10 en 10 las tres primeras horas (ahi caen el R1 y
-- el R2 de la economia v4), de 30 en 30 hasta las 10 h, de 2 en 2 horas
-- hasta las 24 h, y "1440+". 40 valores.
function Analitica.tramoMinutos(minutos: number): string
	local m = math.max(0, tonumber(minutos) or 0)
	if m >= 1440 then
		return "1440+"
	end
	local base, paso = 0, 10
	if m >= 600 then
		base, paso = 600, 120
	elseif m >= 180 then
		base, paso = 180, 30
	end
	local desde = base + math.floor((m - base) / paso) * paso
	return string.format("%d-%d", desde, desde + paso)
end

-- 0..10 y "11+"
function Analitica.tramoRebirths(n: number): string
	local r = math.max(0, math.floor(tonumber(n) or 0))
	return if r > 10 then "11+" else tostring(r)
end

function Analitica.plataforma(jugador: Player): string
	return plataformas[jugador] or SIN_PLATAFORMA
end

local function campoPlataforma(jugador: Player): string
	return "Plataforma - " .. Analitica.plataforma(jugador)
end

local function campoRebirths(perfil: Perfil?): string
	return "Rebirths - " .. (if perfil then Analitica.tramoRebirths(perfil.rebirths) else "?")
end

-- La media de los niveles de las 4 mejoras (el "L" del modelo de la v4)
local function campoNivel(perfil: Perfil?): string
	if not perfil then
		return "Nivel - ?"
	end
	local total, cuantas = 0, 0
	for _, def in DefinicionesMejoras.LISTA do
		total += perfil.mejoras[def.id] or 0
		cuantas += 1
	end
	return "Nivel - " .. tostring(if cuantas > 0 then math.floor(total / cuantas) else 0)
end

local function campoDineroX2(jugador: Player): string
	return "DineroX2 - " .. (if Monetizacion.tienePase(jugador, "DineroX2") then "si" else "no")
end

-- "Patio", "Excavar"... (los ids de DefinicionesTutorial)
local function nombrePaso(id: any, indice: number): string
	for _, paso in DefinicionesTutorial.PASOS do
		if paso.id == id then
			return string.upper(string.sub(paso.id, 1, 1)) .. string.sub(paso.id, 2)
		end
	end
	return "Paso" .. tostring(indice)
end

-- ===========================================================================
-- Envio: cupo, pcall y registro
-- ===========================================================================

local function admitir(jugador: Player, prioritario: boolean): boolean
	local ahora = Analitica.reloj()
	if ahora - ventanaInicio >= Analitica.VENTANA then
		ventanaInicio = ahora
		enVentana = 0
		table.clear(porJugador)
	end
	local limite = math.floor(Analitica.FRACCION_LIMITE * (120 + 20 * #Players:GetPlayers()))
	if enVentana >= limite then
		return false
	end
	if not prioritario and (porJugador[jugador] or 0) >= Analitica.MAX_POR_JUGADOR then
		return false
	end
	enVentana += 1
	porJugador[jugador] = (porJugador[jugador] or 0) + 1
	return true
end

local function anotar(entrada: Registro)
	if not Analitica.registrando then
		return
	end
	table.insert(Analitica.registro, entrada)
	while #Analitica.registro > Analitica.MAX_REGISTRO do
		table.remove(Analitica.registro, 1)
	end
end

local function nuevaEntrada(tipo: string, jugador: Player, nombre: string, valor: number, valores: { string }): Registro
	return { n = 0, tipo = tipo, usuario = jugador.UserId, nombre = nombre, valor = valor, campos = table.clone(valores), ok = false }
end

-- Llama a `metodo` de AnalyticsService (o de su sustituto) dentro de pcall
local function llamar(metodo: string, ...: any): (boolean, string?)
	local servicio = Analitica.servicio
	if EN_STUDIO and not Analitica.ENVIAR_EN_STUDIO and servicio == AnalyticsService then
		estadisticas.sinEnviar += 1
		return true, nil
	end
	local ok, err = pcall(function(...: any)
		servicio[metodo](servicio, ...)
	end, ...)
	if ok then
		estadisticas.enviados += 1
		return true, nil
	end
	estadisticas.fallos += 1
	avisar(string.format("AnalyticsService:%s fallo: %s", metodo, tostring(err)))
	return false, tostring(err)
end

local function despachar(jugador: Player, prioritario: boolean, entrada: Registro, metodo: string, ...: any): boolean
	contador += 1
	entrada.n = contador
	if not admitir(jugador, prioritario) then
		estadisticas.descartados += 1
		entrada.motivo = "limite"
		anotar(entrada)
		return false
	end
	local ok, err = llamar(metodo, ...)
	entrada.ok = ok
	entrada.motivo = err
	anotar(entrada)
	return ok
end

-- ===========================================================================
-- Un envio por tipo de evento de AnalyticsService
-- ===========================================================================

-- Paso del embudo de inicio (una vez por jugador y sesion)
function Analitica.embudo(jugador: Player, paso: number, nombre: string): boolean
	if not esJugador(jugador) then
		return false
	end
	local hechos = pasosHechos[jugador]
	if not hechos then
		hechos = {}
		pasosHechos[jugador] = hechos
	end
	paso = math.floor(paso)
	if hechos[paso] then
		return false
	end
	hechos[paso] = true
	local valores = { campoPlataforma(jugador) }
	return despachar(jugador, true, nuevaEntrada("embudo", jugador, nombre, paso, valores),
		"LogOnboardingFunnelStepEvent", jugador, paso, nombre, aCampos(valores))
end

-- Dinero que entra ("fuente") o sale ("sumidero"); saldo = el que queda
function Analitica.economia(jugador: Player, flujo: Flujo, cantidad: number, saldo: number, transaccion: string, sku: string, perfil: Perfil?): boolean
	if not esJugador(jugador) or not (cantidad > 0) then
		return false
	end
	local p = perfil or Perfiles.obtener(jugador)
	local valores = { campoPlataforma(jugador), campoRebirths(p), campoNivel(p) }
	local final = math.max(tonumber(saldo) or 0, 0)
	local entrada = nuevaEntrada("economia", jugador, sku, cantidad, valores)
	entrada.flujo = flujo
	entrada.saldo = final
	entrada.transaccion = transaccion
	return despachar(jugador, false, entrada,
		"LogEconomyEvent", jugador, flujoEnum(flujo), Analitica.MONEDA, cantidad, final, transaccion, sku, aCampos(valores))
end

-- Un nivel completado de una ruta de progresion
function Analitica.progresion(jugador: Player, ruta: string, nivel: number, nombreNivel: string, valores: { string }): boolean
	if not esJugador(jugador) then
		return false
	end
	nivel = math.floor(nivel)
	return despachar(jugador, true, nuevaEntrada("progresion", jugador, ruta, nivel, valores),
		"LogProgressionCompleteEvent", jugador, ruta, nivel, nombreNivel, aCampos(valores))
end

-- Un evento propio con su valor (lo que se agrega: suma, media...)
function Analitica.personalizado(jugador: Player, nombre: string, valor: number, valores: { string }): boolean
	if not esJugador(jugador) then
		return false
	end
	return despachar(jugador, false, nuevaEntrada("personalizado", jugador, nombre, valor, valores),
		"LogCustomEvent", jugador, nombre, valor, aCampos(valores))
end

-- ===========================================================================
-- Plataforma (AnaliticaEvent)
-- ===========================================================================

-- El paso 1 que esperaba a la plataforma sale ya (con la que haya)
local soltarEntrada = protegido("soltarEntrada", function(jugador: Player)
	if pendientesEntrar[jugador] then
		pendientesEntrar[jugador] = nil
		Analitica.embudo(jugador, 1, NOMBRE_ENTRAR)
	end
end)

-- Solo del servidor (el remote pasa por recibirCliente); nil la olvida
function Analitica.fijarPlataforma(jugador: Player, plataforma: string?): boolean
	if not esJugador(jugador) or (plataforma ~= nil and not Analitica.PLATAFORMAS[plataforma]) then
		return false
	end
	plataformas[jugador] = plataforma
	if plataforma then
		soltarEntrada(jugador)
	end
	return true
end

function Analitica.plataformaDe(jugador: Player): string?
	return plataformas[jugador]
end

-- Lo que llega por AnaliticaEvent: ("plataforma", "teclado"|"tactil"|"gamepad").
-- Devuelve (aceptado, motivo). Todo lo demas se ignora sin tocar nada.
function Analitica.recibirCliente(jugador: Player, tipo: any, valor: any): (boolean, string)
	if not esJugador(jugador) then
		return false, "jugador"
	end
	local motivo: string? = nil
	if tipo ~= "plataforma" then
		motivo = "tipo"
	elseif typeof(valor) ~= "string" or not Analitica.PLATAFORMAS[valor] then
		motivo = "valor"
	else
		local ahora = Analitica.reloj()
		if ahora - (ultimoMensaje[jugador] or -math.huge) < Analitica.ENFRIAMIENTO_CLIENTE then
			motivo = "enfriamiento"
		else
			ultimoMensaje[jugador] = ahora
			if plataformas[jugador] == valor then
				return true, "igual"
			elseif (cambiosPlataforma[jugador] or 0) >= Analitica.MAX_CAMBIOS_PLATAFORMA then
				motivo = "maximo"
			else
				cambiosPlataforma[jugador] = (cambiosPlataforma[jugador] or 0) + 1
				Analitica.fijarPlataforma(jugador, valor)
				return true, "ok"
			end
		end
	end
	estadisticas.rechazados += 1
	return false, motivo or "?"
end

-- ===========================================================================
-- Lo que pasa en el juego (cableado en AnaliticaHandler)
-- ===========================================================================

-- Players.PlayerAdded: empieza la sesion
Analitica.entrada = protegido("entrada", function(jugador: Player)
	if esJugador(jugador) and not entradas[jugador] then
		entradas[jugador] = Analitica.reloj()
	end
end)

-- Perfiles.alCargar (puede llegar dos veces: el provisional y el que se
-- recupera en segundo plano)
Analitica.carga = protegido("carga", function(jugador: Player, perfil: Perfil)
	if not esJugador(jugador) or typeof(perfil) ~= "table" then
		return
	end
	Analitica.entrada(jugador)
	saldos[jugador] = perfil.dinero
	ganadoInicial[jugador] = perfil.estadisticas.dineroGanadoTotal or 0
	contado[jugador] = 0
	if not Perfiles.estaCargado(jugador) then
		local nueva = (tonumber(perfil.version) or 0) > GameConfig.VERSION_PERFIL
		Analitica.personalizado(jugador, "PerfilNoCargado", 1, { "Motivo - " .. (if nueva then "versionNueva" else "fallo"), campoPlataforma(jugador) })
	end
	if (perfil.tutorial or 0) ~= 0 or pendientesEntrar[jugador] then
		return
	end
	local hechos = pasosHechos[jugador]
	if hechos and hechos[1] then
		return
	end
	if plataformas[jugador] then
		Analitica.embudo(jugador, 1, NOMBRE_ENTRAR)
	else
		pendientesEntrar[jugador] = true
		task.delay(Analitica.ESPERA_PLATAFORMA, soltarEntrada, jugador)
	end
end)

-- Tutorial.alCompletar: el paso i del tutorial es el i + 1 del embudo
Analitica.pasoTutorial = protegido("pasoTutorial", function(jugador: Player, id: string, indice: number)
	if not esJugador(jugador) then
		return
	end
	local i = math.floor(tonumber(indice) or 0)
	if i < 1 or i > DefinicionesTutorial.TOTAL then
		return
	end
	soltarEntrada(jugador)
	Analitica.embudo(jugador, i + 1, nombrePaso(id, i))
end)

-- Perfiles.alCambiar (cada publicacion, hasta 4/s): el ultimo saldo visto
Analitica.perfilCambio = protegido("perfilCambio", function(jugador: Player, perfil: Perfil)
	if esJugador(jugador) and typeof(perfil) == "table" then
		saldos[jugador] = perfil.dinero
	end
end)

-- Bolsa.alCambiar: al vaciarse (lanzar o entregar) se apunta donde estaba
Analitica.bolsaCambio = protegido("bolsaCambio", function(jugador: Player)
	if not esJugador(jugador) or not jugador.Parent then
		return
	end
	local cuenta = Bolsa.cuenta(jugador)
	local antes = cuentasBolsa[jugador] or 0
	cuentasBolsa[jugador] = cuenta
	if antes > 0 and cuenta == 0 then
		local personaje = jugador.Character
		local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
		if raiz and raiz:IsA("BasePart") then
			vaciados[jugador] = { posicion = raiz.Position, t = Analitica.reloj() }
		end
	end
end)

-- Bolsa.alResumen: cada deposito en un contenedor (a mano o lanzado)
Analitica.deposito = protegido("deposito", function(jugador: Player, resumen: Bolsa.ResumenDeposito)
	if not esJugador(jugador) or typeof(resumen) ~= "table" then
		return
	end
	local contenedor = contenedorSeguro(resumen.contenedor)
	ultimosDepositos[jugador] = { contenedor = contenedor, t = Analitica.reloj() }
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return
	end
	local cantidad = tonumber(resumen.dinero) or 0
	if cantidad > 0 then
		Analitica.economia(jugador, "fuente", cantidad, perfil.dinero, TRANSACCION_JUEGO, "Deposito_" .. contenedor, perfil)
		contado[jugador] = (contado[jugador] or 0) + cantidad
	end
	saldos[jugador] = perfil.dinero
end)

-- Pedidos.alCumplir: el pedido ya esta pagado
Analitica.pedido = protegido("pedido", function(jugador: Player, pedido: Perfiles.Pedido)
	if not esJugador(jugador) or typeof(pedido) ~= "table" then
		return
	end
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return
	end
	local cantidad = tonumber(pedido.recompensa) or 0
	if cantidad > 0 then
		local plantilla = DefinicionesPedidos.POR_ID[if typeof(pedido.id) == "string" then pedido.id else ""]
		local sku = "Pedido_" .. (if plantilla then plantilla.dificultad else "otro")
		Analitica.economia(jugador, "fuente", cantidad, perfil.dinero, TRANSACCION_JUEGO, sku, perfil)
		contado[jugador] = (contado[jugador] or 0) + cantidad
	end
	saldos[jugador] = perfil.dinero
end)

-- Mejoras.alComprar(jugador, id, nivelNuevo): ya esta cobrada
Analitica.mejora = protegido("mejora", function(jugador: Player, id: string, nivel: number)
	if not esJugador(jugador) or typeof(id) ~= "string" or not DefinicionesMejoras.POR_ID[id] then
		return
	end
	local perfil = Perfiles.obtener(jugador)
	local n = math.floor(tonumber(nivel) or 0)
	if not perfil or n < 1 then
		return
	end
	local coste = DefinicionesMejoras.coste(id, n - 1)
	if coste and coste > 0 then
		Analitica.economia(jugador, "sumidero", coste, perfil.dinero, TRANSACCION_TIENDA, string.format("Mejora_%s_%d", id, n), perfil)
	end
	saldos[jugador] = perfil.dinero
end)

-- Rebirths.alRenacer(jugador, rebirths ahora): el dinero ya esta a 0
Analitica.rebirth = protegido("rebirth", function(jugador: Player, n: number)
	if not esJugador(jugador) then
		return
	end
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return
	end
	local numero = math.max(1, math.floor(tonumber(n) or perfil.rebirths))
	local requisito = DefinicionesRebirths.rebirth(numero).requisito
	local perdido = math.max((saldos[jugador] or 0) - perfil.dinero, requisito)
	local sku = "Rebirth_" .. (if numero > 20 then "21+" else tostring(numero))
	Analitica.economia(jugador, "sumidero", perdido, perfil.dinero, TRANSACCION_JUEGO, sku, perfil)
	saldos[jugador] = perfil.dinero
	local minutos = minutosJugados(perfil)
	local plataforma, x2 = campoPlataforma(jugador), campoDineroX2(jugador)
	Analitica.progresion(jugador, "Rebirth", numero, "Rebirth " .. tostring(numero),
		{ plataforma, "Minutos - " .. Analitica.tramoMinutos(minutos), x2 })
	Analitica.personalizado(jugador, "Rebirth", minutos, { "Rebirth - " .. Analitica.tramoRebirths(numero), plataforma, x2 })
end)

-- Lanzamiento.alAcertar(jugador, distancia redondeada, racha)
Analitica.acierto = protegido("acierto", function(jugador: Player, distancia: number, _racha: number)
	if not esJugador(jugador) or not Perfiles.obtener(jugador) then
		return
	end
	local d = math.max(0, math.floor((tonumber(distancia) or 0) + 0.5))
	local ultimo = ultimosDepositos[jugador]
	local contenedor = if ultimo and Analitica.reloj() - ultimo.t < 1 then ultimo.contenedor else "?"
	-- El primero de la vida del perfil entra siempre (Lanzamiento.esPrimero)
	local primero = Perfiles.leerEstadistica(jugador, "lanzamientos") <= 1
	local tramo = if primero then "primero" else Analitica.tramoDistancia(d)
	Analitica.personalizado(jugador, "Acierto", d, { "Distancia - " .. tramo, "Contenedor - " .. contenedor, campoPlataforma(jugador) })
end)

-- Donde esta la ultima bolsa que se le cayo (la de libreEn mas alto)
local function bolsaCaida(jugador: Player): Vector3?
	local libreMejor = -math.huge
	local posicion: Vector3? = nil
	for _, obj in ObjetosPatio.bolsasDe(jugador) do
		local libre = tonumber(obj.item.libreEn) or 0
		if libre > libreMejor then
			libreMejor = libre
			posicion = obj.modelo:GetPivot().Position
		end
	end
	return posicion
end

-- Lanzamiento.alFallar(jugador): la bolsa ya esta en el suelo
Analitica.fallo = protegido("fallo", function(jugador: Player)
	if not esJugador(jugador) or not Perfiles.obtener(jugador) then
		return
	end
	local vaciado = vaciados[jugador]
	vaciados[jugador] = nil
	local origen = if vaciado and Analitica.reloj() - vaciado.t <= GameConfig.VIDA_PROYECTIL + 6 then vaciado.posicion else nil
	local caida = bolsaCaida(jugador)
	local contenedor = if caida then Contenedores.masCercano(caida) else nil
	local distancia: number? = nil
	if contenedor and origen then
		distancia = math.floor(horizontal(origen, contenedor.zona.Position) + 0.5)
	end
	Analitica.personalizado(jugador, "Fallo", distancia or 0, {
		"Distancia - " .. (if distancia then Analitica.tramoDistancia(distancia) else "?"),
		"Contenedor - " .. (if contenedor then contenedorSeguro(contenedor.material or "General") else "?"),
		campoPlataforma(jugador),
	})
end)

-- Insignias.alConseguir(jugador, id)
Analitica.insignia = protegido("insignia", function(jugador: Player, id: string)
	local perfil = if esJugador(jugador) then Perfiles.obtener(jugador) else nil
	if not perfil then
		return
	end
	local nombre = if typeof(id) == "string" and DefinicionesInsignias.POR_ID[id] then id else "otro"
	Analitica.personalizado(jugador, "Insignia", minutosJugados(perfil), { "Insignia - " .. nombre, campoPlataforma(jugador) })
end)

-- Monetizacion.alComprarPase(jugador, id del pase)
Analitica.compraPase = protegido("compraPase", function(jugador: Player, id: string)
	local perfil = if esJugador(jugador) then Perfiles.obtener(jugador) else nil
	if not perfil then
		return
	end
	local nombre = if typeof(id) == "string" and Productos.PASE_POR_ID[id] then id else "otro"
	Analitica.personalizado(jugador, "CompraPase", minutosJugados(perfil), { "Pase - " .. nombre, campoPlataforma(jugador), campoRebirths(perfil) })
end)

-- Monetizacion.alComprarProducto(jugador, id del producto)
Analitica.compraProducto = protegido("compraProducto", function(jugador: Player, id: string)
	local perfil = if esJugador(jugador) then Perfiles.obtener(jugador) else nil
	if not perfil then
		return
	end
	local nombre = if typeof(id) == "string" and Productos.PRODUCTO_POR_ID[id] then id else "otro"
	Analitica.personalizado(jugador, "CompraProducto", minutosJugados(perfil), { "Producto - " .. nombre, campoPlataforma(jugador), campoRebirths(perfil) })
end)

-- Lo que subio dineroGanadoTotal desde la carga (o el ultimo cuadre) sin
-- que lo explicara un evento de aqui: lo que Bolsa recicla sin bonus (ver
-- cabecera). Sale como fuente Reciclaje_SinBonus y empieza otra cuenta. Lo
-- llama la salida, diferido; las pruebas, para empezar de cero.
Analitica.cuadrar = protegido("cuadrar", function(jugador: Player, perfil: Perfil)
	if not esJugador(jugador) or typeof(perfil) ~= "table" then
		return
	end
	local total = perfil.estadisticas.dineroGanadoTotal or 0
	local inicial = ganadoInicial[jugador]
	if inicial then
		local suelto = total - inicial - (contado[jugador] or 0)
		if suelto > 0 then
			Analitica.economia(jugador, "fuente", suelto, perfil.dinero, TRANSACCION_JUEGO, "Reciclaje_SinBonus", perfil)
		end
	end
	ganadoInicial[jugador] = total
	contado[jugador] = 0
end)

-- Velocidad de una sospecha en veces el limite (4 tramos)
local function tramoExceso(velocidad: number, limite: number): string
	local veces = if limite > 0 then velocidad / limite else math.huge
	if veces ~= veces then
		veces = math.huge
	end
	return if veces < 2 then "<2x" elseif veces < 5 then "2-5x" elseif veces < 10 then "5-10x" else "10x+"
end

-- Movimiento.alSospechar(jugador, datos): se movio mas de lo que puede
-- andando. Una cada SOSPECHA_CADA s por jugador (ver cabecera).
Analitica.sospecha = protegido("sospecha", function(jugador: Player, datos: Movimiento.DatosSospecha)
	if not esJugador(jugador) or typeof(datos) ~= "table" then
		return
	end
	local ahora = Analitica.reloj()
	if ahora - (ultimasSospechas[jugador] or -math.huge) < Analitica.SOSPECHA_CADA then
		return
	end
	ultimasSospechas[jugador] = ahora
	local exceso = math.floor((tonumber(datos.exceso) or 0) + 0.5)
	if exceso ~= exceso then
		exceso = 0
	end
	Analitica.personalizado(jugador, "Sospecha", math.clamp(exceso, 0, 100000), {
		"Exceso - " .. tramoExceso(tonumber(datos.velocidad) or 0, tonumber(datos.limite) or 0),
		"EnPatio - " .. (if datos.enPatio == true then "si" else "no"),
		campoPlataforma(jugador),
	})
end)

-- Perfiles.alSalir(jugador, perfil o nil si se fue antes de cargar). No
-- olvida al jugador: lo hace AnaliticaHandler un rato despues.
Analitica.salida = protegido("salida", function(jugador: Player, perfil: Perfil?)
	if not esJugador(jugador) then
		return
	end
	soltarEntrada(jugador)
	local inicio = entradas[jugador]
	local segundos = if inicio then Analitica.reloj() - inicio elseif perfil then os.time() - perfil.ultimaSesion else 0
	local minutos = math.floor(math.max(segundos, 0) / 6 + 0.5) / 10
	local rebirths = if perfil then campoRebirths(perfil) else "Rebirths - sinPerfil"
	local tutorial = if perfil
		then "Tutorial - " .. tostring(math.clamp(math.floor(perfil.tutorial or 0), 0, DefinicionesTutorial.TOTAL))
		else "Tutorial - sinPerfil"
	Analitica.personalizado(jugador, "Sesion", minutos, { campoPlataforma(jugador), rebirths, tutorial })
	if perfil then
		-- Detras de lo que Bolsa y Lanzamiento cobran en esta misma senal
		task.defer(Analitica.cuadrar, jugador, perfil)
	end
end)

-- ===========================================================================
-- Limpieza y pruebas
-- ===========================================================================

function Analitica.olvidar(jugador: Player)
	plataformas[jugador] = nil
	cambiosPlataforma[jugador] = nil
	ultimoMensaje[jugador] = nil
	entradas[jugador] = nil
	pasosHechos[jugador] = nil
	pendientesEntrar[jugador] = nil
	saldos[jugador] = nil
	ganadoInicial[jugador] = nil
	contado[jugador] = nil
	ultimasSospechas[jugador] = nil
	cuentasBolsa[jugador] = nil
	vaciados[jugador] = nil
	ultimosDepositos[jugador] = nil
	porJugador[jugador] = nil
end

-- Cambia el servicio (nil = AnalyticsService) y devuelve el que habia
function Analitica.usarServicio(servicio: any?): any
	local previo = Analitica.servicio
	Analitica.servicio = if servicio ~= nil then servicio else AnalyticsService
	return previo
end

-- Vacia las ventanas del cupo (las pruebas no deben chocar con el de antes)
function Analitica.reiniciarLimites()
	ventanaInicio = -math.huge
	enVentana = 0
	table.clear(porJugador)
end

-- El numero del ultimo evento (para mirar despues los que vengan)
function Analitica.contador(): number
	return contador
end

-- Los eventos registrados despues del numero n, en orden
function Analitica.desde(n: number): { Registro }
	local lista = {}
	for _, entrada in Analitica.registro do
		if entrada.n > n then
			table.insert(lista, entrada)
		end
	end
	return lista
end

function Analitica.estado(): typeof(estadisticas)
	return table.clone(estadisticas)
end

return Analitica
