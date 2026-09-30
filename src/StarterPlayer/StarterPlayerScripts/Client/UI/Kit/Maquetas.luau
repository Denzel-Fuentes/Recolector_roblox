--!strict
--[[
	Maquetas (constructores del Kit)
	Unica responsabilidad: los layouts de siempre con los valores del tema,
	para no repetir cinco propiedades en cada panel.

	  scope:Lista { Espacio?, Horizontal?, Alinear?, AlinearV? }  -> UIListLayout
	  scope:Rejilla { Celda, Espacio? }                          -> UIGridLayout
	  scope:Relleno { X, Y? }                                    -> UIPadding
]]

local Maquetas = {}

function Maquetas.Lista(scope: any, p: { Espacio: number?, Horizontal: boolean?, Alinear: Enum.HorizontalAlignment?, AlinearV: Enum.VerticalAlignment? }?): UIListLayout
	local props = p or {}
	return scope:New("UIListLayout")({
		Padding = UDim.new(0, props.Espacio or 6),
		FillDirection = if props.Horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = props.Alinear or Enum.HorizontalAlignment.Left,
		VerticalAlignment = props.AlinearV or Enum.VerticalAlignment.Top,
	})
end

function Maquetas.Rejilla(scope: any, p: { Celda: UDim2, Espacio: number? }): UIGridLayout
	return scope:New("UIGridLayout")({
		CellSize = p.Celda,
		CellPadding = UDim2.fromOffset(p.Espacio or 8, p.Espacio or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Maquetas.Relleno(scope: any, p: { X: number, Y: number? }): UIPadding
	return scope:New("UIPadding")({
		PaddingLeft = UDim.new(0, p.X),
		PaddingRight = UDim.new(0, p.X),
		PaddingTop = UDim.new(0, p.Y or p.X),
		PaddingBottom = UDim.new(0, p.Y or p.X),
	})
end

return Maquetas
