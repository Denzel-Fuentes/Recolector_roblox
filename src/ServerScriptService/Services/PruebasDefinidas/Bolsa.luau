--!nonstrict
--[[
	Pruebas de la bolsa: deposito de cerca, bonus por bolsa llena, que recoger
	nunca paga (billetes incluidos), la bolsa al desconectar y la punteria
	(lanzar la bolsa, acierto y fallo).
]]

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
	return string.format("deposito: %d objetos, +$%d (bonus=%s), quedaron=%d, nuevas=%d | dinero %d->%d", resumen.objetos, resumen.dinero, tostring(resumen.bonus), resumen.quedaron, #resumen.mascotasNuevas, dineroAntes, Economia.dinero(j))
end

-- Bolsa llena de basura -> +25%
function Pruebas.bonusBolsaLlena()
	local j = jugador()
	local cap = Bolsa.capacidad(j)
	for i = Bolsa.cuenta(j) + 1, cap do
		Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 })
	end
	local esperado = math.floor(valorEsperado(j) * 1.25 + 0.5)
	local resumen = Bolsa.depositar(j)
	return string.format("bolsa %d/%d -> $%d (esperado %d con bonus) bonus=%s => %s", cap, cap, resumen.dinero, esperado, tostring(resumen.bonus), (resumen.bonus and resumen.dinero == esperado) and "OK" or "FALLO")
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
	local m = nil
	for _, monton in Botin.montones() do
		if monton.estado == "lleno" then
			m = monton
			break
		end
	end
	assert(m, "no queda ningun monton lleno")
	teletransportar(j, m.ranura.Position + Vector3.new(6, 0, 0))
	task.wait(0.3)
	local excavado, motivo = Botin.excavar(j, m)
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

-- Simula un jugador que sale con la bolsa a medias: la basura se pierde y la
-- mascota va al almacen (se comprueba a mano desconectando)
function Pruebas.bolsaAlSalir()
	local j = jugador()
	Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 })
	Bolsa.meter(j, { tipo = "mascota", nombre = "Latita", id = "latita", estado = 2, sucia = false })
	return "bolsa " .. Bolsa.cuenta(j) .. "/" .. Bolsa.capacidad(j) .. " (al desconectar: papel se pierde, latita -> almacen)"
end

-- Lanzar la bolsa entera a la zona de acierto desde 20 studs
function Pruebas.lanzarBolsa()
	local j = jugador()
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, 20))
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
	return string.format("lanzarBolsa ok=%s (%s) bolsa vacia al lanzar=%s aciertos %d->%d dinero %d->%d (3 chatarras x12 x1.5 = 54, mas logros) => %s",
		tostring(ok), motivo, tostring(vacia), aciertosAntes, aciertos, dineroAntes, Economia.dinero(j),
		(ok and vacia and aciertos > aciertosAntes and Economia.dinero(j) - dineroAntes >= 54) and "OK" or "FALLO")
end

-- Lanzar al suelo: la bolsa cae como objeto y otro (un falso) la recoge
function Pruebas.lanzarBolsaFallo()
	local j = jugador()
	local zona = Mundo.zonaAcierto()
	-- El contenedor esta al sur del patio (plano v3): el jugador se pone al
	-- norte, en la plaza, y apunta hacia el patio, lejos del contenedor
	teletransportar(j, zona.Position + Vector3.new(0, 0, -30))
	task.wait(0.3)
	Bolsa.vaciar(j)
	Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 })
	Bolsa.meter(j, { tipo = "fragmento", nombre = "Fragmento de Latita", id = "latita" })
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

return Pruebas
