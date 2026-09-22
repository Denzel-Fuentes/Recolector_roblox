--!strict
--[[
	Notificaciones (ModuleScript)
	Tres canales de texto efimero, y solo estos tres (el dialogo de los NPC es
	otra cosa: UI/Dialogo):

	  toast   lo que te pasa a TI ("+$40", "Bolsa llena"). Pila arriba-centro:
	          chip de papel con el contorno y una marca del color del tipo, 3.5 s.
	  feed    lo que pasa en el SERVIDOR (alguien activo un monton grande,
	          encontro una Rara, Dona Chatarra repuso). Arriba a la derecha, es
	          la senal social del GDD: invita a ir donde esta pasando algo.
	  logro   tarjeta grande centrada con el trofeo, 4 s.

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

-- Toasts: arriba-centro (debajo del dock tactil, que va a 8..70)
local pilaToasts = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(400, 300), Position = UDim2.new(0.5, 0, 0, 76), Anchor = Vector2.new(0.5, 0), Transparencia = 1, Nombre = "Toasts" })
Componentes.lista(pilaToasts, 6, false, Enum.HorizontalAlignment.Center)

-- Feed: arriba-derecha, debajo de los botones de teletransporte
local pilaFeed = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(320, 220), Position = UDim2.new(1, -16, 0, 62), Anchor = Vector2.new(1, 0), Transparencia = 1, Nombre = "Feed" })
Componentes.lista(pilaFeed, 4, false, Enum.HorizontalAlignment.Right)

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

local function desvanecer(etiqueta: TextLabel, tras: number)
	task.delay(tras, function()
		if not etiqueta.Parent then
			return
		end
		local t = TweenService:Create(etiqueta, TweenInfo.new(0.35), { TextTransparency = 1, BackgroundTransparency = 1 })
		t:Play()
		for _, hijo in etiqueta:GetChildren() do
			if hijo:IsA("UIStroke") then
				TweenService:Create(hijo, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			elseif hijo:IsA("Frame") then
				TweenService:Create(hijo, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			end
		end
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
	local color = COLOR_TIPO[tipo or "info"] or Paleta.UI_TINTA_SUAVE
	local t = Componentes.texto({
		Parent = pilaToasts,
		Texto = texto,
		Size = UDim2.new(1, 0, 0, 36),
		Tamano = 15,
		Negrita = true,
		Alinear = Enum.TextXAlignment.Center,
		Fondo = Paleta.UI_PAPEL,
		Color = Paleta.UI_TINTA,
		Orden = ordenToast,
	})
	t.AutomaticSize = Enum.AutomaticSize.Y
	Componentes.padding(t, 22, 8)
	Componentes.borde(t, color, 2.5)
	-- Marca del tipo: una pestana de color pegada al borde izquierdo
	Componentes.marco({ Parent = t, Size = UDim2.new(0, 8, 1, -12), Position = UDim2.fromOffset(-16, 6), Color = color, Radio = 4, Nombre = "Marca", ZIndex = 2 })
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
		Tamano = 12,
		Negrita = true,
		Alinear = Enum.TextXAlignment.Right,
		Fondo = Paleta.UI_PAPEL,
		Color = Paleta.UI_TINTA,
		Orden = ordenFeed,
	})
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.BackgroundTransparency = 0.12
	Componentes.padding(t, 10, 4)
	Componentes.borde(t, Paleta.UI_TINTA, 1.5)
	recortar(pilaFeed, MAX_FEED)
	desvanecer(t, 9)
end

function Notificaciones.logro(nombre: string, descripcion: string)
	local tarjeta, cuerpo = Componentes.pegatina({
		Parent = pantalla,
		Nombre = "Logro",
		Size = UDim2.fromOffset(400, 92),
		Position = UDim2.new(0.5, 0, 0, -110),
		Anchor = Vector2.new(0.5, 0),
		Radio = 16,
		Contorno = Paleta.UI_PRIMARIO,
		Grosor = 3,
	})
	Componentes.icono({ Parent = cuerpo, Clave = "trofeo", Tamano = 54, Position = UDim2.new(0, 14, 0.5, 0), Anchor = Vector2.new(0, 0.5), ZIndex = 3 })
	Componentes.texto({ Parent = cuerpo, Texto = Textos.LOGROS.desbloqueado, Size = UDim2.new(1, -92, 0, 20), Position = UDim2.fromOffset(80, 8), Tamano = 12, Color = Paleta.UI_TINTA_SUAVE, Titulo = true, ZIndex = 3 })
	Componentes.texto({ Parent = cuerpo, Texto = nombre, Size = UDim2.new(1, -92, 0, 26), Position = UDim2.fromOffset(80, 28), Tamano = 19, Titulo = true, ZIndex = 3 })
	Componentes.texto({ Parent = cuerpo, Texto = descripcion, Size = UDim2.new(1, -92, 0, 20), Position = UDim2.fromOffset(80, 56), Tamano = 12, Negrita = true, Color = Paleta.UI_TINTA_SUAVE, ZIndex = 3 })
	TweenService:Create(tarjeta, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 12) }):Play()
	task.delay(4, function()
		local t = TweenService:Create(tarjeta, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -110) })
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
