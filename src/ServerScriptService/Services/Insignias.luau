--!strict
--[[
	Insignias (ModuleScript)
	Unica responsabilidad: dar las 20 insignias (Config/DefinicionesInsignias)
	cuando el perfil cumple su condicion: se anotan en perfil.logros (el
	panel las ensena desde ahi) y, si la insignia tiene badgeId, se otorga el
	Badge de Roblox.

	Se comprueban cada vez que el perfil cambia (Perfiles.alCambiar, como
	mucho 4 veces por segundo por jugador): son 20 comparaciones de numeros
	que ya estan en el perfil, mas barato que engancharse a cada senal que
	mueve una estadistica, y ningun modulo tiene que acordarse de avisar.

	=== Badges de Roblox ===
	Al entrar se pregunta de una vez que Badges tiene ya el jugador, con
	CheckUserBadgesAsync en lotes de hasta LOTE ids (antes: un
	UserHasBadgeAsync por insignia), y se guarda en una cache de la sesion.
	Con ella se otorgan las que tenia en el perfil y aun no tiene en Roblox
	(su Badge se creo despues) y, durante la partida, las nuevas, sin volver
	a preguntar. BadgeService va siempre en pcall y en su propio hilo (puede
	tardar o fallar; nunca debe frenar el juego). El servicio es sustituible
	en pruebas (Insignias.servicio). Cada llamada cede: despues se mira que el
	jugador siga (23 oct): si no, su cache ya se olvido y se volveria a crear
	para alguien que no esta (y se le preguntaria a Roblox por el).
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local DefinicionesInsignias = require(Config:WaitForChild("DefinicionesInsignias"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Red = require(Utilidades:WaitForChild("Red"))
local Senal = require(Utilidades:WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))

local LogroEvent = Red.evento("NotificacionEvent")

local Insignias = {}

-- (jugador, id) cada insignia nueva
Insignias.alConseguir = Senal.nueva() :: Senal.Senal<Player, string>

-- BadgeService o un sustituto con CheckUserBadgesAsync y AwardBadge
Insignias.servicio = BadgeService :: any
-- Maximo de ids por llamada a CheckUserBadgesAsync (limite de Roblox)
Insignias.LOTE = 10

-- Por jugador: badgeId -> true (lo tiene) | false (no lo tiene). Sin
-- entrada = no se sabe.
local tiene: { [Player]: { [number]: boolean } } = {}
-- Otorgamientos en curso (para no pedir el mismo dos veces a la vez)
local otorgando: { [Player]: { [number]: boolean } } = {}
-- Lo ultimo que respondio Roblox, para diagnostico (las pruebas lo leen)
local diagnostico: { string } = {}

local function anotar(texto: string)
	-- Lo que responde un servicio de prueba se marca: no es Roblox
	table.insert(diagnostico, if Insignias.servicio == BadgeService then texto else "(falso) " .. texto)
	if #diagnostico > 30 then
		table.remove(diagnostico, 1)
	end
end

function Insignias.diagnostico(): { string }
	return table.clone(diagnostico)
end

local function cacheDe(jugador: Player): { [number]: boolean }
	local c = tiene[jugador]
	if not c then
		c = {}
		tiene[jugador] = c
	end
	return c
end

-- Que Badges de `ids` tiene el jugador: pregunta en lotes de LOTE solo por
-- los que no estan en la cache y la rellena. Devuelve cuantas llamadas hizo.
-- Un lote que falla deja sus ids sin saber (se reintentaran).
function Insignias.consultarBadges(jugador: Player, ids: { number }): number
	if not jugador.Parent then
		return 0
	end
	local cache = cacheDe(jugador)
	local faltan = {}
	for _, id in ids do
		if id ~= 0 and cache[id] == nil and not table.find(faltan, id) then
			table.insert(faltan, id)
		end
	end
	local llamadas = 0
	for inicio = 1, #faltan, Insignias.LOTE do
		-- (cada lote cede: si se fue entre medias, no se pregunta mas)
		if not jugador.Parent then
			break
		end
		local lote = table.move(faltan, inicio, math.min(inicio + Insignias.LOTE - 1, #faltan), 1, {})
		llamadas += 1
		local ok, resultado = pcall(function()
			return Insignias.servicio:CheckUserBadgesAsync(jugador.UserId, lote)
		end)
		if ok and typeof(resultado) == "table" then
			for _, id in lote do
				cache[id] = table.find(resultado, id) ~= nil
			end
		else
			anotar(string.format("CheckUserBadgesAsync(%d ids) fallo: %s", #lote, tostring(resultado)))
		end
	end
	return llamadas
end

-- Si el jugador tiene ese Badge segun la cache (nil = no se sabe)
function Insignias.tieneBadge(jugador: Player, badgeId: number): boolean?
	local c = tiene[jugador]
	return c and c[badgeId]
end

-- Otorga el Badge de Roblox de la insignia si existe y no lo tiene ya
local function otorgarBadge(jugador: Player, def: DefinicionesInsignias.Insignia)
	local id = def.badgeId
	if id == 0 or not jugador.Parent then
		return
	end
	local cache = cacheDe(jugador)
	local enCurso = otorgando[jugador] or {}
	otorgando[jugador] = enCurso
	if cache[id] == true or enCurso[id] then
		return
	end
	enCurso[id] = true
	task.spawn(function()
		if cache[id] == nil then
			Insignias.consultarBadges(jugador, { id })
		end
		-- consultarBadges cede: si se fue, nada mas (su cache ya se olvido)
		if cache[id] == false and jugador.Parent then
			local ok, resultado = pcall(function()
				return Insignias.servicio:AwardBadge(jugador.UserId, id)
			end)
			if ok and resultado == true then
				cache[id] = true
				anotar(string.format("AwardBadge %s (%d): otorgada", def.id, id))
			elseif ok then
				anotar(string.format("AwardBadge %s (%d): devolvio %s", def.id, id, tostring(resultado)))
			else
				anotar(string.format("AwardBadge %s (%d): error %s", def.id, id, tostring(resultado)))
				warn("[Insignias] no se pudo otorgar " .. def.id .. ": " .. tostring(resultado))
			end
		end
		enCurso[id] = nil
	end)
end

-- Comprueba todas las que le faltan; devuelve cuantas nuevas
function Insignias.comprobar(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0
	end
	local nuevas = 0
	for _, def in DefinicionesInsignias.LISTA do
		if not perfil.logros[def.id] and DefinicionesInsignias.cumple(def, perfil) then
			perfil.logros[def.id] = true
			nuevas += 1
			Perfiles.marcarSucio(jugador)
			otorgarBadge(jugador, def)
			-- "logro": la tarjeta grande con el trofeo (Notificaciones). Va el
			-- id: el cliente pone nombre y descripcion en su idioma
			LogroEvent:FireClient(jugador, def.id, "logro")
			Insignias.alConseguir:Fire(jugador, def.id)
		end
	end
	return nuevas
end

-- Al entrar: una consulta en lote de todos los Badges del juego y se
-- otorgan los de las insignias que ya tenia en el perfil
function Insignias.alEntrar(jugador: Player, perfil: Perfiles.Perfil): number
	local ids = {}
	for _, def in DefinicionesInsignias.LISTA do
		if def.badgeId ~= 0 then
			table.insert(ids, def.badgeId)
		end
	end
	local llamadas = Insignias.consultarBadges(jugador, ids)
	-- La consulta cede: si se fue mientras, no se recrea su cache
	if not jugador.Parent then
		return llamadas
	end
	for _, def in DefinicionesInsignias.LISTA do
		if perfil.logros[def.id] then
			otorgarBadge(jugador, def)
		end
	end
	return llamadas
end

-- Olvida la cache de un jugador (al salir; las pruebas, para empezar de cero)
function Insignias.olvidar(jugador: Player)
	tiene[jugador] = nil
	otorgando[jugador] = nil
end

function Insignias.iniciar()
	Perfiles.alCargar:Connect(function(jugador, perfil)
		task.spawn(Insignias.alEntrar, jugador, perfil)
		Insignias.comprobar(jugador)
	end)
	Perfiles.alCambiar:Connect(function(jugador)
		Insignias.comprobar(jugador)
	end)
	Players.PlayerRemoving:Connect(Insignias.olvidar)
end

return Insignias
