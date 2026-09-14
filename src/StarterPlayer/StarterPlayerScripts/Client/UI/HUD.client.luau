--!strict
--[[
	HUD
	Lo que se ve siempre: dinero y gemas (arriba-izq), energia (arriba-centro),
	bolsa (abajo-izq) y los botones de menu (derecha). Solo presentacion: lee
	EstadoCliente y manda intencion por RemoteEvent o abre paneles por Menu.

	Carga Notificaciones para que los toasts existan desde el primer frame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
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

local pantalla = Componentes.pantalla("HUD", 1)

-- === Dinero y gemas ===
local panelDinero = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(200, 64), Position = UDim2.fromOffset(16, 12), Color = Paleta.UI_FONDO, Transparencia = 0.2 })
Componentes.padding(panelDinero, 12, 6)
Componentes.lista(panelDinero, 2)
local textoDinero = Componentes.texto({ Parent = panelDinero, Texto = "$0", Tamano = 22, Negrita = true, Color = Paleta.UI_DINERO, Size = UDim2.new(1, 0, 0, 26), Orden = 1 })
local textoGemas = Componentes.texto({ Parent = panelDinero, Texto = "0 Gemas", Tamano = 15, Negrita = true, Color = Paleta.UI_GEMAS, Size = UDim2.new(1, 0, 0, 20), Orden = 2 })

-- === Energia ===
local panelEnergia = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(280, 30), Position = UDim2.new(0.5, 0, 0, 14), Anchor = Vector2.new(0.5, 0), Transparencia = 1 })
local barraEnergia = Componentes.barra(panelEnergia, UDim2.fromScale(1, 1), Paleta.UI_ENERGIA)

-- === Bolsa ===
local panelBolsa = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(240, 92), Position = UDim2.new(0, 16, 1, -16), Anchor = Vector2.new(0, 1), Color = Paleta.UI_FONDO, Transparencia = 0.2 })
Componentes.padding(panelBolsa, 12, 8)
Componentes.lista(panelBolsa, 2)
local textoBolsa = Componentes.texto({ Parent = panelBolsa, Texto = Textos.HUD.bolsa .. " 0/8", Tamano = 18, Negrita = true, Size = UDim2.new(1, 0, 0, 24), Orden = 1 })
local textoDesglose = Componentes.texto({ Parent = panelBolsa, Texto = "", Tamano = 13, Color = Paleta.UI_TEXTO_SUAVE, Size = UDim2.new(1, 0, 0, 34), Orden = 2, AlinearY = Enum.TextYAlignment.Top })
local textoPista = Componentes.texto({ Parent = panelBolsa, Texto = "", Tamano = 12, Color = Paleta.UI_ACENTO, Size = UDim2.new(1, 0, 0, 16), Orden = 3 })

-- === Botones de menu ===
local columna = Componentes.marco({ Parent = pantalla, Size = UDim2.fromOffset(120, 300), Position = UDim2.new(1, -16, 0.5, 0), Anchor = Vector2.new(1, 0.5), Transparencia = 1 })
Componentes.lista(columna, 8, false, Enum.HorizontalAlignment.Right)

local function botonMenu(texto: string, orden: number, alPulsar: () -> ())
	return Componentes.boton({
		Parent = columna,
		Texto = texto,
		Size = UDim2.new(1, 0, 0, 42),
		Orden = orden,
		Color = Paleta.UI_PANEL,
		Tamano = 15,
		alPulsar = alPulsar,
	})
end

botonMenu(Textos.HUD.album, 1, function()
	Menu.alternar("Album")
end)
botonMenu(Textos.HUD.tienda, 2, function()
	Menu.alternar("Tienda")
end)
botonMenu(Textos.HUD.logros, 3, function()
	Menu.alternar("Logros")
end)
botonMenu(Textos.HUD.base, 4, function()
	Menu.alternar("Base")
end)
botonMenu(Textos.HUD.irCasa, 5, function()
	TeletransporteEvent:FireServer("casa")
end)
botonMenu(Textos.HUD.irPatio, 6, function()
	TeletransporteEvent:FireServer("patio")
end)

-- === Refrescos ===
local NOMBRES_TIPO = { basura = "Basura", tesoro = "Tesoro", fragmento = "Fragm.", mascota = "Mascota", figurina = "Figurita", cinta = "Cinta", traje = "Traje" }

local function refrescarBolsa()
	local b = EstadoCliente.bolsa
	local n = #b.items
	textoBolsa.Text = string.format("%s %d/%d", Textos.HUD.bolsa, n, b.capacidad)
	textoBolsa.TextColor3 = if n >= b.capacidad then Paleta.UI_ENERGIA else Paleta.UI_TEXTO
	local conteo: { [string]: number } = {}
	for _, item in b.items do
		conteo[item.tipo] = (conteo[item.tipo] or 0) + 1
	end
	local partes = {}
	for tipo, nombre in NOMBRES_TIPO do
		if conteo[tipo] then
			table.insert(partes, string.format("%s %d", nombre, conteo[tipo]))
		end
	end
	table.sort(partes)
	textoDesglose.Text = if #partes > 0 then table.concat(partes, " · ") else "Vacía"
	local hayLanzable = (conteo.basura or 0) + (conteo.tesoro or 0) > 0
	if hayLanzable then
		local tecla = Entrada.etiqueta("F", "Y")
		textoPista.Text = if tecla ~= "" then tecla .. ": " .. Textos.HUD.lanzar .. " a la caseta" else Textos.HUD.lanzar .. " a la caseta (botón)"
	else
		textoPista.Text = ""
	end
end

local function refrescarPerfil()
	local p = EstadoCliente.perfil
	if not p then
		return
	end
	textoDinero.Text = Formato.dinero(p.dinero or 0)
	textoGemas.Text = Formato.gemas(p.gemas or 0)
end

local function refrescarEnergia(actual: number, max: number)
	barraEnergia.fijar(if max > 0 then actual / max else 0, string.format("%s %d/%d", Textos.HUD.energia, actual, max))
end

EstadoCliente.alCambiarPerfil:Connect(refrescarPerfil)
EstadoCliente.alCambiarBolsa:Connect(refrescarBolsa)
EstadoCliente.alCambiarEnergia:Connect(refrescarEnergia)
refrescarPerfil()
refrescarBolsa()
refrescarEnergia(EstadoCliente.energia.actual, EstadoCliente.energia.max)

-- Ocultar el HUD lateral mientras hay un panel abierto (menos ruido)
Menu.alCambiar:Connect(function(nombre)
	columna.Visible = nombre == nil
end)
