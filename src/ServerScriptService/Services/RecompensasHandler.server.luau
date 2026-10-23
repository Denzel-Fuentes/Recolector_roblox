--!strict
--[[
	RecompensasHandler
	Solo cableado de las recompensas (paquete R1, economia v4; las reglas en
	Services/Recompensas):

	  Actividad.alAccion (jugador)          -> Recompensas.anotarAccion
	  Perfiles.alMinuto (jugador, perfil)   -> Recompensas.cerrarMinuto
	  Perfiles.alCargar (jugador, perfil)   -> Recompensas.alEntrar (el bono de
	                                           regreso) y, ESPERA_AVISO s
	                                           despues, avisarEntrada (la
	                                           ventana del regreso y el aviso
	                                           de que hay algo que reclamar)
	  Tutorial.alCompletar (paso 5)         -> Recompensas.alAbrirse
	  RecompensaEvent(accion)               -> Recompensas.peticion: solo un
	                                           texto corto y como mucho una
	                                           peticion por COOLDOWN s; lo
	                                           demas lo valida Recompensas
	                                           (la prueba recompensaRemoteMalo
	                                           le manda lo que mandaria un
	                                           cliente modificado)

	La espera al entrar es la del TutorialHandler: el cliente puede no tener
	aun la UI montada (y la pantalla de carga lo tapa todo).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefinicionesRecompensas = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesRecompensas"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Actividad = require(Servicios:WaitForChild("Actividad"))
local Tutorial = require(Servicios:WaitForChild("Tutorial"))
local Recompensas = require(Servicios:WaitForChild("Recompensas"))

local RecompensaEvent = Red.evento("RecompensaEvent")

-- s tras cargar el perfil para avisar (ver cabecera)
local ESPERA_AVISO = 4
-- s minimos entre dos peticiones de un jugador
local COOLDOWN = 1
-- Largo maximo del nombre de una accion
local LARGO_ACCION = 32

Actividad.alAccion:Connect(function(jugador)
	Recompensas.anotarAccion(jugador)
end)

Perfiles.alMinuto:Connect(function(jugador)
	Recompensas.cerrarMinuto(jugador)
end)

local function alCargar(jugador: Player, perfil: Perfiles.Perfil)
	Recompensas.alEntrar(jugador, perfil)
	task.delay(ESPERA_AVISO, Recompensas.avisarEntrada, jugador)
end
Perfiles.alCargar:Connect(alCargar)
-- Por si algun perfil cargo antes de que corriera este script
for jugador, perfil in Perfiles.todos() do
	task.spawn(alCargar, jugador, perfil)
end

Tutorial.alCompletar:Connect(function(jugador, id)
	if id == DefinicionesRecompensas.PASO_DESBLOQUEO then
		Recompensas.alAbrirse(jugador)
	end
end)

local ultimaPeticion: { [Player]: number } = {}
RecompensaEvent.OnServerEvent:Connect(function(jugador, accion)
	if typeof(accion) ~= "string" or #accion > LARGO_ACCION then
		return
	end
	local ahora = os.clock()
	if ahora - (ultimaPeticion[jugador] or -math.huge) < COOLDOWN then
		return
	end
	ultimaPeticion[jugador] = ahora
	Recompensas.peticion(jugador, accion)
end)

Players.PlayerRemoving:Connect(function(jugador)
	ultimaPeticion[jugador] = nil
	Recompensas.olvidar(jugador)
	-- Lo que su propia salida anotara mientras aun tiene Parent tampoco se
	-- queda (como Actividad)
	task.defer(Recompensas.olvidar, jugador)
end)
