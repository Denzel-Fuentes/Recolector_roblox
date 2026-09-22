--!strict
--[[
	HUD
	Distribucion calcada de KOTAMON (referencia del usuario), en pegatinas de
	papel y tinta (Componentes):

	  arriba-izq     pildoras: $ dinero | cartas (mascotas distintas) | gemas
	  izquierda      barra vertical de ENERGIA con el rayo en la base
	  derecha        barra de FUERZA de lanzamiento (mantener F) y, a su lado,
	                 la de BOLSA: cuanto llevas, sin numeros (decision del
	                 usuario: se ve llenarse, y "LLENA" en rojo avisa de que
	                 toca volver al contenedor)
	  abajo-izq      retrato (headshot del avatar) + dock con icono, nombre y la
	                 insignia de la tecla DEBAJO: telefono Q, album J, logros L,
	                 base B
	  abajo-dcha     "MANTEN [F] PARA LANZAR" con la bolsa, y encima la pista
	                 de recoger (se retira sola tras 20 recogidas)
	  arriba-dcha    Ir a casa / Ir al patio

	Tactil: el thumbstick y el boton de salto de Roblox ocupan las esquinas de
	abajo, asi que el dock pasa ARRIBA-CENTRO (solo iconos) y el retrato se pone
	junto a las pildoras; la pista de lanzar la sustituye el boton de
	ContextActionService que restiliza ControlPatio. Componentes.disposicion()
	decide, y alCambiarDisposicion recoloca sin reconstruir.

	Solo presentacion: lee EstadoCliente y manda intencion por RemoteEvent o
	abre paneles por Menu. Carga Notificaciones y Dialogo para que existan desde
	el primer frame.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Formato = require(Utilidades:WaitForChild("Formato"))
local Entrada = require(Utilidades:WaitForChild("Entrada"))
local Red = require(Utilidades:WaitForChild("Red"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Componentes = require(script.Parent:WaitForChild("Componentes"))
local Menu = require(script.Parent:WaitForChild("Menu"))
require(script.Parent:WaitForChild("Notificaciones"))
require(script.Parent:WaitForChild("Dialogo"))

local TeletransporteEvent = Red.evento("TeletransporteEvent")

local jugador = Players.LocalPlayer
local pantalla = Componentes.pantalla("HUD", 1)

-- No hay Tools: la mochila de Roblox solo estorba
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local MARGEN = 16
local RECOGIDAS_PARA_APRENDER = 20

-- ===========================================================================
-- Arriba-izq: pildoras
-- ===========================================================================

local fila = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(0, 46), Position = UDim2.fromOffset(MARGEN, 12), Transparencia = 1, Nombre = "Pildoras" })
fila.AutomaticSize = Enum.AutomaticSize.X
Componentes.lista(fila, 10, true)

local _, textoDinero = Componentes.pildora({ Parent = fila, Nombre = "Dinero", Icono = "billete", Color = Paleta.UI_DINERO, Ancho = 176, Orden = 1 })
local _, textoCartas = Componentes.pildora({ Parent = fila, Nombre = "Cartas", Icono = "cartas", Color = Paleta.UI_CARTAS, Ancho = 132, Orden = 2 })
local _, textoGemas = Componentes.pildora({ Parent = fila, Nombre = "Gemas", Icono = "gema", Color = Paleta.UI_GEMAS, Ancho = 132, Orden = 3 })

-- ===========================================================================
-- Barras verticales
-- ===========================================================================

local ANCHO_BARRA = 30
local ALTO_BARRA = 210
local DIAMETRO_BASE = 46
local SEPARACION_BARRAS = 26

type BarraVertical = { envoltorio: Frame, cuerpo: Frame, relleno: Frame, etiqueta: TextLabel, borde: UIStroke, base: Frame }

-- lado -1 = borde izquierdo, 1 = derecho; columna 0 = pegada al borde, 1 = la
-- siguiente hacia dentro. El icono de la base asoma por debajo de la barra.
local function barraVertical(nombre: string, lado: number, columna: number, color: Color3, icono: string): BarraVertical
	local desplazamiento = 22 + columna * (DIAMETRO_BASE + SEPARACION_BARRAS)
	local env, cuerpo = Componentes.pegatina({
		Parent = pantalla,
		Nombre = nombre,
		Size = UDim2.fromOffset(ANCHO_BARRA, ALTO_BARRA),
		Position = UDim2.new(if lado < 0 then 0 else 1, -lado * desplazamiento, 0.5, 30),
		Anchor = Vector2.new(if lado < 0 then 0 else 1, 0.5),
		Radio = math.floor(ANCHO_BARRA / 2),
	})
	local borde = cuerpo:FindFirstChildOfClass("UIStroke") :: UIStroke
	local relleno = Componentes.marco({ Parent = cuerpo, Size = UDim2.new(1, -8, 0, 0), Position = UDim2.new(0.5, 0, 1, -4), Anchor = Vector2.new(0.5, 1), Color = color, Radio = math.floor(ANCHO_BARRA / 2) - 4, Nombre = "Relleno", ZIndex = 3 })
	local base = Componentes.circuloIcono({ Parent = env, Nombre = "Base", Clave = icono, Diametro = DIAMETRO_BASE, Position = UDim2.new(0.5, 0, 1, 2), Anchor = Vector2.new(0.5, 0.5), ZIndex = 4 })
	-- La etiqueta cuelga hacia dentro de la pantalla (pegada al borde de la
	-- barra que mira al centro), no centrada: centrada se saldria del viewport
	local etiqueta = Componentes.texto({
		Parent = env,
		Size = UDim2.fromOffset(150, 20),
		Position = UDim2.new(if lado < 0 then 0 else 1, 0, 0, -6),
		Anchor = Vector2.new(if lado < 0 then 0 else 1, 1),
		Tamano = 12,
		Titulo = true,
		Alinear = if lado < 0 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
		Color = Paleta.UI_TINTA,
		Contorno = Paleta.UI_PAPEL,
		ZIndex = 4,
	})
	return { envoltorio = env, cuerpo = cuerpo, relleno = relleno, etiqueta = etiqueta, borde = borde, base = base }
end

local barraEnergia = barraVertical("Energia", -1, 0, Paleta.UI_ENERGIA, "rayo")
local barraFuerza = barraVertical("Fuerza", 1, 0, Paleta.UI_FUERZA, "flecha")
local barraBolsa = barraVertical("Bolsa", 1, 1, Paleta.UI_BOLSA, "bolsa")
barraFuerza.etiqueta.Text = Textos.HUD.fuerza
barraBolsa.etiqueta.Text = Textos.HUD.bolsa

local pulsoBolsaLlena = TweenService:Create(barraBolsa.relleno, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.45 })
local pulsoEnergia = TweenService:Create(barraEnergia.etiqueta, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { TextTransparency = 0.6 })

-- ===========================================================================
-- Retrato y dock
-- ===========================================================================

local DIAMETRO_RETRATO = 84
local retrato, cuerpoRetrato = Componentes.pegatina({ Parent = pantalla, Nombre = "Retrato", Size = UDim2.fromOffset(DIAMETRO_RETRATO, DIAMETRO_RETRATO), Radio = DIAMETRO_RETRATO / 2 })
local iniciales = Componentes.texto({ Parent = cuerpoRetrato, Texto = string.upper(string.sub(jugador.DisplayName, 1, 2)), Size = UDim2.fromScale(1, 1), Alinear = Enum.TextXAlignment.Center, Tamano = 28, Titulo = true, ZIndex = 3 })
local cara = Instance.new("ImageLabel")
cara.Name = "Cara"
cara.Size = UDim2.new(1, -6, 1, -6)
cara.Position = UDim2.fromScale(0.5, 0.5)
cara.AnchorPoint = Vector2.new(0.5, 0.5)
cara.BackgroundTransparency = 1
cara.ScaleType = Enum.ScaleType.Crop
cara.ZIndex = 4
cara.Visible = false
Componentes.esquinas(cara, DIAMETRO_RETRATO)
cara.Parent = cuerpoRetrato
task.spawn(function()
	local ok, url = pcall(function()
		return Players:GetUserThumbnailAsync(jugador.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok and typeof(url) == "string" and url ~= "" then
		cara.Image = url
		cara.Visible = true
		iniciales.Visible = false
	end
end)

-- Cada pegatina del dock: icono arriba, nombre debajo y la insignia de la
-- tecla montada sobre el borde inferior (como en KOTAMON). 72 px para que el
-- nombre quepa sin pisar la insignia.
local LADO_DOCK = 72
local dock = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(4 * LADO_DOCK + 3 * 10, LADO_DOCK + 14), Transparencia = 1, Nombre = "Dock" })
Componentes.lista(dock, 10, true)
local escalaDock = Instance.new("UIScale")
escalaDock.Parent = dock

type ItemDock = { boton: TextButton, nombre: TextLabel, insignia: Frame, icono: GuiObject }
local itemsDock: { ItemDock } = {}

local function iconoDock(nombre: string, icono: string, tecla: string, orden: number, alPulsar: () -> ())
	local b = Componentes.boton({ Parent = dock, Nombre = "Dock_" .. icono, Texto = "", Size = UDim2.fromOffset(LADO_DOCK, LADO_DOCK), Radio = 16, Orden = orden, alPulsar = alPulsar })
	local ic = Componentes.icono({ Parent = b, Clave = icono, Tamano = 34, Position = UDim2.new(0.5, 0, 0, 5), Anchor = Vector2.new(0.5, 0), ZIndex = 3 })
	local t = Componentes.texto({ Parent = b, Texto = nombre, Size = UDim2.new(1, -4, 0, 14), Position = UDim2.new(0, 2, 0, 42), Tamano = 11, Titulo = true, Alinear = Enum.TextXAlignment.Center, Color = Paleta.UI_TINTA_SUAVE, ZIndex = 3, Escalar = true })
	local limite = Instance.new("UITextSizeConstraint")
	limite.MaxTextSize = 11
	limite.MinTextSize = 8
	limite.Parent = t
	local k = Componentes.insignia({ Parent = Componentes.envoltorioDe(b), Teclado = tecla, Tamano = 22, Position = UDim2.new(0.5, 0, 1, -4), Anchor = Vector2.new(0.5, 0.5), ZIndex = 5 })
	table.insert(itemsDock, { boton = b, nombre = t, insignia = k, icono = ic })
end

iconoDock(Textos.HUD.telefono, "telefono", "Q", 1, function()
	Menu.alternar("Tienda")
end)
iconoDock(Textos.HUD.album, "libreta", "J", 2, function()
	Menu.alternar("Album")
end)
iconoDock(Textos.HUD.logros, "trofeo", "L", 3, function()
	Menu.alternar("Logros")
end)
iconoDock(Textos.HUD.base, "casa", "B", 4, function()
	Menu.alternar("Base")
end)

-- ===========================================================================
-- Arriba-dcha: teletransporte. Abajo-dcha: pistas
-- ===========================================================================

local esquina = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(320, 40), Position = UDim2.new(1, -MARGEN, 0, 12), Anchor = Vector2.new(1, 0), Transparencia = 1, Nombre = "Teletransporte" })
Componentes.lista(esquina, 8, true, Enum.HorizontalAlignment.Right)
Componentes.boton({ Parent = esquina, Nombre = "IrCasa", Texto = Textos.HUD.irCasa, Icono = "casa", Size = UDim2.fromOffset(148, 40), Orden = 1, Tamano = 13, Radio = 14, alPulsar = function()
	TeletransporteEvent:FireServer("casa")
end })
Componentes.boton({ Parent = esquina, Nombre = "IrPatio", Texto = Textos.HUD.irPatio, Icono = "montana", Size = UDim2.fromOffset(148, 40), Orden = 2, Tamano = 13, Radio = 14, alPulsar = function()
	TeletransporteEvent:FireServer("patio")
end })

