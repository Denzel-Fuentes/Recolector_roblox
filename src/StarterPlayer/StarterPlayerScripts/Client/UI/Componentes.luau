--!strict
--[[
	Componentes (ModuleScript)
	El "sistema de diseno" de la UI, en codigo. Tema "papel y tinta" (estilo
	pegatina, referencia KOTAMON): todo es papel crema con contorno de tinta y
	una sombra dura debajo; el color solo dice de que va cada cosa (Paleta).
	Toda pantalla del juego se monta con esto, asi el aspecto (colores, esquinas,
	fuentes, sombras) y la navegacion con gamepad se deciden UNA vez aqui.

	Pegatina = envoltorio transparente { Sombra, Cuerpo }. Un hijo no puede
	pintarse detras de su padre, asi que la sombra es HERMANA del cuerpo dentro
	de un envoltorio, que es lo que se coloca (y lo que ven los layouts). Los
	botones devuelven el CUERPO (TextButton) para que quien los crea siga
	tocando texto y nombre como antes; su envoltorio es boton.Parent.

	Iconos: icono() usa la imagen de Config/Iconos si hay id y, si no, la dibuja
	con Utilidades/Glifos: la UI esta terminada aunque el arte llegue despues.
	Insignias de tecla: letra en teclado, imagen del boton en gamepad
	(UserInputService:GetImageForKeyCode), nada en tactil.

	Tamanos: cada ScreenGui lleva un UIScale segun la altura de la pantalla
	(0.72-1.15; minimo 0.8 en tactil para que los botones sigan siendo dedo).
	disposicion() dice si la pantalla es "escritorio" o "tactil" (el pulgar del
	thumbstick y el boton de salto obligan a recolocar el HUD) y compacto() si el
	alto util de diseno baja de 560 px (telefono apaisado): los paneles pasan a
	una columna. alCambiarDisposicion avisa al cambiar el viewport o el tipo de
	entrada.

	Modales: el panel mide min(maximo de diseno, 94 % del viewport / escala),
	recalculado al cambiar el viewport, para caber en un telefono sin disenar
	dos veces.

	Gamepad: todo boton es Selectable (con contorno amarillo al elegirlo, sin
	el recuadro azul de Roblox) y los paneles exponen primerSeleccionable para
	que Menu ponga GuiService.SelectedObject al abrirlos.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local Iconos = require(Shared:WaitForChild("Config"):WaitForChild("Iconos"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Glifos = require(Utilidades:WaitForChild("Glifos"))
local Entrada = require(Utilidades:WaitForChild("Entrada"))
local Senal = require(Utilidades:WaitForChild("Senal"))

local Componentes = {}

Componentes.FUENTE_TITULO = Font.new("rbxasset://fonts/families/FredokaOne.json")
Componentes.FUENTE_CUERPO = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.SemiBold)
Componentes.FUENTE_CUERPO_NEGRITA = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)
-- Compatibilidad con codigo que aun asigna Enum.Font
Componentes.FUENTE = Enum.Font.Nunito
Componentes.FUENTE_NEGRITA = Enum.Font.FredokaOne
Componentes.RADIO = 12
Componentes.GROSOR = 2.5 -- contorno de tinta
Componentes.SOMBRA = 4 -- px que asoma la sombra por debajo

local jugador = Players.LocalPlayer
local playerGui = jugador:WaitForChild("PlayerGui")

-- Sustituye el recuadro azul de seleccion de Roblox: la seleccion se pinta con
-- el contorno del propio boton.
local SELECCION_INVISIBLE = Instance.new("ImageLabel")
SELECCION_INVISIBLE.BackgroundTransparency = 1
SELECCION_INVISIBLE.ImageTransparency = 1

-- ===========================================================================
-- Disposicion y escala
-- ===========================================================================

export type Disposicion = "escritorio" | "tactil"

Componentes.alCambiarDisposicion = Senal.nueva() :: Senal.Senal<nil>

local escalasRegistradas: { UIScale } = {}

local function viewport(): Vector2
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1600, 900)
end

function Componentes.disposicion(): Disposicion
	return if Entrada.esTactil() then "tactil" else "escritorio"
end

function Componentes.escala(): number
	local minimo = if Entrada.esTactil() then 0.8 else 0.72
	return math.clamp(viewport().Y / 900, minimo, 1.15)
end

-- Ancho y alto del viewport en px de DISENO (los que usan Size/Position)
function Componentes.disenoDisponible(): (number, number)
	local vp = viewport()
	local e = Componentes.escala()
	return vp.X / e, vp.Y / e
end

function Componentes.compacto(): boolean
	local _, alto = Componentes.disenoDisponible()
	return alto < 560
end

local refrescoPendiente = false
local function refrescarDisposicion()
	if refrescoPendiente then
		return
	end
	refrescoPendiente = true
	task.defer(function()
		refrescoPendiente = false
		local e = Componentes.escala()
		for i = #escalasRegistradas, 1, -1 do
			local s = escalasRegistradas[i]
			if s.Parent then
				s.Scale = e
			else
				table.remove(escalasRegistradas, i)
			end
		end
		Componentes.alCambiarDisposicion:Fire(nil)
	end)
end

do
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(refrescarDisposicion)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local nueva = workspace.CurrentCamera
		if nueva then
			nueva:GetPropertyChangedSignal("ViewportSize"):Connect(refrescarDisposicion)
		end
		refrescarDisposicion()
	end)
	UserInputService.LastInputTypeChanged:Connect(refrescarDisposicion)
