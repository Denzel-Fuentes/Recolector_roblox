--!strict
--[[
	AvisosMundo
	Unica responsabilidad: pintar los avisos EN EL MUNDO (Services/
	AvisosMundo por AvisoMundoEvent): una burbuja donde pasa la cosa, sobre
	el monton, la pieza, el contenedor o tu cabeza. Sustituyen a los toasts
	de rechazo ("Termina tu montón...", "Ese tipo se abre en el Rebirth
	N"...), que se leian como ventanas sueltas y no decian DONDE (peticion
	del usuario, 6 oct).

	El servidor dice el sitio de la cosa; la burbuja se pinta delante de la
	camara, a media altura de la pantalla, ladeada hacia la cosa
	(puntoLegible): sobre el sitio exacto quedaba demasiado alta para leerla.

	La burbuja es una pastilla del Kit (papel, contorno marino, FredokaOne,
	icono opcional de Config/Iconos o su glifo dibujado), en pixeles: se lee
	igual de cerca que de lejos. Entra con un pop elastico y una sacudida
	corta, sube un poco y se funde. Una sola burbuja por sitio: la nueva
	sustituye a la anterior. Si el aviso trae un modelo para resaltar (tu
	monton pendiente), late con un Highlight mientras dura.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Iconos = require(Config:WaitForChild("Iconos"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Red = require(Utilidades:WaitForChild("Red"))
local Idioma = require(Utilidades:WaitForChild("Idioma"))
local Glifos = require(Utilidades:WaitForChild("Glifos"))

local Tema = require(script.Parent:WaitForChild("UI"):WaitForChild("Kit"):WaitForChild("Tema"))

local AvisoMundoEvent = Red.evento("AvisoMundoEvent")

local VIDA = 1.8 -- s en pantalla
local SUBIDA = 1.6 -- studs que sube
local ALTO = 50 -- px de la pastilla
local TAMANO_ICONO = 34

-- Una burbuja por sitio (posicion redondeada a 2 studs)
local porSitio: { [string]: Attachment } = {}

-- Donde se lee bien (peticion del usuario, 7 oct: sobre un monton grande
-- la burbuja quedaba a 10+ studs de altura y habia que alejarse para
-- leerla). Se pone respecto a la CAMARA: en la direccion en que mira (asi
-- queda a media altura de la pantalla), girada hacia la cosa como mucho
-- GIRO_MAX para que diga hacia donde esta sin salirse del centro. Medido a
-- la altura de la cabeza se veia igual en lo alto de la pantalla: la
-- camara en tercera persona mira desde arriba.
local DISTANCIA_CAMARA = 12 -- studs delante de la camara
local GIRO_MAX = math.rad(20)

local function puntoLegible(objetivo: Vector3): Vector3
	local camara = workspace.CurrentCamera
	if not camara then
		return objetivo
	end
	local origen = camara.CFrame.Position
	local mirada = camara.CFrame.LookVector
	local miradaH = Vector3.new(mirada.X, 0, mirada.Z)
	local hacia = Vector3.new(objetivo.X - origen.X, 0, objetivo.Z - origen.Z)
	local giro = 0
	if miradaH.Magnitude > 1e-3 and hacia.Magnitude > 1e-3 then
		local a, b = miradaH.Unit, hacia.Unit
		giro = math.clamp(math.atan2(a:Cross(b).Y, a:Dot(b)), -GIRO_MAX, GIRO_MAX)
	end
	return origen + CFrame.fromAxisAngle(Vector3.yAxis, giro):VectorToWorldSpace(mirada) * DISTANCIA_CAMARA
end

local function claveSitio(p: Vector3): string
	return string.format("%d,%d,%d", math.round(p.X / 2), math.round(p.Y / 2), math.round(p.Z / 2))
end

local function icono(clave: string, padre: Instance)
	local id = Iconos.id(clave)
	local g: GuiObject
	if id then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = id
		img.ScaleType = Enum.ScaleType.Fit
		img.Size = UDim2.fromOffset(TAMANO_ICONO, TAMANO_ICONO)
		g = img
	elseif Glifos.existe(clave) then
		g = Glifos.dibujar(clave, TAMANO_ICONO)
	else
		return
	end
	g.Name = "Icono"
	g.LayoutOrder = 1
	g.Parent = padre
end

local function resaltar(modelo: Instance)
	if not modelo:IsA("Model") and not modelo:IsA("BasePart") then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "AvisoResaltado"
	h.FillColor = Paleta.UI_PRIMARIO
	h.OutlineColor = Paleta.UI_PRIMARIO
	h.FillTransparency = 1
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = modelo
	h.Parent = workspace.Terrain
	-- Tres latidos y fuera
	local latido = TweenInfo.new(VIDA / 6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true)
	TweenService:Create(h, latido, { FillTransparency = 0.45 }):Play()
	task.delay(VIDA, function()
		h:Destroy()
	end)
end

local function mostrar(objetivo: Vector3, texto: string, claveIcono: string?)
	local posicion = puntoLegible(objetivo)
	local clave = claveSitio(posicion)
	local vieja = porSitio[clave]
	if vieja then
		vieja:Destroy()
	end
	local ancla = Instance.new("Attachment")
	ancla.Name = "AvisoMundo"
	ancla.Parent = workspace.Terrain
	ancla.WorldPosition = posicion
	porSitio[clave] = ancla

	local bb = Instance.new("BillboardGui")
	bb.Adornee = ancla
	bb.Size = UDim2.fromOffset(520, ALTO + 20)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	bb.Parent = ancla

	-- CanvasGroup: se funde entera de una vez
	local grupo = Instance.new("CanvasGroup")
	grupo.Name = "Burbuja"
	grupo.AnchorPoint = Vector2.new(0.5, 0.5)
	grupo.Position = UDim2.fromScale(0.5, 0.5)
	grupo.Size = UDim2.fromOffset(0, ALTO)
	grupo.AutomaticSize = Enum.AutomaticSize.X
	grupo.BackgroundColor3 = Paleta.UI_PAPEL
	grupo.Parent = bb
	local esquinas = Instance.new("UICorner")
	esquinas.CornerRadius = UDim.new(0.5, 0)
	esquinas.Parent = grupo
	local contorno = Instance.new("UIStroke")
	contorno.Color = Paleta.UI_TINTA
	contorno.Thickness = Tema.GROSOR
	contorno.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	contorno.Parent = grupo
	local relleno = Instance.new("UIPadding")
	relleno.PaddingLeft = UDim.new(0, 14)
	relleno.PaddingRight = UDim.new(0, 16)
	relleno.Parent = grupo
	local lista = Instance.new("UIListLayout")
	lista.FillDirection = Enum.FillDirection.Horizontal
	lista.VerticalAlignment = Enum.VerticalAlignment.Center
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Padding = UDim.new(0, 8)
	lista.Parent = grupo
	if claveIcono then
		icono(claveIcono, grupo)
	end
	local etiqueta = Instance.new("TextLabel")
	etiqueta.Name = "Texto"
	etiqueta.LayoutOrder = 2
	etiqueta.BackgroundTransparency = 1
	etiqueta.AutomaticSize = Enum.AutomaticSize.X
	etiqueta.Size = UDim2.fromOffset(0, ALTO - 10)
	etiqueta.FontFace = Tema.FUENTE_TITULO
	etiqueta.TextSize = 22
	etiqueta.TextColor3 = Paleta.UI_TINTA
	etiqueta.Text = texto
	etiqueta.Parent = grupo
	local escala = Instance.new("UIScale")
	escala.Scale = 0.3
	escala.Parent = grupo

	-- Pop elastico con una sacudida, subida y fundido
	grupo.Rotation = -8
	TweenService:Create(escala, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(grupo, TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	TweenService:Create(bb, TweenInfo.new(VIDA, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, SUBIDA, 0) }):Play()
	TweenService:Create(grupo, TweenInfo.new(VIDA * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, VIDA * 0.65), { GroupTransparency = 1 }):Play()
	task.delay(VIDA + 0.05, function()
		if porSitio[clave] == ancla then
			porSitio[clave] = nil
		end
		ancla:Destroy()
	end)
end

-- El texto llega como Idioma.mensaje: se escribe en el idioma del jugador
AvisoMundoEvent.OnClientEvent:Connect(function(posicion, mensaje, claveIcono, modelo)
	local texto = Idioma.resolver(mensaje)
	if typeof(posicion) ~= "Vector3" or texto == "" then
		return
	end
	mostrar(posicion, texto, if typeof(claveIcono) == "string" then claveIcono else nil)
	if typeof(modelo) == "Instance" then
		resaltar(modelo)
	end
end)

-- Para PruebasCliente: ("avisoMundo", texto, icono) delante del personaje
local prueba = Instance.new("BindableEvent")
prueba.Name = "AvisoPrueba"
prueba.Event:Connect(function(posicion, texto, claveIcono)
	mostrar(posicion, Idioma.resolver(texto), claveIcono)
end)
prueba.Parent = script
