--!nonstrict
--[[
	Pruebas de progreso y economia: estado del perfil, dinero y gemas,
	mejoras, mascotas (fusion, pity, fragmentos), coleccionables, parcela,
	tienda (sobre, contenedor), logros, recibos y pases.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local TablasProbabilidad = require(Config:WaitForChild("TablasProbabilidad"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local DefinicionesLogros = require(Config:WaitForChild("DefinicionesLogros"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Energia = require(Servicios:WaitForChild("Energia"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Botin = require(Servicios:WaitForChild("Botin"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))
local Parcelas = require(Servicios:WaitForChild("Parcelas"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador, teletransportar = Comunes.jugador, Comunes.teletransportar

local Pruebas = {}

function Pruebas.estado()
	local j = jugador()
	local p = Perfiles.obtener(j)
	if not p then
		return "sin perfil"
	end
	local mascotas, exhibidas = 0, 0
	for _ in p.mascotas do
		mascotas += 1
	end
	for _ in p.exhibidas do
		exhibidas += 1
	end
	local logros = 0
	for _ in p.logros do
		logros += 1
	end
	return string.format(
		"%s: cargado=%s dinero=%d gemas=%d energia=%d/%d bolsa=%d/%d mascotas=%d/%d exhibidas=%d pity=%d parcela=%s logros=%d modoDev=%s",
		j.Name, tostring(Perfiles.estaCargado(j)), p.dinero, p.gemas, Energia.actual(j), Energia.maxima(j),
		Bolsa.cuenta(j), Bolsa.capacidad(j), mascotas, Mascotas.capacidadAlmacen(j), exhibidas, p.pity,
		tostring(Parcelas.de(j) and Parcelas.de(j).Name), logros, tostring(Monetizacion.modoDev())
	)
end

function Pruebas.dar(cantidad)
	local j = jugador()
	Economia.ganar(j, tonumber(cantidad) or 1000)
	return "dinero: " .. Economia.dinero(j)
end

function Pruebas.comprarMejora(id)
	local j = jugador()
	local coste = Mejoras.costeSiguiente(j, id)
	local antes = Economia.dinero(j)
	local ok, msg = Mejoras.comprar(j, id)
	return string.format("%s: coste=%s ok=%s msg=%s nivel=%d dinero %d->%d valor=%s", id, tostring(coste), tostring(ok), msg, Mejoras.nivel(j, id), antes, Economia.dinero(j), tostring(Mejoras.valor(j, id)))
end

function Pruebas.maxMejoras()
	local j = jugador()
	local p = Perfiles.obtener(j)
	for id in p.mejoras do
		p.mejoras[id] = GameConfig.NIVEL_MAX_MEJORA
	end
	Perfiles.marcarSucio(j)
	Mejoras.aplicarVelocidad(j)
	return "todas al maximo: " .. tostring(Mejoras.todasAlMaximo(j)) .. " walkspeed=" .. tostring(Mejoras.valor(j, "Velocidad"))
end

-- 3 copias Regular limpias -> 1 Buena; Perfecta no fusiona
function Pruebas.fusion()
	local j = jugador()
	local id = "latita"
	local uids = {}
	for _ = 1, 3 do
		table.insert(uids, Mascotas.agregar(j, id, 2, false))
	end
	local antes = #Mascotas.copias(j, id)
	local ok, res = Mascotas.fusionar(j, id, 2)
	local despues = Mascotas.copias(j, id)
	local p = Perfiles.obtener(j)
	local nueva = ok and p.mascotas[res]
	local okPerfecta, motivo = Mascotas.fusionar(j, id, 5)
	return string.format("copias %d -> %d, fusion ok=%s nuevoEstado=%s | fusionar Perfecta: ok=%s (%s) => %s",
		antes, #despues, tostring(ok), tostring(nueva and nueva.estado), tostring(okPerfecta), motivo,
		(ok and nueva and nueva.estado == 3 and not okPerfecta) and "OK" or "FALLO")
end

-- Estadistica del pity: 200 montones grandes con pity fijo
function Pruebas.pity()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local salida = {}
	for _, pity in { 0, 10, 26 } do
		p.pity = pity
		local mascotas, raras = 0, 0
		for _ = 1, 300 do
			local contenido = Botin.generarContenido(j, "grande")
			for _, item in contenido do
				if item.tipo == "mascota" then
					mascotas += 1
					local def = DefinicionesMascotas.obtener(item.id)
					if def.rareza ~= "Comun" then
						raras += 1
					end
				end
			end
		end
		table.insert(salida, string.format("pity %d: prob teorica %.0f%%, observada %.0f%% (%d mascotas)", pity, TablasProbabilidad.probabilidadRara(pity, false) * 100, mascotas > 0 and raras / mascotas * 100 or 0, mascotas))
	end
	p.pity = 0
	return table.concat(salida, " | ")
end

-- Idempotencia de recibos
function Pruebas.recibo()
	local j = jugador()
	local antes = Economia.gemas(j)
	local a = Monetizacion.otorgarProductoPorId(j, "GemasChico", "prueba-recibo-1")
	local b = Monetizacion.otorgarProductoPorId(j, "GemasChico", "prueba-recibo-1")
	local despues = Economia.gemas(j)
	return string.format("gemas %d -> %d (dos recibos iguales, ok=%s/%s) => %s", antes, despues, tostring(a), tostring(b), (despues - antes == 100) and "OK" or "FALLO")
end

function Pruebas.darMascota(id, estado, sucia)
	local j = jugador()
	local uid = Mascotas.agregar(j, id or "latita", tonumber(estado) or 2, sucia == true or sucia == "true")
	return "uid=" .. tostring(uid) .. " copias=" .. #Mascotas.copias(j, id or "latita")
end

function Pruebas.darFragmentos(id)
	local j = jugador()
	for _ = 1, GameConfig.FRAGMENTOS_POR_MASCOTA do
		Mascotas.agregarFragmento(j, id or "latita")
	end
	return "fragmentos de " .. (id or "latita") .. ": " .. Mascotas.fragmentos(j, id or "latita")
end

function Pruebas.logros()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local lista = {}
	for id in p.logros do
		table.insert(lista, id)
	end
	table.sort(lista)
	return string.format("%d/%d logros: %s", #lista, #DefinicionesLogros.LISTA, table.concat(lista, ", "))
end

function Pruebas.irCasa()
	return "teletransporte: " .. tostring(Parcelas.teletransportar(jugador(), "casa"))
end

function Pruebas.pases(activo)
	Monetizacion.fijarModoDev(activo == true or activo == "on" or activo == "true")
	return "modoDev=" .. tostring(Monetizacion.modoDev())
end

function Pruebas.exhibir(uid, indice)
	local j = jugador()
	local ok, motivo = Mascotas.exhibir(j, uid, tonumber(indice) or 1)
	task.wait(0.4)
	return string.format("exhibir uid=%s pedestal=%s ok=%s (%s) | %s", tostring(uid), tostring(indice), tostring(ok), motivo, Pruebas.parcela())
end

function Pruebas.parcela()
	local j = jugador()
	local parcela = Parcelas.de(j)
	if not parcela then
		return "sin parcela"
	end
	local contenido = parcela:FindFirstChild("Contenido")
	local modelos = {}
	if contenido then
		for _, m in contenido:GetChildren() do
			table.insert(modelos, m.Name)
		end
	end
	local cartel = parcela.Cartel.CartelDueno.Texto.Text
	return string.format("%s cartel='%s' contenido=[%s] radio.CintaId=%s", parcela.Name, cartel, table.concat(modelos, ", "), tostring(parcela.Radio:GetAttribute("CintaId")))
end

function Pruebas.darColeccionable(tipo, id)
	local j = jugador()
	local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))
	local nuevo = Coleccionables.agregar(j, tipo, id)
	task.wait(0.4)
	return string.format("%s %s nuevo=%s | %s", tipo, id, tostring(nuevo), Pruebas.parcela())
end

function Pruebas.sobre()
	local j = jugador()
	local Tienda = require(Servicios:WaitForChild("Tienda"))
	Economia.ganarGemas(j, GameConfig.PRECIO_SOBRE_GEMAS)
	local gemasAntes = Economia.gemas(j)
	local ok, motivo, resultados = Tienda.abrirSobre(j)
	local r = resultados[1]
	return string.format("sobre ok=%s (%s) gemas %d->%d | %s", tostring(ok), motivo, gemasAntes, Economia.gemas(j), r and (r.id .. " " .. r.rareza .. " estado " .. r.estado) or "-")
end

function Pruebas.contenedor(pagarCon)
	local j = jugador()
	local Tienda = require(Servicios:WaitForChild("Tienda"))
	local okB, motivoB = Tienda.abrirContenedorDorado(j, "dinero")
	Pruebas.maxMejoras()
	Economia.ganar(j, GameConfig.PRECIO_CONTENEDOR_DORADO)
	Economia.ganarGemas(j, GameConfig.PRECIO_CONTENEDOR_DORADO_GEMAS)
	local dineroAntes, gemasAntes = Economia.dinero(j), Economia.gemas(j)
	local ok, motivo, resultados = Tienda.abrirContenedorDorado(j, pagarCon or "dinero")
	local nombres = {}
	for _, r in resultados do
		table.insert(nombres, r.id .. "/" .. r.rareza .. "/" .. r.estado)
	end
	return string.format("antes de maxear: ok=%s (%s) | despues: ok=%s (%s) dinero %d->%d gemas %d->%d | %s",
		tostring(okB), motivoB, tostring(ok), motivo, dineroAntes, Economia.dinero(j), gemasAntes, Economia.gemas(j), table.concat(nombres, ", "))
end

function Pruebas.darGemas(cantidad)
	local j = jugador()
	Economia.ganarGemas(j, tonumber(cantidad) or 500)
	return "gemas: " .. Economia.gemas(j)
end

-- Una copia de las 40 -> el Rey se corona solo (y el logro Coronacion)
function Pruebas.darTodas()
	local j = jugador()
	local p = Perfiles.obtener(j)
	for id in p.mejoras do
		p.mejoras.Almacen = GameConfig.NIVEL_MAX_MEJORA
	end
	local n = 0
	for _, def in DefinicionesMascotas.LISTA do
		if def.rareza ~= "Mitica" and not Mascotas.tiene(j, def.id) then
			if Mascotas.agregar(j, def.id, 2, false) then
				n += 1
			end
		end
	end
	task.wait(0.6)
	return string.format("%d anadidas, sets completos=%d, Rey=%s | %s", n, Mascotas.setsCompletos(j), tostring(Mascotas.tiene(j, DefinicionesMascotas.ID_REY)), Pruebas.logros())
end

-- Depuracion: fija el nivel de una mejora (p. ej. "Alcance", 10) sin comprar
function Pruebas.fijarMejora(id, nivel)
	local j = jugador()
	local p = Perfiles.obtener(j)
	p.mejoras[id] = math.clamp(tonumber(nivel) or 0, 0, GameConfig.NIVEL_MAX_MEJORA)
	Perfiles.marcarSucio(j)
	Mejoras.aplicarVelocidad(j)
	return id .. " = " .. p.mejoras[id] .. " (valor " .. Mejoras.valor(j, id) .. ")"
end

return Pruebas
