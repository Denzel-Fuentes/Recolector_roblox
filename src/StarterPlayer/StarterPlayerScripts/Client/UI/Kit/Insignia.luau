--!strict
--[[
	Insignia (constructor del Kit)
	Unica responsabilidad: la insignia de tecla. Letra blanca sobre marino con
	teclado, la imagen del boton con mando (GetImageForKeyCode) y nada en
	tactil. Reacciona sola a Escala.plataforma.

	  scope:Insignia { Teclado ("F", "Q", "CLIC"...), Gamepad? (KeyCode),
	                   Tamano? (alto, 24; el ancho crece con el texto),
	                   Position?, AnchorPoint?, Orden?, ZIndex?, Nombre? }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))
local Tema = require(script.Parent:WaitForChild("Tema"))
local Escala = require(script.Parent:WaitForChild("Escala"))

local Children = Fusion.Children

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Teclado: string,
	Gamepad: Enum.KeyCode?,
	Tamano: number?,
	Position: U<UDim2>?,
	AnchorPoint: U<Vector2>?,
	Orden: U<number>?,
	ZIndex: U<number>?,
	Nombre: string?,
}

return function(scope: any, p: Props): Frame
	local alto = p.Tamano or 24
	local conMando = scope:Computed(function(use)
		return use(Escala.plataforma) == "gamepad" and p.Gamepad ~= nil
	end)
	return scope:New("Frame")({
		Name = p.Nombre or "Insignia",
		Size = UDim2.fromOffset(alto, alto),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.Orden,
		ZIndex = p.ZIndex,
		Visible = scope:Computed(function(use)
			return use(conMando) or use(Escala.plataforma) ~= "tactil"
		end),
		BackgroundColor3 = Paleta.UI_TECLA,
		BackgroundTransparency = scope:Computed(function(use)
			return if use(conMando) then 1 else 0
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, math.floor(alto * 0.3)) }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Paleta.UI_PAPEL,
				Thickness = 1.5,
				Enabled = scope:Computed(function(use)
					return not use(conMando)
				end),
			}),
			scope:New("TextLabel")({
				Name = "Letra",
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = p.Teclado,
				TextColor3 = Paleta.UI_PAPEL,
				TextSize = math.floor(alto * 0.6),
				FontFace = Tema.FUENTE_TITULO,
				Visible = scope:Computed(function(use)
					return not use(conMando)
				end),
				[Children] = scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, math.floor(alto * 0.25)),
					PaddingRight = UDim.new(0, math.floor(alto * 0.25)),
				}),
			}),
			scope:New("ImageLabel")({
				Name = "Boton",
				Size = UDim2.fromOffset(alto, alto),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Image = scope:Computed(function(use)
					return if use(conMando) and p.Gamepad then UserInputService:GetImageForKeyCode(p.Gamepad) else ""
				end),
				Visible = conMando,
			}),
		},
	})
end
