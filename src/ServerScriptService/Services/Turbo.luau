--!strict
--[[
	Turbo (ModuleScript)
	Unica responsabilidad: el Turbo de dinero, x2 a todo lo que se recicla
	mientras dura (perfil.turboHasta, un os.time()). Lo dan los pedidos (10
	min por completar los tres del dia) y el producto de Robux "Turbo 15
	min" (Config/Productos), que se registra aqui: Monetizacion no sabe que
	hace cada producto.

	El tiempo se ACUMULA: comprar o ganar un Turbo con otro en marcha suma
	sus minutos al final del que queda. Cuenta en tiempo real (os.time), no
	en tiempo jugado: es un empujon para la sesion, no algo que guardar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Productos = require(Config:WaitForChild("Productos"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))

local Turbo = {}

Turbo.MULTIPLICADOR = 2

-- Para pruebas: el reloj se puede adelantar
Turbo.ahora = os.time

function Turbo.restante(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0
	end
	return math.max(0, (perfil.turboHasta or 0) - Turbo.ahora())
end

function Turbo.activo(jugador: Player): boolean
	return Turbo.restante(jugador) > 0
end

function Turbo.multiplicador(jugador: Player): number
	return if Turbo.activo(jugador) then Turbo.MULTIPLICADOR else 1
end

-- Suma `segundos` de Turbo (al final del que quede)
function Turbo.anadir(jugador: Player, segundos: number)
	local perfil = Perfiles.obtener(jugador)
	if not perfil or segundos <= 0 then
		return
	end
	perfil.turboHasta = math.max(perfil.turboHasta or 0, Turbo.ahora()) + segundos
	Perfiles.marcarSucio(jugador)
end

for _, producto in Productos.PRODUCTOS do
	if producto.turboMinutos then
		Monetizacion.registrarProducto(producto.id, function(jugador)
			if not Perfiles.obtener(jugador) then
				return false
			end
			Turbo.anadir(jugador, producto.turboMinutos * 60)
			return true
		end)
	end
end

return Turbo