end

-- Fuerza la plataforma (solo Studio) y avisa a toda la UI: para capturas
function Componentes.forzarPlataforma(plataforma: Entrada.Plataforma?)
	Entrada.forzar(plataforma)
	refrescarDisposicion()
end

function Componentes.pantalla(nombre: string, orden: number?): ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name = nombre
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = orden or 0
	local escala = Instance.new("UIScale")
	escala.Scale = Componentes.escala()
	escala.Parent = sg
	table.insert(escalasRegistradas, escala)
	sg.Parent = playerGui
	return sg
end

-- ===========================================================================
-- Basicos
-- ===========================================================================

function Componentes.esquinas(inst: Instance, radio: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radio or Componentes.RADIO)
	c.Parent = inst
	return c
end

-- Contorno de tinta (o del color que se pida)
function Componentes.borde(inst: Instance, color: Color3?, grosor: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Paleta.UI_TINTA
	s.Thickness = grosor or Componentes.GROSOR
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

-- Contorno del texto (las letras, no la caja)
function Componentes.contornoTexto(inst: Instance, color: Color3?, grosor: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Paleta.UI_TINTA
	s.Thickness = grosor or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
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

-- Texto tinta sobre colores claros, papel sobre oscuros
function Componentes.textoSobre(color: Color3): Color3
	local luminancia = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if luminancia < 0.5 then Paleta.UI_PAPEL else Paleta.UI_TINTA
end

-- ===========================================================================
-- Marco y texto
-- ===========================================================================

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
	Contorno: Color3?, -- contorno de tinta (o del color dado)
	Grosor: number?,
}

function Componentes.marco(p: PropsMarco): Frame
	local f = Instance.new("Frame")
	f.Name = p.Nombre or "Marco"
	f.Size = p.Size or UDim2.fromOffset(100, 100)
	f.Position = p.Position or UDim2.fromOffset(0, 0)
	f.AnchorPoint = p.Anchor or Vector2.zero
	f.BackgroundColor3 = p.Color or Paleta.UI_PAPEL_OSCURO
	f.BackgroundTransparency = p.Transparencia or 0
	f.BorderSizePixel = 0
	f.LayoutOrder = p.Orden or 0
	f.Visible = p.Visible ~= false
	if p.ZIndex then
		f.ZIndex = p.ZIndex
	end
	if (p.Radio or Componentes.RADIO) > 0 and ((p.Transparencia or 0) < 1 or p.Contorno) then
		Componentes.esquinas(f, p.Radio)
	end
	if p.Contorno then
		Componentes.borde(f, p.Contorno, p.Grosor)
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
	Titulo: boolean?, -- FredokaOne: numeros, titulos, etiquetas gritonas
	Contorno: Color3?, -- contorno de las letras
	Alinear: Enum.TextXAlignment?,
	AlinearY: Enum.TextYAlignment?,
	Ajustar: boolean?,
	Escalar: boolean?,
	Orden: number?,
	Fondo: Color3?,
	Rico: boolean?,
	ZIndex: number?,
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
		Componentes.esquinas(t, 8)
	end
	t.BorderSizePixel = 0
	t.TextColor3 = p.Color or Paleta.UI_TINTA
	-- En compacto (telefono) nada por debajo de 13 px de diseno
	t.TextSize = math.max(p.Tamano or 16, if Componentes.compacto() then 13 else 0)
	t.FontFace = if p.Titulo then Componentes.FUENTE_TITULO elseif p.Negrita then Componentes.FUENTE_CUERPO_NEGRITA else Componentes.FUENTE_CUERPO
	t.TextXAlignment = p.Alinear or Enum.TextXAlignment.Left
	t.TextYAlignment = p.AlinearY or Enum.TextYAlignment.Center
	t.TextWrapped = p.Ajustar ~= false
	t.TextScaled = p.Escalar == true
	t.RichText = p.Rico == true
	t.LayoutOrder = p.Orden or 0
	if p.ZIndex then
		t.ZIndex = p.ZIndex
	end
	if p.Contorno then
		Componentes.contornoTexto(t, p.Contorno, math.max(1.5, (p.Tamano or 16) * 0.1))
	end
	t.Parent = p.Parent
	return t
end

-- ===========================================================================
-- Pegatinas: envoltorio { Sombra, Cuerpo }
-- ===========================================================================

export type PropsPegatina = {
	Parent: Instance?,
	Nombre: string?,
	Size: UDim2?,
	Position: UDim2?,
	Anchor: Vector2?,
	Color: Color3?,
	Contorno: Color3?,
	Grosor: number?,
	Radio: number?,
	Orden: number?,
	Sombra: boolean?, -- false = sin sombra
	Visible: boolean?,
	ZIndex: number?,
}

local function envoltorio(p: PropsPegatina, nombre: string): (Frame, Frame?)
	local env = Instance.new("Frame")
	env.Name = p.Nombre or nombre
	env.Size = p.Size or UDim2.fromOffset(140, 40)
	env.Position = p.Position or UDim2.fromOffset(0, 0)
	env.AnchorPoint = p.Anchor or Vector2.zero
	env.BackgroundTransparency = 1
	env.BorderSizePixel = 0
	env.LayoutOrder = p.Orden or 0
	env.Visible = p.Visible ~= false
	if p.ZIndex then
		env.ZIndex = p.ZIndex
	end
	local sombra: Frame? = nil
	if p.Sombra ~= false then
		local s = Instance.new("Frame")
		s.Name = "Sombra"
		s.Size = UDim2.new(1, 0, 1, -Componentes.SOMBRA)
		s.Position = UDim2.fromOffset(0, Componentes.SOMBRA)
		s.BackgroundColor3 = Paleta.UI_SOMBRA
		s.BackgroundTransparency = 0.72
		s.BorderSizePixel = 0
		s.ZIndex = 1
		Componentes.esquinas(s, p.Radio)
		s.Parent = env
		sombra = s
	end
	env.Parent = p.Parent
	return env, sombra
end

-- Devuelve (envoltorio, cuerpo). Los hijos van en el cuerpo.
function Componentes.pegatina(p: PropsPegatina): (Frame, Frame)
	local env, sombra = envoltorio(p, "Pegatina")
	local cuerpo = Instance.new("Frame")
	cuerpo.Name = "Cuerpo"
	cuerpo.Size = if sombra then UDim2.new(1, 0, 1, -Componentes.SOMBRA) else UDim2.fromScale(1, 1)
	cuerpo.BackgroundColor3 = p.Color or Paleta.UI_PAPEL
	cuerpo.BorderSizePixel = 0
	cuerpo.ZIndex = 2
	Componentes.esquinas(cuerpo, p.Radio)
	Componentes.borde(cuerpo, p.Contorno, p.Grosor)
	cuerpo.Parent = env
	return env, cuerpo
end

-- ===========================================================================
-- Iconos e insignias
-- ===========================================================================

export type PropsIcono = {
	Parent: Instance?,
	Clave: string, -- clave de Config/Iconos y Utilidades/Glifos
	Tamano: number,
	Color: Color3?,
	Position: UDim2?,
	Anchor: Vector2?,
	Orden: number?,
	ZIndex: number?,
	Nombre: string?,
}

-- Imagen si hay id en Config/Iconos; si no, el glifo dibujado
function Componentes.icono(p: PropsIcono): GuiObject
	local id = Iconos.id(p.Clave)
	local obj: GuiObject
	if id then
		local img = Instance.new("ImageLabel")
		img.Image = id
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		if p.Color then
			img.ImageColor3 = p.Color
		end
		img.Size = UDim2.fromOffset(p.Tamano, p.Tamano)
		obj = img
	else
		obj = Glifos.dibujar(p.Clave, p.Tamano, p.Color)
	end
	obj.Name = p.Nombre or ("Icono_" .. p.Clave)
	obj.Position = p.Position or UDim2.fromOffset(0, 0)
	obj.AnchorPoint = p.Anchor or Vector2.zero
	obj.LayoutOrder = p.Orden or 0
	if p.ZIndex then
		obj.ZIndex = p.ZIndex
	end
	obj.Parent = p.Parent
	return obj
end

export type PropsInsignia = {
	Parent: Instance?,
	Teclado: string, -- "F", "Q", "E", "CLIC"...
	Gamepad: Enum.KeyCode?,
	Tamano: number?, -- alto en px (el ancho crece con el texto)
	Position: UDim2?,
	Anchor: Vector2?,
	Orden: number?,
	ZIndex: number?,
	Nombre: string?,
}

-- Las insignias se refrescan al cambiar de plataforma; clave debil para que
-- las de paneles repintados se vayan solas.
local insignias: { [Frame]: () -> () } = setmetatable({}, { __mode = "k" }) :: any

Componentes.alCambiarDisposicion:Connect(function()
	for marco, refrescar in insignias do
		if marco.Parent then
			refrescar()
		end
	end
end)

-- Badge de tecla: letra en teclado, imagen del boton en gamepad, oculta en tactil
function Componentes.insignia(p: PropsInsignia): Frame
	local alto = p.Tamano or 24
	local marco = Instance.new("Frame")
	marco.Name = p.Nombre or "Insignia"
	marco.Size = UDim2.fromOffset(alto, alto)
	marco.AutomaticSize = Enum.AutomaticSize.X
	marco.Position = p.Position or UDim2.fromOffset(0, 0)
	marco.AnchorPoint = p.Anchor or Vector2.zero
	marco.BackgroundColor3 = Paleta.UI_TECLA
	marco.BorderSizePixel = 0
	marco.LayoutOrder = p.Orden or 0
	if p.ZIndex then
		marco.ZIndex = p.ZIndex
	end
	Componentes.esquinas(marco, math.floor(alto * 0.28))
	Componentes.borde(marco, Paleta.UI_PAPEL, 1.5)
	local letra = Instance.new("TextLabel")
	letra.Name = "Letra"
	letra.Size = UDim2.new(0, 0, 1, 0)
	letra.AutomaticSize = Enum.AutomaticSize.X
	letra.BackgroundTransparency = 1
	letra.Text = p.Teclado
	letra.TextColor3 = Paleta.UI_PAPEL
	letra.TextSize = math.floor(alto * 0.58)
	letra.FontFace = Componentes.FUENTE_TITULO
	letra.ZIndex = marco.ZIndex + 1
	letra.Parent = marco
	local relleno = Instance.new("UIPadding")
	relleno.PaddingLeft = UDim.new(0, math.floor(alto * 0.25))
	relleno.PaddingRight = UDim.new(0, math.floor(alto * 0.25))
	relleno.Parent = letra
	local imagen = Instance.new("ImageLabel")
	imagen.Name = "Boton"
	imagen.Size = UDim2.fromOffset(alto, alto)
	imagen.BackgroundTransparency = 1
	imagen.ScaleType = Enum.ScaleType.Fit
	imagen.ZIndex = marco.ZIndex + 1
	imagen.Visible = false
	imagen.Parent = marco
	local function refrescar()
		local plataforma = Entrada.plataforma()
		if plataforma == "gamepad" and p.Gamepad then
			imagen.Image = UserInputService:GetImageForKeyCode(p.Gamepad)
			imagen.Visible = true
			letra.Visible = false
			marco.BackgroundTransparency = 1
			marco.Visible = true
		else
			imagen.Visible = false
			letra.Visible = true
			marco.BackgroundTransparency = 0
			marco.Visible = plataforma ~= "tactil"
		end
	end
	insignias[marco] = refrescar
	refrescar()
	marco.Parent = p.Parent
	return marco
end

-- ===========================================================================
-- Boton
-- ===========================================================================

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
	Icono: string?, -- clave de icono a la izquierda del texto
	Sombra: boolean?,
	ZIndex: number?,
	Visible: boolean?,
}

