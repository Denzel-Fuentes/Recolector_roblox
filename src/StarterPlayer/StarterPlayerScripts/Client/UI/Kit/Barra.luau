--!strict
--[[
	Barra (constructor del Kit)
	Unica responsabilidad: la barra de progreso del kit. Carril gris con
	contorno marino, relleno de color con degradado que se anima (Tween) al
	cambiar la fraccion, y un texto blanco contorneado encima.

	  scope:Barra { Fraccion (estado 0..1), Texto?, Color?, Vertical?,
	                Size?, Position?, AnchorPoint?, Orden?, Nombre?, Visible?,
	                Radio?, TamanoTexto? }

	Vertical: se llena de abajo arriba (energia, bolsa, fuerza en el HUD).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))
local Tema = require(script.Parent:WaitForChild("Tema"))

local Children = Fusion.Children

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Fraccion: U<number>,
	Texto: U<string>?,
	Color: U<Color3>?,
	Vertical: boolean?,
	Size: U<UDim2>?,
	Position: U<UDim2>?,
	AnchorPoint: U<Vector2>?,
	Orden: U<number>?,
	Nombre: string?,
	Visible: U<boolean>?,
	Radio: number?,
	TamanoTexto: number?,
}

local MARGEN = 3

return function(scope: any, p: Props): Frame
	local radio = p.Radio or 10
	local tamanoRelleno = scope:Tween(
		scope:Computed(function(use)
			local f = math.clamp(use(p.Fraccion) :: number, 0, 1)
			if p.Vertical then
				return UDim2.new(1, -MARGEN * 2, f, if f > 0 then -MARGEN * 2 else 0)
			end
			return UDim2.new(f, if f > 0 then -MARGEN * 2 else 0, 1, -MARGEN * 2)
		end),
		TweenInfo.new(0.2, Enum.EasingStyle.Quad)
	)
	return scope:New("Frame")({
		Name = p.Nombre or "Barra",
		Size = p.Size or UDim2.new(1, 0, 0, 22),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.Orden,
		Visible = p.Visible,
		BackgroundColor3 = Paleta.UI_PAPEL_SOMBRA,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, radio) }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Paleta.UI_TINTA,
				Thickness = Tema.GROSOR,
			}),
			scope:New("Frame")({
				Name = "Relleno",
				Size = tamanoRelleno,
				Position = if p.Vertical then UDim2.new(0, MARGEN, 1, -MARGEN) else UDim2.fromOffset(MARGEN, MARGEN),
				AnchorPoint = if p.Vertical then Vector2.new(0, 1) else Vector2.zero,
				BackgroundColor3 = p.Color or Paleta.UI_DINERO,
				ZIndex = 1,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, math.max(2, radio - MARGEN)) }),
					scope:New("UIGradient")({ Color = Tema.DEGRADADO, Rotation = if p.Vertical then 0 else 90 }),
				},
			}),
			scope:New("TextLabel")({
				Name = "Etiqueta",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = p.Texto or "",
				TextColor3 = Paleta.UI_PAPEL,
				TextSize = p.TamanoTexto or 14,
				FontFace = Tema.FUENTE_TITULO,
				ZIndex = 2,
				[Children] = scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
					Color = Paleta.UI_TINTA,
					Thickness = 2,
				}),
			}),
		},
	})
end
