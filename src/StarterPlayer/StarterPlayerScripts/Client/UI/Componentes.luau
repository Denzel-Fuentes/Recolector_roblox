--!strict
--[[
	Componentes (ModuleScript)
	El "sistema de diseno" de la UI, en codigo: paneles, botones, textos,
	barras, pestanas, modales, scroll, rejillas y viewports. Toda pantalla del
	juego se monta con esto, asi que el aspecto (colores de Paleta, esquinas,
	fuentes) y la navegacion con gamepad se deciden UNA vez aqui.

	Gamepad: todo boton es Selectable y los paneles exponen primerSeleccionable
	para que Menu ponga GuiService.SelectedObject al abrirlos. La navegacion
	entre botones la hace Roblox sola con UIListLayout / UIGridLayout.

	Tamanos: cada ScreenGui lleva un UIScale que se adapta a la altura de la
	pantalla (0.75 en moviles pequenos, 1 en escritorio) para no disenar dos
	veces.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))

local Componentes = {}

Componentes.FUENTE = Enum.Font.Gotham
Componentes.FUENTE_NEGRITA = Enum.Font.GothamBold
Componentes.RADIO = 10

local jugador = Players.LocalPlayer
local playerGui = jugador:WaitForChild("PlayerGui")

-- ===========================================================================
-- Basicos
-- ===========================================================================

function Componentes.esquinas(inst: Instance, radio: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radio or Componentes.RADIO)
	c.Parent = inst
	return c
end

function Componentes.borde(inst: Instance, color: Color3?, grosor: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Paleta.UI_PANEL_CLARO
	s.Thickness = grosor or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

function Componentes.padding(inst: Instance, px: number, py: number?): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, py or px)
	p.PaddingBottom = UDim.new(0, py or px)
	p.Parent = inst
	return p
end

function Componentes.lista(inst: Instance, espacio: number?, horizontal: boolean?, alinear: Enum.HorizontalAlignment?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, espacio or 6)
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = alinear or Enum.HorizontalAlignment.Left
	l.Parent = inst
	return l
end

function Componentes.rejilla(inst: Instance, celda: UDim2, espacio: number?): UIGridLayout
	local g = Instance.new("UIGridLayout")
	g.CellSize = celda
	g.CellPadding = UDim2.fromOffset(espacio or 8, espacio or 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = inst
	return g
end

local function escalaPantalla(): number
	local cam = workspace.CurrentCamera
	local alto = if cam then cam.ViewportSize.Y else 900
	return math.clamp(alto / 900, 0.72, 1.1)
end

function Componentes.pantalla(nombre: string, orden: number?): ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name = nombre
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = orden or 0
	local escala = Instance.new("UIScale")
	escala.Scale = escalaPantalla()
	escala.Parent = sg
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			escala.Scale = escalaPantalla()
		end)
	end
	sg.Parent = playerGui
	return sg
end

export type PropsMarco = {
	Parent: Instance?,
	Nombre: string?,
	Size: UDim2?,
	Position: UDim2?,
	Anchor: Vector2?,
	Color: Color3?,
	Transparencia: number?,
	Radio: number?,
	Orden: number?,
	Visible: boolean?,
	ZIndex: number?,
}

function Componentes.marco(p: PropsMarco): Frame
	local f = Instance.new("Frame")
	f.Name = p.Nombre or "Marco"
	f.Size = p.Size or UDim2.fromOffset(100, 100)
	f.Position = p.Position or UDim2.fromOffset(0, 0)
	f.AnchorPoint = p.Anchor or Vector2.zero
	f.BackgroundColor3 = p.Color or Paleta.UI_PANEL
	f.BackgroundTransparency = p.Transparencia or 0
	f.BorderSizePixel = 0
	f.LayoutOrder = p.Orden or 0
	f.Visible = p.Visible ~= false
	if p.ZIndex then
		f.ZIndex = p.ZIndex
	end
	if (p.Radio or Componentes.RADIO) > 0 and (p.Transparencia or 0) < 1 then
		Componentes.esquinas(f, p.Radio)
	end
	f.Parent = p.Parent
	return f
end

