--!strict
--[[
	Manos
	La "imagen" de manos extendidas con la bolsa de basura que se ve en primera
	persona dentro del patio (como en KOTAMON). Whitebox: esta dibujada con
	Frames (dos brazos color piel y una bolsa azul redondeada), no con imagenes.

	Se ve solo con EnPatio y sin panel abierto. Se mueve un poco:
	  - balanceo lento continuo (seno),
	  - sacudida corta cada vez que entra algo en la bolsa,
	  - la bolsa crece con el llenado (0.8 -> 1) y sube/vibra al cargar el
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

-- ===========================================================================
-- AJUSTES: todo lo que se ve se calibra aqui (pixeles a 1080p; la UI escala
-- sola con Componentes.pantalla). Y positivo = mas abajo; Y negativo = mas
-- arriba. Guarda el archivo y Rojo lo sincroniza: en Play se ve al instante.
-- ===========================================================================
local AJUSTES = {
	-- Todo el conjunto (manos + bolsa). Subir todo: bajar `alturaConjunto`
	-- (p. ej. -40 lo sube 80 px respecto a 40).
	alturaConjunto = 20, -- px por debajo del borde inferior de la pantalla

	-- La bolsa
	bolsaAncho = 470,
	bolsaAlto = 320, -- mas alto = la boca queda mas arriba
	bolsaSubida = 40, -- px que el fondo de la bolsa queda por encima del conjunto
	bolsaRedondeo = 150, -- radio de las esquinas del saco
	bolsaEscalaVacia = 0.8, -- tamano con la bolsa vacia (1 = llena)
	colorBolsa = Paleta.BOLSA,

	-- La boca (el ovalo abierto)
	bocaAlto = 200, -- alto del ovalo
	bocaAncho = 0.98, -- fraccion del ancho de la bolsa
	bocaDesplazamiento = 30, -- centro del ovalo respecto al borde superior del saco (+ = mas abajo)
	bocaGrosorBorde = 28, -- px del borde claro alrededor del agujero
	colorBorde = Paleta.escalar(Paleta.BOLSA, 1.35),
	colorInterior = Paleta.escalar(Paleta.BOLSA, 0.22), -- el agujero (mas bajo = mas oscuro)

	-- Las manos
	brazoAncho = 100,
	brazoAlto = 350, -- mas alto = las manos llegan mas arriba
	brazoSeparacion = 240, -- px del centro a cada brazo
	brazoBase = 20, -- px que el brazo baja por debajo del conjunto (esconde el corte)
	brazoInclinacion = 22, -- grados hacia el centro
	colorPiel = Paleta.PIEL,
	colorManga = Paleta.gris(90),
}

-- Composicion: la boca de la bolsa es un ovalo grande y oscuro entre las
-- manos, a media altura, como en KOTAMON; las manos van POR DELANTE del
-- borde (ZIndex mayor) agarrandolo.
local ANCHO, ALTO = 700, 420
local raiz = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(ANCHO, ALTO), Position = UDim2.new(0.5, 0, 1, AJUSTES.alturaConjunto), Anchor = Vector2.new(0.5, 1), Transparencia = 1, Nombre = "Raiz" })
raiz.ClipsDescendants = false

local function brazo(nombre: string, lado: number): Frame
	local b = Componentes.marco({ Parent = raiz, Size = UDim2.fromOffset(AJUSTES.brazoAncho, AJUSTES.brazoAlto), Position = UDim2.new(0.5, lado * AJUSTES.brazoSeparacion, 1, AJUSTES.brazoBase), Anchor = Vector2.new(0.5, 1), Color = AJUSTES.colorPiel, Radio = math.floor(AJUSTES.brazoAncho * 0.46), Nombre = nombre })
	b.Rotation = -lado * AJUSTES.brazoInclinacion
	b.ZIndex = 7
	-- Manga
	local manga = Componentes.marco({ Parent = b, Size = UDim2.new(1.15, 0, 0, 90), Position = UDim2.new(0.5, 0, 1, 0), Anchor = Vector2.new(0.5, 1), Color = AJUSTES.colorManga, Radio = 30 })
	manga.ZIndex = 8
	-- Pulgar
	local pulgar = Componentes.marco({ Parent = b, Size = UDim2.fromOffset(30, 56), Position = UDim2.new(if lado < 0 then 1 else 0, if lado < 0 then -6 else 6, 0, 22), Anchor = Vector2.new(0.5, 0), Color = AJUSTES.colorPiel, Radio = 15 })
	pulgar.Rotation = lado * 35
	pulgar.ZIndex = 9
	return b
