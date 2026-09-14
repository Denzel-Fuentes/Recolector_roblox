--!strict
--[[
	Notificaciones (ModuleScript)
	Tres canales de texto efimero, y solo estos tres:

	  toast   lo que te pasa a TI ("+$40", "Bolsa llena"). Pila arriba-centro,
	          color por tipo, 3.5 s.
	  feed    lo que pasa en el SERVIDOR (alguien activo un monton grande,
	          encontro una Rara, Dona Chatarra repuso). Arriba a la derecha, es
	          la senal social del GDD: invita a ir donde esta pasando algo.
	  logro   tarjeta grande centrada, 4 s.

	Se conecta a NotificacionEvent, FeedEvent y LogroEvent al cargarse.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local DefinicionesLogros = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesLogros"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Componentes = require(script.Parent:WaitForChild("Componentes"))

local Notificaciones = {}

local pantalla = Componentes.pantalla("Notificaciones", 20)

-- Toasts: arriba-centro
local pilaToasts = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(380, 300), Position = UDim2.new(0.5, 0, 0, 70), Anchor = Vector2.new(0.5, 0), Transparencia = 1, Nombre = "Toasts" })
Componentes.lista(pilaToasts, 6, false, Enum.HorizontalAlignment.Center)

-- Feed: arriba-derecha
local pilaFeed = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(320, 220), Position = UDim2.new(1, -16, 0, 60), Anchor = Vector2.new(1, 0), Transparencia = 1, Nombre = "Feed" })
Componentes.lista(pilaFeed, 4, false, Enum.HorizontalAlignment.Right)

local COLOR_TIPO = {
	aviso = Paleta.UI_ENERGIA,
	exito = Paleta.UI_DINERO,
	dinero = Paleta.UI_DINERO,
	objeto = Paleta.UI_GEMAS,
	peligro = Paleta.UI_PELIGRO,
	info = Paleta.UI_TEXTO_SUAVE,
}

local MAX_TOASTS = 5
local MAX_FEED = 6

local function desvanecer(etiqueta: TextLabel, tras: number)
	task.delay(tras, function()
		if not etiqueta.Parent then
			return
		end
		local t = TweenService:Create(etiqueta, TweenInfo.new(0.35), { TextTransparency = 1, BackgroundTransparency = 1 })
		t:Play()
		t.Completed:Wait()
		etiqueta:Destroy()
	end)
end

local function recortar(pila: Frame, max: number)
	local hijos = {}
	for _, h in pila:GetChildren() do
		if h:IsA("TextLabel") then
			table.insert(hijos, h)
		end
	end
	table.sort(hijos, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #hijos > max do
		local viejo = table.remove(hijos, 1)
		if viejo then
			viejo:Destroy()
		end
	end
end

local ordenToast = 0
function Notificaciones.mostrar(texto: string, tipo: string?)
	ordenToast += 1
	local color = COLOR_TIPO[tipo or "info"] or Paleta.UI_TEXTO_SUAVE
	local t = Componentes.texto({
		Parent = pilaToasts,
		Texto = texto,
		Size = UDim2.new(1, 0, 0, 34),
		Tamano = 16,
		Negrita = true,
		Alinear = Enum.TextXAlignment.Center,
		Fondo = Paleta.UI_FONDO,
		Color = color,
		Orden = ordenToast,
	})
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.BackgroundTransparency = 0.15
	Componentes.padding(t, 12, 6)
	Componentes.borde(t, color, 1.5)
	t.TextTransparency = 1
	TweenService:Create(t, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	recortar(pilaToasts, MAX_TOASTS)
	desvanecer(t, 3.5)
end

local ordenFeed = 0
function Notificaciones.feed(texto: string)
	ordenFeed += 1
	local t = Componentes.texto({
		Parent = pilaFeed,
		Texto = texto,
		Size = UDim2.new(1, 0, 0, 26),
		Tamano = 13,
		Alinear = Enum.TextXAlignment.Right,
		Fondo = Paleta.UI_FONDO,
		Color = Paleta.UI_TEXTO,
		Orden = ordenFeed,
	})
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.BackgroundTransparency = 0.4
	Componentes.padding(t, 10, 4)
	recortar(pilaFeed, MAX_FEED)
	desvanecer(t, 9)
end

function Notificaciones.logro(nombre: string, descripcion: string)
	local tarjeta = Componentes.marco({
		Parent = pantalla,
		Size = UDim2.fromOffset(360, 84),
		Position = UDim2.new(0.5, 0, 0, -100),
		Anchor = Vector2.new(0.5, 0),
		Color = Paleta.UI_FONDO,
		Radio = 12,
	})
	Componentes.borde(tarjeta, Paleta.UI_ACENTO, 2)
	Componentes.texto({ Parent = tarjeta, Texto = Textos.LOGROS.desbloqueado, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(12, 8), Tamano = 13, Color = Paleta.UI_ACENTO, Negrita = true })
	Componentes.texto({ Parent = tarjeta, Texto = nombre, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(12, 30), Tamano = 19, Negrita = true })
	Componentes.texto({ Parent = tarjeta, Texto = descripcion, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(12, 56), Tamano = 13, Color = Paleta.UI_TEXTO_SUAVE })
	TweenService:Create(tarjeta, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 12) }):Play()
	task.delay(4, function()
		local t = TweenService:Create(tarjeta, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -100) })
		t:Play()
		t.Completed:Wait()
		tarjeta:Destroy()
	end)
end

Red.evento("NotificacionEvent").OnClientEvent:Connect(function(texto, tipo)
	if typeof(texto) == "string" then
		Notificaciones.mostrar(texto, tipo)
	end
end)

Red.evento("FeedEvent").OnClientEvent:Connect(function(texto)
	if typeof(texto) == "string" then
		Notificaciones.feed(texto)
	end
end)

Red.evento("LogroEvent").OnClientEvent:Connect(function(idLogro)
	local def = DefinicionesLogros.POR_ID[idLogro]
	if def then
		Notificaciones.logro(def.nombre, def.descripcion)
	end
end)

return Notificaciones
