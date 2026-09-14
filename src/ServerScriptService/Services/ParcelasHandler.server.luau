--!strict
--[[
	ParcelasHandler
	Cablea las parcelas: asignar al cargar el perfil, liberar al salir,
	re-renderizar cuando cambia lo que se ve (exhibidas, figurinas, cinta, skin)
	y atender los remotes de la base:

	  TeletransporteEvent("casa" | "patio")
	  ReproducirCintaEvent(idCinta | nil)
	  PonerTrajeEvent(idTraje | nil)
	  PonerSkinBaseEvent(idSkin | nil)
	  Prompt "Me gusta" del cartel (ProximityPromptService)
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local Productos = require(Shared:WaitForChild("Config"):WaitForChild("Productos"))
local DefinicionesColeccionables = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesColeccionables"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Parcelas = require(Servicios:WaitForChild("Parcelas"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))
local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))

local TeletransporteEvent = Red.evento("TeletransporteEvent")
local ReproducirCintaEvent = Red.evento("ReproducirCintaEvent")
local PonerTrajeEvent = Red.evento("PonerTrajeEvent")
local PonerSkinBaseEvent = Red.evento("PonerSkinBaseEvent")
local NotificacionEvent = Red.evento("NotificacionEvent")

local function notificar(jugador: Player, texto: string, tipo: string)
	NotificacionEvent:FireClient(jugador, texto, tipo)
end

Perfiles.alCargar:Connect(function(jugador)
	Parcelas.asignar(jugador)
	Parcelas.renderizar(jugador)
end)

Players.PlayerRemoving:Connect(function(jugador)
	Parcelas.liberar(jugador)
end)

Mascotas.alCambiarExhibidas:Connect(function(jugador)
	Parcelas.renderizarPronto(jugador)
end)

Coleccionables.alAgregar:Connect(function(jugador, tipo)
	if tipo == "figurina" then
		Parcelas.renderizarPronto(jugador)
	end
end)

-- === Teletransporte ===
local ultimoTeletransporte: { [Player]: number } = {}
TeletransporteEvent.OnServerEvent:Connect(function(jugador, destino)
	if destino ~= "casa" and destino ~= "patio" then
		return
	end
	local ahora = os.clock()
	if ahora - (ultimoTeletransporte[jugador] or 0) < 2 then
		return
	end
	ultimoTeletransporte[jugador] = ahora
	Parcelas.teletransportar(jugador, destino)
end)

-- === Radio ===
ReproducirCintaEvent.OnServerEvent:Connect(function(jugador, idCinta)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return
	end
	if idCinta == nil then
		perfil.cintaPuesta = nil
	else
		if typeof(idCinta) ~= "string" or not DefinicionesColeccionables.CINTA_POR_ID[idCinta] then
			return
		end
		if not Coleccionables.tiene(jugador, "cinta", idCinta) then
			notificar(jugador, Textos.BASE.cintaNoTienes, "aviso")
			return
		end
		perfil.cintaPuesta = idCinta
	end
	Perfiles.marcarSucio(jugador)
	Parcelas.renderizarPronto(jugador)
end)

-- === Traje ===
PonerTrajeEvent.OnServerEvent:Connect(function(jugador, idTraje)
	if idTraje ~= nil and typeof(idTraje) ~= "string" then
		return
	end
	-- Los trajes premium se poseen por Game Pass, no por hallazgo
	if idTraje ~= nil and not Coleccionables.tiene(jugador, "traje", idTraje) then
		local pase = Productos.paseParaTraje(idTraje)
		if pase and Monetizacion.tienePase(jugador, pase.id) then
			Coleccionables.agregar(jugador, "traje", idTraje)
		end
	end
	local ok = Coleccionables.ponerTraje(jugador, idTraje)
	if ok and idTraje then
		local def = DefinicionesColeccionables.TRAJE_POR_ID[idTraje]
		if def then
			notificar(jugador, Textos.formatear(Textos.NOTIFICACIONES.trajePuesto, { nombre = def.nombre }), "exito")
		end
	elseif not ok then
		notificar(jugador, Textos.TIENDA.noEncontrado, "aviso")
	end
end)

-- === Skin de base ===
PonerSkinBaseEvent.OnServerEvent:Connect(function(jugador, idSkin)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return
	end
	if idSkin == nil then
		perfil.skinBase = nil
	else
		if typeof(idSkin) ~= "string" or not DefinicionesColeccionables.SKIN_POR_ID[idSkin] then
			return
		end
		local pase = Productos.paseParaSkin(idSkin)
		if not pase or not Monetizacion.tienePase(jugador, pase.id) then
			notificar(jugador, Textos.TIENDA.noEncontrado, "aviso")
			return
		end
		perfil.skinBase = idSkin
	end
	Perfiles.marcarSucio(jugador)
	Parcelas.renderizarPronto(jugador)
end)

-- === Me gusta (prompt del cartel) ===
ProximityPromptService.PromptTriggered:Connect(function(prompt, visitante)
	local parte = prompt.Parent
	if not parte or parte.Name ~= "Cartel" then
		return
	end
	local parcela = Parcelas.parcelaDe(parte)
	if not parcela then
		return
	end
	local ok, dato = Parcelas.darMeGusta(visitante, parcela)
	if ok then
		notificar(visitante, Textos.formatear(Textos.BASE.visitando, { nombre = dato }) .. " ♥", "exito")
		local dueno = Parcelas.duenoDe(parcela)
		if dueno then
			notificar(dueno, Textos.formatear(Textos.BASE.graciasMeGusta, { nombre = visitante.DisplayName }), "exito")
		end
	elseif dato == "repetido" then
		notificar(visitante, Textos.BASE.yaDisteMeGusta, "aviso")
	elseif dato == "propia" then
		notificar(visitante, Textos.BASE.miParcela, "info")
	end
end)

Players.PlayerRemoving:Connect(function(jugador)
	ultimoTeletransporte[jugador] = nil
end)
