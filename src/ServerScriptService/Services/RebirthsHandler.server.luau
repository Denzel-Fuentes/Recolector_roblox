--!strict
--[[
	RebirthsHandler
	Cablea el rebirth: RenacerEvent() pide renacer (el servidor decide si se
	puede), avisa al jugador y lo anuncia en el feed del servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefinicionesRebirths = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesRebirths"))
local Idioma = require(Shared:WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Rebirths = require(Servicios:WaitForChild("Rebirths"))

local RenacerEvent = Red.evento("RenacerEvent")
local NotificacionEvent = Red.evento("NotificacionEvent")
local FeedEvent = Red.evento("FeedEvent")

local ultimo: { [Player]: number } = {}

RenacerEvent.OnServerEvent:Connect(function(jugador)
	local ahora = os.clock()
	if ahora - (ultimo[jugador] or 0) < 1 then
		return
	end
	ultimo[jugador] = ahora
	local ok, motivo = Rebirths.renacer(jugador)
	if ok then
		local n = tonumber(motivo) or 1
		local def = DefinicionesRebirths.rebirth(n)
		NotificacionEvent:FireClient(jugador, Idioma.mensaje("REBIRTH.hecho", { n = n, mult = Idioma.multiplicador(def.multiplicador) }), "exito")
		FeedEvent:FireAllClients(Idioma.mensaje("FEED.rebirth", { jugador = jugador.DisplayName, n = n }))
	elseif motivo == "mejoras" then
		NotificacionEvent:FireClient(jugador, Idioma.mensaje("REBIRTH.faltanMejoras"), "aviso")
	elseif motivo == "dinero" then
		local perfil = Perfiles.obtener(jugador)
		local falta = if perfil then DefinicionesRebirths.rebirth(perfil.rebirths + 1).requisito - perfil.dinero else 0
		NotificacionEvent:FireClient(jugador, Idioma.mensaje("REBIRTH.faltaDinero", { dinero = Idioma.dinero(falta) }), "aviso")
	end
end)

Players.PlayerRemoving:Connect(function(jugador)
	ultimo[jugador] = nil
end)
