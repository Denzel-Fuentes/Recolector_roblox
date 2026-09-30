--!strict
--[[
	Studs (constructor del Kit)
	Unica responsabilidad: la textura de studs en mosaico que el usuario pidio
	como fondo (en el kit de referencia es un damero). Va como PRIMER hijo de
	un marco sin texto propio (tarjeta, cuerpo de boton, ventana) con ZIndex
	0: con ZIndexBehavior Sibling se pinta encima del fondo del padre y
	debajo de sus demas hijos. Hereda las esquinas por su propio UICorner.

	  scope:Studs { Transparencia?, Radio?, Color? }   -> ImageLabel | nil
	Sin id "studs" en Config/Iconos devuelve nil (Children lo ignora).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Tema = require(script.Parent:WaitForChild("Tema"))

local Children = Fusion.Children

export type Props = {
	Transparencia: Fusion.UsedAs<number>?,
	Radio: number?,
	Color: Fusion.UsedAs<Color3>?,
}

return function(scope: any, p: Props?): ImageLabel?
	local id = Tema.idStuds()
	if not id then
		return nil
	end
	local props: Props = p or {}
	return scope:New("ImageLabel")({
		Name = "Studs",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = id,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(Tema.STUDS_BALDOSA, Tema.STUDS_BALDOSA),
		ImageTransparency = props.Transparencia or Tema.STUDS_TARJETA,
		ImageColor3 = props.Color or Color3.new(1, 1, 1),
		ZIndex = 0,
		Active = false,
		[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, props.Radio or Tema.RADIO) }),
	})
end
