--!strict
--[[
	HUD
	Distribucion calcada de KOTAMON (referencia del usuario):

	  arriba-izq     $ dinero  |  cartas (mascotas distintas)  |  gemas
	  izquierda      barra vertical de ENERGIA (se llena de abajo arriba)
	  derecha        barra vertical de FUERZA de lanzamiento (mantener F) y, a
	                 su lado, la de BOLSA: cuanto llevas, sin numeros (decision
	                 del usuario: se ve llenarse, y "LLENA" en rojo avisa de que
	                 toca volver al contenedor)
	  abajo-izq      avatar + iconos con tecla: telefono Q, album J, logros L, base B
	  abajo-dcha     "MANTEN F PARA LANZAR" cuando la bolsa no esta vacia
	  arriba-dcha    Ir a casa / Ir al patio (pequenos)

	Solo presentacion: lee EstadoCliente y manda intencion por RemoteEvent o
	abre paneles por Menu. Carga Notificaciones para que los toasts existan
	desde el primer frame.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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

local TeletransporteEvent = Red.evento("TeletransporteEvent")

local jugador = Players.LocalPlayer
local pantalla = Componentes.pantalla("HUD", 1)

-- ===========================================================================
-- Arriba-izq: pildoras
-- ===========================================================================

local fila = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(700, 44), Position = UDim2.fromOffset(16, 12), Transparencia = 1, Nombre = "Pildoras" })
Componentes.lista(fila, 8, true)

local function pildora(nombre: string, ancho: number, color: Color3, orden: number): (Frame, TextLabel)
	local f = Componentes.marco({ Parent = fila, Size = UDim2.fromOffset(ancho, 44), Color = Paleta.UI_FONDO, Transparencia = 0.15, Radio = 12, Orden = orden, Nombre = nombre })
	Componentes.borde(f, color, 2)
	local icono = Componentes.marco({ Parent = f, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(10, 11), Color = color, Radio = 6, Nombre = "Icono" })
	icono.ZIndex = 2
	local t = Componentes.texto({ Parent = f, Size = UDim2.new(1, -46, 1, 0), Position = UDim2.fromOffset(40, 0), Tamano = 20, Negrita = true, Color = color })
	return f, t
end

local _, textoDinero = pildora("Dinero", 150, Paleta.UI_DINERO, 1)
local pildoraCartas, textoCartas = pildora("Cartas", 120, Paleta.UI_GEMAS, 2)
local _, textoGemas = pildora("Gemas", 130, Paleta.UI_GEMAS, 3)
-- El icono de las cartas es una "carta"
local iconoCartas = pildoraCartas:FindFirstChild("Icono") :: Frame
iconoCartas.Size = UDim2.fromOffset(16, 22)
iconoCartas.Position = UDim2.fromOffset(13, 11)

-- ===========================================================================
-- Barras verticales
-- ===========================================================================

local ANCHO_BARRA = 26
local SEPARACION_BARRAS = 22 -- que "¡LLENA!" y "Fuerza" no se peguen

-- lado -1 = borde izquierdo, 1 = derecho; columna 0 = pegada al borde, 1 = la
-- siguiente hacia dentro
local function barraVertical(nombre: string, lado: number, columna: number, color: Color3): (Frame, Frame, TextLabel)
	local desplazamiento = 22 + columna * (ANCHO_BARRA + SEPARACION_BARRAS)
	local marco = Componentes.marco({
		Parent = pantalla,
		Size = UDim2.fromOffset(ANCHO_BARRA, 190),
		Position = UDim2.new(if lado < 0 then 0 else 1, -lado * desplazamiento, 0.5, 40),
		Anchor = Vector2.new(if lado < 0 then 0 else 1, 0.5),
		Color = Paleta.UI_FONDO,
		Transparencia = 0.15,
		Radio = 13,
		Nombre = nombre,
	})
	Componentes.borde(marco, Paleta.UI_PANEL_CLARO, 2)
	local relleno = Componentes.marco({ Parent = marco, Size = UDim2.new(1, -6, 0, 0), Position = UDim2.new(0.5, 0, 1, -3), Anchor = Vector2.new(0.5, 1), Color = color, Radio = 10, Nombre = "Relleno" })
	local etiqueta = Componentes.texto({
		Parent = marco,
		Size = UDim2.fromOffset(120, 20),
		Position = UDim2.new(0.5, 0, 1, 6),
		Anchor = Vector2.new(0.5, 0),
		Tamano = 11,
		Negrita = true,
		Alinear = Enum.TextXAlignment.Center,
		Color = Paleta.UI_TEXTO_SUAVE,
	})
	return marco, relleno, etiqueta
