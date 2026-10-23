--!strict
--[[
	Pedidos (ModuleScript)
	Unica responsabilidad: los pedidos del dia de cada jugador
	(perfil.pedidos, Config/DefinicionesPedidos): generarlos, contar su
	progreso con lo que el jugador HACE (senales de Bolsa, Lanzamiento y
	ObjetosPatio) y pagarlos al cumplirse. Completar los tres del dia da un
	Turbo (dinero x2 unos minutos, Services/Turbo), el mismo que se compra
	con Robux.

	Se cobran solos: un pedido cumplido paga en el momento y avisa. Asi no
	hay un boton que olvidar ni un panel que abrir para cobrar; el panel solo
	ensena como vas.

	Los pedidos del dia se generan la primera vez que hacen falta ese dia
	(al entrar o al cambiar de dia con la sesion abierta; el dia empieza a
	las 06:00 UTC, DefinicionesPedidos.dia) y se guardan en el perfil: salir
	y entrar no los cambia. Se adaptan a lo que el jugador puede hacer hoy:
	el reto "lejos" pide una distancia que su Brazo alcanza, y el de
	"material", un tipo que abunda en sus zonas abiertas.

	=== Economia v4 (22 oct, docs/Economia-v4.md §2.4 y §5.2) ===
	El premio se calcula AL COBRAR (DefinicionesPedidos.premio: un porcentaje
	del coste del siguiente rebirth, con los rebirths de ese momento) y se
	paga con Economia.ganar tal cual, sin pases ni Turbo. pedido.recompensa
	ya no decide nada: mientras el pedido esta pendiente es un espejo de lo
	que vale ahora (se refresca con cada cambio del perfil: al renacer, con
	/rebirths...), para el panel; al cobrarlo se queda con lo que se pago,
	que es lo que lee la analitica en alCumplir.
	Pase VIP: el dia trae un pedido mas (vip = true) de las plantillas que no
	salieron, que paga como dificil y no cuenta para el Turbo de los tres. Si
	el pase llega con el dia empezado (compra, o el refresco de pases al
	entrar), se anade al momento (Monetizacion.alCambiarPases).
	Cada pedido cobrado, el VIP incluido, suma 1 a la estadistica
	pedidosCompletados: el paso "pedido" del tutorial y la insignia pedidos30.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local DefinicionesPedidos = require(Config:WaitForChild("DefinicionesPedidos"))
local DefinicionesTutorial = require(Config:WaitForChild("DefinicionesTutorial"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Red = require(Utilidades:WaitForChild("Red"))
local Idioma = require(Utilidades:WaitForChild("Idioma"))
local Senal = require(Utilidades:WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Rebirths = require(Servicios:WaitForChild("Rebirths"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Lanzamiento = require(Servicios:WaitForChild("Lanzamiento"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))
local Turbo = require(Servicios:WaitForChild("Turbo"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))

local NotificacionEvent = Red.evento("NotificacionEvent")

type Pedido = Perfiles.Pedido

local Pedidos = {}

-- (jugador, pedido) cada pedido cumplido, ya pagado; lo escuchan el
-- Tutorial y la analitica
Pedidos.alCumplir = Senal.nueva() :: Senal.Senal<Player, Pedido>

-- El pase que trae el Pedido VIP (Config/Productos)
Pedidos.PASE_VIP = "VIP"

local rng = Random.new()

-- Para pruebas: el reloj se puede adelantar
Pedidos.ahora = os.time

function Pedidos.abiertos(jugador: Player): boolean
	local perfil = Perfiles.obtener(jugador)
	return perfil ~= nil and (perfil.tutorial or 0) >= DefinicionesTutorial.indice(DefinicionesPedidos.PASO_DESBLOQUEO)
end

-- Lo que paga ese pedido si se cumple ahora (con los rebirths de ahora)
function Pedidos.premio(jugador: Player, pedido: Pedido): number
	return DefinicionesPedidos.premio(pedido, Rebirths.cuantos(jugador))
end

-- La distancia del reto "lejos": la mayor de las de la tabla que el Brazo
-- alcanza con margen (no se pide un tiro al limite)
local function distanciaLejos(jugador: Player): number
	local alcance = Mejoras.valor(jugador, "Brazo") * 0.85
	local elegida = DefinicionesPedidos.DISTANCIAS[1]
	for _, d in DefinicionesPedidos.DISTANCIAS do
		if d <= alcance then
			elegida = d
		end
	end
	return elegida
end

-- El tipo del reto "material": papel o plastico siempre; metal y organico
-- solo con su zona abierta (fuera de ella salen poco)
local function materialPosible(jugador: Player): string
	local opciones = { "Papel", "Plastico" }
	local rebirths = Rebirths.cuantos(jugador)
	if rebirths >= 1 then
		table.insert(opciones, "Metal")
	end
	if rebirths >= 2 then
		table.insert(opciones, "Organico")
	end
	return opciones[rng:NextInteger(1, #opciones)]
end

local function crear(jugador: Player, plantilla: DefinicionesPedidos.Plantilla, vip: boolean?): Pedido
	local parametro: any = nil
	if plantilla.id == "lejos" then
		parametro = distanciaLejos(jugador)
	elseif plantilla.id == "material" then
		parametro = materialPosible(jugador)
	end
	local pedido: Pedido = {
		id = plantilla.id,
		objetivo = plantilla.objetivo,
		progreso = 0,
		parametro = parametro,
		cobrado = false,
		vip = if vip then true else nil,
	}
	-- Espejo para el panel (ver cabecera); el cobro lo vuelve a calcular
	pedido.recompensa = Pedidos.premio(jugador, pedido)
	return pedido
end

local function tieneVip(jugador: Player): boolean
	return Monetizacion.tienePase(jugador, Pedidos.PASE_VIP)
end

-- Cuantos Pedidos VIP hay en la lista
local function cuantosVip(lista: { Pedido }): number
	local n = 0
	for _, pedido in lista do
		if pedido.vip then
			n += 1
		end
	end
	return n
end

-- Anade a la lista los Pedidos VIP que le falten (uno con POR_DIA_VIP = 4),
-- de las plantillas que aun no estan en ella. Devuelve cuantos anadio
local function completarVip(jugador: Player, lista: { Pedido }): number
	local anadidos = 0
	while cuantosVip(lista) < DefinicionesPedidos.POR_DIA_VIP - DefinicionesPedidos.POR_DIA do
		local libres = {}
		for _, plantilla in DefinicionesPedidos.PLANTILLAS do
			local usada = false
			for _, pedido in lista do
				usada = usada or pedido.id == plantilla.id
			end
			if not usada then
				table.insert(libres, plantilla)
			end
		end
		if #libres == 0 then
			break
		end
		table.insert(lista, crear(jugador, libres[rng:NextInteger(1, #libres)], true))
		anadidos += 1
	end
	return anadidos
end

-- Los de hoy: tres (el primero de punteria y dos distintos del resto) y, con
-- el pase VIP, el Pedido VIP
function Pedidos.generar(jugador: Player): { Pedido }
	local punteria, resto = {}, {}
	for _, p in DefinicionesPedidos.PLANTILLAS do
		table.insert(if p.punteria then punteria else resto, p)
	end
	local lista = { crear(jugador, punteria[rng:NextInteger(1, #punteria)]) }
	-- Los otros dos, sin repetir, de todas las demas (tambien las de
	-- punteria que no salieron)
	local bolsa = table.clone(resto)
	for _, p in punteria do
		if p.id ~= lista[1].id then
			table.insert(bolsa, p)
		end
	end
	while #lista < DefinicionesPedidos.POR_DIA and #bolsa > 0 do
		local i = rng:NextInteger(1, #bolsa)
		table.insert(lista, crear(jugador, bolsa[i]))
		table.remove(bolsa, i)
	end
	if tieneVip(jugador) then
		completarVip(jugador, lista)
	end
	return lista
end

-- Si cambio el dia (o nunca hubo pedidos), los de hoy. Si es el mismo dia y
-- tiene VIP pero no su pedido (el pase llego con el dia empezado), se anade.
-- El dia solo avanza ("menor que", como Recompensas): un perfil con un dia
-- guardado por delante del de hoy (un servidor con el reloj algo atrasado
-- justo al cruzar las 06:00 UTC) no vuelve a generar ni a pagar los de hoy
-- (revision Q4b, 23 oct)
function Pedidos.asegurarDia(jugador: Player)
	local perfil = Perfiles.obtener(jugador)
	if not perfil or not Pedidos.abiertos(jugador) then
		return
	end
	local hoy = DefinicionesPedidos.dia(Pedidos.ahora())
	if (tonumber(perfil.pedidos.dia) or 0) < hoy or #perfil.pedidos.lista == 0 then
		perfil.pedidos = { dia = hoy, lista = Pedidos.generar(jugador), premioCobrado = false }
		Perfiles.marcarSucio(jugador)
	elseif tieneVip(jugador) and completarVip(jugador, perfil.pedidos.lista) > 0 then
		Perfiles.marcarSucio(jugador)
	end
end

-- Pone al dia el espejo del premio (pedido.recompensa) de los pendientes:
-- cambia al renacer. Cuesta unas cuentas por pedido; se llama con cada
-- cambio del perfil (como mucho 4 por segundo)
local function refrescarPremios(jugador: Player, perfil: Perfiles.Perfil)
	local cambio = false
	for _, pedido in perfil.pedidos.lista do
		if not pedido.cobrado then
			local premio = DefinicionesPedidos.premio(pedido, perfil.rebirths)
			if pedido.recompensa ~= premio then
				pedido.recompensa = premio
				cambio = true
			end
		end
	end
	if cambio then
		Perfiles.marcarSucio(jugador)
	end
end

-- Paga un pedido cumplido y, si ya estan los tres del dia, el Turbo
local function cobrar(jugador: Player, pedido: Pedido)
	local perfil = Perfiles.obtener(jugador)
	if not perfil or pedido.cobrado then
		return
	end
	pedido.cobrado = true
	-- Lo que vale ahora, sin pases ni Turbo (ver cabecera). Se anota en el
	-- pedido: es lo que se pago
	local premio = Pedidos.premio(jugador, pedido)
	pedido.recompensa = premio
	Economia.ganar(jugador, premio)
	Perfiles.estadistica(jugador, "pedidosCompletados", 1)
	NotificacionEvent:FireClient(jugador, Idioma.mensaje("PEDIDOS_AVISOS.cumplido", { dinero = Idioma.miles(premio) }), "dinero")
	Pedidos.alCumplir:Fire(jugador, pedido)
	-- El Turbo es de los tres del dia: el Pedido VIP no cuenta
	local todos = true
	for _, p in perfil.pedidos.lista do
		if not p.vip then
			todos = todos and p.cobrado
		end
	end
	if todos and not perfil.pedidos.premioCobrado then
		perfil.pedidos.premioCobrado = true
		Turbo.anadir(jugador, DefinicionesPedidos.MINUTOS_TURBO * 60)
		NotificacionEvent:FireClient(jugador, Idioma.mensaje("PEDIDOS_AVISOS.todos", { minutos = DefinicionesPedidos.MINUTOS_TURBO }), "exito")
	end
	Perfiles.marcarSucio(jugador)
end

-- Suma `cantidad` a los pedidos de hoy de ese tipo que la cumplan (filtro
-- opcional sobre el parametro). "racha" no suma: fija el maximo.
function Pedidos.avanzar(jugador: Player, id: string, cantidad: number?, filtro: ((any) -> boolean)?)
	if not cantidad or cantidad <= 0 then
		return
	end
	Pedidos.asegurarDia(jugador)
	local perfil = Perfiles.obtener(jugador)
	if not perfil or not Pedidos.abiertos(jugador) then
		return
	end
	for _, pedido in perfil.pedidos.lista do
		if pedido.id == id and not pedido.cobrado and (not filtro or filtro(pedido.parametro)) then
			if id == "racha" then
				pedido.progreso = math.max(pedido.progreso, cantidad)
			else
				pedido.progreso += cantidad
			end
			pedido.progreso = math.min(pedido.progreso, pedido.objetivo)
			Perfiles.marcarSucio(jugador)
			if pedido.progreso >= pedido.objetivo then
				cobrar(jugador, pedido)
			end
		end
	end
end

function Pedidos.iniciar()
	Perfiles.alCargar:Connect(function(jugador, perfil)
		Pedidos.asegurarDia(jugador)
		refrescarPremios(jugador, perfil)
	end)
	-- Al abrirse (paso del tutorial) o al cambiar de dia con la sesion
	-- abierta; y el espejo de los premios, por si renacio
	Perfiles.alCambiar:Connect(function(jugador, perfil)
		if Pedidos.abiertos(jugador) and (tonumber(perfil.pedidos.dia) or 0) < DefinicionesPedidos.dia(Pedidos.ahora()) then
			Pedidos.asegurarDia(jugador)
		end
		refrescarPremios(jugador, perfil)
	end)
	-- El pase VIP con el dia empezado: su pedido, al momento
	Monetizacion.alCambiarPases:Connect(function(jugador)
		Pedidos.asegurarDia(jugador)
	end)
	Bolsa.alResumen:Connect(function(jugador, resumen)
		Pedidos.avanzar(jugador, "piezas", resumen.objetos)
		Pedidos.avanzar(jugador, "separadas", resumen.separadas)
		for material, n in resumen.porMaterial do
			Pedidos.avanzar(jugador, "material", n, function(parametro)
				return parametro == material
			end)
		end
		if resumen.llena then
			Pedidos.avanzar(jugador, "bolsasLlenas", 1)
		end
	end)
	Lanzamiento.alAcertar:Connect(function(jugador, distancia, racha)
		Pedidos.avanzar(jugador, "aciertos", 1)
		Pedidos.avanzar(jugador, "racha", racha)
		Pedidos.avanzar(jugador, "lejos", 1, function(parametro)
			return distancia >= (parametro or 0)
		end)
	end)
	ObjetosPatio.alRecoger:Connect(function(jugador, item)
		if item.tipo == "tesoro" then
			Pedidos.avanzar(jugador, "tesoros", 1)
		end
	end)
end

return Pedidos
