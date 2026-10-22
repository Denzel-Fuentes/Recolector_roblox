--!strict
--[[
	AvisosMundo (ModuleScript)
	Unica responsabilidad: mandar a UN jugador un aviso que sale EN EL
	MUNDO, donde pasa la cosa (una burbuja sobre el monton, la pieza, el
	contenedor o su propia cabeza), en vez de un toast arriba de la pantalla
	(peticion del usuario, 6 oct: los toasts de rechazo se leian como
	ventanas sueltas; la burbuja dice ademas DONDE esta el problema). La
	pinta Client/AvisosMundo.

	Lo que se repite sin querer (la mira pasando una y otra vez por una
	pieza bloqueada, varios clics seguidos) se agrupa: el mismo texto al
	mismo jugador como mucho cada REPETIR segundos.

	El texto es un Idioma.mensaje (el cliente lo escribe en su idioma).

	opciones.icono: clave de Config/Iconos (candado, bolsa...);
	opciones.resaltar: un modelo que el cliente hace latir (p. ej. tu monton
	pendiente cuando intentas abrir otro).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Utilidades = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades")
local Red = require(Utilidades:WaitForChild("Red"))
local Idioma = require(Utilidades:WaitForChild("Idioma"))

type Mensaje = Idioma.Mensaje

local AvisoMundoEvent = Red.evento("AvisoMundoEvent")

local REPETIR = 1.2

local AvisosMundo = {}

export type Opciones = { icono: string?, resaltar: Instance? }

local ultimos: { [Player]: { [string]: number } } = {}

function AvisosMundo.mostrar(jugador: Player, posicion: Vector3, mensaje: Mensaje, opciones: Opciones?)
	-- Las pruebas reclaman con jugadores simulados, que no son Player
	if typeof(jugador) ~= "Instance" or not jugador:IsA("Player") or not jugador.Parent then
		return
	end
	local texto = Idioma.codificar(mensaje) -- la clave para agrupar repetidos
	local ahora = os.clock()
	local mapa = ultimos[jugador]
	if not mapa then
		mapa = {}
		ultimos[jugador] = mapa
	end
	if ahora - (mapa[texto] or 0) < REPETIR then
		return
	end
	mapa[texto] = ahora
	local o = opciones or {}
	AvisoMundoEvent:FireClient(jugador, posicion, mensaje, o.icono, o.resaltar)
end

-- Sobre la cabeza del jugador (lo que no tiene otro sitio: "aléjate un
-- poco", "la bolsa está vacía")
function AvisosMundo.sobreJugador(jugador: Player, mensaje: Mensaje, opciones: Opciones?)
	local personaje = jugador.Character
	local cabeza = personaje and (personaje:FindFirstChild("Head") or personaje:FindFirstChild("HumanoidRootPart"))
	if cabeza and cabeza:IsA("BasePart") then
		AvisosMundo.mostrar(jugador, cabeza.Position + Vector3.new(0, 2.5, 0), mensaje, opciones)
	end
end

Players.PlayerRemoving:Connect(function(jugador)
	ultimos[jugador] = nil
end)

return AvisosMundo
