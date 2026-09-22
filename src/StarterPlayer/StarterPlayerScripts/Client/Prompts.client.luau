--!strict
--[[
	Prompts
	Los ProximityPrompts que SOLO abren interfaz se atienden en el cliente, sin
	pasar por el servidor: los muebles de la parcela (atributo Mueble) y el
	dialogo de Dona Chatarra (DialogoEvent, que el servidor manda tras el
	prompt "Hablar").

	  Telefono        -> Tienda
	  Almacen         -> Album
	  MesaReparacion  -> Reparacion
	  Estanteria / Radio / Exhibidor -> Base (en esa pestana)

	Solo en TU parcela. En la de otro, el prompt muestra de quien es: visitar
	es mirar, no tocar (GDD: like/visita, sin edicion ajena).

	=== Estilo ===
	Todos los ProximityPrompts del mundo se pintan aqui como pegatinas de papel
	y tinta en vez de con el estilo por defecto de Roblox: al aparecer uno
	(PromptShown) se monta un BillboardGui en la parte con la insignia de la
	tecla (letra en teclado, imagen del boton en gamepad, una mano en tactil),
	la accion en grande y el objeto en pequeno, y una barra que se llena
	mientras se mantiene (PromptButtonHoldBegan/Ended). En tactil la pegatina
	entera es el boton (InputHoldBegin/End). Style = Custom se pone LOCALMENTE
	a cada prompt (pasada inicial + DescendantAdded): asi no hay que re-hornear
	el mundo ni tocar el servidor, y PromptTriggered sigue igual.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local UI = script.Parent:WaitForChild("UI")
local Menu = require(UI:WaitForChild("Menu"))
local Componentes = require(UI:WaitForChild("Componentes"))
local Notificaciones = require(UI:WaitForChild("Notificaciones"))
local Dialogo = require(UI:WaitForChild("Dialogo"))

local jugador = Players.LocalPlayer

-- ===========================================================================
-- Estilo de los prompts
-- ===========================================================================

local function personalizar(inst: Instance)
	if inst:IsA("ProximityPrompt") then
		inst.Style = Enum.ProximityPromptStyle.Custom
	end
end
for _, d in workspace:GetDescendants() do
	personalizar(d)
end
workspace.DescendantAdded:Connect(personalizar)

local ANCHO_PROMPT, ALTO_PROMPT = 300, 66
local INSIGNIA = 36

-- Altura a la que flota la pegatina sobre la parte del prompt: por encima de
-- lo mas alto entre la parte y su modelo (el prompt de un monton cuelga de la
-- base de la colina, y la pegatina tiene que asomar por encima de la loma).
local function alturaSobre(parte: Instance): number
	if not parte:IsA("BasePart") then
		return 3
	end
	local tope = parte.Position.Y + parte.Size.Y / 2
	local modelo = parte.Parent
	if modelo and modelo:IsA("Model") then
		local cf, tamano = modelo:GetBoundingBox()
		tope = math.max(tope, cf.Position.Y + tamano.Y / 2)
	end
	return tope - parte.Position.Y + 1.2
end

local function montarPrompt(prompt: ProximityPrompt, tipoEntrada: Enum.ProximityPromptInputType): (BillboardGui, { RBXScriptConnection })
	-- Va dentro de la propia parte y SIN AlwaysOnTop: medido en Studio, con
	-- AlwaysOnTop (y/o en PlayerGui) la pegatina no se pintaba. Como flota por
	-- encima del tope del modelo, nada la tapa.
	local bb = Instance.new("BillboardGui")
	bb.Name = "Prompt"
	bb.Adornee = prompt.Parent :: any
	bb.Size = UDim2.fromOffset(ANCHO_PROMPT, ALTO_PROMPT)
	bb.StudsOffsetWorldSpace = Vector3.new(0, alturaSobre(prompt.Parent), 0)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.Active = true
	bb.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	bb.Parent = prompt.Parent

	-- El cuerpo es un boton: en tactil se mantiene pulsado
	local cuerpo = Instance.new("TextButton")
	cuerpo.Name = "Cuerpo"
	cuerpo.Text = ""
	cuerpo.Size = UDim2.new(1, 0, 1, -4)
	cuerpo.BackgroundColor3 = Paleta.UI_PAPEL
	cuerpo.BorderSizePixel = 0
	cuerpo.AutoButtonColor = false
	cuerpo.Selectable = false
	cuerpo.ZIndex = 2
	Componentes.esquinas(cuerpo, 18)
	Componentes.borde(cuerpo, Paleta.UI_TINTA, 3)
	local sombra = Componentes.marco({ Parent = bb, Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 4), Color = Paleta.UI_SOMBRA, Transparencia = 0.72, Radio = 18, Nombre = "Sombra", ZIndex = 1 })
	sombra.ZIndex = 1
	cuerpo.Parent = bb

	-- Insignia: letra, imagen del boton o la mano
	local insignia = Componentes.marco({ Parent = cuerpo, Size = UDim2.fromOffset(INSIGNIA, INSIGNIA), Position = UDim2.new(0, 12, 0.5, 0), Anchor = Vector2.new(0, 0.5), Color = Paleta.UI_TECLA, Radio = 10, Nombre = "Insignia", ZIndex = 3 })
	if tipoEntrada == Enum.ProximityPromptInputType.Gamepad then
		insignia.BackgroundTransparency = 1
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode)
		img.ZIndex = 4
		img.Parent = insignia
	elseif tipoEntrada == Enum.ProximityPromptInputType.Touch then
		insignia.BackgroundColor3 = Paleta.UI_PRIMARIO
		Componentes.icono({ Parent = insignia, Clave = "mano", Tamano = INSIGNIA - 8, Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 4 })
	else
		Componentes.texto({ Parent = insignia, Texto = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode), Size = UDim2.fromScale(1, 1), Tamano = 20, Titulo = true, Alinear = Enum.TextXAlignment.Center, Color = Paleta.UI_PAPEL, ZIndex = 4 })
	end

	local x = 12 + INSIGNIA + 10
	local accion = Componentes.texto({ Parent = cuerpo, Texto = prompt.ActionText, Size = UDim2.new(1, -x - 10, 0, 28), Position = UDim2.fromOffset(x, 6), Tamano = 19, Titulo = true, ZIndex = 3, Escalar = true, Alinear = Enum.TextXAlignment.Left })
	local limite = Instance.new("UITextSizeConstraint")
	limite.MaxTextSize = 19
	limite.MinTextSize = 11
	limite.Parent = accion
	Componentes.texto({ Parent = cuerpo, Texto = prompt.ObjectText, Size = UDim2.new(1, -x - 10, 0, 18), Position = UDim2.fromOffset(x, 34), Tamano = 12, Negrita = true, Color = Paleta.UI_TINTA_SUAVE, ZIndex = 3 })

	-- Barra de mantener: se llena en HoldDuration
	local carril = Componentes.marco({ Parent = cuerpo, Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 12, 1, -8), Anchor = Vector2.new(0, 1), Color = Paleta.UI_PAPEL_SOMBRA, Radio = 3, Nombre = "Carril", ZIndex = 3 })
	carril.Visible = prompt.HoldDuration > 0
	local relleno = Componentes.marco({ Parent = carril, Size = UDim2.fromScale(0, 1), Color = Paleta.UI_PRIMARIO, Radio = 3, Nombre = "Relleno", ZIndex = 4 })
	local tweenCarga: Tween? = nil
	local conexiones: { RBXScriptConnection } = {}

	table.insert(conexiones, prompt.PromptButtonHoldBegan:Connect(function()
		if tweenCarga then
			tweenCarga:Cancel()
		end
		relleno.Size = UDim2.fromScale(0, 1)
		tweenCarga = TweenService:Create(relleno, TweenInfo.new(math.max(prompt.HoldDuration, 0.05), Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
		tweenCarga:Play()
		cuerpo.BackgroundColor3 = Paleta.UI_PAPEL_OSCURO
	end))
	table.insert(conexiones, prompt.PromptButtonHoldEnded:Connect(function()
		if tweenCarga then
			tweenCarga:Cancel()
			tweenCarga = nil
		end
		relleno.Size = UDim2.fromScale(0, 1)
		cuerpo.BackgroundColor3 = Paleta.UI_PAPEL
	end))

	-- Tactil: mantener el dedo sobre la pegatina
	cuerpo.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end)
	cuerpo.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end)

	-- Aparece creciendo
	local escala = Instance.new("UIScale")
	escala.Scale = 0.8
	escala.Parent = bb
	TweenService:Create(escala, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	return bb, conexiones
end

type PromptVisible = { gui: BillboardGui, conexiones: { RBXScriptConnection } }
local promptsVisibles: { [ProximityPrompt]: PromptVisible } = {}

local function quitarPrompt(prompt: ProximityPrompt)
	local visible = promptsVisibles[prompt]
	if not visible then
		return
	end
	promptsVisibles[prompt] = nil
	for _, c in visible.conexiones do
		c:Disconnect()
	end
	visible.gui:Destroy()
end

ProximityPromptService.PromptShown:Connect(function(prompt, tipoEntrada)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	quitarPrompt(prompt)
	local gui, conexiones = montarPrompt(prompt, tipoEntrada)
	promptsVisibles[prompt] = { gui = gui, conexiones = conexiones }
end)

ProximityPromptService.PromptHidden:Connect(quitarPrompt)

local PANEL_POR_MUEBLE = {
	Telefono = { "Tienda", nil },
	Almacen = { "Album", nil },
	MesaReparacion = { "Reparacion", nil },
	Estanteria = { "Base", "estanteria" },
	Radio = { "Base", "radio" },
	Exhibidor = { "Base", "exhibidor" },
}

local function parcelaDe(inst: Instance): Model?
	local actual: Instance? = inst
	while actual and actual ~= workspace do
		if actual:IsA("Model") and actual:GetAttribute("IndiceParcela") ~= nil then
			return actual
		end
		actual = actual.Parent
	end
	return nil
end

local function muebleDe(inst: Instance): string?
	local actual: Instance? = inst
	while actual and actual ~= workspace do
		local mueble = actual:GetAttribute("Mueble")
		if typeof(mueble) == "string" then
			return mueble
		end
		actual = actual.Parent
	end
	return nil
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, quien)
	if quien ~= jugador then
		return
	end
	local mueble = muebleDe(prompt)
	if not mueble then
		return
	end
	local destino = PANEL_POR_MUEBLE[mueble]
	if not destino then
		return
	end
	local parcela = parcelaDe(prompt)
	if parcela and parcela:GetAttribute("Dueno") ~= jugador.UserId then
		local nombre = parcela:GetAttribute("NombreDueno")
		if nombre then
			Notificaciones.mostrar(Textos.formatear(Textos.BASE.visitando, { nombre = nombre }), "info")
		else
			Notificaciones.mostrar(Textos.BASE.parcelaLibre, "info")
		end
		return
	end
	Menu.abrir(destino[1], destino[2])
end)

-- El saludo de Dona Chatarra: la tienda se abre al descartar el dialogo (como
-- con Jenny), no por debajo de el
Red.evento("DialogoEvent").OnClientEvent:Connect(function(npc, texto, abrirTienda)
	local despues = if abrirTienda then function()
		Menu.abrir("Tienda")
	end else nil
	if typeof(texto) == "string" then
		Dialogo.mostrar(if typeof(npc) == "string" then npc else "DonaChatarra", texto, despues)
	elseif despues then
		despues()
	end
end)
