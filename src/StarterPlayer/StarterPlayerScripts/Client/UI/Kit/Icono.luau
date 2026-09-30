--!strict
--[[
	Icono (constructor del Kit)
	Unica responsabilidad: pintar un icono por su clave. Imagen si
	Config/Iconos tiene id; si no, el dibujo de Utilidades/Glifos. Asi la UI
	esta completa aunque falte arte, y cada imagen se activa cambiando un
	numero en Iconos, sin tocar la UI.

	  scope:Icono { Clave (constante o estado), Tamano, Color?, Position?,
	                AnchorPoint?, Orden?, ZIndex?, Nombre?, Visible? }

	Devuelve un Frame transparente de Tamano x Tamano; si la clave es estado,
	el dibujo de dentro se rehace al cambiar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Iconos = require(Shared:WaitForChild("Config"):WaitForChild("Iconos"))
local Glifos = require(Shared:WaitForChild("Utilidades"):WaitForChild("Glifos"))

local Children = Fusion.Children

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Clave: U<string>,
	Tamano: number,
	Color: Color3?,
	Position: U<UDim2>?,
	AnchorPoint: U<Vector2>?,
	Orden: U<number>?,
	ZIndex: U<number>?,
	Visible: U<boolean>?,
	Nombre: string?,
}

return function(scope: any, p: Props): Frame
	local zIndex = p.ZIndex
	local dibujo = scope:Computed(function(use, scope: any): GuiObject
		local clave = use(p.Clave) :: string
		local id = Iconos.id(clave)
		if id then
			return scope:New("ImageLabel")({
				Name = "Imagen",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = id,
				ImageColor3 = p.Color or Color3.new(1, 1, 1),
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = zIndex,
			})
		end
		local glifo = Glifos.dibujar(clave, p.Tamano, p.Color)
		glifo.Name = "Glifo"
		-- El glifo se hizo fuera de Fusion: lo destruye el scope interno al
		-- cambiar de clave o al limpiar
		table.insert(scope, glifo)
		return glifo
	end)
	return scope:New("Frame")({
		Name = p.Nombre or "Icono",
		Size = UDim2.fromOffset(p.Tamano, p.Tamano),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.Orden,
		ZIndex = p.ZIndex,
		Visible = p.Visible,
		BackgroundTransparency = 1,
		[Children] = dibujo,
	})
end