type Pista = { envoltorio: Frame, texto: TextLabel, insignia: Frame }

-- Pegatina horizontal [insignia] TEXTO [icono]; el ancho sigue al contenido
local function pista(nombre: string, alto: number, teclado: string, gamepad: Enum.KeyCode, icono: string?, orden: number): Pista
	local env, cuerpo = Componentes.pegatina({ Parent = pantalla, Nombre = nombre, Size = UDim2.fromOffset(200, alto), Anchor = Vector2.new(1, 1), Radio = math.floor(alto * 0.36), Orden = orden })
	local lista = Componentes.lista(cuerpo, 8, true)
	lista.VerticalAlignment = Enum.VerticalAlignment.Center
	Componentes.padding(cuerpo, 12, 0)
	local insignia = Componentes.insignia({ Parent = cuerpo, Teclado = teclado, Gamepad = gamepad, Tamano = alto - 16, Orden = 1, ZIndex = 3 })
	local t = Componentes.texto({ Parent = cuerpo, Size = UDim2.new(0, 0, 1, 0), Tamano = math.floor(alto * 0.4), Titulo = true, Ajustar = false, Orden = 2, ZIndex = 3 })
	t.AutomaticSize = Enum.AutomaticSize.X
	if icono then
		Componentes.icono({ Parent = cuerpo, Clave = icono, Tamano = alto - 12, Orden = 3, ZIndex = 3 })
	end
	local function ajustar()
		env.Size = UDim2.fromOffset(math.ceil(lista.AbsoluteContentSize.X / Componentes.escala()) + 24, alto)
	end
	lista:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(ajustar)
	task.defer(ajustar)
	env.Visible = false
	return { envoltorio = env, texto = t, insignia = insignia }
