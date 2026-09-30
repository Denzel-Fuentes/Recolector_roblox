--!nonstrict
--[[
	Comunes
	Ayudantes que comparten todas las pruebas.
]]

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local Cuadrantes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Cuadrantes"))

local Mundo = require(script.Parent.Parent:WaitForChild("Mundo"))
local Botin = require(script.Parent.Parent:WaitForChild("Botin"))

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

-- Un punto fuera del patio (donde se aparece, este donde este en el plano):
-- para las pruebas que salen del patio y vuelven
function Comunes.fueraDelPatio(): Vector3
	return Mundo.cframeAparicion().Position
end

-- Da por hechos los primeros lanzamientos del perfil: el primero siempre
-- entra (diseno v2) y las pruebas de fallos necesitan poder fallar
function Comunes.yaLanzo(j: Player)
	local Perfiles = require(script.Parent.Parent:WaitForChild("Perfiles"))
	local perfil = Perfiles.obtener(j)
	if perfil and (perfil.estadisticas.lanzamientos or 0) < 5 then
		perfil.estadisticas.lanzamientos = 5
		Perfiles.marcarSucio(j)
	end
end

-- n montones llenos de cuadrantes abiertos sin rebirths (los del norte se
-- abren con el Rebirth 1 y 2); si no hay bastantes, se repone el patio
function Comunes.montonesLlenos(n: number): { any }
	local llenos = {}
	for _, monton in Botin.montones() do
		if monton.estado == "lleno" and Cuadrantes.abierto(monton.cuadrante, 0) then
			table.insert(llenos, monton)
		end
	end
	if #llenos < n then
		Botin.repoblarAhora()
		return Comunes.montonesLlenos(n)
	end
	return llenos
end

-- Excava sin los limites de rendimiento (1 monton a medias por jugador, tope
-- de objetos del patio): las pruebas de otras cosas abren varios seguidos.
-- Las de los limites llaman a Botin.excavar directamente.
function Comunes.excavar(j: Player, m)
	Botin.liberarMontones(j)
	local tope = GameConfig.MAX_OBJETOS_PATIO
	GameConfig.MAX_OBJETOS_PATIO = math.huge
	local ok, motivo = Botin.excavar(j, m)
	GameConfig.MAX_OBJETOS_PATIO = tope
	return ok, motivo
end

-- Corre fn con una GameConfig.FUNCIONES encendida (lo pospuesto en la v2
-- sigue probandose para cuando se reactive)
function Comunes.conFuncion(nombre: string, fn: () -> any): any
	local antes = (GameConfig.FUNCIONES :: any)[nombre]
	;(GameConfig.FUNCIONES :: any)[nombre] = true
	local ok, resultado = pcall(fn)
	;(GameConfig.FUNCIONES :: any)[nombre] = antes
	if not ok then
		error(resultado, 0)
	end
	return resultado
end

return Comunes
