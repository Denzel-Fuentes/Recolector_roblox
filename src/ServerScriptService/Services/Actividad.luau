--!strict
--[[
	Actividad (ModuleScript)
	Unica responsabilidad: saber cuando hizo algo cada jugador (economia v4,
	C3 22 oct). La misma nocion de "esta jugando" la necesitan dos cosas, y
	vive aqui para que no se haga dos veces:
	  - los minutos activos de las recompensas (R1, docs/Economia-v4.md
	    §4.5): alAccion llega como mucho una vez por segundo por jugador, asi
	    que "3 acciones en un minuto" son 3 segundos distintos con algo hecho
	    y un autoclicker no suma mas;
	  - la pausa del Turbo (K1, §4.6): inactivo(jugador, 120).

	Una accion es lo que el servidor ve hacer: recoger una pieza, excavar,
	que una bolsa lanzada acierte o falle, reciclar en un contenedor y
	comprar una mejora (ActividadHandler). Andar o estar en un menu no
	cuenta, asi el AFK no suma; quien aun no ha hecho nada esta inactivo.

	=== Por que sin dependencias ===
	No requiere ningun servicio del juego: las senales las conecta
	ActividadHandler. Asi lo puede requerir cualquiera sin ciclos, Turbo
	incluido: Bolsa requiere Turbo, y si Turbo requiriera un modulo que
	requiere Bolsa (o ObjetosPatio, Lanzamiento...), el require se cerraria
	sobre si mismo.

	El reloj es Actividad.ahora (os.clock: segundos con decimales, no
	os.time), sustituible en las pruebas; ultima() devuelve un valor de ese
	reloj. Lo de quien se va se borra en PlayerRemoving, y registrar ignora a
	quien ya no esta en el juego: una senal que llegara tarde (una bolsa que
	cae despues de salir) dejaria su entrada para siempre.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Senal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Senal"))

local Actividad = {}

-- Reloj en segundos; las pruebas lo sustituyen (como Pedidos.ahora)
Actividad.ahora = os.clock
-- alAccion como mucho una vez cada tantos segundos por jugador
Actividad.INTERVALO_AVISO = 1

-- (jugador) al hacer algo, como mucho una vez por INTERVALO_AVISO
Actividad.alAccion = Senal.nueva() :: Senal.Senal<Player>

local ultimas: { [Player]: number } = {}
local avisos: { [Player]: number } = {}

-- Marca que el jugador acaba de hacer algo
function Actividad.registrar(jugador: Player)
	if jugador.Parent == nil then
		return
	end
	local ahora = Actividad.ahora()
	ultimas[jugador] = ahora
	local aviso = avisos[jugador]
	if aviso == nil or ahora - aviso >= Actividad.INTERVALO_AVISO then
		avisos[jugador] = ahora
		Actividad.alAccion:Fire(jugador)
	end
end

-- Cuando hizo algo por ultima vez (en el reloj de Actividad.ahora), o nil
function Actividad.ultima(jugador: Player): number?
	return ultimas[jugador]
end

-- Si lleva `segundos` o mas sin hacer nada (o aun no ha hecho nada)
function Actividad.inactivo(jugador: Player, segundos: number): boolean
	local ultima = ultimas[jugador]
	return ultima == nil or Actividad.ahora() - ultima >= segundos
end

-- Olvida a un jugador (al salir; las pruebas, para no dejar rastro)
function Actividad.olvidar(jugador: Player)
	ultimas[jugador] = nil
	avisos[jugador] = nil
end

-- Al salir, y otra vez al acabar el ciclo: lo que su propia salida
-- registrara mientras aun tiene Parent tampoco se queda
Players.PlayerRemoving:Connect(function(jugador)
	Actividad.olvidar(jugador)
	task.defer(Actividad.olvidar, jugador)
end)

return Actividad
