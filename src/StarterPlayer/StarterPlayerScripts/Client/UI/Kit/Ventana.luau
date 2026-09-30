--!strict
--[[
	Ventana (constructor del Kit)
	Unica responsabilidad: la ventana modal del kit. Fondo oscurecido,
	panel blanco con contorno marino grueso y studs suaves, BARRA DE TITULO
	de color (Paleta.CABECERA_PANEL por nombre) con el titulo en mayusculas y
	una X blanca. Se abre con un pequeno rebote (Spring de la escala).

	  scope:Ventana {
	    Nombre (el del ScreenGui y el del panel en Menu), Titulo,
	    Ancho, Alto (MAXIMOS de diseno: en pantallas pequenas se encoge al
	                94 % x 90 % del area util),
	    Abierta (estado), alCerrar, Color? (de la barra), Orden? (DisplayOrder,
	    10 por defecto), Hijos (van en "Contenido")
	  }

	Devuelve el ScreenGui. El contenido esta en Scale y se adapta solo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))
local Tema = require(script.Parent:WaitForChild("Tema"))
local Escala = require(script.Parent:WaitForChild("Escala"))
local Studs = require(script.Parent:WaitForChild("Studs"))
local Pantalla = require(script.Parent:WaitForChild("Pantalla"))

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Nombre: string,
	Titulo: U<string>,
	Ancho: number,
	Alto: number,
	Abierta: U<boolean>,
	alCerrar: () -> (),
	Color: U<Color3>?,
	Orden: number?,
	Hijos: Fusion.Child?,
}

return function(scope: any, p: Props): ScreenGui
	local colorCabecera = p.Color or Tema.cabecera(p.Nombre)
	local alto = Tema.ALTO_CABECERA

	local tamano = scope:Computed(function(use)
		local d = use(Escala.diseno) :: Vector2
		return UDim2.fromOffset(math.min(p.Ancho, math.floor(d.X * 0.94)), math.min(p.Alto, math.floor(d.Y * 0.9)))
	end)
	local escala = scope:Spring(
		scope:Computed(function(use)
			return if use(p.Abierta) then 1 else 0.9
		end),
		35,
		0.65
	)
	local encimaX = scope:Value(false)
	local escalaX = scope:Spring(
		scope:Computed(function(use)
			return if use(encimaX) then 1.15 else 1
		end),
		40,
		0.6
	)

	local cabecera = scope:New("Frame")({
		Name = "Cabecera",
		Size = UDim2.new(1, 0, 0, alto),
		BackgroundColor3 = colorCabecera,
		ZIndex = 3,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, Tema.RADIO_VENTANA) }),
			scope:New("UIGradient")({ Color = Tema.DEGRADADO, Rotation = 90 }),
			-- Tapa las esquinas redondeadas de abajo: la barra acaba recta
			scope:New("Frame")({
				Name = "Recto",
				Size = UDim2.new(1, 0, 0, Tema.RADIO_VENTANA),
				Position = UDim2.new(0, 0, 1, -Tema.RADIO_VENTANA),
				BackgroundColor3 = colorCabecera,
				ZIndex = 3,
				[Children] = scope:New("UIGradient")({
					Color = ColorSequence.new(Color3.fromRGB(215, 215, 222), Color3.fromRGB(200, 200, 210)),
					Rotation = 90,
				}),
			}),
			-- Linea marina que separa la barra del cuerpo
			scope:New("Frame")({
				Name = "Linea",
				Size = UDim2.new(1, 0, 0, Tema.GROSOR_VENTANA),
				Position = UDim2.new(0, 0, 1, 0),
				BackgroundColor3 = Paleta.UI_TINTA,
				ZIndex = 4,
			}),
			scope:New("TextLabel")({
				Name = "Titulo",
				Size = UDim2.new(1, -80, 1, 0),
				Position = UDim2.fromOffset(20, 0),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use)
					return Tema.mayusculas(use(p.Titulo) :: string)
				end),
				TextColor3 = Paleta.UI_PAPEL,
				TextSize = 26,
				FontFace = Tema.FUENTE_TITULO,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 5,
				[Children] = scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
					Color = Paleta.UI_TINTA,
					Thickness = 2.5,
				}),
			}),
			scope:New("TextButton")({
				Name = "Cerrar",
				-- FredokaOne no trae la cruz tipografica: una X gorda
				Text = "X",
				Size = UDim2.fromOffset(alto - 8, alto - 8),
				Position = UDim2.new(1, -8, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				TextColor3 = Paleta.UI_PAPEL,
				TextSize = 32,
				FontFace = Tema.FUENTE_TITULO,
				SelectionImageObject = Tema.SELECCION_INVISIBLE,
				ZIndex = 5,
				[OnEvent("MouseEnter")] = function()
					encimaX:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					encimaX:set(false)
				end,
				[OnEvent("Activated")] = function()
					p.alCerrar()
				end,
				[Children] = {
					scope:New("UIScale")({ Scale = escalaX }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
						Color = Paleta.UI_TINTA,
						Thickness = 3,
					}),
				},
			}),
		},
	})

	local panel = scope:New("Frame")({
		Name = "Panel",
		Size = tamano,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Paleta.UI_PAPEL,
		ZIndex = 2,
		[Children] = {
			Studs(scope, { Transparencia = Tema.STUDS_VENTANA, Radio = Tema.RADIO_VENTANA }),
			scope:New("UICorner")({ CornerRadius = UDim.new(0, Tema.RADIO_VENTANA) }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Paleta.UI_TINTA,
				Thickness = Tema.GROSOR_VENTANA,
			}),
			scope:New("UIScale")({ Scale = escala }),
			cabecera,
			scope:New("Frame")({
				Name = "Contenido",
				Size = UDim2.new(1, -28, 1, -(alto + Tema.GROSOR_VENTANA + 24)),
				Position = UDim2.fromOffset(14, alto + Tema.GROSOR_VENTANA + 12),
				BackgroundTransparency = 1,
				ZIndex = 2,
				[Children] = p.Hijos,
			}),
		},
	})

	return Pantalla(scope, {
		Nombre = p.Nombre,
		Orden = p.Orden or 10,
		Visible = p.Abierta,
		IgnorarInset = true, -- el velo oscuro cubre tambien la barra de Roblox

		Hijos = scope:New("Frame")({
			Name = "Fondo",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Paleta.UI_TINTA,
			BackgroundTransparency = 0.45,
			Active = true, -- que los clics no atraviesen al juego
			[Children] = {
				-- Sombra dura del panel, desplazada hacia abajo
				scope:New("Frame")({
					Name = "Sombra",
					Size = tamano,
					Position = UDim2.new(0.5, 0, 0.5, 8),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Paleta.UI_SOMBRA,
					BackgroundTransparency = 0.4,
					ZIndex = 1,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, Tema.RADIO_VENTANA) }),
						scope:New("UIScale")({ Scale = escala }),
					},
				}),
				panel,
			},
		}),
	})
end
