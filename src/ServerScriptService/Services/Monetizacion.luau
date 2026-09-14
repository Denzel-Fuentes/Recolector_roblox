--!strict
--[[
	Monetizacion (ModuleScript)
	Unica responsabilidad: saber que Game Passes tiene cada jugador y otorgar lo
	que compra con Robux. Las reglas del catalogo estan en Config/Productos.

	=== Pases ===
	Al entrar se consulta UserOwnsGamePassAsync para cada pase con id real y se
	cachea en perfil.pasesCache (para que el cliente pinte "Comprado" sin
	preguntar). PromptGamePassPurchaseFinished actualiza la cache al instante.

	MODO DEV: en Studio, con GameConfig.PASES_DEV_EN_STUDIO, todos los pases
	cuentan como comprados para poder probar sus efectos sin ids reales.
	/pases off (Admin) lo apaga en la sesion para probar el juego sin ellos.

	=== Recibos (Developer Products) ===
	ProcessReceipt tiene que ser IDEMPOTENTE: Roblox puede reintentar el mismo
	recibo si el servidor no respondio. Por eso:
	  - si perfil.recibos ya contiene el PurchaseId -> PurchaseGranted sin dar nada;
	  - si el perfil no cargo (no se podra guardar) -> NotProcessedYet, y Roblox
	    lo reintenta mas tarde en vez de perder la compra;
	  - si no, se otorga, se anota el recibo y se devuelve PurchaseGranted.
	La lista de recibos se recorta a 50 (FIFO): mas que suficiente para los
	reintentos, sin crecer para siempre.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Productos = require(Shared:WaitForChild("Config"):WaitForChild("Productos"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))

local Monetizacion = {}

Monetizacion.alCambiarPases = Senal.nueva() :: Senal.Senal<Player>
Monetizacion.alComprarProducto = Senal.nueva() :: Senal.Senal<Player, string>

local modoDev = RunService:IsStudio() and GameConfig.PASES_DEV_EN_STUDIO
local MAX_RECIBOS = 50

function Monetizacion.modoDev(): boolean
	return modoDev
end

-- El cliente necesita saber si el modo dev esta activo para pintar los pases
-- como comprados sin que eso se guarde en el perfil.
Perfiles.extrasSnapshot = function(_jugador: Player)
	return { modoDev = modoDev }
end

function Monetizacion.fijarModoDev(activo: boolean)
	modoDev = activo
	for _, jugador in Players:GetPlayers() do
		Perfiles.marcarSucio(jugador)
		Monetizacion.alCambiarPases:Fire(jugador)
	end
end

function Monetizacion.tienePase(jugador: Player, idPase: string): boolean
	if modoDev then
		return true
	end
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false
	end
	return perfil.pasesCache[idPase] == true
end

-- Consulta real a Roblox para los pases con id. Se llama al entrar.
function Monetizacion.refrescarPases(jugador: Player)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return
	end
	local cambio = false
	for _, pase in Productos.PASES do
		if pase.gamePassId ~= 0 then
			local ok, tiene = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(jugador.UserId, pase.gamePassId)
			end)
			if ok and tiene ~= (perfil.pasesCache[pase.id] == true) then
				perfil.pasesCache[pase.id] = if tiene then true else nil
				cambio = true
			end
		end
	end
	if cambio then
		Perfiles.marcarSucio(jugador)
		Monetizacion.alCambiarPases:Fire(jugador)
	end
end

function Monetizacion.marcarPase(jugador: Player, idPase: string)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return
	end
	perfil.pasesCache[idPase] = true
	Perfiles.marcarSucio(jugador)
	Monetizacion.alCambiarPases:Fire(jugador)
end

-- Lo que hace un producto al otorgarse. Devuelve false si no se reconoce.
local function otorgarProducto(jugador: Player, producto: Productos.Producto): boolean
	if producto.gemas > 0 then
		Economia.ganarGemas(jugador, producto.gemas)
		Monetizacion.alComprarProducto:Fire(jugador, producto.id)
		return true
	end
	return false
end

local function recordarRecibo(perfil: Perfiles.Perfil, purchaseId: string)
	table.insert(perfil.recibos, purchaseId)
	while #perfil.recibos > MAX_RECIBOS do
		table.remove(perfil.recibos, 1)
	end
end

function Monetizacion.procesarRecibo(recibo: { [string]: any }): Enum.ProductPurchaseDecision
	local jugador = Players:GetPlayerByUserId(recibo.PlayerId)
	if not jugador then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local perfil = Perfiles.obtener(jugador)
	if not perfil or not Perfiles.estaCargado(jugador) then
		-- Sin perfil guardable no se puede garantizar que la compra persista.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(recibo.PurchaseId)
	if table.find(perfil.recibos, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local producto = Productos.productoPorProductId(recibo.ProductId)
	if not producto then
		warn("Monetizacion: recibo de un ProductId desconocido: " .. tostring(recibo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not otorgarProducto(jugador, producto) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	recordarRecibo(perfil, purchaseId)
	Perfiles.estadistica(jugador, "comprasRobux", 1)
	Perfiles.marcarSucio(jugador)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Punto de entrada para pruebas y para Admin: simula un recibo sin Robux.
function Monetizacion.otorgarProductoPorId(jugador: Player, idProducto: string, purchaseId: string?): boolean
	local producto = Productos.PRODUCTO_POR_ID[idProducto]
	local perfil = Perfiles.obtener(jugador)
	if not producto or not perfil then
		return false
	end
	if purchaseId then
		if table.find(perfil.recibos, purchaseId) then
			return true
		end
		recordarRecibo(perfil, purchaseId)
	end
	return otorgarProducto(jugador, producto)
end

return Monetizacion
