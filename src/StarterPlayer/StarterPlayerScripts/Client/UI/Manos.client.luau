--!strict
--[[
	Manos
	La "imagen" de manos extendidas con la bolsa de basura que se ve en primera
	persona dentro del patio (como en KOTAMON).

	Dos versiones, y elige sola:
	  - Con arte (Config/Iconos manosVacia / manosMedia / manosLlena con id):
	    la ilustracion en un ImageLabel anclado abajo-centro; el estado cambia
	    con el llenado de la bolsa (<1/3 vacia, <2/3 media, resto llena) con un
	    fundido. Si solo hay `manosVacia`, esa imagen crece con el llenado.
	  - Sin arte: dibujada con Frames (dos brazos color piel y una bolsa azul
	    redondeada) con contorno de tinta, en el mismo estilo pegatina del HUD.

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
local Iconos = require(Shared:WaitForChild("Config"):WaitForChild("Iconos"))

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

	-- Ilustracion (si hay arte): ancho = fraccion del ancho de diseno, acotado
	imagenFraccionAncho = 0.62,
	imagenAnchoMin = 600,
	imagenAnchoMax = 1100,
	imagenAspecto = 16 / 9,
	imagenEscalaVacia = 0.9, -- con una sola imagen, tamano con la bolsa vacia

	-- La bolsa (dibujada)
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

	-- Las manos (dibujadas)
	brazoAncho = 100,
	brazoAlto = 350, -- mas alto = las manos llegan mas arriba
	brazoSeparacion = 240, -- px del centro a cada brazo
	brazoBase = 20, -- px que el brazo baja por debajo del conjunto (esconde el corte)
	brazoInclinacion = 22, -- grados hacia el centro
	colorPiel = Paleta.PIEL,
	colorManga = Paleta.gris(90),
	contorno = 4, -- grosor del contorno de tinta del dibujo
}

local ANCHO, ALTO = 700, 420
local raiz = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(ANCHO, ALTO), Position = UDim2.new(0.5, 0, 1, AJUSTES.alturaConjunto), Anchor = Vector2.new(0.5, 1), Transparencia = 1, Nombre = "Raiz" })
raiz.ClipsDescendants = false

