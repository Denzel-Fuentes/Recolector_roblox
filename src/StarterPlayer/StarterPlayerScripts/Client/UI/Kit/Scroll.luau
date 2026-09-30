--!strict
--[[
	Scroll (constructor del Kit)
	Unica responsabilidad: la lista con desplazamiento vertical del kit: lienzo
	automatico en Y, barra marina (mas fina en tactil) y, si se pide, su
	UIListLayout ya puesto.

	  scope:Scroll { Size?, Position?, Orden?, Nombre?, Visible?,
	                 Espacio? (si se da, lleva UIListLayout vertical),
	                 Relleno? (px), Hijos? }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))
local Escala = require(script.Parent:WaitForChild("Escala"))

local Children = Fusion.Children

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Size: U<UDim2>?,
	Position: U<UDim2>?,
	Orden: U<number>?,
	Nombre: string?,
	Visible: U<boolean>?,
	Espacio: number?,
	Relleno: number?,
	Hijos: Fusion.Child?,
}

return function(scope: any, p: Props): ScrollingFrame
	local lista = nil
	if p.Espacio then
		lista = scope:New("UIListLayout")({
			Padding = UDim.new(0, p.Espacio),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		})
	end
	local relleno = nil
	if p.Relleno then
		relleno = scope:New("UIPadding")({
			PaddingLeft = UDim.new(0, p.Relleno),
			PaddingRight = UDim.new(0, p.Relleno + 6), -- sitio para la barra
			PaddingTop = UDim.new(0, p.Relleno),
			PaddingBottom = UDim.new(0, p.Relleno),
		})
	end
	return scope:New("ScrollingFrame")({
		Name = p.Nombre or "Scroll",
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position,
		LayoutOrder = p.Orden,
		Visible = p.Visible,
		BackgroundTransparency = 1,
		ScrollBarThickness = scope:Computed(function(use)
			return if use(Escala.plataforma) == "tactil" then 5 else 8
		end),
		ScrollBarImageColor3 = Paleta.UI_TINTA,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromScale(0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		[Children] = { lista, relleno, p.Hijos },
	})
end
