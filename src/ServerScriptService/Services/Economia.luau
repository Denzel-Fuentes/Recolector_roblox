--!strict
--[[
	Economia (ModuleScript)
	Unica responsabilidad: las dos monedas y sus reglas.

	  $ (dinero)   gratuita. Billetes literales: se encuentran en la basura, los
	               paga Dona Chatarra por reciclar/tesoros/duplicados. Compra
	               mejoras, refrescos y el Contenedor Dorado.
	  Gemas        premium. Solo entran por Developer Products (Monetizacion) o
	               comandos de admin. Compran el Sobre Premium y aceleran el
	               Contenedor Dorado.

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

function Economia.gemas(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	return if perfil then perfil.gemas else 0
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

function Economia.ganarGemas(jugador: Player, cantidad: number): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil or cantidad <= 0 then
		return 0
	end
	cantidad = math.floor(cantidad + 0.5)
	perfil.gemas += cantidad
	perfil.estadisticas.gemasGanadas = (perfil.estadisticas.gemasGanadas or 0) + cantidad
	Perfiles.marcarSucio(jugador)
	return cantidad
end

function Economia.puedePagarGemas(jugador: Player, cantidad: number): boolean
	return Economia.gemas(jugador) >= cantidad
end

function Economia.gastarGemas(jugador: Player, cantidad: number): boolean
	local perfil = Perfiles.obtener(jugador)
	if not perfil or cantidad < 0 or perfil.gemas < cantidad then
		return false
	end
	perfil.gemas -= cantidad
	perfil.estadisticas.gemasGastadas = (perfil.estadisticas.gemasGastadas or 0) + cantidad
	Perfiles.marcarSucio(jugador)
	return true
end

return Economia
