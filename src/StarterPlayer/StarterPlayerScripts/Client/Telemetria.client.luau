--!strict
--[[
	Telemetria (LocalScript)
	Unica responsabilidad: decirle al servidor UNA vez con que se juega
	("teclado" | "tactil" | "gamepad", Utilidades/Entrada: lo mismo que usa
	la UI para colocar el HUD) para los campos de la analitica (acierto por
	plataforma, embudo de inicio por plataforma).

	Por que lo manda el cliente: el servidor no sabe si hay pantalla tactil
	o mando. Por que una sola vez y al arrancar: el primer paso del embudo
	la espera (Services/Analitica, como mucho ESPERA_PLATAFORMA s) y Roblox
	desglosa el embudo con los campos de ese paso. El servidor la valida con
	una lista blanca y un enfriamiento, y solo la usa en esos campos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utilidades = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades")
local Entrada = require(Utilidades:WaitForChild("Entrada"))
local Red = require(Utilidades:WaitForChild("Red"))

Red.evento("AnaliticaEvent"):FireServer("plataforma", Entrada.plataforma())
