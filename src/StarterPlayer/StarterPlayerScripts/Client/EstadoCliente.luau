--!strict
--[[
	EstadoCliente (ModuleScript)
	Unica responsabilidad: el espejo local de lo que el servidor publica
	(perfil, bolsa) y senales para que la UI se redibuje.

	Es SOLO lectura: la UI nunca modifica estos datos, envia intencion por
	RemoteEvent y espera el siguiente snapshot. Asi ninguna pantalla puede
	quedarse con un numero inventado.

	Dos caras del mismo dato:
	  - campos + senales (perfil, alCambiarPerfil...): para quien no es UI
	    (Escena, ControlPatio, Camara);
	  - EstadoCliente.reactivo: Values de Fusion para la UI. El perfil llega
	    hasta 4 veces por segundo y SIEMPRE como tablas nuevas, asi que la UI
	    no debe depender de la tabla entera: deriva primitivos con Computed
	    (use(perfil).dinero) y Fusion corta la propagacion si no cambiaron.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Utilidades = Shared:WaitForChild("Utilidades")
local Senal = require(Utilidades:WaitForChild("Senal"))
local Red = require(Utilidades:WaitForChild("Red"))
local Productos = require(Shared:WaitForChild("Config"):WaitForChild("Productos"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local EstadoCliente = {}

EstadoCliente.perfil = nil :: any
EstadoCliente.cargado = false
EstadoCliente.modoDev = false
EstadoCliente.bolsa = { items = {} :: { any }, capacidad = 10 }

EstadoCliente.alCambiarPerfil = Senal.nueva() :: Senal.Senal<any>
EstadoCliente.alCambiarBolsa = Senal.nueva() :: Senal.Senal<any>
-- Carga del lanzamiento (0..1) mientras se mantiene pulsado; la fija
-- ControlPatio y la pintan el HUD (barra derecha) y las manos.
EstadoCliente.cargaLanzamiento = 0
EstadoCliente.alCambiarCarga = Senal.nueva() :: Senal.Senal<number>

-- Scope del modulo: vive lo que dure la sesion, nunca se limpia
local scope = Fusion.scoped(Fusion)
EstadoCliente.reactivo = {
	perfil = scope:Value(nil :: any),
	cargado = scope:Value(false),
	modoDev = scope:Value(false),
	bolsa = scope:Value(EstadoCliente.bolsa),
	carga = scope:Value(0),
}

function EstadoCliente.fijarCarga(fraccion: number)
	EstadoCliente.cargaLanzamiento = math.clamp(fraccion, 0, 1)
	EstadoCliente.reactivo.carga:set(EstadoCliente.cargaLanzamiento)
	EstadoCliente.alCambiarCarga:Fire(EstadoCliente.cargaLanzamiento)
end

Red.evento("PerfilEvent").OnClientEvent:Connect(function(perfil, cargado, extras)
	EstadoCliente.perfil = perfil
	EstadoCliente.cargado = cargado == true
	EstadoCliente.modoDev = extras ~= nil and extras.modoDev == true
	EstadoCliente.reactivo.cargado:set(EstadoCliente.cargado)
	EstadoCliente.reactivo.modoDev:set(EstadoCliente.modoDev)
	EstadoCliente.reactivo.perfil:set(perfil)
	EstadoCliente.alCambiarPerfil:Fire(perfil)
end)

Red.evento("BolsaEvent").OnClientEvent:Connect(function(items, capacidad)
	EstadoCliente.bolsa = { items = items or {}, capacidad = capacidad or 10 }
	EstadoCliente.reactivo.bolsa:set(EstadoCliente.bolsa)
	EstadoCliente.alCambiarBolsa:Fire(EstadoCliente.bolsa)
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

function EstadoCliente.nivelMejora(id: string): number
	local p = EstadoCliente.perfil
	return if p and p.mejoras then (p.mejoras[id] or 0) else 0
end

function EstadoCliente.estadistica(clave: string): number
	local p = EstadoCliente.perfil
	return if p and p.estadisticas then (p.estadisticas[clave] or 0) else 0
end

return EstadoCliente
