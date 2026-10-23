--!strict
--[[
	Turbo (ModuleScript)
	Unica responsabilidad: el Turbo de dinero, x2 a todo lo que se recicla
	mientras le quede (perfil.turboRestante, en segundos). Lo dan los
	pedidos, las recompensas (Turbo.anadir: el Turbo GANADO) y Robux: los
	productos con turboMinutos (Turbo 15 y Turbo 60) y, una sola vez, el
	pase Pack de inicio. Los otorgadores de Robux se registran aqui:
	Monetizacion no sabe que hace cada cosa que vende.

	=== Solo corre mientras se juega (economia v4, §4.6) ===
	Los segundos solo bajan si el jugador esta en el juego y ha hecho algo
	en los ultimos GameConfig.TURBO_PAUSA_INACTIVO s (Services/Actividad:
	recoger, excavar, lanzar, reciclar, comprar una mejora). Si no, esta en
	pausa y el Player lleva el atributo TurboPausado = true (el HUD lo
	ensena en gris, "x2 en pausa"). Al salir se descuenta lo ultimo y se
	para: lo que quede se guarda y sigue en la siguiente sesion. Antes (hasta
	el 22 oct) era una hora de fin (turboHasta): el Turbo de los pedidos, que
	suele llegar al final de la sesion, se gastaba con el jugador fuera.

	Quien acaba de entrar no ha hecho nada: su Turbo empieza en pausa y
	arranca con la primera accion (no se llama a Actividad.registrar al
	entrar). Entrar no es jugar: quien entra y se queda quieto no debe
	gastarlo, y la pildora gris le dice que su Turbo le espera.

	En pausa sigue valiendo x2 (activo): lo que paga es reciclar, y reciclar
	ya es una accion que lo reanuda. Si no, la bolsa lanzada tras un rato
	quieto pagaria x1 con el HUD diciendo x2.

	El descuento va cada TURBO_TIC s con el reloj de Actividad (la ultima
	accion esta en ese reloj; las pruebas sustituyen Actividad.ahora y lo
	controlan todo). Entre dos tics corre desde el tic anterior (o desde la
	accion, si estaba en pausa) hasta la ultima accion + la pausa: los saltos
	del reloj de las pruebas dan cuentas exactas.

	=== Tope de compra (§4.6) ===
	Con TURBO_TOPE_COMPRA s guardados (3 h) la Tienda y las ofertas no dejan
	comprar mas (puedeComprar). El tope NO va aqui en el otorgador: una
	compra pagada nunca se rechaza en ProcessReceipt; si aun asi llega, se
	otorga entera.

	=== Pack de inicio ===
	Se da UNA vez (perfil.compras.packInicio) al ver el pase de verdad en
	perfil.pasesCache: al cargar el perfil, al cambiar los pases
	(Monetizacion.alCambiarPases: refrescarPases al entrar o la compra
	confirmada) y en cada tic (por si el perfil paso a guardable despues).
	Solo con el perfil guardable: un perfil provisional se descarta y el
	Pack llegaria dos veces. El modo dev de pases NO lo da: no se envenena el
	perfil con algo que no se compro (como pasesCache, ver Monetizacion).

	=== alAcabar ===
	(jugador, ganado) cuando se acaba corriendo. ganado = hubo Turbo ganado
	(Turbo.anadir) en el que se acaba: la oferta de Turbo sale despues de
	acabarse uno ganado, no uno comprado (Services/Ofertas). El que ya traia
	al entrar cuenta como ganado si nunca ha comprado con Robux.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Productos = require(Config:WaitForChild("Productos"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Idioma = require(Utilidades:WaitForChild("Idioma"))
local Red = require(Utilidades:WaitForChild("Red"))
local Senal = require(Utilidades:WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Actividad = require(Servicios:WaitForChild("Actividad"))

local NotificacionEvent = Red.evento("NotificacionEvent")

local Turbo = {}

Turbo.MULTIPLICADOR = 2
Turbo.PAUSA = GameConfig.TURBO_PAUSA_INACTIVO
Turbo.TOPE_COMPRA = GameConfig.TURBO_TOPE_COMPRA

-- (jugador, ganado) al acabarse corriendo (ver cabecera)
Turbo.alAcabar = Senal.nueva() :: Senal.Senal<Player, boolean>

local PACK = Productos.PASE_POR_ID.PackInicio

-- Por jugador, solo mientras esta en la sesion
local ultimoTic: { [Player]: number } = {} -- hasta cuando esta descontado
local corria: { [Player]: boolean } = {} -- corria en el ultimo tic
local ganado: { [Player]: boolean } = {} -- hay Turbo ganado en el que corre
local publicado: { [Player]: number } = {} -- ultima publicacion mientras corre
local cerrados: { [Player]: boolean } = {} -- ya salio: no se descuenta mas

local function ahora(): number
	return Actividad.ahora()
end

function Turbo.restante(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	return if perfil then math.max(0, perfil.turboRestante or 0) else 0
end

-- Le queda Turbo (en pausa tambien: ver cabecera)
function Turbo.activo(jugador: Player): boolean
	return Turbo.restante(jugador) > 0
end

-- Le queda y esta corriendo: en el juego y con algo hecho hace poco
function Turbo.corre(jugador: Player): boolean
	return Turbo.restante(jugador) > 0
		and jugador.Parent ~= nil
		and not cerrados[jugador]
		and not Actividad.inactivo(jugador, Turbo.PAUSA)
end

function Turbo.pausado(jugador: Player): boolean
	return Turbo.restante(jugador) > 0 and not Turbo.corre(jugador)
end

function Turbo.multiplicador(jugador: Player): number
	return if Turbo.activo(jugador) then Turbo.MULTIPLICADOR else 1
end

-- Si aun se puede comprar Turbo con Robux (por debajo del tope de 3 h)
function Turbo.puedeComprar(jugador: Player): boolean
	return Turbo.restante(jugador) < Turbo.TOPE_COMPRA
end

-- El atributo del HUD, solo si cambia
local function marcarPausa(jugador: Player)
	local pausado = Turbo.pausado(jugador)
	if jugador:GetAttribute("TurboPausado") ~= pausado then
		jugador:SetAttribute("TurboPausado", pausado)
	end
end

-- Lo que corrio entre `desde` y `hasta` (ver cabecera): mientras su ultima
-- accion estaba a menos de PAUSA s
local function corrido(jugador: Player, desde: number, hasta: number): number
	local ultima = Actividad.ultima(jugador)
	if ultima == nil then
		return 0
	end
	local fin = math.min(hasta, ultima + Turbo.PAUSA)
	local inicio = if ultima > desde and not corria[jugador] then ultima else desde
	return math.max(0, fin - inicio)
end

local function acabar(jugador: Player, perfil: Perfiles.Perfil)
	perfil.turboRestante = 0
	local fueGanado = ganado[jugador] == true
	ganado[jugador] = nil
	publicado[jugador] = nil
	Perfiles.marcarSucio(jugador)
	Turbo.alAcabar:Fire(jugador, fueGanado)
end

-- Descuenta lo que corrio desde el ultimo tic y pone el atributo. Lo llama
-- el tic; tambien al salir y antes de sumar (y las pruebas)
function Turbo.actualizar(jugador: Player)
	local perfil = Perfiles.obtener(jugador)
	if not perfil or cerrados[jugador] or jugador.Parent == nil then
		return
	end
	local t = ahora()
	local desde = ultimoTic[jugador] or t
	ultimoTic[jugador] = t
	local quedaba = math.max(0, perfil.turboRestante or 0)
	local antes = corria[jugador] == true
	if quedaba > 0 then
		local queda = math.max(0, quedaba - corrido(jugador, desde, t))
		perfil.turboRestante = queda
		if queda <= 0 then
			acabar(jugador, perfil)
		elseif queda < quedaba and t - (publicado[jugador] or -math.huge) >= GameConfig.TURBO_PUBLICAR_CADA then
			publicado[jugador] = t
			Perfiles.marcarSucio(jugador)
		end
	end
	local ahoraCorre = Turbo.corre(jugador)
	corria[jugador] = ahoraCorre
	-- Al pausarse o reanudarse, el HUD toma de base el numero de verdad
	if ahoraCorre ~= antes and (perfil.turboRestante or 0) > 0 then
		Perfiles.marcarSucio(jugador)
	end
	marcarPausa(jugador)
end

-- El reloj del tic a ahora, sin descontar (al entrar; las pruebas tras
-- cambiar el reloj)
function Turbo.sincronizar(jugador: Player)
	ultimoTic[jugador] = ahora()
	corria[jugador] = Turbo.corre(jugador)
	marcarPausa(jugador)
end

local function sumar(jugador: Player, segundos: number, esGanado: boolean): boolean
	local perfil = Perfiles.obtener(jugador)
	if not perfil or segundos <= 0 then
		return false
	end
	-- Lo que corrio hasta ahora se descuenta del de antes, no del nuevo
	Turbo.actualizar(jugador)
	perfil.turboRestante = math.max(0, perfil.turboRestante or 0) + segundos
	if esGanado then
		ganado[jugador] = true
	end
	Perfiles.marcarSucio(jugador)
	marcarPausa(jugador)
	return true
end

-- Suma `segundos` de Turbo GANADO (pedidos, recompensas) al que quede
function Turbo.anadir(jugador: Player, segundos: number)
	sumar(jugador, segundos, true)
end

-- El Pack de inicio: su Turbo una sola vez (ver cabecera). Devuelve si lo dio
function Turbo.revisarPack(jugador: Player): boolean
	local perfil = Perfiles.obtener(jugador)
	local minutos = if PACK then PACK.turboMinutos else nil
	if not perfil or not minutos or perfil.compras.packInicio or cerrados[jugador] then
		return false
	end
	if perfil.pasesCache[PACK.id] ~= true or not Perfiles.estaCargado(jugador) then
		return false
	end
	perfil.compras.packInicio = true
	sumar(jugador, minutos * 60, false)
	if jugador.Parent then
		NotificacionEvent:FireClient(jugador, Idioma.mensaje("NOTIFICACIONES.packTurbo", { minutos = minutos }), "exito")
	end
	return true
end

-- Al cargar el perfil (tambien el guardado que sustituye a uno provisional)
function Turbo.entrar(jugador: Player)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return
	end
	cerrados[jugador] = nil
	-- Lo que ya traia es ganado si nunca compro con Robux (ver cabecera)
	ganado[jugador] = if (perfil.turboRestante or 0) > 0 and (perfil.compras.ultimaRobux or 0) == 0 then true else nil
	publicado[jugador] = nil
	Turbo.sincronizar(jugador)
	Turbo.revisarPack(jugador)
end

-- Al salir (Perfiles.alSalir, antes del guardado, sin ceder): lo ultimo que
-- corrio se descuenta y el Turbo se para
function Turbo.salir(jugador: Player)
	Turbo.actualizar(jugador)
	cerrados[jugador] = true
	ultimoTic[jugador] = nil
	corria[jugador] = nil
	ganado[jugador] = nil
	publicado[jugador] = nil
end

-- Robux: los productos con turboMinutos. Comprado, no ganado
for _, producto in Productos.PRODUCTOS do
	local minutos = producto.turboMinutos
	if minutos then
		Monetizacion.registrarProducto(producto.id, function(jugador)
			return sumar(jugador, minutos * 60, false)
		end)
	end
end

Perfiles.alCargar:Connect(Turbo.entrar)
-- Los que cargaron antes de que se requiriera este modulo
for jugador in Perfiles.todos() do
	Turbo.entrar(jugador)
end
Perfiles.alSalir:Connect(Turbo.salir)
Monetizacion.alCambiarPases:Connect(function(jugador)
	Turbo.revisarPack(jugador)
end)
-- Lo de quien se fue se olvida un rato despues, cuando ya no puede llegar
-- nada suyo (el guardado de salida tarda; mientras, ya no tiene Parent y el
-- tic lo salta)
local OLVIDAR_TRAS_SALIR = 60
Players.PlayerRemoving:Connect(function(jugador)
	task.delay(OLVIDAR_TRAS_SALIR, function()
		cerrados[jugador] = nil
		ultimoTic[jugador] = nil
		corria[jugador] = nil
		ganado[jugador] = nil
		publicado[jugador] = nil
	end)
end)

-- El tic de cada jugador. En pcall: un perfil raro no para el Turbo de todo
-- el servidor (y se avisa una vez por jugador, no cada segundo)
local function tic(jugador: Player, perfil: Perfiles.Perfil)
	if jugador.Parent == nil then
		return
	end
	Turbo.actualizar(jugador)
	if not perfil.compras.packInicio and perfil.pasesCache.PackInicio == true then
		Turbo.revisarPack(jugador)
	end
end

local avisados: { [Player]: boolean } = {}
task.spawn(function()
	while true do
		task.wait(GameConfig.TURBO_TIC)
		for jugador, perfil in Perfiles.todos() do
			local bien, err = pcall(tic, jugador, perfil)
			if not bien and not avisados[jugador] then
				avisados[jugador] = true
				warn("Turbo: tic de " .. jugador.Name .. ": " .. tostring(err))
			end
		end
		for jugador in avisados do
			if jugador.Parent == nil then
				avisados[jugador] = nil
			end
		end
	end
end)

return Turbo