end

local pistaLanzar = pista("PistaLanzar", 44, "F", Enum.KeyCode.ButtonY, "lanzar", 1)
local pistaRecoger = pista("PistaRecoger", 36, Textos.HUD.clic, Enum.KeyCode.ButtonX, "mano", 2)

-- ===========================================================================
-- Disposicion (escritorio / tactil)
-- ===========================================================================

local function aplicarDisposicion()
	local tactil = Componentes.disposicion() == "tactil"
	if tactil then
		-- Esquinas de abajo para el thumbstick y el salto de Roblox
		retrato.Size = UDim2.fromOffset(52, 52)
		retrato.Position = UDim2.fromOffset(MARGEN, 10)
		retrato.AnchorPoint = Vector2.zero
		fila.Position = UDim2.fromOffset(MARGEN + 52 + 10, 12)
		dock.Position = UDim2.new(0.5, 0, 0, 8)
		dock.AnchorPoint = Vector2.new(0.5, 0)
		escalaDock.Scale = 0.82
		pistaLanzar.envoltorio.Position = UDim2.new(1, -MARGEN, 1, -130)
		pistaRecoger.envoltorio.Position = UDim2.new(1, -MARGEN, 1, -182)
	else
		retrato.Size = UDim2.fromOffset(DIAMETRO_RETRATO, DIAMETRO_RETRATO)
		retrato.Position = UDim2.new(0, MARGEN, 1, -MARGEN)
		retrato.AnchorPoint = Vector2.new(0, 1)
		fila.Position = UDim2.fromOffset(MARGEN, 12)
		dock.Position = UDim2.new(0, MARGEN + DIAMETRO_RETRATO + 12, 1, -MARGEN + 2)
		dock.AnchorPoint = Vector2.new(0, 1)
		escalaDock.Scale = 1
		pistaLanzar.envoltorio.Position = UDim2.new(1, -MARGEN, 1, -MARGEN)
		pistaRecoger.envoltorio.Position = UDim2.new(1, -MARGEN, 1, -MARGEN - 52)
	end
	for _, item in itemsDock do
		item.nombre.Visible = not tactil
		item.icono.Position = if tactil then UDim2.fromScale(0.5, 0.5) else UDim2.new(0.5, 0, 0, 6)
		item.icono.AnchorPoint = if tactil then Vector2.new(0.5, 0.5) else Vector2.new(0.5, 0)
	end
