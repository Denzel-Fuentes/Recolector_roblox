--!strict
--[[
	Pantalla (constructor del Kit)
	Unica responsabilidad: un ScreenGui del juego con su UIScale atado a
	Escala.escala, colgado del PlayerGui. Toda pantalla del Kit empieza aqui,
	asi el escalado por altura de pantalla se decide una sola vez.

	  scope:Pantalla { Nombre, Orden?, Visible?, IgnorarInset?, Hijos? }
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Escala = require(script.Parent:WaitForChild("Escala"))

local Children = Fusion.Children

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

export type Props = {
	Nombre: string,
	Orden: number?,
	Visible: Fusion.UsedAs<boolean>?,
	IgnorarInset: boolean?,
	Hijos: Fusion.Child?,
}

return function(scope: any, p: Props): ScreenGui
	return scope:New("ScreenGui")({
		Name = p.Nombre,
		DisplayOrder = p.Orden or 0,
		Enabled = if p.Visible == nil then true else p.Visible,
		IgnoreGuiInset = p.IgnorarInset == true,
		-- El idioma lo pone Utilidades/Idioma (Idioma.textos), no la traduccion
		-- automatica de Roblox
		AutoLocalize = false,
		Parent = playerGui,
		[Children] = {
			scope:New("UIScale")({ Scale = Escala.escala }),
			p.Hijos,
		},
	})
end
