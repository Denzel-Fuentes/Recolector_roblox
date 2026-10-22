--!strict
--[[
	Insignias (ModuleScript)
	Unica responsabilidad: dar las 16 insignias (Config/DefinicionesInsignias)
	cuando el perfil cumple su condicion: se anotan en perfil.logros (el
	panel las ensena desde ahi) y, si la insignia tiene badgeId, se otorga el
	Badge de Roblox.

	Se comprueban cada vez que el perfil cambia (Perfiles.alCambiar, como
	mucho 4 veces por segundo por jugador): son 16 comparaciones de numeros
	que ya estan en el perfil, mas barato que engancharse a cada senal que
	mueve una estadistica, y ningun modulo tiene que acordarse de avisar.

	Los badgeId se rellenan despues de crearlos en el Creator Dashboard: a
	quien ya tenia la insignia en el perfil se le otorga el Badge al entrar.
	BadgeService va siempre en pcall y en su propio hilo (puede tardar o
	fallar; nunca debe frenar el juego).
]]

local BadgeService = game:GetService("BadgeService")
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

-- Otorga el Badge de Roblox si existe y aun no lo tiene
local function otorgarBadge(jugador: Player, def: DefinicionesInsignias.Insignia)
	if def.badgeId == 0 then
		return
	end
	task.spawn(function()
		local ok, tiene = pcall(function()
			return BadgeService:UserHasBadgeAsync(jugador.UserId, def.badgeId)
		end)
		if ok and not tiene and jugador.Parent then
			local otorgado, err = pcall(function()
				return BadgeService:AwardBadge(jugador.UserId, def.badgeId)
			end)
			if not otorgado then
				warn("[Insignias] no se pudo otorgar " .. def.id .. ": " .. tostring(err))
			end
		end
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

function Insignias.iniciar()
	Perfiles.alCargar:Connect(function(jugador, perfil)
		-- Las que ya tenia y cuyo Badge se creo despues
		for _, def in DefinicionesInsignias.LISTA do
			if perfil.logros[def.id] then
				otorgarBadge(jugador, def)
			end
		end
		Insignias.comprobar(jugador)
	end)
	Perfiles.alCambiar:Connect(function(jugador)
		Insignias.comprobar(jugador)
	end)
end

return Insignias