end

-- ===========================================================================
-- Refrescos
-- ===========================================================================

local recogidasSesion = 0
local ultimoConteoBolsa = 0

local function enPatio(): boolean
	return jugador:GetAttribute("EnPatio") == true
end

local function refrescarPistas()
	local plataforma = Entrada.plataforma()
	local sinPanel = not Menu.hayAbierto()
	-- Lanzar: solo con algo en la bolsa; en tactil lo dice el boton de ControlPatio
	local hayCarga = #EstadoCliente.bolsa.items > 0
	pistaLanzar.texto.Text = Textos.HUD.mantenerLanzar
	pistaLanzar.envoltorio.Visible = hayCarga and sinPanel and plataforma ~= "tactil"
	-- Recoger: solo en el patio y mientras se aprende
	pistaRecoger.texto.Text = if plataforma == "tactil" then Textos.HUD.tocarRecoger else Textos.HUD.mantenerRecoger
	pistaRecoger.envoltorio.Visible = enPatio() and sinPanel and recogidasSesion < RECOGIDAS_PARA_APRENDER
	barraFuerza.envoltorio.Visible = enPatio()
end

local function refrescarBolsa()
	local b = EstadoCliente.bolsa
	local n = #b.items
	if n > ultimoConteoBolsa then
		recogidasSesion += n - ultimoConteoBolsa
	end
	ultimoConteoBolsa = n
	local llena = n >= b.capacidad
	local fraccion = if b.capacidad > 0 then math.clamp(n / b.capacidad, 0, 1) else 0
	TweenService:Create(barraBolsa.relleno, TweenInfo.new(0.2), { Size = UDim2.new(1, -8, fraccion, if fraccion > 0 then -8 else 0) }):Play()
	if llena then
		barraBolsa.etiqueta.Text = Textos.HUD.bolsaLlenaBarra
		barraBolsa.etiqueta.TextColor3 = Paleta.UI_PELIGRO
		barraBolsa.relleno.BackgroundColor3 = Paleta.UI_PELIGRO
		barraBolsa.borde.Color = Paleta.UI_PELIGRO
		pulsoBolsaLlena:Play()
	else
		barraBolsa.etiqueta.Text = Textos.HUD.bolsa
		barraBolsa.etiqueta.TextColor3 = Paleta.UI_TINTA
		barraBolsa.relleno.BackgroundColor3 = Paleta.UI_BOLSA
		barraBolsa.borde.Color = Paleta.UI_TINTA
		pulsoBolsaLlena:Cancel()
		barraBolsa.relleno.BackgroundTransparency = 0
	end
	refrescarPistas()
