--!nonstrict
--[[
	Comunes
	Ayudantes que comparten todas las pruebas.
]]

local Players = game:GetService("Players")

local Comunes = {}

-- El primer jugador de la sesion de Play Solo
function Comunes.jugador(): Player
	local j = Players:GetPlayers()[1]
	assert(j, "no hay jugador conectado")
	return j
end

-- Teletransporta al personaje (un poco por encima para que no se hunda)
function Comunes.teletransportar(j: Player, pos: Vector3)
	local ch = j.Character
	if ch then
		ch:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
	end
end

return Comunes
