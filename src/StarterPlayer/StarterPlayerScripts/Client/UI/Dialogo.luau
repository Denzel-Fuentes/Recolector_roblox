--!strict
--[[
	Dialogo (ModuleScript)
	La caja de dialogo de Dona Chatarra (y de cualquier NPC): abajo-centro,
	retrato a la izquierda, nombre en una cinta y el texto. Antes era un toast;
	con retrato se lee como una conversacion, que es lo que hace Jenny en
	KOTAMON.

	Retrato: la imagen `retratoChatarra` de Config/Iconos si existe; si no, el
	modelo whitebox del NPC (atributo NPC en workspace.Mundo) clonado en un
	ViewportFrame, sin sus prompts ni carteles.

	Se cierra al tocarla, con Esc / ButtonB, o sola pasado un tiempo que crece
	con el largo del texto; los mensajes hacen cola para no pisarse. No es un
	panel de Menu (no bloquea el juego ni libera el raton): escucha el input
	ella misma.

	  Dialogo.mostrar(idNpc, texto, alSeguir?)   alSeguir corre al descartarlo a mano
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local Iconos = require(Config:WaitForChild("Iconos"))
local Entrada = require(Shared:WaitForChild("Utilidades"):WaitForChild("Entrada"))

local Componentes = require(script.Parent:WaitForChild("Componentes"))

local Dialogo = {}

-- Se cierra solo tras un tiempo proporcional al texto (leer ~14 caracteres/s,
-- con un minimo para los cortos)
local DURACION_MINIMA = 5
local SEGUNDOS_POR_CARACTER = 0.07
local ANCHO, ALTO = 640, 132
local RETRATO = 108

local pantalla = Componentes.pantalla("Dialogo", 8)

local envoltorio, cuerpo = Componentes.pegatina({
	Parent = pantalla,
	Nombre = "Caja",
	Size = UDim2.fromOffset(ANCHO, ALTO),
	Position = UDim2.new(0.5, 0, 1, -24),
	Anchor = Vector2.new(0.5, 1),
	Radio = 18,
	Grosor = 3,
})
envoltorio.Visible = false

-- Retrato: circulo que asoma por la izquierda de la caja
local marcoRetrato, cuerpoRetrato = Componentes.pegatina({
	Parent = envoltorio,
	Nombre = "Retrato",
	Size = UDim2.fromOffset(RETRATO, RETRATO),
	Position = UDim2.new(0, -RETRATO * 0.35, 0.5, 0),
	Anchor = Vector2.new(0, 0.5),
	Radio = RETRATO / 2,
	ZIndex = 5,
	Color = Paleta.UI_PAPEL_OSCURO,
})
cuerpoRetrato.ClipsDescendants = true
local viewport = Componentes.viewport(cuerpoRetrato, UDim2.new(1, -6, 1, -6))
viewport.Position = UDim2.fromScale(0.5, 0.5)
viewport.AnchorPoint = Vector2.new(0.5, 0.5)
viewport.BackgroundTransparency = 1
viewport.ZIndex = 6
Componentes.esquinas(viewport, RETRATO)
local imagenRetrato = Instance.new("ImageLabel")
imagenRetrato.Name = "Imagen"
imagenRetrato.Size = UDim2.new(1, -6, 1, -6)
imagenRetrato.Position = UDim2.fromScale(0.5, 0.5)
imagenRetrato.AnchorPoint = Vector2.new(0.5, 0.5)
imagenRetrato.BackgroundTransparency = 1
imagenRetrato.ScaleType = Enum.ScaleType.Crop
imagenRetrato.ZIndex = 6
imagenRetrato.Visible = false
Componentes.esquinas(imagenRetrato, RETRATO)
imagenRetrato.Parent = cuerpoRetrato

-- Nombre en cinta y texto
local cinta = Componentes.marco({ Parent = cuerpo, Size = UDim2.fromOffset(0, 32), Position = UDim2.fromOffset(RETRATO * 0.75, -14), Color = Paleta.UI_PRIMARIO, Radio = 10, Contorno = Paleta.UI_TINTA, ZIndex = 4, Nombre = "Cinta" })
cinta.AutomaticSize = Enum.AutomaticSize.X
cinta.Rotation = -2
local nombre = Componentes.texto({ Parent = cinta, Size = UDim2.new(0, 0, 1, 0), Tamano = 17, Titulo = true, Ajustar = false, ZIndex = 5 })
nombre.AutomaticSize = Enum.AutomaticSize.X
Componentes.padding(nombre, 12, 0)

local texto = Componentes.texto({
	Parent = cuerpo,
	Size = UDim2.new(1, -RETRATO * 0.75 - 24, 1, -46),
	Position = UDim2.fromOffset(RETRATO * 0.75 + 4, 26),
	Tamano = 17,
	Negrita = true,
	AlinearY = Enum.TextYAlignment.Top,
	ZIndex = 4,
})
local pie = Componentes.texto({
	Parent = cuerpo,
	Size = UDim2.new(1, -24, 0, 16),
	Position = UDim2.new(1, -12, 1, -6),
	Anchor = Vector2.new(1, 1),
	Tamano = 11,
	Alinear = Enum.TextXAlignment.Right,
	Color = Paleta.UI_TINTA_SUAVE,
	ZIndex = 4,
})

-- Toda la caja es un boton: tocarla la cierra
local tapa = Instance.new("TextButton")
tapa.Name = "Tapa"
tapa.Text = ""
tapa.BackgroundTransparency = 1
tapa.Size = UDim2.fromScale(1, 1)
tapa.ZIndex = 7
tapa.Selectable = false
tapa.Parent = cuerpo

-- ===========================================================================
-- Retrato del NPC
-- ===========================================================================

local retratoCargado: string? = nil

local function modeloNPC(idNpc: string): Model?
	local mundo = workspace:FindFirstChild("Mundo")
	if not mundo then
		return nil
	end
	for _, d in mundo:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("NPC") == idNpc then
			return d
		end
	end
	return nil
end

local function cargarRetrato(idNpc: string)
	if retratoCargado == idNpc then
		return
	end
	local imagen = Iconos.id("retratoChatarra")
	if imagen then
		imagenRetrato.Image = imagen
		imagenRetrato.Visible = true
		viewport.Visible = false
		retratoCargado = idNpc
		return
	end
	local original = modeloNPC(idNpc)
	if not original then
		return
	end
	local copia = original:Clone()
	for _, d in copia:GetDescendants() do
		if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
			d:Destroy()
		end
	end
	-- Encuadre de busto: la camara mira a la cabeza, de frente
	Componentes.mostrarModelo(viewport, copia, math.rad(180))
	local cam = viewport.CurrentCamera
	local cabeza = copia:FindFirstChild("Cabeza")
	if cam and cabeza and cabeza:IsA("BasePart") then
		local objetivo = cabeza.Position - Vector3.new(0, 0.6, 0)
		-- La cara esta en +Z local de la cabeza (ArteMundo.vestirChatarra): la
		-- camara se pone delante de ella, mire a donde mire el NPC en el mundo
		cam.CFrame = CFrame.lookAt((cabeza.CFrame * CFrame.new(0, -0.3, 5.2)).Position, objetivo)
		cam.FieldOfView = 40
	end
	viewport.Visible = true
	imagenRetrato.Visible = false
	retratoCargado = idNpc
end

-- ===========================================================================
-- Cola y apertura
-- ===========================================================================

local NOMBRES = {
	DonaChatarra = Textos.DIALOGO.chatarra,
}

-- alSeguir: lo que pasa cuando el jugador DESCARTA el mensaje a mano (tocar,
-- Esc, B), p. ej. abrir la tienda tras el saludo de Dona Chatarra, como Jenny
-- en KOTAMON. Si el mensaje se cierra solo por tiempo no se llama: abrir un
-- panel sin que nadie lo pida seria un susto.
type Mensaje = { idNpc: string, texto: string, alSeguir: (() -> ())? }
local cola: { Mensaje } = {}
local abierto = false
local numero = 0
local actual: Mensaje? = nil

local function ocultar()
	if not abierto then
		return
	end
	abierto = false
	numero += 1
	local t = TweenService:Create(envoltorio, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 1, ALTO + 40) })
	t:Play()
	t.Completed:Wait()
	if not abierto then
		envoltorio.Visible = false
	end
