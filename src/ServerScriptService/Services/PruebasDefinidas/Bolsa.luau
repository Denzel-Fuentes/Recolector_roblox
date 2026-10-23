--!nonstrict
--[[
	Pruebas de la bolsa: deposito de cerca, que recoger nunca paga (billetes
	incluidos), la bolsa al desconectar, la punteria (lanzar la bolsa,
	acierto, fallo y bolsa protegida) y los cinco contenedores (premio por
	separar, y que la bolsa entra en el contenedor al que se apunta).

	Desde el 22 oct (P3) el servidor solo lanza bolsas llenas: las que lanzan
	llenan la bolsa con Comunes.llenarBolsa y cuentan con su capacidad, y
	quitan antes las bolsas caidas que dejaran otras pruebas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local Rebirths = require(script.Parent.Parent:WaitForChild("Rebirths"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Botin = require(Servicios:WaitForChild("Botin"))
local Mundo = require(Servicios:WaitForChild("Mundo"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador, teletransportar = Comunes.jugador, Comunes.teletransportar

local Pruebas = {}

-- Lo que deberia pagar el contenedor por la bolsa actual (sin bonus)
local function valorEsperado(j)
	local total = 0
	for _, item in Bolsa.contenido(j) do
		total += Bolsa.valorDeposito(j, item)
	end
	return total
end

function Pruebas.depositar()
	local j = jugador()
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, 6))
	local dineroAntes = Economia.dinero(j)
	local resumen = Bolsa.depositar(j)
	if not resumen then
		return "bolsa vacia"
	end
	return string.format("deposito: %d objetos, +$%d (bonus=%s) | dinero %d->%d", resumen.objetos, resumen.dinero, tostring(resumen.bonus), dineroAntes, Economia.dinero(j))
end

-- Un billete ocupa un hueco y NO paga al meterlo: paga al depositar
function Pruebas.billeteEnBolsa()
	local j = jugador()
	Bolsa.vaciar(j)
	local dineroAntes = Economia.dinero(j)
	local metido = Bolsa.meter(j, { tipo = "billete", nombre = "Billete", valor = 50 })
	local cuenta = Bolsa.cuenta(j)
	local dineroTrasMeter = Economia.dinero(j)
	local resumen = Bolsa.depositar(j)
	return string.format("billete $50: metido=%s bolsa=%d dinero al meter %d->%d | deposito objetos=%d +$%d => %s",
		tostring(metido), cuenta, dineroAntes, dineroTrasMeter, resumen.objetos, resumen.dinero,
		(metido and cuenta == 1 and dineroTrasMeter == dineroAntes and resumen.objetos == 1 and resumen.dinero == 50) and "OK" or "FALLO")
end

-- Recoger de una montana (lo que sea que salga) no cambia el dinero
function Pruebas.sinDineroAlRecoger()
	local j = jugador()
	Bolsa.vaciar(j)
	local m = Comunes.montonesLlenos(1)[1]
	teletransportar(j, m.ranura.Position + Vector3.new(6, 0, 0))
	task.wait(0.3)
	local excavado, motivo = Comunes.excavar(j, m)
	assert(excavado, "no se pudo excavar: " .. tostring(motivo))
	task.wait(1.6)
	local dineroAntes = Economia.dinero(j)
	local recogidos, tipos = 0, {}
	for id, obj in Botin.objetos() do
		if obj.monton == m and not Bolsa.estaLlena(j) then
			local ok = Botin.reclamar(j, id, "toque")
			if ok then
				recogidos += 1
				tipos[obj.item.tipo] = (tipos[obj.item.tipo] or 0) + 1
			end
		end
	end
	local partes = {}
	for tipo, n in tipos do
		table.insert(partes, tipo .. "=" .. n)
	end
	table.sort(partes)
	local dineroDespues = Economia.dinero(j)
	local cuenta = Bolsa.cuenta(j)
	Bolsa.vaciar(j)
	return string.format("recogidos %d (%s) bolsa %d/%d | dinero %d->%d => %s", recogidos, table.concat(partes, " "), cuenta, Bolsa.capacidad(j), dineroAntes, dineroDespues,
		(recogidos > 0 and cuenta == recogidos and dineroDespues == dineroAntes) and "OK" or "FALLO")
end

-- Simula un jugador que sale con la bolsa a medias: se recicla sin bonus (se
-- comprueba a mano desconectando; la prueba "salirRecicla" lo comprueba sin
-- salir)
function Pruebas.bolsaAlSalir()
	local j = jugador()
	Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 })
	Bolsa.meter(j, { tipo = "billete", nombre = "Billete", valor = 50 })
	return "bolsa " .. Bolsa.cuenta(j) .. "/" .. Bolsa.capacidad(j) .. " (al desconectar: $56 sin bonus)"
end

-- Al salir la bolsa se recicla sin bonus (se llama a lo mismo que PlayerRemoving)
function Pruebas.salirRecicla()
	local j = jugador()
	local items = {
		{ tipo = "basura", nombre = "Chatarra", material = "Metal", valor = 12 },
		{ tipo = "billete", nombre = "Billete", valor = 50 },
	}
	local esperado = 0
	for _, item in items do
		esperado += Bolsa.valorDeposito(j, item)
	end
	local antes = Economia.dinero(j)
	local resumen = Bolsa.reciclarSinBonus(j, items)
	local cobrado = Economia.dinero(j) - antes
	return string.format("esperado $%d, resumen $%d, cobrado $%d => %s", esperado, resumen.dinero, cobrado, (resumen.dinero == esperado and cobrado == esperado) and "OK" or "FALLO")
end

-- Premio por separar (3 oct): en el contenedor de Papel, 4 papeles pagan x2,
-- 2 plasticos x0,5 y un billete x1; en el general, todo x1
function Pruebas.pagoSeparado()
	local j = jugador()
	local function bolsa()
		local items = {}
		for _ = 1, 4 do
			table.insert(items, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 10 })
		end
		for _ = 1, 2 do
			table.insert(items, { tipo = "basura", nombre = "Plastico", material = "Plastico", valor = 10 })
		end
		table.insert(items, { tipo = "billete", nombre = "Billete", material = "Papel", valor = 50 })
		return items
	end
	local mult = Rebirths.multiplicador(j)
	local enPapel = Bolsa.depositarItems(j, bolsa(), 0, "Papel")
	local enGeneral = Bolsa.depositarItems(j, bolsa(), 0, nil)
	local esperadoPapel = math.floor((4 * 10 * GameConfig.MULT_SEPARADO + 2 * 10 * GameConfig.MULT_MAL_SEPARADO + 50) * mult + 0.5)
	local esperadoGeneral = math.floor((60 + 50) * mult + 0.5)
	return string.format("papel: $%d (esperado %d) bien %d mal %d | general: $%d (esperado %d) bien %d mal %d => %s",
		enPapel.dinero, esperadoPapel, enPapel.separadas, enPapel.malSeparadas,
		enGeneral.dinero, esperadoGeneral, enGeneral.separadas, enGeneral.malSeparadas,
		(enPapel.dinero == esperadoPapel and enPapel.separadas == 4 and enPapel.malSeparadas == 2 and enPapel.contenedor == "Papel"
			and enGeneral.dinero == esperadoGeneral and enGeneral.separadas == 0 and enGeneral.malSeparadas == 0 and enGeneral.contenedor == "General")
			and "OK" or "FALLO")
end

-- Ejecuta fn con los rebirths del perfil puestos a n y los restaura: los
-- contenedores de metal y organico solo aceptan la bolsa con sus rebirths
-- (Bolsa.contenedorAbierto)
local function conRebirths(j, n, fn)
	local p = Perfiles.obtener(j)
	local antes = p.rebirths
	p.rebirths = n
	local ok, resultado = pcall(fn)
	p.rebirths = antes
	if not ok then
		error(resultado)
	end
	return resultado
end

-- Lanza la bolsa (llena de piezas de `material`) a la boca del contenedor de
-- `material` desde 20 studs por delante; devuelve el resumen si entro (nil
-- si no) y si se lanzo
local function lanzarAlContenedor(j, material: string?)
	local c = Mundo.contenedorDe(material)
	if not c then
		return nil, false
	end
	local ultimo = nil
	local conexion = Bolsa.alResumen:Connect(function(quien, resumen)
		if quien == j then
			ultimo = resumen
		end
	end)
	teletransportar(j, c.zona.Position + Vector3.new(0, 0, -20))
	task.wait(0.3)
	local tipo = material or "Metal"
	Comunes.llenarBolsa(j, { tipo = "basura", nombre = tipo, material = tipo, valor = 10 })
	local ok = Botin.lanzarBolsa(j, c.zona.Position, 1)
	local limite = os.clock() + 4
	while not ultimo and os.clock() < limite do
		task.wait(0.1)
	end
	conexion:Disconnect()
	return ultimo, ok
end

-- El contenedor de un tipo que el jugador aun no tiene abierto no acepta la
-- bolsa: lanzada rebota (fallo, queda en el suelo) y a mano se rechaza
-- ("bloqueado"). Con el rebirth que lo abre, entra.
function Pruebas.contenedorBloqueado()
	local j = jugador()
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local cerrado, lanzoCerrado, aMano, motivoMano, abierto, lanzoAbierto, enSuelo
	conRebirths(j, 0, function()
		cerrado, lanzoCerrado = lanzarAlContenedor(j, "Metal")
		task.wait(0.8)
		-- La bolsa rebotada queda en el suelo: se recoge para no dejar restos
		for id, obj in Botin.objetos() do
			if obj.item.tipo == "bolsa" and obj.item.duenoId == j.UserId then
				enSuelo = true
				Botin.reclamar(j, id, "toque")
			end
		end
		Bolsa.vaciar(j)
		Bolsa.meter(j, { tipo = "basura", nombre = "Metal", material = "Metal", valor = 10 })
		aMano, motivoMano = Bolsa.depositar(j, "Metal")
		Bolsa.vaciar(j)
	end)
	conRebirths(j, 1, function()
		abierto, lanzoAbierto = lanzarAlContenedor(j, "Metal")
	end)
	Bolsa.vaciar(j)
	return string.format("R0: lanzo=%s entro=%s en el suelo=%s | a mano: %s (%s) | R1: lanzo=%s entro en %s => %s",
		tostring(lanzoCerrado), tostring(cerrado ~= nil), tostring(enSuelo == true), tostring(aMano ~= nil), tostring(motivoMano),
		tostring(lanzoAbierto), if abierto then abierto.contenedor else "ninguno",
		(lanzoCerrado and cerrado == nil and enSuelo and aMano == nil and motivoMano == "bloqueado" and lanzoAbierto and abierto and abierto.contenedor == "Metal") and "OK" or "FALLO")
end

-- Lanzar a cada uno de los cinco desde 20 studs por delante: la bolsa entra
-- en ESE (no en el vecino) y su tipo paga x2. Con 2 rebirths: todos abiertos.
-- Desde 20 studs al centro de la boca (4,5 x 3,5 en los de tipo) la bolsa
-- cruza el borde 0,4 studs dentro: hasta el 22 oct el vuelo del servidor la
-- dejaba caer mas baja que el arco segun los fps y daba en la pared de
-- delante (pasaba 2 de cada 6; ver la cabecera de Lanzamiento)
local function lanzarATipoCon(j)
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local ultimo = nil
	local conexion = Bolsa.alResumen:Connect(function(quien, resumen)
		if quien == j then
			ultimo = resumen
		end
	end)
	local partes, bien = {}, true
	for _, material in { "Papel", "Plastico", "Metal", "Organico", "General" } do
		local c = Mundo.contenedorDe(if material == "General" then nil else material)
		if not c then
			table.insert(partes, material .. ": no existe")
			bien = false
			continue
		end
		teletransportar(j, c.zona.Position + Vector3.new(0, 0, -20))
		task.wait(0.3)
		local tipoBasura = if material == "General" then "Metal" else material
		local n = Comunes.llenarBolsa(j, { tipo = "basura", nombre = tipoBasura, material = tipoBasura, valor = 10 })
		ultimo = nil
		local ok = Botin.lanzarBolsa(j, c.zona.Position, 1)
		local limite = os.clock() + 4
		while not ultimo and os.clock() < limite do
			task.wait(0.1)
		end
		local entro = ultimo ~= nil and ultimo.contenedor == material
		local separadas = if ultimo then ultimo.separadas else -1
		local esperadas = if material == "General" then 0 else n
		bien = bien and ok and entro and separadas == esperadas
		local donde = ""
		if not ultimo then
			-- Si no entro, donde quedo (para ver si fue la pared de delante)
			task.wait(0.5)
			for _, obj in Botin.objetos() do
				if obj.item.tipo == "bolsa" and obj.item.duenoId == j.UserId then
					local p = obj.modelo:GetPivot().Position
					donde = string.format(" (cayo en x=%.1f z=%.1f)", p.X, p.Z)
				end
			end
		end
		table.insert(partes, string.format("%s: entro en %s, %d/%d bien%s", material, if ultimo then ultimo.contenedor else "ninguno", separadas, esperadas, donde))
		task.wait(0.6)
	end
	conexion:Disconnect()
	Bolsa.vaciar(j)
	return table.concat(partes, " | ") .. " => " .. (bien and "OK" or "FALLO")
end

function Pruebas.lanzarATipo()
	local j = jugador()
	return conRebirths(j, 2, function()
		return lanzarATipoCon(j)
	end)
end

-- Lanzar la bolsa entera a la zona de acierto desde 21 studs, desde el
-- frente (al norte, -Z): detras esta la trituradora, que ya colisiona. A 21
-- y no a 20 (23 oct): 20 es justo el borde del tramo de +40 % y al posarse
-- tras el teletransporte el personaje a veces lanzaba desde 19,99 (+20 %)
function Pruebas.lanzarBolsa()
	local j = jugador()
	Comunes.yaLanzo(j)
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, -21))
	task.wait(0.3)
	local n = Comunes.llenarBolsa(j, { tipo = "basura", nombre = "Chatarra", material = "Metal", valor = 12 })
	-- n chatarras x12 x(1 + 0,4 desde 20-29 studs + la racha, al menos 0,1)
	local minimo = math.floor(n * 12 * 1.5)
	local dineroAntes = Economia.dinero(j)
	local aciertosAntes = Perfiles.leerEstadistica(j, "aciertos")
	local ok, motivo = Botin.lanzarBolsa(j, zona.Position, 1)
	local vacia = Bolsa.cuenta(j) == 0
	task.wait(2.5)
	local aciertos = Perfiles.leerEstadistica(j, "aciertos")
	return string.format("lanzarBolsa ok=%s (%s) bolsa (llena, %d) vacia al lanzar=%s aciertos %d->%d dinero %d->%d (%d chatarras x12 x(1 + 0,4 desde 21 studs + racha) >= %d) => %s",
		tostring(ok), motivo, n, tostring(vacia), aciertosAntes, aciertos, dineroAntes, Economia.dinero(j), n, minimo,
		(ok and vacia and aciertos > aciertosAntes and Economia.dinero(j) - dineroAntes >= minimo) and "OK" or "FALLO")
