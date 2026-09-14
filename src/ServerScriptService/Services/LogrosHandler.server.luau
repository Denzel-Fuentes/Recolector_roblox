--!strict
--[[
	LogrosHandler
	Reevalua los logros cada vez que el perfil cambia (Perfiles.alCambiar se
	dispara al publicar, como mucho 4 veces por segundo por jugador) y una vez
	al cargar, para quien ya cumpla condiciones de una sesion anterior con una
	definicion nueva.

	Se hace en defer para no evaluar dentro del propio ciclo de publicacion.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Logros = require(Servicios:WaitForChild("Logros"))

Perfiles.alCargar:Connect(function(jugador)
	task.defer(Logros.evaluar, jugador)
end)

Perfiles.alCambiar:Connect(function(jugador)
	task.defer(Logros.evaluar, jugador)
end)
