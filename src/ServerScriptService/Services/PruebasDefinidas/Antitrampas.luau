--!nonstrict
--[[
	Pruebas anti-trampas del patio y del lanzamiento (P3, 22 oct): lo que un
	cliente modificado ya no consigue, y que la salida del jugador ni pierde
	ni duplica dinero.

	  lanzarSoloLlena        el servidor no lanza una bolsa vacia ni a medias
	  lanzarArgumentosMalos  NaN, infinitos, numeros enormes, puntos fuera del
	                         mapa y tipos que no son: se rechazan sin tocar la
	                         bolsa; apuntar por encima de la valla sigue valiendo
	  primeroSinRecord       el primero entra, pero paga la distancia del Brazo
	                         y no es record ni mejorDistanciaAcierto
	  topeBolsasCaidas       con una bolsa en el suelo mas que el tope, la mas
	                         vieja se recicla sola para su dueno, sin bonus y a
	                         x0,5 (decision del usuario, 23 oct)
	  vueloAlSalir           al salir se cobra sin bonus lo que esta en el aire
	                         (y al llegar ya no paga ni se queda en el suelo) y
	                         lo que esta en el suelo, una sola vez; y con un
	                         contexto de Guardado, que eso va en el guardado de
	                         salida (orden real alSalir -> guardado)
	  teletransporte         un salto que no dio el servidor deja 2 s sin
	                         recoger, entregar a mano ni lanzar, desde ese mismo
	                         instante; con permitirSalto, nada
	  camaraCooldown         la vista se escribe como mucho una vez por
	                         cooldown y la ultima pedida no se pierde
	  poseSinBucle           (rendimiento, del mismo paquete) sin el bucle de
	                         la pose de brazos de Studio, como en un servidor
	                         publicado, la bolsa se suelda igual entre las
	                         manos medidas

	La salida se prueba llamando a Lanzamiento.cobrarAlSalir (lo que conecta
	a Perfiles.alSalir): disparar alSalir de verdad vaciaria tambien la bolsa
	y publicaria los rankings. Para la de verdad, dejarBolsaCaida (depuracion)
	deja una bolsa en el suelo y dice cuanto deberia cobrarse: se para el Play
	y al volver el dinero tiene que haber subido eso.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local DefinicionesPunteria = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesPunteria"))
local Geometria = require(Shared:WaitForChild("Utilidades"):WaitForChild("Geometria"))
local PoseBrazos = require(Shared:WaitForChild("Utilidades"):WaitForChild("PoseBrazos"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local HttpService = game:GetService("HttpService")

local Servicios = script.Parent.Parent
local Guardado = require(Servicios:WaitForChild("Guardado"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Botin = require(Servicios:WaitForChild("Botin"))
local Mundo = require(Servicios:WaitForChild("Mundo"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Lanzamiento = require(Servicios:WaitForChild("Lanzamiento"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))
local Movimiento = require(Servicios:WaitForChild("Movimiento"))
local Patio = require(Servicios:WaitForChild("Patio"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador, teletransportar = Comunes.jugador, Comunes.teletransportar

local Pruebas = {}

local function ok(cond: any): string
	return if cond then "OK" else "FALLO"
end

local function papel(valor: number)
	return { tipo = "basura", nombre = "Papel", material = "Papel", valor = valor }
end

-- Para fallar a proposito (como lanzarBolsaFallo): desde 30 studs al norte
-- del general, hacia el patio, con media fuerza
local function sitioDeFallo(): (Vector3, Vector3)
	local zona = Mundo.zonaAcierto()
	return zona.Position + Vector3.new(0, 0, -30), zona.Position + Vector3.new(-25, 0, -80)
end

-- El servidor no lanza una bolsa vacia ("nadaQueLanzar") ni a medias
-- ("bolsaNoLlena", y no la toca); llena, si
function Pruebas.lanzarSoloLlena()
	local j = jugador()
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, -20))
	task.wait(0.4)
	Bolsa.vaciar(j)
	local vacia, motivoVacia = Botin.lanzarBolsa(j, zona.Position, 1)
	Bolsa.meter(j, papel(6))
	Bolsa.meter(j, papel(6))
	local media, motivoMedia = Botin.lanzarBolsa(j, zona.Position, 1)
	local quedan = Bolsa.cuenta(j)
	local aciertosAntes = Perfiles.leerEstadistica(j, "aciertos")
	local n = Comunes.llenarBolsa(j, papel(6))
	local llena, motivoLlena = Botin.lanzarBolsa(j, zona.Position, 1)
	local vaciada = Bolsa.cuenta(j) == 0
	task.wait(2.5)
	local entro = Perfiles.leerEstadistica(j, "aciertos") > aciertosAntes
	return string.format("vacia: lanzo=%s (%s) | a medias (2/%d): lanzo=%s (%s), le quedan %d | llena (%d): lanzo=%s (%s), vaciada=%s, entro=%s => %s",
		tostring(vacia), motivoVacia, Bolsa.capacidad(j), tostring(media), motivoMedia, quedan, n, tostring(llena), motivoLlena, tostring(vaciada), tostring(entro),
		ok(not vacia and motivoVacia == "nadaQueLanzar" and not media and motivoMedia == "bolsaNoLlena" and quedan == 2 and llena and vaciada and entro))
end

-- Lo que un cliente modificado puede mandar en LanzarObjetoEvent: nada de
-- ello lanza ni toca la bolsa ("argumentos"). Apuntar por encima de la valla
-- (fuera de los muros Limite, dentro del margen) sigue siendo valido
function Pruebas.lanzarArgumentosMalos()
	local j = jugador()
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, -20))
	task.wait(0.4)
	local n = Comunes.llenarBolsa(j, papel(6))
	local p = zona.Position
	local nan = 0 / 0
	local casos = {
		{ "NaN en x", Vector3.new(nan, p.Y, p.Z), 1 },
		{ "infinito en z", Vector3.new(p.X, p.Y, math.huge), 1 },
		{ "-infinito en y", Vector3.new(p.X, -math.huge, p.Z), 1 },
		{ "x = 20000", Vector3.new(2e4, p.Y, p.Z), 1 },
		{ "400 studs fuera del mapa", Vector3.new(p.X - 400, p.Y, p.Z), 1 },
		{ "a 900 de altura", Vector3.new(p.X, 900, p.Z), 1 },
		{ "fuerza NaN", p, nan },
		{ "fuerza infinita", p, math.huge },
		{ "fuerza 1e6", p, 1e6 },
		{ "punto texto", "0,0,0", 1 },
		{ "fuerza texto", p, "1" },
		{ "sin punto", nil, 1 },
	}
	local aceptados = {}
	for _, caso in casos do
		local lanzo, motivo = Botin.lanzarBolsa(j, caso[2], caso[3])
		if lanzo or motivo ~= "argumentos" then
			table.insert(aceptados, string.format("%s: lanzo=%s (%s)", caso[1], tostring(lanzo), tostring(motivo)))
		end
	end
	local intacta = Bolsa.cuenta(j) == n
	local porEncimaDeLaValla = Lanzamiento.argumentosValidos(Vector3.new(p.X, p.Y + 20, p.Z + 70), 0.5)
	local lanzo, motivo = Botin.lanzarBolsa(j, p, 1)
	task.wait(2.5)
	Bolsa.vaciar(j)
	return string.format("%d casos malos, aceptados [%s] | bolsa intacta (%d)=%s | por encima de la valla valido=%s | uno bueno: lanzo=%s (%s) => %s",
		#casos, table.concat(aceptados, "; "), n, tostring(intacta), tostring(porEncimaDeLaValla), tostring(lanzo), motivo,
		ok(#aceptados == 0 and intacta and porEncimaDeLaValla and lanzo))
end

-- El primer lanzamiento entra aunque se tire desde 60 studs y apuntando a
-- otro sitio, pero paga la distancia del Brazo (a nivel 0, 25 studs: +40 %,
-- no +150 %), no sube mejorDistanciaAcierto (las insignias de distancia) ni
-- el record del servidor, y alAcertar lleva la distancia recortada
function Pruebas.primeroSinRecord()
	local j = jugador()
	Comunes.limpiarBolsasCaidas(j)
	local p = Perfiles.obtener(j)
	local guardado = {
		lanzamientos = p.estadisticas.lanzamientos or 0,
		mejor = p.estadisticas.mejorDistanciaAcierto,
		brazo = p.mejoras.Brazo,
		racha = p.racha,
		rebirths = p.rebirths,
	}
	p.estadisticas.lanzamientos = 0
	p.estadisticas.mejorDistanciaAcierto = 0
	p.mejoras.Brazo = 0
	p.racha = 0
	p.rebirths = 0
	local brazo = Mejoras.valor(j, "Brazo")
	local DISTANCIA = 60
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, -DISTANCIA))
	task.wait(0.5)
	local n = Comunes.llenarBolsa(j, papel(10))
	local mult = Bolsa.multiplicadorDinero(j)
	local racha1 = DefinicionesPunteria.bonusRacha(1)
	local esperado = math.floor(n * 10 * (1 + DefinicionesPunteria.bonusDistancia(brazo) + racha1) * mult + 0.5)
	local sinRecorte = math.floor(n * 10 * (1 + DefinicionesPunteria.bonusDistancia(DISTANCIA) + racha1) * mult + 0.5)
	local recordAntes = Lanzamiento.recordServidor()
	local aciertosAntes = Perfiles.leerEstadistica(j, "aciertos")
	local distanciaSenal = nil
	local conexion = Lanzamiento.alAcertar:Connect(function(quien, distancia)
		if quien == j then
			distanciaSenal = distancia
		end
	end)
	local dinero0 = Economia.dinero(j)
	local lanzo, motivo = Botin.lanzarBolsa(j, zona.Position + Vector3.new(-40, 0, -60), 0.2)
	local limite = os.clock() + 5
	while Perfiles.leerEstadistica(j, "aciertos") == aciertosAntes and os.clock() < limite do
		task.wait(0.1)
	end
	task.wait(0.2)
	conexion:Disconnect()
	local cobrado = Economia.dinero(j) - dinero0
	local entro = Perfiles.leerEstadistica(j, "aciertos") > aciertosAntes
	local mejor = p.estadisticas.mejorDistanciaAcierto or 0
	local recordDespues = Lanzamiento.recordServidor()
	p.estadisticas.lanzamientos = math.max(guardado.lanzamientos, 1)
	p.estadisticas.mejorDistanciaAcierto = guardado.mejor
	p.mejoras.Brazo = guardado.brazo
	p.racha = guardado.racha
	p.rebirths = guardado.rebirths
	Perfiles.marcarSucio(j)
	return string.format("desde %d studs con el Brazo a %d: lanzo=%s (%s) entro=%s | cobrado $%d (esperado $%d; sin recorte serian $%d) | alAcertar distancia=%s | mejorDistanciaAcierto=%d | record del servidor %d -> %d => %s",
		DISTANCIA, brazo, tostring(lanzo), motivo, tostring(entro), cobrado, esperado, sinRecorte, tostring(distanciaSenal), mejor, recordAntes, recordDespues,
		ok(lanzo and entro and cobrado == esperado and distanciaSenal ~= nil and distanciaSenal <= brazo and mejor == 0 and recordDespues == recordAntes))
end

-- Con una bolsa en el suelo mas que el tope (3), la que se poso antes se
-- recicla sola para su dueno, sin bonus y a x0,5 (GameConfig.
-- MULT_MAL_SEPARADO, decision del usuario 23 oct). Cada bolsa lleva piezas
-- de valor 10k (la k-esima): asi se sabe cual se fue y lo que pago
function Pruebas.topeBolsasCaidas()
	local j = jugador()
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local desde, haciaPatio = sitioDeFallo()
	teletransportar(j, desde)
	task.wait(0.4)
	local tope = Lanzamiento.TOPE_BOLSAS_CAIDAS
	local mult = Bolsa.multiplicadorDinero(j)
	local n, lanzadas = 0, 0
	local dinero0 = Economia.dinero(j)
	for k = 1, tope + 1 do
		n = Comunes.llenarBolsa(j, papel(10 * k))
		if Botin.lanzarBolsa(j, haciaPatio, 0.5) then
			lanzadas += 1
		end
		task.wait(0.6) -- el cooldown de lanzar es 0,5 s
	end
	task.wait(4.5)
	local cobrado = Economia.dinero(j) - dinero0
	local esperado = math.floor(n * 10 * GameConfig.MULT_MAL_SEPARADO * mult + 0.5)
	local aX1 = math.floor(n * 10 * mult + 0.5)
	local quedan = ObjetosPatio.bolsasDe(j)
	local valores, esperados = {}, {}
	for _, obj in quedan do
		local primera = obj.item.contenido and obj.item.contenido[1]
		table.insert(valores, if primera then primera.valor else 0)
	end
	table.sort(valores)
	for k = 2, tope + 1 do
		table.insert(esperados, 10 * k)
	end
	local lista, listaEsperada = table.concat(valores, ","), table.concat(esperados, ",")
	Comunes.limpiarBolsasCaidas(j)
	return string.format("lanzadas %d | en el suelo %d (tope %d), de las bolsas [%s] (esperadas [%s]) | cobrado $%d (esperado $%d: la primera, sin bonus a x%s; a x1 serian $%d) => %s",
		lanzadas, #quedan, tope, lista, listaEsperada, cobrado, esperado, tostring(GameConfig.MULT_MAL_SEPARADO), aX1,
		ok(lanzadas == tope + 1 and #quedan == tope and lista == listaEsperada and cobrado == esperado))
end

-- Copia como la de un DataStore (JSON ida y vuelta)
local function copiaJson(valor)
	if valor == nil then
		return nil
	end
	return HttpService:JSONDecode(HttpService:JSONEncode(valor))
end

-- Almacen en memoria con la semantica de UpdateAsync (como en Datos);
-- alLlamar(clave) justo antes de la transformacion
local function almacenMemoria(alLlamar: ((string) -> ())?)
	local datos = {}
	local almacen = {}
	function almacen:UpdateAsync(clave, fn)
		if alLlamar then
			alLlamar(clave)
		end
		local nuevo = fn(copiaJson(datos[clave]))
		if nuevo ~= nil then
			datos[clave] = copiaJson(nuevo)
		end
		return nuevo
	end
	function almacen:GetAsync(clave)
		return copiaJson(datos[clave])
	end
	return almacen, datos
end

-- La salida del jugador (Lanzamiento.cobrarAlSalir, en Perfiles.alSalir):
-- 1) bolsa en el aire hacia el contenedor: se cobra al salir, sin bonus, y
--    al llegar ya no paga ni cuenta como acierto;
-- 2) bolsa en el aire hacia el suelo: se cobra al salir y no se queda en el
--    suelo de alguien que ya no esta;
-- 3) bolsa ya en el suelo: se recicla al salir;
-- 4) el orden real: Guardado.guardarSalida con un contexto de prueba (almacen
--    en memoria y su propia senal alSalir, conectada a cobrarAlSalir como la
--    del juego): la bolsa que esta en el aire al salir va en lo que se
--    escribe, y alSalir llega antes del guardado. No se usa la senal real
--    porque vaciaria tambien la bolsa en mano y publicaria los rankings, ni
--    el registro real del DataStore (lo soltaria).
function Pruebas.vueloAlSalir()
	local j = jugador()
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local zona = Mundo.zonaAcierto()
	local mult = Bolsa.multiplicadorDinero(j)
	local function sinBonus(n: number, valor: number): number
		return math.floor(n * valor * mult + 0.5)
	end

	-- 1)
	teletransportar(j, zona.Position + Vector3.new(0, 0, -20))
	task.wait(0.4)
	local n1 = Comunes.llenarBolsa(j, papel(10))
	local aciertos0 = Perfiles.leerEstadistica(j, "aciertos")
	local d0 = Economia.dinero(j)
	local lanzo1 = Botin.lanzarBolsa(j, zona.Position, 1)
	task.wait(0.25)
	Lanzamiento.cobrarAlSalir(j)
	local alSalir1 = Economia.dinero(j) - d0
	task.wait(2.5)
	local total1 = Economia.dinero(j) - d0
	local aciertos1 = Perfiles.leerEstadistica(j, "aciertos") - aciertos0
	local bien1 = lanzo1 and alSalir1 == sinBonus(n1, 10) and total1 == alSalir1 and aciertos1 == 0

	-- 2)
	local desde, haciaPatio = sitioDeFallo()
	teletransportar(j, desde)
	task.wait(0.4)
	local n2 = Comunes.llenarBolsa(j, papel(20))
	d0 = Economia.dinero(j)
	local lanzo2 = Botin.lanzarBolsa(j, haciaPatio, 0.5)
	task.wait(0.25)
	Lanzamiento.cobrarAlSalir(j)
	local alSalir2 = Economia.dinero(j) - d0
	task.wait(4.5)
	local total2 = Economia.dinero(j) - d0
	local enSuelo2 = #ObjetosPatio.bolsasDe(j)
	local bien2 = lanzo2 and alSalir2 == sinBonus(n2, 20) and total2 == alSalir2 and enSuelo2 == 0

	-- 3)
	local n3 = Comunes.llenarBolsa(j, papel(30))
	local lanzo3 = Botin.lanzarBolsa(j, haciaPatio, 0.5)
	task.wait(4.5)
	local enSuelo3 = #ObjetosPatio.bolsasDe(j)
	d0 = Economia.dinero(j)
	Lanzamiento.cobrarAlSalir(j)
	local alSalir3 = Economia.dinero(j) - d0
	local quedan3 = #ObjetosPatio.bolsasDe(j)
	local bien3 = lanzo3 and enSuelo3 == 1 and alSalir3 == sinBonus(n3, 30) and quedan3 == 0

	-- 4)
	local texto4, bien4 = "sin API (el perfil no cargo: no se guardaria)", true
	if Perfiles.estaCargado(j) then
		teletransportar(j, zona.Position + Vector3.new(0, 0, -20))
		task.wait(0.4)
		local n4 = Comunes.llenarBolsa(j, papel(40))
		local clave = Guardado.claveDe(j)
		local orden = {}
		local almacen, datos = almacenMemoria(function(c)
			if c == clave then
				table.insert(orden, "guardado")
			end
		end)
		local alSalir = Senal.nueva()
		alSalir:Connect(function(quien)
			if quien == j then
				Lanzamiento.cobrarAlSalir(quien)
				table.insert(orden, "alSalir")
			end
		end)
		local ctx = Guardado.nuevoContexto({
			almacen = almacen,
			alSalir = alSalir,
			expulsar = function() end,
			notificar = function() end,
			espera = function() end,
			sesionesStudioCaducan = false,
		})
		datos[clave] = { perfil = {}, sesion = { servidor = ctx.servidor, latido = os.time() } }
		local dinero0 = Economia.dinero(j)
		local lanzo4 = Botin.lanzarBolsa(j, zona.Position, 1)
		task.wait(0.25)
		local exito, guardo = pcall(Guardado.guardarSalida, j, "salida", ctx)
		local escrito = datos[clave] and datos[clave].perfil
		local dineroEscrito = if typeof(escrito) == "table" then escrito.dinero else nil
		task.wait(2.5) -- lo que tardaria en llegar al contenedor
		local total4 = Economia.dinero(j) - dinero0
		local esperado4 = dinero0 + sinBonus(n4, 40)
		bien4 = exito and guardo == true and lanzo4 and table.concat(orden, ",") == "alSalir,guardado"
			and dineroEscrito == esperado4 and total4 == sinBonus(n4, 40)
		texto4 = string.format("lanzo=%s, guardarSalida=%s, orden [%s], dinero escrito $%s (esperado $%d), en total +$%d",
			tostring(lanzo4), if exito then tostring(guardo) else ("error " .. tostring(guardo)), table.concat(orden, ","),
			tostring(dineroEscrito), esperado4, total4)
	end

	Bolsa.vaciar(j)
	return string.format("1) al contenedor: lanzo=%s, al salir $%d (esperado $%d), en total $%d, aciertos +%d | 2) al suelo: lanzo=%s, al salir $%d (esperado $%d), en total $%d, en el suelo %d | 3) ya en el suelo (%d): al salir $%d (esperado $%d), quedan %d | 4) con Guardado: %s => %s",
		tostring(lanzo1), alSalir1, sinBonus(n1, 10), total1, aciertos1,
		tostring(lanzo2), alSalir2, sinBonus(n2, 20), total2, enSuelo2,
		enSuelo3, alSalir3, sinBonus(n3, 30), quedan3, texto4,
		ok(bien1 and bien2 and bien3 and bien4))