end

-- Lanzar al suelo: la bolsa cae como objeto y su dueno la recoge (que otro
-- no pueda lo comprueba "bolsaProtegida"). Con el Brazo a nivel 0 (25 studs)
-- y media fuerza, la bolsa cae a ~12 studs, hacia el patio.
function Pruebas.lanzarBolsaFallo()
	local j = jugador()
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local zona = Mundo.zonaAcierto()
	-- El contenedor esta al sur del patio (plano v3): el jugador se pone al
	-- norte, en la plaza, y apunta hacia el patio, lejos del contenedor
	teletransportar(j, zona.Position + Vector3.new(0, 0, -30))
	task.wait(0.3)
	-- Un billete y el resto papel
	local n = Comunes.llenarBolsa(j, function(i)
		return if i == 1
			then { tipo = "billete", nombre = "Billete", valor = 50 }
			else { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 }
	end)
	-- apuntar lejos del contenedor, hacia el patio
	local ok, motivo = Botin.lanzarBolsa(j, zona.Position + Vector3.new(-25, 0, -80), 0.5)
	task.wait(3)
	local bolsaId = nil
	for id, obj in Botin.objetos() do
		if obj.item.tipo == "bolsa" then
			bolsaId = id
		end
	end
	local recogida, motivoRec = false, "sinBolsa"
	if bolsaId then
		recogida, motivoRec = Botin.reclamar(j, bolsaId, "toque")
	end
	local cuenta = Bolsa.cuenta(j)
	Bolsa.vaciar(j)
	return string.format("lanzar ok=%s (%s) | bolsa en el suelo=%s | recogida=%s (%s) | bolsa ahora %d/%d (lanzada con %d) => %s",
		tostring(ok), motivo, tostring(bolsaId ~= nil), tostring(recogida), motivoRec, cuenta, Bolsa.capacidad(j), n,
		(ok and bolsaId and recogida and cuenta == n) and "OK" or "FALLO")
