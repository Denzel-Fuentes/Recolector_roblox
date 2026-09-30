--!strict
--[[
	Mascotas (ModuleScript)
	Unica responsabilidad: la coleccion de mascotas de cada jugador (diseno
	v2) y lo que le dan en el patio. Una mascota se tiene o no, y tiene un
	NIVEL 1..5; no hay copias, estados, limpieza ni venta.

	  agregar    lo que da una capsula: si es nueva, nivel 1 (y se equipa sola
	             si queda hueco); si ya la tienes, sube un nivel; pasado el 5
	             se convierte en dinero (VALOR_REPETIDA x multiplicador de
	             rebirth). Con las 40, llega el Rey Reciclon.
	  equipar    1 hueco, 2 desde el Rebirth 3 (el pase Tercera mascota, lote
	             8, da otro). El Rey va siempre contigo sin ocupar hueco.
	  bonus      las equipadas suman su bonus al dinero de SU material
	             (Comun +20 -> +40 %, Rara +40 -> +80 %, Epica +80 -> +160 %
	             del nivel 1 al 5); el Rey, +50 % a todo. Lo aplica Bolsa.
	  iman       las Raras y Epicas equipadas atraen las piezas de su material
	             (6 y 10 studs). Lo aplica Iman.

	Quien necesita enterarse escucha alAgregar (capsulas, insignias) y
	alCambiarEquipadas (Seguidores).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local DefinicionesRebirths = require(Config:WaitForChild("DefinicionesRebirths"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))

export type Resultado = {
	id: string,
	nueva: boolean,
	nivel: number, -- nivel tras agregarla
	dinero: number, -- > 0 si ya estaba al maximo y se convirtio en dinero
	equipada: boolean, -- se equipo sola
}

local Mascotas = {}

Mascotas.alAgregar = Senal.nueva() :: Senal.Senal<Player, Resultado>
Mascotas.alCambiarEquipadas = Senal.nueva() :: Senal.Senal<Player>
Mascotas.alRey = Senal.nueva() :: Senal.Senal<Player>

-- Huecos que da algo mas que los rebirths (el pase Tercera mascota, lote 8):
-- lo registra quien lo sabe, asi Mascotas no depende de Monetizacion
Mascotas.huecosExtra = nil :: ((Player) -> number)?

function Mascotas.nivel(jugador: Player, id: string): number
	local perfil = Perfiles.obtener(jugador)
	return if perfil then (perfil.mascotas[id] or 0) else 0
end

function Mascotas.tiene(jugador: Player, id: string): boolean
	return Mascotas.nivel(jugador, id) > 0
end

-- Distintas que tiene (sin el Rey)
function Mascotas.distintas(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	local n = 0
	if perfil then
		for id in perfil.mascotas do
			if id ~= DefinicionesMascotas.ID_REY then
				n += 1
			end
		end
	end
	return n
end

function Mascotas.setCompleto(jugador: Player, setId: string): boolean
	for _, def in DefinicionesMascotas.porSet(setId) do
		if not Mascotas.tiene(jugador, def.id) then
			return false
		end
	end
	return true
end

function Mascotas.huecos(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	local base = DefinicionesRebirths.huecosMascota(if perfil then perfil.rebirths else 0)
	return base + (if Mascotas.huecosExtra then Mascotas.huecosExtra(jugador) else 0)
end

function Mascotas.equipadas(jugador: Player): { string }
	local perfil = Perfiles.obtener(jugador)
	return if perfil then perfil.equipadas else {}
end

-- Deja la lista de equipadas coherente: solo mascotas que tiene, sin el Rey,
-- sin repetir y sin pasar de los huecos (p. ej. al perder un pase)
local function sanear(jugador: Player, perfil: Perfiles.Perfil)
	local limpia, vistas = {}, {}
	local huecos = Mascotas.huecos(jugador)
	for _, id in perfil.equipadas do
		if #limpia < huecos and not vistas[id] and (perfil.mascotas[id] or 0) > 0 and id ~= DefinicionesMascotas.ID_REY then
			table.insert(limpia, id)
			vistas[id] = true
		end
	end
	if #limpia ~= #perfil.equipadas then
		perfil.equipadas = limpia
		Perfiles.marcarSucio(jugador)
		Mascotas.alCambiarEquipadas:Fire(jugador)
	end
end

function Mascotas.sanear(jugador: Player)
	local perfil = Perfiles.obtener(jugador)
	if perfil then
		sanear(jugador, perfil)
	end
end

-- Ponerse o quitarse una mascota. Devuelve (ok, motivo)
function Mascotas.equipar(jugador: Player, id: string, poner: boolean): (boolean, string)
	local perfil = Perfiles.obtener(jugador)
	if not perfil or not DefinicionesMascotas.obtener(id) or id == DefinicionesMascotas.ID_REY then
		return false, "noExiste"
	end
	local indice = table.find(perfil.equipadas, id)
	if not poner then
		if indice then
			table.remove(perfil.equipadas, indice)
			Perfiles.marcarSucio(jugador)
			Mascotas.alCambiarEquipadas:Fire(jugador)
		end
		return true, "quitada"
	end
	if not Mascotas.tiene(jugador, id) then
		return false, "noLaTienes"
	end
	if indice then
		return true, "yaEquipada"
	end
	if #perfil.equipadas >= Mascotas.huecos(jugador) then
		return false, "huecosLlenos"
	end
	table.insert(perfil.equipadas, id)
	Perfiles.marcarSucio(jugador)
	Mascotas.alCambiarEquipadas:Fire(jugador)
	return true, "equipada"
end

local function comprobarRey(jugador: Player, perfil: Perfiles.Perfil)
	if (perfil.mascotas[DefinicionesMascotas.ID_REY] or 0) > 0 then
		return
	end
	for _, def in DefinicionesMascotas.LISTA do
		if def.id ~= DefinicionesMascotas.ID_REY and (perfil.mascotas[def.id] or 0) == 0 then
			return
		end
	end
	perfil.mascotas[DefinicionesMascotas.ID_REY] = 1
	Perfiles.marcarSucio(jugador)
	Mascotas.alRey:Fire(jugador)
	Mascotas.alCambiarEquipadas:Fire(jugador)
end

-- Lo que da una capsula con esta mascota
function Mascotas.agregar(jugador: Player, id: string): Resultado
	local perfil = Perfiles.obtener(jugador)
	local def = DefinicionesMascotas.obtener(id)
	local resultado: Resultado = { id = id, nueva = false, nivel = 0, dinero = 0, equipada = false }
	if not perfil or not def then
		return resultado
	end
	local nivel = perfil.mascotas[id] or 0
	if nivel == 0 then
		perfil.mascotas[id] = 1
		resultado.nueva = true
		resultado.nivel = 1
		if id ~= DefinicionesMascotas.ID_REY and #perfil.equipadas < Mascotas.huecos(jugador) then
			table.insert(perfil.equipadas, id)
			resultado.equipada = true
		end
	elseif nivel < DefinicionesMascotas.NIVEL_MAX then
		perfil.mascotas[id] = nivel + 1
		resultado.nivel = nivel + 1
	else
		resultado.nivel = nivel
		local valor = (DefinicionesMascotas.VALOR_REPETIDA[def.rareza] or 0) * DefinicionesRebirths.multiplicador(perfil.rebirths)
		resultado.dinero = Economia.ganar(jugador, valor)
	end
	Perfiles.marcarSucio(jugador)
	Mascotas.alAgregar:Fire(jugador, resultado)
	if resultado.equipada or (resultado.nivel > 1 and table.find(perfil.equipadas, id)) then
		-- nueva equipada, o una equipada que cambia de aspecto al subir
		Mascotas.alCambiarEquipadas:Fire(jugador)
	end
	if resultado.nueva then
		comprobarRey(jugador, perfil)
	end
	return resultado
end

-- Bonus al dinero de un material: la suma de las equipadas de ese material,
-- mas el Rey (a todo)
function Mascotas.bonusMaterial(jugador: Player, material: string): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0
	end
	local bonus = 0
	for _, id in perfil.equipadas do
		local def = DefinicionesMascotas.obtener(id)
		if def and def.material == material then
			bonus += DefinicionesMascotas.bonus(def, perfil.mascotas[id] or 1)
		end
	end
	if (perfil.mascotas[DefinicionesMascotas.ID_REY] or 0) > 0 then
		bonus += DefinicionesMascotas.BONUS_REY
	end
	return bonus
end

-- Radio del iman por material (el mayor de sus equipadas Raras y Epicas)
function Mascotas.radiosIman(jugador: Player): { [string]: number }
	local perfil = Perfiles.obtener(jugador)
	local radios = {}
	if perfil then
		for _, id in perfil.equipadas do
			local def = DefinicionesMascotas.obtener(id)
			local radio = if def then DefinicionesMascotas.iman(def) else 0
			if def and radio > (radios[def.material] or 0) then
				radios[def.material] = radio
			end
		end
	end
	return radios
end

Perfiles.alCargar:Connect(function(jugador, perfil)
	sanear(jugador, perfil)
end)

return Mascotas
