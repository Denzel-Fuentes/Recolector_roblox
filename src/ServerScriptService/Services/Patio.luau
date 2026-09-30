--!strict
--[[
	Patio (ModuleScript)
	Unica responsabilidad: saber quien esta DENTRO del patio de basura y hacer
	visible que va a recoger: brazos extendidos y la bolsa abierta en las manos.

	Se decide en el servidor (posicion del personaje dentro del rectangulo de
	GameConfig.PATIO) y se publica como atributo EnPatio del Player:
	  - el cliente lo lee para pasar a primera persona y mostrar sus manos;
	  - los demas ven la bolsa porque se suelda aqui, en el servidor.

	La pose de brazos (Utilidades/PoseBrazos) se escribe en Transform cada
	Stepped: el Animator la pisaria si se pusiera una sola vez. La escribe
	cada cliente para todos los personajes con EnPatio (Escena.client) y
	tambien aqui, porque Transform no se replica y la vista de servidor de
	Studio es donde el usuario mira su personaje desde fuera. La bolsa
	(ModelosObjetos.bolsaAbierta) se suelda al torso justo entre las manos,
	medidas de verdad una vez puesta la pose, y crece con el llenado.
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
local Bolsa = require(Servicios:WaitForChild("Bolsa"))

local Patio = {}

Patio.alCambiar = Senal.nueva() :: Senal.Senal<Player, boolean>

local dentro: { [Player]: boolean } = {}

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
-- la pose: el servidor tambien la aplica, y el largo real del brazo depende
-- del avatar (los rig attachments no estan en los extremos de las partes, asi
-- que calcularlo desde los tamanos se va casi un stud). Si aun no hay manos
-- se usa la estimacion de PoseBrazos.
local function puntoManos(personaje: Model): (BasePart?, CFrame?)
	local torso = personaje:FindFirstChild("UpperTorso") or personaje:FindFirstChild("Torso")
	local derecha = personaje:FindFirstChild("RightHand") or personaje:FindFirstChild("Right Arm")
	local izquierda = personaje:FindFirstChild("LeftHand") or personaje:FindFirstChild("Left Arm")
	if torso and torso:IsA("BasePart") and derecha and derecha:IsA("BasePart") and izquierda and izquierda:IsA("BasePart") then
		-- En R6 la "mano" es el extremo inferior del brazo
		local pd = if derecha.Name == "Right Arm" then (derecha.CFrame * CFrame.new(0, -0.7, 0)).Position else derecha.Position
		local pi = if izquierda.Name == "Left Arm" then (izquierda.CFrame * CFrame.new(0, -0.7, 0)).Position else izquierda.Position
		local medio = torso.CFrame:PointToObjectSpace((pd + pi) / 2)
		if medio.Z < -0.8 then -- ya estan al frente (con la pose puesta)
			return torso, CFrame.new(medio)
		end
	end
	return PoseBrazos.puntoManos(personaje)
end

local function colocarBolsa(jugador: Player)
	local personaje = jugador.Character
	if not personaje or not dentro[jugador] then
		return
	end
	local torso, manos = puntoManos(personaje)
	if not torso or not manos then
		return
	end
	quitarBolsa(personaje)
	local fraccion = Bolsa.cuenta(jugador) / math.max(1, Bolsa.capacidad(jugador))
	local bolsa, alto = ModelosObjetos.bolsaAbierta(fraccion)
	bolsa.Name = "BolsaEnManos"
	for _, p in bolsa:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
		end
	end
	-- Las manos agarran el borde de la boca: el fondo del saco cuelga debajo
	bolsa:PivotTo(torso.CFrame * manos * CFrame.new(0, -alto + 0.25, 0))
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

-- Pose de brazos en la vista del servidor (ver cabecera)
RunService.Stepped:Connect(function()
	for jugador, esta in dentro do
		local personaje = jugador.Character
		if esta and personaje then
			PoseBrazos.aplicar(personaje)
		end
	end
end)

local function engancharPersonaje(jugador: Player)
	jugador.CharacterAdded:Connect(function()
		dentro[jugador] = nil
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
end)

Bolsa.alCambiar:Connect(function(jugador)
	Patio.actualizarBolsa(jugador)
end)

return Patio
