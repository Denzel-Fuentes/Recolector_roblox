--!nonstrict
--[[
	Pruebas de la economia v4 (22 oct, docs/Economia-v4.md, paquete E1
	"Ritmo"): el ritmo que dan los numeros de Config con el modelo del
	documento (§1), el coste del siguiente rebirth y lo que pagan los
	pedidos (§2.4), lo que anuncia y regala cada rebirth (§3), el Pedido VIP
	(§5.2) y que el premio de un pedido se calcula al cobrar.

	ritmoR1, costeSiguiente y rebirthsAbren son cuentas sobre Config: no
	tocan a ningun jugador. pedidoVip y premioAlCobrar usan al de Play Solo
	y dejan su perfil (y el modo dev de pases) como estaban.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local DefinicionesRebirths = require(Config:WaitForChild("DefinicionesRebirths"))
local DefinicionesPedidos = require(Config:WaitForChild("DefinicionesPedidos"))
local DefinicionesPunteria = require(Config:WaitForChild("DefinicionesPunteria"))
local DefinicionesCosmeticos = require(Config:WaitForChild("DefinicionesCosmeticos"))
local DefinicionesInsignias = require(Config:WaitForChild("DefinicionesInsignias"))
local TablasProbabilidad = require(Config:WaitForChild("TablasProbabilidad"))
local Textos = require(Config:WaitForChild("Textos"))

local Servicios = script.Parent.Parent

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

-- ===========================================================================
-- El modelo del documento (§1.2): minutos de juego hasta cada rebirth
-- ===========================================================================

-- Los tres perfiles de jugador (§1.3): h acierto, kd fraccion del Brazo a la
-- que tira, s bolsas bien separadas y p su pureza, tp0 segundos por pieza con
-- Alcance 6, cs sobrecoste de recoger un solo color, tm segundos por pieza de
-- ir al monton y excavar, D studs monton -> contenedor, tl segundos por
-- lanzamiento, eta fraccion de la sesion en el bucle (el unico ajustado: con
-- 0,75 el modelo reproducia la auditoria del 22 oct con los numeros de antes)
local PERFILES_JUGADOR = {
	eficiente = { h = 0.75, kd = 0.86, s = 0.40, p = 0.95, tp0 = 0.65, cs = 0.25, tm = 0.15, D = 85, tl = 2.0, eta = 0.75 },
	medio = { h = 0.65, kd = 0.75, s = 0.25, p = 0.90, tp0 = 0.80, cs = 0.30, tm = 0.18, D = 90, tl = 2.5, eta = 0.75 },
	casual = { h = 0.50, kd = 0.65, s = 0.10, p = 0.85, tp0 = 0.90, cs = 0.40, tm = 0.20, D = 95, tl = 3.0, eta = 0.75 },
}
-- Constantes del modelo (no son de Config): el Alcance al que se midio tp0,
-- el tramo minimo que se anda aunque se tire desde lejos y los segundos de
-- ir a por una bolsa fallada
local ALCANCE_REFERENCIA = 6
local ANDAR_MINIMO = 10
local SEGUNDOS_FALLO = 3

-- (1) Valor medio de una pieza de basura con los tipos que abren `rebirths`
local function valorPieza(rebirths: number): number
	local suma, peso = 0, 0
	for _, e in TablasProbabilidad.MEZCLA.patio do
		if GameConfig.materialAbierto(e.id, rebirths) then
			suma += e.peso * GameConfig.VALOR_MATERIAL[e.id]
			peso += e.peso
		end
	end
	return suma / peso
end

local function pesoPieza(id: string): number
	for _, e in TablasProbabilidad.TIPO_PIEZA do
		if e.id == id then
			return e.peso / TablasProbabilidad.suma(TablasProbabilidad.TIPO_PIEZA)
		end
	end
	return 0
end

-- (2) K: lo que vale una pieza media en piezas de basura revuelta, con
-- billetes, tesoros (y el seguro del monton grande) y lo bien separado
local function factorK(perfil): number
	local chico, grande = GameConfig.TAMANOS_MONTON.chico, GameConfig.TAMANOS_MONTON.grande
	local piezasChicos, piezasGrandes = chico.cantidad * chico.max, grande.cantidad * grande.max
	local fraccionGrande = piezasGrandes / (piezasChicos + piezasGrandes)
	local fBillete = pesoPieza("billete")
	local pTesoro = pesoPieza("tesoro")
	-- El tesoro seguro del grande: la probabilidad de que no salga ninguno en
	-- sus piezas, repartida entre ellas
	local fTesoro = pTesoro + fraccionGrande * (1 - pTesoro) ^ grande.max / grande.max
	local fBasura = 1 - fBillete - fTesoro
	local s, p = perfil.s, perfil.p
	local S = (1 - s) + s * (GameConfig.MULT_SEPARADO * p + GameConfig.MULT_MAL_SEPARADO * (1 - p))
	return fBasura * S + fBillete * GameConfig.MULT_BILLETE + fTesoro * GameConfig.MULT_TESORO
end

-- (3)-(6) Ingreso real en $/min con las 4 mejoras al nivel L y 0 rebirths
local function ingreso(perfil, L: number): number
	local h = perfil.h
	local N = DefinicionesMejoras.valor("Bolsa", L)
	local A = DefinicionesMejoras.valor("Alcance", L)
	local V = DefinicionesMejoras.valor("Velocidad", L)
	local B = DefinicionesMejoras.valor("Brazo", L)
	local d = perfil.kd * B
	-- Racha media con acierto h: +RACHA_PASO por cada acierto seguido, con tope
	local racha = 0
	for k = 0, DefinicionesPunteria.RACHA_TOPE - 1 do
		racha += DefinicionesPunteria.RACHA_PASO * h ^ k
	end
	local T = 1 + h * (DefinicionesPunteria.bonusDistancia(d) + racha)
	local pago = N * valorPieza(0) * factorK(perfil) * T
	local recoger = N * (perfil.tp0 * math.sqrt(ALCANCE_REFERENCIA / A) * (1 + perfil.cs * perfil.s) + perfil.tm)
	local andar = 2 * math.max(perfil.D - d, ANDAR_MINIMO) / V
	local fallo = (1 - h) * (SEGUNDOS_FALLO + 2 * d / V)
	local ciclo = recoger + andar + perfil.tl + fallo
	return perfil.eta * 60 * pago / ciclo
end

-- (7) Minutos de juego de un rebirth: de `n` a n + 1 rebirths. Recomprar las
-- 40 mejoras (cada tramo de L a L + 1 con el ingreso del nivel L) y ahorrar
-- el requisito al maximo; todo el ingreso con n rebirths es el de 0 por
-- multiplicador x (valor de la pieza con n / con 0)
local function minutosRebirth(perfil, n: number): (number, number, number)
	local mejoras = 0
	for L = 0, DefinicionesMejoras.NIVEL_MAX - 1 do
		local tramo = 0
		for _, def in DefinicionesMejoras.LISTA do
			tramo += DefinicionesMejoras.coste(def.id, L) or 0
		end
		mejoras += tramo / ingreso(perfil, L)
	end
	local ahorro = DefinicionesRebirths.rebirth(n + 1).requisito / ingreso(perfil, DefinicionesMejoras.NIVEL_MAX)
	local factor = DefinicionesRebirths.multiplicador(n) * valorPieza(n) / valorPieza(0)
	return (mejoras + ahorro) / factor, mejoras / factor, ahorro / factor
end

local function horas(minutos: number): string
	local m = math.floor(minutos + 0.5)
	return string.format("%d:%02d", m // 60, m % 60)
end

-- El ritmo del jugador medio (§2.5), jugando seguido, sin pases ni
-- recompensas: el R1 entre 45 y 60 min (el objetivo del KPI de §7.3) y los
-- tramos R1..R5 del documento (58 / 71 / 87 / 106 / 123 min; 7:26 hasta el
-- R5), con 2 min de margen por tramo. Los del eficiente y el casual se
-- ensenan para comparar (doc: R1 38 y 82 min)
function Pruebas.ritmoR1()
	local medio = PERFILES_JUGADOR.medio
	local DOC = { 57.9, 71.5, 86.9, 106.4, 123.4 }
	local tramos, mal = {}, {}
	local acumulado = 0
	for n = 0, 4 do
		local m = minutosRebirth(medio, n)
		acumulado += m
		table.insert(tramos, string.format("%.1f", m))
		if math.abs(m - DOC[n + 1]) > 2 then
			table.insert(mal, string.format("R%d %.1f (doc %.1f)", n + 1, m, DOC[n + 1]))
		end
	end
	local r1, mejorasR1, ahorroR1 = minutosRebirth(medio, 0)
	local i0, i10 = ingreso(medio, 0), ingreso(medio, DefinicionesMejoras.NIVEL_MAX)
	local eficiente, casual = minutosRebirth(PERFILES_JUGADOR.eficiente, 0), minutosRebirth(PERFILES_JUGADOR.casual, 0)
	return string.format("medio: R1 %.1f min (%.1f de mejoras + %.1f de ahorro; objetivo 45-60) | tramos R1..R5 %s (doc 57.9/71.5/86.9/106.4/123.4) | R5 a las %s (doc 7:26) | $/min nivel 0 %.0f, nivel 10 %.0f (doc 299 y 1.110) | R1 eficiente %.1f, casual %.1f (doc 38.4 y 81.6) | mal [%s] => %s",
		r1, mejorasR1, ahorroR1, table.concat(tramos, "/"), horas(acumulado), i0, i10, eficiente, casual, table.concat(mal, ", "),
		ok(r1 >= 45 and r1 <= 60 and #mal == 0 and math.abs(acumulado - 446) <= 6))
end

-- ===========================================================================
-- Coste del siguiente rebirth y premios de los pedidos (§2.4)
-- ===========================================================================

-- costeSiguiente = requisito del siguiente + las 4 mejoras ($35.485); los
-- pedidos pagan 1,5 / 2 / 3 % de el en dos cifras significativas (la tabla
-- de §2.4, de 0 a 4 rebirths); el Pedido VIP paga como dificil y un pedido
-- de una plantilla que no existe, nada
function Pruebas.costeSiguiente()
	local COSTES = { 50485, 135485, 285485, 535485, 835485 }
	local PREMIOS = {
		{ 760, 1000, 1500 },
		{ 2000, 2700, 4100 },
		{ 4300, 5700, 8600 },
		{ 8000, 11000, 16000 },
		{ 13000, 17000, 25000 },
	}
	local mal = {}
	for r = 0, 4 do
		local coste = DefinicionesRebirths.costeSiguiente(r)
		if coste ~= COSTES[r + 1] then
			table.insert(mal, string.format("coste %d rebirths %s", r, tostring(coste)))
		end
		for i, dificultad in { "facil", "medio", "dificil" } do
			local premio = DefinicionesPedidos.recompensa(dificultad, r)
			if premio ~= PREMIOS[r + 1][i] then
				table.insert(mal, string.format("%s con %d: %s", dificultad, r, tostring(premio)))
			end
		end
	end
	for _, caso in { { 757.275, 760 }, { 1009.7, 1000 }, { 4064.55, 4100 }, { 1000, 1000 }, { 99.4, 99 }, { 0, 0 } } do
		local r = DefinicionesRebirths.redondear(caso[1])
		if r ~= caso[2] then
			table.insert(mal, string.format("redondear(%s)=%s", tostring(caso[1]), tostring(r)))
		end
	end
	local vip = DefinicionesPedidos.premio({ id = "separadas", vip = true }, 0)
	local normal = DefinicionesPedidos.premio({ id = "separadas" }, 0)
	local desconocido = DefinicionesPedidos.premio({ id = "noExiste" }, 0)
	return string.format("costes 0..4 rebirths %s,%s,%s,%s,%s | separadas $%d, como VIP $%d | plantilla desconocida $%d | mal [%s] => %s",
		tostring(DefinicionesRebirths.costeSiguiente(0)), tostring(DefinicionesRebirths.costeSiguiente(1)), tostring(DefinicionesRebirths.costeSiguiente(2)),
		tostring(DefinicionesRebirths.costeSiguiente(3)), tostring(DefinicionesRebirths.costeSiguiente(4)), normal, vip, desconocido,
		table.concat(mal, ", "),
		ok(#mal == 0 and DefinicionesMejoras.costeTotal() == 35485 and normal == 760 and vip == 1500 and desconocido == 0))
end

-- ===========================================================================
-- Lo que abre cada rebirth (§3)
-- ===========================================================================

-- Que lo que anuncia el panel (rebirth(n).desbloquea, con su texto en
-- Textos) es lo que se da de verdad: el metal y el organico en
-- MATERIAL_REBIRTH, los cosmeticos regalados con ese rebirth, la insignia
-- del R5 y la del R10; y que los que dicen "multiplicador" no regalan nada
function Pruebas.rebirthsAbren()
	local REGALOS = { -- clave -> cosmetico que tiene que dar ese rebirth
		bolsaPlateada = { "bolsa", "Plateada" },
		bolsaHielo = { "bolsa", "Hielo" },
		estelaFuego = { "estela", "Fuego" },
	}
	local INSIGNIAS = { estelaFuego = "rebirth5", leyenda = "rebirth10" }
	local function insigniaEn(n: number): string?
		for _, def in DefinicionesInsignias.LISTA do
			if def.estadistica == "rebirthMaximo" and def.meta == n then
				return def.id
			end
		end
		return nil
	end
	local function cosmeticoEn(n: number): string?
		for _, lista in { DefinicionesCosmeticos.BOLSAS, DefinicionesCosmeticos.ESTELAS } do
			for _, def in lista do
				if def.rebirth == n then
					return def.id
				end
			end
		end
		return nil
	end
	local mal, abren = {}, {}
	for n = 1, 12 do
		local clave = DefinicionesRebirths.rebirth(n).desbloquea
		table.insert(abren, n .. "=" .. clave)
		if (Textos.REBIRTH.desbloquea :: any)[clave] == nil then
			table.insert(mal, n .. " sin texto " .. clave)
		end
		local regalo = REGALOS[clave]
		if regalo then
			local def = DefinicionesCosmeticos.obtener(regalo[1], regalo[2])
			if not def or def.rebirth ~= n then
				table.insert(mal, string.format("%d %s no regala %s", n, clave, regalo[2]))
			end
		end
		if INSIGNIAS[clave] and insigniaEn(n) ~= INSIGNIAS[clave] then
			table.insert(mal, string.format("%d %s sin la insignia %s", n, clave, INSIGNIAS[clave]))
		end
		if clave == "multiplicador" and (cosmeticoEn(n) or insigniaEn(n)) then
			table.insert(mal, string.format("%d dice multiplicador y regala %s", n, tostring(cosmeticoEn(n) or insigniaEn(n))))
		end
	end
	local materiales = DefinicionesRebirths.rebirth(GameConfig.MATERIAL_REBIRTH.Metal).desbloquea == "metal"
		and DefinicionesRebirths.rebirth(GameConfig.MATERIAL_REBIRTH.Organico).desbloquea == "organico"
	-- Ningun cosmetico de rebirth sin anunciar
	for _, lista in { DefinicionesCosmeticos.BOLSAS, DefinicionesCosmeticos.ESTELAS } do
		for _, def in lista do
			if def.rebirth and not REGALOS[DefinicionesRebirths.rebirth(def.rebirth).desbloquea] then
				table.insert(mal, def.id .. " (rebirth " .. def.rebirth .. ") sin anunciar")
			end
		end
	end
	return string.format("abren [%s] | metal y organico=%s | mal [%s] => %s", table.concat(abren, " "), tostring(materiales),
		table.concat(mal, ", "), ok(#mal == 0 and materiales))
end

-- ===========================================================================
-- Pedidos con jugador
-- ===========================================================================

-- Lo que tocan las dos pruebas de abajo, para dejarlo como estaba. Por
-- lista y no recorriendo la copia: un campo que era nil no estaria en ella
-- y se quedaria con lo de la prueba. (El Turbo es turboRestante desde la
-- v5 del perfil: turboHasta ya no existe, K1)
local CAMPOS_PERFIL = { "dinero", "rebirths", "tutorial", "pedidos", "pasesCache", "estadisticas", "logros", "turboRestante" }
local CLONAR = { pasesCache = true, estadisticas = true, logros = true }
local function guardarPerfil(p)
	local copia = {}
	for _, campo in CAMPOS_PERFIL do
		local v = p[campo]
		copia[campo] = if CLONAR[campo] and typeof(v) == "table" then table.clone(v) else v
	end
	return copia
end
local function restaurarPerfil(j, p, copia)
	for _, campo in CAMPOS_PERFIL do
		p[campo] = copia[campo]
	end
	require(Servicios:WaitForChild("Perfiles")).marcarSucio(j)
end

local function cuantosVip(lista): number
	local n = 0
	for _, pedido in lista do
		if pedido.vip then
			n += 1
		end
	end
	return n
end

local function pedido(id: string, vip: boolean?)
	return { id = id, objetivo = 1, progreso = 0, cobrado = false, vip = vip }
end

-- El Pedido VIP (§5.2): sin el pase, tres; con el, uno mas, vip, de una
-- plantilla que no salio, que paga como dificil ($1.500 con 0 rebirths). Si
-- el pase llega con el dia empezado se anade al momento, una sola vez. Y no
-- cuenta para el Turbo: el VIP y dos de los tres no lo dan, el tercero si
function Pruebas.pedidoVip()
	local Comunes = require(script.Parent:WaitForChild("Comunes"))
	local Perfiles = require(Servicios:WaitForChild("Perfiles"))
	local Pedidos = require(Servicios:WaitForChild("Pedidos"))
	local Economia = require(Servicios:WaitForChild("Economia"))
	local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
	local j = Comunes.jugador()
	local p = Perfiles.obtener(j)
	local copia = guardarPerfil(p)
	local modoDev = Monetizacion.modoDev()
	if modoDev then
		Monetizacion.fijarModoDev(false)
	end
	p.tutorial = 99
	p.rebirths = 0
	p.pasesCache[Pedidos.PASE_VIP] = nil
	local malos = {}
	-- Sin el pase
	local sinPase = Pedidos.generar(j)
	if #sinPase ~= DefinicionesPedidos.POR_DIA or cuantosVip(sinPase) ~= 0 then
		table.insert(malos, string.format("sin VIP %d pedidos, %d vip", #sinPase, cuantosVip(sinPase)))
	end
	-- Con el pase
	p.pasesCache[Pedidos.PASE_VIP] = true
	local premioVip = DefinicionesPedidos.recompensa(DefinicionesPedidos.DIFICULTAD_VIP, 0)
	for _ = 1, 100 do
		local lista = Pedidos.generar(j)
		local vip = lista[#lista]
		local repetido = false
		for i = 1, #lista - 1 do
			repetido = repetido or lista[i].id == vip.id
		end
		if #lista ~= DefinicionesPedidos.POR_DIA_VIP or cuantosVip(lista) ~= 1 or not vip.vip or repetido or vip.recompensa ~= premioVip then
			table.insert(malos, string.format("con VIP %d pedidos, %d vip, ultimo %s vip=%s $%s", #lista, cuantosVip(lista), vip.id,
				tostring(vip.vip), tostring(vip.recompensa)))
			break
		end
	end
	-- El pase llega con el dia empezado: los tres de hoy ya estan
	p.pasesCache[Pedidos.PASE_VIP] = nil
	p.pedidos = { dia = 0, lista = {}, premioCobrado = false }
	Pedidos.asegurarDia(j)
	local antesDelPase = #p.pedidos.lista
	p.pasesCache[Pedidos.PASE_VIP] = true
	Monetizacion.alCambiarPases:Fire(j)
	local trasPase = #p.pedidos.lista
	Monetizacion.alCambiarPases:Fire(j)
	local otraVez = #p.pedidos.lista
	local alMomento = antesDelPase == DefinicionesPedidos.POR_DIA and trasPase == DefinicionesPedidos.POR_DIA_VIP
		and otraVez == trasPase and p.pedidos.lista[trasPase].vip == true
	-- El Turbo de los tres: el VIP no cuenta
	p.pedidos = {
		dia = DefinicionesPedidos.dia(Pedidos.ahora()),
		lista = { pedido("piezas"), pedido("tesoros"), pedido("aciertos"), pedido("bolsasLlenas", true) },
		premioCobrado = false,
	}
	local antes = Economia.dinero(j)
	Pedidos.avanzar(j, "bolsasLlenas", 1)
	local cobroVip = Economia.dinero(j) - antes
	Pedidos.avanzar(j, "piezas", 1)
	Pedidos.avanzar(j, "tesoros", 1)
	local turboAntes = p.pedidos.premioCobrado
	Pedidos.avanzar(j, "aciertos", 1)
	local turboTras = p.pedidos.premioCobrado
	restaurarPerfil(j, p, copia)
	if modoDev then
		Monetizacion.fijarModoDev(true)
	end
	-- Los que escuchan los pases (Pedidos, la corona...) vuelven a lo de antes
	Monetizacion.alCambiarPases:Fire(j)
	return string.format("con el dia empezado %d -> %d (y otra vez %d) | el VIP paga $%d (esperado $%d) | Turbo tras el VIP y dos=%s, tras los tres=%s | malos [%s] => %s",
		antesDelPase, trasPase, otraVez, cobroVip, premioVip, tostring(turboAntes), tostring(turboTras), table.concat(malos, ", "),
		ok(#malos == 0 and alMomento and premioVip == 1500 and cobroVip == premioVip and turboAntes == false and turboTras == true))
end

-- El premio se calcula al cobrar (§2.4): un pedido de hoy, pendiente desde
-- antes de renacer, paga lo del rebirth nuevo (medio con 1 rebirth: $2.700,
-- no los $1.000 de 0), tal cual aunque Dinero x2 y el Turbo doblen lo
-- reciclado; y cada pedido suma 1 a pedidosCompletados (la insignia
-- pedidos30 pide 30)
function Pruebas.premioAlCobrar()
	local Comunes = require(script.Parent:WaitForChild("Comunes"))
	local Perfiles = require(Servicios:WaitForChild("Perfiles"))
	local Pedidos = require(Servicios:WaitForChild("Pedidos"))
	local Economia = require(Servicios:WaitForChild("Economia"))
	local Bolsa = require(Servicios:WaitForChild("Bolsa"))
	local Turbo = require(Servicios:WaitForChild("Turbo"))
	local j = Comunes.jugador()
	local p = Perfiles.obtener(j)
	local copia = guardarPerfil(p)
	p.tutorial = 99
	p.rebirths = 0
	p.pedidos = {
		dia = DefinicionesPedidos.dia(Pedidos.ahora()),
		lista = { pedido("piezas"), pedido("tesoros"), pedido("aciertos") },
		premioCobrado = false,
	}
	local valiaAntes = DefinicionesPedidos.premio(p.pedidos.lista[1], 0)
	-- Renace (solo cuenta el numero) y con todo lo que dobla lo reciclado
	p.rebirths = 1
	p.pasesCache.DineroX2 = true
	Turbo.anadir(j, 120)
	local multiplicadorBolsa = Bolsa.multiplicadorDinero(j)
	p.estadisticas.pedidosCompletados = 29
	local antes = Economia.dinero(j)
	Pedidos.avanzar(j, "piezas", 1)
	local cobro = Economia.dinero(j) - antes
	local cobrado = p.pedidos.lista[1]
	local esperado = DefinicionesPedidos.recompensa("medio", 1)
	local cumplidos = p.estadisticas.pedidosCompletados
	local insignia = DefinicionesInsignias.cumple(DefinicionesInsignias.POR_ID.pedidos30, p)
	restaurarPerfil(j, p, copia)
	return string.format("valia $%d con 0 rebirths, cobra $%d con 1 (esperado $%d) aunque lo reciclado vaya x%s | anotado $%s | pedidosCompletados 29 -> %d, pedidos30=%s => %s",
		valiaAntes, cobro, esperado, tostring(multiplicadorBolsa), tostring(cobrado.recompensa), cumplidos, tostring(insignia),
		ok(valiaAntes == 1000 and esperado == 2700 and cobro == esperado and cobrado.recompensa == esperado and cobrado.cobrado
			and multiplicadorBolsa > 1 and cumplidos == 30 and insignia))
end

return Pruebas