end

-- La bolsa que falla solo la recoge su dueno durante BOLSA_LIBRE_SEGUNDOS
-- (30 s), y no se recicla sola: a los 21 s sigue en el suelo y el dueno la
-- recupera (ver bolsaLibre para lo que pasa despues de los 30 s)
function Pruebas.bolsaProtegida()
	local j = jugador()
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, -30))
	task.wait(0.3)
	local n = Comunes.llenarBolsa(j)
	local lanzo = Botin.lanzarBolsa(j, zona.Position + Vector3.new(-25, 0, -80), 0.5)
	-- vuelo + botes (hasta VIDA_PROYECTIL)
	task.wait(3.2)
	local obj = nil
	for _, o in Botin.objetos() do
		if o.item.tipo == "bolsa" and o.item.duenoId == j.UserId then
			obj = o
		end
	end
	if not obj then
		return "no quedo bolsa en el suelo => FALLO"
	end
	-- Otro jugador (simulado cambiando el dueno) no puede recogerla
	obj.item.duenoId = -1
	local recogidaAjena, motivo = Botin.reclamar(j, obj.id, "toque")
	obj.item.duenoId = j.UserId
	local dineroAntes = Economia.dinero(j)
	task.wait(21)
	local sigueEnElSuelo = Botin.objetos()[obj.id] ~= nil
	local cobrado = Economia.dinero(j) - dineroAntes
	-- Y su dueno la recupera
	local recogida = Botin.reclamar(j, obj.id, "toque")
	local enLaBolsa = Bolsa.cuenta(j)
	Bolsa.vaciar(j)
	return string.format("lanzo=%s | ajena: recogida=%s (%s) | a los 21 s: sigue=%s cobrado=$%d | el dueno la recoge=%s (%d/%d en la bolsa) => %s",
		tostring(lanzo), tostring(recogidaAjena), tostring(motivo), tostring(sigueEnElSuelo), cobrado, tostring(recogida), enLaBolsa, n,
		(lanzo and not recogidaAjena and motivo == "ajena" and sigueEnElSuelo and cobrado == 0 and recogida and enLaBolsa == n) and "OK" or "FALLO")