export type PropsTexto = {
	Parent: Instance?,
	Nombre: string?,
	Texto: string?,
	Size: UDim2?,
	Position: UDim2?,
	Anchor: Vector2?,
	Color: Color3?,
	Tamano: number?,
	Negrita: boolean?,
	Alinear: Enum.TextXAlignment?,
	AlinearY: Enum.TextYAlignment?,
	Ajustar: boolean?,
	Escalar: boolean?,
	Orden: number?,
	Fondo: Color3?,
	Rico: boolean?,
}

function Componentes.texto(p: PropsTexto): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = p.Nombre or "Texto"
	t.Text = p.Texto or ""
	t.Size = p.Size or UDim2.new(1, 0, 0, 24)
	t.Position = p.Position or UDim2.fromOffset(0, 0)
	t.AnchorPoint = p.Anchor or Vector2.zero
	t.BackgroundTransparency = if p.Fondo then 0 else 1
	if p.Fondo then
		t.BackgroundColor3 = p.Fondo
		Componentes.esquinas(t, 6)
	end
	t.BorderSizePixel = 0
	t.TextColor3 = p.Color or Paleta.UI_TEXTO
	t.TextSize = p.Tamano or 16
	t.Font = if p.Negrita then Componentes.FUENTE_NEGRITA else Componentes.FUENTE
	t.TextXAlignment = p.Alinear or Enum.TextXAlignment.Left
	t.TextYAlignment = p.AlinearY or Enum.TextYAlignment.Center
	t.TextWrapped = p.Ajustar ~= false
	t.TextScaled = p.Escalar == true
	t.RichText = p.Rico == true
	t.LayoutOrder = p.Orden or 0
	t.Parent = p.Parent
	return t
end

export type PropsBoton = {
	Parent: Instance?,
	Nombre: string?,
	Texto: string?,
	Size: UDim2?,
	Position: UDim2?,
	Anchor: Vector2?,
	Color: Color3?,
	ColorTexto: Color3?,
	Tamano: number?,
	Orden: number?,
	alPulsar: (() -> ())?,
	Deshabilitado: boolean?,
	Radio: number?,
}

function Componentes.boton(p: PropsBoton): TextButton
	local b = Instance.new("TextButton")
	b.Name = p.Nombre or "Boton"
	b.Text = p.Texto or ""
	b.Size = p.Size or UDim2.fromOffset(140, 40)
	b.Position = p.Position or UDim2.fromOffset(0, 0)
	b.AnchorPoint = p.Anchor or Vector2.zero
	b.BackgroundColor3 = p.Color or Paleta.UI_PANEL_CLARO
	b.BorderSizePixel = 0
	b.TextColor3 = p.ColorTexto or Paleta.UI_TEXTO
	b.TextSize = p.Tamano or 16
	b.Font = Componentes.FUENTE_NEGRITA
	b.AutoButtonColor = false
	b.Selectable = true
	b.LayoutOrder = p.Orden or 0
	b.TextWrapped = true
	Componentes.esquinas(b, p.Radio)
	local base = b.BackgroundColor3
	local function refrescar()
		if p.Deshabilitado then
			b.BackgroundColor3 = Paleta.UI_BLOQUEADO
			b.TextColor3 = Paleta.UI_TEXTO_SUAVE
		else
			b.BackgroundColor3 = base
			b.TextColor3 = p.ColorTexto or Paleta.UI_TEXTO
		end
	end
	refrescar()
	b.MouseEnter:Connect(function()
		if not p.Deshabilitado then
			TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = Paleta.escalar(base, 1.2) }):Play()
		end
	end)
	b.MouseLeave:Connect(function()
		if not p.Deshabilitado then
			TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = base }):Play()
		end
	end)
	b.SelectionGained:Connect(function()
		if not p.Deshabilitado then
			b.BackgroundColor3 = Paleta.escalar(base, 1.3)
		end
	end)
	b.SelectionLost:Connect(function()
		refrescar()
	end)
	b.Activated:Connect(function()
		if p.Deshabilitado then
			return
		end
		TweenService:Create(b, TweenInfo.new(0.06), { BackgroundColor3 = Paleta.escalar(base, 0.8) }):Play()
		task.delay(0.08, function()
			if b.Parent then
				TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = base }):Play()
			end
		end)
		if p.alPulsar then
			p.alPulsar()
		end
	end)
	b.Parent = p.Parent
	return b
end