end

-- Depuracion (para comprobar la salida de verdad, parando el Play): deja en
-- el suelo una bolsa llena fallada con piezas de `valor` y la mano vacia, y
-- dice cuanto deberia cobrarse al salir (sin bonus) y el dinero de ahora
function Pruebas.dejarBolsaCaida(valor)
	local j = jugador()
	Comunes.yaLanzo(j)
	Comunes.limpiarBolsasCaidas(j)
	local desde, haciaPatio = sitioDeFallo()
	teletransportar(j, desde)
	task.wait(0.4)
	local n = Comunes.llenarBolsa(j, papel(tonumber(valor) or 7))
	local lanzo, motivo = Botin.lanzarBolsa(j, haciaPatio, 0.5)
	task.wait(4.5)
	local esperado = math.floor(n * (tonumber(valor) or 7) * Bolsa.multiplicadorDinero(j) + 0.5)
	return string.format("lanzo=%s (%s) | en el suelo %d | al salir deberia cobrar $%d | dinero ahora $%d (en la mano %d)",
		tostring(lanzo), motivo, #ObjetosPatio.bolsasDe(j), esperado, Economia.dinero(j), Bolsa.cuenta(j))
end

-- Depuracion (falsos positivos de Movimiento jugando de verdad: andar,
-- saltar, caer, reaparecer): "empezar" pone a cero la cuenta de alSospechar
-- del jugador; "ver" dice cuantas hubo desde entonces y la ultima
local vigilancia = { conexion = nil :: any, cuenta = 0, ultima = nil :: any }
function Pruebas.vigilarSospechas(accion)
	local j = jugador()
	if accion == "empezar" then
		if not vigilancia.conexion then
			vigilancia.conexion = Movimiento.alSospechar:Connect(function(quien, datos)
				if quien == jugador() then
					vigilancia.cuenta += 1
					vigilancia.ultima = datos
				end
			end)
		end
		vigilancia.cuenta, vigilancia.ultima = 0, nil
		return "vigilando alSospechar de " .. j.Name
	end
	local d = vigilancia.ultima
	return string.format("alSospechar x%d desde 'empezar'%s | sospechoso ahora=%s | limite %.0f studs/s",
		vigilancia.cuenta,
		if d then string.format(" (la ultima: %.1f studs en %.2f s = %.0f studs/s)", d.distancia, d.segundos, d.velocidad) else "",
		tostring(Movimiento.sospechoso(j)), Movimiento.limite(j))
end

-- La pieza del monton mas cercana al jugador que este al alcance de la mano
-- y pueda llevarse (o nil)
local function piezaAlAlcance(j: Player, m): string?
	local root = j.Character and j.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local alcance = Mejoras.valor(j, "Alcance") + 2
	local mejor, dMejor = nil, math.huge
	for id, obj in Botin.objetos() do
		if obj.monton == m and not obj.reclamadoPor and ObjetosPatio.puedeReclamar(j, obj) then
			local d = Geometria.distanciaASuperficie(obj.modelo, root.Position)
			if d <= alcance and d < dMejor then
				mejor, dMejor = id, d
			end
		end
	end
	return mejor
end

local function reclamarCerca(j: Player, m): (boolean, string)
	local id = piezaAlAlcance(j, m)
	if not id then
		return false, "sinPieza"
	end
	local reclamado, motivo = Botin.reclamar(j, id, "clic")
	Bolsa.vaciar(j)
	return reclamado, motivo
end

-- Un salto que no dio el servidor (como el de un exploit: aqui un PivotTo sin
-- permitirSalto, desde la plaza a un monton al otro lado del patio) deja
-- SOSPECHA_SEGUNDOS sin recoger ("movimiento"), entregar a mano ni lanzar,
-- y se publica en alSospechar; luego todo vuelve. Lo primero se mira EN EL
-- MISMO INSTANTE del salto, sin ceder, antes de que llegue la muestra: el
-- exploit teletransporta y actua en el mismo frame (23 oct). El mismo viaje
-- con permitirSalto (teletransportar) no es sospecha, y con
-- Movimiento.ACTIVO apagado tampoco. La Velocidad va a 0 durante la prueba:
-- limite conocido y un salto de mas de 100 studs. Antes de cada salto sin
-- permiso se espera ECO_SEGUNDOS: vuelve al sitio del que el salto
-- permitido a la plaza lo saco, y eso cuenta como eco hasta entonces.
function Pruebas.teletransporte()
	local j = jugador()
	if not Movimiento.ACTIVO then
		return "Movimiento.ACTIVO esta apagado => FALLO"
	end
	local p = Perfiles.obtener(j)
	local velocidadAntes = p.mejoras.Velocidad
	p.mejoras.Velocidad = 0
	Comunes.yaLanzo(j)
	Bolsa.vaciar(j)
	local plaza = Comunes.fueraDelPatio()
	-- El monton lleno mas lejos de la plaza
	local m, dm = nil, -1
	for _, candidato in Comunes.montonesLlenos(1) do
		local d = (candidato.ranura.Position - plaza).Magnitude
		if d > dm then
			m, dm = candidato, d
		end
	end
	local junto = m.ranura.Position + Vector3.new(6, 0, 0)
	teletransportar(j, junto)
	task.wait(0.4)
	local excavado = Comunes.excavar(j, m)
	task.wait(1.8)

	local sospechas = {}
	local conexion = Movimiento.alSospechar:Connect(function(quien, datos)
		if quien == j then
			table.insert(sospechas, datos)
		end
	end)
	-- Vuelve al monton sin permiso y NO cede: quien llama mira en ese instante
	local function saltoSinPermiso()
		teletransportar(j, plaza)
		task.wait(Movimiento.ECO_SEGUNDOS + 0.4)
		local ch = j.Character
		if ch then
			ch:PivotTo(CFrame.new(junto + Vector3.new(0, 3, 0)))
		end
	end

	-- 1) Salto sin permiso y, en el mismo instante: sospecha, no recoge, no
	-- entrega a mano, no lanza
	saltoSinPermiso()
	local sospechoso1 = Movimiento.sospechoso(j)
	local reclamo1, motivo1 = reclamarCerca(j, m)
	Comunes.llenarBolsa(j)
	local mano1, motivoMano1 = Bolsa.depositar(j, nil)
	local lanzo1, motivoLanzo1 = Botin.lanzarBolsa(j, junto + Vector3.new(0, 0, -20), 0.3)
	Bolsa.vaciar(j)
	local nSospechas1 = #sospechas
	local datos = sospechas[1]
	-- Y sigue medio segundo despues (ya con la muestra)
	task.wait(0.5)
	local sospechoso1b = Movimiento.sospechoso(j)

	-- 2) Pasada la sospecha, todo normal
	local t0 = os.clock()
	while Movimiento.sospechoso(j) and os.clock() - t0 < 5 do
		task.wait(0.1)
	end
	local duro = os.clock() - t0
	local reclamo2, motivo2 = reclamarCerca(j, m)

	-- 3) El mismo viaje con permitirSalto: nada
	local nAntes3 = #sospechas
	teletransportar(j, plaza)
	task.wait(0.6)
	teletransportar(j, junto)
	task.wait(0.6)
	local sospechoso3 = Movimiento.sospechoso(j)
	local reclamo3, motivo3 = reclamarCerca(j, m)
	local nuevas3 = #sospechas - nAntes3

	-- 4) Con el interruptor apagado tampoco; al encenderlo se empieza de cero
	Movimiento.ACTIVO = false
	local ok4, err4 = pcall(saltoSinPermiso)
	local sospechoso4 = Movimiento.sospechoso(j)
	task.wait(0.5)
	Movimiento.ACTIVO = true
	task.wait(0.5)
	local sospechoso5 = Movimiento.sospechoso(j)

	conexion:Disconnect()
	p.mejoras.Velocidad = velocidadAntes
	Perfiles.marcarSucio(j)
	Bolsa.vaciar(j)
	teletransportar(j, plaza)
	return string.format("monton a %.0f studs de la plaza (excavado=%s) | sin permiso, en el mismo instante: sospechoso=%s, recoger=%s (%s), a mano=%s (%s), lanzar=%s (%s), alSospechar x%d (%s); medio segundo despues sospechoso=%s | a los %.1f s: recoger=%s (%s) | con permiso: sospechoso=%s, recoger=%s (%s), avisos nuevos %d | ACTIVO=false: sospechoso=%s%s, al encender=%s => %s",
		dm, tostring(excavado), tostring(sospechoso1), tostring(reclamo1), motivo1, tostring(mano1 ~= nil), tostring(motivoMano1),
		tostring(lanzo1), tostring(motivoLanzo1), nSospechas1,
		if datos then string.format("%.0f studs en %.2f s = %.0f studs/s, limite %.0f, exceso %.0f", datos.distancia, datos.segundos, datos.velocidad, datos.limite, datos.exceso) else "sin datos",
		tostring(sospechoso1b), duro, tostring(reclamo2), motivo2, tostring(sospechoso3), tostring(reclamo3), motivo3, nuevas3,
		tostring(sospechoso4), if ok4 then "" else " (error: " .. tostring(err4) .. ")", tostring(sospechoso5),
		ok(excavado and sospechoso1 and not reclamo1 and motivo1 == "movimiento" and mano1 == nil and motivoMano1 == "movimiento"
			and not lanzo1 and motivoLanzo1 == "movimiento" and sospechoso1b
			and nSospechas1 >= 1 and datos and datos.velocidad > datos.limite
			and duro <= Movimiento.SOSPECHA_SEGUNDOS + 1 and reclamo2
			and not sospechoso3 and reclamo3 and nuevas3 == 0
			and ok4 and not sospechoso4 and not sospechoso5))