local function fraccionLlenado(): number
	local b = EstadoCliente.bolsa
	if b.capacidad <= 0 then
		return 0
	end
	return math.clamp(#b.items / b.capacidad, 0, 1)
end

-- Lo que cada version expone al resto del script
type Vista = {
	alLlenar: (fraccion: number) -> (),
}

-- ===========================================================================
-- Version con arte: la ilustracion
-- ===========================================================================

local function montarIlustracion(): Vista
	local claves = { "manosVacia", "manosMedia", "manosLlena" }
	local imagenes: { ImageLabel } = {}
	for i, clave in claves do
		local id = Iconos.id(clave)
		if id then
			local img = Instance.new("ImageLabel")
			img.Name = clave
			img.Image = id
			img.BackgroundTransparency = 1
			img.ScaleType = Enum.ScaleType.Fit
			img.Position = UDim2.new(0.5, 0, 1, 0)
			img.AnchorPoint = Vector2.new(0.5, 1)
			img.ZIndex = 4
			img.ImageTransparency = if #imagenes == 0 then 0 else 1
			img.Parent = raiz
			imagenes[#imagenes + 1] = img
		elseif i == 1 then
			error("Manos: falta manosVacia")
		end
	end
	local escala = Instance.new("UIScale")
	escala.Scale = if #imagenes == 1 then AJUSTES.imagenEscalaVacia else 1
	escala.Parent = raiz

	local function ajustarTamano()
		local anchoDiseno = Componentes.disenoDisponible()
		local w = math.clamp(anchoDiseno * AJUSTES.imagenFraccionAncho, AJUSTES.imagenAnchoMin, AJUSTES.imagenAnchoMax)
		local h = w / AJUSTES.imagenAspecto
		for _, img in imagenes do
			img.Size = UDim2.fromOffset(w, h)
		end
	end
	Componentes.alCambiarDisposicion:Connect(ajustarTamano)
	ajustarTamano()

	local visible = 1
	return {
		alLlenar = function(fraccion: number)
			if #imagenes == 1 then
				TweenService:Create(escala, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = AJUSTES.imagenEscalaVacia + (1 - AJUSTES.imagenEscalaVacia) * fraccion }):Play()
				return
			end
			local objetivo = if fraccion < 1 / 3 then 1 elseif fraccion < 2 / 3 then math.min(2, #imagenes) else #imagenes
			if objetivo ~= visible then
				TweenService:Create(imagenes[visible], TweenInfo.new(0.2), { ImageTransparency = 1 }):Play()
				TweenService:Create(imagenes[objetivo], TweenInfo.new(0.2), { ImageTransparency = 0 }):Play()
				visible = objetivo
			end
		end,
	}
end

-- ===========================================================================
-- Version dibujada: Frames con contorno de tinta
-- ===========================================================================

local function contorno(inst: Instance)
	Componentes.borde(inst, Paleta.UI_TINTA, AJUSTES.contorno)
end

local function montarDibujo(): Vista
	-- Composicion: la boca de la bolsa es un ovalo grande y oscuro entre las
	-- manos, a media altura, como en KOTAMON; las manos van POR DELANTE del
	-- borde (ZIndex mayor) agarrandolo.
	local function brazo(nombre: string, lado: number): Frame
		local b = Componentes.marco({ Parent = raiz, Size = UDim2.fromOffset(AJUSTES.brazoAncho, AJUSTES.brazoAlto), Position = UDim2.new(0.5, lado * AJUSTES.brazoSeparacion, 1, AJUSTES.brazoBase), Anchor = Vector2.new(0.5, 1), Color = AJUSTES.colorPiel, Radio = math.floor(AJUSTES.brazoAncho * 0.46), Nombre = nombre })
		b.Rotation = -lado * AJUSTES.brazoInclinacion
		b.ZIndex = 7
		contorno(b)
		-- Manga
		local manga = Componentes.marco({ Parent = b, Size = UDim2.new(1.15, 0, 0, 90), Position = UDim2.new(0.5, 0, 1, 0), Anchor = Vector2.new(0.5, 1), Color = AJUSTES.colorManga, Radio = 30 })
		manga.ZIndex = 8
		contorno(manga)
		-- Pulgar
		local pulgar = Componentes.marco({ Parent = b, Size = UDim2.fromOffset(30, 56), Position = UDim2.new(if lado < 0 then 1 else 0, if lado < 0 then -6 else 6, 0, 22), Anchor = Vector2.new(0.5, 0), Color = AJUSTES.colorPiel, Radio = 15 })
		pulgar.Rotation = lado * 35
		pulgar.ZIndex = 9
		contorno(pulgar)
		return b
	end

	brazo("BrazoIzq", -1)
	brazo("BrazoDer", 1)

	-- Ovalo: UICorner al 50 % solo da una "pastilla" (semicirculos en los
	-- extremos), no una elipse. Se apilan tres pastillas de proporciones
	-- distintas centradas: su union se lee como un ovalo. El contorno no puede
	-- ser un UIStroke por pastilla (cruzaria el dibujo): es la MISMA union en
	-- tinta, unos px mas grande, pintada debajo.
	local function ovalo(padre: Instance, nombre: string, ancho: UDim, alto: number, color: Color3, zindex: number, conContorno: boolean): Frame
		local raizOvalo = Componentes.marco({ Parent = padre, Size = UDim2.new(ancho.Scale, ancho.Offset, 0, alto), Position = UDim2.new(0.5, 0, 0.5, 0), Anchor = Vector2.new(0.5, 0.5), Transparencia = 1, Nombre = nombre })
		raizOvalo.ZIndex = zindex
		local capas = { { 1, 0.55 }, { 0.88, 0.8 }, { 0.66, 1 } }
		local function union(colorCapa: Color3, extra: number, z: number)
			for _, capa in capas do
				local f = Componentes.marco({ Parent = raizOvalo, Size = UDim2.new(capa[1], extra, capa[2], extra), Position = UDim2.new(0.5, 0, 0.5, 0), Anchor = Vector2.new(0.5, 0.5), Color = colorCapa, Radio = 0 })
				f.ZIndex = z
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0.5, 0)
				c.Parent = f
			end
		end
		if conContorno then
			union(Paleta.UI_TINTA, AJUSTES.contorno * 2, zindex)
		end
		union(color, 0, zindex + 1)
		return raizOvalo
	end

	local bolsa = Componentes.marco({ Parent = raiz, Size = UDim2.fromOffset(AJUSTES.bolsaAncho, AJUSTES.bolsaAlto), Position = UDim2.new(0.5, 0, 1, -AJUSTES.bolsaSubida), Anchor = Vector2.new(0.5, 1), Color = AJUSTES.colorBolsa, Radio = AJUSTES.bolsaRedondeo, Nombre = "Bolsa" })
	bolsa.ZIndex = 4
	contorno(bolsa)
	-- La boca: borde claro y agujero oscuro, centrados en el borde superior del saco
	local boca = Componentes.marco({ Parent = bolsa, Size = UDim2.new(1, 0, 0, AJUSTES.bocaAlto), Position = UDim2.new(0.5, 0, 0, AJUSTES.bocaDesplazamiento), Anchor = Vector2.new(0.5, 0.5), Transparencia = 1, Nombre = "Boca" })
	boca.ZIndex = 5
	ovalo(boca, "Borde", UDim.new(AJUSTES.bocaAncho, 0), AJUSTES.bocaAlto, AJUSTES.colorBorde, 5, true)
	ovalo(boca, "Interior", UDim.new(AJUSTES.bocaAncho, -AJUSTES.bocaGrosorBorde), AJUSTES.bocaAlto - AJUSTES.bocaGrosorBorde, AJUSTES.colorInterior, 6, false)
	local pliegue = Componentes.marco({ Parent = bolsa, Size = UDim2.new(0.7, 0, 0, 18), Position = UDim2.new(0.5, 0, 0.7, 0), Anchor = Vector2.new(0.5, 0.5), Color = Paleta.escalar(AJUSTES.colorBolsa, 0.8), Radio = 9 })
	pliegue.ZIndex = 5
	pliegue.Rotation = -6

	local escalaBolsa = Instance.new("UIScale")
	escalaBolsa.Scale = AJUSTES.bolsaEscalaVacia
	escalaBolsa.Parent = bolsa

	return {
		alLlenar = function(fraccion: number)
			TweenService:Create(escalaBolsa, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = AJUSTES.bolsaEscalaVacia + (1 - AJUSTES.bolsaEscalaVacia) * fraccion }):Play()
		end,
	}
end

local vista: Vista = if Iconos.id("manosVacia") then montarIlustracion() else montarDibujo()

-- ===========================================================================
-- Visibilidad y movimiento
-- ===========================================================================

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
	vista.alLlenar(fraccionLlenado())
end)
vista.alLlenar(fraccionLlenado())

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
