--!strict
--[[
	Interruptor (constructor del Kit)
	Unica responsabilidad: el interruptor encendido/apagado del kit (los
	ajustes de sonido, A1). Carril en pastilla con el contorno marino y el
	degradado de los botones: verde encendido, gris apagado; una bola
	blanca contorneada que se desliza de un lado a otro con un muelle.
	Suena el "clic" de los botones del kit al cambiarlo (Client/Sonido).

	  scope:Interruptor { Activado (estado), alCambiar (el valor pedido),
	                      Deshabilitado?, Nombre?, Size? (en px, 72 x 38),
	                      Position?, AnchorPoint?, Orden?, ZIndex? }

	El valor lo posee quien lo crea (el panel lo deriva del perfil): el
	interruptor solo pide el cambio y se mueve cuando el valor cambia. Es
	un TextButton Selectable: con gamepad se elige como un Boton (contorno
	amarillo) y Navegacion lo encuentra.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))
local Tema = require(script.Parent:WaitForChild("Tema"))
-- Kit -> UI -> Client
local Sonido = require(script.Parent.Parent.Parent:WaitForChild("Sonido"))

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Activado: U<boolean>,
	alCambiar: (valor: boolean) -> (),
	Deshabilitado: U<boolean>?,
	Nombre: string?,
	Size: UDim2?,
	Position: U<UDim2>?,
	AnchorPoint: U<Vector2>?,
	Orden: U<number>?,
	ZIndex: U<number>?,
}

local MARGEN = 4 -- px entre la bola y el borde del carril

return function(scope: any, p: Props): TextButton
	local tamano = p.Size or UDim2.fromOffset(72, 38)
	local ancho, alto = tamano.X.Offset, tamano.Y.Offset
	local lado = alto - MARGEN * 2

	local encendido = scope:Computed(function(use)
		return use(p.Activado) == true
	end)
	local deshabilitado = scope:Computed(function(use)
		return use(p.Deshabilitado or false) == true
	end)
	local elegido = scope:Value(false) -- seleccion con gamepad

	local color = scope:Tween(
		scope:Computed(function(use)
			if use(deshabilitado) then
				return Paleta.UI_BLOQUEADO
			end
			return if use(encendido) then Paleta.UI_EXITO else Paleta.UI_PAPEL_SOMBRA
		end),
		TweenInfo.new(0.15)
	)
	local x = scope:Spring(
		scope:Computed(function(use)
			return if use(encendido) then ancho - MARGEN - lado else MARGEN
		end),
		40,
		0.7
	)

	return scope:New("TextButton")({
		Name = p.Nombre or "Interruptor",
		Text = "",
		Size = tamano,
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.Orden,
		ZIndex = p.ZIndex,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Selectable = scope:Computed(function(use)
			return not use(deshabilitado)
		end),
		Active = scope:Computed(function(use)
			return not use(deshabilitado)
		end),
		SelectionImageObject = Tema.SELECCION_INVISIBLE,
		[OnEvent("SelectionGained")] = function()
			elegido:set(true)
		end,
		[OnEvent("SelectionLost")] = function()
			elegido:set(false)
		end,
		[OnEvent("Activated")] = function()
			if peek(deshabilitado) then
				return
			end
			Sonido.tocar("clic")
			p.alCambiar(not peek(encendido))
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			scope:New("UIGradient")({ Color = Tema.DEGRADADO, Rotation = 90 }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = scope:Computed(function(use)
					return if use(elegido) then Paleta.UI_SELECCION else Paleta.UI_TINTA
				end),
				Thickness = scope:Computed(function(use)
					return if use(elegido) then Tema.GROSOR + 2 else Tema.GROSOR
				end),
			}),
			scope:New("Frame")({
				Name = "Bola",
				Size = UDim2.fromOffset(lado, lado),
				Position = scope:Computed(function(use)
					return UDim2.new(0, use(x), 0.5, 0)
				end),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Paleta.UI_PAPEL,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Paleta.UI_TINTA,
						Thickness = 2,
					}),
				},
			}),
		},
	})
end
