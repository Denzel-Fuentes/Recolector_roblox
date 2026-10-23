--!strict
--[[
	Notificaciones (ModuleScript)
	Tres canales de texto efimero, y solo estos tres (no hay dialogos de NPC:
	se quitaron el 29 sep):

	  toast   lo que te pasa a TI (pedido cumplido, rebirth, compra). Los
	          rechazos con sitio en el mundo (montón agotado, contenedor
	          cerrado...) son burbujas desde el 6 oct (AvisosMundo.client).
	          Pila pegada arriba
	          en el centro (peticion del usuario, 29 sep: a 122 px caian a
	          media pantalla en el movil, que mide ~500 px de alto); baja
	          por debajo de la tarjeta de logro mientras esta se ve. En
	          tactil la botonera sube arriba-izquierda y los contadores
	          (dinero, pedido) se apartan de las barras hacia el centro:
	          la pila se centra en el hueco libre entre los dos, medido en
	          pantalla. Tarjeta blanca con contorno marino, medalla del tipo
	          con icono, pop de entrada y barra de tiempo, 3.5 s.
	  feed    lo que pasa en el SERVIDOR (alguien activo un monton grande,
	          bato un record, Dona Chatarra repuso). Arriba a la derecha, es
	          la senal social del GDD: invita a ir donde esta pasando algo.
	  logro   tarjeta grande que baja desde arriba con el trofeo, 4 s (las
	          insignias: NotificacionEvent con tipo "logro"; desde el 7 oct
	          tambien los records de distancia, tipo "record": en el feed
	          se leian muy pequenos).

	Cada aviso vive en su propio scope de Fusion: su aparicion y su fundido
	son Tweens de un Value de transparencia, y al acabar se limpia entero.
	Se conecta a NotificacionEvent y FeedEvent al cargarse.

	Sonido (Client/Sonido): lo que el servidor avisa por NotificacionEvent
	suena segun la CLAVE de su mensaje (SONIDO_AVISO: mejora comprada y
	compra de Robux, rebirth con su capa de magia, pedido cumplido y premio
	del dia, y los "no te alcanza"), y la tarjeta de insignia o de record con
	"insignia". El feed no suena: es lo que les pasa a otros.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local DefinicionesInsignias = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesInsignias"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local Tema = require(script.Parent:WaitForChild("Kit"):WaitForChild("Tema"))
local Escala = require(script.Parent:WaitForChild("Kit"):WaitForChild("Escala"))
local Sonido = require(script.Parent.Parent:WaitForChild("Sonido"))

local Children = Fusion.Children

local Notificaciones = {}

local scope = Fusion.scoped(Fusion, Kit)

local COLOR_TIPO = {
	aviso = Paleta.UI_ENERGIA,
	exito = Paleta.UI_DINERO,
	dinero = Paleta.UI_DINERO,
	objeto = Paleta.UI_GEMAS,
	peligro = Paleta.UI_PELIGRO,
	info = Paleta.UI_TINTA_SUAVE,
}

local MAX_TOASTS = 5
local MAX_FEED = 6
local FUNDIDO = TweenInfo.new(0.3)

-- Toasts: arriba-centro; mientras se ve una tarjeta de logro (12..112), por
-- debajo de ella. centroToasts < 0 = centrados en la pantalla; si no, el x
-- (px de diseno) del hueco libre en tactil (recolocarToasts)
local ANCHO_TOASTS = 440
local logrosEnPantalla = scope:Value(0)
local centroToasts = scope:Value(-1)
local anchoToasts = scope:Value(ANCHO_TOASTS)
local pilaToasts = scope:New("Frame")({
	Name = "Toasts",
	Size = scope:Computed(function(use)
		return UDim2.fromOffset(use(anchoToasts), 320)
	end),
	Position = scope:Spring(
		scope:Computed(function(use)
			local y = if use(logrosEnPantalla) > 0 then 122 else 12
			local x = use(centroToasts)
			return if x < 0 then UDim2.new(0.5, 0, 0, y) else UDim2.new(0, x, 0, y)
		end),
		25,
		0.8
	),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	[Children] = scope:Lista({ Espacio = 6, Alinear = Enum.HorizontalAlignment.Center }),
})

-- Feed: arriba-derecha, debajo de los contadores del HUD (dinero y
-- pedido: 16 + 58 + 8 + 30). En tactil los contadores se apartan de las
-- barras verticales y el feed con ellos (recolocarFeed): pegado al borde
-- caia encima de las barras de bolsa y fuerza.
local posicionFeed = scope:Value(UDim2.new(1, -16, 0, 124))
local pilaFeed = scope:New("Frame")({
	Name = "Feed",
	Size = UDim2.fromOffset(420, 300),
	Position = posicionFeed,
	AnchorPoint = Vector2.new(1, 0),
	BackgroundTransparency = 1,
	[Children] = scope:Lista({ Espacio = 4, Alinear = Enum.HorizontalAlignment.Right }),
})

local pantalla = scope:Pantalla({ Nombre = "Notificaciones", Orden = 20, Hijos = { pilaToasts, pilaFeed } })

-- Avisos vivos por pila (el mas viejo primero), para recortar
type Aviso = { scope: any, orden: number }
local vivos: { [Frame]: { Aviso } } = { [pilaToasts] = {}, [pilaFeed] = {} }

local function retirar(pila: Frame, aviso: Aviso)
	local lista = vivos[pila]
	local i = table.find(lista, aviso)
	if i then
		table.remove(lista, i)
		Fusion.doCleanup(aviso.scope)
	end
end

-- Monta un aviso en su scope: aparece, espera `dura` s, se funde y se limpia
local function aviso(pila: Frame, max: number, dura: number, construir: (scope: any, opacidad: any) -> Instance)
	local s = scope:innerScope()
	local transparencia = s:Value(1)
	local opacidad = s:Tween(transparencia, FUNDIDO)
	local instancia = construir(s, opacidad)
	instancia.Parent = pila
	local entrada: Aviso = { scope = s, orden = #vivos[pila] }
	table.insert(vivos[pila], entrada)
	while #vivos[pila] > max do
		retirar(pila, vivos[pila][1])
	end
	transparencia:set(0)
	task.delay(dura, function()
		-- Pudo recortarse antes (llegaron mas avisos): entonces ya esta limpio
		if not table.find(vivos[pila], entrada) then
			return
		end
		transparencia:set(1)
		task.wait(FUNDIDO.Time + 0.05)
		retirar(pila, entrada)
	end)
end

-- En tactil, centra la pila en el hueco de arriba entre la botonera y los
-- contadores del HUD (sus posiciones reales en pantalla, en px de diseno:
-- la UI de Kit/Pantalla va escalada por Escala.valor()). En escritorio la
-- botonera esta a media altura y el centro de arriba esta libre.
local function recolocarToasts()
	local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local hud = gui and gui:FindFirstChild("HUD")
	local botonera = hud and hud:FindFirstChild("Botonera")
	local contadores = hud and hud:FindFirstChild("Contadores")
	if Escala.disposicionActual() ~= "tactil" or not botonera or not contadores then
		centroToasts:set(-1)
		anchoToasts:set(ANCHO_TOASTS)
		return
	end
	local escala = Escala.valor()
	local izquierda = ((botonera :: GuiObject).AbsolutePosition.X + (botonera :: GuiObject).AbsoluteSize.X) / escala + 8
	local derecha = (contadores :: GuiObject).AbsolutePosition.X / escala - 8
	anchoToasts:set(math.clamp(derecha - izquierda, 220, ANCHO_TOASTS))
	centroToasts:set((izquierda + derecha) / 2)
end

-- En tactil, el feed bajo los contadores y alineado con su borde derecho
local function recolocarFeed()
	local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local hud = gui and gui:FindFirstChild("HUD")
	local contadores = hud and hud:FindFirstChild("Contadores")
	if Escala.disposicionActual() ~= "tactil" or not contadores then
		posicionFeed:set(UDim2.new(1, -16, 0, 124))
		return
	end
	local escala = Escala.valor()
	local c = contadores :: GuiObject
	local derecha = (c.AbsolutePosition.X + c.AbsoluteSize.X) / escala
	local abajo = (c.AbsolutePosition.Y + c.AbsoluteSize.Y) / escala + 6
	posicionFeed:set(UDim2.new(0, derecha, 0, abajo))
end

-- Icono de cada tipo de toast (Config/Iconos, o su glifo dibujado)
local ICONO_TIPO = {
	aviso = "rayo",
	exito = "estrella",
	dinero = "billete",
	objeto = "bolsa",
	peligro = "cruz",
	info = "check",
}

-- Toast (6 oct, peticion del usuario: "que se vean mejor, con algun
-- efecto"): pastilla blanca con contorno marino y una medalla redonda del
-- color del tipo con su icono. Entra con un pop elastico (UIScale con
-- muelle); los de aviso y peligro, ademas, con una sacudida. Debajo, una
-- barra fina del color del tipo se vacia mientras dura. Los rechazos que
-- tienen un sitio en el mundo ya no llegan aqui: son burbujas
-- (AvisosMundo.client).
local DURACION_TOAST = 3.5
local ordenToast = 0
function Notificaciones.mostrar(texto: string, tipo: string?)
	recolocarToasts()
	ordenToast += 1
	local clase = tipo or "info"
	local color = COLOR_TIPO[clase] or Paleta.UI_TINTA_SUAVE
	local sacude = clase == "aviso" or clase == "peligro"
	local orden = ordenToast
	aviso(pilaToasts, MAX_TOASTS, DURACION_TOAST, function(s, opacidad)
		local escala = s:Value(0.55)
		local giro = s:Value(if sacude then -7 else 0)
		local resto = s:Value(1)
		task.defer(function()
			escala:set(1)
			giro:set(0)
			resto:set(0)
		end)
		return s:New("Frame")({
			Name = "Toast",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = orden,
			BackgroundColor3 = Paleta.UI_PAPEL,
			BackgroundTransparency = opacidad,
			Rotation = s:Spring(giro, 40, 0.25),
			[Children] = {
				s:New("UIScale")({ Scale = s:Spring(escala, 28, 0.45) }),
				s:New("UICorner")({ CornerRadius = UDim.new(0, Tema.RADIO) }),
				s:New("UIStroke")({ Color = Paleta.UI_TINTA, Thickness = Tema.GROSOR, Transparency = opacidad }),
				s:New("UIPadding")({
					PaddingLeft = UDim.new(0, 56),
					PaddingRight = UDim.new(0, 14),
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 12),
				}),
				-- Medalla del tipo con su icono, asomando por la izquierda
				s:New("Frame")({
					Name = "Medalla",
					Size = UDim2.fromOffset(40, 40),
					Position = UDim2.new(0, -48, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = color,
					BackgroundTransparency = opacidad,
					[Children] = {
						s:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						s:New("UIStroke")({ Color = Paleta.UI_TINTA, Thickness = 2, Transparency = opacidad }),
						s:New("UIGradient")({ Color = Tema.DEGRADADO, Rotation = 90 }),
						s:Icono({ Clave = ICONO_TIPO[clase] or "check", Tamano = 26, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) }),
					},
				}),
				s:New("TextLabel")({
					Name = "Texto",
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = texto,
					TextColor3 = Paleta.UI_TINTA,
					TextTransparency = opacidad,
					TextSize = 18,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Tema.FUENTE_TITULO,
				}),
				-- Lo que le queda: una barra fina que se vacia
				s:New("Frame")({
					Name = "Tiempo",
					Size = s:Tween(
						s:Computed(function(use)
							return UDim2.new(use(resto), 0, 0, 4)
						end),
						TweenInfo.new(DURACION_TOAST, Enum.EasingStyle.Linear)
					),
					Position = UDim2.new(0, 0, 1, 6),
					AnchorPoint = Vector2.new(0, 1),
					BackgroundColor3 = color,
					BackgroundTransparency = opacidad,
					BorderSizePixel = 0,
					[Children] = s:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				}),
			},
		})
	end)
end

local ordenFeed = 0
function Notificaciones.feed(texto: string)
	recolocarFeed()
	ordenFeed += 1
	local orden = ordenFeed
	aviso(pilaFeed, MAX_FEED, 9, function(s, opacidad)
		return s:New("Frame")({
			Name = "Noticia",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = orden,
			BackgroundColor3 = Paleta.UI_TINTA,
			BackgroundTransparency = s:Computed(function(use)
				return 0.15 + (use(opacidad) :: number) * 0.85
			end),
			[Children] = {
				s:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
				-- Borde del color primario: se distingue del fondo (7 oct)
				s:New("UIStroke")({ Color = Paleta.UI_PRIMARIO, Thickness = 2, Transparency = opacidad }),
				s:New("UIPadding")({
					PaddingLeft = UDim.new(0, 14),
					PaddingRight = UDim.new(0, 14),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
				}),
				s:New("TextLabel")({
					Name = "Texto",
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = texto,
					TextColor3 = Paleta.UI_PAPEL,
					TextTransparency = opacidad,
					TextSize = 18, -- a 14 no se leia (7 oct)
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Right,
					FontFace = Tema.FUENTE_NEGRITA,
				}),
			},
		})
	end)
end

-- Tarjeta grande que baja desde arriba (insignias y records): icono a la
-- izquierda, linea pequena arriba, linea grande y descripcion
local function tarjetaGrande(icono: string, color: Color3, arriba: string, grande: string, descripcion: string)
	local s = scope:innerScope()
	local dentro = s:Value(false)
	local posicion = s:Spring(
		s:Computed(function(use)
			return if use(dentro) then UDim2.new(0.5, 0, 0, 12) else UDim2.new(0.5, 0, 0, -130)
		end),
		22,
		0.7
	)
	s:Tarjeta({
		Nombre = "Logro",
		Size = UDim2.fromOffset(460, 108),
		Position = posicion,
		AnchorPoint = Vector2.new(0.5, 0),
		Color = color,
		Radio = 18,
		Relleno = 14,
		Hijos = {
			s:Icono({ Clave = icono, Tamano = 68, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) }),
			s:Texto({ Texto = arriba, Size = UDim2.new(1, -82, 0, 22), Position = UDim2.fromOffset(80, 0), Tamano = 16, Fuente = "titulo", Color = Paleta.UI_PAPEL, Contorno = Paleta.UI_TINTA, Mayusculas = true }),
			s:Texto({ Texto = grande, Size = UDim2.new(1, -82, 0, 36), Position = UDim2.fromOffset(80, 22), Tamano = 30, Fuente = "titulo", Color = Paleta.UI_PAPEL, Contorno = Paleta.UI_TINTA }),
			s:Texto({ Texto = descripcion, Size = UDim2.new(1, -82, 0, 20), Position = UDim2.fromOffset(80, 58), Tamano = 15, Fuente = "negrita", Color = Paleta.UI_TINTA }),
		},
	}).Parent = pantalla
	dentro:set(true)
	logrosEnPantalla:set(Fusion.peek(logrosEnPantalla) + 1)
	task.delay(4, function()
		dentro:set(false)
		task.wait(0.8)
		logrosEnPantalla:set(math.max(0, Fusion.peek(logrosEnPantalla) - 1))
		Fusion.doCleanup(s)
	end)
end

-- Record de distancia (7 oct: en el feed, a 14 px, no se leia): la misma
-- tarjeta que las insignias, con la distancia en grande
function Notificaciones.record(distancia: string, delServidor: boolean)
	tarjetaGrande("trofeo", Paleta.UI_DINERO, Textos.RECORD.titulo, Textos.formatear(Textos.RECORD.distancia, { distancia = distancia }),
		if delServidor then Textos.RECORD.servidor else Textos.RECORD.personal)
end

function Notificaciones.logro(nombre: string, descripcion: string)
	tarjetaGrande("trofeo", Paleta.UI_PRIMARIO, Textos.LOGROS.desbloqueado, nombre, descripcion)
end

-- Lo que suena con cada aviso del servidor, por la clave de su mensaje
-- (Idioma.mensaje). Los que no estan aqui solo se ven.
local SONIDO_AVISO: { [string]: { string } } = {
	["TIENDA.mejoraComprada"] = { "mejora" },
	["NOTIFICACIONES.compraRobux"] = { "mejora" },
	["REBIRTH.hecho"] = { "rebirth", "rebirthMagia" },
	["PEDIDOS_AVISOS.cumplido"] = { "regalo" },
	["PEDIDOS_AVISOS.todos"] = { "regalo" },
	["PATIO.sinDinero"] = { "denegado" },
	["REBIRTH.faltanMejoras"] = { "denegado" },
	["REBIRTH.faltaDinero"] = { "denegado" },
}

local function sonarAviso(mensaje: any)
	local clave = if typeof(mensaje) == "table" and typeof(mensaje.k) == "string" then mensaje.k else nil
	local sonidos = if clave then SONIDO_AVISO[clave] else nil
	if sonidos then
		for _, s in sonidos do
			Sonido.tocar(s)
		end
	end
end

-- El servidor manda Idioma.mensaje (o un string suelto); aqui se escribe en
-- el idioma del jugador
Red.evento("NotificacionEvent").OnClientEvent:Connect(function(mensaje, tipo)
	if tipo == "logro" then
		-- Las insignias llegan por id (Services/Insignias)
		local def = if typeof(mensaje) == "string" then DefinicionesInsignias.POR_ID[mensaje] else nil
		if def then
			Notificaciones.logro(Idioma.nombre("Insignias", def), Idioma.descripcion("Insignias", def))
			Sonido.tocar("insignia")
		end
		return
	end
	local texto = Idioma.resolver(mensaje)
	if texto == "" then
		return
	end
	if tipo == "record" then
		-- "distancia|servidor" o "distancia|personal" (Services/Lanzamiento)
		local partes = string.split(texto, "|")
		Notificaciones.record(partes[1], partes[2] == "servidor")
		Sonido.tocar("insignia")
	else
		Notificaciones.mostrar(texto, tipo)
		sonarAviso(mensaje)
	end
end)

Red.evento("FeedEvent").OnClientEvent:Connect(function(mensaje)
	local texto = Idioma.resolver(mensaje)
	if texto ~= "" then
		Notificaciones.feed(texto)
	end
end)

return Notificaciones
