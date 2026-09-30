--!strict
--[[
	MascotasHandler
	Cablea las mascotas: arranca los seguidores y atiende

	  EquiparMascotaEvent(id, poner)  ponerse o quitarse una mascota
	  UsarFragmentoEvent(setId)       gastar un fragmento libre (pedidos) en ese set

	Y avisa de lo que pasa con los fragmentos al reciclarlos
	(Services/Fragmentos): cada uno, con un aviso ("Latita 3/5"; el primero
	dice que mascota se esta montando); al completar una, la revelacion
	(RevelacionEvent, UI/Revelacion) y, si es Rara o mejor y nueva, el feed.
	Tambien anuncia el Rey.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local DefinicionesMascotas = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMascotas"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Mascotas = require(Servicios:WaitForChild("Mascotas"))
local Fragmentos = require(Servicios:WaitForChild("Fragmentos"))
local Seguidores = require(Servicios:WaitForChild("Seguidores"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))

local EquiparMascotaEvent = Red.evento("EquiparMascotaEvent")
local UsarFragmentoEvent = Red.evento("UsarFragmentoEvent")
local RevelacionEvent = Red.evento("RevelacionEvent")
local NotificacionEvent = Red.evento("NotificacionEvent")
local FeedEvent = Red.evento("FeedEvent")

Seguidores.iniciar()

local ultimo: { [Player]: number } = {}
local function enCooldown(jugador: Player, segundos: number): boolean
	local ahora = os.clock()
	if ahora - (ultimo[jugador] or 0) < segundos then
		return true
	end
	ultimo[jugador] = ahora
	return false
end

EquiparMascotaEvent.OnServerEvent:Connect(function(jugador, id, poner)
	if typeof(id) ~= "string" or typeof(poner) ~= "boolean" or enCooldown(jugador, 0.25) then
		return
	end
	local ok, motivo = Mascotas.equipar(jugador, id, poner)
	if ok and motivo == "equipada" then
		local def = DefinicionesMascotas.obtener(id)
		NotificacionEvent:FireClient(jugador, Textos.formatear(Textos.NOTIFICACIONES.mascotaEquipada, { nombre = if def then def.nombre else id }), "exito")
	elseif motivo == "huecosLlenos" then
		NotificacionEvent:FireClient(jugador, Textos.MASCOTAS.huecosLlenos, "aviso")
	end
end)

UsarFragmentoEvent.OnServerEvent:Connect(function(jugador, setId)
	if typeof(setId) ~= "string" or enCooldown(jugador, 0.5) then
		return
	end
	Fragmentos.usarLibre(jugador, setId)
end)

Fragmentos.alAgregar:Connect(function(jugador, r)
	if not jugador.Parent then
		return -- reciclado al desconectar: cuenta, pero no hay a quien avisar
	end
	local def = DefinicionesMascotas.obtener(r.id)
	local nombre = if def then def.nombre else r.id
	local completa = r.completa
	if not completa then
		local plantilla = if r.empezada then Textos.NOTIFICACIONES.fragmentoNuevo else Textos.NOTIFICACIONES.fragmento
		NotificacionEvent:FireClient(jugador, Textos.formatear(plantilla, {
			nombre = nombre,
			rareza = DefinicionesMascotas.NOMBRE_RAREZA[r.rareza] or r.rareza,
			n = r.n,
			total = r.total,
		}), "exito")
		return
	end
	RevelacionEvent:FireClient(jugador, {
		set = r.set,
		rareza = r.rareza,
		id = r.id,
		nueva = completa.nueva,
		nivel = completa.nivel,
		dinero = completa.dinero,
	})
	if r.rareza ~= "Comun" and completa.nueva then
		FeedEvent:FireAllClients(Textos.formatear(Textos.FEED.mascota, {
			jugador = jugador.DisplayName,
			mascota = nombre,
			rareza = DefinicionesMascotas.NOMBRE_RAREZA[r.rareza] or r.rareza,
		}))
	end
end)

-- Fragmentos de un set que el jugador aun no tiene abierto (los excavo otro)
Bolsa.alResumen:Connect(function(jugador, resumen)
	for _, setId in resumen.cerrados do
		local set = DefinicionesMascotas.SET_POR_ID[setId]
		if set and jugador.Parent then
			NotificacionEvent:FireClient(jugador, Textos.formatear(Textos.NOTIFICACIONES.fragmentoCerrado, { set = set.nombre, n = set.rebirth }), "aviso")
		end
	end
end)

Mascotas.alRey:Connect(function(jugador)
	FeedEvent:FireAllClients(Textos.formatear(Textos.FEED.rey, { jugador = jugador.DisplayName }))
end)

Players.PlayerRemoving:Connect(function(jugador)
	ultimo[jugador] = nil
end)
