--!nonstrict
--[[
	Pruebas del patio (diseno v2, lote 3): cuadrantes y sus zonas, lo que
	sale de un monton, precios por material, prioridad del excavador,
	reposicion, y el desbloqueo por TIPO de basura del 5 oct
	(materialPorRebirth, reclamoMaterialBloqueado, sinBarreras).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local TablasProbabilidad = require(Shared:WaitForChild("Config"):WaitForChild("TablasProbabilidad"))
local Cuadrantes = require(Shared:WaitForChild("Utilidades"):WaitForChild("Cuadrantes"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Botin = require(Servicios:WaitForChild("Botin"))
local GeneradorBotin = require(Servicios:WaitForChild("GeneradorBotin"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador, teletransportar = Comunes.jugador, Comunes.teletransportar

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

-- Lo que sale depende de los rebirths del excavador (5 oct): con 0 solo
-- papel y plastico, con 1 tambien metal, con 2 los cuatro con los pesos de
-- MEZCLA.patio (8.000 piezas por nivel)
function Pruebas.materialPorRebirth()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = p.rebirths
	local partes, bien = {}, true
	for _, rebirths in { 0, 1, 2 } do
		p.rebirths = rebirths
		local lista = GeneradorBotin.generar(j, "chico", "patio", 8000)
		local cuenta, n = {}, 0
		for _, item in lista do
			if item.material then
				cuenta[item.material] = (cuenta[item.material] or 0) + 1
				n += 1
			end
		end
		local total = 0
		for _, e in TablasProbabilidad.MEZCLA.patio do
			if GameConfig.materialAbierto(e.id, rebirths) then
				total += e.peso
			end
		end
		local texto = {}
		for _, e in TablasProbabilidad.MEZCLA.patio do
			local pct = (cuenta[e.id] or 0) / n * 100
			local esperado = if GameConfig.materialAbierto(e.id, rebirths) then e.peso / total * 100 else 0
			bien = bien and math.abs(pct - esperado) < 2.5 and (esperado > 0 or (cuenta[e.id] or 0) == 0)
			table.insert(texto, string.format("%s %.0f/%.0f", e.id, pct, esperado))
		end
		table.insert(partes, "R" .. rebirths .. ": " .. table.concat(texto, " "))
	end
	p.rebirths = antes
	return table.concat(partes, " | ") .. " => " .. ok(bien)
end

-- Cada monton sabe su cuadrante y zona, coherentes con donde esta; tres
-- por cuadrante (2 chicos + 1 grande)
function Pruebas.cuadrantes()
	local porCuadrante = {}
	local mal = {}
	for _, m in Botin.montones() do
		local c = Cuadrantes.en(m.ranura.Position)
		if c ~= m.cuadrante or GameConfig.CUADRANTES[m.cuadrante].zona ~= m.zona then
			table.insert(mal, string.format("%d(%s en %s)", m.id, m.zona, tostring(c)))
		end
		local t = porCuadrante[m.cuadrante] or { chico = 0, grande = 0 }
		t[m.tamano] = (t[m.tamano] or 0) + 1
		porCuadrante[m.cuadrante] = t
	end
	local partes, reparto = {}, true
	for i = 1, #GameConfig.CUADRANTES do
		local t = porCuadrante[i] or { chico = 0, grande = 0 }
		table.insert(partes, string.format("%d:%s %dc+%dg", i, GameConfig.CUADRANTES[i].zona, t.chico or 0, t.grande or 0))
		reparto = reparto and t.chico == 2 and t.grande == 1
	end
	local ranura = Botin.montones()[1] and Botin.montones()[1].ranura
	local horneado = ranura ~= nil and ranura:GetAttribute("Cuadrante") ~= nil
	-- El mundo v5 hornea la Zona; uno v4 aun lleva Material (hay que rehornear)
	local zonas = ranura ~= nil and ranura:GetAttribute("Zona") ~= nil
	return string.format("%d montones [%s] | horneado v2=%s | con Zona (mundo v5)=%s | mal [%s] => %s",
		#Botin.montones(), table.concat(partes, " "), tostring(horneado), tostring(zonas), table.concat(mal, " "), ok(#mal == 0 and reparto and horneado))
end

-- 5 % billetes y 1 % tesoros
function Pruebas.variedadPiezas()
	local j = jugador()
	local lista = GeneradorBotin.generar(j, "chico", "patio", 8000)
	local billetes, tesoros = 0, 0
	for _, item in lista do
		if item.tipo == "billete" then
			billetes += 1
		elseif item.tipo == "tesoro" then
			tesoros += 1
		end
	end
	local n = #lista
	return string.format("%d piezas: billetes %.1f%% tesoros %.1f%% => %s", n, billetes / n * 100, tesoros / n * 100,
		ok(billetes / n > 0.035 and billetes / n < 0.065 and tesoros / n > 0.004 and tesoros / n < 0.018))
end

-- El monton grande trae siempre un tesoro
function Pruebas.tesoroGrande()
	local j = jugador()
	local sin, total, piezas = 0, 200, 0
	for _ = 1, total do
		local lista = GeneradorBotin.generar(j, "grande", "patio")
		piezas += #lista
		local hay = false
		for _, item in lista do
			hay = hay or item.tipo == "tesoro"
		end
		if not hay then
			sin += 1
		end
	end
	return string.format("%d grandes de %.0f piezas de media, sin tesoro: %d => %s", total, piezas / total, sin, ok(sin == 0 and piezas / total == 60))
end

-- Precios por material: una pieza, un billete (x6) y un tesoro (x40)
function Pruebas.valoresMaterial()
	local j = jugador()
	local malos = {}
	for material, v in GameConfig.VALOR_MATERIAL do
		local b = Bolsa.valorDeposito(j, { tipo = "basura", nombre = "x", material = material })
		local bi = Bolsa.valorDeposito(j, { tipo = "billete", nombre = "x", material = material })
		local t = Bolsa.valorDeposito(j, { tipo = "tesoro", nombre = "x", material = material })
		if b ~= v or bi ~= v * 6 or t ~= v * 40 then
			table.insert(malos, string.format("%s %d/%d/%d", material, b, bi, t))
		end
	end
	local plastico = Bolsa.valorDeposito(j, { tipo = "billete", nombre = "x", material = "Plastico" })
	return string.format("billete de plastico $%d (esperado 42) | mal [%s] => %s", plastico, table.concat(malos, " "), ok(#malos == 0 and plastico == 42))
end

-- Durante 10 s solo quien excavo recoge las piezas de su monton
function Pruebas.prioridadExcavador()
	local j = jugador()
	local m = Comunes.montonesLlenos(1)[1]
	teletransportar(j, m.ranura.Position + Vector3.new(GameConfig.TAMANOS_MONTON[m.tamano].radio + 6, 0, 0))
	task.wait(0.2)
	assert(Comunes.excavar(j, m))
	task.wait(1.6)
	local ids = {}
	for id, obj in Botin.objetos() do
		if obj.monton == m then
			table.insert(ids, id)
		end
	end
	Bolsa.vaciar(j)
	-- Otro jugador (simulado): el monton es suyo y recien excavado
	local otro = { Parent = workspace, DisplayName = "Otro" }
	m.excavador = otro
	m.activadoEn = os.clock()
	local okAntes, motivoAntes = Botin.reclamar(j, ids[1], "toque")
	-- A los 10 s ya se puede
	m.activadoEn = os.clock() - GameConfig.PRIORIDAD_EXCAVADOR - 0.1
	local okDespues = Botin.reclamar(j, ids[2], "toque")
	-- Y el propio excavador nunca espera
	m.excavador = j
	m.activadoEn = os.clock()
	local okPropio = Botin.reclamar(j, ids[3], "toque")
	Bolsa.vaciar(j)
	return string.format("ajeno a los 0 s: %s (%s) | a los 10 s: %s | el excavador: %s => %s",
		tostring(okAntes), tostring(motivoAntes), tostring(okDespues), tostring(okPropio),
		ok(not okAntes and motivoAntes == "prioridad" and okDespues and okPropio))
end

-- Un monton terminado (menos del 25 %) se repone solo: los restos se
-- retiran y vuelve la colina
function Pruebas.reposicion()
	local j = jugador()
	local espera = GameConfig.REPOSICION_MONTON
	GameConfig.REPOSICION_MONTON = 2
	local m = Comunes.montonesLlenos(1)[1]
	teletransportar(j, m.ranura.Position + Vector3.new(GameConfig.TAMANOS_MONTON[m.tamano].radio + 6, 0, 0))
	task.wait(0.2)
	assert(Comunes.excavar(j, m))
	task.wait(1.6)
	local limite = math.floor(m.objetosIniciales * GameConfig.FRACCION_MONTON_DISPONIBLE)
	for id, obj in Botin.objetos() do
		if m.objetosVivos < limite then
			break
		end
		if obj.monton == m then
			if Bolsa.estaLlena(j) then
				Bolsa.vaciar(j)
			end
			Botin.reclamar(j, id, "toque")
		end
	end
	local restos = m.objetosVivos
	local estadoTerminado = m.estado
	task.wait(2.6)
	GameConfig.REPOSICION_MONTON = espera
	local quedan = 0
	for _, obj in Botin.objetos() do
		if obj.monton == m then
			quedan += 1
		end
	end
	Bolsa.vaciar(j)
	local lomas = 0
	for _, hijo in (if m.modelo then m.modelo:GetChildren() else {}) do
		if hijo.Name:match("^Loma_") then
			lomas += 1
		end
	end
	return string.format("terminado con %d restos (%s) | a los 2 s: estado=%s restos=%d lomas=%d => %s",
		restos, estadoTerminado, m.estado, quedan, lomas,
		ok(restos > 0 and m.estado == "lleno" and quedan == 0 and lomas > 0))
end

-- Un jugador con Rebirth 2 excava (salen los cuatro tipos); otro con 0 no
-- puede llevarse el metal ni el organico de ese monton, pero si el papel y
-- el plastico. Ningun monton esta cerrado.
function Pruebas.reclamoMaterialBloqueado()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = p.rebirths
	local m = Comunes.montonesLlenos(1)[1]
	teletransportar(j, m.ranura.Position + Vector3.new(GameConfig.TAMANOS_MONTON[m.tamano].radio + 4, 0, 0))
	task.wait(0.2)
	p.rebirths = 2
	Botin.liberarMontones(j)
	local excavo = Comunes.excavar(j, m)
	task.wait(1.6)
	local bloqueado, abierto = nil, nil
	for oid, obj in Botin.objetos() do
		if obj.monton == m then
			if not GameConfig.materialAbierto(obj.item.material, 0) then
				bloqueado = bloqueado or oid
			else
				abierto = abierto or oid
			end
		end
	end
	Bolsa.vaciar(j)
	p.rebirths = 0
	local okB, motivoB = Botin.reclamar(j, bloqueado, "toque")
	local okA = Botin.reclamar(j, abierto, "toque")
	p.rebirths = 2
	local okB2 = Botin.reclamar(j, bloqueado, "toque")
	p.rebirths = antes
	Perfiles.marcarSucio(j)
	Bolsa.vaciar(j)
	teletransportar(j, Comunes.fueraDelPatio())
	return string.format("excavo con R2=%s | con 0: tipo cerrado=%s (%s) tipo abierto=%s | con 2: tipo cerrado=%s => %s",
		tostring(excavo), tostring(okB), tostring(motivoB), tostring(okA), tostring(okB2),
		ok(excavo and bloqueado ~= nil and not okB and motivoB == "materialBloqueado" and okA and okB2))
end

-- Sin secciones bloqueadas: todos los cuadrantes abiertos con 0 rebirths y
-- ninguna barrera horneada
function Pruebas.sinBarreras()
	local cerrados = 0
	for i = 1, #GameConfig.CUADRANTES do
		if not Cuadrantes.abierto(i, 0) then
			cerrados += 1
		end
	end
	local barreras = #CollectionService:GetTagged("BarreraCuadrante")
	return string.format("cuadrantes cerrados con 0 rebirths: %d | barreras: %d => %s", cerrados, barreras, ok(cerrados == 0 and barreras == 0))
end

return Pruebas
