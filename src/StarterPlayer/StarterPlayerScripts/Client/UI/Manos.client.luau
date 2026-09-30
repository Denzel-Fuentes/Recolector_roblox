--!strict
--[[
	Manos
	La "imagen" de manos extendidas con la bolsa de basura que se ve en primera
	persona dentro del patio (como en KOTAMON).

	Dos versiones, y elige sola:
	  - Con arte (Config/Iconos manosVacia / manosMedia / manosLlena con id):
	    la ilustracion en un ImageLabel anclado abajo-centro; el estado cambia
	    con el llenado de la bolsa (<1/3 vacia, <2/3 media, resto llena) con un
	    fundido.
	  - Sin arte: dibujada con Frames (dos brazos color piel y una bolsa azul
	    redondeada) con contorno marino, en el estilo del Kit. Llena, la boca
	    se sustituye por la bolsa cerrada y atada (nudo).

	La bolsa NO cambia de tamano con el llenado (decision del usuario).
	Se ve solo con EnPatio y sin panel abierto. Se mueve un poco:
	  - balanceo lento continuo (seno),
	  - sacudida corta cada vez que entra algo en la bolsa,
	  - sube/vibra al cargar el lanzamiento.

	Fusion monta las piezas y ata lo que es estado (visible, llena, fundidos
	de la ilustracion). El balanceo es de cada fotograma y se
	escribe directo en RenderStepped: no es estado, es animacion.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local Iconos = require(Shared:WaitForChild("Config"):WaitForChild("Iconos"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Escala = require(script.Parent:WaitForChild("Kit"):WaitForChild("Escala"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local Children = Fusion.Children
local peek = Fusion.peek

local jugador = Players.LocalPlayer

-- ===========================================================================
-- AJUSTES: todo lo que se ve se calibra aqui (pixeles a 1080p; la UI escala
-- sola con Kit/Pantalla). Y positivo = mas abajo; Y negativo = mas
-- arriba. Guarda el archivo y Rojo lo sincroniza: en Play se ve al instante.
-- ===========================================================================
local AJUSTES = {
	-- Todo el conjunto (manos + bolsa). Subir todo: bajar `alturaConjunto`
	-- (p. ej. -40 lo sube 80 px respecto a 40).
	alturaConjunto = 190, -- px por debajo del borde inferior de la pantalla

	-- En movil (tactil) la UI se dibuja a escala 0,8 como minimo y la
	-- pantalla "mide" unos 500 px de alto: con los valores de PC las manos
	-- tapaban casi la mitad (peticion del usuario, 29 sep: mas pequenas y mas
	-- abajo). Asomen ~100 px: el borde de la bolsa y las puntas de las manos.
	tactilEscala = 0.6, -- tamano del conjunto respecto al de PC
	tactilAlturaConjunto = 150, -- como alturaConjunto, ya con la escala aplicada

	-- Ilustracion (si hay arte): ancho = fraccion del ancho de diseno, acotado
	imagenFraccionAncho = 0.62,
	imagenAnchoMin = 600,
	imagenAnchoMax = 1100,
	imagenAspecto = 16 / 9,

	-- La bolsa (dibujada)
	bolsaAncho = 470,
	bolsaAlto = 320, -- mas alto = la boca queda mas arriba
	bolsaSubida = 40, -- px que el fondo de la bolsa queda por encima del conjunto
	bolsaRedondeo = 150, -- radio de las esquinas del saco
	colorBolsa = Paleta.BOLSA,

	-- El nudo (bolsa llena: cerrada y atada)
	nudoHundido = 40, -- px por debajo del borde superior del saco donde nace el cuello
	nudoCuelloAncho = 120,
	nudoCuelloAlto = 70,
	nudoOrejaAncho = 70,
	nudoOrejaAlto = 110,
	nudoOrejaSeparacion = 40, -- px del centro a cada oreja
	nudoOrejaInclinacion = 35, -- grados hacia fuera
	colorAtadura = Paleta.escalar(Paleta.BOLSA, 0.55),

	-- La boca (el ovalo abierto)
	bocaAlto = 170, -- alto del ovalo
	bocaAncho = 0.85, -- fraccion del ancho de la bolsa
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
	contorno = 4, -- grosor del contorno marino del dibujo
}

local ANCHO, ALTO = 700, 420

local scope = Fusion.scoped(Fusion, Kit)

local llenado = scope:Computed(function(use)
	local b = use(EstadoCliente.reactivo.bolsa) :: any
	return if b.capacidad > 0 then math.clamp(#b.items / b.capacidad, 0, 1) else 0
end)
local llena = scope:Computed(function(use)
	return use(llenado) >= 1
end)

-- Un Frame redondeado (con contorno marino si se pide)
local function forma(props: { Nombre: string, Size: UDim2, Position: UDim2, AnchorPoint: Vector2?, Color: Color3, Radio: UDim?, ZIndex: number, Rotacion: number?, Contorno: boolean?, Hijos: any? })
	return scope:New("Frame")({
		Name = props.Nombre,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundColor3 = props.Color,
		Rotation = props.Rotacion or 0,
		ZIndex = props.ZIndex,
		[Children] = {
			if props.Radio then scope:New("UICorner")({ CornerRadius = props.Radio }) else nil,
			if props.Contorno then scope:New("UIStroke")({ Color = Paleta.UI_TINTA, Thickness = AJUSTES.contorno }) else nil,
			props.Hijos,
		},
	})
end

-- ===========================================================================
-- Version con arte: la ilustracion
-- ===========================================================================

local function ilustracion(): { Instance }
	local claves = { "manosVacia", "manosMedia", "manosLlena" }
	local ids = {}
	for _, clave in claves do
		local id = Iconos.id(clave)
		if id then
			table.insert(ids, id)
		end
	end
	local tamano = scope:Computed(function(use)
		local anchoDiseno = (use(Escala.diseno) :: Vector2).X
		local w = math.clamp(anchoDiseno * AJUSTES.imagenFraccionAncho, AJUSTES.imagenAnchoMin, AJUSTES.imagenAnchoMax)
		return UDim2.fromOffset(w, w / AJUSTES.imagenAspecto)
	end)
	-- Con varias imagenes se ve la del tramo de llenado; con una, siempre esa
	local tramo = scope:Computed(function(use)
		local f = use(llenado)
		return if f < 1 / 3 then 1 elseif f < 2 / 3 then math.min(2, #ids) else #ids
	end)
	local hijos = {}
	for i, id in ids do
		table.insert(hijos, scope:New("ImageLabel")({
			Name = claves[i],
			Image = id,
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = tamano,
			Position = UDim2.new(0.5, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 1),
			ZIndex = 4,
			ImageTransparency = scope:Tween(
				scope:Computed(function(use)
					return if use(tramo) == i then 0 else 1
				end),
				TweenInfo.new(0.2)
			),
		}))
	end
	return hijos
end

-- ===========================================================================
-- Version dibujada: Frames con contorno marino
-- ===========================================================================

-- Ovalo: UICorner al 50 % solo da una "pastilla" (semicirculos en los
-- extremos), no una elipse. Se apilan tres pastillas de proporciones
-- distintas centradas: su union se lee como un ovalo. El contorno no puede
-- ser un UIStroke por pastilla (cruzaria el dibujo): es la MISMA union en
-- marino, unos px mas grande, pintada debajo.
local function ovalo(nombre: string, ancho: UDim, alto: number, color: Color3, zindex: number, conContorno: boolean)
	local capas = { { 1, 0.55 }, { 0.88, 0.8 }, { 0.66, 1 } }
	local piezas = {}
	local function union(colorCapa: Color3, extra: number, z: number)
		for _, capa in capas do
			table.insert(piezas, forma({
				Nombre = "Capa",
				Size = UDim2.new(capa[1], extra, capa[2], extra),
				Position = UDim2.fromScale(0.5, 0.5),
				Color = colorCapa,
				Radio = UDim.new(0.5, 0),
				ZIndex = z,
			}))
		end
	end
	if conContorno then
		union(Paleta.UI_TINTA, AJUSTES.contorno * 2, zindex)
	end
	union(color, 0, zindex + 1)
	return scope:New("Frame")({
		Name = nombre,
		Size = UDim2.new(ancho.Scale, ancho.Offset, 0, alto),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = zindex,
		[Children] = piezas,
	})
end

local function brazo(nombre: string, lado: number)
	return forma({
		Nombre = nombre,
		Size = UDim2.fromOffset(AJUSTES.brazoAncho, AJUSTES.brazoAlto),
		Position = UDim2.new(0.5, lado * AJUSTES.brazoSeparacion, 1, AJUSTES.brazoBase),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = AJUSTES.colorPiel,
		Radio = UDim.new(0, math.floor(AJUSTES.brazoAncho * 0.46)),
		Rotacion = -lado * AJUSTES.brazoInclinacion,
		ZIndex = 7,
		Contorno = true,
		Hijos = {
			-- Manga
			forma({ Nombre = "Manga", Size = UDim2.new(1.15, 0, 0, 90), Position = UDim2.new(0.5, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), Color = AJUSTES.colorManga, Radio = UDim.new(0, 30), ZIndex = 8, Contorno = true }),
			-- Pulgar
			forma({
				Nombre = "Pulgar",
				Size = UDim2.fromOffset(30, 56),
				Position = UDim2.new(if lado < 0 then 1 else 0, if lado < 0 then -6 else 6, 0, 22),
				AnchorPoint = Vector2.new(0.5, 0),
				Color = AJUSTES.colorPiel,
				Radio = UDim.new(0, 15),
				Rotacion = lado * 35,
				ZIndex = 9,
				Contorno = true,
			}),
		},
	})
end

-- Bolsa llena: la boca desaparece y en su lugar la bolsa esta cerrada y atada
-- (cuello fruncido, cinta y las dos "orejas" del nudo)
local function nudo()
	local color = AJUSTES.colorBolsa
	local function oreja(lado: number)
		return forma({
			Nombre = if lado < 0 then "OrejaIzq" else "OrejaDer",
			Size = UDim2.fromOffset(AJUSTES.nudoOrejaAncho, AJUSTES.nudoOrejaAlto),
			Position = UDim2.new(0.5, lado * AJUSTES.nudoOrejaSeparacion, 0, -AJUSTES.nudoCuelloAlto + 10),
			AnchorPoint = Vector2.new(0.5, 1),
			Color = color,
			Radio = UDim.new(0.5, 0),
			Rotacion = lado * AJUSTES.nudoOrejaInclinacion,
			ZIndex = 5,
			Contorno = true,
		})
	end
	return scope:New("Frame")({
		Name = "Nudo",
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0, AJUSTES.nudoHundido),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Visible = llena,
		ZIndex = 5,
		[Children] = {
			oreja(-1),
			oreja(1),
			forma({
				Nombre = "Cuello",
				Size = UDim2.fromOffset(AJUSTES.nudoCuelloAncho, AJUSTES.nudoCuelloAlto + 30),
				Position = UDim2.new(0.5, 0, 0, 30),
				AnchorPoint = Vector2.new(0.5, 1),
				Color = color,
				Radio = UDim.new(0, 26),
				ZIndex = 6,
				Contorno = true,
			}),
			forma({
				Nombre = "Atadura",
				Size = UDim2.fromOffset(AJUSTES.nudoCuelloAncho + 24, 26),
				Position = UDim2.new(0.5, 0, 0, -AJUSTES.nudoCuelloAlto + 12),
				Color = AJUSTES.colorAtadura,
				Radio = UDim.new(0, 13),
				ZIndex = 7,
				Contorno = true,
			}),
		},
	})
end

local function dibujo(): { Instance }
	-- Composicion: la boca de la bolsa es un ovalo grande y oscuro entre las
	-- manos, a media altura, como en KOTAMON; las manos van POR DELANTE del
	-- borde (ZIndex mayor) agarrandolo.
	local bolsa = forma({
		Nombre = "Bolsa",
		Size = UDim2.fromOffset(AJUSTES.bolsaAncho, AJUSTES.bolsaAlto),
		Position = UDim2.new(0.5, 0, 1, -AJUSTES.bolsaSubida),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = AJUSTES.colorBolsa,
		Radio = UDim.new(0, AJUSTES.bolsaRedondeo),
		ZIndex = 4,
		Contorno = true,
		Hijos = {
			-- La boca: borde claro y agujero oscuro, centrados en el borde superior del saco
			scope:New("Frame")({
				Name = "Boca",
				Size = UDim2.new(1, 0, 0, AJUSTES.bocaAlto),
				Position = UDim2.new(0.5, 0, 0, AJUSTES.bocaDesplazamiento),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use)
					return not use(llena)
				end),
				ZIndex = 5,
				[Children] = {
					ovalo("Borde", UDim.new(AJUSTES.bocaAncho, 0), AJUSTES.bocaAlto, AJUSTES.colorBorde, 5, true),
					ovalo("Interior", UDim.new(AJUSTES.bocaAncho, -AJUSTES.bocaGrosorBorde), AJUSTES.bocaAlto - AJUSTES.bocaGrosorBorde, AJUSTES.colorInterior, 6, false),
				},
			}),
			nudo(),
			forma({
				Nombre = "Pliegue",
				Size = UDim2.new(0.7, 0, 0, 18),
				Position = UDim2.fromScale(0.5, 0.7),
				Color = Paleta.escalar(AJUSTES.colorBolsa, 0.8),
				Radio = UDim.new(0, 9),
				Rotacion = -6,
				ZIndex = 5,
			}),
		},
	})
	return { brazo("BrazoIzq", -1), brazo("BrazoDer", 1), bolsa }
end

-- ===========================================================================
-- Montaje, visibilidad y movimiento
-- ===========================================================================

local tactil = scope:Computed(function(use)
	return use(Escala.plataforma) == "tactil"
end)

-- La escala va sobre la raiz anclada abajo-centro: encoge hacia el borde
-- inferior, sin mover el punto de anclaje
local raiz = scope:New("Frame")({
	Name = "Raiz",
	Size = UDim2.fromOffset(ANCHO, ALTO),
	Position = UDim2.new(0.5, 0, 1, AJUSTES.alturaConjunto),
	AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1,
	[Children] = {
		scope:New("UIScale")({
			Scale = scope:Computed(function(use)
				return if use(tactil) then AJUSTES.tactilEscala else 1
			end),
		}),
		if Iconos.id("manosVacia") then ilustracion() else dibujo(),
	},
})

local enPatio = scope:Value(jugador:GetAttribute("EnPatio") == true)
jugador:GetAttributeChangedSignal("EnPatio"):Connect(function()
	enPatio:set(jugador:GetAttribute("EnPatio") == true)
end)
local visible = scope:Computed(function(use)
	return use(enPatio) and use(Menu.abiertoR) == nil
end)

scope:Pantalla({ Nombre = "Manos", Orden = 0, Visible = visible, Hijos = raiz })

-- Sacudida al recoger algo
local sacudida = 0
do
	local ultimoConteo = #EstadoCliente.bolsa.items
	scope:Observer(EstadoCliente.reactivo.bolsa):onChange(function()
		local n = #(peek(EstadoCliente.reactivo.bolsa) :: any).items
		if n > ultimoConteo then
			sacudida = 1
		end
		ultimoConteo = n
	end)
end

local tiempo = 0
RunService.RenderStepped:Connect(function(dt)
	if not peek(visible) then
		return
	end
	tiempo += dt
	sacudida = math.max(0, sacudida - dt * 4)
	local carga = EstadoCliente.cargaLanzamiento
	local enTactil = peek(tactil)
	local escala = if enTactil then AJUSTES.tactilEscala else 1
	local altura = if enTactil then AJUSTES.tactilAlturaConjunto else AJUSTES.alturaConjunto
	local vibracion = if carga > 0 then math.sin(tiempo * 40) * 4 * carga else 0
	local dx = (math.sin(tiempo * 1.4) * 7 + vibracion) * escala
	local dy = (math.cos(tiempo * 2.1) * 5 - math.sin(sacudida * math.pi) * 26 - carga * 40) * escala
	raiz.Position = UDim2.new(0.5, dx, 1, altura + dy)
	raiz.Rotation = math.sin(tiempo * 1.1) * 1.5 - carga * 6
end)
