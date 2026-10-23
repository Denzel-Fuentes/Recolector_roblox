--!strict
--[[
	OfertasHandler
	Solo cableado (K1, economia v4 §5.6): los disparadores de las ofertas y
	el remote de las respuestas van a Services/Ofertas, que decide.

	  sesion                 Perfiles.alCargar / alSalir
	  tras un deposito       Bolsa.alDepositar (a mano o una lanzada que
	                         entra; lo que se recicla solo no es un momento)
	  al renacer             Rebirths.alRenacer (jugador, rebirths)
	  fin de un Turbo        Turbo.alAcabar (jugador, ganado)
	  compra completada      Monetizacion.alComprarPase / alComprarProducto
	  OfertaRespuestaEvent   (accion, token, opcion): "mostrada",
	                         "descartada", "ahoraNo", "comprar" y
	                         "bolsaLlena". Solo se pasan esos tres argumentos;
	                         los mira Ofertas.responder (la prueba
	                         ofertaReglas le manda basura)

	"Tras cobrar el calendario" (el Pack de inicio, momento "calendario") se
	cablea aqui cuando las recompensas avisen de ello; mientras, el Pack sale
	en el primer deposito de la sesion en que ya se puede.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Red = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Rebirths = require(Servicios:WaitForChild("Rebirths"))
local Turbo = require(Servicios:WaitForChild("Turbo"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Ofertas = require(Servicios:WaitForChild("Ofertas"))

Perfiles.alCargar:Connect(function(jugador)
	Ofertas.entrar(jugador)
end)
-- Los que cargaron antes de que arrancara este script
for jugador in Perfiles.todos() do
	Ofertas.entrar(jugador)
end
Perfiles.alSalir:Connect(function(jugador)
	Ofertas.salir(jugador)
end)

Bolsa.alDepositar:Connect(function(jugador)
	Ofertas.momento(jugador, "deposito")
end)
Rebirths.alRenacer:Connect(function(jugador, rebirths)
	Ofertas.momento(jugador, "rebirth", rebirths)
end)
Turbo.alAcabar:Connect(Ofertas.turboAcabado)
Monetizacion.alComprarPase:Connect(Ofertas.compra)
Monetizacion.alComprarProducto:Connect(Ofertas.compra)

Red.evento("OfertaRespuestaEvent").OnServerEvent:Connect(function(jugador: Player, accion: any, token: any, opcion: any)
	Ofertas.responder(jugador, accion, token, opcion)
end)