local function aplicarEstadoBoton(b: TextButton, deshabilitado: boolean, base: Color3, colorTexto: Color3)
	local env = b.Parent
	local sombra = if env then env:FindFirstChild("Sombra") else nil
	if deshabilitado then
		b.BackgroundColor3 = Paleta.UI_BLOQUEADO
		b.TextColor3 = Paleta.UI_TINTA_SUAVE
		if sombra and sombra:IsA("Frame") then
			sombra.Visible = false
		end
	else
		b.BackgroundColor3 = base
		b.TextColor3 = colorTexto
		if sombra and sombra:IsA("Frame") then
			sombra.Visible = true
		end
	end
	b.Selectable = not deshabilitado
end

-- Devuelve el TextButton (cuerpo); su envoltorio (con la sombra) es .Parent
function Componentes.boton(p: PropsBoton): TextButton
	local env, sombra = envoltorio({
		Parent = p.Parent,
		Nombre = p.Nombre or "Boton",
		Size = p.Size or UDim2.fromOffset(140, 40),
		Position = p.Position,
		Anchor = p.Anchor,
		Radio = p.Radio,
		Orden = p.Orden,
		Sombra = p.Sombra,
		ZIndex = p.ZIndex,
		Visible = p.Visible,
	}, "Boton")
	local base = p.Color or Paleta.UI_PAPEL
	local colorTexto = p.ColorTexto or Componentes.textoSobre(base)
	local b = Instance.new("TextButton")
	b.Name = p.Nombre or "Boton"
	b.Text = p.Texto or ""
	b.Size = if sombra then UDim2.new(1, 0, 1, -Componentes.SOMBRA) else UDim2.fromScale(1, 1)
	b.BackgroundColor3 = base
	b.BorderSizePixel = 0
	b.TextColor3 = colorTexto
	b.TextSize = p.Tamano or 16
	b.FontFace = Componentes.FUENTE_TITULO
	b.AutoButtonColor = false
	b.Selectable = true
	b.SelectionImageObject = SELECCION_INVISIBLE
	b.TextWrapped = true
	b.ZIndex = 2
	Componentes.esquinas(b, p.Radio)
	local contorno = Componentes.borde(b)
	if p.Icono then
		-- El icono va en el envoltorio, no en el boton: el UIPadding que aparta
		-- el texto desplazaria tambien al icono y quedarian uno encima del otro.
		local alto = (p.Size or UDim2.fromOffset(140, 40)).Y.Offset - (if sombra then Componentes.SOMBRA else 0)
		local lado = math.max(16, math.floor(alto * 0.6))
		Componentes.icono({ Parent = env, Clave = p.Icono, Tamano = lado, Position = UDim2.new(0, 8, 0, alto / 2), Anchor = Vector2.new(0, 0.5), ZIndex = 3 })
		b.TextXAlignment = Enum.TextXAlignment.Left
		local relleno = Instance.new("UIPadding")
		relleno.PaddingLeft = UDim.new(0, lado + 14)
		relleno.PaddingRight = UDim.new(0, 8)
		relleno.Parent = b
	end
	-- La escala del hover va en el cuerpo, no en el envoltorio: el envoltorio es
	-- lo que miden los layouts y no debe cambiar de tamano al pasar el raton.
	local escala = Instance.new("UIScale")
	escala.Parent = b
	local abajo = UDim2.fromOffset(0, if sombra then Componentes.SOMBRA else 0)
	local arriba = UDim2.fromOffset(0, 0)
	b.Parent = env

	local function habilitado(): boolean
		return not p.Deshabilitado and b.Selectable
	end
	aplicarEstadoBoton(b, p.Deshabilitado == true, base, colorTexto)

	b.MouseEnter:Connect(function()
		if habilitado() then
			TweenService:Create(escala, TweenInfo.new(0.08), { Scale = 1.04 }):Play()
		end
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(escala, TweenInfo.new(0.08), { Scale = 1 }):Play()
		b.Position = arriba
	end)
	b.MouseButton1Down:Connect(function()
		if habilitado() then
			b.Position = abajo
		end
	end)
	b.MouseButton1Up:Connect(function()
		b.Position = arriba
	end)
	b.SelectionGained:Connect(function()
		if habilitado() then
			contorno.Color = Paleta.UI_SELECCION
			contorno.Thickness = Componentes.GROSOR + 2
		end
	end)
	b.SelectionLost:Connect(function()
		contorno.Color = Paleta.UI_TINTA
		contorno.Thickness = Componentes.GROSOR
	end)
	b.Activated:Connect(function()
		if not habilitado() then
			return
		end
		b.Position = abajo
		task.delay(0.07, function()
			if b.Parent then
				b.Position = arriba
			end
		end)
		if p.alPulsar then
			p.alPulsar()
		end
	end)
	-- Quien oculte el cuerpo oculta la pegatina entera
	b:GetPropertyChangedSignal("Visible"):Connect(function()
		env.Visible = b.Visible
	end)
	return b
