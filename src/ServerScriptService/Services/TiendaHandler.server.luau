--!strict
--[[
	TiendaHandler
	Atiende los remotes de la tienda de Dona Chatarra:

	  ComprarMejoraEvent(idMejora)         -> Mejoras.comprar
	  EquiparCosmeticoEvent(tipo, id|nil)  -> Cosmeticos.equipar (diseno de
	                                          bolsa o estela; nil = quitar)

	Los pases y el Turbo se compran con MarketplaceService desde el cliente
	(MonetizacionHandler).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Idioma = require(Shared:WaitForChild("Utilidades"):WaitForChild("Idioma"))
local DefinicionesMejoras = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMejoras"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Cosmeticos = require(Servicios:WaitForChild("Cosmeticos"))

local ComprarMejoraEvent = Red.evento("ComprarMejoraEvent")
local EquiparCosmeticoEvent = Red.evento("EquiparCosmeticoEvent")
local NotificacionEvent = Red.evento("NotificacionEvent")

local function notificar(jugador: Player, texto: string, tipo: string)
	NotificacionEvent:FireClient(jugador, texto, tipo)
end

local ultimo: { [Player]: number } = {}
local function enCooldown(jugador: Player, segundos: number): boolean
	local ahora = os.clock()
	if ahora - (ultimo[jugador] or 0) < segundos then
		return true
	end
	ultimo[jugador] = ahora
	return false
end

ComprarMejoraEvent.OnServerEvent:Connect(function(jugador, id)
	if typeof(id) ~= "string" or enCooldown(jugador, 0.2) then
		return
	end
	local ok, msg = Mejoras.comprar(jugador, id)
	local def = DefinicionesMejoras.POR_ID[id]
	if ok and def then
		notificar(jugador, Idioma.mensaje("TIENDA.mejoraComprada", { nombre = Idioma.mensajeNombre("Mejoras", def), nivel = msg }), "exito")
	elseif msg == "sinDinero" then
		notificar(jugador, Idioma.mensaje("PATIO.sinDinero"), "aviso")
	end
end)

EquiparCosmeticoEvent.OnServerEvent:Connect(function(jugador, tipo, id)
	if typeof(tipo) ~= "string" or (id ~= nil and typeof(id) ~= "string") or enCooldown(jugador, 0.2) then
		return
	end
	Cosmeticos.equipar(jugador, tipo, id)
end)

Players.PlayerRemoving:Connect(function(jugador)
	ultimo[jugador] = nil
end)
