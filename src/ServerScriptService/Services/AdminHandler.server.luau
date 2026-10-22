--!strict
--[[
	AdminHandler
	Cablea los comandos de desarrollo (Services/Admin) al chat como
	TextChatCommand: el chat los reconoce y no los publica. Solo en Studio
	(decision del usuario, 22 oct): en el juego publicado no se crea ninguno.
	Responde por NotificacionEvent.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Red = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Red"))

local Admin = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Admin"))

local NotificacionEvent = Red.evento("NotificacionEvent")

Admin.crearComandos(TextChatService, function(jugador, nombre, args)
	local respuesta = Admin.ejecutar(jugador, nombre, args)
	if respuesta then
		NotificacionEvent:FireClient(jugador, "[admin] " .. respuesta, "info")
	end
end)
