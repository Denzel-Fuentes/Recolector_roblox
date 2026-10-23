--!strict
--[[
	ActividadHandler
	Solo cableado (C3, 22 oct): cada accion de juego marca al jugador como
	activo en Services/Actividad. Va aparte para que Actividad no requiera
	ningun servicio del juego (lo requiere Turbo, y Bolsa requiere Turbo).

	  recoger una pieza           ObjetosPatio.alRecoger (jugador, item, posicion)
	  excavar un monton           Montones.alExcavar (jugador, tamano, zona)
	  una bolsa lanzada entra     Lanzamiento.alAcertar (jugador, distancia, racha)
	  ... o cae fuera             Lanzamiento.alFallar (jugador)
	  reciclar en un contenedor   Bolsa.alDepositar (jugador, items, resumen): a
	                              mano o una lanzada que entra. Lo que se recicla
	                              solo (al salir, una bolsa perdida) va por
	                              Bolsa.reciclarSinBonus, sin senal: no cuenta
	  comprar una mejora          Mejoras.alComprar (jugador, id, nivel)

	Solo importa el jugador (el primer argumento de todas).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Servicios = ServerScriptService:WaitForChild("Services")
local Actividad = require(Servicios:WaitForChild("Actividad"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))
local Montones = require(Servicios:WaitForChild("Montones"))
local Lanzamiento = require(Servicios:WaitForChild("Lanzamiento"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))

ObjetosPatio.alRecoger:Connect(function(jugador)
	Actividad.registrar(jugador)
end)
Montones.alExcavar:Connect(function(jugador)
	Actividad.registrar(jugador)
end)
Lanzamiento.alAcertar:Connect(function(jugador)
	Actividad.registrar(jugador)
end)
Lanzamiento.alFallar:Connect(function(jugador)
	Actividad.registrar(jugador)
end)
Bolsa.alDepositar:Connect(function(jugador)
	Actividad.registrar(jugador)
end)
Mejoras.alComprar:Connect(function(jugador)
	Actividad.registrar(jugador)
end)
