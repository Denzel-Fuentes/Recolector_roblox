--!strict
--[[
	DefinicionesRecompensas
	Las recompensas de la economia v4 (paquete R1, 22 oct;
	docs/Economia-v4.md §4): el calendario de 7 casillas, los regalos por
	minutos activos del dia y el bono de regreso. Solo datos y cuentas puras:
	el servidor (Services/Recompensas) y el panel (UI/Recompensas) usan las
	mismas, asi el panel ensena exactamente lo que se va a cobrar.

	=== Premios ===
	  dinero  fraccion del coste del siguiente rebirth
	          (DefinicionesRebirths.costeSiguiente) redondeada a dos cifras
	          significativas (DefinicionesRebirths.redondear), y calculada AL
	          COBRAR con los rebirths de ese momento: un premio vale lo mismo,
	          en proporcion, con 0 rebirths que con 9, y cambiar la curva no
	          obliga a retocar nada de aqui. Las funciones leen las tablas al
	          llamarlas.
	  turbo   minutos de Turbo (Services/Turbo.anadir, que los suma al que
	          quede).
	Nada de esto se multiplica por pases ni por el Turbo (§1.6): nadie paga
	por recibir mas dinero gratis.

	=== Dias ===
	Los de DefinicionesPedidos.dia, el mismo reloj que los pedidos (con la
	economia v4 cambia a las 06:00 UTC). Las funciones de aqui reciben `hoy`
	ya calculado y no leen ningun reloj: quien las llama (servidor o panel)
	hace DefinicionesPedidos.dia(ahora).

	=== Calendario (§4.2 y §4.3) ===
	Una casilla por DIA JUGADO, con boton: `siguiente` espera hasta el dia en
	que se vuelva. Saltarse un dia no reinicia nada (con publico infantil,
	perder lo acumulado por no entrar es presion). La 7.a vuelve a la 1 y suma
	una vuelta; la primera vez que se cobra es la 7.a casilla cobrada
	(estadistica diasCalendario = 7) y Services/Insignias da la insignia
	INSIGNIA_SEMANA, que regala la Bolsa de carton (DefinicionesCosmeticos,
	forma insignia); desde la 2.a vuelta la casilla 7 suma turboDesdeVuelta2.

	=== Regalos (§4.5) ===
	Por minutos ACTIVOS del dia (un minuto con ACCIONES_MINUTO_ACTIVO o mas
	acciones de juego; ver Services/Actividad): se suman entre las sesiones
	del mismo dia, asi salir y volver no reinicia los tramos (por sesion,
	entrar y salir cada 5 min rendiria mas que jugar). Se dan solos. El
	ultimo es el de 60 min: no se premia jugar mas de una hora.

	=== Regreso (§4.4) ===
	Al entrar tras REGRESO[i].dias o mas sin un minuto activo, el primero
	que se cumpla (la lista va de mas a menos dias).

	Todo se abre con el paso PASO_DESBLOQUEO del tutorial (la primera mejora,
	el paso 5), como los pedidos; los minutos activos se cuentan desde el
	principio y al abrirse se dan de golpe los tramos ya pasados.
]]

local DefinicionesRebirths = require(script.Parent.DefinicionesRebirths)
local DefinicionesTutorial = require(script.Parent.DefinicionesTutorial)

-- Una casilla del calendario (dinero = fraccion; turbo = minutos)
export type Casilla = { dinero: number?, turbo: number?, turboDesdeVuelta2: number? }
-- Un tramo de regalos: a los `minutos` activos del dia
export type Regalo = { minutos: number, dinero: number?, turbo: number? }
-- Un bono de regreso: tras `dias` o mas sin jugar
export type Regreso = { dias: number, dinero: number?, turbo: number? }
-- Lo que se da de verdad: $ ya calculados y minutos de Turbo
export type Premio = { dinero: number, turbo: number }

-- La parte de perfil.recompensas que miran estas cuentas (Services/Perfiles)
export type Estado = {
	calendario: { siguiente: number, vueltas: number, ultimoDia: number },
	regalos: { dia: number, minutos: number, cobrados: number },
	ultimoDiaJugado: number,
}

local DefinicionesRecompensas = {}

-- Se abren con este paso del tutorial completado (como los pedidos)
DefinicionesRecompensas.PASO_DESBLOQUEO = "mejora"

DefinicionesRecompensas.CALENDARIO = {
	{ dinero = 0.02 },
	{ dinero = 0.02 },
	{ turbo = 10 },
	{ dinero = 0.03 },
	{ dinero = 0.03 },
	{ turbo = 15 },
	-- La 7.a cobrada da la insignia (ver cabecera); desde la 2.a vuelta,
	-- ademas Turbo
	{ dinero = 0.04, turboDesdeVuelta2 = 15 },
} :: { Casilla }

-- La insignia de la casilla 7 (DefinicionesInsignias: diasCalendario >= 7)
DefinicionesRecompensas.INSIGNIA_SEMANA = "semanaCompleta"

-- Acciones (avisos de Actividad.alAccion, como mucho uno por segundo) para
-- que un minuto cuente
DefinicionesRecompensas.ACCIONES_MINUTO_ACTIVO = 3

-- Minutos activos del dia (de menos a mas)
DefinicionesRecompensas.REGALOS = {
	{ minutos = 5, dinero = 0.005 },
	{ minutos = 10, dinero = 0.005 },
	{ minutos = 20, dinero = 0.01 },
	{ minutos = 30, turbo = 5 },
	{ minutos = 45, dinero = 0.01 },
	{ minutos = 60, dinero = 0.02 },
} :: { Regalo }

