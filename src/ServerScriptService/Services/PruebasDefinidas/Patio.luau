--!nonstrict
--[[
	Pruebas del patio: montones, activacion, reclamo atomico, fisica de la
	basura, recogida solo por clic, variedad de basura y su color por tipo,
	EnPatio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local ModelosObjetos = require(Shared:WaitForChild("Utilidades"):WaitForChild("ModelosObjetos"))
local ModelosMonton = require(Shared:WaitForChild("Utilidades"):WaitForChild("ModelosMonton"))

local Servicios = script.Parent.Parent
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Botin = require(Servicios:WaitForChild("Botin"))
local Mundo = require(Servicios:WaitForChild("Mundo"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador, teletransportar = Comunes.jugador, Comunes.teletransportar

local Pruebas = {}

function Pruebas.montones()
	local lleno, activo, agotado = 0, 0, 0
	for _, m in Botin.montones() do
		if m.estado == "lleno" then lleno += 1 elseif m.estado == "activo" then activo += 1 else agotado += 1 end
	end
	local objetos = 0
	for _ in Botin.objetos() do
		objetos += 1
	end
	return string.format("montones: %d llenos, %d activos, %d agotados | objetos libres: %d", lleno, activo, agotado, objetos)
end

-- Excava el monton N (teletransportando al jugador al lado)
function Pruebas.excavar(indice)
	local j = jugador()
	-- Sin indice, el primer monton lleno de un cuadrante abierto (el 1 esta
	-- en la zona de metal, tras la barrera del Rebirth 1)
	local m = if indice then Botin.montones()[tonumber(indice) or 1] else Comunes.montonesLlenos(1)[1]
	assert(m, "no existe el monton")
	teletransportar(j, m.ranura.Position + Vector3.new(GameConfig.TAMANOS_MONTON[m.tamano].radio + 6, 0, 0))
	task.wait(0.2)
	local piezas = m.numPiezas
	local ok, motivo = Comunes.excavar(j, m)
	task.wait(1.4) -- toda la montana brota en 1 s
	local conteo = {}
	for _, obj in Botin.objetos() do
		if obj.monton == m then
			conteo[obj.item.tipo] = (conteo[obj.item.tipo] or 0) + 1
		end
	end
	local partes = {}
	for tipo, n in conteo do
		table.insert(partes, tipo .. "=" .. n)
	end
	table.sort(partes)
	local total = 0
	for _, n in conteo do
		total += n
	end
	return string.format("excavar monton %d (%s): ok=%s motivo=%s | piezas=%d objetos=%d (%s) | %s", m.id, m.tamano, tostring(ok), motivo, piezas, total, if piezas == total then "IGUAL OK" else "DIFERENTE", table.concat(partes, " "))
end

-- Reclama todos los objetos libres para el jugador
function Pruebas.reclamarTodo()
	local j = jugador()
	local ok, fallos = 0, {}
	task.wait(0.3)
	for id, obj in Botin.objetos() do
		local exito, motivo = Botin.reclamar(j, id, "toque")
		if exito then
			ok += 1
		else
			fallos[motivo] = (fallos[motivo] or 0) + 1
		end
	end
	local partes = {}
	for motivo, n in fallos do
		table.insert(partes, motivo .. "=" .. n)
	end
	return string.format("reclamados %d | fallos: %s | bolsa %d/%d", ok, table.concat(partes, " "), Bolsa.cuenta(j), Bolsa.capacidad(j))
end

-- Dos reclamantes sobre el mismo objeto: exactamente uno gana
function Pruebas.reclamoAtomico()
	local j = jugador()
	local m = Comunes.montonesLlenos(1)[1]
	teletransportar(j, m.ranura.Position + Vector3.new(GameConfig.TAMANOS_MONTON[m.tamano].radio + 6, 0, 0))
	task.wait(0.2)
	assert(Comunes.excavar(j, m))
	task.wait(0.3)
	local basuras = {}
	for id, obj in Botin.objetos() do
		if obj.monton == m and obj.item.tipo == "basura" then
			table.insert(basuras, id)
		end
	end
	assert(#basuras >= 2, "hacen falta 2 basuras, hay " .. #basuras)
	-- Sin la prioridad del excavador (la prueba "prioridadExcavador" la mira
	-- aparte): aqui solo cuenta quien llega primero
	m.activadoEn = os.clock() - GameConfig.PRIORIDAD_EXCAVADOR - 1
	local falso = { Name = "Falso", Parent = nil }
	-- Caso 1: el falso llega primero
	local ok1, mot1 = Botin.reclamar(falso, basuras[1], "toque")
	local ok2, mot2 = Botin.reclamar(j, basuras[1], "toque")
	-- Caso 2: el real llega primero
	local ok3, mot3 = Botin.reclamar(j, basuras[2], "toque")
	local ok4, mot4 = Botin.reclamar(falso, basuras[2], "toque")
	local correcto = ok1 and not ok2 and (mot2 == "yaReclamado" or mot2 == "noExiste") and ok3 and not ok4 and (mot4 == "yaReclamado" or mot4 == "noExiste")
	return string.format("caso1: falso=%s real=%s(%s) | caso2: real=%s falso=%s(%s) => %s", tostring(ok1), tostring(ok2), mot2, tostring(ok3), tostring(ok4), mot4, correcto and "ATOMICO OK" or "FALLO")
end

function Pruebas.repoblar()
	Botin.repoblarAhora()
	return Pruebas.montones()
end

local function primerMontonLleno()
	return Comunes.montonesLlenos(1)[1]
end

-- Apoyo de la basura de un monton: un objeto esta apoyado si su caja casi
-- toca el suelo o tiene otra caja debajo (solapada en planta). Devuelve
-- (sin apoyo, anclados, total, mas alto sobre el suelo, mas bajo).
local function apoyoBasura(m)
	local cajas = {}
	for _, obj in Botin.objetos() do
		if obj.monton == m and not obj.suelto and obj.modelo:IsA("Model") and obj.modelo.Parent then
			local cf, size = obj.modelo:GetBoundingBox()
			table.insert(cajas, { obj = obj, cf = cf, size = size, minY = cf.Position.Y - size.Y / 2, maxY = cf.Position.Y + size.Y / 2 })
		end
	end
	local suelo = m.ranura.Position.Y
	local sinApoyo, anclados, masAlto, masBajo = 0, 0, 0, math.huge
	for _, a in cajas do
		if a.obj.asentado then
			anclados += 1
		end
		masAlto = math.max(masAlto, a.maxY - suelo)
		masBajo = math.min(masBajo, a.minY - suelo)
		local apoyado = a.minY - suelo < 1.0
		if not apoyado then
			for _, b in cajas do
				if b ~= a then
					local dx = Vector3.new(a.cf.Position.X - b.cf.Position.X, 0, a.cf.Position.Z - b.cf.Position.Z).Magnitude
					if dx < (a.size.X + b.size.X) / 2 + 0.5 and b.maxY > a.minY - 1.0 and b.cf.Position.Y < a.cf.Position.Y then
						apoyado = true
						break
					end
				end
			end
		end
		if not apoyado then
			sinApoyo += 1
		end
	end
	return sinApoyo, anclados, #cajas, masAlto, masBajo
end

-- Grupos de colision: lo anclado choca con todos (Default), lo que cae va en
-- Basura (no choca con personajes). Devuelve cuantas piezas los tienen mal.
local function gruposMal(m)
	local mal = 0
	for _, obj in Botin.objetos() do
		if obj.monton == m and not obj.suelto and obj.modelo:IsA("Model") and obj.modelo.PrimaryPart then
			local p = obj.modelo.PrimaryPart
			local esperado = if p.Anchored then "Default" else "Basura"
			if p.CollisionGroup ~= esperado or not p.CanCollide then
				mal += 1
			end
		end
	end
	return mal
end

local function lomas(m)
	local n = 0
	for _, hijo in m.modelo:GetChildren() do
		if hijo:IsA("BasePart") and hijo.Name:match("^Loma_") then
			n += 1
		end
	end
	return n
end

-- Activa un monton con el jugador lejos y devuelve (monton, altura de la colina intacta)
local function activarLejos(j)
	local m = primerMontonLleno()
	local alturaAntes = m.params.h
	teletransportar(j, m.ranura.Position + Vector3.new(GameConfig.TAMANOS_MONTON[m.tamano].radio + 6, 0, 0))
	task.wait(0.2)
	local ok = Comunes.excavar(j, m)
	assert(ok, "no se pudo excavar")
	teletransportar(j, Comunes.fueraDelPatio())
	task.wait(1.6) -- toda la montana brota en 1 s
	return m, alturaAntes
end

-- Reclama por clic con el jugador al lado del objeto (vaciando la bolsa si se llena)
local function reclamarPorClic(j, obj)
	teletransportar(j, obj.modelo:GetPivot().Position + Vector3.new(2.5, 0, 0))
	local ok, motivo = Botin.reclamar(j, obj.id, "clic")
	if not ok and motivo == "bolsaLlena" then
		Bolsa.vaciar(j)
		ok, motivo = Botin.reclamar(j, obj.id, "clic")
	end
	return ok, motivo
end

-- La colina intacta es lisa (solo lomas); al activarla desaparece y en su
-- lugar caen tantos objetos REALES como numPiezas (mucha basura: min/max de
-- TAMANOS_MONTON), sin etiquetas, que se asientan con fisica (nada flota,
-- nada se cuela por el suelo) y se anclan; y nada caduca
function Pruebas.montonPiezas()
	local j = jugador()
	local m0 = primerMontonLleno()
	local lomasAntes, otros = lomas(m0), 0
	for _, hijo in m0.modelo:GetChildren() do
		if not hijo.Name:match("^Loma_") and (hijo:IsA("BasePart") or hijo:IsA("Model")) then
			otros += 1
		end
	end
	local def = GameConfig.TAMANOS_MONTON[m0.tamano]
	local m, alturaAntes = activarLejos(j)
	task.wait(5) -- que caiga y se asiente
	local objetos, enMontana, etiquetas, formas, basuras = 0, 0, 0, {}, 0
	for _, obj in Botin.objetos() do
		if obj.monton == m then
			objetos += 1
			if obj.modelo:IsDescendantOf(m.modelo) then
				enMontana += 1
			end
			if obj.modelo:FindFirstChild("Etiqueta", true) then
				etiquetas += 1
			end
			if obj.item.tipo == "basura" then
				basuras += 1
			end
			local forma = obj.modelo:GetAttribute("Forma")
			if forma then
				formas[forma] = true
			end
		end
	end
	local sinApoyo, anclados, total, masAlto, masBajo = apoyoBasura(m)
	local lomasDespues = lomas(m)
	local grupos = gruposMal(m)
	task.wait(2)
	local despues = 0
	for _, obj in Botin.objetos() do
		if obj.monton == m then
			despues += 1
		end
	end
	local nFormas = 0
	for _ in formas do
		nFormas += 1
	end
	return string.format("monton %d (%s): intacta lomas=%d otros=%d | numPiezas=%d (config %d-%d) objetos=%d (en la montana %d, basura %d, etiquetas %d, formas %d) | tras 5 s: sin apoyo %d, anclados %d/%d, alto %.1f (colina %.1f), bajo %.2f, lomas %d, grupos mal %d | tras 2 s mas siguen %d => %s",
		m.id, m.tamano, lomasAntes, otros, m.numPiezas, def.min, def.max, objetos, enMontana, basuras, etiquetas, nFormas, sinApoyo, anclados, total, masAlto, alturaAntes, masBajo, lomasDespues, grupos, despues,
		(lomasAntes >= 3 and otros == 0 and m.numPiezas >= def.min and m.numPiezas <= def.max and objetos == m.numPiezas and enMontana == objetos
			and etiquetas == 0 and nFormas >= 6 and sinApoyo <= math.ceil(total * 0.05) and anclados >= total * 0.85 and masBajo > -1.2
			and masAlto < alturaAntes + 3 and lomasDespues == 0 and grupos == 0 and despues == objetos) and "OK" or "FALLO")
end

-- Al recoger por clic piezas de ABAJO, las de encima caen (fisica) y se
-- vuelven a asentar: nada flota; al vaciarla aparece la marca plana (agotado)
function Pruebas.reacomodo()
	local j = jugador()
	local m = activarLejos(j)
	task.wait(4)
	local lista = {}
	for _, obj in Botin.objetos() do
		if obj.monton == m then
			table.insert(lista, obj)
		end
	end
	-- las mas bajas primero: son las que dejan a otras sin apoyo
	table.sort(lista, function(a, b)
		return a.modelo:GetPivot().Position.Y < b.modelo:GetPivot().Position.Y
	end)
	local _, _, _, altoAntes = apoyoBasura(m)
	local mitad = math.floor(#lista / 2)
	local recogidas = 0
	for i = 1, mitad do
		if reclamarPorClic(j, lista[i]) then
			recogidas += 1
		end
	end
	task.wait(0.6)
	local _, ancladosEnMedio, totalEnMedio = apoyoBasura(m) -- justo despues deberia haber piezas cayendo
	task.wait(5)
	local sinApoyo, anclados, total, altoDespues = apoyoBasura(m)
	for i = mitad + 1, #lista do
		reclamarPorClic(j, lista[i])
	end
	task.wait(0.5)
	local resto = m.modelo and m.modelo:FindFirstChild("Resto") ~= nil
	Bolsa.vaciar(j)
	return string.format("monton %d: recogidas %d/%d (las de abajo) | a 0,6 s: anclados %d/%d (cayendo) | a 5 s: sin apoyo %d, anclados %d/%d, alto %.1f -> %.1f | vaciado: estado=%s marca plana=%s => %s",
		m.id, recogidas, #lista, ancladosEnMedio, totalEnMedio, sinApoyo, anclados, total, altoAntes, altoDespues, m.estado, tostring(resto),
		(recogidas == mitad and ancladosEnMedio < totalEnMedio and sinApoyo <= math.ceil(total * 0.05) and anclados >= total * 0.9
			and altoDespues < altoAntes and m.estado == "agotado" and resto) and "OK" or "FALLO")
end

-- Nada se recoge por pasar al lado: solo el clic (o la mira en el movil)
function Pruebas.sinRecogidaAutomatica()
	local j = jugador()
	local m = activarLejos(j)
	local antes = 0
	local cercano = nil
	for _, obj in Botin.objetos() do
		if obj.monton == m then
			antes += 1
			cercano = cercano or obj
		end
	end
	-- pegado a un objeto
	teletransportar(j, cercano.modelo:GetPivot().Position + Vector3.new(1.5, 0, 0))
	task.wait(1.5)
	local trasEsperar = 0
	for _, obj in Botin.objetos() do
		if obj.monton == m then
			trasEsperar += 1
		end
	end
	-- el clic si
	local ok, motivo = Botin.reclamar(j, cercano.id, "clic")
	-- lejos, el clic no
	local lejano = nil
	for _, obj in Botin.objetos() do
		if obj.monton == m then
			lejano = obj
			break
		end
	end
	teletransportar(j, m.ranura.Position + Vector3.new(GameConfig.TAMANOS_MONTON[m.tamano].radio + 25, 0, 0))
	task.wait(0.2)
	local okLejos, motivoLejos = Botin.reclamar(j, lejano.id, "clic")
	Bolsa.vaciar(j)
	teletransportar(j, Comunes.fueraDelPatio())
	return string.format("1,5 s al lado: %d -> %d | clic cerca ok=%s (%s) | clic lejos ok=%s (%s) => %s",
		antes, trasEsperar, tostring(ok), motivo, tostring(okLejos), motivoLejos,
		(trasEsperar == antes and ok and not okLejos and motivoLejos == "lejos") and "OK" or "FALLO")
end

-- La basura tiene variedad de formas reales (latas, llantas, cajas, botellas...)
function Pruebas.variedadBasura()
	local rng = Random.new(7) -- fija: la prueba es reproducible
	local formas = {}
	local total = 0
	for _, material in { "Metal", "Plastico", "Papel", "Organico" } do
		for _ = 1, 40 do
			local m = ModelosObjetos.basura(material, rng)
			local forma = m:GetAttribute("Forma")
			if forma then
				formas[material .. ":" .. forma] = true
			end
			local extents = m:GetExtentsSize()
			local mayor = math.max(extents.X, extents.Y, extents.Z)
			assert(mayor >= 0.8 and mayor <= 4.5, material .. " " .. tostring(forma) .. " mide " .. mayor)
			total += 1
			m:Destroy()
		end
	end
	local lista = {}
	for k in formas do
		table.insert(lista, k)
	end
	table.sort(lista)
	return string.format("%d modelos, %d formas distintas: %s => %s", total, #lista, table.concat(lista, ", "), (#lista >= 14) and "OK" or "FALLO")
end

-- La basura es del color de su tipo (3 oct): el cuerpo de cada pieza esta
-- mas cerca de los tonos de SU tipo que de los de cualquier otro, y sin
-- textura de paleta (taparia el color)
function Pruebas.coloresBasura()
	local rng = Random.new(11)
	local function distancia(a: Color3, b: Color3): number
		return (a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2
	end
	local function tipoMasCercano(color: Color3): string
		local mejor, dMejor = "", math.huge
		for tipo, tonos in Paleta.BASURA do
			for _, tono in tonos do
				local d = distancia(color, tono)
				if d < dMejor then
					mejor, dMejor = tipo, d
				end
			end
		end
		return mejor
	end
	local mal, conTextura, total = {}, 0, 0
	for _, material in { "Metal", "Plastico", "Papel", "Organico" } do
		for _ = 1, 40 do
			local m = ModelosObjetos.basura(material, rng)
			local cuerpo = m.PrimaryPart
			if cuerpo then
				total += 1
				if cuerpo:IsA("MeshPart") and cuerpo.TextureID ~= "" then
					conTextura += 1
				end
				local cercano = tipoMasCercano(cuerpo.Color)
				if cercano ~= material then
					table.insert(mal, string.format("%s:%s parece %s", material, tostring(m:GetAttribute("Forma")), cercano))
				end
			end
			m:Destroy()
		end
	end
	return string.format("%d piezas | con textura %d | de otro color %d [%s] => %s",
		total, conTextura, #mal, table.concat(mal, ", ", 1, math.min(#mal, 6)), (total >= 160 and conTextura == 0 and #mal == 0) and "OK" or "FALLO")
end

-- Depuracion: lista lo que queda en el monton i con su apoyo sobre la colina
function Pruebas.verMonton(indice)
	local m = Botin.montones()[tonumber(indice) or 1]
	assert(m, "no existe el monton")
	local restantes = {}
	for _, obj in Botin.objetos() do
		if obj.monton == m then
			local pos = obj.modelo:GetPivot().Position - m.ranura.Position
			local superficie = ModelosMonton.alturaColina(m.params, pos.X, pos.Z)
			table.insert(restantes, string.format("%s y=%.1f (sup %.1f) r=%.1f%s", obj.modelo.Name, pos.Y, superficie,
				Vector3.new(pos.X, 0, pos.Z).Magnitude, obj.suelto and " SUELTO" or ""))
		end
	end
	table.sort(restantes)
	return string.format("monton %d (%s): estado=%s r=%.1f h=%.1f quedan %d: %s", m.id, m.tamano, m.estado, m.params.r, m.params.h, #restantes, table.concat(restantes, " | "))
end

-- Entrar y salir del patio: atributo EnPatio, bolsa abierta en las manos y la
-- pose de brazos tambien en el servidor (Transform del hombro)
function Pruebas.enPatio()
	local j = jugador()
	-- Sobre el camino entre las dos columnas de cuadrantes (x = -26,25): el
	-- resto del patio esta lleno de montones
	teletransportar(j, Vector3.new(-26.25, 0, 0))
	task.wait(0.6)
	local dentro = j:GetAttribute("EnPatio")
	local ch = j.Character
	local bolsa = ch and ch:FindFirstChild("BolsaEnManos")
	local abierta = bolsa and bolsa:FindFirstChild("Boca") ~= nil
	local hombro = ch and ch:FindFirstChild("RightUpperArm") and ch.RightUpperArm:FindFirstChild("RightShoulder")
	local elevado = false
	if hombro then
		local _, _, _, _, _, _, _, r11 = hombro.Transform:GetComponents()
		elevado = r11 < 0.5 -- cos(70) = 0.34; en reposo seria ~1
	end
	-- la bolsa esta delante del torso, entre las manos, no a un lado
	local delante = false
	if bolsa and ch then
		local torso = ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")
		local l = torso.CFrame:PointToObjectSpace(bolsa:GetPivot().Position)
		delante = math.abs(l.X) < 0.5 and l.Z < -1.5
	end
	teletransportar(j, Comunes.fueraDelPatio())
	task.wait(0.6)
	local fuera = j:GetAttribute("EnPatio")
	local bolsaFuera = ch and ch:FindFirstChild("BolsaEnManos") ~= nil
	return string.format("dentro: EnPatio=%s bolsa=%s abierta=%s delante=%s brazoElevado=%s | fuera: EnPatio=%s bolsa=%s => %s",
		tostring(dentro), tostring(bolsa ~= nil), tostring(abierta), tostring(delante), tostring(elevado), tostring(fuera), tostring(bolsaFuera),
		(dentro == true and bolsa and abierta and delante and elevado and fuera == false and not bolsaFuera) and "OK" or "FALLO")
end

-- La bolsa en las manos: abierta (Boca) mientras cabe algo; llena, cerrada
-- con su nudo (Nudo, sin Boca), como el dibujo de primera persona
function Pruebas.bolsaManosLlena()
	local j = jugador()
	teletransportar(j, Vector3.new(-26.25, 0, 0))
	Bolsa.vaciar(j)
	task.wait(0.6)
	local ch = j.Character
	local vacia = ch and ch:FindFirstChild("BolsaEnManos")
	local abiertaVacia = vacia and vacia:FindFirstChild("Boca") ~= nil
	for _ = 1, Bolsa.capacidad(j) do
		Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 1 })
	end
	task.wait(0.6)
	local llena = ch and ch:FindFirstChild("BolsaEnManos")
	local cerrada = llena and llena:FindFirstChild("Nudo") ~= nil and llena:FindFirstChild("Boca") == nil
	local hijos = {}
	for _, c in (llena and llena:GetChildren() or {}) do
		table.insert(hijos, c.Name)
	end
	Bolsa.vaciar(j)
	teletransportar(j, Comunes.fueraDelPatio())
	return string.format("vacia: abierta=%s | llena (%d/%d): cerrada=%s hijos=%s => %s",
		tostring(abiertaVacia), Bolsa.capacidad(j), Bolsa.capacidad(j), tostring(cerrada), table.concat(hijos, ","),
		(abiertaVacia and cerrada) and "OK" or "FALLO")
end

-- ===========================================================================
-- Limites de rendimiento: 1 monton a medias por jugador y tope del patio
-- ===========================================================================

local montonesLlenos = Comunes.montonesLlenos

local function objetosEnPatio()
	local total = 0
	for _, m in Botin.montones() do
		if m.estado == "activo" then
			total += m.objetosVivos
		end
	end
	return total
end

-- Excava de verdad (con limites) al lado del monton; el tope del patio se
-- sube salvo que se pida lo contrario, para no depender de pruebas previas
local function excavarJunto(j, m, conTope)
	teletransportar(j, m.ranura.Position + Vector3.new(GameConfig.TAMANOS_MONTON[m.tamano].radio + 6, 0, 0))
	task.wait(0.2)
	local tope = GameConfig.MAX_OBJETOS_PATIO
	if not conTope then
		GameConfig.MAX_OBJETOS_PATIO = math.huge
	end
	local ok, motivo = Botin.excavar(j, m)
	GameConfig.MAX_OBJETOS_PATIO = tope
	return ok, motivo
end

-- Segundo monton sin terminar el primero: "yaTienesUno"; al recoger el 75 %
-- del primero ya se puede
function Pruebas.limiteJugador()
	local j = jugador()
	Botin.liberarMontones(j)
	local llenos = montonesLlenos(2)
	local m1, m2 = llenos[1], llenos[2]
	local ok1 = excavarJunto(j, m1)
	task.wait(1.6)
	local ok2, mot2 = excavarJunto(j, m2)
	-- Recoge hasta dejar menos del 25 %
	local limite = math.floor(m1.objetosIniciales * GameConfig.FRACCION_MONTON_DISPONIBLE)
	for id, obj in Botin.objetos() do
		if m1.objetosVivos < limite then
			break
		end
		if obj.monton == m1 then
			if Bolsa.estaLlena(j) then
				Bolsa.vaciar(j)
			end
			Botin.reclamar(j, id, "toque")
		end
	end
	local activos = Botin.montonesActivosDe(j)
	local ok3, mot3 = excavarJunto(j, m2)
	Bolsa.vaciar(j)
	return string.format("1o=%s | 2o=%s(%s) | tras recoger quedan %d/%d, activos=%d | 2o otra vez=%s(%s) => %s",
		tostring(ok1), tostring(ok2), tostring(mot2), m1.objetosVivos, m1.objetosIniciales, activos, tostring(ok3), tostring(mot3),
		(ok1 and not ok2 and mot2 == "yaTienesUno" and activos == 0 and ok3) and "OK" or "FALLO")
end

-- Con el patio al tope no se abre nada
function Pruebas.topePatio()
	local j = jugador()
	Botin.liberarMontones(j)
	local m = montonesLlenos(1)[1]
	local tope = GameConfig.MAX_OBJETOS_PATIO
	GameConfig.MAX_OBJETOS_PATIO = objetosEnPatio() + m.numPiezas - 1
	local ok, motivo = excavarJunto(j, m, true)
	GameConfig.MAX_OBJETOS_PATIO = tope
	return string.format("excavar con el patio lleno: ok=%s motivo=%s estado=%s => %s",
		tostring(ok), tostring(motivo), m.estado,
		(not ok and motivo == "patioLleno" and m.estado == "lleno") and "OK" or "FALLO")
end

return Pruebas
