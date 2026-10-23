--!strict
--[[
	Movimiento (ModuleScript)
	Unica responsabilidad: darse cuenta de que un personaje se movio mas de
	lo que puede andando (teletransporte, speed hack) y dejarlo
	SOSPECHA_SEGUNDOS sin tocar el patio. Nunca expulsa ni le devuelve a su
	sitio: el movimiento del personaje lo simula su cliente y corregirlo
	desde aqui pelearia con el lag. Lo que si se puede es que no le sirva:
	durante la sospecha ObjetosPatio no le deja recoger, Bolsa no le deja
	entregar a mano, BotinHandler no le deja excavar y Lanzamiento no le deja
	lanzar. Cada sospecha sale en alSospechar, y Analitica la cuenta (evento
	Sospecha, como mucho uno cada SOSPECHA_CADA s por jugador).

	=== Como se mide (falsos positivos) ===
	Cada INTERVALO s (MovimientoHandler) se mira cuanto se movio EN
	HORIZONTAL la raiz de cada personaje desde la muestra anterior, y eso se
	paga de un CREDITO de distancia que se recarga con el tiempo al ritmo
	permitido (la Velocidad efectiva de la mejora x FACTOR_VELOCIDAD) y
	guarda como mucho RAFAGA_SEGUNDOS de ese ritmo. Si no alcanza, sospecha.
	Por credito y no por la velocidad de cada muestra:
	  - lag: con la red atascada el servidor ve al personaje quieto y luego
	    todo el camino de golpe; mientras parecia quieto el credito se lleno
	    y paga el salto. Lo mismo con un servidor que se para unos segundos
	    (la recarga de esa muestra cuenta todo el tiempo que paso);
	  - empujones de la fisica (una pieza de basura que brota debajo y lo
	    lanza unos studs): una rafaga, no un ritmo sostenido.
	Y no se mide:
	  - la vertical: caer de la recicladora o de una montana es rapido y
	    legitimo;
	  - el primer instante de cada personaje (respawn: el nuevo empieza de
	    cero, con el credito lleno) ni a quien esta muerto.

	sospechoso() no se fia solo de la ultima muestra: mide tambien la
	posicion de ESE instante contra el credito (sin tocar nada si no hay
	salto), asi que un teletransporte y una accion en el mismo frame se
	cogen. Hasta el 23 oct pasaban: la muestra llegaba hasta 0,2 s despues.

	Un salto del propio servidor (permitirSalto con su destino: la aparicion,
	las pruebas) no cuenta: se mide desde el destino, con el credito lleno.
	Durante ECO_SEGUNDOS se ignora lo que se vea a menos de RADIO_ECO de donde
	estaba antes del salto: el cliente aun puede mandar alguna posicion de
	antes de enterarse, y el servidor lo veria ir y volver. Hasta el 23 oct
	eran GRACIA_SALTO s sin medir nada (cabia un teletransporte justo detras
	de reaparecer); sin destino sigue siendo asi.

	Margen (23 oct, medido en Studio con la raiz que ve el servidor cada
	0,1 s): andando a 1x hay picos de 1,44x en 0,2 s y 1,23x en 1 s (el
	jitter de la replicacion); sobre una montana recien excavada, 1,75x y
	1,09x; con la navegacion a 2x, 2,34x y 2,14x. FACTOR_VELOCIDAD 1,8 (era
	2,5) con RAFAGA_SEGUNDOS 2,1 (era 1,5): el credito guarda lo mismo que
	antes (3,8 veces la Velocidad: 60 studs a nivel 0, 106 al maximo), asi
	que un salto suelto se coge igual y un atasco de red de unos 4 s andando
	no cuenta, pero el ritmo sostenido baja de 2,5x a 1,8x: un speed hack de
	2,4x se coge en carreras de mas de ~240 studs y uno de 3x en ~150 (antes,
	nunca y en ~360). 1,8 con 3 s se descarto: el credito subia a 86 / 151
	studs y con la Velocidad al maximo se podia saltar del patio al
	contenedor sin que se viera. 1,5 ya marcaba la navegacion a 2x. Andar a
	2x sostenido gasta el credito poco a poco (13 de 60 studs en 400 studs),
	nada en lo que mide un recorrido de este mapa.

	Interruptor: Movimiento.ACTIVO (apagado, nada es sospecha). Los numeros
	son campos del modulo para que las pruebas los puedan medir y cambiar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Senal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Senal"))

local Mejoras = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Mejoras"))

-- Lo que recibe la analitica con cada sospecha
export type DatosSospecha = {
	distancia: number, -- studs en horizontal desde la medida anterior
	segundos: number, -- desde la medida anterior
	velocidad: number, -- distancia / segundos (studs/s)
	limite: number, -- studs/s permitidos sostenidos (Velocidad x FACTOR_VELOCIDAD)
	exceso: number, -- studs que no cubria el credito
	desde: Vector3,
	hasta: Vector3,
	enPatio: boolean, -- atributo EnPatio del jugador (Patio)
}

type Estado = {
	personaje: Model?,
	pos: Vector3?, -- desde donde se mide; nil = la siguiente muestra empieza de cero
	t: number,
	credito: number,
	graciaHasta: number, -- salto del servidor sin destino: hasta aqui no se mide
	origenSalto: Vector3?, -- donde estaba antes del ultimo salto del servidor
	ecoHasta: number, -- hasta aqui, lo que se vea cerca de origenSalto no cuenta
	sospechaHasta: number,
	ultimoAviso: number,
}

local Movimiento = {}

Movimiento.ACTIVO = true
-- Segundos entre muestras (los usa MovimientoHandler)
Movimiento.INTERVALO = 0.2
-- Segundos sin tocar el patio tras la ultima medida imposible
Movimiento.SOSPECHA_SEGUNDOS = 2
-- Veces la Velocidad efectiva que se puede ir sostenido, y segundos de ese
-- ritmo que guarda el credito (la rafaga: lag, empujones). Ver cabecera
Movimiento.FACTOR_VELOCIDAD = 1.8
Movimiento.RAFAGA_SEGUNDOS = 2.1
-- Tras un salto del servidor: segundos y studs alrededor de donde estaba en
-- los que lo que se vea es un eco de antes del salto
Movimiento.ECO_SEGUNDOS = 3
Movimiento.RADIO_ECO = 10
-- Segundos sin medir tras un salto del servidor del que no se sabe el destino
Movimiento.GRACIA_SALTO = 1

-- (jugador, datos) cada vez que empieza (o sigue, cada SOSPECHA_SEGUNDOS) una
-- sospecha: la escucha Analitica
Movimiento.alSospechar = Senal.nueva() :: Senal.Senal<Player, DatosSospecha>

local estados: { [Player]: Estado } = {}

local function estadoDe(jugador: Player): Estado
	local estado = estados[jugador]
	if not estado then
		estado = {
			personaje = nil,
			pos = nil,
			t = 0,
			credito = 0,
			graciaHasta = 0,
			origenSalto = nil,
			ecoHasta = 0,
			sospechaHasta = 0,
			ultimoAviso = -math.huge,
		}
		estados[jugador] = estado
	end
	return estado
end

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- El personaje vivo del jugador y su raiz (nil, nil si no lo hay)
local function raizViva(jugador: Player): (Model?, BasePart?)
	local personaje = jugador.Character
	local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if not personaje or not root or not root:IsA("BasePart") or not humanoide or humanoide.Health <= 0 then
		return nil, nil
	end
	return personaje, root
end

-- Studs/s que puede recorrer sostenidos (la Velocidad efectiva x FACTOR)
function Movimiento.limite(jugador: Player): number
	return Mejoras.valor(jugador, "Velocidad") * Movimiento.FACTOR_VELOCIDAD
end

-- Mide la posicion de ahora contra el credito. `muestra`: la del bucle, que
-- mueve la referencia y recarga; si no (sospechoso), solo mira, y solo toca
-- el estado si encuentra un salto imposible. Devuelve si lo encontro.
local function medir(jugador: Player, estado: Estado, ahora: number, muestra: boolean): boolean
	local personaje, root = raizViva(jugador)
	if not personaje or not root then
		if muestra then
			estado.pos = nil
		end
		return false
	end
	local limite = Movimiento.limite(jugador)
	local tope = limite * Movimiento.RAFAGA_SEGUNDOS
	local pos = root.Position
	local desde = estado.pos
	if estado.personaje ~= personaje or not desde or ahora < estado.graciaHasta then
		-- Personaje nuevo, primera muestra o salto del servidor sin destino
		if muestra then
			estado.personaje = personaje
			estado.pos = pos
			estado.t = ahora
			estado.credito = tope
		end
		return false
	end
	local origen = estado.origenSalto
	if origen and ahora < estado.ecoHasta and horizontal(pos, origen) <= Movimiento.RADIO_ECO then
		return false -- un eco de antes del ultimo salto del servidor
	end
	local segundos = ahora - estado.t
	local distancia = horizontal(pos, desde)
	local resto = math.min(estado.credito, tope) + limite * segundos - distancia
	if resto >= 0 then
		if muestra then
			estado.pos, estado.t, estado.credito = pos, ahora, math.min(resto, tope)
		end
		return false
	end
	-- Sin credito: lo que hiciera ahora no lo alcanzo andando. La referencia
	-- pasa aqui (la siguiente medida no vuelve a cobrar el mismo salto)
	estado.pos, estado.t, estado.credito = pos, ahora, 0
	estado.sospechaHasta = ahora + Movimiento.SOSPECHA_SEGUNDOS
	if ahora - estado.ultimoAviso >= Movimiento.SOSPECHA_SEGUNDOS then
		estado.ultimoAviso = ahora
		Movimiento.alSospechar:Fire(jugador, {
			distancia = distancia,
			segundos = segundos,
			velocidad = if segundos > 0 then distancia / segundos else math.huge,
			limite = limite,
			exceso = -resto,
			desde = desde,
			hasta = pos,
			enPatio = jugador:GetAttribute("EnPatio") == true,
		})
	end
	return true
end

-- El servidor va a mover al personaje a `destino` (la posicion de su raiz:
-- aparicion, pruebas): ese salto no cuenta, y lo de despues se mide desde
-- alli (ver cabecera). Sin destino, `segundos` (GRACIA_SALTO) sin medir.
function Movimiento.permitirSalto(jugador: Player, destino: Vector3?, segundos: number?)
	local estado = estadoDe(jugador)
	local ahora = os.clock()
	local personaje, root = raizViva(jugador)
	estado.origenSalto = if root then root.Position else nil
	estado.ecoHasta = ahora + Movimiento.ECO_SEGUNDOS
	if destino then
		estado.personaje = personaje or jugador.Character
		estado.pos = destino
		estado.t = ahora
		estado.credito = Movimiento.limite(jugador) * Movimiento.RAFAGA_SEGUNDOS
		estado.graciaHasta = 0
	else
		estado.pos = nil
		estado.graciaHasta = ahora + (segundos or Movimiento.GRACIA_SALTO)
	end
end

-- Si ahora mismo no debe tocar el patio: la sospecha de antes o un salto
-- imposible en este mismo instante (ver cabecera)
function Movimiento.sospechoso(jugador: Player): boolean
	if not Movimiento.ACTIVO then
		return false
	end
	local estado = estados[jugador]
	if not estado then
		return false
	end
	local ahora = os.clock()
	if ahora < estado.sospechaHasta then
		return true
	end
	return medir(jugador, estado, ahora, false)
end

function Movimiento.olvidar(jugador: Player)
	estados[jugador] = nil
end

-- Una muestra de todos los personajes (cada INTERVALO s)
function Movimiento.muestrear()
	local ahora = os.clock()
	for _, jugador in Players:GetPlayers() do
		local estado = estadoDe(jugador)
		if not Movimiento.ACTIVO then
			estado.pos = nil
			continue
		end
		medir(jugador, estado, ahora, true)
	end
end

return Movimiento
