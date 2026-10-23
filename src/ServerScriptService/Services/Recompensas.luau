--!strict
--[[
	Recompensas (ModuleScript)
	Unica responsabilidad: las recompensas de la economia v4 de cada jugador
	(paquete R1, 22 oct; perfil.recompensas, Config/DefinicionesRecompensas,
	docs/Economia-v4.md §4): el calendario de 7 casillas (se cobra con el
	boton del panel: RecompensaEvent "diaria"), los regalos por minutos
	activos del dia (se dan solos) y el bono de regreso (se da solo al
	entrar, con una ventana de bienvenida). El cableado (senales, remote,
	cooldown, cuando avisar) esta en RecompensasHandler.

	=== Como se paga ===
	Dinero con Economia.ganar, como los pedidos: no pasa por pases ni Turbo.
	Turbo SOLO por Turbo.anadir(jugador, segundos), la firma que Turbo
	mantiene mientras cambia por dentro (K1: solo corre jugando). El premio
	en $ se calcula al cobrar (DefinicionesRecompensas.premio...), con los
	rebirths de ese momento.

	=== Minutos activos ===
	Actividad.alAccion llega como mucho una vez por segundo y jugador
	(anotarAccion las cuenta); cada tic de 60 s de Perfiles.alMinuto cierra
	el minuto (cerrarMinuto): con ACCIONES_MINUTO_ACTIVO o mas es activo,
	suma la estadistica minutosActivos, pone ultimoDiaJugado y cuenta para
	los regalos del dia. Se cuentan aunque las recompensas esten cerradas
	(tutorial < 5): al abrirse (alAbrirse, el paso 5) se dan de golpe los
	tramos ya pasados. No se escuchan las senales del juego directamente: lo
	que es una accion lo decide Actividad.

	=== Regreso ===
	alEntrar lo mira UNA vez por perfil cargado, con Perfiles.anterior (el
	perfil tal y como llego del DataStore): asi no depende de que ningun otro
	oyente de alCargar, ni un minuto activo, haya tocado ya ultimoDiaJugado.
	Solo con el tutorial en el paso 5 o mas y ultimoDiaJugado > 0: un jugador
	nuevo nunca lo recibe. Al darlo, ultimoDiaJugado pasa a hoy (entrar 10 s
	cada 3 dias da como mucho un bono cada 3 dias). La ventana se manda
	despues (avisarEntrada), cuando la UI del cliente ya esta montada.

	=== Orden al cobrar ===
	Primero el estado del perfil (la casilla avanza, el tramo cuenta) y
	despues el pago: nada de aqui cede, y si el pago fallara, lo peor es no
	cobrarlo, nunca cobrarlo dos veces.

	El reloj es Recompensas.ahora (os.time; las pruebas lo sustituyen) y el
	dia, DefinicionesPedidos.dia de ese reloj. Tambien sustituibles en las
	pruebas: notificar (el toast, NotificacionEvent) y alCliente
	(RecompensaEvent hacia el cliente: "regreso" abre la ventana, "premio"
	suena). alReclamar avisa de cada premio dado (la analitica).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local DefinicionesRecompensas = require(Config:WaitForChild("DefinicionesRecompensas"))
local DefinicionesPedidos = require(Config:WaitForChild("DefinicionesPedidos"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Red = require(Utilidades:WaitForChild("Red"))
local Idioma = require(Utilidades:WaitForChild("Idioma"))
local Senal = require(Utilidades:WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Turbo = require(Servicios:WaitForChild("Turbo"))

local NotificacionEvent = Red.evento("NotificacionEvent")
local RecompensaEvent = Red.evento("RecompensaEvent")

type Perfil = Perfiles.Perfil
type Premio = DefinicionesRecompensas.Premio

-- Lo que se dio, para quien escucha alReclamar (la analitica: Calendario_3,
-- Regalo_20, Regreso_14...)
export type Reclamo = {
	dinero: number, -- $ dados
	turbo: number, -- minutos de Turbo dados
	casilla: number?, -- calendario: la casilla cobrada (1..7)
	vuelta: number?, -- calendario: la vuelta (1 = la primera semana)
	minutos: number?, -- regalo: el tramo (5, 10, 20...)
	dias: number?, -- regreso: dias sin jugar
	tramo: number?, -- regreso: el tramo que se cumplio (3 o 14)
}

-- Lo de la sesion de cada jugador (no se guarda)
export type Sesion = {
	acciones: number, -- avisos de Actividad en el minuto en curso
	entrada: Perfil?, -- el perfil cuyo regreso ya se miro
	regreso: any?, -- la ventana del regreso por mandar ({ texto, dias })
	avisado: number, -- dia del ultimo aviso de "tu premio esta listo"
}

local Recompensas = {}

-- Reloj en s (UTC), sustituible en las pruebas (como Pedidos.ahora)
Recompensas.ahora = os.time

-- (jugador, tipo, reclamo) cada premio dado; tipo "calendario" | "regalo" |
-- "regreso"
Recompensas.alReclamar = Senal.nueva() :: Senal.Senal<Player, string, Reclamo>

-- El toast (ver cabecera)
function Recompensas.notificar(jugador: Player, mensaje: any, tipo: string)
	NotificacionEvent:FireClient(jugador, mensaje, tipo)
end

-- RecompensaEvent hacia el cliente (ver cabecera)
function Recompensas.alCliente(jugador: Player, accion: string, datos: any)
	RecompensaEvent:FireClient(jugador, accion, datos)
end

local sesiones: { [Player]: Sesion } = {}

-- Lo de la sesion de un jugador (se crea al pedirlo; las pruebas lo guardan
-- y lo restauran). Solo se guarda la de quien sigue en el juego: lo que
-- llegue tarde de quien ya se fue (su ultimo alMinuto llega mientras se
-- guarda su perfil) no deja una entrada para siempre
function Recompensas.sesion(jugador: Player): Sesion
	local existente = sesiones[jugador]
	if existente then
		return existente
	end
	local nueva: Sesion = { acciones = 0, entrada = nil, regreso = nil, avisado = 0 }
	if jugador.Parent ~= nil then
		sesiones[jugador] = nueva
	end
	return nueva
end

-- Olvida la sesion (al salir)
function Recompensas.olvidar(jugador: Player)
	sesiones[jugador] = nil
end

function Recompensas.hoy(): number
	return DefinicionesPedidos.dia(Recompensas.ahora())
end

function Recompensas.abiertas(jugador: Player): boolean
	local perfil = Perfiles.obtener(jugador)
	return perfil ~= nil and DefinicionesRecompensas.abiertas(perfil.tutorial)
end

-- Si tiene algo que reclamar con el boton (la casilla de hoy)
function Recompensas.hayAlgo(jugador: Player): boolean
	local perfil = Perfiles.obtener(jugador)
	return perfil ~= nil and DefinicionesRecompensas.hayAlgo(perfil, Recompensas.hoy())
end

-- El premio como mensaje (Idioma): "$1.000", "Turbo 10 min" o "$2.000 y
-- Turbo 15 min"
function Recompensas.mensajePremio(premio: Premio): any
	local dinero = if premio.dinero > 0 then Idioma.dinero(premio.dinero) else nil
	local turbo = if premio.turbo > 0 then Idioma.mensaje("RECOMPENSAS.premioTurbo", { minutos = premio.turbo }) else nil
	if dinero and turbo then
		return Idioma.mensaje("RECOMPENSAS.premioY", { a = dinero, b = turbo })
	end
	return dinero or turbo or Idioma.dinero(0)
end

local function pagar(jugador: Player, premio: Premio)
	if premio.dinero > 0 then
		Economia.ganar(jugador, premio.dinero)
	end
	if premio.turbo > 0 then
		Turbo.anadir(jugador, premio.turbo * 60)
	end
	Perfiles.marcarSucio(jugador)
end

-- ===========================================================================
-- Calendario
-- ===========================================================================

-- Cobra la casilla de hoy. Devuelve (true) o (false, motivo): "sinPerfil",
-- "cerradas" (tutorial < 5) o "yaCobrada" (hoy ya cobro una)
function Recompensas.reclamarDiaria(jugador: Player): (boolean, string?)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false, "sinPerfil"
	end
	if not DefinicionesRecompensas.abiertas(perfil.tutorial) then
		return false, "cerradas"
	end
	local hoy = Recompensas.hoy()
	local calendario = perfil.recompensas.calendario
	if not DefinicionesRecompensas.diariaDisponible(calendario, hoy) then
		return false, "yaCobrada"
	end
	local casilla = DefinicionesRecompensas.casillaActual(calendario)
	local vueltas = math.max(0, math.floor(tonumber(calendario.vueltas) or 0))
	local premio = DefinicionesRecompensas.premioCasilla(casilla, vueltas, perfil.rebirths)
	-- Primero el estado (ver cabecera)
	calendario.ultimoDia = hoy
	if casilla >= #DefinicionesRecompensas.CALENDARIO then
		calendario.siguiente = 1
		calendario.vueltas = vueltas + 1
	else
		calendario.siguiente = casilla + 1
		calendario.vueltas = vueltas
	end
	-- Casillas cobradas en total: la 7.a da la insignia (Services/Insignias la
	-- ve en el siguiente cambio del perfil)
	Perfiles.estadistica(jugador, "diasCalendario", 1)
	pagar(jugador, premio)
	Recompensas.sesion(jugador).avisado = hoy -- el "listo" de hoy ya sobra
	Recompensas.notificar(jugador, Idioma.mensaje("RECOMPENSAS.cobrado", { n = casilla, premio = Recompensas.mensajePremio(premio) }),
		if premio.dinero > 0 then "dinero" else "exito")
	Recompensas.alCliente(jugador, "premio", "calendario")
	Recompensas.alReclamar:Fire(jugador, "calendario", { dinero = premio.dinero, turbo = premio.turbo, casilla = casilla, vuelta = vueltas + 1 })
	return true, nil
end

-- ===========================================================================
-- Regalos por minutos activos
-- ===========================================================================

-- Una accion de juego (Actividad.alAccion, ver cabecera)
function Recompensas.anotarAccion(jugador: Player)
	if jugador.Parent == nil then
		return
	end
	local s = Recompensas.sesion(jugador)
	s.acciones += 1
end

-- Acciones contadas en el minuto en curso
function Recompensas.accionesEnMinuto(jugador: Player): number
	local s = sesiones[jugador]
	return if s then s.acciones else 0
end

-- Da los tramos de hoy ya alcanzados que aun no se dieron (solo abiertas).
-- Devuelve cuantos dio
function Recompensas.darRegalos(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil or not DefinicionesRecompensas.abiertas(perfil.tutorial) then
		return 0
	end
	local regalos = perfil.recompensas.regalos
	local minutos, cobrados = DefinicionesRecompensas.regalosDeHoy(regalos, Recompensas.hoy())
	local alcanzados = DefinicionesRecompensas.tramosAlcanzados(minutos)
	local dados = 0
	for i = cobrados + 1, alcanzados do
		local tramo = DefinicionesRecompensas.REGALOS[i]
		local premio = DefinicionesRecompensas.premio(tramo, perfil.rebirths)
		regalos.cobrados = i
		pagar(jugador, premio)
		dados += 1
		Recompensas.notificar(jugador, Idioma.mensaje("RECOMPENSAS.regalo", { n = tramo.minutos, premio = Recompensas.mensajePremio(premio) }),
			if premio.dinero > 0 then "dinero" else "exito")
		Recompensas.alReclamar:Fire(jugador, "regalo", { dinero = premio.dinero, turbo = premio.turbo, minutos = tramo.minutos })
	end
	if dados > 0 then
		Recompensas.alCliente(jugador, "premio", "regalo")
	end
	return dados
end

-- El tic de 60 s (Perfiles.alMinuto): cierra el minuto en curso. Devuelve
-- si fue activo
function Recompensas.cerrarMinuto(jugador: Player): boolean
	-- (quien ya se fue no juega: su perfil aun se esta guardando)
	local perfil = Perfiles.obtener(jugador)
	if not perfil or jugador.Parent == nil then
		return false
	end
	local s = Recompensas.sesion(jugador)
	local acciones = s.acciones
	s.acciones = 0
	local activo = acciones >= DefinicionesRecompensas.ACCIONES_MINUTO_ACTIVO
	if activo then
		local hoy = Recompensas.hoy()
		local estado = perfil.recompensas
		-- Los dias guardados nunca van hacia atras (ver regalosDeHoy en
		-- DefinicionesRecompensas: el dia puede cambiar de hora)
		estado.ultimoDiaJugado = math.max(tonumber(estado.ultimoDiaJugado) or 0, hoy)
		if (tonumber(estado.regalos.dia) or 0) < hoy then
			-- Un dia nuevo: los regalos empiezan de cero
			estado.regalos = { dia = hoy, minutos = 0, cobrados = 0 }
		end
		estado.regalos.minutos += 1
		Perfiles.estadistica(jugador, "minutosActivos", 1)
		Recompensas.darRegalos(jugador)
	end
	-- Con la sesion abierta al cambiar de dia, el aviso de la casilla nueva
	Recompensas.avisarSiHayAlgo(jugador)
	return activo
end

-- ===========================================================================
-- Al abrirse, al entrar y avisos
-- ===========================================================================

-- El paso del tutorial que las abre: el aviso y los regalos ya ganados hoy
function Recompensas.alAbrirse(jugador: Player)
	if not Recompensas.abiertas(jugador) then
		return
	end
	Recompensas.sesion(jugador).avisado = Recompensas.hoy() -- (este aviso ya lo dice)
	Recompensas.notificar(jugador, Idioma.mensaje("RECOMPENSAS.abiertas"), "exito")
	Recompensas.darRegalos(jugador)
end

-- El bono de regreso que toca a `perfil` con `antes` (el perfil al entrar,
-- Perfiles.anterior), o nil. Lo da: dinero, Turbo, ultimoDiaJugado = hoy y
-- la ventana pendiente. Sin mirar si ya se miro en esta sesion (alEntrar)
function Recompensas.comprobarRegreso(jugador: Player, perfil: Perfil, antes: any): Reclamo?
	if not DefinicionesRecompensas.abiertas(perfil.tutorial) then
		return nil
	end
	local estadoAntes = if typeof(antes) == "table" then antes.recompensas else nil
	local ultimo = if typeof(estadoAntes) == "table" then (tonumber(estadoAntes.ultimoDiaJugado) or 0) else 0
	if ultimo <= 0 then
		return nil
	end
	local hoy = Recompensas.hoy()
	local dias = hoy - ultimo
	local bono = DefinicionesRecompensas.regreso(dias)
	if not bono then
		return nil
	end
	local premio = DefinicionesRecompensas.premio(bono, perfil.rebirths)
	perfil.recompensas.ultimoDiaJugado = math.max(tonumber(perfil.recompensas.ultimoDiaJugado) or 0, hoy)
	pagar(jugador, premio)
	Recompensas.sesion(jugador).regreso = {
		texto = Idioma.mensaje("RECOMPENSAS.regresoTexto", { premio = Recompensas.mensajePremio(premio) }),
		dias = dias,
	}
	local reclamo: Reclamo = { dinero = premio.dinero, turbo = premio.turbo, dias = dias, tramo = bono.dias }
	Recompensas.alReclamar:Fire(jugador, "regreso", reclamo)
	return reclamo
end

-- Al cargar el perfil (Perfiles.alCargar): el regreso, una vez por perfil
-- (un provisional sustituido por el guardado se mira otra vez: el guardado
-- no tiene lo que se dio al provisional)
function Recompensas.alEntrar(jugador: Player, perfil: Perfil): Reclamo?
	local s = Recompensas.sesion(jugador)
	if s.entrada == perfil or jugador.Parent == nil then
		return nil
	end
	s.entrada = perfil
	return Recompensas.comprobarRegreso(jugador, perfil, Perfiles.anterior(jugador) or perfil)
end

-- "Tu premio del dia esta listo", una vez al dia por sesion. Devuelve si
-- aviso
function Recompensas.avisarSiHayAlgo(jugador: Player): boolean
	local s = Recompensas.sesion(jugador)
	local hoy = Recompensas.hoy()
	if s.avisado == hoy or not Recompensas.hayAlgo(jugador) then
		return false
	end
	s.avisado = hoy
	Recompensas.notificar(jugador, Idioma.mensaje("RECOMPENSAS.listo"), "exito")
	return true
end

-- Unos segundos despues de entrar (RecompensasHandler): la ventana del
-- regreso si se dio, los regalos que quedaran por dar y el aviso
function Recompensas.avisarEntrada(jugador: Player)
	if jugador.Parent == nil or not Perfiles.obtener(jugador) then
		return
	end
	local s = Recompensas.sesion(jugador)
	local regreso = s.regreso
	s.regreso = nil
	if regreso then
		Recompensas.alCliente(jugador, "regreso", regreso)
	end
	Recompensas.darRegalos(jugador)
	Recompensas.avisarSiHayAlgo(jugador)
end

-- ===========================================================================
-- Lo que pide el cliente (RecompensaEvent)
-- ===========================================================================

local ACCIONES: { [string]: (Player) -> (boolean, string?) } = {
	diaria = function(jugador)
		return Recompensas.reclamarDiaria(jugador)
	end,
}

-- La peticion del cliente tal cual llega (un cliente modificado puede mandar
-- cualquier cosa): solo un nombre de ACCIONES. Devuelve (exito, motivo);
-- "argumentos" si no es una accion
function Recompensas.peticion(jugador: Player, accion: any): (boolean, string?)
	if typeof(accion) ~= "string" then
		return false, "argumentos"
	end
	local hacer = ACCIONES[accion]
	if not hacer then
		return false, "argumentos"
	end
	return hacer(jugador)
end

return Recompensas
