--!nonstrict
--[[
	Pruebas de la analitica (paquete N1). AnalyticsService no envia nada
	desde Studio, asi que miran Analitica.registro (lo que se habria enviado,
	con su resultado): que cada cosa del juego deja su evento con los campos
	en tramos, que el remote de la plataforma ignora la basura y que un
	AnalyticsService caido no para el juego.

	Todas vuelven a dejar como estaba lo que tocan (tutorial, dinero,
	mejoras, rebirths, plataforma, pedidos del dia: sinPedidos los aparta
	mientras tanto); como las de rebirth y tutorial, dejan las estadisticas
	algo movidas. Las que tocan la sesion del jugador en Analitica (embudo,
	plataforma, enfriamiento) la olvidan y la vuelven a empezar.
]]

local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local DefinicionesPedidos = require(Config:WaitForChild("DefinicionesPedidos"))
local DefinicionesRebirths = require(Config:WaitForChild("DefinicionesRebirths"))
local DefinicionesTutorial = require(Config:WaitForChild("DefinicionesTutorial"))

local Servicios = script.Parent.Parent
local Analitica = require(Servicios:WaitForChild("Analitica"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Rebirths = require(Servicios:WaitForChild("Rebirths"))
local Tutorial = require(Servicios:WaitForChild("Tutorial"))
local Pedidos = require(Servicios:WaitForChild("Pedidos"))
local Lanzamiento = require(Servicios:WaitForChild("Lanzamiento"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Botin = require(Servicios:WaitForChild("Botin"))
local Mundo = require(Servicios:WaitForChild("Mundo"))
local Movimiento = require(Servicios:WaitForChild("Movimiento"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador, teletransportar = Comunes.jugador, Comunes.teletransportar

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

-- Los eventos registrados despues de `desde` de un tipo (y nombre, si se da)
local function eventos(desde: number, tipo: string, nombre: string?)
	local lista = {}
	for _, e in Analitica.desde(desde) do
		if e.tipo == tipo and (nombre == nil or e.nombre == nombre) then
			table.insert(lista, e)
		end
	end
	return lista
end

local function papel(valor: number)
	return { tipo = "basura", nombre = "Papel", material = "Papel", valor = valor }
end

-- Deja los pedidos de hoy sin nada que avanzar (uno de hoy ya cobrado) y
-- devuelve con que restaurarlos: asi un deposito o un acierto de prueba no
-- cobra un pedido por el camino (cambiaria el saldo que se compara) ni
-- mueve los de verdad
local function sinPedidos(p): () -> ()
	local antes = p.pedidos
	p.pedidos = {
		dia = DefinicionesPedidos.dia(Pedidos.ahora()),
		lista = { { id = "piezas", objetivo = 1, progreso = 1, cobrado = true, recompensa = 0 } },
		premioCobrado = true,
	}
	return function()
		p.pedidos = antes
	end
end

local function describir(e): string
	if not e then
		return "ninguno"
	end
	return string.format("%s %s=%s [%s] ok=%s", e.tipo, e.nombre, tostring(e.valor), table.concat(e.campos, ", "), tostring(e.ok))
end

-- Paso 1 "Entrar" al cargar con el tutorial a 0: espera a la plataforma y
-- sale con ella, una vez; los 8 pasos del tutorial, con sus senales de
-- verdad (el recorrido de la prueba tutorial), son los pasos 2..9 en orden;
-- otra vuelta al tutorial no repite ninguno; y sin plataforma el paso 1
-- sale igual a los ESPERA_PLATAFORMA s, con "desconocida". Con el
-- AnalyticsService de verdad (ENVIAR_EN_STUDIO encendido mientras dura): el
-- recorrido dispara los cuatro tipos de evento y Studio acepta sus firmas
-- (escribe una linea "event fired" por cada uno)
function Pruebas.analiticaEmbudo()
	local j = jugador()
	local p = Perfiles.obtener(j)
	if not p then
		return "sin perfil => FALLO"
	end
	Analitica.reiniciarLimites()
	local enviarPrevio = Analitica.ENVIAR_EN_STUDIO
	Analitica.ENVIAR_EN_STUDIO = true
	local estadoAntes = Analitica.estado()
	local desdeTodo = Analitica.contador()
	local previo = p.tutorial
	local dineroPrevio = p.dinero
	local plataformaPrevia = Analitica.plataformaDe(j)
	local esperaPrevia = Analitica.ESPERA_PLATAFORMA
	local pedidosPrevios = p.estadisticas.pedidosCompletados
	local restaurarPedidos = sinPedidos(p)
	Bolsa.vaciar(j)
	teletransportar(j, Comunes.fueraDelPatio())
	task.wait(0.5)

	-- 1) Paso 1: espera a la plataforma, sale con ella y no se repite
	Analitica.olvidar(j)
	Analitica.entrada(j)
	Tutorial.fijar(j, 0)
	local desde = Analitica.contador()
	Analitica.carga(j, p)
	local esperaba = #eventos(desde, "embudo") == 0
	Analitica.fijarPlataforma(j, "tactil")
	Analitica.carga(j, p) -- el perfil que se recupera en segundo plano: no repite
	local entrar = eventos(desde, "embudo")
	local paso1 = entrar[1]
	local paso1Ok = esperaba and #entrar == 1 and paso1.valor == 1 and paso1.nombre == "Entrar"
		and paso1.campos[1] == "Plataforma - tactil" and paso1.ok

	-- 2) Los 8 pasos del tutorial por sus senales
	desde = Analitica.contador()
	Tutorial.completar(j, "excavar") -- fuera de orden: no cuenta
	Tutorial.completar(j, "patio")
	Tutorial.completar(j, "excavar")
	while not Bolsa.estaLlena(j) do
		Bolsa.meter(j, papel(1))
	end
	Lanzamiento.alAcertar:Fire(j, 12, 1)
	Mejoras.alComprar:Fire(j, "Bolsa", 1)
	Bolsa.vaciar(j)
	p.estadisticas.pedidosCompletados = 0
	Bolsa.depositarItems(j, { papel(1), papel(1), papel(1) }, 0, "Papel")
	Pedidos.alCumplir:Fire(j, {})
	Rebirths.alRenacer:Fire(j, 1)
	local serie, nombres, esperados = {}, {}, {}
	local todosOk, plataformaOk = true, true
	for _, e in eventos(desde, "embudo") do
		table.insert(serie, tostring(e.valor))
		table.insert(nombres, e.nombre)
		todosOk = todosOk and e.ok
		plataformaOk = plataformaOk and e.campos[1] == "Plataforma - tactil"
	end
	local serieEsperada = {}
	for i, paso in DefinicionesTutorial.PASOS do
		table.insert(serieEsperada, tostring(i + 1))
		table.insert(esperados, string.upper(string.sub(paso.id, 1, 1)) .. string.sub(paso.id, 2))
	end
	local pasosOk = table.concat(serie, ",") == table.concat(serieEsperada, ",")
		and table.concat(nombres, ",") == table.concat(esperados, ",") and todosOk and plataformaOk

	-- 3) Otra vuelta en la misma sesion: nada nuevo
	desde = Analitica.contador()
	Tutorial.fijar(j, 0)
	Tutorial.completar(j, "patio")
	Analitica.carga(j, p)
	local repetidos = #eventos(desde, "embudo")

	-- 4) Sin plataforma y sin que llegue: sale a los ESPERA_PLATAFORMA s
	Analitica.olvidar(j)
	Analitica.entrada(j)
	Analitica.ESPERA_PLATAFORMA = 0.2
	Tutorial.fijar(j, 0)
	desde = Analitica.contador()
	Analitica.carga(j, p)
	local antesDelPlazo = #eventos(desde, "embudo")
	task.wait(0.5)
	local tarde = eventos(desde, "embudo")
	local plazoOk = antesDelPlazo == 0 and #tarde == 1 and tarde[1].valor == 1 and tarde[1].campos[1] == "Plataforma - desconocida"

	-- Las firmas: todo lo de la prueba llego al servicio de verdad sin error
	local estadoTras = Analitica.estado()
	local todos = Analitica.desde(desdeTodo)
	local porTipo, firmasOk = {}, true
	for _, e in todos do
		porTipo[e.tipo] = (porTipo[e.tipo] or 0) + 1
		firmasOk = firmasOk and e.ok
	end
	local enviados = estadoTras.enviados - estadoAntes.enviados
	firmasOk = firmasOk and enviados == #todos and estadoTras.sinEnviar == estadoAntes.sinEnviar
		and (porTipo.embudo or 0) > 0 and (porTipo.economia or 0) > 0 and (porTipo.progresion or 0) > 0 and (porTipo.personalizado or 0) > 0

	Analitica.ENVIAR_EN_STUDIO = enviarPrevio
	Analitica.ESPERA_PLATAFORMA = esperaPrevia
	Analitica.fijarPlataforma(j, plataformaPrevia)
	p.estadisticas.pedidosCompletados = pedidosPrevios
	p.dinero = dineroPrevio
	restaurarPedidos()
	Tutorial.fijar(j, previo)
	Bolsa.vaciar(j)
	return string.format("paso 1: esperaba a la plataforma=%s, %s | tutorial: pasos [%s] [%s] (esperado [%s] [%s]) ok=%s plataforma=%s | otra vuelta: %d repetidos | sin plataforma: antes del plazo %d, despues %s | AnalyticsService de verdad: %d de %d enviados (embudo %d, economia %d, progresion %d, propios %d) => %s",
		tostring(esperaba), describir(paso1), table.concat(serie, ","), table.concat(nombres, ","),
		table.concat(serieEsperada, ","), table.concat(esperados, ","), tostring(todosOk), tostring(plataformaOk),
		repetidos, antesDelPlazo, describir(tarde[1]), enviados, #todos,
		porTipo.embudo or 0, porTipo.economia or 0, porTipo.progresion or 0, porTipo.personalizado or 0,
		ok(paso1Ok and pasosOk and repetidos == 0 and plazoOk and firmasOk))
end

-- Fuentes (depositos en el de papel y en el general, un pedido, lo que
-- entro sin senal, que se cuadra al salir) y un sumidero (una mejora de
-- verdad), cada uno
-- con su sku, cantidad, tipo de transaccion, saldo final y campos
-- (plataforma, rebirths, nivel medio); un deposito sin dinero no deja nada
function Pruebas.analiticaEconomia()
	local j = jugador()
	local p = Perfiles.obtener(j)
	if not p then
		return "sin perfil => FALLO"
	end
	Analitica.reiniciarLimites()
	local copia = { dinero = p.dinero, alcance = p.mejoras.Alcance, tutorial = p.tutorial, plataforma = Analitica.plataformaDe(j) }
	local restaurarPedidos = sinPedidos(p)
	Analitica.fijarPlataforma(j, "teclado")
	Bolsa.vaciar(j)
	local desde = Analitica.contador()
	local mal = {}
	local function ultimo(sku: string)
		local lista = eventos(desde, "economia", sku)
		return lista[#lista]
	end
	local function comprobar(sku: string, flujo: string, cantidad: number, saldo: number, transaccion: string)
		local e = ultimo(sku)
		if not e then
			table.insert(mal, sku .. " no salio")
		elseif e.flujo ~= flujo or e.valor ~= cantidad or e.saldo ~= saldo or e.transaccion ~= transaccion or not e.ok then
			table.insert(mal, string.format("%s: %s $%s saldo %s (esperado %s) %s ok=%s", sku, tostring(e.flujo), tostring(e.valor),
				tostring(e.saldo), tostring(saldo), tostring(e.transaccion), tostring(e.ok)))
		end
	end

	-- Depositos: en el de papel (x2) y en el general
	local r1 = Bolsa.depositarItems(j, { papel(10), papel(10) }, 0, "Papel")
	comprobar("Deposito_Papel", "fuente", r1.dinero, p.dinero, "Gameplay")
	local r2 = Bolsa.depositarItems(j, { papel(10) }, 0, nil)
	comprobar("Deposito_General", "fuente", r2.dinero, p.dinero, "Gameplay")
	-- Pedido: Pedidos paga y despues avisa
	Economia.ganar(j, 500)
	Pedidos.alCumplir:Fire(j, { id = "separadas", objetivo = 40, progreso = 40, cobrado = true, recompensa = 500 })
	comprobar("Pedido_facil", "fuente", 500, p.dinero, "Gameplay")
	-- Mejora de verdad: Alcance de 0 a 1
	p.mejoras.Alcance = 0
	local coste = DefinicionesMejoras.coste("Alcance", 0)
	Economia.ganar(j, coste)
	local compro = Mejoras.comprar(j, "Alcance")
	comprobar("Mejora_Alcance_1", "sumidero", coste, p.dinero, "Shop")
	local total = 0
	for _, def in DefinicionesMejoras.LISTA do
		total += p.mejoras[def.id] or 0
	end
	local mejora = ultimo("Mejora_Alcance_1")
	local camposOk = mejora ~= nil and mejora.campos[1] == "Plataforma - teclado"
		and mejora.campos[2] == "Rebirths - " .. Analitica.tramoRebirths(p.rebirths)
		and mejora.campos[3] == "Nivel - " .. tostring(math.floor(total / #DefinicionesMejoras.LISTA))
	-- Un deposito sin dinero no deja evento de economia
	local antes = #eventos(desde, "economia")
	Analitica.deposito(j, Bolsa.resumenVacio())
	local sinDinero = #eventos(desde, "economia") == antes
	-- Al salir: lo que entro sin ningun evento de aqui (lo que Bolsa recicla
	-- sin bonus) y la sesion. Antes se cuadra lo que habia (el dinero que la
	-- prueba dio para la mejora, el de otras pruebas): solo deben quedar 77
	Analitica.cuadrar(j, p)
	Economia.ganar(j, 77)
	local tutorialAhora = p.tutorial
	Analitica.salida(j, p)
	task.wait() -- el cuadre de la salida va diferido
	comprobar("Reciclaje_SinBonus", "fuente", 77, p.dinero, "Gameplay")
	local sesion = eventos(desde, "personalizado", "Sesion")
	local sesionOk = #sesion == 1 and sesion[1].ok and sesion[1].campos[1] == "Plataforma - teclado"
		and sesion[1].campos[2] == "Rebirths - " .. Analitica.tramoRebirths(p.rebirths)
		and sesion[1].campos[3] == "Tutorial - " .. tostring(tutorialAhora) and sesion[1].valor >= 0

	p.dinero = copia.dinero
	p.mejoras.Alcance = copia.alcance
	restaurarPedidos()
	Tutorial.fijar(j, copia.tutorial)
	Analitica.fijarPlataforma(j, copia.plataforma)
	Perfiles.marcarSucio(j)
	return string.format("depositos $%d (papel) y $%d (general), pedido $500, mejora $%d (compro=%s), salida $77 | mal [%s] | campos %s | deposito sin dinero sin evento=%s | %s => %s",
		r1.dinero, r2.dinero, coste, tostring(compro), table.concat(mal, "; "), describir(mejora), tostring(sinDinero), describir(sesion[1]),
		ok(#mal == 0 and compro and camposOk and sinDinero and sesionOk))
end

-- Un rebirth de verdad: progresion "Rebirth" 1 (plataforma, minutos en
-- tramo, Dinero x2), el sumidero Rebirth_1 con TODO el dinero que se pierde
-- (el ultimo saldo visto, saldo final 0) y el evento propio "Rebirth" con
-- los minutos jugados; sin saldo visto, el requisito como minimo; y los
-- tramos
function Pruebas.analiticaProgresion()
	local j = jugador()
	local p = Perfiles.obtener(j)
	if not p then
		return "sin perfil => FALLO"
	end
	Analitica.reiniciarLimites()
	local copia = { dinero = p.dinero, rebirths = p.rebirths, mejoras = table.clone(p.mejoras), tutorial = p.tutorial, plataforma = Analitica.plataformaDe(j) }
	Analitica.fijarPlataforma(j, "gamepad")
	Bolsa.vaciar(j)
	p.rebirths = 0
	for id in p.mejoras do
		p.mejoras[id] = GameConfig.NIVEL_MAX_MEJORA
	end
	local requisito = DefinicionesRebirths.rebirth(1).requisito
	p.dinero = requisito + 1234
	Perfiles.marcarSucio(j)
	task.wait(0.4) -- se publica el perfil: Analitica ve el saldo
	local desde = Analitica.contador()
	local exito = Rebirths.renacer(j)
	local minutos = math.floor(p.tiempoJugado / 60 + 0.5)
	local x2 = "DineroX2 - " .. (if Monetizacion.tienePase(j, "DineroX2") then "si" else "no")
	local prog = eventos(desde, "progresion", "Rebirth")[1]
	local sumidero = eventos(desde, "economia", "Rebirth_1")[1]
	local propio = eventos(desde, "personalizado", "Rebirth")[1]
	local progOk = prog ~= nil and prog.valor == 1 and prog.ok and prog.campos[1] == "Plataforma - gamepad"
		and prog.campos[2] == "Minutos - " .. Analitica.tramoMinutos(minutos) and prog.campos[3] == x2
	local sumideroOk = sumidero ~= nil and sumidero.flujo == "sumidero" and sumidero.valor == requisito + 1234 and sumidero.saldo == 0
		and sumidero.transaccion == "Gameplay" and sumidero.ok and sumidero.campos[2] == "Rebirths - 1" and sumidero.campos[3] == "Nivel - 0"
	local propioOk = propio ~= nil and propio.valor == minutos and propio.ok and propio.campos[1] == "Rebirth - 1"
		and propio.campos[2] == "Plataforma - gamepad" and propio.campos[3] == x2
	-- Sin saldo visto (el ultimo es el 0 de despues del rebirth): el requisito
	desde = Analitica.contador()
	Rebirths.alRenacer:Fire(j, 2)
	local suelo = eventos(desde, "economia", "Rebirth_2")[1]
	local sueloOk = suelo ~= nil and suelo.valor == DefinicionesRebirths.rebirth(2).requisito

	local tramosOk = Analitica.tramoMinutos(0) == "0-10" and Analitica.tramoMinutos(59) == "50-60"
		and Analitica.tramoMinutos(185) == "180-210" and Analitica.tramoMinutos(700) == "600-720"
		and Analitica.tramoMinutos(5000) == "1440+" and Analitica.tramoRebirths(3) == "3" and Analitica.tramoRebirths(12) == "11+"
		and Analitica.tramoDistancia(9) == "<10" and Analitica.tramoDistancia(10) == "10-19"
		and Analitica.tramoDistancia(44) == "30-44" and Analitica.tramoDistancia(75) == "60+"

	p.dinero = copia.dinero
	p.rebirths = copia.rebirths
	p.mejoras = copia.mejoras
	Tutorial.fijar(j, copia.tutorial)
	Perfiles.marcarSucio(j)
	Mejoras.aplicarVelocidad(j)
	Analitica.fijarPlataforma(j, copia.plataforma)
	return string.format("renacer=%s | %s | %s saldo %s | %s | sin saldo visto: %s | tramos=%s => %s",
		tostring(exito), describir(prog), describir(sumidero), tostring(sumidero and sumidero.saldo), describir(propio),
		describir(suelo), tostring(tramosOk), ok(exito and progOk and sumideroOk and propioOk and sueloOk and tramosOk))
end

-- AnaliticaEvent con basura: nada se acepta, la plataforma no cambia y no
-- sale ningun evento; la buena se acepta, enseguida otra no (enfriamiento)
-- y despues de tres cambios no se acepta ninguno mas (reloj de prueba)
function Pruebas.analiticaEventoMalo()
	local j = jugador()
	local previa = Analitica.plataformaDe(j)
	local relojPrevio = Analitica.reloj
	local t = 1000
	Analitica.reloj = function()
		return t
	end
	Analitica.olvidar(j) -- sin enfriamiento ni cambios de antes
	local desde = Analitica.contador()
	local rechazadosAntes = Analitica.estado().rechazados
	local basura = {
		{}, { "plataforma" }, { "plataforma", 5 }, { "plataforma", {} }, { "plataforma", true },
		{ "plataforma", "raton" }, { "plataforma", "TECLADO" }, { "plataforma", "tactil\0" },
		{ "plataforma", string.rep("x", 5000) }, { "plataforma", Vector3.new(1, 2, 3) },
		{ 123, "tactil" }, { "otra", "tactil" }, { { "plataforma" }, "tactil" }, { "Plataforma", "tactil" },
		{ "plataforma", { "tactil" } }, { "plataforma", 0 / 0 },
	}
	local aceptadas = 0
	for _, args in basura do
		if Analitica.recibirCliente(j, args[1], args[2]) then
			aceptadas += 1
		end
	end
	local trasBasura = Analitica.plataformaDe(j)
	local ok1, m1 = Analitica.recibirCliente(j, "plataforma", "tactil")
	local ok2, m2 = Analitica.recibirCliente(j, "plataforma", "gamepad")
	t += Analitica.ENFRIAMIENTO_CLIENTE + 0.1
	local ok3, m3 = Analitica.recibirCliente(j, "plataforma", "gamepad")
	t += Analitica.ENFRIAMIENTO_CLIENTE + 0.1
	local ok4, m4 = Analitica.recibirCliente(j, "plataforma", "teclado")
	t += Analitica.ENFRIAMIENTO_CLIENTE + 0.1
	local ok5, m5 = Analitica.recibirCliente(j, "plataforma", "tactil")
	local final = Analitica.plataformaDe(j)
	local okFalso = Analitica.recibirCliente({ Name = "Falso" } :: any, "plataforma", "tactil")
	local rechazados = Analitica.estado().rechazados - rechazadosAntes
	local nuevos = #Analitica.desde(desde)

	-- Con el reloj de verdad: se olvida lo de la prueba y la sesion vuelve
	-- a contar desde ahora
	Analitica.reloj = relojPrevio
	Analitica.olvidar(j)
	Analitica.entrada(j)
	Analitica.fijarPlataforma(j, previa)
	return string.format("basura: %d de %d aceptadas, plataforma=%s, %d rechazos | buena %s(%s), enseguida %s(%s), tras el enfriamiento %s(%s) y %s(%s), cuarto cambio %s(%s), queda %s | no Player: %s | eventos enviados por el remote: %d => %s",
		aceptadas, #basura, tostring(trasBasura), rechazados, tostring(ok1), m1, tostring(ok2), m2, tostring(ok3), m3,
		tostring(ok4), m4, tostring(ok5), m5, tostring(final), tostring(okFalso), nuevos,
		ok(aceptadas == 0 and trasBasura == nil and ok1 and m1 == "ok" and not ok2 and m2 == "enfriamiento"
			and ok3 and ok4 and not ok5 and m5 == "maximo" and final == "teclado" and not okFalso
			and rechazados == #basura + 2 and nuevos == 0))
end

-- AnalyticsService caido (cada llamada lanza un error): el deposito paga
-- igual, ninguna funcion de Analitica lanza, los fallos quedan contados y
-- en el registro, sale como mucho un aviso, y al volver el servicio se
-- envia otra vez
function Pruebas.analiticaSinServicio()
	local j = jugador()
	local p = Perfiles.obtener(j)
	if not p then
		return "sin perfil => FALLO"
	end
	Analitica.reiniciarLimites()
	local roto = setmetatable({}, {
		__index = function(_, metodo)
			return function()
				error("AnalyticsService simulado caido (" .. tostring(metodo) .. ")", 0)
			end
		end,
	})
	local avisos = 0
	local conexion = LogService.MessageOut:Connect(function(mensaje, tipo)
		if tipo == Enum.MessageType.MessageWarning and string.find(mensaje, "[Analitica]", 1, true) then
			avisos += 1
		end
	end)
	local restaurarPedidos = sinPedidos(p)
	local tutorialAntes = p.tutorial
	local estadoAntes = Analitica.estado()
	local previo = Analitica.usarServicio(roto)
	local desde = Analitica.contador()
	local dineroAntes = p.dinero
	local resumen, pagado = nil, 0
	local sinErrores, errorLanzado = pcall(function()
		-- Lo del juego (Senales de verdad) y una llamada de cada tipo
		resumen = Bolsa.depositarItems(j, { papel(10) }, 0, nil)
		pagado = p.dinero - dineroAntes
		Lanzamiento.alAcertar:Fire(j, 20, 1)
		Analitica.personalizado(j, "Prueba", 1, { "Prueba - si" })
		Analitica.progresion(j, "Prueba", 1, "Prueba 1", {})
		Analitica.economia(j, "fuente", 1, p.dinero, "Gameplay", "Prueba", p)
	end)
	local fallidos = 0
	for _, e in Analitica.desde(desde) do
		if not e.ok and e.motivo and string.find(e.motivo, "simulado", 1, true) then
			fallidos += 1
		end
	end
	local estadoTras = Analitica.estado()
	-- Vuelve el servicio (el de verdad, aunque en Studio no se envie: se
	-- enciende para esta llamada y se mira que de verdad llego a el)
	Analitica.usarServicio(previo)
	local enviarPrevio = Analitica.ENVIAR_EN_STUDIO
	Analitica.ENVIAR_EN_STUDIO = true
	local desdeVuelta = Analitica.contador()
	Analitica.personalizado(j, "Prueba", 1, { "Prueba - si" })
	local vuelta = Analitica.desde(desdeVuelta)[1]
	local enviadosVuelta = Analitica.estado().enviados - estadoTras.enviados
	Analitica.ENVIAR_EN_STUDIO = enviarPrevio
	task.wait(0.1) -- MessageOut puede llegar un instante despues
	conexion:Disconnect()
	p.dinero = dineroAntes
	restaurarPedidos()
	Tutorial.fijar(j, tutorialAntes)
	Perfiles.marcarSucio(j)
	local contados = estadoTras.fallos - estadoAntes.fallos
	return string.format("sin errores=%s (%s) | el deposito pago $%d (resumen $%s) | %d eventos fallidos en el registro, %d contados, %d errores propios | %d avisos | al volver: %s, %d enviado => %s",
		tostring(sinErrores), tostring(errorLanzado), pagado, tostring(resumen and resumen.dinero), fallidos, contados,
		estadoTras.errores - estadoAntes.errores, avisos, describir(vuelta), enviadosVuelta,
		ok(sinErrores and resumen ~= nil and resumen.dinero > 0 and pagado == resumen.dinero and fallidos >= 5 and contados == fallidos
			and estadoTras.errores == estadoAntes.errores and avisos <= 1 and vuelta ~= nil and vuelta.ok and enviadosVuelta == 1))
end

-- Un fallo y un acierto de verdad desde 40 studs del general (como
-- brazoLimita, con la bolsa llena: el servidor no lanza una a medias desde
-- P3): el fallo sabe desde donde se lanzo (al vaciarse la bolsa) y junto a
-- que contenedor cayo; los dos en el tramo 30-44, con su contenedor y la
-- plataforma
function Pruebas.analiticaLanzamiento()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local general = Mundo.contenedorDe(nil)
	if not p or not general then
		return "sin perfil o sin contenedor general => FALLO"
	end
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	Analitica.reiniciarLimites()
	local restaurarPedidos = sinPedidos(p)
	local tutorialAntes = p.tutorial
	local dineroAntes = p.dinero
	local plataformaPrevia = Analitica.plataformaDe(j)
	Analitica.fijarPlataforma(j, "teclado")
	local nivelAntes = p.mejoras.Brazo
	local zona = general.zona
	local function tirar(nivel: number)
		p.mejoras.Brazo = nivel
		teletransportar(j, zona.Position + Vector3.new(0, 0, -40))
		task.wait(0.6)
		Comunes.llenarBolsa(j)
		local desde = Analitica.contador()
		local lanzo = Botin.lanzarBolsa(j, zona.Position, 1)
		task.wait(4.3)
		for id, obj in Botin.objetos() do
			if obj.item.tipo == "bolsa" and obj.item.duenoId == j.UserId then
				Botin.reclamar(j, id, "toque")
			end
		end
		Bolsa.vaciar(j)
		return lanzo, eventos(desde, "personalizado", "Fallo")[1], eventos(desde, "personalizado", "Acierto")[1]
	end
	local lanzo0, fallo, aciertoCorto = tirar(0)
	local lanzo10, falloLargo, acierto = tirar(GameConfig.NIVEL_MAX_MEJORA)
	p.mejoras.Brazo = nivelAntes
	p.dinero = dineroAntes
	restaurarPedidos()
	Tutorial.fijar(j, tutorialAntes)
	Perfiles.marcarSucio(j)
	teletransportar(j, Comunes.fueraDelPatio())
	Analitica.fijarPlataforma(j, plataformaPrevia)
	local falloOk = lanzo0 and fallo ~= nil and aciertoCorto == nil and fallo.ok and math.abs(fallo.valor - 40) <= 2
		and fallo.campos[1] == "Distancia - 30-44" and fallo.campos[2] == "Contenedor - General" and fallo.campos[3] == "Plataforma - teclado"
	local aciertoOk = lanzo10 and acierto ~= nil and falloLargo == nil and acierto.ok and math.abs(acierto.valor - 40) <= 2
		and acierto.campos[1] == "Distancia - 30-44" and acierto.campos[2] == "Contenedor - General" and acierto.campos[3] == "Plataforma - teclado"
	return string.format("Brazo 0: lanzo=%s, %s | Brazo 10: lanzo=%s, %s => %s",
		tostring(lanzo0), describir(fallo), tostring(lanzo10), describir(acierto), ok(falloOk and aciertoOk))
end

-- Movimiento.alSospechar: el primero sale con el exceso de valor y sus
-- tramos (veces el limite, en el patio, plataforma); otro enseguida no sale
-- (uno cada SOSPECHA_CADA s por jugador), y pasado ese tiempo si (reloj de
-- prueba)
function Pruebas.analiticaSospecha()
	local j = jugador()
	Analitica.reiniciarLimites()
	local previa = Analitica.plataformaDe(j)
	local relojPrevio = Analitica.reloj
	local t = 5000
	Analitica.reloj = function()
		return t
	end
	Analitica.olvidar(j) -- sin sospechas de antes
	Analitica.fijarPlataforma(j, "tactil")
	local desde = Analitica.contador()
	local function datos(velocidad: number, enPatio: boolean)
		local distancia = velocidad * 0.2
		return {
			distancia = distancia, segundos = 0.2, velocidad = velocidad, limite = 40, exceso = distancia - 8,
			desde = Vector3.zero, hasta = Vector3.new(distancia, 0, 0), enPatio = enPatio,
		}
	end
	Movimiento.alSospechar:Fire(j, datos(600, true)) -- 15 veces el limite: un teletransporte
	Movimiento.alSospechar:Fire(j, datos(600, true)) -- enseguida: no sale
	t += Analitica.SOSPECHA_CADA + 1
	Movimiento.alSospechar:Fire(j, datos(100, false)) -- 2,5 veces
	local lista = eventos(desde, "personalizado", "Sospecha")

	Analitica.reloj = relojPrevio
	Analitica.olvidar(j)
	Analitica.entrada(j)
	Analitica.fijarPlataforma(j, previa)
	local primeraOk = lista[1] ~= nil and lista[1].valor == 112 and lista[1].ok and lista[1].campos[1] == "Exceso - 10x+"
		and lista[1].campos[2] == "EnPatio - si" and lista[1].campos[3] == "Plataforma - tactil"
	local segundaOk = lista[2] ~= nil and lista[2].valor == 12 and lista[2].campos[1] == "Exceso - 2-5x" and lista[2].campos[2] == "EnPatio - no"
	return string.format("%d eventos de 3 avisos: %s | %s => %s", #lista, describir(lista[1]), describir(lista[2]),
		ok(#lista == 2 and primeraOk and segundaOk))
end

return Pruebas