end

local mostrarSiguiente: () -> ()

local function mostrarAhora(m: Mensaje)
	abierto = true
	actual = m
	numero += 1
	local mio = numero
	cargarRetrato(m.idNpc)
	nombre.Text = NOMBRES[m.idNpc] or m.idNpc
	texto.Text = m.texto
	pie.Text = if Entrada.esTactil() then Textos.DIALOGO.continuar else (Textos.DIALOGO.continuar .. "  ·  Esc")
	envoltorio.Visible = true
	envoltorio.Position = UDim2.new(0.5, 0, 1, ALTO + 40)
	TweenService:Create(envoltorio, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 1, -24) }):Play()
	task.delay(DURACION_MINIMA + SEGUNDOS_POR_CARACTER * #m.texto, function()
		if abierto and numero == mio then
			ocultar()
			mostrarSiguiente()
		end
	end)
end

mostrarSiguiente = function()
	local siguiente = table.remove(cola, 1)
	if siguiente then
		mostrarAhora(siguiente)
	end
end

function Dialogo.mostrar(idNpc: string, textoMensaje: string, alSeguir: (() -> ())?)
	table.insert(cola, { idNpc = idNpc, texto = textoMensaje, alSeguir = alSeguir })
	if not abierto then
		mostrarSiguiente()
	end
end

-- Descarte a mano: cierra y ejecuta lo que siga
function Dialogo.cerrar()
	if abierto then
		local m = actual
		ocultar()
		mostrarSiguiente()
		if m and m.alSeguir then
			m.alSeguir()
		end
	end
end

function Dialogo.estaAbierto(): boolean
	return abierto
end

tapa.Activated:Connect(Dialogo.cerrar)
UserInputService.InputBegan:Connect(function(input, procesado)
	if procesado or not abierto then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		Dialogo.cerrar()
	end
end)

return Dialogo