end

brazo("BrazoIzq", -1)
brazo("BrazoDer", 1)

-- Ovalo: UICorner al 50 % solo da una "pastilla" (semicirculos en los
-- extremos), no una elipse. Se apilan tres pastillas de proporciones
-- distintas centradas: su union se lee como un ovalo.
local function ovalo(padre: Instance, nombre: string, ancho: UDim, alto: number, color: Color3, zindex: number): Frame
	local raizOvalo = Componentes.marco({ Parent = padre, Size = UDim2.new(ancho.Scale, ancho.Offset, 0, alto), Position = UDim2.new(0.5, 0, 0.5, 0), Anchor = Vector2.new(0.5, 0.5), Transparencia = 1, Nombre = nombre })
	raizOvalo.ZIndex = zindex
	for _, capa in { { 1, 0.55 }, { 0.88, 0.8 }, { 0.66, 1 } } do
		local f = Componentes.marco({ Parent = raizOvalo, Size = UDim2.fromScale(capa[1], capa[2]), Position = UDim2.new(0.5, 0, 0.5, 0), Anchor = Vector2.new(0.5, 0.5), Color = color, Radio = 0 })
		f.ZIndex = zindex
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
	end
	return raizOvalo
end

local bolsa = Componentes.marco({ Parent = raiz, Size = UDim2.fromOffset(AJUSTES.bolsaAncho, AJUSTES.bolsaAlto), Position = UDim2.new(0.5, 0, 1, -AJUSTES.bolsaSubida), Anchor = Vector2.new(0.5, 1), Color = AJUSTES.colorBolsa, Radio = AJUSTES.bolsaRedondeo, Nombre = "Bolsa" })
bolsa.ZIndex = 4
-- La boca: borde claro y agujero oscuro, centrados en el borde superior del saco
local boca = Componentes.marco({ Parent = bolsa, Size = UDim2.new(1, 0, 0, AJUSTES.bocaAlto), Position = UDim2.new(0.5, 0, 0, AJUSTES.bocaDesplazamiento), Anchor = Vector2.new(0.5, 0.5), Transparencia = 1, Nombre = "Boca" })
boca.ZIndex = 5
ovalo(boca, "Borde", UDim.new(AJUSTES.bocaAncho, 0), AJUSTES.bocaAlto, AJUSTES.colorBorde, 5)
ovalo(boca, "Interior", UDim.new(AJUSTES.bocaAncho, -AJUSTES.bocaGrosorBorde), AJUSTES.bocaAlto - AJUSTES.bocaGrosorBorde, AJUSTES.colorInterior, 6)
local pliegue = Componentes.marco({ Parent = bolsa, Size = UDim2.new(0.7, 0, 0, 18), Position = UDim2.new(0.5, 0, 0.7, 0), Anchor = Vector2.new(0.5, 0.5), Color = Paleta.escalar(AJUSTES.colorBolsa, 0.8), Radio = 9 })
pliegue.ZIndex = 5
pliegue.Rotation = -6

local ESCALA_BOLSA = Instance.new("UIScale")
ESCALA_BOLSA.Scale = AJUSTES.bolsaEscalaVacia
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
	TweenService:Create(ESCALA_BOLSA, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = AJUSTES.bolsaEscalaVacia + (1 - AJUSTES.bolsaEscalaVacia) * fraccionLlenado() }):Play()
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
	raiz.Position = UDim2.new(0.5, dx, 1, AJUSTES.alturaConjunto + dy)
	raiz.Rotation = math.sin(tiempo * 1.1) * 1.5 - carga * 6
end)
