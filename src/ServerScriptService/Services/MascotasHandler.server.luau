--!strict
--[[
	MascotasHandler
	Atiende las acciones del album que no pasan por la mesa ni por la tienda:

	  FusionarEvent(idMascota, estado)   3 copias limpias -> 1 en estado+1
	  VenderMascotaEvent(uid)            vender UNA copia a Dona Chatarra
	  VenderDuplicadosEvent()            vender todas las sobrantes
	  ExhibirEvent(uid | nil, indice)    poner/quitar del pedestal

	Y avisa de los hitos de coleccion (Rey Reciclon, set completo) que detecta
	el modulo Mascotas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local DefinicionesMascotas = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMascotas"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Mascotas = require(Servicios:WaitForChild("Mascotas"))

local FusionarEvent = Red.evento("FusionarEvent")
local VenderMascotaEvent = Red.evento("VenderMascotaEvent")
local VenderDuplicadosEvent = Red.evento("VenderDuplicadosEvent")
local ExhibirEvent = Red.evento("ExhibirEvent")
local NotificacionEvent = Red.evento("NotificacionEvent")
local FeedEvent = Red.evento("FeedEvent")

local function notificar(jugador: Player, texto: string, tipo: string)
	NotificacionEvent:FireClient(jugador, texto, tipo)
end

local ultimo: { [Player]: number } = {}
local function enCooldown(jugador: Player): boolean
	local ahora = os.clock()
	if ahora - (ultimo[jugador] or 0) < 0.2 then
		return true
	end
	ultimo[jugador] = ahora
	return false
end

FusionarEvent.OnServerEvent:Connect(function(jugador, id, estado)
	if typeof(id) ~= "string" or typeof(estado) ~= "number" or enCooldown(jugador) then
		return
	end
	local ok = Mascotas.fusionar(jugador, id, math.floor(estado))
	local def = DefinicionesMascotas.obtener(id)
	if ok and def then
		notificar(jugador, Textos.formatear(Textos.NOTIFICACIONES.fusion, { nombre = def.nombre, estado = DefinicionesMascotas.nombreEstado(estado + 1) }), "exito")
	end
end)

VenderMascotaEvent.OnServerEvent:Connect(function(jugador, uid)
	if typeof(uid) ~= "string" or enCooldown(jugador) then
		return
	end
	local ok, valor = Mascotas.vender(jugador, uid)
	if ok then
		notificar(jugador, Textos.formatear(Textos.TIENDA.vendidos, { n = 1, dinero = valor }), "dinero")
	end
end)

VenderDuplicadosEvent.OnServerEvent:Connect(function(jugador)
	if enCooldown(jugador) then
		return
	end
	local n, dinero = Mascotas.venderDuplicados(jugador)
	if n > 0 then
		notificar(jugador, Textos.formatear(Textos.TIENDA.vendidos, { n = n, dinero = dinero }), "dinero")
	else
		notificar(jugador, Textos.TIENDA.sinDuplicados, "aviso")
	end
end)

ExhibirEvent.OnServerEvent:Connect(function(jugador, uid, indice)
	if (uid ~= nil and typeof(uid) ~= "string") or typeof(indice) ~= "number" or enCooldown(jugador) then
		return
	end
	local ok, motivo = Mascotas.exhibir(jugador, uid, math.floor(indice))
	if not ok and motivo == "sucia" then
		notificar(jugador, Textos.ALBUM.limpiar .. ": " .. Textos.ALBUM.sucia, "aviso")
	end
end)

Mascotas.alCoronar:Connect(function(jugador)
	notificar(jugador, Textos.NOTIFICACIONES.rey, "exito")
	FeedEvent:FireAllClients(Textos.formatear(Textos.FEED.rey, { jugador = jugador.DisplayName }))
end)

game:GetService("Players").PlayerRemoving:Connect(function(jugador)
	ultimo[jugador] = nil
end)
