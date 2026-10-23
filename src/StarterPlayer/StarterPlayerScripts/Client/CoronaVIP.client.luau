--!strict
--[[
	CoronaVIP
	Unica responsabilidad: la corona VIP sobre la cabeza de quien tiene el
	pase VIP (economia v4, K1 22 oct; docs/Economia-v4.md §5.2). El servidor
	pone el atributo VIP en el Player (Services/Monetizacion) y cada cliente
	pinta, sobre todos los que lo tienen (el propio incluido), un
	BillboardGui con el icono "corona" (Config/Iconos; sin imagen, su glifo)
	y "VIP" (Textos.MUNDO.vip). Es la ventaja que se ve: no va en el chat
	porque en las cuentas Select el chat suele ir apagado (la etiqueta del
	chat, EtiquetaVIP.client, es un extra).

	Cuelga de la cabeza del personaje (se va con el al morir y se rehace en
	CharacterAdded) y es local: el servidor no toca el personaje. En pixeles
	fijos, como el nombre de Roblox, y hasta MAX_DISTANCIA. La propia se
	oculta en primera persona (la camara dentro de la cabeza la veria desde
	abajo, tapando el cielo).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Iconos = require(Config:WaitForChild("Iconos"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Glifos = require(Utilidades:WaitForChild("Glifos"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(Utilidades:WaitForChild("Idioma"))
local Textos = Idioma.textos

local Tema = require(script.Parent:WaitForChild("UI"):WaitForChild("Kit"):WaitForChild("Tema"))

local NOMBRE = "CoronaVIP"
local LADO_ICONO = 46 -- px
local ALTO_TEXTO = 18
local ALTURA = 2.4 -- studs por encima de la cabeza
local MAX_DISTANCIA = 90
-- Camara a menos de esto de la cabeza = primera persona
local DISTANCIA_PRIMERA = 1.6

local yo = Players.LocalPlayer
local conexiones: { [Player]: { RBXScriptConnection } } = {}
local propia: BillboardGui? = nil

local function crearCorona(cabeza: BasePart): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = NOMBRE
	bb.Adornee = cabeza
	bb.Size = UDim2.fromOffset(LADO_ICONO + 24, LADO_ICONO + ALTO_TEXTO)
	bb.StudsOffsetWorldSpace = Vector3.new(0, ALTURA, 0)
	bb.MaxDistance = MAX_DISTANCIA
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.ResetOnSpawn = false
	-- La UI la traduce Idioma, no Roblox
	bb.AutoLocalize = false

	local id = Iconos.id("corona")
	local icono: GuiObject
	if id then
		local imagen = Instance.new("ImageLabel")
		imagen.Image = id
		imagen.BackgroundTransparency = 1
		imagen.ScaleType = Enum.ScaleType.Fit
		icono = imagen
	else
		icono = Glifos.dibujar("corona", LADO_ICONO, Paleta.UI_ORO)
	end
	icono.Name = "Corona"
	icono.Size = UDim2.fromOffset(LADO_ICONO, LADO_ICONO)
	icono.Position = UDim2.new(0.5, 0, 0, 0)
	icono.AnchorPoint = Vector2.new(0.5, 0)
	icono.Parent = bb

	local texto = Instance.new("TextLabel")
	texto.Name = "Texto"
	texto.Size = UDim2.new(1, 0, 0, ALTO_TEXTO)
	texto.Position = UDim2.new(0, 0, 1, 0)
	texto.AnchorPoint = Vector2.new(0, 1)
	texto.BackgroundTransparency = 1
	texto.Text = Textos.MUNDO.vip
	texto.TextColor3 = Paleta.UI_ORO
	texto.TextSize = ALTO_TEXTO
	texto.FontFace = Tema.FUENTE_TITULO
	local contorno = Instance.new("UIStroke")
	contorno.Color = Paleta.UI_TINTA
	contorno.Thickness = 2
	contorno.Parent = texto
	texto.Parent = bb

	bb.Parent = cabeza
	return bb
end

-- Pone o quita la corona segun el atributo y el personaje de ahora
local function actualizar(jugador: Player)
	local personaje = jugador.Character
	local cabeza = personaje and personaje:FindFirstChild("Head")
	local actual = if cabeza then cabeza:FindFirstChild(NOMBRE) else nil
	local quiere = jugador:GetAttribute("VIP") == true and cabeza ~= nil and cabeza:IsA("BasePart")
	if quiere and not actual and cabeza and cabeza:IsA("BasePart") then
		actual = crearCorona(cabeza)
	elseif not quiere and actual then
		actual:Destroy()
		actual = nil
	end
	if jugador == yo then
		propia = if actual and actual:IsA("BillboardGui") then actual else nil
	end
end

local function alPersonaje(jugador: Player, personaje: Model)
	task.spawn(function()
		personaje:WaitForChild("Head", 10)
		if jugador.Character == personaje then
			actualizar(jugador)
		end
	end)
end

local function vigilar(jugador: Player)
	if conexiones[jugador] then
		return
	end
	conexiones[jugador] = {
		jugador.CharacterAdded:Connect(function(personaje)
			alPersonaje(jugador, personaje)
		end),
		jugador:GetAttributeChangedSignal("VIP"):Connect(function()
			actualizar(jugador)
		end),
	}
	if jugador.Character then
		alPersonaje(jugador, jugador.Character)
	end
end

Players.PlayerAdded:Connect(vigilar)
for _, jugador in Players:GetPlayers() do
	vigilar(jugador)
end
Players.PlayerRemoving:Connect(function(jugador)
	for _, c in conexiones[jugador] or {} do
		c:Disconnect()
	end
	conexiones[jugador] = nil
end)

-- La propia, oculta con la camara dentro de la cabeza (ver cabecera)
RunService.RenderStepped:Connect(function()
	local bb = propia
	if not bb then
		return
	end
	local cabeza = bb.Adornee
	local camara = workspace.CurrentCamera
	if cabeza and cabeza:IsA("BasePart") and camara then
		bb.Enabled = (camara.CFrame.Position - cabeza.Position).Magnitude > DISTANCIA_PRIMERA
	end
end)
