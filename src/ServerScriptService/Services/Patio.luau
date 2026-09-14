--!strict
--[[
	Patio (ModuleScript)
	Unica responsabilidad: saber quien esta DENTRO del patio de basura y hacer
	visible que va a recoger: brazos extendidos y la bolsa en las manos.

	Se decide en el servidor (posicion del personaje dentro del cuadrado de
	GameConfig.PATIO_LADO) y se publica como atributo EnPatio del Player:
	  - el cliente lo lee para pasar a primera persona y mostrar sus manos;
	  - los demas ven la bolsa porque se suelda aqui, en el servidor.

	La pose de brazos NO se hace aqui: los rigs nuevos usan AnimationConstraint
	(sin C0) y el Animator del cliente pisa cualquier cambio del servidor. Cada
	cliente escribe Transform de los hombros en RunService.Stepped para todos
	los personajes con EnPatio (Escena.client). El servidor solo suelda la
	bolsa (ModelosMascota.bolsaLlena) al torso, que crece con el llenado.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local ModelosMascota = require(Shared:WaitForChild("Utilidades"):WaitForChild("ModelosMascota"))
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
	local mitad = GameConfig.PATIO_LADO / 2
	return math.abs(pos.X) < mitad and math.abs(pos.Z) < mitad
end

local function torsoDe(personaje: Model): BasePart?
	local t = personaje:FindFirstChild("UpperTorso") or personaje:FindFirstChild("Torso")
	return if t and t:IsA("BasePart") then t else nil
end

local function quitarBolsa(personaje: Model)
	local vieja = personaje:FindFirstChild("BolsaEnManos")
	if vieja then
		vieja:Destroy()
	end
end

-- Escala de la bolsa segun llenado. Se reconstruye entera: son 3 partes.
function Patio.actualizarBolsa(jugador: Player)
	local personaje = jugador.Character
	if not personaje or not dentro[jugador] then
		return
	end
	local torso = torsoDe(personaje)
	if not torso then
		return
	end
	quitarBolsa(personaje)
	local fraccion = Bolsa.cuenta(jugador) / math.max(1, Bolsa.capacidad(jugador))
	local bolsa = ModelosMascota.bolsaLlena(fraccion)
	bolsa.Name = "BolsaEnManos"
	for _, p in bolsa:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
		elseif p:IsA("BillboardGui") then
			p:Destroy()
		end
	end
	-- Delante del torso, a la altura de las manos extendidas
	local cf = torso.CFrame * CFrame.new(0, -0.5, -2.2)
	bolsa:PivotTo(cf)
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
end)

Bolsa.alCambiar:Connect(function(jugador)
	Patio.actualizarBolsa(jugador)
end)

return Patio