end

-- Pasados BOLSA_LIBRE_SEGUNDOS desde que se posa, la bolsa fallada la recoge
-- cualquiera y se queda lo que lleva. El atributo LibreEn (la cuenta atras
-- del cliente) va unos 30 s por delante al posarse. El paso del tiempo se
-- simula moviendo libreEn al pasado; el otro jugador, cambiando el dueno.
function Pruebas.bolsaLibre()
	local j = jugador()
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, -30))
	task.wait(0.3)
	-- Papel y metal alternados
	local n = Comunes.llenarBolsa(j, function(i)
		return if i % 2 == 1
			then { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 }
			else { tipo = "basura", nombre = "Metal", material = "Metal", valor = 15 }
	end)
	local lanzo = Botin.lanzarBolsa(j, zona.Position + Vector3.new(-25, 0, -80), 0.5)
	task.wait(3.2)
	local obj = nil
	for _, o in Botin.objetos() do
		if o.item.tipo == "bolsa" and o.item.duenoId == j.UserId then
			obj = o
		end
	end
	if not obj then
		return "no quedo bolsa en el suelo => FALLO"
	end
	local adelanto = (obj.modelo:GetAttribute("LibreEn") or 0) - workspace:GetServerTimeNow()
	local atributoOk = math.abs(adelanto - GameConfig.BOLSA_LIBRE_SEGUNDOS) < 3
	-- Otro jugador antes de tiempo: no
	obj.item.duenoId = -1
	local antes, motivoAntes = Botin.reclamar(j, obj.id, "toque")
	-- Pasado el tiempo: si, y se queda el contenido
	obj.item.libreEn = workspace:GetServerTimeNow() - 1
	local despues, motivoDespues = Botin.reclamar(j, obj.id, "toque")
	local enLaBolsa = Bolsa.cuenta(j)
	Bolsa.vaciar(j)
	return string.format("lanzo=%s | LibreEn a %.1f s (ok=%s) | ajena antes: %s (%s) | ajena despues: %s (%s), %d/%d en la bolsa => %s",
		tostring(lanzo), adelanto, tostring(atributoOk), tostring(antes), tostring(motivoAntes), tostring(despues), tostring(motivoDespues), enLaBolsa, n,
		(lanzo and atributoOk and not antes and motivoAntes == "ajena" and despues and enLaBolsa == n) and "OK" or "FALLO")
