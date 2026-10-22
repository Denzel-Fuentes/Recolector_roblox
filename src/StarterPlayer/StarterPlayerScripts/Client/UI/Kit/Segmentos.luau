--!strict
--[[
	Segmentos (constructor del Kit)
	Unica responsabilidad: una barra de progreso hecha de cuadros (el nivel de
	una mejora: peticion del usuario, 3 oct, "una barra progresiva de 10
	cuadros", sin numeros ni unidades). Cada cuadro lleva el contorno marino
	del kit; los llenos, el color con el degradado de Barra y los botones.

	  scope:Segmentos { Total (numero fijo), Llenos (estado 0..Total),
	                    Color?, Size?, Position?, AnchorPoint?, Orden?,
	                    Nombre?, Espacio? }

	El numero de cuadros es fijo al construir (las mejoras tienen 10 niveles);
	solo cambia cuantos estan llenos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))
local Tema = require(script.Parent:WaitForChild("Tema"))

local Children = Fusion.Children

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Total: number,
	Llenos: U<number>,
	Color: U<Color3>?,
	Size: U<UDim2>?,
	Position: U<UDim2>?,
	AnchorPoint: U<Vector2>?,
	Orden: U<number>?,
	Nombre: string?,
	Espacio: number?,
}

return function(scope: any, p: Props): Frame
	local espacio = p.Espacio or 4
	local cuadros = {}
	for i = 1, p.Total do
		local lleno = scope:Computed(function(use)
			return (use(p.Llenos) :: number) >= i
		end)
		table.insert(cuadros, scope:New("Frame")({
			Name = "Cuadro" .. i,
			LayoutOrder = i,
			-- Cada cuadro, 1/Total del ancho menos su parte de los huecos
			Size = UDim2.new(1 / p.Total, -espacio * (p.Total - 1) / p.Total, 1, 0),
			BackgroundColor3 = scope:Computed(function(use)
				return if use(lleno) then (use(p.Color or Paleta.UI_EXITO) :: Color3) else Paleta.UI_PAPEL_SOMBRA
			end),
			[Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Paleta.UI_TINTA,
					Thickness = 2,
				}),
				scope:New("UIGradient")({
					Color = Tema.DEGRADADO,
					Rotation = 90,
					Enabled = lleno,
				}),
			},
		}))
	end
	return scope:New("Frame")({
		Name = p.Nombre or "Segmentos",
		Size = p.Size or UDim2.new(1, 0, 0, 18),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.Orden,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, espacio),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			cuadros,
		},
	})
end