end

function Componentes.deshabilitar(b: TextButton, deshabilitado: boolean, colorBase: Color3?)
	b.Active = not deshabilitado
	local base = colorBase or Paleta.UI_PAPEL
	aplicarEstadoBoton(b, deshabilitado, base, Componentes.textoSobre(base))
end

-- Envoltorio de un boton (para colocarlo o cambiarle el tamano)
function Componentes.envoltorioDe(b: GuiObject): GuiObject
	local env = b.Parent
	return if env and env:IsA("GuiObject") then env else b
end

-- ===========================================================================
-- Pildora (HUD) y circulo con icono
-- ===========================================================================

export type PropsPildora = {
	Parent: Instance?,
	Nombre: string?,
	Icono: string,
	Color: Color3, -- del numero y del icono dibujado
	Ancho: number,
	Alto: number?,
	Orden: number?,
	Texto: string?,
	Position: UDim2?,
	Anchor: Vector2?,
}

-- Pegatina horizontal con icono a la izquierda y un numero gordo. Devuelve
-- (envoltorio, texto).
function Componentes.pildora(p: PropsPildora): (Frame, TextLabel)
	local alto = p.Alto or 46
	local env, cuerpo = Componentes.pegatina({
		Parent = p.Parent,
		Nombre = p.Nombre or ("Pildora_" .. p.Icono),
		Size = UDim2.fromOffset(p.Ancho, alto),
		Position = p.Position,
		Anchor = p.Anchor,
		Radio = math.floor(alto * 0.36),
		Orden = p.Orden,
	})
	local lado = alto - 14
	Componentes.icono({ Parent = cuerpo, Clave = p.Icono, Tamano = lado, Position = UDim2.new(0, 8, 0.5, 0), Anchor = Vector2.new(0, 0.5), ZIndex = 3 })
	local t = Componentes.texto({
		Parent = cuerpo,
		Texto = p.Texto or "",
		Size = UDim2.new(1, -(lado + 22), 1, 0),
		Position = UDim2.fromOffset(lado + 16, 0),
		Tamano = math.floor(alto * 0.5),
		Titulo = true,
		Color = p.Color,
		Contorno = Paleta.UI_TINTA,
		ZIndex = 3,
	})
	return env, t
