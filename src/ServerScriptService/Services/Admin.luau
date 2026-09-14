--!strict
--[[
	Admin (ModuleScript)
	Unica responsabilidad: quien es administrador. Lo es el creador del juego
	(game.CreatorId; si el juego es de un grupo, el propietario del grupo no se
	resuelve aqui: anadirlo a ADMINS) y cualquiera en Studio.

	Los comandos viven en AdminHandler; este modulo solo responde "si o no".
]]

local RunService = game:GetService("RunService")

local Admin = {}

-- UserIds con permisos ademas del creador (rellenar si hace falta)
local ADMINS: { [number]: boolean } = {}

function Admin.esAdmin(jugador: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and jugador.UserId == game.CreatorId then
		return true
	end
	return ADMINS[jugador.UserId] == true
end

return Admin