function Componentes.deshabilitar(b: TextButton, deshabilitado: boolean, colorBase: Color3?)
	b.Active = not deshabilitado
	b.Selectable = not deshabilitado
	if deshabilitado then
		b.BackgroundColor3 = Paleta.UI_BLOQUEADO
		b.TextColor3 = Paleta.UI_TEXTO_SUAVE
	else
		b.BackgroundColor3 = colorBase or Paleta.UI_PANEL_CLARO
		b.TextColor3 = Paleta.UI_TEXTO
	end
end

export type Barra = {
	marco: Frame,
	fijar: (fraccion: number, texto: string?) -> (),
}

function Componentes.barra(parent: Instance, size: UDim2, color: Color3, orden: number?): Barra
	local marco = Componentes.marco({ Parent = parent, Size = size, Color = Paleta.UI_FONDO, Radio = 6, Orden = orden })
	local relleno = Componentes.marco({ Parent = marco, Size = UDim2.fromScale(0, 1), Color = color, Radio = 6, Nombre = "Relleno" })
	local etiqueta = Componentes.texto({ Parent = marco, Size = UDim2.fromScale(1, 1), Alinear = Enum.TextXAlignment.Center, Tamano = 13, Negrita = true })
	etiqueta.ZIndex = 2
	return {
		marco = marco,
		fijar = function(fraccion: number, texto: string?)
			fraccion = math.clamp(fraccion, 0, 1)
			TweenService:Create(relleno, TweenInfo.new(0.2), { Size = UDim2.fromScale(fraccion, 1) }):Play()
			etiqueta.Text = texto or ""
		end,
	}
end

function Componentes.scroll(parent: Instance, size: UDim2?, position: UDim2?): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Size = size or UDim2.fromScale(1, 1)
	s.Position = position or UDim2.fromOffset(0, 0)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.ScrollBarImageColor3 = Paleta.UI_TEXTO_SUAVE
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.fromScale(0, 0)
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.Parent = parent
	return s
end

-- ===========================================================================
-- Pestanas
-- ===========================================================================

export type Pestanas = {
	barra: Frame,
	seleccionar: (indice: number) -> (),
	botones: { TextButton },
}

function Componentes.pestanas(parent: Instance, nombres: { string }, alCambiar: (indice: number) -> (), orden: number?): Pestanas
	local barra = Componentes.marco({ Parent = parent, Size = UDim2.new(1, 0, 0, 38), Transparencia = 1, Orden = orden, Nombre = "Pestanas" })
	Componentes.lista(barra, 6, true)
	local botones = {}
	local actual = 0
	local function seleccionar(i: number)
		actual = i
		for j, b in botones do
			b.BackgroundColor3 = if j == i then Paleta.UI_ACENTO else Paleta.UI_PANEL_CLARO
			b.TextColor3 = if j == i then Paleta.UI_FONDO else Paleta.UI_TEXTO
		end
		alCambiar(i)
	end
	for i, nombre in nombres do
		local b = Componentes.boton({
			Parent = barra,
			Texto = nombre,
			Size = UDim2.new(1 / #nombres, -6, 1, 0),
			Orden = i,
			Tamano = 15,
			alPulsar = function()
				seleccionar(i)
			end,
		})
		botones[i] = b
	end
	return { barra = barra, seleccionar = seleccionar, botones = botones }
end

-- ===========================================================================
-- Modal
-- ===========================================================================

export type Modal = {
	pantalla: ScreenGui,
	panel: Frame,
	contenido: Frame,
	titulo: TextLabel,
	abrir: () -> (),
	cerrar: () -> (),
	estaAbierto: () -> boolean,
	botonCerrar: TextButton,
	alCerrar: { (() -> ())? },
}

function Componentes.modal(nombre: string, tituloTexto: string, ancho: number, alto: number): Modal
	local pantalla = Componentes.pantalla(nombre, 10)
	pantalla.Enabled = false
	local fondo = Componentes.marco({ Parent = pantalla, Size = UDim2.fromScale(1, 1), Color = Color3.new(0, 0, 0), Transparencia = 0.45, Radio = 0, Nombre = "Fondo" })
	local panel = Componentes.marco({
		Parent = fondo,
		Size = UDim2.fromOffset(ancho, alto),
		Position = UDim2.fromScale(0.5, 0.5),
		Anchor = Vector2.new(0.5, 0.5),
		Color = Paleta.UI_FONDO,
		Radio = 14,
		Nombre = "Panel",
	})
	Componentes.borde(panel, Paleta.UI_PANEL_CLARO, 2)
	local cabecera = Componentes.marco({ Parent = panel, Size = UDim2.new(1, 0, 0, 52), Transparencia = 1, Nombre = "Cabecera" })
	local titulo = Componentes.texto({ Parent = cabecera, Texto = tituloTexto, Size = UDim2.new(1, -120, 1, 0), Position = UDim2.fromOffset(18, 0), Tamano = 22, Negrita = true })
	local estado = { abierto = false }
	local alCerrar = {}
	local function cerrar()
		if not estado.abierto then
			return
		end
		estado.abierto = false
		pantalla.Enabled = false
		for _, fn in alCerrar do
			if fn then
				fn()
			end
		end
	end
	local botonCerrar = Componentes.boton({
		Parent = cabecera,
		Texto = "✕",
		Size = UDim2.fromOffset(40, 36),
		Position = UDim2.new(1, -50, 0.5, 0),
		Anchor = Vector2.new(0, 0.5),
		Color = Paleta.UI_PELIGRO,
		Tamano = 18,
		alPulsar = cerrar,
	})
	local contenido = Componentes.marco({ Parent = panel, Size = UDim2.new(1, -24, 1, -64), Position = UDim2.fromOffset(12, 56), Transparencia = 1, Nombre = "Contenido" })
	local function abrir()
		estado.abierto = true
		pantalla.Enabled = true
		panel.Size = UDim2.fromOffset(ancho * 0.94, alto * 0.94)
		TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(ancho, alto) }):Play()
	end
	return {
		pantalla = pantalla,
		panel = panel,
		contenido = contenido,
		titulo = titulo,
		abrir = abrir,
		cerrar = cerrar,
		estaAbierto = function()
			return estado.abierto
		end,
		botonCerrar = botonCerrar,
		alCerrar = alCerrar,
	}
