--!nonstrict
--[[
	Pruebas de las recompensas (R1, 22 oct, economia v4): el calendario de 7
	casillas, los regalos por minutos activos y el bono de regreso
	(Services/Recompensas, docs/Economia-v4.md §4).

	  diariaCalendario            las 7 casillas en 7 dias: lo que paga cada
	                              una (% del siguiente rebirth, Turbo), la
	                              vuelta a la 1, la 7 de la 2.a vuelta con
	                              Turbo y que el premio sale de los rebirths
	                              del momento de cobrar
	  diariaUnaVezAlDia           una al dia aunque se pida 10 veces, tambien
	                              al final del mismo dia; al siguiente, la
	                              siguiente; con el dia de la ultima por
	                              delante (cambio de hora del dia), nada
	  diariaSaltarDia             saltarse dias no reinicia nada
	  diariaCasilla7              la 7.a cobrada da la insignia Constante y
	                              con ella la Bolsa de carton
	  regresoTrasDias             3 y 14 dias sin jugar (Perfiles.anterior):
	                              Turbo 15 min + 4 % y Turbo 30 min + 8 %; con
	                              2 dias, sin jugar nunca o con el tutorial a
	                              medias, nada; una vez por perfil
	  regalosMinutosActivos       un minuto con menos de 3 acciones no cuenta;
	                              los 6 tramos del dia y al dia siguiente de
	                              cero; Actividad.alAccion llega cableado
	  recompensaBloqueadaTutorial antes del paso 5 nada se cobra (los minutos
	                              si se cuentan) y al abrirse los regalos
	                              pasados se dan de golpe
	  recompensaRemoteMalo        lo que mandaria un cliente modificado por
	                              RecompensaEvent no hace nada

	Usan al jugador de Play Solo con el reloj y el dia inyectados
	(Recompensas.ahora) y no tocan nada fuera de lo suyo: Turbo.anadir se
	cambia por un espia (se miran los segundos pedidos, no como los guarda
	Turbo, que cambia por dentro con K1), los avisos al cliente se apuntan en
	vez de mandarse (Recompensas.notificar y alCliente) y lo que tocan del
	perfil y de la sesion se guarda y se restaura. No ceden mientras dura lo
	inyectado: ningun otro hilo ve el reloj de mentira ni publica el perfil a
	medias. (El filtro del RecompensasHandler, texto corto y cooldown, no se
	puede probar desde el servidor: solo un cliente dispara OnServerEvent.)
	diariaCasilla7 llama a Insignias.comprobar como la prueba insignias: con
	el badgeId de semanaCompleta a 0 no se pide nada a Roblox, pero el
	cliente ensena la tarjeta de la insignia.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local DefinicionesRecompensas = require(Config:WaitForChild("DefinicionesRecompensas"))
local DefinicionesRebirths = require(Config:WaitForChild("DefinicionesRebirths"))
local DefinicionesPedidos = require(Config:WaitForChild("DefinicionesPedidos"))
local DefinicionesTutorial = require(Config:WaitForChild("DefinicionesTutorial"))
local DefinicionesCosmeticos = require(Config:WaitForChild("DefinicionesCosmeticos"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Turbo = require(Servicios:WaitForChild("Turbo"))
local Insignias = require(Servicios:WaitForChild("Insignias"))
local Actividad = require(Servicios:WaitForChild("Actividad"))
local Recompensas = require(Servicios:WaitForChild("Recompensas"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador = Comunes.jugador

local Pruebas = {}

local CAMPOS_SESION = { "acciones", "entrada", "regreso", "avisado" }
local PASO_ABRE = DefinicionesTutorial.indice(DefinicionesRecompensas.PASO_DESBLOQUEO)

local function ok(cond: any): string
	return if cond then "OK" else "FALLO"
end

local function copiaProfunda(valor: any): any
	if typeof(valor) ~= "table" then
		return valor
	end
	local copia = {}
	for clave, v in valor do
		copia[clave] = copiaProfunda(v)
	end
	return copia
end

local function sumar(lista: { number }): number
	local total = 0
	for _, n in lista do
		total += n
	end
	return total
end

-- La clave del ultimo aviso apuntado ("RECOMPENSAS.cobrado"...) y sus valores
local function ultimoAviso(e): (string?, any)
	local m = e.avisos[#e.avisos]
	if typeof(m) == "table" then
		return m.k, m.v
	end
	return nil, nil
end

local function contarAvisos(e, clave: string): number
	local n = 0
	for _, m in e.avisos do
		if typeof(m) == "table" and m.k == clave then
			n += 1
		end
	end
	return n
end

-- El entorno de cada prueba (ver cabecera). fn(e) recibe:
--   e.j, e.p        el jugador y su perfil
--   e.irA(k)        el reloj al mismo instante de hace/dentro de k dias
--   e.reloj         el instante del reloj inyectado (se puede fijar)
--   e.hoy0          el dia de hoy (de verdad); Recompensas.hoy() el inyectado
--   e.turbo         segundos de cada Turbo.anadir del jugador
--   e.avisos        mensajes de cada toast (Idioma.mensaje)
--   e.cliente       { accion, datos } de cada envio por RecompensaEvent
--   e.reclamos      { tipo, reclamo } de cada Recompensas.alReclamar
-- Todo vuelve a como estaba al acabar, haya ido bien o no
local function entorno(fn: (any) -> string): string
	local j = jugador()
	local p = Perfiles.obtener(j)
	if not p then
		return "sin perfil => FALLO"
	end
	local copia = {
		recompensas = copiaProfunda(p.recompensas),
		dinero = p.dinero,
		estadisticas = table.clone(p.estadisticas),
		tutorial = p.tutorial,
		rebirths = p.rebirths,
		logros = table.clone(p.logros),
	}
	local sesion = Recompensas.sesion(j)
	local copiaSesion = {}
	for _, campo in CAMPOS_SESION do
		copiaSesion[campo] = sesion[campo]
	end
	local antes = {
		ahora = Recompensas.ahora,
		notificar = Recompensas.notificar,
		alCliente = Recompensas.alCliente,
		anadir = Turbo.anadir,
		anterior = Perfiles.anterior,
	}
	local t0 = os.time()
	local e = {
		j = j,
		p = p,
		reloj = t0,
		hoy0 = DefinicionesPedidos.dia(t0),
		turbo = {},
		avisos = {},
		cliente = {},
		reclamos = {},
		anteriorReal = antes.anterior,
	}
	function e.irA(k: number)
		e.reloj = t0 + k * 86400
	end
	Recompensas.ahora = function()
		return e.reloj
	end
	Recompensas.notificar = function(quien, mensaje)
		if quien == j then
			table.insert(e.avisos, mensaje)
		end
	end
	Recompensas.alCliente = function(quien, accion, datos)
		if quien == j then
			table.insert(e.cliente, { accion, datos })
		end
	end
	Turbo.anadir = function(quien, segundos)
		if quien == j then
			table.insert(e.turbo, segundos)
		end
	end
	local conexion = Recompensas.alReclamar:Connect(function(quien, tipo, reclamo)
		if quien == j then
			table.insert(e.reclamos, { tipo, reclamo })
		end
	end)

	local exito, resultado = pcall(fn, e)

	conexion:Disconnect()
	Recompensas.ahora = antes.ahora
	Recompensas.notificar = antes.notificar
	Recompensas.alCliente = antes.alCliente
	Turbo.anadir = antes.anadir
	Perfiles.anterior = antes.anterior
	for clave, v in copia do
		p[clave] = v
	end
	for _, campo in CAMPOS_SESION do
		sesion[campo] = copiaSesion[campo]
	end
	Perfiles.marcarSucio(j)
	if not exito then
		return "error: " .. tostring(resultado) .. " => FALLO"
	end
	return resultado
end

-- Un perfil con las recompensas abiertas, 0 rebirths y todo por estrenar
local function preparar(e)
	e.p.tutorial = DefinicionesTutorial.TOTAL
	e.p.rebirths = 0
	e.p.recompensas = {
		calendario = { siguiente = 1, vueltas = 0, ultimoDia = 0 },
		regalos = { dia = 0, minutos = 0, cobrados = 0 },
		ultimoDiaJugado = 0,
	}
	e.p.estadisticas.diasCalendario = 0
	e.p.estadisticas.minutosActivos = 0
	Recompensas.sesion(e.j).acciones = 0
end

-- Cobra la diaria y dice cuanto dio: (exito, motivo, $, s de Turbo)
local function cobrar(e): (boolean, string?, number, number)
	local dineroAntes = e.p.dinero
	local turboAntes = #e.turbo
	local exito, motivo = Recompensas.reclamarDiaria(e.j)
	local turbo = 0
	for i = turboAntes + 1, #e.turbo do
		turbo += e.turbo[i]
	end
	return exito, motivo, e.p.dinero - dineroAntes, turbo
end

-- ===========================================================================
-- Calendario
-- ===========================================================================

function Pruebas.diariaCalendario()
	return entorno(function(e)
		preparar(e)
		local cal = e.p.recompensas.calendario
		local filas, malos = {}, {}
		for casilla = 1, 7 do
			e.irA(casilla)
			local exito, motivo, dinero, turbo = cobrar(e)
			local def = DefinicionesRecompensas.CALENDARIO[casilla]
			local esperado = DefinicionesRecompensas.dinero(def.dinero, 0)
			local esperadoTurbo = (def.turbo or 0) * 60
			local clave, valores = ultimoAviso(e)
			table.insert(filas, string.format("%d:$%d%s", casilla, dinero, if turbo > 0 then "+T" .. turbo .. "s" else ""))
			if not exito or dinero ~= esperado or turbo ~= esperadoTurbo or clave ~= "RECOMPENSAS.cobrado" or (valores and valores.n) ~= casilla then
				table.insert(malos, string.format("casilla %d: %s (%s) $%d/%d T%d/%d aviso %s", casilla, tostring(exito), tostring(motivo), dinero, esperado, turbo, esperadoTurbo, tostring(clave)))
			end
		end
		-- Las de dinero son su % del siguiente rebirth (con 0 rebirths)
		local base = DefinicionesRebirths.costeSiguiente(0)
		local porcentaje = DefinicionesRecompensas.dinero(0.02, 0) == DefinicionesRebirths.redondear(0.02 * base)
			and DefinicionesRecompensas.dinero(0.04, 0) == DefinicionesRebirths.redondear(0.04 * base)
		local tras7 = { cal.siguiente, cal.vueltas, cal.ultimoDia - e.hoy0, e.p.estadisticas.diasCalendario }
		local vuelta = tras7[1] == 1 and tras7[2] == 1 and tras7[3] == 7
		local dias = tras7[4] == 7
		local reclamo = e.reclamos[#e.reclamos]
		local senal = #e.reclamos == 7 and reclamo[1] == "calendario" and reclamo[2].casilla == 7 and reclamo[2].vuelta == 1
		-- 2.a vuelta: la 7 suma Turbo 15 min
		cal.siguiente = 7
		e.irA(20)
		local exito7, _, dinero7, turbo7 = cobrar(e)
		local vuelta2 = exito7 and turbo7 == 15 * 60 and dinero7 == DefinicionesRecompensas.dinero(0.04, 0) and cal.vueltas == 2 and cal.siguiente == 1
		-- Con un rebirth, la misma casilla paga su % del rebirth siguiente
		e.p.rebirths = 1
		e.irA(21)
		local exito1, _, dinero1 = cobrar(e)
		local conRebirth = exito1 and dinero1 == DefinicionesRebirths.redondear(0.02 * DefinicionesRebirths.costeSiguiente(1)) and dinero1 > DefinicionesRecompensas.dinero(0.02, 0)
		return string.format(
			"%s | %% del siguiente rebirth=%s | tras la 7: casilla %d, vuelta %d, ultimoDia=hoy+%d, diasCalendario %d | alReclamar=%s | 7 de la 2.a vuelta: +T%ds $%d=%s | con 1 rebirth la 1 paga $%d=%s | malos [%s] => %s",
			table.concat(filas, " "), tostring(porcentaje), tras7[1], tras7[2], tras7[3], tras7[4], tostring(senal),
			turbo7, dinero7, tostring(vuelta2), dinero1, tostring(conRebirth), table.concat(malos, "; "),
			ok(#malos == 0 and porcentaje and vuelta and dias and senal and vuelta2 and conRebirth)
		)
	end)
end

function Pruebas.diariaUnaVezAlDia()
	return entorno(function(e)
		preparar(e)
		local cal = e.p.recompensas.calendario
		e.irA(0)
		local primera, _, dinero = cobrar(e)
		local segunda, motivo, dinero2 = cobrar(e)
		-- Diez veces mas por el remote, el mismo dia
		local aceptadas = 0
		for _ = 1, 10 do
			if Recompensas.peticion(e.j, "diaria") then
				aceptadas += 1
			end
		end
		-- La ultima hora de hoy sigue siendo hoy
		local t = e.reloj
		while DefinicionesPedidos.dia(t + 3600) == e.hoy0 do
			t += 3600
		end
		e.reloj = t
		local tarde = cobrar(e)
		local tras = { cal.siguiente, e.p.estadisticas.diasCalendario }
		-- Al dia siguiente, la siguiente casilla
		e.irA(1)
		local manana, _, dineroManana = cobrar(e)
		local avanza = manana and cal.siguiente == 3 and dineroManana == DefinicionesRecompensas.dinero(DefinicionesRecompensas.CALENDARIO[2].dinero, 0)
		-- Si el dia de la ultima va por delante del de hoy (el dia pasa a
		-- cambiar a otra hora), se espera a ese dia
		cal.ultimoDia = e.hoy0 + 5
		e.irA(2)
		local adelantada, motivoAdelantada = cobrar(e)
		return string.format(
			"1.a: %s ($%d) | 2.a el mismo dia: %s (%s, $%d) | 10 por el remote: %d aceptadas | a ultima hora: %s | tras hoy: casilla %d, diasCalendario %d | manana: %s, casilla 3=%s | ultima por delante: %s (%s) => %s",
			tostring(primera), dinero, tostring(segunda), tostring(motivo), dinero2, aceptadas, tostring(tarde), tras[1], tras[2],
			tostring(manana), tostring(avanza), tostring(adelantada), tostring(motivoAdelantada),
			ok(primera and dinero > 0 and not segunda and motivo == "yaCobrada" and dinero2 == 0 and aceptadas == 0 and not tarde
				and tras[1] == 2 and tras[2] == 1 and avanza and not adelantada and motivoAdelantada == "yaCobrada")
		)
	end)
end

function Pruebas.diariaSaltarDia()
	return entorno(function(e)
		preparar(e)
		local cal = e.p.recompensas.calendario
		-- Cobro la 2 hoy: va por la 3
		cal.siguiente = 2
		e.irA(0)
		local hoy = cobrar(e)
		-- Cinco dias sin jugar: la 3 espera (Turbo 10 min), no se reinicia
		e.irA(5)
		local exito3, _, dinero3, turbo3 = cobrar(e)
		local _, valores3 = ultimoAviso(e)
		local tras3 = { cal.siguiente, cal.vueltas }
		-- Un mes despues, la 4
		e.irA(35)
		local exito4, _, dinero4 = cobrar(e)
		return string.format(
			"hoy la 2: %s | 5 dias despues: %s, la casilla %s (T%ds, $%d) -> va por la %d, vuelta %d | un mes despues: %s, $%d (la 4) => %s",
			tostring(hoy), tostring(exito3), tostring(valores3 and valores3.n), turbo3, dinero3, tras3[1], tras3[2], tostring(exito4), dinero4,
			ok(hoy and exito3 and valores3 and valores3.n == 3 and turbo3 == 10 * 60 and dinero3 == 0 and tras3[1] == 4 and tras3[2] == 0
				and exito4 and dinero4 == DefinicionesRecompensas.dinero(DefinicionesRecompensas.CALENDARIO[4].dinero, 0) and cal.siguiente == 5)
		)
	end)
end

function Pruebas.diariaCasilla7()
	return entorno(function(e)
		preparar(e)
		local p = e.p
		local cal = p.recompensas.calendario
		local carton
		for _, d in DefinicionesCosmeticos.BOLSAS do
			if d.insignia == DefinicionesRecompensas.INSIGNIA_SEMANA then
				carton = d
			end
		end
		local function tieneCarton(): boolean
			return carton ~= nil and DefinicionesCosmeticos.loTiene(carton, p.rebirths, function()
				return false
			end, function(id)
				return p.logros[id] == true
			end)
		end
		p.logros[DefinicionesRecompensas.INSIGNIA_SEMANA] = nil
		p.estadisticas.diasCalendario = 6
		cal.siguiente = 7
		cal.ultimoDia = e.hoy0 - 1
		local antes = tieneCarton()
		e.irA(0)
		local exito, _, dinero, turbo = cobrar(e)
		local dias = p.estadisticas.diasCalendario
		-- La insignia la da Services/Insignias al ver diasCalendario = 7 (en el
		-- siguiente cambio del perfil; aqui se llama sin esperar)
		Insignias.comprobar(e.j)
		local insignia = p.logros[DefinicionesRecompensas.INSIGNIA_SEMANA] == true
		local despues = tieneCarton()
		return string.format(
			"casilla 7 de la 1.a vuelta: %s, $%d (esperado %d), T%ds | diasCalendario %d | insignia %s=%s | Bolsa de carton antes=%s despues=%s | vuelve a la %d, vuelta %d => %s",
			tostring(exito), dinero, DefinicionesRecompensas.dinero(0.04, 0), turbo, dias, DefinicionesRecompensas.INSIGNIA_SEMANA, tostring(insignia),
			tostring(antes), tostring(despues), cal.siguiente, cal.vueltas,
			ok(exito and dinero == DefinicionesRecompensas.dinero(0.04, 0) and turbo == 0 and dias == 7 and insignia and carton ~= nil
				and not antes and despues and cal.siguiente == 1 and cal.vueltas == 1)
		)
	end)
end

-- ===========================================================================
-- Regreso
-- ===========================================================================

function Pruebas.regresoTrasDias()
	return entorno(function(e)
		preparar(e)
		local p = e.p
		e.irA(0)
		local hoy = Recompensas.hoy()
		-- Entra con el perfil de antes de entrar (Perfiles.anterior) diciendo
		-- que jugo por ultima vez hace `dias` (nil = nunca)
		local function entrar(dias: number?, vivo: number?)
			local ultimo = if dias then hoy - dias else 0
			local anterior = { tutorial = p.tutorial, recompensas = { ultimoDiaJugado = ultimo } }
			Perfiles.anterior = function(quien)
				return if quien == e.j then anterior else e.anteriorReal(quien)
			end
			p.recompensas.ultimoDiaJugado = vivo or ultimo
			local s = Recompensas.sesion(e.j)
			s.entrada = nil
			s.regreso = nil
			e.cliente = {}
			local dineroAntes = p.dinero
			local turboAntes = #e.turbo
			local reclamo = Recompensas.alEntrar(e.j, p)
			Recompensas.avisarEntrada(e.j)
			local ventana = nil
			for _, envio in e.cliente do
				if envio[1] == "regreso" then
					ventana = envio[2]
				end
			end
			local turbo = 0
			for i = turboAntes + 1, #e.turbo do
				turbo += e.turbo[i]
			end
			return { reclamo = reclamo, dinero = p.dinero - dineroAntes, turbo = turbo, ventana = ventana, ultimo = p.recompensas.ultimoDiaJugado }
		end
		local function nada(r): boolean
			return r.reclamo == nil and r.dinero == 0 and r.turbo == 0 and r.ventana == nil
		end
		local dos = entrar(2)
		local tres = entrar(3)
		local trece = entrar(13)
		local catorce = entrar(14)
		local nunca = entrar(nil)
		-- Con un minuto activo ya contado hoy en el perfil vivo, cuenta lo de
		-- antes de entrar
		local conMinuto = entrar(3, hoy)
		-- Una vez por perfil: entrar otra vez con el mismo no da nada
		local otraVez = Recompensas.alEntrar(e.j, p)
		-- Con el tutorial a medias (jugador nuevo), nada
		p.tutorial = PASO_ABRE - 1
		local nuevo = entrar(20)
		p.tutorial = DefinicionesTutorial.TOTAL
		local cuatro = DefinicionesRecompensas.dinero(0.04, 0)
		local ocho = DefinicionesRecompensas.dinero(0.08, 0)
		local function bono(r, dinero, minutos, dias): boolean
			return r.reclamo ~= nil and r.dinero == dinero and r.turbo == minutos * 60 and r.ultimo == hoy
				and typeof(r.ventana) == "table" and r.ventana.dias == dias and typeof(r.ventana.texto) == "table"
				and r.ventana.texto.k == "RECOMPENSAS.regresoTexto"
		end
		local senal = false
		for _, r in e.reclamos do
			if r[1] == "regreso" and r[2].tramo == 14 and r[2].dias == 14 then
				senal = true
			end
		end
		return string.format(
			"2 dias: nada=%s | 3: $%d T%ds ventana=%s | 13: $%d T%ds | 14: $%d T%ds | nunca jugo: nada=%s | con un minuto de hoy ya contado: $%d | otra vez el mismo perfil: %s | tutorial a medias: nada=%s | alReclamar regreso=%s (esperados 3: $%d T900s, 14: $%d T1800s) => %s",
			tostring(nada(dos)), tres.dinero, tres.turbo, tostring(tres.ventana ~= nil), trece.dinero, trece.turbo, catorce.dinero, catorce.turbo,
			tostring(nada(nunca)), conMinuto.dinero, tostring(otraVez), tostring(nada(nuevo)), tostring(senal), cuatro, ocho,
			ok(nada(dos) and bono(tres, cuatro, 15, 3) and bono(trece, cuatro, 15, 13) and bono(catorce, ocho, 30, 14) and nada(nunca)
				and bono(conMinuto, cuatro, 15, 3) and otraVez == nil and nada(nuevo) and senal)
		)
	end)
end

-- ===========================================================================
-- Regalos por minutos activos
-- ===========================================================================

-- Un minuto con `acciones` avisos de Actividad; devuelve si conto
local function minuto(e, acciones: number): boolean
	for _ = 1, acciones do
		Recompensas.anotarAccion(e.j)
	end
	return Recompensas.cerrarMinuto(e.j)
end

function Pruebas.regalosMinutosActivos()
	return entorno(function(e)
		preparar(e)
		local p = e.p
		e.irA(0)
		local hoy = Recompensas.hoy()
		-- El cableado: Actividad.alAccion llega a anotarAccion
		local antesCable = Recompensas.accionesEnMinuto(e.j)
		Actividad.alAccion:Fire(e.j)
		local cableado = Recompensas.accionesEnMinuto(e.j) == antesCable + 1
		Recompensas.sesion(e.j).acciones = 0
		-- Menos de 3 acciones no cuentan
		local conDos = minuto(e, 2)
		local conCero = minuto(e, 0)
		local minutosFlojos = (DefinicionesRecompensas.regalosDeHoy(p.recompensas.regalos, hoy))
		-- 60 minutos activos: los 6 tramos, cada uno en su minuto
		local dadosEn = {}
		local dineroPorTramo = {}
		local turboPorTramo = {}
		local malos = {}
		for m = 1, 61 do
			local dineroAntes, turboAntes, cobradosAntes = p.dinero, #e.turbo, p.recompensas.regalos.cobrados
			if not minuto(e, 3) then
				table.insert(malos, "minuto " .. m .. " no conto")
			end
			if p.recompensas.regalos.cobrados > cobradosAntes then
				table.insert(dadosEn, m)
				dineroPorTramo[m] = p.dinero - dineroAntes
				local t = 0
				for i = turboAntes + 1, #e.turbo do
					t += e.turbo[i]
				end
				turboPorTramo[m] = t
			end
		end
		for _, tramo in DefinicionesRecompensas.REGALOS do
			local esperado = DefinicionesRecompensas.dinero(tramo.dinero, 0)
			if dineroPorTramo[tramo.minutos] ~= esperado or turboPorTramo[tramo.minutos] ~= (tramo.turbo or 0) * 60 then
				table.insert(malos, string.format("tramo %d: $%s/%d T%s", tramo.minutos, tostring(dineroPorTramo[tramo.minutos]), esperado, tostring(turboPorTramo[tramo.minutos])))
			end
		end
		local avisos = contarAvisos(e, "RECOMPENSAS.regalo")
		local regalos = p.recompensas.regalos
		local estadistica = p.estadisticas.minutosActivos
		local jugado = p.recompensas.ultimoDiaJugado
		-- Al dia siguiente, de cero
		e.irA(1)
		local nuevoDia = minuto(e, 3)
		local reinicio = p.recompensas.regalos.dia == hoy + 1 and p.recompensas.regalos.minutos == 1 and p.recompensas.regalos.cobrados == 0
		-- Un dia guardado por delante de hoy (el dia cambia de hora) cuenta
		-- como hoy: ni se reinicia ni se vuelve a dar el tramo de 5
		p.recompensas.regalos = { dia = hoy + 2, minutos = 7, cobrados = 1 }
		p.recompensas.ultimoDiaJugado = hoy + 2
		local dineroAdelantado = p.dinero
		local adelantado = minuto(e, 3)
		local sigue = p.recompensas.regalos.dia == hoy + 2 and p.recompensas.regalos.minutos == 8 and p.recompensas.regalos.cobrados == 1
			and p.dinero == dineroAdelantado and p.recompensas.ultimoDiaJugado == hoy + 2
		return string.format(
			"cableado=%s | 2 acciones: %s, 0: %s -> %d min | 61 minutos de 3 acciones: regalos en los minutos [%s], %d avisos, dia %d con %d min y %d tramos | minutosActivos %d, ultimoDiaJugado=hoy %s | al dia siguiente: %s, de cero=%s | dia guardado por delante: cuenta=%s, sigue sin repetir=%s | malos [%s] => %s",
			tostring(cableado), tostring(conDos), tostring(conCero), minutosFlojos, table.concat(dadosEn, ","), avisos, regalos.dia - hoy, regalos.minutos,
			regalos.cobrados, estadistica, tostring(jugado == hoy), tostring(nuevoDia), tostring(reinicio), tostring(adelantado), tostring(sigue),
			table.concat(malos, "; "),
			ok(cableado and not conDos and not conCero and minutosFlojos == 0 and table.concat(dadosEn, ",") == "5,10,20,30,45,60" and avisos == 6
				and regalos.minutos == 61 and regalos.cobrados == 6 and estadistica == 61 and jugado == hoy and nuevoDia and reinicio
				and adelantado and sigue and #malos == 0)
		)
	end)
end

-- ===========================================================================
-- Tutorial y remote
-- ===========================================================================

function Pruebas.recompensaBloqueadaTutorial()
	return entorno(function(e)
		preparar(e)
		local p = e.p
		p.tutorial = PASO_ABRE - 1
		p.recompensas.calendario.ultimoDia = e.hoy0 - 3
		e.irA(0)
		local hoy = Recompensas.hoy()
		local dineroAntes = p.dinero
		local diaria, motivo = Recompensas.reclamarDiaria(e.j)
		local porRemote = Recompensas.peticion(e.j, "diaria")
		local hayAlgo = Recompensas.hayAlgo(e.j)
		-- Los minutos se cuentan, los regalos no se dan
		for _ = 1, 12 do
			minuto(e, 3)
		end
		local minutos, cobrados = DefinicionesRecompensas.regalosDeHoy(p.recompensas.regalos, hoy)
		local cerrado = p.dinero == dineroAntes and #e.turbo == 0
		-- Regreso: con el tutorial a medias, no
		local anterior = { tutorial = p.tutorial, recompensas = { ultimoDiaJugado = hoy - 20 } }
		Perfiles.anterior = function(quien)
			return if quien == e.j then anterior else e.anteriorReal(quien)
		end
		Recompensas.sesion(e.j).entrada = nil
		local regreso = Recompensas.alEntrar(e.j, p)
		-- Se abren (el paso 5): el aviso y los regalos de 5 y 10 min de golpe
		p.tutorial = PASO_ABRE
		local avisosAntes = #e.avisos
		Recompensas.alAbrirse(e.j)
		local abiertas = false
		for i = avisosAntes + 1, #e.avisos do
			local m = e.avisos[i]
			if typeof(m) == "table" and m.k == "RECOMPENSAS.abiertas" then
				abiertas = true
			end
		end
		local _, cobradosTras = DefinicionesRecompensas.regalosDeHoy(p.recompensas.regalos, hoy)
		local deGolpe = p.dinero - dineroAntes
		local esperado = DefinicionesRecompensas.dinero(DefinicionesRecompensas.REGALOS[1].dinero, 0) + DefinicionesRecompensas.dinero(DefinicionesRecompensas.REGALOS[2].dinero, 0)
		local ahoraHay = Recompensas.hayAlgo(e.j)
		local ahoraDiaria = Recompensas.reclamarDiaria(e.j)
		return string.format(
			"tutorial %d: diaria %s (%s), por el remote %s, hayAlgo %s | 12 min activos: %d min contados, %d tramos, sin pagar=%s | regreso tras 20 dias: %s | al abrirse: aviso=%s, tramos %d, $%d de golpe (esperado %d) | despues hayAlgo %s y la diaria se cobra %s => %s",
			PASO_ABRE - 1, tostring(diaria), tostring(motivo), tostring(porRemote), tostring(hayAlgo), minutos, cobrados, tostring(cerrado), tostring(regreso),
			tostring(abiertas), cobradosTras, deGolpe, esperado, tostring(ahoraHay), tostring(ahoraDiaria),
			ok(not diaria and motivo == "cerradas" and not porRemote and not hayAlgo and minutos == 12 and cobrados == 0 and cerrado
				and regreso == nil and abiertas and cobradosTras == 2 and deGolpe == esperado and ahoraHay and ahoraDiaria)
		)
	end)
end

function Pruebas.recompensaRemoteMalo()
	return entorno(function(e)
		preparar(e)
		local p = e.p
		e.irA(0)
		local cal = p.recompensas.calendario
		local function foto(): string
			return string.format("%d|%d|%d|%d|%d", p.dinero, cal.siguiente, cal.vueltas, cal.ultimoDia, p.estadisticas.diasCalendario or 0)
		end
		local antes = foto()
		local casos = {
			{ "nil" },
			{ "numero", 5 },
			{ "NaN", 0 / 0 },
			{ "infinito", math.huge },
			{ "booleano", true },
			{ "tabla", {} },
			{ "lista con la accion", { "diaria" } },
			{ "tabla con la accion", { accion = "diaria" } },
			{ "funcion", function() end },
			{ "Vector3", Vector3.new(1, 2, 3) },
			{ "el propio jugador", e.j },
			{ "mayusculas", "DIARIA" },
			{ "con espacio", "diaria " },
			{ "vacio", "" },
			{ "otra accion", "regalos" },
			{ "regreso", "regreso" },
			{ "metodo", "__index" },
			{ "muy largo", string.rep("diaria", 5000) },
		}
		local aceptados = {}
		for _, caso in casos do
			local exito, motivo = Recompensas.peticion(e.j, caso[2])
			if exito or motivo ~= "argumentos" then
				table.insert(aceptados, string.format("%s: %s (%s)", caso[1], tostring(exito), tostring(motivo)))
			end
		end
		local intacto = foto() == antes and #e.turbo == 0
		-- 20 peticiones buenas seguidas: una sola cobra
		local buenas = 0
		for _ = 1, 20 do
			if Recompensas.peticion(e.j, "diaria") then
				buenas += 1
			end
		end
		return string.format("%d casos malos: aceptados [%s], perfil intacto=%s | 20 \"diaria\" seguidas: %d cobradas, casilla %d => %s",
			#casos, table.concat(aceptados, "; "), tostring(intacto), buenas, cal.siguiente,
			ok(#aceptados == 0 and intacto and buenas == 1 and cal.siguiente == 2 and p.estadisticas.diasCalendario == 1))
	end)
end

return Pruebas
