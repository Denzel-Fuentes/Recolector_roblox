--!strict
--[[
	EstadoCliente (ModuleScript)
	Unica responsabilidad: el espejo local de lo que el servidor publica
	(perfil, bolsa, energia) y senales para que la UI se redibuje.

	Es SOLO lectura: la UI nunca modifica estos datos, envia intencion por
	RemoteEvent y espera el siguiente snapshot. Asi ninguna pantalla puede
	quedarse con un numero inventado.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Utilidades = Shared:WaitForChild("Utilidades")
local Senal = require(Utilidades:WaitForChild("Senal"))
local Red = require(Utilidades:WaitForChild("Red"))
local Productos = require(Shared:WaitForChild("Config"):WaitForChild("Productos"))

local EstadoCliente = {}

EstadoCliente.perfil = nil :: any
EstadoCliente.cargado = false
EstadoCliente.modoDev = false
EstadoCliente.bolsa = { items = {} :: { any }, capacidad = 8 }
EstadoCliente.energia = { actual = 0, max = 100 }

EstadoCliente.alCambiarPerfil = Senal.nueva() :: Senal.Senal<any>
EstadoCliente.alCambiarBolsa = Senal.nueva() :: Senal.Senal<any>
EstadoCliente.alCambiarEnergia = Senal.nueva() :: Senal.Senal<number, number>

Red.evento("PerfilEvent").OnClientEvent:Connect(function(perfil, cargado, extras)
	EstadoCliente.perfil = perfil
	EstadoCliente.cargado = cargado == true
	EstadoCliente.modoDev = extras ~= nil and extras.modoDev == true
	EstadoCliente.alCambiarPerfil:Fire(perfil)
end)

Red.evento("BolsaEvent").OnClientEvent:Connect(function(items, capacidad)
	EstadoCliente.bolsa = { items = items or {}, capacidad = capacidad or 8 }
	EstadoCliente.alCambiarBolsa:Fire(EstadoCliente.bolsa)
end)

Red.evento("EnergiaEvent").OnClientEvent:Connect(function(actual, max)
	EstadoCliente.energia = { actual = actual, max = max }
	EstadoCliente.alCambiarEnergia:Fire(actual, max)
end)

function EstadoCliente.listo(): boolean
	return EstadoCliente.perfil ~= nil
end

function EstadoCliente.esperar(): any
	while not EstadoCliente.perfil do
		task.wait(0.1)
	end
	return EstadoCliente.perfil
end

function EstadoCliente.tienePase(idPase: string): boolean
	if EstadoCliente.modoDev then
		return true
	end
	local p = EstadoCliente.perfil
	return p ~= nil and p.pasesCache ~= nil and p.pasesCache[idPase] == true
end

function EstadoCliente.tieneTraje(id: string): boolean
	local p = EstadoCliente.perfil
	if p and p.trajes and p.trajes[id] then
		return true
	end
	local pase = Productos.paseParaTraje(id)
	return pase ~= nil and EstadoCliente.tienePase(pase.id)
end

function EstadoCliente.tieneSkin(id: string): boolean
	local pase = Productos.paseParaSkin(id)
	return pase ~= nil and EstadoCliente.tienePase(pase.id)
end

function EstadoCliente.nivelMejora(id: string): number
	local p = EstadoCliente.perfil
	return if p and p.mejoras then (p.mejoras[id] or 0) else 0
end

-- Copias por id de mascota: { uid -> copia }
function EstadoCliente.copiasDe(id: string): { [string]: any }
	local lista = {}
	local p = EstadoCliente.perfil
	if p and p.mascotas then
		for uid, copia in p.mascotas do
			if copia.id == id then
				lista[uid] = copia
			end
		end
	end
	return lista
end

function EstadoCliente.cuentaMascotas(): number
	local p = EstadoCliente.perfil
	local n = 0
	if p and p.mascotas then
		for _ in p.mascotas do
			n += 1
		end
	end
	return n
end

function EstadoCliente.estaExhibida(uid: string): number?
	local p = EstadoCliente.perfil
	if p and p.exhibidas then
		for indice, u in p.exhibidas do
			if u == uid then
				return tonumber(indice)
			end
		end
	end
	return nil
end

function EstadoCliente.estadistica(clave: string): number
	local p = EstadoCliente.perfil
	return if p and p.estadisticas then (p.estadisticas[clave] or 0) else 0
end

return EstadoCliente
