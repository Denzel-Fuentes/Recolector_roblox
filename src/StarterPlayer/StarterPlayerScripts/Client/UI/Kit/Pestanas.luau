--!strict
--[[
	Pestanas (constructor del Kit)
	Unica responsabilidad: una fila de pestanas del kit. Cada una con su color
	intenso (fijo por nombre, o el que se pida: p. ej. el del set en el
	Album), contorno marino y texto blanco; la elegida sube y se ve entera,
	las demas quedan hundidas y oscurecidas.

	  scope:Pestanas { Nombres, Seleccion (Value<number>), Colores?,
	                   Alto? (40), Orden?, Size?, Position?, alCambiar?(indice) }

	La seleccion es un Value que posee quien crea las pestanas: el panel
	decide que se ve con Computed(use(seleccion)). Devuelve la barra.

	Cambiar de pestana suena "pestana" (Client/Sonido); pulsar la que ya
	esta elegida, nada.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))
local Tema = require(script.Parent:WaitForChild("Tema"))
local Studs = require(script.Parent:WaitForChild("Studs"))
-- Kit -> UI -> Client
local Sonido = require(script.Parent.Parent.Parent:WaitForChild("Sonido"))

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Nombres: { string },
	Seleccion: Fusion.Value<number>,
	Colores: { Color3 }?,
	Alto: number?,
	Orden: U<number>?,
	Size: U<UDim2>?,
	Position: U<UDim2>?,
	alCambiar: ((indice: number) -> ())?,
}

return function(scope: any, p: Props): Frame
	local alto = p.Alto or 40
	local hueco = 6
	local pestanas = {}
	for i, nombre in p.Nombres do
		local propio = (p.Colores and p.Colores[i]) or Tema.colorBoton(nombre)
		local elegida = scope:Computed(function(use)
			return use(p.Seleccion) == i
		end)
		local elegidoPad = scope:Value(false)
		local subida = scope:Spring(
			scope:Computed(function(use)
				return UDim2.fromOffset(0, if use(elegida) then 0 else 6)
			end),
			45,
			0.75
		)
		table.insert(pestanas, scope:New("Frame")({
			Name = "Hueco" .. i,
			Size = UDim2.new(1 / #p.Nombres, -hueco, 1, 0),
			LayoutOrder = i,
			BackgroundTransparency = 1,
			[Children] = scope:New("TextButton")({
				Name = "Pestana_" .. nombre,
				Text = "",
				Size = UDim2.new(1, 0, 1, 12), -- sobresale por abajo y la barra lo recorta
				Position = subida,
				BackgroundColor3 = scope:Computed(function(use)
					return if use(elegida) then propio else Tema.oscurecer(propio, 0.18)
				end),
				AutoButtonColor = false,
				SelectionImageObject = Tema.SELECCION_INVISIBLE,
				ZIndex = scope:Computed(function(use)
					return if use(elegida) then 3 else 2
				end),
				[OnEvent("Activated")] = function()
					if peek(p.Seleccion) ~= i then
						Sonido.tocar("pestana")
					end
					p.Seleccion:set(i)
					if p.alCambiar then
						p.alCambiar(i)
					end
				end,
				[OnEvent("SelectionGained")] = function()
					elegidoPad:set(true)
				end,
				[OnEvent("SelectionLost")] = function()
					elegidoPad:set(false)
				end,
				[Children] = {
					Studs(scope, { Transparencia = Tema.STUDS_BOTON, Radio = 12 }),
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
					scope:New("UIGradient")({ Color = Tema.DEGRADADO, Rotation = 90 }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = scope:Computed(function(use)
							return if use(elegidoPad) then Paleta.UI_SELECCION else Paleta.UI_TINTA
						end),
						Thickness = scope:Computed(function(use)
							return if use(elegidoPad) then Tema.GROSOR + 2 else Tema.GROSOR
						end),
					}),
					scope:New("TextLabel")({
						Name = "Etiqueta",
						Size = UDim2.new(1, -16, 1, -12),
						Position = UDim2.fromOffset(8, 0),
						BackgroundTransparency = 1,
						Text = nombre,
						TextColor3 = scope:Computed(function(use)
							return if use(elegida) then Paleta.UI_PAPEL else Color3.fromRGB(225, 228, 240)
						end),
						FontFace = Tema.FUENTE_TITULO,
						TextScaled = true,
						ZIndex = 3,
						[Children] = {
							scope:New("UITextSizeConstraint")({ MinTextSize = 10, MaxTextSize = 18 }),
							scope:New("UIStroke")({
								ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
								Color = Paleta.UI_TINTA,
								Thickness = 2,
							}),
						},
					}),
				},
			}),
		}))
	end
	return scope:New("Frame")({
		Name = "Pestanas",
		Size = p.Size or UDim2.new(1, 0, 0, alto),
		Position = p.Position,
		LayoutOrder = p.Orden,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, hueco),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			pestanas,
		},
	})
end