-- El primero que se cumpla (de mas a menos dias)
DefinicionesRecompensas.REGRESO = {
	{ dias = 14, dinero = 0.08, turbo = 30 },
	{ dias = 3, dinero = 0.04, turbo = 15 },
} :: { Regreso }

-- Las tablas en el orden que suponen las cuentas de abajo (como las sumas de
-- TablasProbabilidad): un cambio que las desordene falla al cargar
do
	assert(#DefinicionesRecompensas.CALENDARIO == 7, "DefinicionesRecompensas: el calendario tiene 7 casillas")
	for i, tramo in DefinicionesRecompensas.REGALOS do
		local anterior = DefinicionesRecompensas.REGALOS[i - 1]
		assert(tramo.minutos > 0 and (anterior == nil or tramo.minutos > anterior.minutos), "DefinicionesRecompensas: REGALOS va de menos a mas minutos")
	end
	for i, bono in DefinicionesRecompensas.REGRESO do
		local anterior = DefinicionesRecompensas.REGRESO[i - 1]
		assert(bono.dias > 0 and (anterior == nil or bono.dias < anterior.dias), "DefinicionesRecompensas: REGRESO va de mas a menos dias")
	end
end

-- $ de una fraccion del coste del siguiente rebirth con `rebirths` hechos
function DefinicionesRecompensas.dinero(fraccion: number?, rebirths: number): number
	if fraccion == nil or fraccion <= 0 then
		return 0
	end
	return DefinicionesRebirths.redondear(fraccion * DefinicionesRebirths.costeSiguiente(math.max(0, rebirths)))
end

-- Lo que da una definicion (casilla, tramo o bono) con `rebirths` hechos
function DefinicionesRecompensas.premio(def: { dinero: number?, turbo: number? }, rebirths: number): Premio
	return { dinero = DefinicionesRecompensas.dinero(def.dinero, rebirths), turbo = def.turbo or 0 }
end

-- Lo que da la casilla i (1..7) en la vuelta `vueltas` (0 = la primera)
function DefinicionesRecompensas.premioCasilla(i: number, vueltas: number, rebirths: number): Premio
	local casilla = DefinicionesRecompensas.CALENDARIO[i]
	local premio = DefinicionesRecompensas.premio(casilla, rebirths)
	if casilla.turboDesdeVuelta2 and vueltas >= 1 then
		premio.turbo += casilla.turboDesdeVuelta2
	end
	return premio
end

-- Si estan abiertas con `tutorial` pasos completados
function DefinicionesRecompensas.abiertas(tutorial: number?): boolean
	return (tutorial or 0) >= DefinicionesTutorial.indice(DefinicionesRecompensas.PASO_DESBLOQUEO)
end

-- La casilla en la que va (1..7), aunque el perfil traiga algo raro
function DefinicionesRecompensas.casillaActual(calendario: { siguiente: number }): number
	local n = math.floor(tonumber(calendario.siguiente) or 1)
	return math.clamp(n, 1, #DefinicionesRecompensas.CALENDARIO)
end

-- Si hoy aun no se cobro ninguna casilla. Con "mayor que" y no "distinto":
-- si el dia cambia de hora (06:00 UTC) y el de la ultima queda por delante
-- del de hoy, se espera a ese dia en vez de dejar cobrar otra vez
function DefinicionesRecompensas.diariaDisponible(calendario: { ultimoDia: number }, hoy: number): boolean
	return hoy > (tonumber(calendario.ultimoDia) or 0)
end

-- Minutos activos de HOY y tramos ya dados hoy (lo guardado de un dia
-- anterior no cuenta: los regalos son del dia). Un dia guardado POR DELANTE
-- de hoy (el dia pasa a cambiar a otra hora y queda unas horas atras) cuenta
-- como hoy, igual que diariaDisponible: asi nunca se dan dos veces
function DefinicionesRecompensas.regalosDeHoy(regalos: { dia: number, minutos: number, cobrados: number }, hoy: number): (number, number)
	if (tonumber(regalos.dia) or 0) < hoy then
		return 0, 0
	end
	return math.max(0, tonumber(regalos.minutos) or 0), math.max(0, tonumber(regalos.cobrados) or 0)
end

-- Cuantos tramos de REGALOS alcanzan `minutos` activos
function DefinicionesRecompensas.tramosAlcanzados(minutos: number): number
	local n = 0
	for i, tramo in DefinicionesRecompensas.REGALOS do
		if minutos >= tramo.minutos then
			n = i
		end
	end
	return n
end

-- El siguiente tramo por llegar con `minutos` activos (nil: ya estan todos)
function DefinicionesRecompensas.siguienteRegalo(minutos: number): Regalo?
	for _, tramo in DefinicionesRecompensas.REGALOS do
		if minutos < tramo.minutos then
			return tramo
		end
	end
	return nil
end

-- El bono que toca tras `dias` sin jugar (nil: ninguno)
function DefinicionesRecompensas.regreso(dias: number): Regreso?
	for _, bono in DefinicionesRecompensas.REGRESO do
		if dias >= bono.dias then
			return bono
		end
	end
	return nil
end

-- Si hay algo que reclamar con un boton (el punto rojo del HUD): abiertas y
-- la casilla de hoy sin cobrar. Los regalos y el regreso se dan solos
function DefinicionesRecompensas.hayAlgo(perfil: { tutorial: number?, recompensas: Estado? }, hoy: number): boolean
	local estado = perfil.recompensas
	return estado ~= nil and DefinicionesRecompensas.abiertas(perfil.tutorial)
		and DefinicionesRecompensas.diariaDisponible(estado.calendario, hoy)
end

return DefinicionesRecompensas