end

-- La recicladora del general (sin atributo Material): desde el 5 oct cada
-- contenedor de tipo lleva tambien la suya, escalada
local function recicladoraGeneral(): Model?
	for _, m in game:GetService("CollectionService"):GetTagged("RecicladoraArte") do
		if m:IsA("Model") and m:GetAttribute("Material") == nil then
			return m
		end
	end
	return nil
end

-- La bolsa lanzada choca con la recicladora: desde delante de la caja de
-- salida se apunta a la parte baja de su frente (z = -3,95 en el marco del
-- pivote; apuntando a su centro el tiro cae sobre el techo); debe rebotar y
-- quedar en el suelo delante, no dentro de ninguna caja de ColisionRecicladora
function Pruebas.lanzarContraRecicladora()
	local j = jugador()
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local rec = recicladoraGeneral()
	local caseta = rec and rec.Parent
	local colision = caseta and caseta:FindFirstChild("ColisionRecicladora")
	if not colision then
		return "sin recicladora o sin ColisionRecicladora => FALLO"
	end
	local pivote = rec:GetPivot()
	teletransportar(j, pivote:PointToWorldSpace(Vector3.new(9.4, 3, 14)))
	task.wait(0.3)
	Comunes.llenarBolsa(j)
	local ok, motivo = Botin.lanzarBolsa(j, pivote:PointToWorldSpace(Vector3.new(9.4, 2, -3.9)), 1)
	task.wait(4.5)
	local bolsaId, pos = nil, nil
	for id, obj in Botin.objetos() do
		if obj.item.tipo == "bolsa" and obj.modelo then
			bolsaId, pos = id, obj.modelo:GetPivot().Position
		end
	end
	if not pos then
		return string.format("lanzar ok=%s (%s) | no quedo bolsa en el suelo => FALLO", tostring(ok), motivo)
	end
	local dentro = nil
	for _, p in colision:GetChildren() do
		local l = p.CFrame:PointToObjectSpace(pos + Vector3.new(0, 0.5, 0))
		if math.abs(l.X) < p.Size.X / 2 and math.abs(l.Y) < p.Size.Y / 2 and math.abs(l.Z) < p.Size.Z / 2 then
			dentro = p.Name
		end
	end
	local local_ = pivote:PointToObjectSpace(pos)
	if bolsaId then
		Botin.reclamar(j, bolsaId, "toque")
	end
	return string.format("lanzar ok=%s (%s) | bolsa en local (%.1f, %.1f, %.1f) dentro de=%s => %s",
		tostring(ok), motivo, local_.X, local_.Y, local_.Z, tostring(dentro),
		(ok and dentro == nil and local_.Z > -3.9) and "OK" or "FALLO")
