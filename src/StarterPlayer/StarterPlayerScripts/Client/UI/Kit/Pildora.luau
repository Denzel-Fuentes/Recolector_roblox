--!strict
--[[
	Pildora (constructor del Kit)
	Unica responsabilidad: el contador del HUD del kit. Pastilla de color
	(verde el dinero, oscura las gemas...) con contorno marino, un numero gordo
	blanco con contorno y el icono asomando por la izquierda.

	  scope:Pildora { Icono, Texto (estado), Color?, Ancho, Alto? (46),
	                  TamanoTexto?, Nombre?, Position?, AnchorPoint?, Orden?,
	                  Visible? }

	Devuelve el marco (su nombre es el que mide la prueba "hud").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))
local Tema = require(script.Parent:WaitForChild("Tema"))
local Studs = require(script.Parent:WaitForChild("Studs"))
local Icono = require(script.Parent:WaitForChild("Icono"))

local Children = Fusion.Children

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Icono: string,
	Texto: U<string>,
	Color: U<Color3>?,
	Ancho: number,
	Alto: number?,
	TamanoTexto: number?,
	Nombre: string?,
	Position: U<UDim2>?,
	AnchorPoint: U<Vector2>?,
	Orden: U<number>?,
	Visible: U<boolean>?,
}

return function(scope: any, p: Props): Frame
	local alto = p.Alto or 46
	local lado = math.floor(alto * 1.05) -- el icono sobresale un poco: se ve "encima"
	local tamanoTexto = p.TamanoTexto or math.floor(alto * 0.58)
	return scope:New("Frame")({
		Name = p.Nombre or ("Pildora_" .. p.Icono),
		Size = UDim2.fromOffset(p.Ancho, alto),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.Orden,
		Visible = p.Visible,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("Frame")({
				Name = "Cuerpo",
				Size = UDim2.new(1, -math.floor(lado * 0.35), 1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = p.Color or Paleta.UI_TINTA,
				ZIndex = 1,
				[Children] = {
					Studs(scope, { Transparencia = Tema.STUDS_BOTON, Radio = math.floor(alto / 2) }),
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIGradient")({ Color = Tema.DEGRADADO, Rotation = 90 }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Paleta.UI_TINTA,
						Thickness = Tema.GROSOR,
					}),
					scope:New("TextLabel")({
						Name = "Numero",
						Size = UDim2.new(1, -math.floor(lado * 0.75), 1, 0),
						Position = UDim2.new(1, -8, 0, 0),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundTransparency = 1,
						Text = p.Texto,
						TextColor3 = Paleta.UI_PAPEL,
						TextSize = tamanoTexto,
						FontFace = Tema.FUENTE_TITULO,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextScaled = false,
						ZIndex = 2,
						[Children] = scope:New("UIStroke")({
							ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
							Color = Paleta.UI_TINTA,
							Thickness = math.max(2, tamanoTexto * 0.1),
						}),
					}),
				},
			}),
			Icono(scope, {
				Clave = p.Icono,
				Tamano = lado,
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				ZIndex = 3,
			}),
		},
	})
end
