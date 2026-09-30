--!strict
--[[
	Prompts
	El prompt de Dona Chatarra abre la tienda directamente (decision del
	usuario, 29 sep: fuera los dialogos con sus consejos). Es solo abrir un
	panel, asi que lo atiende el cliente; lo que se compra lo valida el
	servidor igual.

	=== Estilo ===
	Todos los ProximityPrompts del mundo se pintan aqui con el estilo del Kit
	(pastilla blanca, contorno marino) en vez de con el de Roblox: al aparecer uno
	(PromptShown) se monta una pegatina EN PANTALLA, bajo la mira (delante del
	jugador, no sobre el objeto; varias se apilan) con la insignia de la
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
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local UI = script.Parent:WaitForChild("UI")
local Menu = require(UI:WaitForChild("Menu"))
local Kit = require(UI:WaitForChild("Kit"))
local Tema = require(UI:WaitForChild("Kit"):WaitForChild("Tema"))

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

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local scopeRaiz = Fusion.scoped(Fusion, Kit)

-- Columna de pegatinas en pantalla, algo por debajo de la mira (centro)
local columna = scopeRaiz:New("Frame")({
	Name = "Columna",
	Size = UDim2.fromOffset(ANCHO_PROMPT, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Position = UDim2.fromScale(0.5, 0.58),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	[Children] = scopeRaiz:Lista({ Espacio = 8, Alinear = Enum.HorizontalAlignment.Center }),
})
scopeRaiz:Pantalla({ Nombre = "Prompts", Orden = 5, Hijos = columna })
local siguienteOrden = 0

-- Cada prompt visible vive en su propio scope: al ocultarse se limpia entero
-- (BillboardGui, conexiones de mantener y animaciones).
local function montarPrompt(prompt: ProximityPrompt, tipoEntrada: Enum.ProximityPromptInputType): any
	local scope = scopeRaiz:innerScope()
	local manteniendo = scope:Value(false)
	local aparecido = scope:Value(false)
	local carga = scope:Value(0)
	siguienteOrden += 1
	local orden = siguienteOrden

	-- Insignia: letra, imagen del boton o la mano
	local contenidoInsignia
	if tipoEntrada == Enum.ProximityPromptInputType.Gamepad then
		contenidoInsignia = scope:New("ImageLabel")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode),
			ZIndex = 4,
		})
	elseif tipoEntrada == Enum.ProximityPromptInputType.Touch then
		contenidoInsignia = scope:Icono({ Clave = "mano", Tamano = INSIGNIA - 8, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4 })
	else
		contenidoInsignia = scope:Texto({
			Texto = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode),
			Size = UDim2.fromScale(1, 1),
			Tamano = 22,
			Fuente = "titulo",
			Color = Paleta.UI_PAPEL,
			Alinear = Enum.TextXAlignment.Center,
			ZIndex = 4,
		})
	end
	local x = 12 + INSIGNIA + 10

	-- En pantalla, delante del jugador (decision del usuario), no flotando
	-- sobre el objeto: se apila en la columna bajo la mira
	scope:New("Frame")({
		Name = "Prompt",
		Size = UDim2.fromOffset(ANCHO_PROMPT, ALTO_PROMPT),
		BackgroundTransparency = 1,
		LayoutOrder = orden,
		Parent = columna,
		[Children] = {
			-- Aparece creciendo
			scope:New("UIScale")({
				Scale = scope:Spring(
					scope:Computed(function(use)
						return if use(aparecido) then 1 else 0.8
					end),
					40,
					0.6
				),
			}),
			scope:New("Frame")({
				Name = "Sombra",
				Size = UDim2.new(1, 0, 1, -4),
				Position = UDim2.fromOffset(0, 4),
				BackgroundColor3 = Paleta.UI_SOMBRA,
				BackgroundTransparency = 0.55,
				ZIndex = 1,
				[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
			-- El cuerpo es un boton: en tactil se mantiene pulsado
			scope:New("TextButton")({
				Name = "Cuerpo",
				Text = "",
				Size = UDim2.new(1, 0, 1, -4),
				BackgroundColor3 = scope:Computed(function(use)
					return if use(manteniendo) then Paleta.UI_PAPEL_OSCURO else Paleta.UI_PAPEL
				end),
				AutoButtonColor = false,
				Selectable = false,
				ZIndex = 2,
				[OnEvent("InputBegan")] = function(input: InputObject)
					if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
						prompt:InputHoldBegin()
					end
				end,
				[OnEvent("InputEnded")] = function(input: InputObject)
					if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
						prompt:InputHoldEnd()
					end
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({ Color = Paleta.UI_TINTA, Thickness = Tema.GROSOR }),
					scope:New("Frame")({
						Name = "Insignia",
						Size = UDim2.fromOffset(INSIGNIA, INSIGNIA),
						Position = UDim2.new(0, 12, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = if tipoEntrada == Enum.ProximityPromptInputType.Touch then Paleta.UI_PRIMARIO else Paleta.UI_TECLA,
						BackgroundTransparency = if tipoEntrada == Enum.ProximityPromptInputType.Gamepad then 1 else 0,
						ZIndex = 3,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
							contenidoInsignia,
						},
					}),
					scope:New("TextLabel")({
						Name = "Accion",
						Size = UDim2.new(1, -x - 14, 0, 28),
						Position = UDim2.fromOffset(x, 6),
						BackgroundTransparency = 1,
						Text = prompt.ActionText,
						TextColor3 = Paleta.UI_TINTA,
						FontFace = Tema.FUENTE_TITULO,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 3,
						[Children] = scope:New("UITextSizeConstraint")({ MaxTextSize = 21, MinTextSize = 11 }),
					}),
					scope:Texto({
						Texto = prompt.ObjectText,
						Size = UDim2.new(1, -x - 14, 0, 18),
						Position = UDim2.fromOffset(x, 34),
						Tamano = 13,
						Fuente = "negrita",
						Color = Paleta.UI_TINTA_SUAVE,
						ZIndex = 3,
					}),
					-- Barra de mantener: se llena en HoldDuration
					if prompt.HoldDuration > 0
						then scope:New("Frame")({
							Name = "Carril",
							Size = UDim2.new(1, -x - 24, 0, 7),
							Position = UDim2.new(0, x, 1, -8),
							AnchorPoint = Vector2.new(0, 1),
							BackgroundColor3 = Paleta.UI_PAPEL_SOMBRA,
							ZIndex = 3,
							[Children] = {
								scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
								scope:New("Frame")({
									Name = "Relleno",
									Size = scope:Tween(
										scope:Computed(function(use)
											return UDim2.fromScale(use(carga), 1)
										end),
										scope:Computed(function(use)
											-- Llenarse dura HoldDuration; vaciarse, al instante
											return if use(carga) > 0 then TweenInfo.new(math.max(prompt.HoldDuration, 0.05), Enum.EasingStyle.Linear) else TweenInfo.new(0)
										end)
									),
									BackgroundColor3 = Paleta.UI_DINERO,
									ZIndex = 4,
									[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
								}),
							},
						})
						else nil,
				},
			}),
		},
	})

	table.insert(scope, prompt.PromptButtonHoldBegan:Connect(function()
		manteniendo:set(true)
		carga:set(1)
	end))
	table.insert(scope, prompt.PromptButtonHoldEnded:Connect(function()
		manteniendo:set(false)
		carga:set(0)
	end))
	aparecido:set(true)
	return scope
end

local promptsVisibles: { [ProximityPrompt]: any } = {}

local function quitarPrompt(prompt: ProximityPrompt)
	local scope = promptsVisibles[prompt]
	if not scope then
		return
	end
	promptsVisibles[prompt] = nil
	Fusion.doCleanup(scope)
end

ProximityPromptService.PromptShown:Connect(function(prompt, tipoEntrada)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	quitarPrompt(prompt)
	promptsVisibles[prompt] = montarPrompt(prompt, tipoEntrada)
end)

ProximityPromptService.PromptHidden:Connect(quitarPrompt)

-- Dona Chatarra: su prompt abre la tienda (por el modelo con atributo NPC)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local actual: Instance? = prompt.Parent
	while actual and actual ~= workspace do
		if actual:GetAttribute("NPC") == "DonaChatarra" then
			Menu.abrir("Tienda")
			return
		end
		actual = actual.Parent
	end
end)