end

-- CamaraEvent pasa por Patio.elegirVista: la primera se guarda; lo que llega
-- durante el cooldown no escribe el perfil, pero la ultima pedida se guarda
-- al acabarlo (una sola escritura); lo que no es "primera"/"tercera" se
-- descarta
function Pruebas.camaraCooldown()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = p.camara
	task.wait(Patio.COOLDOWN_VISTA + 0.1) -- sin cooldown de antes
	local ok1, motivo1 = Patio.elegirVista(j, "tercera")
	local tras1 = p.camara
	local escrituras, ultima = 0, p.camara
	local vigilante = RunService.Heartbeat:Connect(function()
		if p.camara ~= ultima then
			escrituras += 1
			ultima = p.camara
		end
	end)
	-- 21 peticiones alternas seguidas: la ultima es "primera"
	local rechazos = 0
	for i = 1, 21 do
		local aceptada = Patio.elegirVista(j, if i % 2 == 1 then "primera" else "tercera")
		if not aceptada then
			rechazos += 1
		end
	end
	local invalida, motivoInvalida = Patio.elegirVista(j, "cuarta")
	local durante = p.camara
	task.wait(Patio.COOLDOWN_VISTA + 0.3)
	local final = p.camara
	vigilante:Disconnect()
	-- Se deja como estaba (pasado el cooldown, a mano: el cliente no se entera)
	p.camara = antes
	Perfiles.marcarSucio(j)
	return string.format("primera peticion: %s (%s) -> %s | 21 durante el cooldown: %d rechazadas, perfil durante=%s | 'cuarta': %s (%s) | tras el cooldown: %s, %d escritura(s) => %s",
		tostring(ok1), motivo1, tostring(tras1), rechazos, tostring(durante), tostring(invalida), motivoInvalida, tostring(final), escrituras,
		ok(ok1 and tras1 == "tercera" and rechazos == 21 and durante == "tercera" and not invalida and motivoInvalida == "invalida" and final == "primera" and escrituras == 1))
