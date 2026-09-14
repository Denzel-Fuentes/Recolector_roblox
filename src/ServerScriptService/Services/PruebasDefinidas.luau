--!nonstrict
--[[
	PruebasDefinidas (ModuleScript)
	Pruebas de servidor que corren DENTRO de la VM del juego (ver Pruebas).
	Cada una devuelve un string legible. Usan al primer jugador conectado en
	Play Solo; para el reclamo compartido se simula un segundo reclamante con
	una tabla vacia (Botin no exige un Player real para basura).

	Se invocan asi desde la barra de comandos / execute_luau (DataModel Server):
	    game.ServerStorage.EjecutarPrueba:Invoke("estado")
	    game.ServerStorage.EjecutarPrueba:Invoke("excavar", 3)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local TablasProbabilidad = require(Config:WaitForChild("TablasProbabilidad"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local DefinicionesLogros = require(Config:WaitForChild("DefinicionesLogros"))

local Servicios = script.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Energia = require(Servicios:WaitForChild("Energia"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Botin = require(Servicios:WaitForChild("Botin"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))
local Parcelas = require(Servicios:WaitForChild("Parcelas"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Mundo = require(Servicios:WaitForChild("Mundo"))

local Pruebas = {}

local function jugador(): Player
	local j = Players:GetPlayers()[1]
	assert(j, "no hay jugador conectado")
	return j
end

local function teletransportar(j: Player, pos: Vector3)
	local ch = j.Character
	if ch then
		ch:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
	end
end

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
	local m = Botin.montones()[tonumber(indice) or 1]
	assert(m, "no existe el monton")
	teletransportar(j, m.ranura.Position + Vector3.new(6, 0, 0))
	task.wait(0.2)
	local energiaAntes = Energia.actual(j)
	local ok, motivo = Botin.excavar(j, m)
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
	return string.format("excavar monton %d (%s): ok=%s motivo=%s energia %d->%d | %s", m.id, m.tamano, tostring(ok), motivo, energiaAntes, Energia.actual(j), table.concat(partes, " "))
end

-- Reclama todos los objetos libres para el jugador
function Pruebas.reclamarTodo()
	local j = jugador()
	local ok, fallos = 0, {}
	task.wait(0.8) -- que aterricen
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
	local m = nil
	for _, monton in Botin.montones() do
		if monton.estado == "lleno" then
			m = monton
			break
		end
	end
	assert(m, "no queda monton lleno")
	teletransportar(j, m.ranura.Position + Vector3.new(6, 0, 0))
	task.wait(0.2)
	Energia.fijar(j, Energia.maxima(j))
	assert(Botin.excavar(j, m))
	task.wait(0.8)
	local basuras = {}
	for id, obj in Botin.objetos() do
		if obj.monton == m and obj.item.tipo == "basura" then
			table.insert(basuras, id)
		end
	end
	assert(#basuras >= 2, "hacen falta 2 basuras, hay " .. #basuras)
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
	Monetizacion.fijarModoDev(false) -- sin AutoReciclaje para que la basura entre en la bolsa
	local cap = Bolsa.capacidad(j)
	for i = Bolsa.cuenta(j) + 1, cap do
		Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 })
	end
	local esperadoBase = 0
	for _, item in Bolsa.contenido(j) do
		if item.tipo == "basura" then
			esperadoBase += Bolsa.valorBasura(j, item)
		elseif item.tipo == "tesoro" then
			esperadoBase += item.valor
		end
	end
	local resumen = Bolsa.depositar(j)
	Monetizacion.fijarModoDev(true)
	local esperado = math.floor(esperadoBase * 1.25 + 0.5)
	return string.format("bolsa %d/%d -> $%d (esperado %d con bonus) bonus=%s => %s", cap, cap, resumen.dinero, esperado, tostring(resumen.bonus), (resumen.bonus and resumen.dinero == esperado) and "OK" or "FALLO")
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

-- Lanzar directo a la zona de acierto desde 20 studs
function Pruebas.lanzar()
	local j = jugador()
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, 20))
	task.wait(0.3)
	Monetizacion.fijarModoDev(false)
	Bolsa.meter(j, { tipo = "basura", nombre = "Chatarra", material = "Metal", valor = 12 })
	Monetizacion.fijarModoDev(true)
	local aciertosAntes = Perfiles.leerEstadistica(j, "aciertos")
	local ok, motivo = Botin.lanzar(j, zona.Position)
	task.wait(2)
	local aciertos = Perfiles.leerEstadistica(j, "aciertos")
	return string.format("lanzar ok=%s (%s) aciertos %d->%d mejorDistancia=%d => %s", tostring(ok), motivo, aciertosAntes, aciertos, Perfiles.leerEstadistica(j, "mejorDistanciaAcierto"), (ok and aciertos > aciertosAntes) and "OK" or "FALLO")
end

function Pruebas.repoblar()
	Botin.repoblarAhora()
	return Pruebas.montones()
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

-- Simula un jugador que sale con la bolsa llena: la basura se recicla sin bonus
function Pruebas.bolsaAlSalir()
	local j = jugador()
	Monetizacion.fijarModoDev(false)
	Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 6 })
	Bolsa.meter(j, { tipo = "mascota", nombre = "Latita", id = "latita", estado = 2, sucia = false })
	Monetizacion.fijarModoDev(true)
	return "bolsa " .. Bolsa.cuenta(j) .. "/" .. Bolsa.capacidad(j) .. " (al desconectar: papel -> $6, latita -> almacen)"
end

return Pruebas
