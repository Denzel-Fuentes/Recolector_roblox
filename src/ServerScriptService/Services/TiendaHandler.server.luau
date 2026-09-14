--!strict
--[[
	TiendaHandler
	Atiende los remotes de la tienda de Dona Chatarra:

	  ComprarMejoraEvent(idMejora)         -> Mejoras.comprar
	  ComprarSobreEvent()                  -> Tienda.abrirSobre
	  ContenedorDoradoEvent("dinero"|"gemas") -> Tienda.abrirContenedorDorado

	Los resultados de sobres y contenedores vuelven por ResultadoSobreEvent
	(lista de { id, uid, estado, rareza }, origen) para que el cliente muestre
	la revelacion. Los refrescos van por el prompt de la maquina (BotinHandler)
	y las ventas por MascotasHandler.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local DefinicionesMejoras = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMejoras"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Tienda = require(Servicios:WaitForChild("Tienda"))

local ComprarMejoraEvent = Red.evento("ComprarMejoraEvent")
local ComprarSobreEvent = Red.evento("ComprarSobreEvent")
local ContenedorDoradoEvent = Red.evento("ContenedorDoradoEvent")
local ResultadoSobreEvent = Red.evento("ResultadoSobreEvent")
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

local MENSAJE_FALLO = {
	sinDinero = Textos.PATIO.sinDinero,
	sinGemas = Textos.PATIO.sinGemas,
	almacenLleno = Textos.PATIO.almacenLleno,
}

ComprarMejoraEvent.OnServerEvent:Connect(function(jugador, id)
	if typeof(id) ~= "string" or enCooldown(jugador, 0.2) then
		return
	end
	local ok, msg = Mejoras.comprar(jugador, id)
	local def = DefinicionesMejoras.POR_ID[id]
	if ok and def then
		notificar(jugador, Textos.formatear(Textos.TIENDA.mejoraComprada, { nombre = def.nombre, nivel = msg }), "exito")
	elseif msg == "sinDinero" then
		notificar(jugador, Textos.PATIO.sinDinero, "aviso")
	end
end)

ComprarSobreEvent.OnServerEvent:Connect(function(jugador)
	if enCooldown(jugador, 0.5) then
		return
	end
	local ok, motivo, resultados = Tienda.abrirSobre(jugador)
	if ok then
		ResultadoSobreEvent:FireClient(jugador, resultados, "sobre")
	elseif MENSAJE_FALLO[motivo] then
		notificar(jugador, MENSAJE_FALLO[motivo], "aviso")
	end
end)

ContenedorDoradoEvent.OnServerEvent:Connect(function(jugador, pagarCon)
	if (pagarCon ~= "dinero" and pagarCon ~= "gemas") or enCooldown(jugador, 0.5) then
		return
	end
	local ok, motivo, resultados = Tienda.abrirContenedorDorado(jugador, pagarCon)
	if ok then
		ResultadoSobreEvent:FireClient(jugador, resultados, "contenedor")
	elseif MENSAJE_FALLO[motivo] then
		notificar(jugador, MENSAJE_FALLO[motivo], "aviso")
	elseif motivo == "bloqueado" then
		notificar(jugador, Textos.formatear(Textos.TIENDA.contenedorBloqueado, { n = Mejoras.numMaximas(jugador) }), "aviso")
	end
end)

Players.PlayerRemoving:Connect(function(jugador)
	ultimo[jugador] = nil
end)
