--!nonstrict
--[[
	Pruebas del patio por zonas (diseno v2, lote 3; zonas revueltas desde el
	29 sep): cuadrantes y sus zonas, lo que sale de un monton, precios por
	material, prioridad del excavador, reposicion a los 45 s y bloqueo por
	rebirth (servidor y grupos de colision). La mezcla de cada zona y los
	fragmentos se prueban en Mascotas (mezclaZonas, fragmentosMonton).
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Cuadrantes = require(Shared:WaitForChild("Utilidades"):WaitForChild("Cuadrantes"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Botin = require(Servicios:WaitForChild("Botin"))
local GeneradorBotin = require(Servicios:WaitForChild("GeneradorBotin"))
local Colisiones = require(Servicios:WaitForChild("Colisiones"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador, teletransportar = Comunes.jugador, Comunes.teletransportar

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
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

-- Sin el rebirth no se excava ni se recoge en un cuadrante cerrado; con el, si
function Pruebas.bloqueoRebirth()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = p.rebirths
	local m = nil
	for _, monton in Botin.montones() do
		if monton.estado == "lleno" and GameConfig.CUADRANTES[monton.cuadrante].rebirth == 1 then
			m = monton
			break
		end
	end
	if not m then
		Botin.repoblarAhora()
		return "no habia monton lleno en un cuadrante de Rebirth 1 (repuesto; repite) => FALLO"
	end
	teletransportar(j, m.ranura.Position + Vector3.new(GameConfig.TAMANOS_MONTON[m.tamano].radio + 4, 0, 0))
	task.wait(0.2)
	p.rebirths = 0
	Botin.liberarMontones(j)
	local ok0, motivo0 = Botin.excavar(j, m)
	p.rebirths = 1
	local ok1 = Comunes.excavar(j, m)
	task.wait(1.6)
	local id = nil
	for oid, obj in Botin.objetos() do
		if obj.monton == m then
			id = oid
			break
		end
	end
	p.rebirths = 0
	local recoge0, motivoRecoge = Botin.reclamar(j, id, "toque")
	p.rebirths = 1
	local recoge1 = Botin.reclamar(j, id, "toque")
	p.rebirths = antes
	Perfiles.marcarSucio(j)
	Bolsa.vaciar(j)
	teletransportar(j, Comunes.fueraDelPatio())
	return string.format("%s con 0 rebirths: excavar=%s (%s) recoger=%s (%s) | con 1: excavar=%s recoger=%s => %s",
		m.zona, tostring(ok0), tostring(motivo0), tostring(recoge0), tostring(motivoRecoge), tostring(ok1), tostring(recoge1),
		ok(not ok0 and motivo0 == "bloqueado" and not recoge0 and motivoRecoge == "bloqueado" and ok1 and recoge1))
end

-- Grupos de colision: cada nivel de rebirth atraviesa sus barreras y no las
-- de mas arriba; las barreras horneadas llevan su grupo; el personaje cambia
-- de grupo al cambiar sus rebirths
function Pruebas.barreraColision()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = p.rebirths
	local function choca(a, b)
		return PhysicsService:CollisionGroupsAreCollidable(a, b)
	end
	local matriz = choca("Personaje", "BarreraR1") and choca("Personaje", "BarreraR2")
		and not choca("PersonajeR1", "BarreraR1") and choca("PersonajeR1", "BarreraR2")
		and not choca("PersonajeR2", "BarreraR1") and not choca("PersonajeR2", "BarreraR2")
		and not choca("Basura", "PersonajeR1") and choca("Basura", "BarreraR1")
	local barreras, malas = 0, 0
	for _, pared in CollectionService:GetTagged("BarreraCuadrante") do
		barreras += 1
		if pared.CollisionGroup ~= "BarreraR" .. tostring(pared:GetAttribute("Rebirth")) or not pared.CanCollide then
			malas += 1
		end
	end
	local grupos = {}
	for _, n in { 0, 1, 2, 3 } do
		p.rebirths = n
		Perfiles.marcarSucio(j)
		task.wait(0.4)
		local torso = j.Character and j.Character:FindFirstChild("HumanoidRootPart")
		table.insert(grupos, tostring(torso and torso.CollisionGroup))
	end
	p.rebirths = antes
	Perfiles.marcarSucio(j)
	local serie = table.concat(grupos, ",")
	return string.format("matriz=%s | %d paredes, %d mal agrupadas | personaje con 0..3 rebirths: %s => %s",
		tostring(matriz), barreras, malas, serie,
		ok(matriz and barreras > 0 and malas == 0 and serie == "Personaje,PersonajeR1,PersonajeR2,PersonajeR2" and Colisiones.grupoPersonaje(j) ~= nil))
end

-- De verdad: el personaje anda hacia el cuadrante de Metal. Con 0 rebirths
-- se queda en la pared; con 1 entra.
function Pruebas.caminarBarrera()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = p.rebirths
	local humanoide = j.Character and j.Character:FindFirstChildOfClass("Humanoid")
	local root = j.Character and j.Character:FindFirstChild("HumanoidRootPart")
	if not humanoide or not root then
		return "sin personaje => FALLO"
	end
	local function intentar(rebirths)
		p.rebirths = rebirths
		Perfiles.marcarSucio(j)
		task.wait(0.5)
		j.Character:PivotTo(CFrame.lookAt(Vector3.new(-50, 4, -18), Vector3.new(-50, 4, -60)))
		task.wait(0.3)
		humanoide:MoveTo(Vector3.new(-50, 1, -45))
		task.wait(3)
		return root.Position.Z
	end
	local z0 = intentar(0)
	local z1 = intentar(1)
	p.rebirths = antes
	Perfiles.marcarSucio(j)
	teletransportar(j, Comunes.fueraDelPatio())
	return string.format("pared sur del Metal en z=-25,6 | con 0 rebirths llega a z=%.1f | con 1 a z=%.1f => %s", z0, z1, ok(z0 > -26 and z1 < -40))
end

return Pruebas
