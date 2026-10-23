--!strict
--[[
	Ofertas (ModuleScript)
	Unica responsabilidad: decidir cuando se le ensena una oferta a cada
	jugador y llevar la cuenta de lo que se le ensena (perfil.ofertas), con
	las reglas de Config/DefinicionesOfertas (economia v4, K1 22 oct;
	docs/Economia-v4.md §5.6). La ventana es del cliente (UI/Oferta) y la
	compra la confirma siempre la de Roblox: aqui no se vende nada.

	=== El viaje de una oferta ===
	  1 Un disparador (momento): tras un deposito (Bolsa.alDepositar) o al
	    renacer (Rebirths.alRenacer); lo cablea OfertasHandler. Se arma el
	    contexto (perfil, sesion, pases) y DefinicionesOfertas.elegir dice
	    cual, por prioridad. Si hay, va al cliente por OfertaEvent con un
	    token: { id, token, momento, espera, titulo, texto, icono, opciones }
	    (titulo y texto son Idioma.mensaje: el servidor no monta texto).
	  2 El cliente busca un momento tranquilo (sin panel, sin celebracion,
	    sin cargar un lanzamiento) durante `espera` s. Si lo encuentra, abre
	    la ventana y responde "mostrada": SOLO entonces cuenta (vistas,
	    ultima, historial, la de la sesion). Si no, "descartada" (o nada: a
	    los `espera` s mas un margen caduca) y no cuenta.
	  3 Luego "ahoraNo" (el boton, la X o Esc: suma un rechazo) o "comprar"
	    (lanza el prompt de Roblox en el cliente). Si la compra se completa,
	    Monetizacion lo avisa (compra) y se cierra; si el jugador cancela la
	    ventana de Roblox, la oferta sigue abierta y aun puede decir "Ahora no".
	Una oferta a la vez por jugador. Lo que manda el cliente solo cuenta con
	el token de la que tiene: un cliente que mintiera solo cambia sus
	propias ofertas (y no puede sumar vistas ni rechazos dos veces).

	=== Por que el cliente avisa de los intentos con la bolsa llena ===
	El disparador de Bolsa XL cuenta los intentos de recoger con la bolsa
	llena, pero ControlPatio no llega a pedir el reclamo con la bolsa llena
	(sacude la barra y ya). El cliente manda "bolsaLlena" por un intento
	(UI/Oferta lo agrupa) y aqui solo se cuenta si de verdad la bolsa esta
	llena en el servidor, como mucho uno cada OFERTAS_BOLSA_LLENA_CADA s.

	=== Relojes ===
	Ofertas.ahora (os.time) para lo que se guarda (ultima, historial, la
	compra de hace 24 h) y Ofertas.reloj (os.clock) para la sesion (sus
	minutos, la espera del momento). Los dos y enviarCliente se sustituyen
	en la prueba ofertaReglas.

	alMostrar(jugador, id) y alResponder(jugador, id, respuesta, opcion?)
	("ahoraNo", "comprar", "aceptada") quedan para la analitica (§7.2).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Productos = require(Config:WaitForChild("Productos"))
local DefinicionesOfertas = require(Config:WaitForChild("DefinicionesOfertas"))
local DefinicionesRebirths = require(Config:WaitForChild("DefinicionesRebirths"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Idioma = require(Utilidades:WaitForChild("Idioma"))
local Red = require(Utilidades:WaitForChild("Red"))
local Senal = require(Utilidades:WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Turbo = require(Servicios:WaitForChild("Turbo"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))

local OfertaEvent = Red.evento("OfertaEvent")

type Opcion = DefinicionesOfertas.Opcion
type Definicion = DefinicionesOfertas.Definicion

-- La oferta que tiene el jugador: enviada (aun sin ensenar) o ensenada
type Actual = {
	token: number,
	id: string,
	opciones: { Opcion },
	mostrada: boolean,
	hasta: number, -- en Ofertas.reloj: caduca
}

export type Sesion = {
	inicio: number, -- Ofertas.reloj() al cargar el perfil
	mostradas: number,
	porId: { [string]: number },
	enviadas: number,
	token: number,
	intentosBolsaLlena: number,
	ultimoIntento: number,
	turboGanadoAcabado: boolean,
	actual: Actual?,
	ventana: number, -- inicio de la ventana de 1 s del limite del remote
	enVentana: number,
}

export type Datos = {
	id: string,
	token: number,
	momento: string,
	espera: number,
	titulo: Idioma.Mensaje,
	texto: Idioma.Mensaje,
	icono: string,
	opciones: { Opcion },
}

local Ofertas = {}

Ofertas.ahora = os.time
Ofertas.reloj = os.clock
-- Por donde sale una oferta al cliente (la prueba la captura)
Ofertas.enviarCliente = function(jugador: Player, datos: Datos)
	OfertaEvent:FireClient(jugador, datos)
end

-- (jugador, id de la oferta) al ensenarse
Ofertas.alMostrar = Senal.nueva() :: Senal.Senal<Player, string>
-- (jugador, id de la oferta, "ahoraNo" | "comprar" | "aceptada", opcion?)
Ofertas.alResponder = Senal.nueva() :: Senal.Senal<Player, string, string, string?>

-- s de mas para el "mostrada" de una oferta que se abrio al final de su espera
local MARGEN_ESPERA = 5
-- Una ensenada sin respuesta (se fue a mitad, un cliente roto) se olvida a los
local VIDA_MOSTRADA = 600
-- Envios por sesion como mucho: un cliente que nunca dice "mostrada" no
-- recibe una oferta en cada deposito
local MAX_ENVIADAS = 4

local ACCIONES = { mostrada = true, descartada = true, ahoraNo = true, comprar = true, bolsaLlena = true }

local sesiones: { [Player]: Sesion } = {}

local function nuevaSesion(): Sesion
	return {
		inicio = Ofertas.reloj(),
		mostradas = 0,
		porId = {},
		enviadas = 0,
		token = 0,
		intentosBolsaLlena = 0,
		ultimoIntento = -math.huge,
		turboGanadoAcabado = false,
		actual = nil,
		ventana = -math.huge,
		enVentana = 0,
	}
end

-- Al cargar el perfil. Si ya habia sesion (un perfil provisional que
-- sustituye el guardado), sigue la misma: no vuelven a empezar sus minutos
function Ofertas.entrar(jugador: Player)
	if not sesiones[jugador] then
		sesiones[jugador] = nuevaSesion()
	end
end

function Ofertas.salir(jugador: Player)
	sesiones[jugador] = nil
end

-- La sesion de ofertas del jugador (pruebas)
function Ofertas.sesion(jugador: Player): Sesion?
	return sesiones[jugador]
end

-- Empieza otra sesion de ofertas con los relojes de ahora (pruebas)
function Ofertas.reiniciarSesion(jugador: Player): Sesion
	local s = nuevaSesion()
	sesiones[jugador] = s
	return s
end

-- El id de Roblox de un pase o un producto de Config/Productos (0 = sin crear)
function Ofertas.idRoblox(tipo: string, id: string): number
	if tipo == "pase" then
		local pase = Productos.PASE_POR_ID[id]
		return if pase then pase.gamePassId else 0
	end
	local producto = Productos.PRODUCTO_POR_ID[id]
	return if producto then producto.productId else 0
end

function Ofertas.contexto(jugador: Player, momento: string, rebirthHecho: number?): DefinicionesOfertas.Contexto?
	local perfil = Perfiles.obtener(jugador)
	local s = sesiones[jugador]
	if not perfil or not s then
		return nil
	end
	return {
		momento = momento,
		rebirthHecho = rebirthHecho,
		ahora = Ofertas.ahora(),
		tutorial = perfil.tutorial or 0,
		sesion = perfil.estadisticas.sesiones or 0,
		segundosSesion = Ofertas.reloj() - s.inicio,
		mostradasSesion = s.mostradas,
		mostradasSesionPorId = s.porId,
		historial = perfil.ofertas.historial,
		porId = perfil.ofertas.porId,
		ultimaRobux = perfil.compras.ultimaRobux or 0,
		rebirths = perfil.rebirths,
		turboRestante = Turbo.restante(jugador),
		intentosBolsaLlena = s.intentosBolsaLlena,
		nivelBolsa = Mejoras.nivel(jugador, "Bolsa"),
		turboGanadoAcabado = s.turboGanadoAcabado,
		tienePase = function(id: string): boolean
			return Monetizacion.tienePase(jugador, id)
		end,
		idRoblox = Ofertas.idRoblox,
	}
end

local function caducar(s: Sesion)
	local actual = s.actual
	if actual and Ofertas.reloj() > actual.hasta then
		s.actual = nil
	end
end

local function tieneOpcion(actual: Actual, id: string): boolean
	for _, opcion in actual.opciones do
		if opcion.id == id then
			return true
		end
	end
	return false
end

-- Los {valores} de su titulo y su texto
local function valoresDe(def: Definicion, ctx: DefinicionesOfertas.Contexto): { [string]: any }?
	if def.valores == "multiplicador" then
		local m = DefinicionesRebirths.multiplicador(ctx.rebirths)
		return { mult = Idioma.multiplicador(m), mult2 = Idioma.multiplicador(m * 2) }
	end
	return nil
end

local function enviar(jugador: Player, s: Sesion, def: Definicion, ctx: DefinicionesOfertas.Contexto)
	s.token += 1
	s.enviadas += 1
	local opciones = DefinicionesOfertas.opciones(def, ctx)
	local espera = DefinicionesOfertas.GLOBAL.esperaMomento
	s.actual = { token = s.token, id = def.id, opciones = opciones, mostrada = false, hasta = Ofertas.reloj() + espera + MARGEN_ESPERA }
	local valores = valoresDe(def, ctx)
	Ofertas.enviarCliente(jugador, {
		id = def.id,
		token = s.token,
		momento = if def.momento == "rebirth" then "rebirth" else "deposito",
		espera = espera,
		titulo = Idioma.mensaje(def.titulo, valores),
		texto = Idioma.mensaje(def.texto, valores),
		icono = def.icono,
		opciones = opciones,
	})
end

-- Un disparador: "deposito", "rebirth" (con el rebirth hecho) o
-- "calendario". Devuelve el id de la oferta enviada (o nil) y por que
function Ofertas.momento(jugador: Player, momento: string, rebirthHecho: number?): (string?, string)
	local s = sesiones[jugador]
	if not s then
		return nil, "sinSesion"
	end
	caducar(s)
	local ctx = Ofertas.contexto(jugador, momento, rebirthHecho)
	-- El Turbo ganado que se acabo vale para el PRIMER deposito despues, se
	-- ensene algo o no (el contexto ya lo lleva)
	if momento == "deposito" then
		s.turboGanadoAcabado = false
	end
	if not ctx then
		return nil, "sinPerfil"
	elseif s.actual then
		return nil, "pendiente"
	elseif s.enviadas >= MAX_ENVIADAS then
		return nil, "enviadas"
	end
	local def, motivo = DefinicionesOfertas.elegir(ctx)
	if not def then
		return nil, motivo
	end
	enviar(jugador, s, def, ctx)
	return def.id, "ok"
end

local function registro(perfil: Perfiles.Perfil, id: string): Perfiles.Oferta
	local r = perfil.ofertas.porId[id]
	if typeof(r) ~= "table" then
		r = { vistas = 0, ultima = 0, rechazos = 0 }
		perfil.ofertas.porId[id] = r
	end
	return r
end

local function contarVista(jugador: Player, s: Sesion, id: string)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return
	end
	local ahora = Ofertas.ahora()
	local r = registro(perfil, id)
	r.vistas = (r.vistas or 0) + 1
	r.ultima = ahora
	-- Solo los ultimos 7 dias: es para el tope de 3 por semana
	local historial = DefinicionesOfertas.recortar(perfil.ofertas.historial, ahora)
	table.insert(historial, ahora)
	perfil.ofertas.historial = historial
	s.mostradas += 1
	s.porId[id] = (s.porId[id] or 0) + 1
	Perfiles.marcarSucio(jugador)
end

local function contarRechazo(jugador: Player, id: string)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return
	end
	local r = registro(perfil, id)
	r.rechazos = (r.rechazos or 0) + 1
	Perfiles.marcarSucio(jugador)
end

-- Un intento de recoger con la bolsa llena (ver cabecera). Devuelve si contó
function Ofertas.intentoBolsaLlena(jugador: Player): boolean
	local s = sesiones[jugador]
	if not s then
		return false
	end
	local t = Ofertas.reloj()
	if t - s.ultimoIntento < GameConfig.OFERTAS_BOLSA_LLENA_CADA or not Bolsa.estaLlena(jugador) then
		return false
	end
	s.ultimoIntento = t
	s.intentosBolsaLlena += 1
	return true
end

-- Lo que manda el cliente por OfertaRespuestaEvent (accion, token, opcion).
-- Todo se mira: tipo, el token de la oferta que tiene y en que punto esta.
-- Devuelve si sirvio de algo.
function Ofertas.responder(jugador: Player, accion: any, token: any, opcion: any): boolean
	local s = sesiones[jugador]
	if not s or typeof(accion) ~= "string" or not ACCIONES[accion] then
		return false
	end
	-- Limite del remote: tantas por segundo y jugador
	local t = Ofertas.reloj()
	if t - s.ventana >= 1 then
		s.ventana, s.enVentana = t, 0
	end
	s.enVentana += 1
	if s.enVentana > GameConfig.OFERTAS_RESPUESTAS_POR_SEGUNDO then
		return false
	end
	if accion == "bolsaLlena" then
		return Ofertas.intentoBolsaLlena(jugador)
	end
	caducar(s)
	local actual = s.actual
	if not actual or typeof(token) ~= "number" or token ~= actual.token then
		return false
	end
	if accion == "mostrada" then
		if actual.mostrada then
			return false
		end
		actual.mostrada = true
		actual.hasta = t + VIDA_MOSTRADA
		contarVista(jugador, s, actual.id)
		Ofertas.alMostrar:Fire(jugador, actual.id)
		return true
	elseif accion == "descartada" then
		if actual.mostrada then
			return false
		end
		s.actual = nil
		return true
	end
	-- "ahoraNo" y "comprar" solo de una ensenada
	if not actual.mostrada then
		return false
	end
	if accion == "ahoraNo" then
		s.actual = nil
		contarRechazo(jugador, actual.id)
		Ofertas.alResponder:Fire(jugador, actual.id, "ahoraNo", nil)
		return true
	elseif accion == "comprar" then
		if typeof(opcion) ~= "string" or not tieneOpcion(actual, opcion) then
			return false
		end
		Ofertas.alResponder:Fire(jugador, actual.id, "comprar", opcion)
		return true
	end
	return false
end

-- Una compra completada (Monetizacion.alComprarPase / alComprarProducto):
-- si era de la oferta que tiene, se cierra (y si estaba sin ensenar, ya no
-- hace falta)
function Ofertas.compra(jugador: Player, idCompra: string)
	local s = sesiones[jugador]
	local actual = s and s.actual
	if not s or not actual or not tieneOpcion(actual, idCompra) then
		return
	end
	s.actual = nil
	if actual.mostrada then
		Ofertas.alResponder:Fire(jugador, actual.id, "aceptada", idCompra)
	end
end

-- Se acabo un Turbo corriendo (Turbo.alAcabar): si era ganado, la oferta de
-- Turbo espera al siguiente deposito
function Ofertas.turboAcabado(jugador: Player, ganado: boolean)
	local s = sesiones[jugador]
	if s and ganado then
		s.turboGanadoAcabado = true
	end
end

-- Por si alguien se va sin alSalir (pruebas, un perfil que no cargo)
Players.PlayerRemoving:Connect(function(jugador)
	task.defer(Ofertas.salir, jugador)
end)

return Ofertas
