--!strict
--[[
	Viewport (constructor del Kit)
	Unica responsabilidad: el ViewportFrame para ensenar modelos (bolsas,
	objetos) con la luz y el marco del kit. Colocar el modelo y encuadrar la
	camara lo hace Encuadre.mostrar.

	  scope:Viewport { Size?, Position?, AnchorPoint?, Orden?, Color?,
	                   Nombre?, ZIndex?, Visible?, Contorno? (por defecto si) }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))
local Tema = require(script.Parent:WaitForChild("Tema"))

local Children = Fusion.Children

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Size: U<UDim2>?,
	Position: U<UDim2>?,
	AnchorPoint: U<Vector2>?,
	Orden: U<number>?,
	Color: U<Color3>?,
	Nombre: string?,
	ZIndex: U<number>?,
	Visible: U<boolean>?,
	Contorno: boolean?,
}

return function(scope: any, p: Props): ViewportFrame
	local camara = scope:New("Camera")({ FieldOfView = 40 })
	local contorno = nil
	if p.Contorno ~= false then
		contorno = scope:New("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Paleta.UI_TINTA,
			Thickness = 2,
		})
	end
	return scope:New("ViewportFrame")({
		Name = p.Nombre or "Viewport",
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.Orden,
		ZIndex = p.ZIndex,
		Visible = p.Visible,
		BackgroundColor3 = p.Color or Paleta.UI_PAPEL_OSCURO,
		Ambient = Color3.fromRGB(205, 205, 205),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1.5, -1),
		CurrentCamera = camara,
		[Children] = {
			camara,
			scope:New("UICorner")({ CornerRadius = UDim.new(0, Tema.RADIO - 2) }),
			contorno,
		},
	})
end
