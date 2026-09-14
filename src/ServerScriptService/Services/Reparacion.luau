--!strict
--[[
	Reparacion (ModuleScript)
	Unica responsabilidad: los dos procesos de la mesa de reparacion, como en
	KOTAMON:

	  Limpieza     una copia SUCIA pasa a limpia. El minijuego (arrastrar sobre
	               las manchas) es del cliente; aqui solo se valida que paso un
	               tiempo minimo plausible desde iniciar() y se aplica.
	  Ensamblaje   5 fragmentos de una mascota -> 1 copia en estado Regular,
	               limpia. El minijuego (girar piezas) es del cliente, misma
	               validacion de tiempo. Con el Game Pass Auto-Ensamblaje se
	               completa al INSTANTE en iniciar(): es la correccion deliberada
	               de la queja #2 del original (girar piezas durante horas).

	El cliente no puede fabricar resultados: el servidor decide que copia se
	limpia y cuando se consumen los fragmentos, y solo si hay sesion iniciada.
	Una sesion por jugador; iniciar otra cancela la anterior.

	Si el almacen esta lleno el ensamblaje NO consume los fragmentos: se avisa y
	se conserva todo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local DefinicionesMascotas = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMascotas"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))

type Sesion = {
	tipo: string, -- "limpieza" | "ensamblaje"
	clave: string, -- uid o idMascota
	inicio: number,
}

local Reparacion = {}

local sesiones: { [Player]: Sesion } = {}

function Reparacion.cancelar(jugador: Player)
	sesiones[jugador] = nil
end

-- === Limpieza ===

function Reparacion.iniciarLimpieza(jugador: Player, uid: string): (boolean, string)
	local perfil = Perfiles.obtener(jugador)
	local copia = perfil and perfil.mascotas[uid]
	if not perfil or not copia then
		return false, "noExiste"
	end
	if not copia.sucia then
		return false, "yaLimpia"
	end
	sesiones[jugador] = { tipo = "limpieza", clave = uid, inicio = os.clock() }
	return true, uid
end

function Reparacion.terminarLimpieza(jugador: Player, uid: string): (boolean, string)
	local sesion = sesiones[jugador]
	if not sesion or sesion.tipo ~= "limpieza" or sesion.clave ~= uid then
		return false, "sinSesion"
	end
	if os.clock() - sesion.inicio < GameConfig.MIN_SEGUNDOS_LIMPIEZA then
		return false, "demasiadoRapido"
	end
	sesiones[jugador] = nil
	if not Mascotas.limpiar(jugador, uid) then
		return false, "noExiste"
	end
	return true, uid
end

-- === Ensamblaje ===

local function ensamblar(jugador: Player, id: string): (boolean, string)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false, "sinPerfil"
	end
	if (perfil.fragmentos[id] or 0) < GameConfig.FRAGMENTOS_POR_MASCOTA then
		return false, "faltanFragmentos"
	end
	if not Mascotas.hayEspacio(jugador) then
		return false, "almacenLleno"
	end
	perfil.fragmentos[id] = 0
	local uid = Mascotas.agregar(jugador, id, 2, false)
	if not uid then
		perfil.fragmentos[id] = GameConfig.FRAGMENTOS_POR_MASCOTA
		return false, "almacenLleno"
	end
	Perfiles.estadistica(jugador, "ensamblajes", 1)
	Perfiles.marcarSucio(jugador)
	return true, uid
end

-- Devuelve (ok, "auto" | "iniciado" | motivo). "auto" = ya esta hecha.
function Reparacion.iniciarEnsamblaje(jugador: Player, id: string): (boolean, string)
	local perfil = Perfiles.obtener(jugador)
	if not perfil or not DefinicionesMascotas.obtener(id) then
		return false, "noExiste"
	end
	if (perfil.fragmentos[id] or 0) < GameConfig.FRAGMENTOS_POR_MASCOTA then
		return false, "faltanFragmentos"
	end
	if not Mascotas.hayEspacio(jugador) then
		return false, "almacenLleno"
	end
	if Monetizacion.tienePase(jugador, "AutoEnsamblaje") then
		local ok, motivo = ensamblar(jugador, id)
		if ok then
			Perfiles.estadistica(jugador, "autoEnsamblajes", 1)
			return true, "auto"
		end
		return false, motivo
	end
	sesiones[jugador] = { tipo = "ensamblaje", clave = id, inicio = os.clock() }
	return true, "iniciado"
end

function Reparacion.terminarEnsamblaje(jugador: Player, id: string): (boolean, string)
	local sesion = sesiones[jugador]
	if not sesion or sesion.tipo ~= "ensamblaje" or sesion.clave ~= id then
		return false, "sinSesion"
	end
	if os.clock() - sesion.inicio < GameConfig.MIN_SEGUNDOS_ENSAMBLAJE then
		return false, "demasiadoRapido"
	end
	sesiones[jugador] = nil
	return ensamblar(jugador, id)
end

Players.PlayerRemoving:Connect(function(jugador)
	sesiones[jugador] = nil
end)

return Reparacion
