--!nonstrict
--[[
	Pruebas de las mascotas y sus fragmentos (diseno v2, lote 6; fragmentos
	en vez de capsulas desde el 29 sep): probabilidades y pity por set,
	"siempre nueva", la primera mascota (Comun, 3 fragmentos), el montaje
	de un set hasta completarla, los fragmentos de un set cerrado, lo que
	sale de los montones, niveles y dinero de las repetidas, huecos, bonus e
	iman por material, el Rey Reciclon y una simulacion de cuantos
	fragmentos (y piezas) cuesta completar un set.

	Cada prueba guarda y restaura lo que toca del perfil.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local TablasProbabilidad = require(Shared:WaitForChild("Config"):WaitForChild("TablasProbabilidad"))
local DefinicionesMascotas = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMascotas"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))
local Fragmentos = require(Servicios:WaitForChild("Fragmentos"))
local GeneradorBotin = require(Servicios:WaitForChild("GeneradorBotin"))
local Seguidores = require(Servicios:WaitForChild("Seguidores"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador, teletransportar = Comunes.jugador, Comunes.teletransportar

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

local CAMPOS = { "mascotas", "equipadas", "fragmentos", "pityMascotas", "rebirths", "fragmentosLibres" }

-- Copia profunda (dos niveles bastan) de lo que tocan los fragmentos
local function guardar(p)
	local copia = {}
	for _, c in CAMPOS do
		local v = p[c]
		if typeof(v) == "table" then
			local t = {}
			for k, x in v do
				t[k] = if typeof(x) == "table" then table.clone(x) else x
			end
			copia[c] = t
		else
			copia[c] = v
		end
	end
	return copia
end

local function restaurar(j, p, copia)
	for _, c in CAMPOS do
		p[c] = copia[c]
	end
	Perfiles.marcarSucio(j)
	Mascotas.alCambiarEquipadas:Fire(j)
end

local function vaciarColeccion(p)
	p.mascotas, p.equipadas, p.fragmentos, p.pityMascotas = {}, {}, {}, {}
	p.rebirths, p.fragmentosLibres = 0, 0
end

local function perfilFalso()
	return { fragmentos = {}, pityMascotas = {}, mascotas = {} }
end

-- 20.000 mascotas empezadas en un perfil de mentira: las tasas rondan
-- 67/28/5, con mas Rara y Epica por el pity (~61/31/8; la garantia de "Rara
-- o mejor" tambien puede dar Epica) y ninguna racha pasa los topes
function Pruebas.rarezaOdds()
	local falso = perfilFalso()
	local r = Random.new(11)
	local cuenta = { Comun = 0, Rara = 0, Epica = 0 }
	local sinRara, sinEpica, peorRara, peorEpica = 0, 0, 0, 0
	local n = 20000
	for _ = 1, n do
		local rareza = Fragmentos.tirarRareza(falso, "Plastin", r)
		cuenta[rareza] += 1
		if rareza == "Comun" then
			sinRara += 1
			sinEpica += 1
		elseif rareza == "Rara" then
			sinRara = 0
			sinEpica += 1
		else
			sinRara, sinEpica = 0, 0
		end
		peorRara = math.max(peorRara, sinRara)
		peorEpica = math.max(peorEpica, sinEpica)
	end
	local P = DefinicionesMascotas.PITY
	local c, ra, e = cuenta.Comun / n * 100, cuenta.Rara / n * 100, cuenta.Epica / n * 100
	return string.format("Comun %.1f%% Rara %.1f%% Epica %.1f%% | peor racha sin Rara+ %d (tope %d) sin Epica %d (tope %d) => %s",
		c, ra, e, peorRara, P.rara - 1, peorEpica, P.epica - 1,
		ok(c > 55 and c < 67.5 and ra > 27 and ra < 36 and e > 6 and e < 10 and peorRara <= P.rara - 1 and peorEpica <= P.epica - 1))
end

-- Las 4 primeras Comunes de un set son las 4 distintas; la 5.a, repetida
function Pruebas.siempreNueva()
	local falso = perfilFalso()
	local r = Random.new(5)
	local vistas = {}
	for _ = 1, 4 do
		local id = Fragmentos.elegirMascota(falso, "Cartonin", "Comun", r)
		vistas[id] = true
		falso.mascotas[id] = 1
	end
	local distintas = 0
	for _ in vistas do
		distintas += 1
	end
	local quinta = Fragmentos.elegirMascota(falso, "Cartonin", "Comun", r)
	return string.format("4 Comunes distintas: %d | la 5.a es repetida: %s => %s", distintas, tostring(vistas[quinta] == true), ok(distintas == 4 and vistas[quinta] == true))
end

-- Un perfil sin nada: la primera mascota es Comun y pide 3 fragmentos; la
-- siguiente (otro set) ya pide lo de su rareza
function Pruebas.primeraMascota()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	vaciarColeccion(p)
	local r1 = Fragmentos.agregar(j, "Plastin", "admin")
	local r2 = Fragmentos.agregar(j, "Plastin", "admin")
	local r3 = Fragmentos.agregar(j, "Plastin", "admin")
	local tiene = r3 and Mascotas.tiene(j, r3.id)
	local otra = Fragmentos.agregar(j, "Cartonin", "admin")
	local totalOtra = otra and otra.total or 0
	local esperado = otra and DefinicionesMascotas.fragmentos(otra.rareza) or -1
	restaurar(j, p, copia)
	return string.format("1.a: %s %s %d/%d empezada=%s | al 3.o completa=%s tiene=%s | la siguiente (%s) pide %d (esperado %d) => %s",
		tostring(r1 and r1.id), tostring(r1 and r1.rareza), r1 and r1.n or 0, r1 and r1.total or 0, tostring(r1 and r1.empezada),
		tostring(r3 and r3.completa ~= nil), tostring(tiene), tostring(otra and otra.rareza), totalOtra, esperado,
		ok(r1 ~= nil and r1.rareza == "Comun" and r1.total == DefinicionesMascotas.FRAGMENTOS_PRIMERA and r1.empezada
			and r2 ~= nil and r2.completa == nil and r3 ~= nil and r3.completa ~= nil and tiene == true
			and totalOtra == esperado))
end

-- Un set monta UNA mascota: cada fragmento la acerca, al completar sale (o
-- sube de nivel) y el siguiente empieza otra
function Pruebas.montaje()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	vaciarColeccion(p)
	Mascotas.agregar(j, "cajita") -- ya no es la primera
	local primero = Fragmentos.agregar(j, "Plastin", "admin")
	local id, total = primero.id, primero.total
	local mismo = true
	local ultimo = primero
	for _ = 2, total do
		ultimo = Fragmentos.agregar(j, "Plastin", "admin")
		mismo = mismo and ultimo.id == id
	end
	local completa = ultimo.completa
	local limpio = p.fragmentos.Plastin == nil
	local nivel = Mascotas.nivel(j, id)
	local siguiente = Fragmentos.agregar(j, "Plastin", "admin")
	restaurar(j, p, copia)
	return string.format("monta %s (%s) en %d | siempre la misma=%s | al ultimo completa=%s nueva=%s nivel=%d | montaje limpio=%s | el siguiente empieza=%s => %s",
		id, primero.rareza, total, tostring(mismo), tostring(completa ~= nil), tostring(completa and completa.nueva), nivel, tostring(limpio), tostring(siguiente and siguiente.empezada),
		ok(primero.empezada and total == DefinicionesMascotas.fragmentos(primero.rareza) and mismo and completa ~= nil and completa.nueva
			and nivel == 1 and limpio and siguiente ~= nil and siguiente.empezada and siguiente.n == 1))
end

-- Sin el Rebirth 1 los fragmentos de Chatarrin no cuentan: reciclado, se
-- paga como un billete de metal (15 x 6 = $90)
function Pruebas.fragmentoCerrado()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	vaciarColeccion(p)
	local directo = Fragmentos.agregar(j, "Chatarrin", "admin")
	local antes = Economia.dinero(j)
	local resumen = Bolsa.depositarItems(j, { { tipo = "fragmento", nombre = "Fragmento de Chatarrín", material = "Metal", id = "Chatarrin" } }, 0)
	local cobrado = Economia.dinero(j) - antes
	p.rebirths = 1
	local conRebirth = Fragmentos.agregar(j, "Chatarrin", "admin")
	restaurar(j, p, copia)
	return string.format("sin rebirth: agregar=%s | reciclado +$%d cerrados=[%s] | con Rebirth 1 cuenta=%s => %s",
		tostring(directo), cobrado, table.concat(resumen.cerrados, ","), tostring(conRebirth ~= nil),
		ok(directo == nil and cobrado == 90 and resumen.cerrados[1] == "Chatarrin" and resumen.fragmentos == 0 and conRebirth ~= nil))
end

-- Reciclar una bolsa con 2 fragmentos de Plastin y basura: la basura paga y
-- los 2 fragmentos van al montaje de Plastin
function Pruebas.fragmentoAlDepositar()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	vaciarColeccion(p)
	Mascotas.agregar(j, "cajita")
	local items = {}
	for _ = 1, 8 do
		table.insert(items, { tipo = "basura", nombre = "Plástico", material = "Plastico" })
	end
	table.insert(items, { tipo = "fragmento", nombre = "Fragmento de Plastín", material = "Plastico", id = "Plastin" })
	table.insert(items, { tipo = "fragmento", nombre = "Fragmento de Plastín", material = "Plastico", id = "Plastin" })
	local resumen = Bolsa.depositarItems(j, items, 0)
	local montaje = p.fragmentos.Plastin
	local n = montaje and montaje.n or 0
	restaurar(j, p, copia)
	return string.format("objetos pagados %d ($%d) | fragmentos %d | montaje de Plastin %d => %s",
		resumen.objetos, resumen.dinero, resumen.fragmentos, n, ok(resumen.objetos == 8 and resumen.dinero == 56 and resumen.fragmentos == 2 and n == 2))
end

-- Lo que sale de los montones: ~2,5 % fragmentos, de los sets abiertos de
-- quien excava; el grande trae siempre uno; y la zona decide la mezcla
function Pruebas.fragmentosMonton()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = p.rebirths
	p.rebirths = 0
	local lista = GeneradorBotin.generar(j, "chico", "patio", 8000)
	local frag, porSet = 0, {}
	for _, item in lista do
		if item.tipo == "fragmento" then
			frag += 1
			porSet[item.id] = (porSet[item.id] or 0) + 1
		end
	end
	local cerrados = (porSet.Chatarrin or 0) + (porSet.Mostrenco or 0)
	p.rebirths = 2
	local metal = GeneradorBotin.generar(j, "chico", "metal", 8000)
	local fragMetal = 0
	for _, item in metal do
		if item.tipo == "fragmento" and item.id == "Chatarrin" then
			fragMetal += 1
		end
	end
	p.rebirths = 0
	local sinGrande = 0
	for _ = 1, 200 do
		local hay = false
		for _, item in GeneradorBotin.generar(j, "grande", "patio") do
			hay = hay or item.tipo == "fragmento"
		end
		if not hay then
			sinGrande += 1
		end
	end
	p.rebirths = antes
	local pct = frag / #lista * 100
	return string.format("patio con 0 rebirths: %.2f%% fragmentos (Cartonin %d, Plastin %d, cerrados %d) | zona de metal con R2: %d de Chatarrin | grandes sin fragmento %d/200 => %s",
		pct, porSet.Cartonin or 0, porSet.Plastin or 0, cerrados, fragMetal, sinGrande,
		ok(pct > 2 and pct < 3 and cerrados == 0 and (porSet.Cartonin or 0) > 0 and (porSet.Plastin or 0) > 0 and fragMetal > 50 and sinGrande == 0))
end

-- La mezcla de cada zona: el patio casi todo papel y plastico; la del metal,
-- metal (tabla MEZCLA, 8.000 piezas de cada una)
function Pruebas.mezclaZonas()
	local j = jugador()
	local partes, bien = {}, true
	for zona, tabla in TablasProbabilidad.MEZCLA do
		local lista = GeneradorBotin.generar(j, "chico", zona, 8000)
		local cuenta, n = {}, 0
		for _, item in lista do
			if item.tipo ~= "fragmento" and item.material then
				cuenta[item.material] = (cuenta[item.material] or 0) + 1
				n += 1
			end
		end
		local texto = {}
		for _, e in tabla do
			local pct = (cuenta[e.id] or 0) / n * 100
			bien = bien and math.abs(pct - e.peso) < 2.5
			table.insert(texto, string.format("%s %.0f/%d", e.id, pct, e.peso))
		end
		table.insert(partes, zona .. ": " .. table.concat(texto, " "))
	end
	return table.concat(partes, " | ") .. " => " .. ok(bien)
end

-- Repetidas: nivel 1 -> 5 y despues dinero (una Rara: $400 x rebirth)
function Pruebas.repetidaNivel()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	vaciarColeccion(p)
	local niveles = {}
	for _ = 1, 5 do
		table.insert(niveles, Mascotas.agregar(j, "burbujin").nivel)
	end
	local antes = Economia.dinero(j)
	local sexta = Mascotas.agregar(j, "burbujin")
	local cobrado = Economia.dinero(j) - antes
	p.rebirths = 2
	local antes2 = Economia.dinero(j)
	Mascotas.agregar(j, "burbujin")
	local cobrado2 = Economia.dinero(j) - antes2
	restaurar(j, p, copia)
	local serie = table.concat(niveles, ",")
	return string.format("niveles %s | la 6.a: nivel %d y +$%d | con 2 rebirths +$%d => %s",
		serie, sexta.nivel, cobrado, cobrado2, ok(serie == "1,2,3,4,5" and sexta.nivel == 5 and cobrado == 400 and cobrado2 == 800))
end

-- Huecos: 1, 2 desde el Rebirth 3; la primera se equipa sola; no se pasa del
-- hueco; el Rey no ocupa
function Pruebas.huecos()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	vaciarColeccion(p)
	local h0 = Mascotas.huecos(j)
	local primera = Mascotas.agregar(j, "cajita")
	Mascotas.agregar(j, "botellin")
	local okSegunda, motivo = Mascotas.equipar(j, "botellin", true)
	p.rebirths = 3
	local h3 = Mascotas.huecos(j)
	local okConR3 = Mascotas.equipar(j, "botellin", true)
	local okRey = Mascotas.equipar(j, DefinicionesMascotas.ID_REY, true)
	local equipadas = table.concat(p.equipadas, ",")
	restaurar(j, p, copia)
	return string.format("huecos 0 rebirths=%d, R3=%d | la 1.a se equipa sola=%s | 2.a sin hueco=%s (%s) | con R3=%s | Rey=%s | equipadas=%s => %s",
		h0, h3, tostring(primera.equipada), tostring(okSegunda), motivo, tostring(okConR3), tostring(okRey), equipadas,
		ok(h0 == 1 and h3 == 2 and primera.equipada and not okSegunda and motivo == "huecosLlenos" and okConR3 and not okRey and equipadas == "cajita,botellin"))
end

-- Bonus al material: una Comun de papel +20 % a nivel 1 y +40 % a nivel 5;
-- el pago de una pieza de papel ($5) lo lleva
function Pruebas.bonusMascota()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	vaciarColeccion(p)
	Mascotas.agregar(j, "cajita")
	local b1 = Mascotas.bonusMaterial(j, "Papel")
	local bPlastico = Mascotas.bonusMaterial(j, "Plastico")
	for _ = 1, 4 do
		Mascotas.agregar(j, "cajita")
	end
	local b5 = Mascotas.bonusMaterial(j, "Papel")
	local antes = Economia.dinero(j)
	Bolsa.depositarItems(j, { { tipo = "basura", nombre = "Papel", material = "Papel" } }, 0)
	local cobrado = Economia.dinero(j) - antes
	restaurar(j, p, copia)
	return string.format("Cajita nv1: papel +%.0f%% plastico +%.0f%% | nv5: +%.0f%% | pieza de papel paga $%d (5 x 1,4 = 7) => %s",
		b1 * 100, bPlastico * 100, b5 * 100, cobrado, ok(math.abs(b1 - 0.2) < 1e-6 and bPlastico == 0 and math.abs(b5 - 0.4) < 1e-6 and cobrado == 7))
end

-- Iman: una Rara de plastico equipada atrae plastico a 6 studs y nada mas;
-- en un monton del patio (revuelto: ~40 % plastico) el plastico vuela solo
-- a la bolsa y el resto se queda
function Pruebas.imanMaterial()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	vaciarColeccion(p)
	Mascotas.agregar(j, "burbujin")
	local radios = Mascotas.radiosIman(j)
	local m = Comunes.montonesLlenos(1)[1]
	local recogidas, soloPlastico = 0, true
	if m then
		teletransportar(j, m.ranura.Position + Vector3.new(GameConfig.TAMANOS_MONTON[m.tamano].radio + 6, 0, 0))
		task.wait(0.2)
		Comunes.excavar(j, m)
		task.wait(1.8)
		Bolsa.vaciar(j)
		teletransportar(j, m.ranura.Position + Vector3.new(GameConfig.TAMANOS_MONTON[m.tamano].radio * 0.6, 0, 0))
		task.wait(3)
		for _, item in Bolsa.contenido(j) do
			recogidas += 1
			soloPlastico = soloPlastico and item.material == "Plastico"
		end
		Bolsa.vaciar(j)
	end
	restaurar(j, p, copia)
	teletransportar(j, Comunes.fueraDelPatio())
	return string.format("radios: plastico=%s papel=%s | en un monton revuelto, sin clic, a la bolsa: %d (solo plastico=%s) => %s",
		tostring(radios.Plastico), tostring(radios.Papel), recogidas, tostring(soloPlastico), ok(radios.Plastico == 6 and radios.Papel == nil and recogidas > 0 and soloPlastico))
end

-- Con las 40 llega el Rey: +50 % a todo, y le sigue sin ocupar hueco
function Pruebas.reyReciclon()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = guardar(p)
	vaciarColeccion(p)
	for _, def in DefinicionesMascotas.LISTA do
		if def.id ~= DefinicionesMascotas.ID_REY then
			Mascotas.agregar(j, def.id)
		end
	end
	task.wait(0.3)
	local rey = Mascotas.tiene(j, DefinicionesMascotas.ID_REY)
	local bonus = Mascotas.bonusMaterial(j, "Metal") -- la equipada es de papel: solo el Rey
	local equipadas = #p.equipadas
	local seguidores = #Seguidores.de(j)
	restaurar(j, p, copia)
	return string.format("rey=%s | bonus al metal +%.0f%% | equipadas %d + seguidores %d (con el Rey) => %s",
		tostring(rey), bonus * 100, equipadas, seguidores, ok(rey and math.abs(bonus - 0.5) < 1e-6 and equipadas == 1 and seguidores == 2))
end

-- Simulacion: fragmentos hasta completar un set, 400 veces, y las piezas
-- que eso supone solo con la tasa de fragmentos de los montones (sin los
-- garantizados de los grandes, ni los de otros sets que salen a la vez)
function Pruebas.simularSet()
	local r = Random.new(3)
	local tasa = 0
	for _, e in TablasProbabilidad.TIPO_PIEZA do
		if e.id == "fragmento" then
			tasa = e.peso / 100
		end
	end
	local resultados, mascotas = {}, {}
	for _ = 1, 400 do
		local falso = perfilFalso()
		falso.mascotas.cajita = 1 -- no es la primera
		local tengo, fragmentos, empezadas = 0, 0, 0
		while tengo < 10 do
			local montaje = Fragmentos.empezar(falso, "Chatarrin", r)
			empezadas += 1
			fragmentos += montaje.total
			falso.fragmentos.Chatarrin = nil
			if (falso.mascotas[montaje.id] or 0) == 0 then
				tengo += 1
			end
			falso.mascotas[montaje.id] = (falso.mascotas[montaje.id] or 0) + 1
		end
		table.insert(resultados, fragmentos)
		table.insert(mascotas, empezadas)
	end
	table.sort(resultados)
	table.sort(mascotas)
	local mediana, p90 = resultados[200], resultados[360]
	return string.format("para completar un set: mediana %d fragmentos (%d mascotas), p90 %d fragmentos; a %.1f %% son ~%d y ~%d piezas del set",
		mediana, mascotas[200], p90, tasa * 100, math.floor(mediana / tasa), math.floor(p90 / tasa))
end

-- Depuracion: n fragmentos de un set para el jugador (como reciclados)
function Pruebas.darFragmentos(setId, n)
	local j = jugador()
	local salida = {}
	for _ = 1, tonumber(n) or 1 do
		local r = Fragmentos.agregar(j, setId or "Plastin", "admin")
		if r then
			table.insert(salida, string.format("%s %d/%d%s", r.id, r.n, r.total, if r.completa then "!" else ""))
		end
	end
	return table.concat(salida, " ")
end

return Pruebas
