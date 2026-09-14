--!strict
--[[
	Logros (ModuleScript)
	Unica responsabilidad: desbloquear los 40 logros cuando su condicion se
	cumple. La condicion se evalua con Utilidades/ProgresoLogros (compartido con
	el cliente) sobre el perfil; se reevalua cada vez que Perfiles publica un
	cambio (maximo 4 veces por segundo por jugador: 40 comprobaciones baratas).

	Al desbloquear: se anota en perfil.logros, se paga RECOMPENSA_LOGRO en $,
	se avisa al jugador (LogroEvent) y al servidor (FeedEvent), y si el logro
	tiene badgeId real se otorga la insignia (pcall: BadgeService puede fallar y
	no debe romper nada).

	Un logro nunca se pierde ni se vuelve a otorgar.
]]

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local DefinicionesLogros = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesLogros"))
local ProgresoLogros = require(Shared:WaitForChild("Utilidades"):WaitForChild("ProgresoLogros"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))

local LogroEvent = Red.evento("LogroEvent")
local FeedEvent = Red.evento("FeedEvent")

local Logros = {}

Logros.alDesbloquear = Senal.nueva() :: Senal.Senal<Player, string>

local evaluando: { [Player]: boolean } = {}

local function otorgar(jugador: Player, perfil: Perfiles.Perfil, logro: DefinicionesLogros.Logro)
	perfil.logros[logro.id] = true
	perfil.estadisticas.logrosDesbloqueados = (perfil.estadisticas.logrosDesbloqueados or 0) + 1
	Economia.ganar(jugador, GameConfig.RECOMPENSA_LOGRO)
	Perfiles.marcarSucio(jugador)
	LogroEvent:FireClient(jugador, logro.id)
	FeedEvent:FireAllClients(Textos.formatear(Textos.FEED.logro, { jugador = jugador.DisplayName, logro = logro.nombre }))
	if logro.badgeId ~= 0 then
		task.spawn(function()
			pcall(function()
				BadgeService:AwardBadge(jugador.UserId, logro.badgeId)
			end)
		end)
	end
	Logros.alDesbloquear:Fire(jugador, logro.id)
end

-- Devuelve cuantos se desbloquearon en esta pasada
function Logros.evaluar(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil or evaluando[jugador] then
		return 0
	end
	evaluando[jugador] = true
	local nuevos = 0
	for _, logro in DefinicionesLogros.LISTA do
		if not perfil.logros[logro.id] and ProgresoLogros.completado(perfil, logro) then
			otorgar(jugador, perfil, logro)
			nuevos += 1
		end
	end
	evaluando[jugador] = nil
	return nuevos
end

function Logros.cuenta(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0
	end
	local n = 0
	for _ in perfil.logros do
		n += 1
	end
	return n
end

return Logros
