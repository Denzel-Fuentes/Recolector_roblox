--!strict
--[[
	OfertasHandler
	Solo cableado (K1, economia v4 §5.6): los disparadores de las ofertas y
	el remote de las respuestas van a Services/Ofertas, que decide.

	  sesion                 Perfiles.alCargar / alSalir
	  tras un deposito       Bolsa.alDepositar (a mano o una lanzada que
	                         entra; lo que se recicla solo no es un momento)
	  al renacer             Rebirths.alRenacer (jugador, rebirths)
	  tras cobrar el         Recompensas.alReclamar (jugador, "calendario"):
	  calendario             el momento del Pack de inicio (con el panel aun
	                         abierto: el cliente espera a que se cierre)
	  fin de un Turbo        Turbo.alAcabar (jugador, ganado)
	  compra completada      Monetizacion.alComprarPase / alComprarProducto
	  OfertaRespuestaEvent   (accion, token, opcion): "mostrada",
	                         "descartada", "ahoraNo", "cerrada", "comprar" y
	                         "bolsaLlena". Solo se pasan esos tres argumentos;
	                         los mira Ofertas.responder (la prueba
	                         ofertaReglas le manda basura)

	El calendario se suele cobrar nada mas entrar, y en los 3 primeros
	minutos de una sesion no sale ninguna oferta: entonces el Pack espera al
	primer deposito en que ya se puede.
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
local Recompensas = require(Servicios:WaitForChild("Recompensas"))
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

-- Diferido: Bolsa avisa del deposito (alDepositar) antes de su resumen
-- (alResumen), con el que se cobran los pedidos; si ese deposito cumple los
-- tres del dia y trae Turbo, la oferta tiene que verlo ya
Bolsa.alDepositar:Connect(function(jugador)
	task.defer(Ofertas.momento, jugador, "deposito")
end)
Rebirths.alRenacer:Connect(function(jugador, rebirths)
	Ofertas.momento(jugador, "rebirth", rebirths)
end)
Recompensas.alReclamar:Connect(function(jugador, tipo)
	if tipo == "calendario" then
		Ofertas.momento(jugador, "calendario")
	end
end)
Turbo.alAcabar:Connect(Ofertas.turboAcabado)
Monetizacion.alComprarPase:Connect(Ofertas.compra)
Monetizacion.alComprarProducto:Connect(Ofertas.compra)

Red.evento("OfertaRespuestaEvent").OnServerEvent:Connect(function(jugador: Player, accion: any, token: any, opcion: any)
	Ofertas.responder(jugador, accion, token, opcion)
end)
