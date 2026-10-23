--!strict
--[[
	Patio (ModuleScript)
	Unica responsabilidad: estar en el patio de basura. Quien esta DENTRO,
	que se le vea recoger (brazos extendidos y la bolsa abierta en las
	manos) y con que vista lo mira el (primera o tercera persona: la aplica
	el cliente, aqui solo se guarda en el perfil).

	Se decide en el servidor (posicion del personaje dentro del rectangulo de
	GameConfig.PATIO) y se publica como atributo EnPatio del Player:
	  - el cliente lo lee para pasar a primera persona y mostrar sus manos;
	  - los demas ven la bolsa porque se suelda aqui, en el servidor.

	La pose de brazos (Utilidades/PoseBrazos) se escribe en Transform cada
	Stepped: el Animator la pisaria si se pusiera una sola vez. La escribe
	cada cliente para todos los personajes con EnPatio (Escena.client).
	Transform no se replica, asi que el servidor no la ve: en Studio tambien
	se escribe aqui cada Stepped, porque la vista de servidor de Studio es
	donde el usuario mira su personaje desde fuera; fuera de Studio no la ve
	nadie y no se paga ese bucle por frame (P3, 22 oct). La bolsa
	(ModelosObjetos.bolsaAbierta) se suelda al torso justo entre las manos,
	medidas de verdad con la pose puesta (fuera de Studio se pone un par de
	frames solo para medir, una vez por personaje: el punto no cambia y vale
	para cada bolsa siguiente; la estimacion de PoseBrazos se va casi un
	stud), crece con el llenado y, llena, se cierra con su nudo (las manos la
	cogen entonces por el nudo).

	La vista (CamaraEvent, PatioHandler) va con cooldown: alternarla sin
	parar escribiria el perfil cada vez. La ultima pedida durante el cooldown
	se guarda al acabar: el cliente ya cambio de vista y el perfil no puede
	quedarse con la anterior.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local ModelosObjetos = require(Shared:WaitForChild("Utilidades"):WaitForChild("ModelosObjetos"))
local PoseBrazos = require(Shared:WaitForChild("Utilidades"):WaitForChild("PoseBrazos"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Cosmeticos = require(Servicios:WaitForChild("Cosmeticos"))

local Patio = {}

Patio.alCambiar = Senal.nueva() :: Senal.Senal<Player, boolean>
-- Segundos minimos entre dos escrituras de la vista en el perfil
Patio.COOLDOWN_VISTA = 0.5

local dentro: { [Player]: boolean } = {}

-- Studs que sube la bolsa atada respecto a la abierta (ver colocarBolsa)
local SUBIDA_CERRADA = 0.6

-- El bucle que pone la pose en el servidor cada frame (solo en Studio, ver
-- cabecera; Patio.poseCadaFrame lo enciende y lo apaga)
local conexionPose: RBXScriptConnection? = nil

-- Donde quedan las manos de cada personaje con la pose puesta, en
-- coordenadas del torso: se mide una vez por personaje (ver cabecera)
type Medida = { personaje: Model, torso: BasePart, manos: CFrame }
local medidas: { [Player]: Medida } = {}

function Patio.estaDentro(jugador: Player): boolean
	return dentro[jugador] == true
end

function Patio.posicionEnPatio(pos: Vector3): boolean
	local p = GameConfig.PATIO
	return pos.X > p.oeste and pos.X < p.este and pos.Z > p.norte and pos.Z < p.sur
end

local function quitarBolsa(personaje: Model)
	local vieja = personaje:FindFirstChild("BolsaEnManos")
	if vieja then
		vieja:Destroy()
	end
end

-- Punto medio REAL entre las manos (en coordenadas del torso) una vez puesta
-- la pose: el largo real del brazo depende del avatar (los rig attachments no
-- estan en los extremos de las partes, asi que calcularlo desde los tamanos
-- se va casi un stud). Si las manos aun no estan al frente se usa la
-- estimacion de PoseBrazos. El tercer valor dice si es medida de verdad.
local function puntoManos(personaje: Model): (BasePart?, CFrame?, boolean)
	local torso = personaje:FindFirstChild("UpperTorso") or personaje:FindFirstChild("Torso")
	local derecha = personaje:FindFirstChild("RightHand") or personaje:FindFirstChild("Right Arm")
	local izquierda = personaje:FindFirstChild("LeftHand") or personaje:FindFirstChild("Left Arm")
	if torso and torso:IsA("BasePart") and derecha and derecha:IsA("BasePart") and izquierda and izquierda:IsA("BasePart") then
		-- En R6 la "mano" es el extremo inferior del brazo
		local pd = if derecha.Name == "Right Arm" then (derecha.CFrame * CFrame.new(0, -0.7, 0)).Position else derecha.Position
		local pi = if izquierda.Name == "Left Arm" then (izquierda.CFrame * CFrame.new(0, -0.7, 0)).Position else izquierda.Position
		local medio = torso.CFrame:PointToObjectSpace((pd + pi) / 2)
		if medio.Z < -0.8 then -- ya estan al frente (con la pose puesta)
			return torso, CFrame.new(medio), true
		end
	end
	local torsoEstimado, manosEstimadas = PoseBrazos.puntoManos(personaje)
	return torsoEstimado, manosEstimadas, false
end

-- Las manos del personaje con la pose: la medida guardada o, si no la hay,
-- se mide (fuera de Studio poniendo la pose un par de frames en Stepped,
-- despues del Animator, como el bucle de Studio). Puede ceder.
local function manosDe(jugador: Player, personaje: Model): (BasePart?, CFrame?)
	local medida = medidas[jugador]
	if medida and medida.personaje == personaje and medida.torso.Parent == personaje then
		return medida.torso, medida.manos
	end
	if not conexionPose then
		local conexion = RunService.Stepped:Connect(function()
			PoseBrazos.aplicar(personaje)
		end)
		RunService.Heartbeat:Wait()
		RunService.Heartbeat:Wait()
		conexion:Disconnect()
		-- Cedio: si se fue mientras, no se guarda nada (PlayerRemoving ya
		-- limpio sus medidas)
		if not jugador.Parent then
			return nil, nil
		end
	end
	local torso, manos, medido = puntoManos(personaje)
	if torso and manos and medido then
		medidas[jugador] = { personaje = personaje, torso = torso, manos = manos }
	end
	return torso, manos
end

local function colocarBolsa(jugador: Player)
	local personaje = jugador.Character
	if not personaje or not dentro[jugador] then
		return
	end
	local torso, manos = manosDe(jugador, personaje)
	-- Medir puede haber cedido: sigue siendo el mismo personaje y sigue dentro
	if not torso or not manos or jugador.Character ~= personaje or not dentro[jugador] or torso.Parent ~= personaje then
		return
	end
	quitarBolsa(personaje)
	local fraccion = Bolsa.cuenta(jugador) / math.max(1, Bolsa.capacidad(jugador))
	local bolsa, alto = ModelosObjetos.bolsaAbierta(fraccion)
	ModelosObjetos.vestirBolsa(bolsa, Cosmeticos.puesto(jugador, "bolsa"))
	bolsa.Name = "BolsaEnManos"
	for _, p in bolsa:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
		end
	end
	-- Las manos agarran el borde de la boca: el fondo del saco cuelga debajo.
	-- La atada (llena) va SUBIDA_CERRADA mas arriba (peticion del usuario,
	-- 6 oct): colgada del nudo quedaba demasiado baja
	local subida = if bolsa:FindFirstChild("Nudo") then SUBIDA_CERRADA else 0
	bolsa:PivotTo(torso.CFrame * manos * CFrame.new(0, -alto + 0.25 + subida, 0))
	for _, p in bolsa:GetDescendants() do
		if p:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = torso
			weld.Part1 = p
			weld.Parent = p
		end
	end
	bolsa.Parent = personaje
end

-- Escala de la bolsa segun llenado. Se reconstruye entera (son 3 partes) con
-- un pequeno retraso: al entrar al patio la pose tarda un frame en aplicarse
-- y hay que medir las manos ya puestas; el retraso ademas agrupa varios
-- cambios seguidos de la bolsa en una sola reconstruccion.
local pendientes: { [Player]: boolean } = {}
function Patio.actualizarBolsa(jugador: Player)
	if pendientes[jugador] then
		return
	end
	pendientes[jugador] = true
	task.delay(0.2, function()
		pendientes[jugador] = nil
		colocarBolsa(jugador)
	end)
end

local function poner(jugador: Player)
	Patio.actualizarBolsa(jugador)
end

local function quitar(jugador: Player)
	local personaje = jugador.Character
	if personaje then
		quitarBolsa(personaje)
	end
end

function Patio.fijar(jugador: Player, esta: boolean)
	if dentro[jugador] == esta then
		return
	end
	dentro[jugador] = esta
	jugador:SetAttribute("EnPatio", esta)
	if esta then
		poner(jugador)
	else
		quitar(jugador)
	end
	Patio.alCambiar:Fire(jugador, esta)
end

-- Llamar cada ~0.2 s desde un bucle del servidor
function Patio.actualizar()
	for _, jugador in Players:GetPlayers() do
		local personaje = jugador.Character
		local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			Patio.fijar(jugador, Patio.posicionEnPatio(root.Position))
		end
	end
end

-- Pose de brazos en la vista del servidor cada Stepped (ver cabecera). Por
-- defecto solo en Studio; las pruebas la apagan para probar el camino de un
-- servidor publicado (Antitrampas.poseSinBucle)
function Patio.poseCadaFrame(activa: boolean)
	if activa and not conexionPose then
		conexionPose = RunService.Stepped:Connect(function()
			for jugador, esta in dentro do
				local personaje = jugador.Character
				if esta and personaje then
					PoseBrazos.aplicar(personaje)
				end
			end
		end)
	elseif not activa and conexionPose then
		conexionPose:Disconnect()
		conexionPose = nil
	end
end
Patio.poseCadaFrame(RunService:IsStudio())

-- Para pruebas: si hay medida de las manos del personaje actual del jugador
-- (en coordenadas del torso), o nil si aun no se midio de verdad
function Patio.medidaManos(jugador: Player): CFrame?
	local medida = medidas[jugador]
	return if medida and medida.personaje == jugador.Character then medida.manos else nil
end

-- ===========================================================================
-- La vista en el patio (CamaraEvent)
-- ===========================================================================

type EstadoVista = { ultima: number, pendiente: string? }
local vistas: { [Player]: EstadoVista } = {}

local function guardarVista(jugador: Player, vista: string)
	local perfil = Perfiles.obtener(jugador)
	if perfil and perfil.camara ~= vista then
		perfil.camara = vista
		Perfiles.marcarSucio(jugador)
	end
end

-- "primera" | "tercera" pedida por el cliente: (ok, motivo) con motivo
-- "guardada", "invalida" o "cooldown". Con cooldown no se escribe ya, pero
-- la ultima pedida se guarda al acabar (ver cabecera)
function Patio.elegirVista(jugador: Player, vista: any): (boolean, string)
	if vista ~= "primera" and vista ~= "tercera" then
		return false, "invalida"
	end
	local estado = vistas[jugador]
	if not estado then
		estado = { ultima = -math.huge, pendiente = nil }
		vistas[jugador] = estado
	end
	local espera = estado.ultima + Patio.COOLDOWN_VISTA - os.clock()
	if espera <= 0 then
		estado.ultima = os.clock()
		guardarVista(jugador, vista)
		return true, "guardada"
	end
	local yaProgramada = estado.pendiente ~= nil
	estado.pendiente = vista
	if not yaProgramada then
		task.delay(espera, function()
			local pendiente = estado.pendiente
			estado.pendiente = nil
			if pendiente and vistas[jugador] == estado then
				estado.ultima = os.clock()
				guardarVista(jugador, pendiente)
			end
		end)
	end
	return false, "cooldown"
end

local function engancharPersonaje(jugador: Player)
	jugador.CharacterAdded:Connect(function()
		dentro[jugador] = nil
		medidas[jugador] = nil
		jugador:SetAttribute("EnPatio", false)
	end)
end

Players.PlayerAdded:Connect(engancharPersonaje)
for _, jugador in Players:GetPlayers() do
	engancharPersonaje(jugador)
end
Players.PlayerRemoving:Connect(function(jugador)
	dentro[jugador] = nil
	pendientes[jugador] = nil
	medidas[jugador] = nil
	vistas[jugador] = nil
end)

-- Al cambiar de diseno de bolsa se rehace la que lleva en las manos
Cosmeticos.alCambiar:Connect(function(jugador)
	if dentro[jugador] then
		Patio.actualizarBolsa(jugador)
	end
end)

Bolsa.alCambiar:Connect(function(jugador)
	Patio.actualizarBolsa(jugador)
end)

return Patio
