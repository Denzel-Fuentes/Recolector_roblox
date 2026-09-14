--!strict
--[[
	BotinHandler
	Cablea el patio: arranca Botin cuando el mundo esta listo y atiende
	  - ProximityPrompts del patio y la caseta (excavar, reciclar, refresco,
	    hablar con Dona Chatarra),
	  - ReclamarObjetoEvent (clic dentro del Alcance),
	  - LanzarObjetoEvent(punto, fuerza): lanzar la bolsa entera (punteria).

	Un solo listener de ProximityPromptService.PromptTriggered para todo: se
	decide por el MODELO al que pertenece el prompt (atributo MontonId, tags
	Contenedor / MaquinaRefrescos, atributo NPC). Asi los prompts horneados en el
	place no necesitan scripts propios.

	Cada remote tiene cooldown por jugador: un cliente modificado que dispare
	1000 reclamos por segundo solo consigue que se ignoren.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local DefinicionesMascotas = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMascotas"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Mundo = require(Servicios:WaitForChild("Mundo"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Energia = require(Servicios:WaitForChild("Energia"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Botin = require(Servicios:WaitForChild("Botin"))

local ReclamarObjetoEvent = Red.evento("ReclamarObjetoEvent")
local LanzarObjetoEvent = Red.evento("LanzarObjetoEvent")
local NotificacionEvent = Red.evento("NotificacionEvent")
local DialogoEvent = Red.evento("DialogoEvent")

Mundo.asegurar()
Botin.iniciar()

-- === Cooldown por jugador y accion ===
local cooldowns: { [Player]: { [string]: number } } = {}
local function enCooldown(jugador: Player, accion: string, segundos: number): boolean
	local ahora = os.clock()
	local mapa = cooldowns[jugador]
	if not mapa then
		mapa = {}
		cooldowns[jugador] = mapa
	end
	if ahora - (mapa[accion] or 0) < segundos then
		return true
	end
	mapa[accion] = ahora
	return false
end
Players.PlayerRemoving:Connect(function(jugador)
	cooldowns[jugador] = nil
end)

local function notificar(jugador: Player, texto: string, tipo: string)
	NotificacionEvent:FireClient(jugador, texto, tipo)
end

-- === Acciones de la caseta ===

local function reciclar(jugador: Player)
	local resumen = Bolsa.depositar(jugador)
	if not resumen then
		notificar(jugador, Textos.PATIO.bolsaVacia, "aviso")
		return
	end
	if resumen.dinero > 0 then
		local plantilla = if resumen.bonus then Textos.PATIO.recicladoBonus else Textos.PATIO.reciclado
		notificar(jugador, Textos.formatear(plantilla, { objetos = resumen.objetos, dinero = resumen.dinero }), "dinero")
	end
	for _, id in resumen.mascotasNuevas do
		local def = DefinicionesMascotas.obtener(id)
		if def then
			notificar(jugador, Textos.formatear(Textos.NOTIFICACIONES.mascotaNueva, { nombre = def.nombre }), "exito")
		end
	end
	for _, id in resumen.fragmentosCompletos do
		local def = DefinicionesMascotas.obtener(id)
		if def then
			notificar(jugador, Textos.formatear(Textos.NOTIFICACIONES.fragmentosCompletos, { nombre = def.nombre }), "exito")
		end
	end
	if resumen.quedaron > 0 then
		notificar(jugador, Textos.PATIO.almacenLleno, "aviso")
	end
end

local function comprarRefresco(jugador: Player)
	if not Economia.gastar(jugador, GameConfig.PRECIO_REFRESCO) then
		notificar(jugador, Textos.PATIO.sinDinero, "aviso")
		return
	end
	local restaurado = Energia.refresco(jugador)
	Perfiles.estadistica(jugador, "refrescos", 1)
	notificar(jugador, Textos.formatear(Textos.PATIO.refresco, { energia = restaurado }), "exito")
end

local saludos = { Textos.NPC.saludo1, Textos.NPC.saludo2, Textos.NPC.saludo3 }
local turnoSaludo: { [Player]: number } = {}

local function hablar(jugador: Player)
	local i = ((turnoSaludo[jugador] or 0) % #saludos) + 1
	turnoSaludo[jugador] = i
	DialogoEvent:FireClient(jugador, "DonaChatarra", saludos[i], true)
end

-- === Un listener para todos los prompts del patio y la caseta ===

ProximityPromptService.PromptTriggered:Connect(function(prompt, jugador)
	if not Perfiles.obtener(jugador) then
		return
	end
	local monton = Botin.montonDe(prompt)
	if monton then
		if enCooldown(jugador, "excavar", 0.5) then
			return
		end
		local ok, motivo = Botin.excavar(jugador, monton)
		if not ok then
			if motivo == "sinEnergia" then
				notificar(jugador, Textos.PATIO.sinEnergia, "aviso")
			elseif motivo == "agotado" then
				notificar(jugador, Textos.PATIO.montonAgotado, "aviso")
			end
		end
		return
	end
	local modelo = Mundo.modeloDe(prompt)
	if not modelo then
		return
	end
	if CollectionService:HasTag(modelo, "Contenedor") then
		if not enCooldown(jugador, "reciclar", 0.5) then
			reciclar(jugador)
		end
	elseif CollectionService:HasTag(modelo, "MaquinaRefrescos") then
		if not enCooldown(jugador, "refresco", 0.5) then
			comprarRefresco(jugador)
		end
	elseif modelo:GetAttribute("NPC") == "DonaChatarra" then
		if not enCooldown(jugador, "hablar", 0.5) then
			hablar(jugador)
		end
	end
end)

-- === Remotes ===

ReclamarObjetoEvent.OnServerEvent:Connect(function(jugador, objetoId)
	if typeof(objetoId) ~= "string" or enCooldown(jugador, "reclamar", GameConfig.COOLDOWN_REMOTE) then
		return
	end
	Botin.reclamar(jugador, objetoId, "clic")
end)

LanzarObjetoEvent.OnServerEvent:Connect(function(jugador, punto, fuerza)
	if typeof(punto) ~= "Vector3" or typeof(fuerza) ~= "number" or enCooldown(jugador, "lanzar", 0.4) then
		return
	end
	local ok, motivo = Botin.lanzarBolsa(jugador, punto, fuerza)
	if not ok then
		if motivo == "demasiadoCerca" then
			notificar(jugador, Textos.PATIO.demasiadoCerca, "aviso")
		elseif motivo == "demasiadoLejos" then
			notificar(jugador, Textos.PATIO.demasiadoLejos, "aviso")
		elseif motivo == "nadaQueLanzar" then
			notificar(jugador, Textos.PATIO.nadaQueLanzar, "aviso")
		end
	end
end)

Players.PlayerRemoving:Connect(function(jugador)
	turnoSaludo[jugador] = nil
end)
