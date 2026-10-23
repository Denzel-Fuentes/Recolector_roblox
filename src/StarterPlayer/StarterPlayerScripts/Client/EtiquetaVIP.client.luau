--!strict
--[[
	EtiquetaVIP
	Unica responsabilidad: la etiqueta [VIP] delante del nombre, en el chat,
	de quien tiene el pase VIP (economia v4, K1 22 oct). El servidor pone el
	atributo VIP en el Player (Services/Monetizacion) y cada cliente lo mira
	al pintar cada mensaje que le llega.

	TextChatService.OnIncomingMessage es UN callback por cliente: asignarlo
	en otro script dejaria solo el ultimo. Si algo mas necesita tocar los
	mensajes del chat, va aqui. Las cuentas Select suelen tener el chat
	apagado: lo que ve todo el mundo es la corona (CoronaVIP.client); esto
	es un extra para quien si lo tiene.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(Shared:WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos

-- El dorado de la corona y de la Estela VIP
local COLOR = Paleta.UI_ORO:ToHex()

TextChatService.OnIncomingMessage = function(mensaje: TextChatMessage): TextChatMessageProperties?
	local fuente = mensaje.TextSource
	if fuente == nil then
		return nil
	end
	local quien = Players:GetPlayerByUserId(fuente.UserId)
	if quien == nil or quien:GetAttribute("VIP") ~= true then
		return nil
	end
	local propiedades = Instance.new("TextChatMessageProperties")
	propiedades.PrefixText = string.format('<font color="#%s">[%s]</font> %s', COLOR, Textos.MUNDO.vip, mensaje.PrefixText)
	return propiedades
end
