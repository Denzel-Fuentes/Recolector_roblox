--!strict
--[[
	Oferta (ModuleScript)
	El panel "Oferta" (economia v4, K1 22 oct; docs/Economia-v4.md §5.6): lo
	que el servidor decide ofrecer en un momento justo (Services/Ofertas, por
	OfertaEvent) en una ventana del Kit con el icono, el titulo de la oferta
	(nunca "Oferta": Textos.OFERTAS), una frase con lo que da y los botones:
	"Comprar · N Robux" y "Ahora no" (con el Turbo, "15 min · 49 Robux",
	"60 min · 149 Robux" y "Ahora no"). Todos del mismo tamano, tipo de letra
	y peso; "Ahora no" en un color neutro del kit, no en el gris de
	desactivado. Sin cuentas atras ni precios tachados: el precio es el de
	verdad (Client/PreciosRobux).

	=== El momento tranquilo ===
	La oferta llega tras un deposito, al renacer o al cobrar el calendario,
	y se ensena cuando no hay panel abierto (el de Rebirth incluido: "al
	cerrar la celebracion del rebirth"), ni celebracion (UI/Celebraciones)
	ni tarjeta de insignia (UI/Notificaciones), ni lanzamiento cargando, ni
	una bolsa suya en el aire (en workspace.Objetos con LanzadaPor y aun sin
	LibreEn: Lanzamiento), durante TRANQUILO_DURANTE s seguidos. Se espera
	PAUSA_INICIAL s antes de mirar: el servidor avisa de la oferta antes de
	mandar la celebracion del mismo deposito. Si en `espera` s (60) no hay
	momento, se descarta ("descartada") y no cuenta.

	Justo antes de abrirla se mira que siga teniendo sentido: si desde que
	llego compro algo (perfil.compras.ultimaRobux cambio: 24 h sin ofertas),
	ya tiene el pase, o le llego Turbo, se descarta. Las opciones que Roblox
	dice que no estan a la venta (PreciosRobux) no salen; sin ninguna, se
	descarta. El servidor lo vuelve a mirar al recibir "mostrada" y, si ya
	no vale, la cancela ({ cancelar = token } por OfertaEvent): esperando, se
	olvida; abierta, se cierra sin responder.

	=== Respuestas (OfertaRespuestaEvent, con el token de la oferta) ===
	  "mostrada"    al abrirse: solo entonces cuenta
	  "ahoraNo"     el boton, la X o Esc (Menu.cerrarTodo -> cerrar)
	  "cerrada"     se abrio otro panel encima (un atajo, el prompt de la
	                tienda): se cierra sin contar un "Ahora no"
	  "comprar"     y el prompt de Roblox se lanza aqui (PromptGamePassPurchase
	                / PromptProductPurchase): la ventana de Roblox confirma.
	                La oferta sigue abierta: comprado, dice "¡Gracias! Ya es
	                tuyo" y se cierra; cancelado, aun se puede decir "Ahora no"
	  "descartada"  sin momento tranquilo a tiempo, o ya sin sentido
	  "bolsaLlena"  cada intento de recoger con la bolsa llena (senales de
	                EstadoCliente separadas SEPARACION_INTENTO s): el
	                disparador de Bolsa XL (el servidor comprueba que de verdad
	                esta llena; ver Services/Ofertas)
	Un Turbo con el tope de 3 h guardado no se puede comprar (como en la
	Tienda): su boton se desactiva.

	Es un panel de Menu a proposito: abierto, suelta el raton en primera
	persona (Camara.client) y deja el patio quieto (ControlPatio). No tiene
	boton en el HUD ni atajo. Devuelve `indicador` (siempre false: nadie lo
	pinta) y `prueba`:
	  ("modulo", "Oferta", "mostrar", id?)  la abre con datos de ejemplo
	                                        (PackInicio, DineroX2, VIP,
	                                        BolsaXL o Turbo) sin servidor
	  ("modulo", "Oferta", "estado")        titulo, botones y sus tamanos
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Paleta = require(Config:WaitForChild("Paleta"))
local Productos = require(Config:WaitForChild("Productos"))
local DefinicionesOfertas = require(Config:WaitForChild("DefinicionesOfertas"))
local DefinicionesRebirths = require(Config:WaitForChild("DefinicionesRebirths"))
local Utilidades = Shared:WaitForChild("Utilidades")
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(Utilidades:WaitForChild("Idioma"))
local Textos = Idioma.textos
local Red = require(Utilidades:WaitForChild("Red"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local PreciosRobux = require(Cliente:WaitForChild("PreciosRobux"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local Children = Fusion.Children
local peek = Fusion.peek

local OfertaEvent = Red.evento("OfertaEvent")
local OfertaRespuestaEvent = Red.evento("OfertaRespuestaEvent")

local NOMBRE = "Oferta"
local jugador = Players.LocalPlayer
local playerGui = jugador:WaitForChild("PlayerGui")

-- El momento tranquilo (ver cabecera)
local PAUSA_INICIAL = 1
local TRANQUILO_DURANTE = 0.6
local PASO = 0.2
-- Dos senales de bolsa llena mas separadas que esto son dos intentos
local SEPARACION_INTENTO = 1.5
-- Lo que se ve el "gracias" antes de cerrarse
local DURA_GRACIAS = 2.5
-- Botones: alto y separacion (todos iguales)
local ALTO_BOTON = 60
local HUECO_BOTONES = 14
local TAMANO_TEXTO_BOTON = 18
-- Nombre del boton "Ahora no": Tema.colorBoton le da un color fijo por
-- nombre y este sale cian (neutro: ni el verde de aceptar, ni el rojo de
-- peligro, ni el gris de desactivado)
local NOMBRE_AHORA_NO = "OfertaAhoraNo"

type Opcion = DefinicionesOfertas.Opcion
export type Datos = {
	id: string,
	token: number,
	momento: string,
	espera: number,
	titulo: any, -- Idioma.mensaje
	texto: any,
	icono: string,
	opciones: { Opcion },
	compraAlRecibir: number, -- perfil.compras.ultimaRobux cuando llego
}

local scope = Fusion.scoped(Fusion, Kit)

local indicador = scope:Value(false)
-- La oferta abierta (nil: ninguna) y, tras comprar, el texto de gracias
local datosR = scope:Value(nil :: Datos?)
local graciasR = scope:Value(nil :: string?)

-- La recibida que espera su momento, y si la abierta ya tiene respuesta
local pendiente: Datos? = nil
local respondida = true

local turboAlTope = scope:Computed(function(use)
	local p = use(EstadoCliente.reactivo.perfil)
	local r = p and p.turboRestante
	return typeof(r) == "number" and r >= GameConfig.TURBO_TOPE_COMPRA
end)

local function responder(accion: string, token: number, opcion: string?)
	OfertaRespuestaEvent:FireServer(accion, token, opcion)
end

-- ===========================================================================
-- Datos
-- ===========================================================================

-- La hora de su ultima compra con Robux, segun el perfil publicado
local function ultimaCompra(): number
	local p = EstadoCliente.perfil
	local compras = p and p.compras
	local t = compras and compras.ultimaRobux
	return if typeof(t) == "number" then t else 0
end

-- Lo que manda el servidor, mirado (o nil)
local function validar(d: any): Datos?
	if typeof(d) ~= "table" or typeof(d.id) ~= "string" or typeof(d.token) ~= "number" or typeof(d.opciones) ~= "table" then
		return nil
	end
	local opciones: { Opcion } = {}
	for _, o in d.opciones do
		if typeof(o) == "table" and typeof(o.id) == "string" then
			if (o.tipo == "pase" and Productos.PASE_POR_ID[o.id]) or (o.tipo == "producto" and Productos.PRODUCTO_POR_ID[o.id]) then
				table.insert(opciones, { tipo = o.tipo, id = o.id })
			end
		end
	end
	if #opciones == 0 then
		return nil
	end
	return {
		id = d.id,
		token = d.token,
		momento = if d.momento == "rebirth" then "rebirth" else "deposito",
		espera = math.clamp(tonumber(d.espera) or DefinicionesOfertas.GLOBAL.esperaMomento, 0, DefinicionesOfertas.GLOBAL.esperaMomento),
		titulo = d.titulo,
		texto = d.texto,
		icono = if typeof(d.icono) == "string" then d.icono else "estrella",
		opciones = opciones,
		compraAlRecibir = if typeof(d.compraAlRecibir) == "number" then d.compraAlRecibir else ultimaCompra(),
	}
end

-- La oferta tal y como se puede abrir ahora, o nil si ya no tiene sentido
-- (ver cabecera): sin las opciones que Roblox dice que no estan a la venta
local function paraAbrir(d: Datos): Datos?
	local p = EstadoCliente.perfil
	if not p or ultimaCompra() ~= d.compraAlRecibir then
		return nil
	end
	local turbo = if typeof(p.turboRestante) == "number" then p.turboRestante else 0
	local opciones: { Opcion } = {}
	for _, o in d.opciones do
		if o.tipo == "pase" and EstadoCliente.tienePase(o.id) then
			return nil
		elseif o.tipo == "producto" and turbo > 0 then
			-- La oferta de Turbo es para quien se quedo sin el
			return nil
		end
		local info = PreciosRobux.info(o.tipo, o.id)
		if info.estado == "cargando" or info.aLaVenta then
			table.insert(opciones, o)
		end
	end
	if #opciones == 0 then
		return nil
	end
	local copia = table.clone(d)
	copia.opciones = opciones
	return copia
end

local function nombreDe(opcion: Opcion): string
	if opcion.tipo == "pase" then
		local pase = Productos.PASE_POR_ID[opcion.id]
		return if pase then Idioma.nombre("Pases", pase) else opcion.id
	end
	local producto = Productos.PRODUCTO_POR_ID[opcion.id]
	return if producto then Idioma.nombre("Productos", producto) else opcion.id
end

local function comprar(opcion: Opcion)
	local d = peek(datosR)
	if not d or respondida then
		return
	end
	if opcion.tipo == "pase" then
		local pase = Productos.PASE_POR_ID[opcion.id]
		if not pase or pase.gamePassId == 0 then
			return
		end
		responder("comprar", d.token, opcion.id)
		MarketplaceService:PromptGamePassPurchase(jugador, pase.gamePassId)
	else
		local producto = Productos.PRODUCTO_POR_ID[opcion.id]
		if not producto or producto.productId == 0 or (producto.turboMinutos and peek(turboAlTope)) then
			return
		end
		responder("comprar", d.token, opcion.id)
		MarketplaceService:PromptProductPurchase(jugador, producto.productId)
	end
end

-- "Ahora no" (el boton): una vez por oferta
local function ahoraNo()
	local d = peek(datosR)
	if d and not respondida then
		respondida = true
		responder("ahoraNo", d.token)
	end
end

-- Se cierra sin pulsar "Ahora no" (Menu llama a `cerrar`): la X y Esc
-- (Menu.cerrarTodo) valen "Ahora no"; abrir otro panel encima (un atajo, el
-- prompt de la tienda) es "cerrada", sin rechazo. Las dos llegan con
-- Menu.abierto() a nil: se distinguen despues, cuando Menu.abrir ya puso
-- el otro panel
local function alCerrarse()
	local d = peek(datosR)
	if not d or respondida then
		return
	end
	respondida = true
	task.defer(function()
		responder(if Menu.abierto() ~= nil then "cerrada" else "ahoraNo", d.token)
	end)
end

-- ===========================================================================
-- Ventana
-- ===========================================================================

-- Un boton de compra: el precio de verdad, "Cargando precio…" mientras
-- llega; "Proximamente" si no esta a la venta
local function botonOpcion(s: any, opcion: Opcion, ancho: UDim, orden: number)
	local info = PreciosRobux.de(opcion.tipo, opcion.id)
	local producto = if opcion.tipo == "producto" then Productos.PRODUCTO_POR_ID[opcion.id] else nil
	local esTurbo = producto ~= nil and producto.turboMinutos ~= nil
	return s:Boton({
		Nombre = "Opcion_" .. opcion.id,
		Texto = s:Computed(function(use)
			local i = use(info) :: PreciosRobux.Info
			if i.estado ~= "cargando" and not i.aLaVenta then
				return Textos.TIENDA.proximamente
			elseif i.estado == "cargando" then
				return Textos.TIENDA.cargandoPrecio
			elseif producto and producto.turboMinutos then
				return Textos.formatear(Textos.OFERTAS.turboOpcion, { minutos = producto.turboMinutos, precio = i.precio })
			end
			return Textos.formatear(Textos.OFERTAS.comprar, { precio = i.precio })
		end),
		Color = Paleta.UI_GEMAS,
		Tamano = TAMANO_TEXTO_BOTON,
		Size = UDim2.new(ancho, UDim.new(1, 0)),
		Orden = orden,
		Deshabilitado = s:Computed(function(use)
			local i = use(info) :: PreciosRobux.Info
			return (i.estado ~= "cargando" and not i.aLaVenta) or (esTurbo and use(turboAlTope))
		end),
		alPulsar = function()
			comprar(opcion)
		end,
	})
end

local fila = scope:Computed(function(use, s: any)
	local d = use(datosR)
	if not d then
		return nil
	end
	local n = #d.opciones + 1
	-- Todos iguales: el ancho entero menos los huecos, entre todos
	local ancho = UDim.new(1 / n, -math.ceil(HUECO_BOTONES * (n - 1) / n))
	local botones: { any } = {
		s:Lista({ Espacio = HUECO_BOTONES, Horizontal = true, Alinear = Enum.HorizontalAlignment.Center, AlinearV = Enum.VerticalAlignment.Center }),
	}
	for i, opcion in d.opciones do
		table.insert(botones, botonOpcion(s, opcion, ancho, i))
	end
	table.insert(botones, s:Boton({
		Nombre = NOMBRE_AHORA_NO,
		Texto = Textos.OFERTAS.ahoraNo,
		Tamano = TAMANO_TEXTO_BOTON,
		Size = UDim2.new(ancho, UDim.new(1, 0)),
		Orden = n,
		alPulsar = function()
			ahoraNo()
			Menu.cerrarTodo()
		end,
	}))
	return s:New("Frame")({
		Name = "Botones",
		Size = UDim2.new(1, 0, 0, ALTO_BOTON),
		Position = UDim2.fromScale(0.5, 1),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Visible = s:Computed(function(use2)
			return use2(graciasR) == nil
		end),
		[Children] = botones,
	})
end)

scope:Ventana({
	Nombre = NOMBRE,
	Titulo = scope:Computed(function(use)
		local d = use(datosR)
		return if d then Idioma.resolver(d.titulo) else ""
	end),
	Ancho = 620,
	Alto = 400,
	Abierta = scope:Computed(function(use)
		return use(Menu.abiertoR) == NOMBRE
	end),
	-- La X vale "Ahora no": Menu.cerrarTodo llama al `cerrar` del registro
	alCerrar = Menu.cerrarTodo,
	Hijos = {
		scope:Icono({
			Clave = scope:Computed(function(use)
				local d = use(datosR)
				return if d then d.icono else "estrella"
			end),
			Tamano = 96,
			Position = UDim2.new(0.5, 0, 0, 2),
			AnchorPoint = Vector2.new(0.5, 0),
		}),
		scope:Texto({
			Nombre = "Frase",
			Texto = scope:Computed(function(use)
				local d = use(datosR)
				return if d then Idioma.resolver(d.texto) else ""
			end),
			Size = UDim2.new(1, -24, 0, 104),
			Position = UDim2.new(0.5, 0, 0, 108),
			AnchorPoint = Vector2.new(0.5, 0),
			Tamano = 20,
			Fuente = "negrita",
			Alinear = Enum.TextXAlignment.Center,
			AlinearY = Enum.TextYAlignment.Top,
			Visible = scope:Computed(function(use)
				return use(graciasR) == nil
			end),
		}),
		scope:Texto({
			Nombre = "Gracias",
			Texto = scope:Computed(function(use)
				return use(graciasR) or ""
			end),
			Size = UDim2.new(1, -24, 0, 104),
			Position = UDim2.new(0.5, 0, 0, 120),
			AnchorPoint = Vector2.new(0.5, 0),
			Tamano = 26,
			Fuente = "titulo",
			Color = Paleta.UI_EXITO,
			Contorno = Paleta.UI_TINTA,
			Alinear = Enum.TextXAlignment.Center,
			Visible = scope:Computed(function(use)
				return use(graciasR) ~= nil
			end),
		}),
		fila,
	},
})

-- El boton "Ahora no" de la ventana (el que se elige primero con mando: con
-- menores, el que no compra)
local function botonAhoraNo(): GuiObject?
	local gui = playerGui:FindFirstChild(NOMBRE)
	local boton = gui and gui:FindFirstChild(NOMBRE_AHORA_NO, true)
	local cuerpo = boton and boton:FindFirstChild("Cuerpo")
	return if cuerpo and cuerpo:IsA("GuiObject") then cuerpo else nil
end

Menu.registrar(NOMBRE, {
	-- datos: los de OfertaEvent (ver Services/Ofertas)
	abrir = function(datos: any?)
		local d = validar(datos)
		if not d then
			task.defer(Menu.notificarCierre, NOMBRE)
			return
		end
		graciasR:set(nil)
		datosR:set(d)
		respondida = false
		responder("mostrada", d.token)
	end,
	-- Cerrar sin haber respondido: "Ahora no" o "cerrada" (ver alCerrarse)
	cerrar = alCerrarse,
	primerSeleccionable = botonAhoraNo,
})

-- ===========================================================================
-- Llegada y momento tranquilo
-- ===========================================================================

local function celebrando(): boolean
	local celebraciones = playerGui:FindFirstChild("Celebraciones")
	local notificaciones = playerGui:FindFirstChild("Notificaciones")
	return (celebraciones ~= nil and celebraciones:FindFirstChild("Celebracion") ~= nil)
		or (notificaciones ~= nil and notificaciones:FindFirstChild("Logro") ~= nil)
end

-- Una bolsa suya volando: Lanzamiento la pone en workspace.Objetos con
-- LanzadaPor y le pone LibreEn al posarse (si entra, desaparece)
local function bolsaEnElAire(): boolean
	local carpeta = workspace:FindFirstChild("Objetos")
	if not carpeta then
		return false
	end
	for _, objeto in carpeta:GetChildren() do
		if objeto:GetAttribute("LanzadaPor") == jugador.UserId and objeto:GetAttribute("LibreEn") == nil then
			return true
		end
	end
	return false
end

local function tranquilo(): boolean
	return Menu.abierto() == nil and EstadoCliente.cargaLanzamiento <= 0 and not celebrando() and not bolsaEnElAire()
end

local function esperarMomento(d: Datos)
	local limite = os.clock() + d.espera
	task.wait(PAUSA_INICIAL)
	local desde: number? = nil
	while pendiente == d and os.clock() < limite do
		if tranquilo() then
			desde = desde or os.clock()
			if os.clock() - (desde :: number) >= TRANQUILO_DURANTE then
				pendiente = nil
				-- Justo antes de abrir, si aun tiene sentido (ver cabecera)
				local lista = paraAbrir(d)
				if lista then
					Menu.abrir(NOMBRE, lista)
				else
					responder("descartada", d.token)
				end
				return
			end
		else
			desde = nil
		end
		task.wait(PASO)
	end
	if pendiente == d then
		pendiente = nil
		responder("descartada", d.token)
	end
end

-- El servidor la cancela (una compra mientras esperaba, o al ensenarse ya
-- no valia): esperando, se olvida; abierta, se cierra sin responder
local function cancelar(token: number)
	if pendiente and pendiente.token == token then
		pendiente = nil
	end
	local abierta = peek(datosR)
	if abierta and abierta.token == token and Menu.abierto() == NOMBRE then
		respondida = true
		Menu.cerrarTodo()
	end
end

OfertaEvent.OnClientEvent:Connect(function(datos)
	if typeof(datos) == "table" and typeof(datos.cancelar) == "number" then
		cancelar(datos.cancelar)
		return
	end
	local d = validar(datos)
	-- Una a la vez: con una abierta o esperando, la nueva no entra
	if not d or pendiente ~= nil or Menu.abierto() == NOMBRE then
		return
	end
	pendiente = d
	task.spawn(esperarMomento, d)
end)

-- La compra de una opcion abierta se completo: gracias y se cierra
local function comprado(opcion: Opcion)
	local d = peek(datosR)
	if not d or Menu.abierto() ~= NOMBRE then
		return
	end
	respondida = true
	graciasR:set(Textos.formatear(Textos.OFERTAS.gracias, { nombre = nombreDe(opcion) }))
	task.delay(DURA_GRACIAS, function()
		if peek(datosR) == d and Menu.abierto() == NOMBRE then
			Menu.cerrarTodo()
		end
	end)
end

local function opcionDe(tipo: string, idRoblox: number): Opcion?
	local d = peek(datosR)
	if not d then
		return nil
	end
	for _, opcion in d.opciones do
		if opcion.tipo == tipo then
			local def: any = if tipo == "pase" then Productos.PASE_POR_ID[opcion.id] else Productos.PRODUCTO_POR_ID[opcion.id]
			local id = if def then (if tipo == "pase" then def.gamePassId else def.productId) else 0
			if id ~= 0 and id == idRoblox then
				return opcion
			end
		end
	end
	return nil
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(quien, gamePassId, hecho)
	if quien ~= jugador or not hecho then
		return
	end
	local opcion = opcionDe("pase", gamePassId)
	if opcion then
		comprado(opcion)
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, hecho)
	if userId ~= jugador.UserId or not hecho then
		return
	end
	local opcion = opcionDe("producto", productId)
	if opcion then
		comprado(opcion)
	end
end)

-- Intentos de recoger con la bolsa llena (ver cabecera). Solo sin Bolsa XL:
-- con ella el disparador ya no sirve
local ultimaSenalLlena = -math.huge
EstadoCliente.alRecogerConBolsaLlena:Connect(function()
	local t = os.clock()
	local nuevo = t - ultimaSenalLlena >= SEPARACION_INTENTO
	ultimaSenalLlena = t
	if nuevo and not EstadoCliente.tienePase("BolsaXL") then
		responder("bolsaLlena", 0)
	end
end)

-- ===========================================================================
-- Pruebas (PruebasCliente: "modulo", "Oferta", ...)
-- ===========================================================================

-- Datos de ejemplo de cada oferta, como los armaria el servidor (token
-- negativo: el servidor ignora sus respuestas)
local function ejemplo(id: string): Datos?
	local def = DefinicionesOfertas.POR_ID[id]
	if not def then
		return nil
	end
	local valores: { [string]: any }? = nil
	if def.valores == "multiplicador" then
		local m = DefinicionesRebirths.multiplicador(1)
		valores = { mult = Idioma.multiplicador(m), mult2 = Idioma.multiplicador(m * 2) }
	end
	local opciones: { Opcion } = {}
	for _, pase in def.pases or {} do
		table.insert(opciones, { tipo = "pase", id = pase })
	end
	for _, producto in def.productos or {} do
		table.insert(opciones, { tipo = "producto", id = producto })
	end
	return {
		id = def.id,
		token = -1,
		momento = "deposito",
		espera = 0,
		titulo = Idioma.mensaje(def.titulo, valores),
		texto = Idioma.mensaje(def.texto, valores),
		icono = def.icono,
		opciones = opciones,
		compraAlRecibir = ultimaCompra(),
	}
end

local prueba = {
	mostrar = function(id: any): string
		local d = ejemplo(if typeof(id) == "string" then id else "PackInicio")
		if not d then
			return "no hay oferta " .. tostring(id)
		end
		Menu.abrir(NOMBRE, d)
		task.wait(0.4)
		return string.format("abierta: %s | %s | %d botones", tostring(Menu.abierto()), Idioma.resolver(d.titulo), #d.opciones + 1)
	end,
	estado = function(): string
		local gui = playerGui:FindFirstChild(NOMBRE)
		local botones = gui and gui:FindFirstChild("Botones", true)
		if not botones then
			return "sin oferta abierta"
		end
		local partes = {}
		for _, b in botones:GetChildren() do
			if b:IsA("Frame") then
				local etiqueta = b:FindFirstChild("Etiqueta", true)
				table.insert(partes, string.format("%s '%s' %dx%d", b.Name, if etiqueta and etiqueta:IsA("TextLabel") then etiqueta.Text else "?", b.AbsoluteSize.X, b.AbsoluteSize.Y))
			end
		end
		local d = peek(datosR)
		return string.format("%s | %s", if d then Idioma.resolver(d.titulo) else "?", table.concat(partes, " · "))
	end,
}

return {
	indicador = indicador,
	prueba = prueba,
}
