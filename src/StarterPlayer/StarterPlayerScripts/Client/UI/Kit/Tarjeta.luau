--!strict
--[[
	Tarjeta (constructor del Kit)
	Unica responsabilidad: la fila/tarjeta del kit. Gris claro (o el color
	que se pida para destacarla) con studs, contorno marino y esquinas
	redondeadas. Los hijos van en "Contenido", que lleva el relleno: si el
	UIPadding estuviera en la tarjeta tambien apartaria los studs del borde.

	  scope:Tarjeta { Color?, Relleno? (px, por defecto 12), RellenoY?,
	                  Radio?, AutoAlto?, Nombre?, Size?, Position?,
	                  AnchorPoint?, Orden?, ZIndex?, Visible?, Hijos? }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))
local Tema = require(script.Parent:WaitForChild("Tema"))
local Studs = require(script.Parent:WaitForChild("Studs"))

local Children = Fusion.Children

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Color: U<Color3>?,
	Relleno: number?,
	RellenoY: number?,
	Radio: number?,
	AutoAlto: boolean?,
	Nombre: string?,
	Size: U<UDim2>?,
	Position: U<UDim2>?,
	AnchorPoint: U<Vector2>?,
	Orden: U<number>?,
	ZIndex: U<number>?,
	Visible: U<boolean>?,
	Hijos: Fusion.Child?,
}

return function(scope: any, p: Props): Frame
	local radio = p.Radio or Tema.RADIO
	local rx = p.Relleno or 12
	local ry = p.RellenoY or math.floor(rx * 0.75)
	local auto = if p.AutoAlto then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	return scope:New("Frame")({
		Name = p.Nombre or "Tarjeta",
		Size = p.Size or UDim2.new(1, 0, 0, 64),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		AutomaticSize = auto,
		LayoutOrder = p.Orden,
		ZIndex = p.ZIndex,
		Visible = p.Visible,
		BackgroundColor3 = p.Color or Paleta.UI_PAPEL_OSCURO,
		[Children] = {
			Studs(scope, { Transparencia = Tema.STUDS_TARJETA, Radio = radio }),
			scope:New("UICorner")({ CornerRadius = UDim.new(0, radio) }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Paleta.UI_TINTA,
				Thickness = Tema.GROSOR,
			}),
			scope:New("Frame")({
				Name = "Contenido",
				Size = if p.AutoAlto then UDim2.fromScale(1, 0) else UDim2.fromScale(1, 1),
				AutomaticSize = auto,
				BackgroundTransparency = 1,
				ZIndex = 1,
				[Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, rx),
						PaddingRight = UDim.new(0, rx),
						PaddingTop = UDim.new(0, ry),
						PaddingBottom = UDim.new(0, ry),
					}),
					p.Hijos,
				},
			}),
		},
	})
end
