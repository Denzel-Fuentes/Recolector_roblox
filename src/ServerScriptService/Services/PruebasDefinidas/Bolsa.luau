--!nonstrict
--[[
	Pruebas de la bolsa: deposito de cerca, que recoger nunca paga (billetes
	incluidos), la bolsa al desconectar y la punteria (lanzar la bolsa,
	acierto, fallo y bolsa protegida).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

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

-- Lanzar la bolsa entera a la zona de acierto desde 20 studs, desde el
-- frente (al norte, -Z): detras esta la trituradora, que ya colisiona
function Pruebas.lanzarBolsa()
	local j = jugador()
	Comunes.yaLanzo(j)
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, -20))
	task.wait(0.3)
	for _ = 1, 3 do
		Bolsa.meter(j, { tipo = "basura", nombre = "Chatarra", material = "Metal", valor = 12 })
	end
	local dineroAntes = Economia.dinero(j)
	local aciertosAntes = Perfiles.leerEstadistica(j, "aciertos")
	local ok, motivo = Botin.lanzarBolsa(j, zona.Position, 1)
	local vacia = Bolsa.cuenta(j) == 0
	task.wait(2.5)
	local aciertos = Perfiles.leerEstadistica(j, "aciertos")
	return string.format("lanzarBolsa ok=%s (%s) bolsa vacia al lanzar=%s aciertos %d->%d dinero %d->%d (3 chatarras x12 x(1 + 0,4 desde 20 studs + racha) >= 54) => %s",
		tostring(ok), motivo, tostring(vacia), aciertosAntes, aciertos, dineroAntes, Economia.dinero(j),
		(ok and vacia and aciertos > aciertosAntes and Economia.dinero(j) - dineroAntes >= 54) and "OK" or "FALLO")
end

-- Lanzar al suelo: la bolsa cae como objeto y su dueno la recoge (que otro
-- no pueda lo comprueba "bolsaProtegida"). Con el Brazo a nivel 0 (25 studs)
-- y media fuerza, la bolsa cae a ~12 studs, hacia el patio.
function Pruebas.lanzarBolsaFallo()
	local j = jugador()
	Comunes.yaLanzo(j)
	local zona = Mundo.zonaAcierto()
	-- El contenedor esta al sur del patio (plano v3): el jugador se pone al
	-- norte, en la plaza, y apunta hacia el patio, lejos del contenedor
	teletransportar(j, zona.Position + Vector3.new(0, 0, -30))
	task.wait(0.3)
	Bolsa.vaciar(j)
	Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 })
	Bolsa.meter(j, { tipo = "billete", nombre = "Billete", valor = 50 })
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
	return string.format("lanzar ok=%s (%s) | bolsa en el suelo=%s | recogida=%s (%s) | bolsa ahora %d/%d => %s",
		tostring(ok), motivo, tostring(bolsaId ~= nil), tostring(recogida), motivoRec, Bolsa.cuenta(j), Bolsa.capacidad(j),
		(ok and bolsaId and recogida and Bolsa.cuenta(j) == 2) and "OK" or "FALLO")
end

-- La bolsa que falla solo la recoge su dueno, y no se recicla sola: sigue en
-- el suelo pasado el tiempo que antes tenia (20 s) hasta que vuelve a por ella
function Pruebas.bolsaProtegida()
	local j = jugador()
	Comunes.yaLanzo(j)
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, -30))
	task.wait(0.3)
	Bolsa.vaciar(j)
	Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 })
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
	return string.format("lanzo=%s | ajena: recogida=%s (%s) | a los 21 s: sigue=%s cobrado=$%d | el dueno la recoge=%s (%d en la bolsa) => %s",
		tostring(lanzo), tostring(recogidaAjena), tostring(motivo), tostring(sigueEnElSuelo), cobrado, tostring(recogida), enLaBolsa,
		(lanzo and not recogidaAjena and motivo == "ajena" and sigueEnElSuelo and cobrado == 0 and recogida and enLaBolsa == 1) and "OK" or "FALLO")
end

-- La bolsa lanzada choca con la recicladora: desde delante de la caja de
-- salida se apunta a la parte baja de su frente (z = -3,95 en el marco del
-- pivote; apuntando a su centro el tiro cae sobre el techo); debe rebotar y
-- quedar en el suelo delante, no dentro de ninguna caja de ColisionRecicladora
function Pruebas.lanzarContraRecicladora()
	local j = jugador()
	Comunes.yaLanzo(j)
	local rec = game:GetService("CollectionService"):GetTagged("RecicladoraArte")[1]
	local caseta = rec and rec.Parent
	local colision = caseta and caseta:FindFirstChild("ColisionRecicladora")
	if not colision then
		return "sin recicladora o sin ColisionRecicladora => FALLO"
	end
	local pivote = rec:GetPivot()
	teletransportar(j, pivote:PointToWorldSpace(Vector3.new(9.4, 3, 14)))
	task.wait(0.3)
	Bolsa.vaciar(j)
	Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 })
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

-- Una bolsa fallada que quedaria en alto (por defecto se apunta a la
-- carcasa de la recicladora, techo a y = 10,7; x y z en el marco de su
-- pivote) se baja al suelo junto al contenedor: ya no se recicla sola, asi
-- que ahi arriba se perderia
function Pruebas.bolsaEnAlto(fuerza, x, y, z)
	local j = jugador()
	Comunes.yaLanzo(j)
	local rec = game:GetService("CollectionService"):GetTagged("RecicladoraArte")[1]
	if not rec then
		return "sin recicladora => FALLO"
	end
	local pivote = rec:GetPivot()
	teletransportar(j, pivote:PointToWorldSpace(Vector3.new(9.4, 3, 14)))
	task.wait(0.3)
	Bolsa.vaciar(j)
	Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 })
	local objetivo = pivote:PointToWorldSpace(Vector3.new(tonumber(x) or 5.5, tonumber(y) or 10.7, tonumber(z) or -6.4))
	-- (con 0,7 cae en el techo de la carcasa; medido el 29 sep)
	local ok, motivo = Botin.lanzarBolsa(j, objetivo, tonumber(fuerza) or 0.7)
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
	return string.format("lanzar ok=%s (%s) | cayo en alto=%s | bolsa a y=%.1f, a %.1f studs del contenedor | recogida=%s => %s",
		tostring(ok), motivo, if bajadaDesde then string.format("si, a y=%.1f", bajadaDesde) else "no", pos.Y, alContenedor, tostring(recogida),
		(ok and pos.Y <= 4 and recogida) and "OK" or "FALLO")
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
