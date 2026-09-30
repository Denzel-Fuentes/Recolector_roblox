--!strict
--[[
	BotinHandler
	Cablea el patio: arranca Botin cuando el mundo esta listo y atiende
	  - ProximityPrompts del patio y la caseta (excavar, reciclar a mano; el
	    de Dona Chatarra solo abre la tienda y lo atiende el cliente,
	    Prompts.client),
	  - ReclamarObjetoEvent (clic dentro del Alcance, o la mira en el movil),
	  - LanzarObjetoEvent(punto, fuerza): lanzar la bolsa entera (punteria).
	Y avisa a TODOS los clientes de cada deposito (RecicladoraEvent con el
	material de cada objeto, "" si no es basura) para que la cinta de la
	recicladora lo transporte: es decorado compartido, no estado de juego.

	Un solo listener de ProximityPromptService.PromptTriggered para todo: se
	decide por el MODELO al que pertenece el prompt (atributo MontonId, tag
	Contenedor). Asi los prompts horneados en el place no
	necesitan scripts propios.

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
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))
local Cuadrantes = require(Shared:WaitForChild("Utilidades"):WaitForChild("Cuadrantes"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Mundo = require(Servicios:WaitForChild("Mundo"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Botin = require(Servicios:WaitForChild("Botin"))

local ReclamarObjetoEvent = Red.evento("ReclamarObjetoEvent")
local LanzarObjetoEvent = Red.evento("LanzarObjetoEvent")
local NotificacionEvent = Red.evento("NotificacionEvent")
local RecicladoraEvent = Red.evento("RecicladoraEvent")

Mundo.asegurar()
Botin.iniciar()

Bolsa.alDepositar:Connect(function(_, items)
	local materiales = table.create(#items)
	for _, item in items do
		table.insert(materiales, if item.tipo == "basura" then item.material or "" else "")
	end
	RecicladoraEvent:FireAllClients(materiales)
end)

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

local function notificar(jugador: Player, texto: string, tipo: string)
	NotificacionEvent:FireClient(jugador, texto, tipo)
end

-- === Acciones de la caseta ===

-- Entregar a mano junto al contenedor: funciona, pero sin bonus
local function reciclar(jugador: Player)
	local resumen = Bolsa.depositar(jugador)
	if not resumen then
		notificar(jugador, Textos.PATIO.bolsaVacia, "aviso")
		return
	end
	if resumen.dinero > 0 then
		notificar(jugador, Textos.formatear(Textos.PATIO.reciclado, { objetos = resumen.objetos, dinero = resumen.dinero }), "dinero")
	end
end

-- === Excavar ===

local function avisarExcavar(jugador: Player, monton: Botin.Monton, ok: boolean, motivo: string)
	if ok then
		return
	elseif motivo == "agotado" then
		notificar(jugador, Textos.PATIO.montonAgotado, "aviso")
	elseif motivo == "patioLleno" then
		notificar(jugador, Textos.PATIO.patioLleno, "aviso")
	elseif motivo == "yaTienesUno" then
		notificar(jugador, Textos.PATIO.montonPendiente, "aviso")
	elseif motivo == "bloqueado" then
		local def = Cuadrantes.definicion(monton.cuadrante)
		notificar(jugador, Textos.formatear(Textos.PATIO.cuadranteBloqueado, { n = if def then def.rebirth else 1 }), "aviso")
	end
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
		avisarExcavar(jugador, monton, ok, motivo)
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
	end
end)

-- === Remotes ===

-- (objetoId, porMira?): porMira = la recogida automatica de la mira en el
-- movil (mismas reglas que el clic, sin avisos de rechazo)
ReclamarObjetoEvent.OnServerEvent:Connect(function(jugador, objetoId, porMira)
	if typeof(objetoId) ~= "string" or enCooldown(jugador, "reclamar", GameConfig.COOLDOWN_REMOTE) then
		return
	end
	Botin.reclamar(jugador, objetoId, if porMira == true then "mira" else "clic")
end)

LanzarObjetoEvent.OnServerEvent:Connect(function(jugador, punto, fuerza)
	if typeof(punto) ~= "Vector3" or typeof(fuerza) ~= "number" or enCooldown(jugador, "lanzar", 0.4) then
		return
	end
	local ok, motivo = Botin.lanzarBolsa(jugador, punto, fuerza)
	if not ok then
		if motivo == "demasiadoCerca" then
			notificar(jugador, Textos.PATIO.demasiadoCerca, "aviso")
		elseif motivo == "nadaQueLanzar" then
			notificar(jugador, Textos.PATIO.nadaQueLanzar, "aviso")
		end
	end
end)

Players.PlayerRemoving:Connect(function(jugador)
	cooldowns[jugador] = nil
end)
