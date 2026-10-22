--!strict
--[[
	Tutorial (ModuleScript)
	Unica responsabilidad: en que paso del tutorial jugable esta cada jugador
	(perfil.tutorial = pasos completados, DefinicionesTutorial) y avanzarlo.

	No enseña con carteles: escucha lo que el jugador HACE (senales de los
	modulos de abajo) y cuando hace lo que pide el paso actual, lo completa.
	Asi un jugador que ya sabe jugar lo termina sin leerlo. El cliente
	(UI/Tutorial) pinta el paso actual leyendo el perfil; aqui no hay remotes.

	Ayudas que dan otros modulos: el primer lanzamiento de un perfil siempre
	entra y los cinco primeros llevan linea de trayectoria (Lanzamiento,
	ControlPatio); todos aparecen en la plaza, con el patio a la vista
	(AparicionHandler).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefinicionesTutorial = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesTutorial"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Patio = require(Servicios:WaitForChild("Patio"))
local Montones = require(Servicios:WaitForChild("Montones"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Lanzamiento = require(Servicios:WaitForChild("Lanzamiento"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Pedidos = require(Servicios:WaitForChild("Pedidos"))
local Rebirths = require(Servicios:WaitForChild("Rebirths"))

local Tutorial = {}

function Tutorial.completados(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	return if perfil then (perfil.tutorial or 0) else DefinicionesTutorial.TOTAL
end

function Tutorial.terminado(jugador: Player): boolean
	return Tutorial.completados(jugador) >= DefinicionesTutorial.TOTAL
end

-- Lo que ya se cumple sin esperar a un evento (al entrar en el paso)
local function yaCumple(jugador: Player, id: string): boolean
	if id == "patio" then
		return Patio.estaDentro(jugador)
	elseif id == "llenar" then
		return Bolsa.estaLlena(jugador)
	elseif id == "pedido" then
		return Perfiles.leerEstadistica(jugador, "pedidosCompletados") >= 1
	elseif id == "rebirth" then
		return Rebirths.cuantos(jugador) >= 1
	end
	return false
end

-- Completa `id` si es el paso actual, y los siguientes que ya se cumplan
function Tutorial.completar(jugador: Player, id: string)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return
	end
	local paso = DefinicionesTutorial.actual(perfil.tutorial or 0)
	if not paso or paso.id ~= id then
		return
	end
	perfil.tutorial = (perfil.tutorial or 0) + 1
	Perfiles.marcarSucio(jugador)
	local siguiente = DefinicionesTutorial.actual(perfil.tutorial)
	if siguiente and yaCumple(jugador, siguiente.id) then
		Tutorial.completar(jugador, siguiente.id)
	end
end

-- Para pruebas y admin: fija el numero de pasos completados
function Tutorial.fijar(jugador: Player, completados: number)
	local perfil = Perfiles.obtener(jugador)
	if perfil then
		perfil.tutorial = math.clamp(completados, 0, DefinicionesTutorial.TOTAL)
		Perfiles.marcarSucio(jugador)
	end
end

function Tutorial.iniciar()
	Perfiles.alCargar:Connect(function(jugador, perfil)
		local paso = DefinicionesTutorial.actual(perfil.tutorial or 0)
		if paso and yaCumple(jugador, paso.id) then
			Tutorial.completar(jugador, paso.id)
		end
	end)
	Patio.alCambiar:Connect(function(jugador, dentro)
		if dentro then
			Tutorial.completar(jugador, "patio")
		end
	end)
	Montones.alExcavar:Connect(function(jugador)
		-- Excavar desde fuera del patio (en el borde) tambien cuenta como llegar
		Tutorial.completar(jugador, "patio")
		Tutorial.completar(jugador, "excavar")
	end)
	Bolsa.alCambiar:Connect(function(jugador)
		if Bolsa.estaLlena(jugador) then
			Tutorial.completar(jugador, "llenar")
		end
	end)
	Lanzamiento.alAcertar:Connect(function(jugador)
		Tutorial.completar(jugador, "lanzar")
	end)
	Mejoras.alComprar:Connect(function(jugador)
		Tutorial.completar(jugador, "mejora")
	end)
	Bolsa.alResumen:Connect(function(jugador, resumen)
		if resumen.separadas >= DefinicionesTutorial.SEPARADAS_PARA_PASO and resumen.separadas > resumen.malSeparadas then
			Tutorial.completar(jugador, "separar")
		end
	end)
	Pedidos.alCumplir:Connect(function(jugador)
		Tutorial.completar(jugador, "pedido")
	end)
	Rebirths.alRenacer:Connect(function(jugador)
		Tutorial.completar(jugador, "rebirth")
	end)
end

return Tutorial
