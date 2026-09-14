--!strict
--[[
	Entrada
	Que plataforma esta usando el jugador, para que la UI decida si muestra
	botones tactiles, pistas de gamepad o atajos de teclado. Se consulta en el
	cliente; en el servidor devuelve "teclado".

	Roblox no expone "es movil" directamente: se infiere de TouchEnabled sin
	teclado, y gamepad si hay uno conectado o fue el ultimo input usado.
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Entrada = {}

export type Plataforma = "teclado" | "tactil" | "gamepad"

function Entrada.plataforma(): Plataforma
	if RunService:IsServer() then
		return "teclado"
	end
	local ultimo = UserInputService:GetLastInputType()
	if ultimo == Enum.UserInputType.Gamepad1
		or ultimo == Enum.UserInputType.Gamepad2
		or ultimo == Enum.UserInputType.Gamepad3
		or ultimo == Enum.UserInputType.Gamepad4 then
		return "gamepad"
	end
	if ultimo == Enum.UserInputType.Touch then
		return "tactil"
	end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
		return "gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "tactil"
	end
	return "teclado"
end

function Entrada.esTactil(): boolean
	return Entrada.plataforma() == "tactil"
end

function Entrada.esGamepad(): boolean
	return Entrada.plataforma() == "gamepad"
end

-- Etiqueta de la tecla/boton para mostrar en la UI ("F", "Y", o nada en tactil)
function Entrada.etiqueta(teclado: string, gamepad: string): string
	local p = Entrada.plataforma()
	if p == "gamepad" then
		return gamepad
	elseif p == "tactil" then
		return ""
	end
	return teclado
end

return Entrada
