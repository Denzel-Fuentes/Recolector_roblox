--!strict
--[[
	Movimiento (ModuleScript)
	Unica responsabilidad: darse cuenta de que un personaje se movio mas de
	lo que puede andando (teletransporte, speed hack) y dejarlo
	SOSPECHA_SEGUNDOS sin tocar el patio. Nunca expulsa ni le devuelve a su
	sitio: el movimiento del personaje lo simula su cliente y corregirlo
	desde aqui pelearia con el lag. Lo que si se puede es que no le sirva:
	durante la sospecha ObjetosPatio no le deja recoger, BotinHandler no le
	deja excavar y Lanzamiento no le deja lanzar. Y se publica
	(alSospechar) para la analitica.

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
	    cero, con el credito lleno) ni a quien esta muerto;
	  - durante GRACIA_SALTO s tras un teletransporte del propio servidor
	    (permitirSalto: la aparicion, las pruebas). Es una ventana y no un
	    reinicio de una vez porque el cliente aun puede mandar alguna
	    posicion de antes del salto, y el servidor la veria ir y volver.
	Margen elegido: hasta 2,5 veces la velocidad de andar sostenida nunca es
	sospecha (40 studs/s con la Velocidad a 0, 70 al maximo), ni un salto
	suelto de hasta 1,5 s de ese ritmo (60 / 105 studs). Lo que se coge es lo
	grosero: cruzar el mapa de un salto, correr a 5x. Un tramposo fino no
	gana casi nada y un jugador con lag no paga nada.

	alSospechar(jugador, datos) sale como mucho una vez cada
	SOSPECHA_SEGUNDOS por jugador mientras dure (no una por muestra).
	Interruptor: Movimiento.ACTIVO (apagado, nada es sospecha).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Senal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Senal"))

local Mejoras = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Mejoras"))

-- Lo que recibe la analitica con cada sospecha
export type DatosSospecha = {
	distancia: number, -- studs en horizontal entre las dos muestras
	segundos: number, -- entre las dos muestras
	velocidad: number, -- distancia / segundos (studs/s)
	limite: number, -- studs/s permitidos sostenidos (Velocidad x FACTOR_VELOCIDAD)
	exceso: number, -- studs que no cubria el credito
	desde: Vector3,
	hasta: Vector3,
	enPatio: boolean, -- atributo EnPatio del jugador (Patio)
}

type Estado = {
	personaje: Model?,
	pos: Vector3?, -- nil = la siguiente muestra empieza de cero
	t: number,
	credito: number,
	graciaHasta: number,
	sospechaHasta: number,
	ultimoAviso: number,
}

local Movimiento = {}

Movimiento.ACTIVO = true
-- Segundos entre muestras (los usa MovimientoHandler)
Movimiento.INTERVALO = 0.2
-- Segundos sin tocar el patio tras la ultima muestra imposible
Movimiento.SOSPECHA_SEGUNDOS = 2
-- Segundos que no se mide tras un salto del servidor (permitirSalto)
Movimiento.GRACIA_SALTO = 1

-- (jugador, datos) cada vez que empieza (o sigue, cada SOSPECHA_SEGUNDOS) una
-- sospecha: la escucha la analitica
Movimiento.alSospechar = Senal.nueva() :: Senal.Senal<Player, DatosSospecha>

local FACTOR_VELOCIDAD = 2.5
local RAFAGA_SEGUNDOS = 1.5

local estados: { [Player]: Estado } = {}

local function estadoDe(jugador: Player): Estado
	local estado = estados[jugador]
	if not estado then
		estado = { personaje = nil, pos = nil, t = 0, credito = 0, graciaHasta = 0, sospechaHasta = 0, ultimoAviso = -math.huge }
		estados[jugador] = estado
	end
	return estado
end

-- Studs/s que puede recorrer sostenidos (la Velocidad efectiva x 2,5)
function Movimiento.limite(jugador: Player): number
	return Mejoras.valor(jugador, "Velocidad") * FACTOR_VELOCIDAD
end

-- El servidor va a mover al personaje (aparicion, pruebas): ese salto y lo
-- que se vea durante `segundos` no cuentan
function Movimiento.permitirSalto(jugador: Player, segundos: number?)
	local estado = estadoDe(jugador)
	estado.graciaHasta = os.clock() + (segundos or Movimiento.GRACIA_SALTO)
	estado.pos = nil
end

-- Si ahora mismo no debe tocar el patio (ver cabecera)
function Movimiento.sospechoso(jugador: Player): boolean
	local estado = estados[jugador]
	return Movimiento.ACTIVO and estado ~= nil and os.clock() < estado.sospechaHasta
end

function Movimiento.olvidar(jugador: Player)
	estados[jugador] = nil
end

-- Una muestra de todos los personajes (cada INTERVALO s)
function Movimiento.muestrear()
	local ahora = os.clock()
	for _, jugador in Players:GetPlayers() do
		local estado = estadoDe(jugador)
		local personaje = jugador.Character
		local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
		local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
		if not Movimiento.ACTIVO or not personaje or not root or not root:IsA("BasePart") or not humanoide or humanoide.Health <= 0 then
			estado.pos = nil
			continue
		end
		local limite = Movimiento.limite(jugador)
		local tope = limite * RAFAGA_SEGUNDOS
		local pos = root.Position
		local desde = estado.pos
		if estado.personaje ~= personaje or not desde or ahora < estado.graciaHasta then
			-- Personaje nuevo, primera muestra o salto del servidor: de cero
			estado.personaje = personaje
			estado.pos = pos
			estado.t = ahora
			estado.credito = tope
			continue
		end
		local segundos = ahora - estado.t
		local distancia = Vector3.new(pos.X - desde.X, 0, pos.Z - desde.Z).Magnitude
		estado.pos, estado.t = pos, ahora
		local resto = math.min(estado.credito, tope) + limite * segundos - distancia
		if resto >= 0 then
			estado.credito = math.min(resto, tope)
			continue
		end
		-- Sin credito: lo que hiciera ahora no lo alcanzo andando
		estado.credito = 0
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
	end
end

return Movimiento