end

local _, rellenoEnergia, etiquetaEnergia = barraVertical("Energia", -1, 0, Paleta.UI_ENERGIA)
local _, rellenoFuerza, etiquetaFuerza = barraVertical("Fuerza", 1, 0, Paleta.UI_ACENTO)
etiquetaFuerza.Text = Textos.HUD.fuerza
-- La bolsa, al lado de la fuerza: se llena con cada objeto recogido
local COLOR_BOLSA_HUD = Paleta.escalar(Paleta.BOLSA, 1.6)
local marcoBolsa, rellenoBolsa, etiquetaBolsa = barraVertical("Bolsa", 1, 1, COLOR_BOLSA_HUD)
local bordeBolsa = marcoBolsa:FindFirstChildOfClass("UIStroke") :: UIStroke
etiquetaBolsa.Text = Textos.HUD.bolsa
local pulsoBolsaLlena = TweenService:Create(rellenoBolsa, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.45 })

-- ===========================================================================
-- Abajo-izq: avatar e iconos con tecla
-- ===========================================================================

local dock = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(420, 78), Position = UDim2.new(0, 16, 1, -16), Anchor = Vector2.new(0, 1), Transparencia = 1, Nombre = "Dock" })
Componentes.lista(dock, 10, true)

local avatar = Componentes.marco({ Parent = dock, Size = UDim2.fromOffset(70, 70), Color = Paleta.UI_FONDO, Radio = 35, Orden = 1, Nombre = "Avatar" })
Componentes.borde(avatar, Paleta.UI_TEXTO, 2)
local iniciales = string.upper(string.sub(jugador.DisplayName, 1, 2))
Componentes.texto({ Parent = avatar, Texto = iniciales, Size = UDim2.fromScale(1, 1), Alinear = Enum.TextXAlignment.Center, Tamano = 24, Negrita = true })

local function iconoDock(nombre: string, tecla: string, color: Color3, orden: number, alPulsar: () -> ())
	local b = Componentes.boton({ Parent = dock, Texto = "", Size = UDim2.fromOffset(62, 62), Color = Paleta.UI_FONDO, Radio = 14, Orden = orden, alPulsar = alPulsar })
	b.Name = "Dock_" .. nombre
	Componentes.borde(b, color, 2)
	local simbolo = Componentes.marco({ Parent = b, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0.5, 0, 0, 8), Anchor = Vector2.new(0.5, 0), Color = color, Radio = 7 })
	simbolo.ZIndex = 2
	local t = Componentes.texto({ Parent = b, Texto = nombre, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -18), Tamano = 10, Alinear = Enum.TextXAlignment.Center, Color = Paleta.UI_TEXTO_SUAVE })
	t.ZIndex = 2
	local k = Componentes.texto({ Parent = b, Texto = tecla, Size = UDim2.fromOffset(20, 18), Position = UDim2.new(1, -4, 0, -6), Anchor = Vector2.new(1, 0), Tamano = 11, Negrita = true, Alinear = Enum.TextXAlignment.Center, Fondo = Paleta.UI_ACENTO, Color = Paleta.UI_FONDO })
	k.ZIndex = 3
	k.Visible = not Entrada.esTactil()
	return b
end

iconoDock(Textos.HUD.telefono, "Q", Paleta.UI_GEMAS, 2, function()
	Menu.alternar("Tienda")
end)
iconoDock(Textos.HUD.album, "J", Paleta.UI_DINERO, 3, function()
	Menu.alternar("Album")
end)
iconoDock(Textos.HUD.logros, "L", Paleta.UI_ENERGIA, 4, function()
	Menu.alternar("Logros")
end)
iconoDock(Textos.HUD.base, "B", Paleta.MATERIAL.Papel, 5, function()
	Menu.alternar("Base")
end)

-- ===========================================================================
-- Arriba-dcha: teletransporte. Abajo-dcha: pista de lanzar
-- ===========================================================================

local esquina = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(260, 36), Position = UDim2.new(1, -16, 0, 12), Anchor = Vector2.new(1, 0), Transparencia = 1 })
Componentes.lista(esquina, 8, true, Enum.HorizontalAlignment.Right)
Componentes.boton({ Parent = esquina, Texto = Textos.HUD.irCasa, Size = UDim2.fromOffset(120, 34), Orden = 1, Color = Paleta.UI_PANEL, Tamano = 13, alPulsar = function()
	TeletransporteEvent:FireServer("casa")
end })
Componentes.boton({ Parent = esquina, Texto = Textos.HUD.irPatio, Size = UDim2.fromOffset(120, 34), Orden = 2, Color = Paleta.UI_PANEL, Tamano = 13, alPulsar = function()
	TeletransporteEvent:FireServer("patio")
end })

