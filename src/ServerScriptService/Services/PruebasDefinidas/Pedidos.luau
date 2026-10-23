--!nonstrict
--[[
	Pruebas de los pedidos del dia y las insignias (lote 7): que se generen
	tres (el primero de punteria, adaptados al Brazo), que avancen con lo que
	el jugador hace y se cobren solos, que los tres den el Turbo, y que las
	insignias se den una sola vez.

	Cada prueba guarda y restaura lo que toca del perfil.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local DefinicionesPedidos = require(Config:WaitForChild("DefinicionesPedidos"))
local DefinicionesInsignias = require(Config:WaitForChild("DefinicionesInsignias"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Pedidos = require(Servicios:WaitForChild("Pedidos"))
local Insignias = require(Servicios:WaitForChild("Insignias"))
local Turbo = require(Servicios:WaitForChild("Turbo"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador = Comunes.jugador

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

-- Copia de lo que tocan estas pruebas, para dejarlo como estaba
local function guardar(p)
	return {
		pedidos = p.pedidos,
		turboHasta = p.turboHasta,
		tutorial = p.tutorial,
		logros = table.clone(p.logros),
		estadisticas = table.clone(p.estadisticas),
		mejoras = table.clone(p.mejoras),
		dinero = p.dinero,
	}
end
local function restaurar(j, p, copia)
	for k, v in copia do
		p[k] = v
	end
	-- Lo que no habia no sale en el bucle: en un perfil v5 turboHasta es nil
	-- y el Turbo que pusiera la prueba seguiria corriendo (y doblaria el
	-- dinero de las pruebas siguientes, p. ej. salirRecicla)
	p.turboHasta = copia.turboHasta
	Perfiles.marcarSucio(j)
end

-- Tres pedidos al dia, el primero de punteria, sin repetir; el "lejos" no
-- pide mas de lo que el Brazo alcanza
function Pruebas.pedidosDia()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	p.tutorial = 99
	p.mejoras.Brazo = 0
	local malos = {}
	local vistos = {}
	for _ = 1, 200 do
		local lista = Pedidos.generar(j)
		local ids = {}
		for i, pedido in lista do
			if ids[pedido.id] then
				table.insert(malos, "repetido " .. pedido.id)
			end
			ids[pedido.id] = true
			vistos[pedido.id] = true
			if i == 1 and not DefinicionesPedidos.POR_ID[pedido.id].punteria then
				table.insert(malos, "primero no es de punteria: " .. pedido.id)
			end
			if pedido.id == "lejos" and pedido.parametro > 25 then
				-- Brazo 0 = 25 studs: con margen, como mucho 20
				table.insert(malos, "lejos " .. pedido.parametro)
			end
			if (pedido.recompensa or 0) <= 0 then
				table.insert(malos, "sin recompensa")
			end
		end
		if #lista ~= DefinicionesPedidos.POR_DIA then
			table.insert(malos, "son " .. #lista)
		end
	end
	local n = 0
	for _ in vistos do
		n += 1
	end
	-- Al cambiar de dia salen nuevos
	p.pedidos = { dia = 0, lista = {}, premioCobrado = false }
	Pedidos.asegurarDia(j)
	local hoy = DefinicionesPedidos.dia(os.time())
	local generados = p.pedidos.dia == hoy and #p.pedidos.lista == 3
	restaurar(j, p, copia)
	return string.format("plantillas vistas %d/%d | dia nuevo genera=%s | malos [%s] => %s",
		n, #DefinicionesPedidos.PLANTILLAS, tostring(generados), table.concat(malos, ", ", 1, math.min(#malos, 5)),
		ok(#malos == 0 and n == #DefinicionesPedidos.PLANTILLAS and generados))
end

-- "Separa N" avanza solo con lo bien separado y se cobra solo al llegar
function Pruebas.pedidoSeparadas()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	p.tutorial = 99
	p.pedidos = {
		dia = DefinicionesPedidos.dia(os.time()),
		lista = { { id = "separadas", objetivo = 5, progreso = 0, cobrado = false, recompensa = 250 } },
		premioCobrado = false,
	}
	local function bolsa(material, n)
		local items = {}
		for _ = 1, n do
			table.insert(items, { tipo = "basura", nombre = material, material = material, valor = 1 })
		end
		return items
	end
	Bolsa.depositarItems(j, bolsa("Papel", 3), 0, "Plastico") -- mal separadas: no cuentan
	local trasMal = p.pedidos.lista[1].progreso
	Bolsa.depositarItems(j, bolsa("Papel", 3), 0, "Papel")
	local trasBien = p.pedidos.lista[1].progreso
	local antes = Economia.dinero(j)
	Bolsa.depositarItems(j, bolsa("Papel", 3), 0, "Papel")
	local pedido = p.pedidos.lista[1]
	local cobro = Economia.dinero(j) - antes
	local resultado = string.format("tras 3 mal: %d | tras 3 bien: %d | tras 3 mas: %d/%d cobrado=%s +$%d",
		trasMal, trasBien, pedido.progreso, pedido.objetivo, tostring(pedido.cobrado), cobro)
	local bien = trasMal == 0 and trasBien == 3 and pedido.progreso == 5 and pedido.cobrado and cobro >= 250
	restaurar(j, p, copia)
	return resultado .. " => " .. ok(bien)
end

-- Cumplir los tres da el Turbo del dia (10 min) una sola vez, y el Turbo
-- dobla el dinero
function Pruebas.premioTurbo()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	p.tutorial = 99
	p.turboHasta = 0
	p.pedidos = {
		dia = DefinicionesPedidos.dia(os.time()),
		lista = {
			{ id = "piezas", objetivo = 1, progreso = 0, cobrado = false, recompensa = 1 },
			{ id = "tesoros", objetivo = 1, progreso = 1, cobrado = true, recompensa = 1 },
			{ id = "aciertos", objetivo = 1, progreso = 1, cobrado = true, recompensa = 1 },
		},
		premioCobrado = false,
	}
	local sinTurbo = Bolsa.multiplicadorDinero(j)
	Bolsa.depositarItems(j, { { tipo = "basura", nombre = "Papel", material = "Papel", valor = 1 } }, 0, nil)
	local restante = Turbo.restante(j)
	local conTurbo = Bolsa.multiplicadorDinero(j)
	-- Otro deposito no vuelve a dar el premio
	Bolsa.depositarItems(j, { { tipo = "basura", nombre = "Papel", material = "Papel", valor = 1 } }, 0, nil)
	local restanteDespues = Turbo.restante(j)
	-- Se acumula
	Turbo.anadir(j, 60)
	local acumulado = Turbo.restante(j)
	local resultado = string.format("premio=%s turbo %d s (esperado %d) | x%s -> x%s | sin repetir=%s | +60 s -> %d",
		tostring(p.pedidos.premioCobrado), restante, DefinicionesPedidos.MINUTOS_TURBO * 60, tostring(sinTurbo), tostring(conTurbo),
		tostring(restanteDespues <= restante), acumulado)
	local bien = p.pedidos.premioCobrado and math.abs(restante - DefinicionesPedidos.MINUTOS_TURBO * 60) <= 1
		and conTurbo == sinTurbo * 2 and restanteDespues <= restante and acumulado >= restante + 59
	restaurar(j, p, copia)
	return resultado .. " => " .. ok(bien)
end

-- Una insignia se da cuando el perfil cumple su condicion, una sola vez
function Pruebas.insignias()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	p.logros = {}
	p.estadisticas.depositos = 0
	p.estadisticas.aciertos = 0
	for id in p.mejoras do
		p.mejoras[id] = 0
	end
	local cero = Insignias.comprobar(j)
	local tieneAntes = p.logros.primerReciclaje == true
	p.estadisticas.depositos = 1
	local una = Insignias.comprobar(j)
	local otraVez = Insignias.comprobar(j)
	p.mejoras.Bolsa = 10
	local mejoraMax = Insignias.comprobar(j)
	local resultado = string.format("de %d posibles, %d (estadisticas reales) | primerReciclaje antes=%s | al reciclar +%d, otra vez +%d | mejora al maximo +%d (%s)",
		#DefinicionesInsignias.LISTA, cero, tostring(tieneAntes), una, otraVez, mejoraMax, tostring(p.logros.mejoraMax))
	local bien = not tieneAntes and una == 1 and p.logros.primerReciclaje == true and otraVez == 0 and mejoraMax == 1 and p.logros.mejoraMax == true
	restaurar(j, p, copia)
	-- 16 del diseno v2 y 4 de la economia v4 (22 oct)
	return resultado .. " (" .. #DefinicionesInsignias.LISTA .. " insignias) => " .. ok(bien and #DefinicionesInsignias.LISTA == 20)
end

return Pruebas
