--!strict
--[[
	MonetizacionHandler
	Cablea MarketplaceService con el modulo Monetizacion:
	  - ProcessReceipt (Developer Products): idempotente, y PurchaseGranted
	    solo con la compra ya guardada (Monetizacion.procesarRecibo);
	  - PromptGamePassPurchaseFinished (pases): Monetizacion.registrarCompraPase
	    confirma con Roblox que el pase es suyo (el "comprado" del evento no
	    basta), marca la cache y dispara alComprarPase; aqui se avisa;
	  - al cargar el perfil, consulta los pases reales.

	El cliente lanza los prompts de compra directamente con MarketplaceService
	(PromptGamePassPurchase / PromptProductPurchase): no hace falta RemoteEvent.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Productos = require(Shared:WaitForChild("Config"):WaitForChild("Productos"))
local Idioma = require(Shared:WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))

local NotificacionEvent = Red.evento("NotificacionEvent")

MarketplaceService.ProcessReceipt = function(recibo)
	return Monetizacion.procesarRecibo(recibo)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(jugador, gamePassId, comprado)
	if not comprado or typeof(gamePassId) ~= "number" then
		return
	end
	-- Cede: consulta a Roblox (y reintenta si aun no ve la compra)
	local pase = Monetizacion.registrarCompraPase(jugador, gamePassId)
	if pase and jugador.Parent then
		NotificacionEvent:FireClient(jugador, Idioma.mensaje("NOTIFICACIONES.compraRobux", { nombre = Idioma.mensajeNombre("Pases", pase) }), "exito")
	end
end)

Monetizacion.alComprarProducto:Connect(function(jugador, idProducto)
	local producto = Productos.PRODUCTO_POR_ID[idProducto]
	if producto then
		NotificacionEvent:FireClient(jugador, Idioma.mensaje("NOTIFICACIONES.compraRobux", { nombre = Idioma.mensajeNombre("Productos", producto) }), "exito")
	end
end)

Perfiles.alCargar:Connect(function(jugador)
	Monetizacion.refrescarPases(jugador)
end)
