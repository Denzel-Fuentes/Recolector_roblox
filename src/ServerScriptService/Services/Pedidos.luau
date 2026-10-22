--!strict
--[[
	Pedidos (ModuleScript)
	Unica responsabilidad: los tres pedidos del dia de cada jugador
	(perfil.pedidos, Config/DefinicionesPedidos): generarlos, contar su
	progreso con lo que el jugador HACE (senales de Bolsa, Lanzamiento y
	ObjetosPatio) y pagarlos al cumplirse. Completar los tres da un Turbo
	(dinero x2 unos minutos, perfil.turboHasta), el mismo que se compra con
	Robux (Services/Turbo).

	Se cobran solos: un pedido cumplido paga en el momento y avisa. Asi no
	hay un boton que olvidar ni un panel que abrir para cobrar; el panel solo
	ensena como vas.

	Los pedidos del dia se generan la primera vez que hacen falta ese dia
	(al entrar o al cambiar de dia con la sesion abierta) y se guardan en el
	perfil: salir y entrar no los cambia. Se adaptan a lo que el jugador
	puede hacer hoy: el reto "lejos" pide una distancia que su Brazo alcanza,
	y el de "material", un tipo que abunda en sus zonas abiertas.
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

local NotificacionEvent = Red.evento("NotificacionEvent")

type Pedido = Perfiles.Pedido

local Pedidos = {}

-- (jugador, pedido) cada pedido cumplido; lo escucha el Tutorial
Pedidos.alCumplir = Senal.nueva() :: Senal.Senal<Player, Pedido>

local rng = Random.new()

-- Para pruebas: el reloj se puede adelantar
Pedidos.ahora = os.time

function Pedidos.abiertos(jugador: Player): boolean
	local perfil = Perfiles.obtener(jugador)
	return perfil ~= nil and (perfil.tutorial or 0) >= DefinicionesTutorial.indice(DefinicionesPedidos.PASO_DESBLOQUEO)
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

local function crear(jugador: Player, plantilla: DefinicionesPedidos.Plantilla): Pedido
	local parametro: any = nil
	if plantilla.id == "lejos" then
		parametro = distanciaLejos(jugador)
	elseif plantilla.id == "material" then
		parametro = materialPosible(jugador)
	end
	return {
		id = plantilla.id,
		objetivo = plantilla.objetivo,
		progreso = 0,
		parametro = parametro,
		cobrado = false,
		recompensa = math.floor(DefinicionesPedidos.RECOMPENSA[plantilla.dificultad] * Rebirths.multiplicador(jugador) + 0.5),
	}
end

-- Los tres de hoy: el primero de punteria y dos distintos del resto
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
	return lista
end

-- Si cambio el dia (o nunca hubo pedidos), los de hoy
function Pedidos.asegurarDia(jugador: Player)
	local perfil = Perfiles.obtener(jugador)
	if not perfil or not Pedidos.abiertos(jugador) then
		return
	end
	local hoy = DefinicionesPedidos.dia(Pedidos.ahora())
	if perfil.pedidos.dia ~= hoy or #perfil.pedidos.lista == 0 then
		perfil.pedidos = { dia = hoy, lista = Pedidos.generar(jugador), premioCobrado = false }
		Perfiles.marcarSucio(jugador)
	end
end

-- Paga un pedido cumplido y, si ya estan los tres, el Turbo del dia
local function cobrar(jugador: Player, pedido: Pedido)
	local perfil = Perfiles.obtener(jugador)
	if not perfil or pedido.cobrado then
		return
	end
	pedido.cobrado = true
	Economia.ganar(jugador, pedido.recompensa or 0)
	Perfiles.estadistica(jugador, "pedidosCompletados", 1)
	NotificacionEvent:FireClient(jugador, Idioma.mensaje("PEDIDOS_AVISOS.cumplido", { dinero = Idioma.miles(pedido.recompensa or 0) }), "dinero")
	Pedidos.alCumplir:Fire(jugador, pedido)
	local todos = true
	for _, p in perfil.pedidos.lista do
		todos = todos and p.cobrado
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
	Perfiles.alCargar:Connect(function(jugador)
		Pedidos.asegurarDia(jugador)
	end)
	-- Al abrirse (paso del tutorial) o al cambiar de dia con la sesion abierta
	Perfiles.alCambiar:Connect(function(jugador, perfil)
		if Pedidos.abiertos(jugador) and perfil.pedidos.dia ~= DefinicionesPedidos.dia(Pedidos.ahora()) then
			Pedidos.asegurarDia(jugador)
		end
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