end

-- Fuera de Studio el servidor no pone la pose de brazos cada frame (nadie ve
-- su vista). Sin ese bucle, un personaje nuevo que entra al patio se mide
-- igual (la pose un par de frames, una vez) y la bolsa se suelda delante del
-- torso entre las manos MEDIDAS, no las estimadas (que se van casi un stud).
-- Se vuelve a dejar el bucle como esta en Studio.
function Pruebas.poseSinBucle()
	local j = jugador()
	Patio.poseCadaFrame(false)
	local bien, resultado, cumple = pcall(function()
		Bolsa.vaciar(j)
		-- Personaje nuevo: sin medida guardada
		j:LoadCharacter()
		local ch = j.Character or j.CharacterAdded:Wait()
		ch:WaitForChild("HumanoidRootPart", 5)
		task.wait(0.8)
		local sinMedida = Patio.medidaManos(j) == nil
		teletransportar(j, Vector3.new(-26.25, 0, 0)) -- el camino entre las dos columnas del patio
		task.wait(1)
		local medida = Patio.medidaManos(j)
		local torso = ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")
		local bolsa = ch:FindFirstChild("BolsaEnManos")
		local delante = false
		if bolsa and torso then
			local l = torso.CFrame:PointToObjectSpace(bolsa:GetPivot().Position)
			delante = math.abs(l.X) < 0.5 and l.Z < -1.5
		end
		local _, estimada = PoseBrazos.puntoManos(ch)
		local diferencia = if medida and estimada then (medida.Position - estimada.Position).Magnitude else -1
		return string.format("personaje nuevo sin medida=%s | dentro: EnPatio=%s, medida=%s (%.2f studs de la estimacion), bolsa=%s delante=%s",
			tostring(sinMedida), tostring(j:GetAttribute("EnPatio")),
			if medida then string.format("(%.2f, %.2f, %.2f)", medida.X, medida.Y, medida.Z) else "no", diferencia,
			tostring(bolsa ~= nil), tostring(delante)),
			sinMedida and j:GetAttribute("EnPatio") == true and medida ~= nil and bolsa ~= nil and delante
	end)
	Patio.poseCadaFrame(true)
	Bolsa.vaciar(j)
	teletransportar(j, Comunes.fueraDelPatio())
	if not bien then
		return "error: " .. tostring(resultado) .. " => FALLO"
	end
	return resultado .. " => " .. ok(cumple)
end

return Pruebas