end

-- Una bolsa fallada que quedaria en alto se baja al suelo junto al
-- contenedor: ya no se recicla sola, asi que ahi arriba se perderia. Se
-- apunta al techo de la Carcasa de la recicladora general (la caja de
-- colision del lado oeste, techo a y = 10,7 con el mundo v6), un stud dentro
-- de su borde delantero, desde 18 studs por delante y a su altura en x: el
-- tiro pasa al oeste del volquete (no puede entrar en el) y la bolsa, que
-- llega a ~21 studs/s, se para con los botes antes del borde de atras
-- (5,7 de fondo). Todo se mide en el marco de la Carcasa, asi que vale aunque
-- se mueva la recicladora entera. Hasta el 22 oct el objetivo estaba medido
-- a mano (29 sep) y desde que la recicladora general se movio a la caseta
-- (5 oct) la bolsa ya no caia en alto: la prueba pasaba sin probar nada.
-- Ahora exige que de verdad cayera en alto (atributo BajadaDesde).
function Pruebas.bolsaEnAlto(fuerza)
	local j = jugador()
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local rec = recicladoraGeneral()
	local colision = rec and rec.Parent and rec.Parent:FindFirstChild("ColisionRecicladora")
	local carcasa = colision and colision:FindFirstChild("Carcasa")
	if not carcasa or not carcasa:IsA("BasePart") then
		return "sin recicladora o sin ColisionRecicladora.Carcasa => FALLO"
	end
	local cf, tamano = carcasa.CFrame, carcasa.Size
	-- El frente de la Carcasa es la cara que mira al jugador (la plaza): la
	-- +Z local o la -Z, la que este mas al norte (-Z del mundo)
	local frente = if cf:VectorToWorldSpace(Vector3.zAxis).Z < 0 then 1 else -1
	local objetivo = cf:PointToWorldSpace(Vector3.new(0.5 * frente, tamano.Y / 2, frente * (tamano.Z / 2 - 1)))
	local desde = cf:PointToWorldSpace(Vector3.new(0.5 * frente, 0, frente * (tamano.Z / 2 - 1 + 18)))
	teletransportar(j, Vector3.new(desde.X, 1, desde.Z))
	task.wait(0.4)
	Comunes.llenarBolsa(j)
	local ok, motivo = Botin.lanzarBolsa(j, objetivo, tonumber(fuerza) or 1)
	task.wait(4.5)
	local bolsaId, pos, bajadaDesde = nil, nil, nil
	for id, obj in Botin.objetos() do
		if obj.item.tipo == "bolsa" and obj.item.duenoId == j.UserId and obj.modelo then
			bolsaId, pos, bajadaDesde = id, obj.modelo:GetPivot().Position, obj.modelo:GetAttribute("BajadaDesde")
		end
	end
	if not pos then
		return string.format("lanzar ok=%s (%s) | no quedo bolsa (entro?) => FALLO", tostring(ok), motivo)
	end
	local zona = Mundo.zonaAcierto()
	local alContenedor = Vector3.new(pos.X - zona.Position.X, 0, pos.Z - zona.Position.Z).Magnitude
	local recogida = Botin.reclamar(j, bolsaId, "toque")
	Bolsa.vaciar(j)
	teletransportar(j, Comunes.fueraDelPatio())
	return string.format("objetivo (%.1f, %.1f, %.1f) desde (%.1f, %.1f) | lanzar ok=%s (%s) | cayo en alto=%s | bolsa a y=%.1f, a %.1f studs del contenedor | recogida=%s => %s",
		objetivo.X, objetivo.Y, objetivo.Z, desde.X, desde.Z, tostring(ok), motivo,
		if bajadaDesde then string.format("si, a y=%.1f", bajadaDesde) else "no", pos.Y, alContenedor, tostring(recogida),
		(ok and bajadaDesde ~= nil and bajadaDesde > 4 and pos.Y <= 4 and recogida) and "OK" or "FALLO")
end

-- Deposito de cerca con basura de los cuatro materiales: Bolsa.alDepositar
-- debe salir con todos los objetos (BotinHandler lo reenvia a los clientes y
-- la cinta de la recicladora los transporta; se mira con PruebasCliente
-- "recicladora" y una captura). El jugador queda al norte, mirando la maquina.
function Pruebas.recicladora()
	local j = jugador()
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, -14))
	task.wait(0.3)
	Bolsa.vaciar(j)
	local materiales = { "Metal", "Plastico", "Papel", "Organico", "Plastico", "Metal" }
	for _, m in materiales do
		Bolsa.meter(j, { tipo = "basura", nombre = m, material = m, valor = 5 })
	end
	local recibidos = -1
	local conexion = Bolsa.alDepositar:Connect(function(quien, items)
		if quien == j then
			recibidos = #items
		end
	end)
	Bolsa.depositar(j)
	task.wait(0.2)
	conexion:Disconnect()
	return string.format("deposito de %d objetos -> alDepositar con %d => %s", #materiales, recibidos, recibidos == #materiales and "OK" or "FALLO")
end

return Pruebas