end

-- ===========================================================================
-- Viewport para modelos whitebox
-- ===========================================================================

function Componentes.viewport(parent: Instance, size: UDim2?, orden: number?): ViewportFrame
	local v = Instance.new("ViewportFrame")
	v.Size = size or UDim2.fromScale(1, 1)
	v.BackgroundColor3 = Paleta.UI_PANEL
	v.BackgroundTransparency = 0
	v.BorderSizePixel = 0
	v.LayoutOrder = orden or 0
	v.Ambient = Color3.fromRGB(180, 180, 180)
	v.LightColor = Color3.fromRGB(255, 255, 255)
	v.LightDirection = Vector3.new(-1, -1.5, -1)
	Componentes.esquinas(v, 8)
	local cam = Instance.new("Camera")
	cam.Parent = v
	v.CurrentCamera = cam
	v.Parent = parent
	return v
end

-- Coloca el modelo y encuadra la camara. Devuelve el modelo (ya en el
-- viewport) para poder girarlo.
function Componentes.mostrarModelo(v: ViewportFrame, modelo: Model, giro: number?): Model
	for _, hijo in v:GetChildren() do
		if hijo:IsA("Model") then
			hijo:Destroy()
		end
	end
	modelo:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, giro or math.rad(-25), 0))
	modelo.Parent = v
	local cf, size = modelo:GetBoundingBox()
	local radio = math.max(size.X, size.Y, size.Z) * 0.62 + 0.6
	local cam = v.CurrentCamera
	if cam then
		local objetivo = cf.Position
		cam.CFrame = CFrame.lookAt(objetivo + Vector3.new(0, radio * 0.55, -radio * 2.1), objetivo)
		cam.FieldOfView = 40
	end
	return modelo
end

-- Primer boton seleccionable dentro de un contenedor (para gamepad)
function Componentes.primerSeleccionable(inst: Instance): GuiObject?
	for _, d in inst:GetDescendants() do
		if d:IsA("GuiButton") and d.Selectable and d.Visible then
			return d
		end
	end
	return nil
end

function Componentes.limpiar(inst: Instance)
	for _, hijo in inst:GetChildren() do
		if hijo:IsA("GuiObject") then
			hijo:Destroy()
		end
	end
end

return Componentes
