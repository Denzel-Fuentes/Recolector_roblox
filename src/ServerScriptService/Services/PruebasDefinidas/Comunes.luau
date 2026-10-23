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
local Bolsa = require(script.Parent.Parent:WaitForChild("Bolsa"))
local ObjetosPatio = require(script.Parent.Parent:WaitForChild("ObjetosPatio"))
local Movimiento = require(script.Parent.Parent:WaitForChild("Movimiento"))

local Comunes = {}

-- El primer jugador de la sesion de Play Solo
function Comunes.jugador(): Player
	local j = Players:GetPlayers()[1]
	assert(j, "no hay jugador conectado")
	return j
end

-- Teletransporta al personaje (un poco por encima para que no se hunda). Es
-- un salto del servidor: se avisa a Movimiento con el destino (mide desde
-- alli), que si no lo tomaria por un teletransporte del cliente y dejaria
-- 2 s sin recoger ni lanzar
function Comunes.teletransportar(j: Player, pos: Vector3)
	local ch = j.Character
	if ch then
		local destino = pos + Vector3.new(0, 3, 0)
		Movimiento.permitirSalto(j, destino)
		ch:PivotTo(CFrame.new(destino))
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

local PAPEL = { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 }

-- El servidor solo lanza la bolsa LLENA (P3, 22 oct): vacia la bolsa y la
-- llena hasta su capacidad (la del momento: nivel de la mejora y Bolsa XL)
-- con copias de `item` (por defecto un papel de $6), o con lo que devuelva
-- item(i) si es una funcion. Devuelve cuantas piezas metio.
function Comunes.llenarBolsa(j: Player, item: any?): number
	Bolsa.vaciar(j)
	local n = Bolsa.capacidad(j)
	local items = table.create(n)
	for i = 1, n do
		table.insert(items, if typeof(item) == "function" then item(i) else table.clone(item or PAPEL))
	end
	Bolsa.meterVarios(j, items)
	return n
end

-- Quita del suelo, sin cobrarlas, las bolsas caidas del jugador que dejaron
-- otras pruebas: las que buscan "su" bolsa no deben dar con una vieja, y el
-- tope de bolsas caidas (Lanzamiento) no debe reciclar ninguna a mitad
function Comunes.limpiarBolsasCaidas(j: Player)
	for _, obj in ObjetosPatio.bolsasDe(j) do
		ObjetosPatio.retirar(obj.id)
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
