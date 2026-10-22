--!strict
--[[
	PantallaCarga (LocalScript de ReplicatedFirst)
	Unica responsabilidad: poner la pantalla de carga en cuanto arranca el
	cliente. Lo de ReplicatedFirst llega y corre antes que el resto del juego
	(los LocalScripts de otros sitios esperan a que el juego cargue), asi que
	este es el primer codigo nuestro que ve el jugador.

	Todo lo demas (cuando se quita, que muestra, sus pruebas) esta en el
	ModuleScript hermano Carga, donde PruebasCliente puede consultarlo.
]]

local Carga = require(script.Parent:WaitForChild("Carga"))

Carga.iniciar()
