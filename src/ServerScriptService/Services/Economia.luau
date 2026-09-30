--!strict
--[[
	Economia (ModuleScript)
	Unica responsabilidad: el dinero, la unica moneda (v2: sin gemas ni
	moneda premium) y sus reglas.

	El dinero lo paga Dona Chatarra al DEPOSITAR en el contenedor (recoger
	nunca paga); tambien las mascotas repetidas por encima del nivel 5 y los
	pedidos. Se gasta en mejoras y rebirths, nada mas.

	Nunca se resta sin comprobar antes: gastar() devuelve false y no toca nada si
	no alcanza. Las estadisticas de Ahorro (dineroMaximo) y de ganancia total se
	actualizan aqui para que ningun otro modulo tenga que recordarlo.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))

local Economia = {}

function Economia.dinero(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	return if perfil then perfil.dinero else 0
end

function Economia.ganar(jugador: Player, cantidad: number): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil or cantidad <= 0 then
		return 0
	end
	cantidad = math.floor(cantidad + 0.5)
	perfil.dinero += cantidad
	perfil.estadisticas.dineroGanadoTotal = (perfil.estadisticas.dineroGanadoTotal or 0) + cantidad
	if perfil.dinero > (perfil.estadisticas.dineroMaximo or 0) then
		perfil.estadisticas.dineroMaximo = perfil.dinero
	end
	Perfiles.marcarSucio(jugador)
	return cantidad
end

function Economia.puedePagar(jugador: Player, cantidad: number): boolean
	return Economia.dinero(jugador) >= cantidad
end

function Economia.gastar(jugador: Player, cantidad: number): boolean
	local perfil = Perfiles.obtener(jugador)
	if not perfil or cantidad < 0 or perfil.dinero < cantidad then
		return false
	end
	perfil.dinero -= cantidad
	perfil.estadisticas.dineroGastado = (perfil.estadisticas.dineroGastado or 0) + cantidad
	Perfiles.marcarSucio(jugador)
	return true
end

return Economia
