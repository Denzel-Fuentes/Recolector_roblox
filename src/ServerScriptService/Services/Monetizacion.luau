--!strict
--[[
	Monetizacion (ModuleScript)
	Unica responsabilidad: saber que Game Passes tiene cada jugador y otorgar lo
	que compra con Robux. Las reglas del catalogo estan en Config/Productos.

	=== Pases ===
	Al entrar se consulta UserOwnsGamePassAsync para cada pase con id real y se
	cachea en perfil.pasesCache (para que el cliente pinte "Comprado" sin
	preguntar). PromptGamePassPurchaseFinished actualiza la cache
	(registrarCompraPase) y dispara alComprarPase, pero solo despues de que
	Roblox confirme que el pase es suyo (UserOwnsGamePassAsync, con
	REINTENTOS_PASE mas si aun dice que no: la compra tarda un momento en
	verse). El "comprado" del evento no basta (revision P2, 23 oct): no es
	una prueba de pago y no debe dar nada por si solo. Las esperas entre
	consultas doblan hasta ~1 min: Roblox recuerda un "no" de
	UserOwnsGamePassAsync unos 10 s (medido por la comunidad, sin documentar),
	y con 3 consultas en 4 s una primera hecha antes de que la compra se viera
	dejaba el "no" toda la ventana: el pase no llegaba hasta volver a entrar
	(revision Q4b, 23 oct).

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
	  - si el perfil aun no cargo, se espera mientras el jugador siga y su
	    perfil no este registrado (PerfilListo nil), con tope ESPERA_PERFIL:
	    la carga puede tardar SESION_ESPERA_ROBO s si la sesion la tiene aun
	    otro servidor (23 oct; eran 10 s y se rendia antes de que llegara);
	    sin perfil guardable -> NotProcessedYet, y Roblox lo reintenta;
	  - si perfil.recibos ya tiene el PurchaseId (un reintento) no se da nada
	    otra vez: solo se vuelve a guardar;
	  - si no, se otorga y se anota el recibo en el perfil;
	  - en los dos casos, Guardado.guardarAhora: PurchaseGranted solo si
	    quedo escrito; si no, NotProcessedYet. Lo otorgado se queda en memoria
	    con su recibo anotado: el reintento lo encuentra y no lo repite, y si
	    el jugador se va, el guardado de salida lo persiste.
	La lista de recibos se recorta a 50 (FIFO): mas que suficiente para los
	reintentos, sin crecer para siempre.

	=== Economia v4 (K1, 22 oct) ===
	- Cada compra con Robux (un producto otorgado, un pase confirmado o un
	  pase que aparece al entrar, comprado en la web) deja
	  perfil.compras.ultimaRobux = os.time(): en las 24 h siguientes no sale
	  ninguna oferta (Config/DefinicionesOfertas, nada de encadenar compras).
	- El atributo VIP del Player dice si tiene el pase VIP (tambien con el
	  modo dev): cada cliente le pinta la corona encima (CoronaVIP.client) y
	  la etiqueta del chat (EtiquetaVIP.client). Se pone al cargar el perfil
	  y cada vez que cambian los pases.
	- Lo que da cada cosa no esta aqui: el Turbo de los productos y el del
	  Pack de inicio (una sola vez) los registra Services/Turbo, las estelas
	  y bolsas los mira Services/Cosmeticos con tienePase.
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
-- Lo que puede tardar en registrarse el perfil (Guardado): la espera de la
-- sesion de otro servidor y un margen para el robo y la latencia
Monetizacion.ESPERA_PERFIL = GameConfig.SESION_ESPERA_ROBO + 15
Monetizacion.jugadorPorId = function(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end
-- Si Roblox dice que el pase es suyo: true / false, o nil si la consulta
-- fallo (no se sabe)
Monetizacion.poseePase = function(userId: number, gamePassId: number): boolean?
	local ok, tiene = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
	end)
	if not ok then
		return nil
	end
	return tiene == true
end
-- Al confirmar una compra de pase: consultas de mas si aun no se ve, y la
-- primera espera, que dobla en cada una (2, 4, 8, 16 y 32 s: la ultima
-- consulta a los ~62 s; ver cabecera)
Monetizacion.REINTENTOS_PASE = 5
Monetizacion.ESPERA_REINTENTO_PASE = 2
-- La hora de una compra (compras.ultimaRobux)
Monetizacion.ahora = os.time

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

-- Los atributos del Player que dependen de los pases (ver cabecera)
function Monetizacion.publicarAtributos(jugador: Player)
	if typeof(jugador) ~= "Instance" or not jugador:IsA("Player") then
		return
	end
	local vip = Monetizacion.tienePase(jugador, "VIP")
	if jugador:GetAttribute("VIP") ~= vip then
		jugador:SetAttribute("VIP", vip)
	end
end

-- Una compra con Robux: la hora, para las ofertas (ver cabecera)
local function anotarCompra(jugador: Player)
	local perfil = Perfiles.obtener(jugador)
	if perfil then
		perfil.compras.ultimaRobux = Monetizacion.ahora()
		Perfiles.marcarSucio(jugador)
	end
end

-- Consulta real a Roblox para los pases con id. Se llama al entrar.
function Monetizacion.refrescarPases(jugador: Player)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return
	end
	local cambio, nuevo = false, false
	for _, pase in Productos.PASES do
		if pase.gamePassId ~= 0 then
			local ok, tiene = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(jugador.UserId, pase.gamePassId)
			end)
			if ok and tiene ~= (perfil.pasesCache[pase.id] == true) then
				perfil.pasesCache[pase.id] = if tiene then true else nil
				cambio = true
				nuevo = nuevo or tiene == true
			end
		end
	end
	-- Un pase que aparece al entrar se compro fuera (la web) o en una sesion
	-- que no llego a guardarse: tambien es una compra para la regla de 24 h
	if nuevo then
		anotarCompra(jugador)
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

-- La compra de un pase acaba de completarse (PromptGamePassPurchaseFinished
-- con "comprado"): se confirma con Roblox (ver cabecera) y solo entonces se
-- anota en la cache y se avisa. Devuelve el pase (nil si el id no es de
-- ninguno del catalogo, si Roblox no lo confirma o si el jugador se fue
-- mientras). Puede ceder (la consulta y las esperas de los reintentos).
function Monetizacion.registrarCompraPase(jugador: Player, gamePassId: number): Productos.Pase?
	local pase = Productos.pasePorGamePassId(gamePassId)
	if not pase then
		return nil
	end
	local confirmado = false
	for intento = 0, Monetizacion.REINTENTOS_PASE do
		if intento > 0 then
			task.wait(Monetizacion.ESPERA_REINTENTO_PASE * 2 ^ (intento - 1))
		end
		if not jugador.Parent then
			return nil
		end
		if Monetizacion.poseePase(jugador.UserId, gamePassId) == true then
			confirmado = true
			break
		end
	end
	if not confirmado or not jugador.Parent then
		return nil
	end
	anotarCompra(jugador)
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
-- Nunca mira topes (el de 3 h de Turbo lo pone el cliente antes del
-- prompt): lo pagado se da entero.
local function otorgarProducto(jugador: Player, producto: Productos.Producto): boolean
	local otorgar = otorgadores[producto.id]
	if not otorgar or not otorgar(jugador) then
		return false
	end
	anotarCompra(jugador)
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

-- El atributo VIP al cargar y cada vez que cambian los pases (compra,
-- refrescarPases, modo dev)
Perfiles.alCargar:Connect(function(jugador)
	Monetizacion.publicarAtributos(jugador)
end)
for jugador in Perfiles.todos() do
	Monetizacion.publicarAtributos(jugador)
end
Monetizacion.alCambiarPases:Connect(function(jugador)
	Monetizacion.publicarAtributos(jugador)
end)

return Monetizacion