local pistaLanzar = Componentes.texto({
	Parent = pantalla,
	Size = UDim2.fromOffset(300, 30),
	Position = UDim2.new(1, -16, 1, -16),
	Anchor = Vector2.new(1, 1),
	Tamano = 14,
	Negrita = true,
	Alinear = Enum.TextXAlignment.Right,
	Color = Paleta.UI_ACENTO,
})
pistaLanzar.Visible = false

-- Encima de la de lanzar: como se recoge (mantener el clic). Solo en el patio.
local pistaRecoger = Componentes.texto({
	Parent = pantalla,
	Size = UDim2.fromOffset(360, 30),
	Position = UDim2.new(1, -16, 1, -46),
	Anchor = Vector2.new(1, 1),
	Tamano = 14,
	Negrita = true,
	Alinear = Enum.TextXAlignment.Right,
	Color = Paleta.UI_TEXTO_SUAVE,
})
pistaRecoger.Visible = false

local function refrescarPistaRecoger()
	local plataforma = Entrada.plataforma()
	if plataforma == "tactil" then
		pistaRecoger.Text = Textos.HUD.tocarRecoger
	else
		pistaRecoger.Text = Textos.formatear(Textos.HUD.mantenerRecoger, { tecla = if plataforma == "gamepad" then "X" else "CLIC" })
	end
	pistaRecoger.Visible = jugador:GetAttribute("EnPatio") == true and not Menu.hayAbierto()
end

-- ===========================================================================
-- Refrescos
-- ===========================================================================

local function refrescarBolsa()
	local b = EstadoCliente.bolsa
	local n = #b.items
	local llena = n >= b.capacidad
	local fraccion = if b.capacidad > 0 then math.clamp(n / b.capacidad, 0, 1) else 0
	TweenService:Create(rellenoBolsa, TweenInfo.new(0.2), { Size = UDim2.new(1, -6, fraccion, -6) }):Play()
	if llena then
		etiquetaBolsa.Text = Textos.HUD.bolsaLlenaBarra
		etiquetaBolsa.TextColor3 = Paleta.UI_PELIGRO
		rellenoBolsa.BackgroundColor3 = Paleta.UI_PELIGRO
		bordeBolsa.Color = Paleta.UI_PELIGRO
		pulsoBolsaLlena:Play()
	else
		etiquetaBolsa.Text = Textos.HUD.bolsa
		etiquetaBolsa.TextColor3 = Paleta.UI_TEXTO_SUAVE
		rellenoBolsa.BackgroundColor3 = COLOR_BOLSA_HUD
		bordeBolsa.Color = Paleta.UI_PANEL_CLARO
		pulsoBolsaLlena:Cancel()
		rellenoBolsa.BackgroundTransparency = 0
	end
	if n > 0 then
		local plataforma = Entrada.plataforma()
		if plataforma == "tactil" then
			pistaLanzar.Text = Textos.HUD.tocarLanzar
		else
			pistaLanzar.Text = Textos.formatear(Textos.HUD.mantenerLanzar, { tecla = if plataforma == "gamepad" then "Y" else "F" })
		end
		pistaLanzar.Visible = not Menu.hayAbierto()
	else
		pistaLanzar.Visible = false
	end
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
	TweenService:Create(rellenoEnergia, TweenInfo.new(0.2), { Size = UDim2.new(1, -6, fraccion, -6) }):Play()
	if actual < 10 then
		etiquetaEnergia.Text = Textos.HUD.restaurarEnergia
		etiquetaEnergia.TextColor3 = Paleta.UI_PELIGRO
	else
		etiquetaEnergia.Text = string.format("%d/%d", actual, max)
		etiquetaEnergia.TextColor3 = Paleta.UI_TEXTO_SUAVE
	end
end

local function refrescarCarga(fraccion: number)
	rellenoFuerza.Size = UDim2.new(1, -6, fraccion, -6)
	rellenoFuerza.BackgroundColor3 = if fraccion >= 0.99 then Paleta.UI_ENERGIA else Paleta.UI_ACENTO
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
	refrescarBolsa()
	refrescarPistaRecoger()
end)
jugador:GetAttributeChangedSignal("EnPatio"):Connect(refrescarPistaRecoger)
UserInputService.LastInputTypeChanged:Connect(refrescarPistaRecoger)
refrescarPistaRecoger()