end

export type PropsCirculo = {
	Parent: Instance?,
	Nombre: string?,
	Clave: string,
	Diametro: number,
	Color: Color3?, -- fondo del circulo
	ColorIcono: Color3?,
	Position: UDim2?,
	Anchor: Vector2?,
	Orden: number?,
	ZIndex: number?,
	Sombra: boolean?,
}

-- Circulo-pegatina con un icono centrado (bases de las barras, boton tactil)
function Componentes.circuloIcono(p: PropsCirculo): (Frame, Frame)
	local env, cuerpo = Componentes.pegatina({
		Parent = p.Parent,
		Nombre = p.Nombre or ("Circulo_" .. p.Clave),
		Size = UDim2.fromOffset(p.Diametro, p.Diametro),
		Position = p.Position,
		Anchor = p.Anchor,
		Color = p.Color,
		Radio = math.ceil(p.Diametro / 2),
		Orden = p.Orden,
		ZIndex = p.ZIndex,
		Sombra = p.Sombra,
	})
	Componentes.icono({ Parent = cuerpo, Clave = p.Clave, Tamano = math.floor(p.Diametro * 0.62), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), Color = p.ColorIcono, ZIndex = 3 })
	return env, cuerpo
end

-- ===========================================================================
-- Barra horizontal de progreso
-- ===========================================================================

