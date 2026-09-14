--!strict
--[[
	Manos
	La "imagen" de manos extendidas con la bolsa de basura que se ve en primera
	persona dentro del patio (como en KOTAMON). Whitebox: esta dibujada con
	Frames (dos brazos color piel y una bolsa azul redondeada), no con imagenes.

	Se ve solo con EnPatio y sin panel abierto. Se mueve un poco:
	  - balanceo lento continuo (seno),
	  - sacudida corta cada vez que entra algo en la bolsa,
	  - la bolsa crece con el llenado (0.75 -> 1) y sube/vibra al cargar el
	    lanzamiento.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Componentes = require(script.Parent:WaitForChild("Componentes"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local jugador = Players.LocalPlayer

local pantalla = Componentes.pantalla("Manos", 0)

local ANCHO, ALTO = 560, 300
local raiz = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(ANCHO, ALTO), Position = UDim2.new(0.5, 0, 1, 40), Anchor = Vector2.new(0.5, 1), Transparencia = 1, Nombre = "Raiz" })
raiz.ClipsDescendants = false

local function brazo(nombre: string, lado: number): Frame
	local b = Componentes.marco({ Parent = raiz, Size = UDim2.fromOffset(96, 330), Position = UDim2.new(0.5, lado * 215, 1, 40), Anchor = Vector2.new(0.5, 1), Color = Paleta.PIEL, Radio = 44, Nombre = nombre })
	b.Rotation = -lado * 28
	b.ZIndex = 1
	-- Manga
	local manga = Componentes.marco({ Parent = b, Size = UDim2.new(1.15, 0, 0, 90), Position = UDim2.new(0.5, 0, 1, 0), Anchor = Vector2.new(0.5, 1), Color = Paleta.gris(90), Radio = 30 })
	manga.ZIndex = 2
	-- Pulgar
	local pulgar = Componentes.marco({ Parent = b, Size = UDim2.fromOffset(30, 56), Position = UDim2.new(if lado < 0 then 1 else 0, if lado < 0 then -6 else 6, 0, 22), Anchor = Vector2.new(0.5, 0), Color = Paleta.PIEL, Radio = 15 })
	pulgar.Rotation = lado * 35
	pulgar.ZIndex = 3
	return b
end

brazo("BrazoIzq", -1)
brazo("BrazoDer", 1)

local bolsa = Componentes.marco({ Parent = raiz, Size = UDim2.fromOffset(330, 230), Position = UDim2.new(0.5, 0, 1, 30), Anchor = Vector2.new(0.5, 1), Color = Paleta.BOLSA, Radio = 110, Nombre = "Bolsa" })
bolsa.ZIndex = 4
local borde = Componentes.marco({ Parent = bolsa, Size = UDim2.new(0.62, 0, 0, 40), Position = UDim2.new(0.5, 0, 0, -6), Anchor = Vector2.new(0.5, 0), Color = Paleta.escalar(Paleta.BOLSA, 1.35), Radio = 20, Nombre = "Boca" })
borde.ZIndex = 5
local interior = Componentes.marco({ Parent = borde, Size = UDim2.new(1, -14, 1, -12), Position = UDim2.new(0.5, 0, 0.5, 0), Anchor = Vector2.new(0.5, 0.5), Color = Paleta.gris(28), Radio = 16 })
interior.ZIndex = 6
local pliegue = Componentes.marco({ Parent = bolsa, Size = UDim2.new(0.7, 0, 0, 18), Position = UDim2.new(0.5, 0, 0.55, 0), Anchor = Vector2.new(0.5, 0.5), Color = Paleta.escalar(Paleta.BOLSA, 0.8), Radio = 9 })
pliegue.ZIndex = 5
pliegue.Rotation = -6

local ESCALA_BOLSA = Instance.new("UIScale")
ESCALA_BOLSA.Scale = 0.75
ESCALA_BOLSA.Parent = bolsa

local function fraccionLlenado(): number
	local b = EstadoCliente.bolsa
	if b.capacidad <= 0 then
		return 0
	end
	return math.clamp(#b.items / b.capacidad, 0, 1)
end

local function refrescarVisibilidad()
	pantalla.Enabled = jugador:GetAttribute("EnPatio") == true and not Menu.hayAbierto()
end

jugador:GetAttributeChangedSignal("EnPatio"):Connect(refrescarVisibilidad)
Menu.alCambiar:Connect(refrescarVisibilidad)
refrescarVisibilidad()

-- Sacudida al recoger algo y crecimiento con el llenado
local ultimoConteo = 0
local sacudida = 0
EstadoCliente.alCambiarBolsa:Connect(function()
	local n = #EstadoCliente.bolsa.items
	if n > ultimoConteo then
		sacudida = 1
	end
	ultimoConteo = n
	TweenService:Create(ESCALA_BOLSA, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 0.75 + 0.25 * fraccionLlenado() }):Play()
end)

local tiempo = 0
RunService.RenderStepped:Connect(function(dt)
	if not pantalla.Enabled then
		return
	end
	tiempo += dt
	sacudida = math.max(0, sacudida - dt * 4)
	local carga = EstadoCliente.cargaLanzamiento
	local vibracion = if carga > 0 then math.sin(tiempo * 40) * 4 * carga else 0
	local dx = math.sin(tiempo * 1.4) * 7 + vibracion
	local dy = math.cos(tiempo * 2.1) * 5 - math.sin(sacudida * math.pi) * 26 - carga * 40
	raiz.Position = UDim2.new(0.5, dx, 1, 40 + dy)
	raiz.Rotation = math.sin(tiempo * 1.1) * 1.5 - carga * 6
end)
