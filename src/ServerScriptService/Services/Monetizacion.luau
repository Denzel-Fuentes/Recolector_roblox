--!strict
--[[
	Monetizacion (ModuleScript)
	Unica responsabilidad: saber que Game Passes tiene cada jugador y otorgar lo
	que compra con Robux. Las reglas del catalogo estan en Config/Productos.

	=== Pases ===
	Al entrar se consulta UserOwnsGamePassAsync para cada pase con id real y se
	cachea en perfil.pasesCache (para que el cliente pinte "Comprado" sin
	preguntar). PromptGamePassPurchaseFinished actualiza la cache al instante
	(registrarCompraPase) y dispara alComprarPase.

	MODO DEV: SOLO EN STUDIO, con GameConfig.PASES_DEV_EN_STUDIO, todos los
	pases cuentan como comprados para poder probar sus efectos sin ids reales.
	/pases on|off (Admin, que tambien es solo de Studio) lo cambia en la
	sesion. Fuera de Studio fijarModoDev no hace nada y modoDev() es siempre
	false: antes, un /pases on en el juego publicado daba todos los pases a
	todo el servidor. "Estar en Studio" es esStudio(), sustituible en pruebas.

	=== Recibos (Developer Products) ===
	ProcessReceipt tiene que ser IDEMPOTENTE (Roblox reintenta el mismo
	recibo mientras no se le devuelva PurchaseGranted) y solo puede devolver
	PurchaseGranted con la compra YA GUARDADA: si el servidor cae despues,
	Roblox ya no lo reintenta. Por eso:
	  - si el perfil aun no cargo, se espera (Perfiles.esperar, ESPERA_PERFIL
	    s); sin perfil guardable -> NotProcessedYet, y Roblox lo reintenta;
	  - si perfil.recibos ya tiene el PurchaseId (un reintento) no se da nada
	    otra vez: solo se vuelve a guardar;
	  - si no, se otorga y se anota el recibo en el perfil;
	  - en los dos casos, Guardado.guardarAhora: PurchaseGranted solo si
	    quedo escrito; si no, NotProcessedYet. Lo otorgado se queda en memoria
	    con su recibo anotado: el reintento lo encuentra y no lo repite, y si
	    el jugador se va, el guardado de salida lo persiste.
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
local Guardado = require(Servicios:WaitForChild("Guardado"))

local Monetizacion = {}

Monetizacion.alCambiarPases = Senal.nueva() :: Senal.Senal<Player>
-- (jugador, id del producto de Config/Productos) al OTORGAR un producto: una
-- vez por compra (el reintento de un recibo ya otorgado no lo repite)
Monetizacion.alComprarProducto = Senal.nueva() :: Senal.Senal<Player, string>
-- (jugador, id del pase de Config/Productos) al completarse la compra de un
-- pase (PromptGamePassPurchaseFinished con la compra hecha)
Monetizacion.alComprarPase = Senal.nueva() :: Senal.Senal<Player, string>

-- Sustituibles en pruebas
Monetizacion.esStudio = function(): boolean
	return RunService:IsStudio()
end
Monetizacion.ESPERA_PERFIL = 10
Monetizacion.jugadorPorId = function(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

local MAX_RECIBOS = 50

-- Lo pedido (GameConfig o /pases); solo cuenta dentro de Studio
local modoDevPedido = GameConfig.PASES_DEV_EN_STUDIO

function Monetizacion.modoDev(): boolean
	return modoDevPedido and Monetizacion.esStudio()
end

-- El cliente necesita saber si el modo dev esta activo para pintar los pases
-- como comprados sin que eso se guarde en el perfil.
Perfiles.extrasSnapshot = function(_jugador: Player)
	return { modoDev = Monetizacion.modoDev() }
end

-- Solo en Studio. Devuelve si se aplico.
function Monetizacion.fijarModoDev(activo: boolean): boolean
	if not Monetizacion.esStudio() then
		return false
	end
	modoDevPedido = activo
	for _, jugador in Players:GetPlayers() do
		Perfiles.marcarSucio(jugador)
		Monetizacion.alCambiarPases:Fire(jugador)
	end
	return true
end

function Monetizacion.tienePase(jugador: Player, idPase: string): boolean
	if Monetizacion.modoDev() then
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

-- La compra de un pase acaba de completarse (PromptGamePassPurchaseFinished):
-- se anota en la cache y se avisa. Devuelve el pase (nil si el id no es
-- de ninguno del catalogo).
function Monetizacion.registrarCompraPase(jugador: Player, gamePassId: number): Productos.Pase?
	local pase = Productos.pasePorGamePassId(gamePassId)
	if not pase then
		return nil
	end
	Monetizacion.marcarPase(jugador, pase.id)
	Monetizacion.alComprarPase:Fire(jugador, pase.id)
	return pase
end

-- Lo que hace cada producto al otorgarse lo decide el servicio dueno de ese
-- efecto (p. ej. el Turbo de dinero), que se registra aqui: asi Monetizacion
-- no depende de todos los sistemas que se venden.
local otorgadores: { [string]: (Player) -> boolean } = {}

function Monetizacion.registrarProducto(idProducto: string, otorgar: (Player) -> boolean)
	otorgadores[idProducto] = otorgar
end

-- Devuelve false si el producto no tiene quien lo otorgue o no se pudo.
local function otorgarProducto(jugador: Player, producto: Productos.Producto): boolean
	local otorgar = otorgadores[producto.id]
	if not otorgar or not otorgar(jugador) then
		return false
	end
	Monetizacion.alComprarProducto:Fire(jugador, producto.id)
	return true
end

local function recordarRecibo(perfil: Perfiles.Perfil, purchaseId: string)
	table.insert(perfil.recibos, purchaseId)
	while #perfil.recibos > MAX_RECIBOS do
		table.remove(perfil.recibos, 1)
	end
end

local function guardado(jugador: Player): Enum.ProductPurchaseDecision
	if Guardado.guardarAhora(jugador, "recibo") then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function Monetizacion.procesarRecibo(recibo: { [string]: any }): Enum.ProductPurchaseDecision
	local jugador = Monetizacion.jugadorPorId(recibo.PlayerId)
	if not jugador then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Recien entrado: su perfil puede estar cargando todavia
	local perfil = Perfiles.obtener(jugador) or Perfiles.esperar(jugador, Monetizacion.ESPERA_PERFIL)
	if not perfil or not Perfiles.estaCargado(jugador) then
		-- Sin perfil guardable no se puede garantizar que la compra persista
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(recibo.PurchaseId)
	if table.find(perfil.recibos, purchaseId) then
		-- Ya otorgado: un reintento. No se da otra vez; solo se asegura que
		-- quede guardado antes de confirmarlo
		return guardado(jugador)
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
	return guardado(jugador)
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
