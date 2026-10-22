--!strict
--[[
	AnaliticaHandler
	Solo cableado: conecta las Senales del juego con Services/Analitica (que
	decide que se envia a AnalyticsService y con que campos) y atiende
	AnaliticaEvent, por el que el cliente manda UNA vez su plataforma
	(Client/Telemetria). La validacion de ese remote (lista blanca,
	enfriamiento, cambios por sesion) esta en Analitica.recibirCliente para
	que la prueba analiticaEventoMalo la pueda probar con basura sin un
	cliente; aqui solo se le pasan los dos argumentos que espera (nunca lo
	que sobre de lo que mande el cliente).

	Al salir, Analitica.salida (en Perfiles.alSalir, antes del guardado)
	cierra la sesion; lo que se recuerda del jugador se borra un rato
	despues (OLVIDAR_TRAS_SALIR), cuando ya no puede llegar nada suyo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Red = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Analitica = require(Servicios:WaitForChild("Analitica"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Tutorial = require(Servicios:WaitForChild("Tutorial"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Pedidos = require(Servicios:WaitForChild("Pedidos"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Rebirths = require(Servicios:WaitForChild("Rebirths"))
local Lanzamiento = require(Servicios:WaitForChild("Lanzamiento"))
local Insignias = require(Servicios:WaitForChild("Insignias"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))

-- Sesion
Players.PlayerAdded:Connect(Analitica.entrada)
for _, jugador in Players:GetPlayers() do
	Analitica.entrada(jugador)
end
Players.PlayerRemoving:Connect(function(jugador)
	task.delay(Analitica.OLVIDAR_TRAS_SALIR, Analitica.olvidar, jugador)
end)

-- Perfil: embudo (paso 1), perfil no cargado, ultimo saldo, salida
Perfiles.alCargar:Connect(Analitica.carga)
Perfiles.alCambiar:Connect(Analitica.perfilCambio)
Perfiles.alSalir:Connect(Analitica.salida)

-- Embudo de inicio: los 8 pasos del tutorial
Tutorial.alCompletar:Connect(Analitica.pasoTutorial)

-- Economia
Bolsa.alResumen:Connect(Analitica.deposito)
Pedidos.alCumplir:Connect(Analitica.pedido)
Mejoras.alComprar:Connect(Analitica.mejora)

-- Progresion
Rebirths.alRenacer:Connect(Analitica.rebirth)

-- Punteria (el origen de un fallo: donde se vacio la bolsa)
Bolsa.alCambiar:Connect(Analitica.bolsaCambio)
Lanzamiento.alAcertar:Connect(Analitica.acierto)
Lanzamiento.alFallar:Connect(Analitica.fallo)

-- Insignias y compras
Insignias.alConseguir:Connect(Analitica.insignia)
Monetizacion.alComprarPase:Connect(Analitica.compraPase)
Monetizacion.alComprarProducto:Connect(Analitica.compraProducto)

-- La plataforma del cliente
Red.evento("AnaliticaEvent").OnServerEvent:Connect(function(jugador: Player, tipo: any, valor: any)
	Analitica.recibirCliente(jugador, tipo, valor)
end)