end

local function refrescarPerfil()
	local p = EstadoCliente.perfil
	if not p then
		return
	end
	textoDinero.Text = Formato.dinero(p.dinero or 0)
	textoGemas.Text = Formato.miles(p.gemas or 0)
	local distintas = {}
	for _, copia in p.mascotas or {} do
		distintas[copia.id] = true
	end
	local n = 0
	for _ in distintas do
		n += 1
	end
	textoCartas.Text = string.format("%d/%d", n, #DefinicionesMascotas.LISTA)
end

local function refrescarEnergia(actual: number, max: number)
	local fraccion = if max > 0 then math.clamp(actual / max, 0, 1) else 0
	TweenService:Create(barraEnergia.relleno, TweenInfo.new(0.2), { Size = UDim2.new(1, -8, fraccion, if fraccion > 0 then -8 else 0) }):Play()
	if actual < 10 then
		barraEnergia.etiqueta.Text = Textos.HUD.restaurarEnergia
		barraEnergia.etiqueta.TextColor3 = Paleta.UI_PELIGRO
		barraEnergia.borde.Color = Paleta.UI_PELIGRO
		pulsoEnergia:Play()
	else
		barraEnergia.etiqueta.Text = string.format("%d/%d", actual, max)
		barraEnergia.etiqueta.TextColor3 = Paleta.UI_TINTA
		barraEnergia.borde.Color = Paleta.UI_TINTA
		pulsoEnergia:Cancel()
		barraEnergia.etiqueta.TextTransparency = 0
	end
end

local function refrescarCarga(fraccion: number)
	barraFuerza.relleno.Size = UDim2.new(1, -8, fraccion, if fraccion > 0 then -8 else 0)
	barraFuerza.relleno.BackgroundColor3 = if fraccion >= 0.99 then Paleta.UI_PRIMARIO else Paleta.UI_FUERZA
end

EstadoCliente.alCambiarPerfil:Connect(refrescarPerfil)
EstadoCliente.alCambiarBolsa:Connect(refrescarBolsa)
EstadoCliente.alCambiarEnergia:Connect(refrescarEnergia)
EstadoCliente.alCambiarCarga:Connect(refrescarCarga)
refrescarPerfil()
refrescarBolsa()
refrescarEnergia(EstadoCliente.energia.actual, EstadoCliente.energia.max)
refrescarCarga(0)

-- Menos ruido con un panel abierto
Menu.alCambiar:Connect(function(nombre)
	dock.Visible = nombre == nil
	esquina.Visible = nombre == nil
	refrescarPistas()
end)
jugador:GetAttributeChangedSignal("EnPatio"):Connect(refrescarPistas)
Componentes.alCambiarDisposicion:Connect(function()
	aplicarDisposicion()
	refrescarPistas()
end)
aplicarDisposicion()
refrescarPistas()