export type Barra = {
	marco: Frame,
	fijar: (fraccion: number, texto: string?) -> (),
}

function Componentes.barra(parent: Instance, size: UDim2, color: Color3, orden: number?): Barra
	local marco = Componentes.marco({ Parent = parent, Size = size, Color = Paleta.UI_PAPEL_SOMBRA, Radio = 8, Orden = orden, Contorno = Paleta.UI_TINTA, Grosor = 2 })
	local relleno = Componentes.marco({ Parent = marco, Size = UDim2.new(0, 0, 1, -4), Position = UDim2.fromOffset(2, 2), Color = color, Radio = 6, Nombre = "Relleno" })
	local etiqueta = Componentes.texto({ Parent = marco, Size = UDim2.fromScale(1, 1), Alinear = Enum.TextXAlignment.Center, Tamano = 13, Titulo = true, ZIndex = 3 })
	return {
		marco = marco,
		fijar = function(fraccion: number, texto: string?)
			fraccion = math.clamp(fraccion, 0, 1)
			TweenService:Create(relleno, TweenInfo.new(0.2), { Size = UDim2.new(fraccion, if fraccion > 0 then -4 else 0, 1, -4) }):Play()
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
	s.ScrollBarThickness = if Entrada.esTactil() then 4 else 6
	s.ScrollBarImageColor3 = Paleta.UI_TINTA_SUAVE
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.fromScale(0, 0)
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.Parent = parent
	return s
end

-- ===========================================================================
-- Pestanas de libreta
-- ===========================================================================

export type Pestanas = {
	barra: Frame,
	seleccionar: (indice: number) -> (),
	botones: { TextButton },
}

-- Pestanas pegadas al borde superior del contenido, como una libreta: la
-- elegida sube y toma su color; las demas quedan hundidas en papel-sombra.
-- Las esquinas de abajo se recortan con ClipsDescendants de la barra.
function Componentes.pestanas(parent: Instance, nombres: { string }, alCambiar: (indice: number) -> (), orden: number?, colores: { Color3 }?): Pestanas
	local ALTO = 40
	local barra = Componentes.marco({ Parent = parent, Size = UDim2.new(1, 0, 0, ALTO), Transparencia = 1, Orden = orden, Nombre = "Pestanas" })
	barra.ClipsDescendants = true
	Componentes.lista(barra, 6, true)
	local botones = {}
	local function seleccionar(i: number)
		for j, b in botones do
			local elegida = j == i
			local color = if elegida then ((colores and colores[j]) or Paleta.UI_PRIMARIO) else Paleta.UI_PAPEL_SOMBRA
			b.BackgroundColor3 = color
			b.TextColor3 = if elegida then Componentes.textoSobre(color) else Paleta.UI_TINTA_SUAVE
			b.Position = UDim2.fromOffset(0, if elegida then 0 else 6)
			b.ZIndex = if elegida then 3 else 2
		end
		alCambiar(i)
	end
	for i, nombre in nombres do
		local hueco = Componentes.marco({ Parent = barra, Size = UDim2.new(1 / #nombres, -6, 1, 0), Transparencia = 1, Orden = i, Nombre = "Hueco" .. i })
		local b = Instance.new("TextButton")
		b.Name = "Pestana_" .. nombre
		b.Text = nombre
		b.Size = UDim2.new(1, 0, 1, 12)
		b.BackgroundColor3 = Paleta.UI_PAPEL_SOMBRA
		b.BorderSizePixel = 0
		b.TextColor3 = Paleta.UI_TINTA_SUAVE
		b.FontFace = Componentes.FUENTE_TITULO
		b.TextScaled = true
		b.AutoButtonColor = false
		b.Selectable = true
		b.SelectionImageObject = SELECCION_INVISIBLE
		b.LayoutOrder = i
		Componentes.esquinas(b, 12)
		local contorno = Componentes.borde(b)
		local limite = Instance.new("UITextSizeConstraint")
		limite.MinTextSize = 10
		limite.MaxTextSize = 16
		limite.Parent = b
		local relleno = Instance.new("UIPadding")
		relleno.PaddingLeft = UDim.new(0, 8)
		relleno.PaddingRight = UDim.new(0, 8)
		relleno.PaddingBottom = UDim.new(0, 12)
		relleno.Parent = b
		b.SelectionGained:Connect(function()
			contorno.Color = Paleta.UI_SELECCION
			contorno.Thickness = Componentes.GROSOR + 2
		end)
		b.SelectionLost:Connect(function()
			contorno.Color = Paleta.UI_TINTA
			contorno.Thickness = Componentes.GROSOR
		end)
		b.Activated:Connect(function()
			seleccionar(i)
		end)
		b.Parent = hueco
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

-- ancho/alto son el MAXIMO de diseno: en pantallas pequenas el panel se
-- encoge al 94 % del viewport (el contenido esta en Scale y se adapta).
function Componentes.modal(nombre: string, tituloTexto: string, ancho: number, alto: number): Modal
	local pantalla = Componentes.pantalla(nombre, 10)
	pantalla.Enabled = false
	local fondo = Componentes.marco({ Parent = pantalla, Size = UDim2.fromScale(1, 1), Color = Paleta.UI_TINTA, Transparencia = 0.5, Radio = 0, Nombre = "Fondo" })
	local sombra = Componentes.marco({
		Parent = fondo,
		Size = UDim2.fromOffset(ancho, alto),
		Position = UDim2.new(0.5, 0, 0.5, 8),
		Anchor = Vector2.new(0.5, 0.5),
		Color = Paleta.UI_SOMBRA,
		Transparencia = 0.6,
		Radio = 20,
		Nombre = "Sombra",
		ZIndex = 1,
	})
	local panel = Componentes.marco({
		Parent = fondo,
		Size = UDim2.fromOffset(ancho, alto),
		Position = UDim2.fromScale(0.5, 0.5),
		Anchor = Vector2.new(0.5, 0.5),
		Color = Paleta.UI_PAPEL,
		Radio = 20,
		Nombre = "Panel",
		ZIndex = 2,
		Contorno = Paleta.UI_TINTA,
		Grosor = 3,
	})
	local escalaPanel = Instance.new("UIScale")
	escalaPanel.Parent = panel

	-- Titulo en una cinta inclinada que asoma por el borde superior
	local cinta = Componentes.marco({
		Parent = panel,
		Size = UDim2.fromOffset(0, 44),
		Position = UDim2.fromOffset(22, -16),
		Color = Paleta.UI_PRIMARIO,
		Radio = 12,
		Nombre = "Cinta",
		ZIndex = 4,
		Contorno = Paleta.UI_TINTA,
	})
	cinta.AutomaticSize = Enum.AutomaticSize.X
	cinta.Rotation = -2
	local titulo = Componentes.texto({ Parent = cinta, Texto = tituloTexto, Size = UDim2.new(0, 0, 1, 0), Tamano = 22, Titulo = true, ZIndex = 5, Ajustar = false })
	titulo.AutomaticSize = Enum.AutomaticSize.X
	Componentes.padding(titulo, 16, 0)

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
		Parent = panel,
		Nombre = "Cerrar",
		Texto = "X", -- FredokaOne no trae la cruz tipografica (sale fina y casi invisible): una X gorda si
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, 8, 0, -14),
		Anchor = Vector2.new(1, 0),
		Color = Paleta.UI_PELIGRO,
		ColorTexto = Paleta.UI_PAPEL,
		Tamano = 22,
		Radio = 24,
		ZIndex = 4,
		alPulsar = cerrar,
	})
	local contenido = Componentes.marco({ Parent = panel, Size = UDim2.new(1, -24, 1, -68), Position = UDim2.fromOffset(12, 56), Transparencia = 1, Nombre = "Contenido", ZIndex = 3 })

	local function ajustar()
		local dw, dh = Componentes.disenoDisponible()
		local w = math.min(ancho, math.floor(dw * 0.94))
		local h = math.min(alto, math.floor(dh * 0.9))
		panel.Size = UDim2.fromOffset(w, h)
		sombra.Size = UDim2.fromOffset(w, h)
	end
	Componentes.alCambiarDisposicion:Connect(ajustar)
	ajustar()

	local function abrir()
		estado.abierto = true
		ajustar()
		pantalla.Enabled = true
		escalaPanel.Scale = 0.94
		TweenService:Create(escalaPanel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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
	v.BackgroundColor3 = Paleta.UI_PAPEL_OSCURO
	v.BackgroundTransparency = 0
	v.BorderSizePixel = 0
	v.LayoutOrder = orden or 0
	v.Ambient = Color3.fromRGB(205, 205, 205)
	v.LightColor = Color3.fromRGB(255, 255, 255)
	v.LightDirection = Vector3.new(-1, -1.5, -1)
	Componentes.esquinas(v, 10)
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
