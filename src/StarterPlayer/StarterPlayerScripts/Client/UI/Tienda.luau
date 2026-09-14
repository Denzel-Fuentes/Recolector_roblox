--!strict
--[[
	Tienda (ModuleScript)
	La caseta de Dona Chatarra, con las 4 pestanas del GDD:

	  Mejoras    las 7, con nivel, valor actual -> siguiente y coste en $.
	  Mascotas   Sobre Premium (Gemas), Contenedor Dorado (bloqueado hasta las 7
	             mejoras al maximo; $ o Gemas), vender duplicados. Ambos con el
	             boton "Ver probabilidades" ANTES de comprar.
	  Trajes     3 gratis (encontrar en montones; equipar) + 2 premium (Robux) y
	             las 2 skins de base.
	  Gemas      packs de Gemas (Developer Products) y Game Passes.

	Compras con Robux: el cliente llama a MarketplaceService directamente; con
	id 0 (placeholder) se avisa de que el producto no existe aun. El servidor
	resuelve la compra en MonetizacionHandler.

	La revelacion de sobres/contenedores llega por ResultadoSobreEvent y se
	muestra como un sub-modal con las mascotas obtenidas.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))
local Productos = require(Config:WaitForChild("Productos"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosMascota = require(Utilidades:WaitForChild("ModelosMascota"))
local Formato = require(Utilidades:WaitForChild("Formato"))
local Red = require(Utilidades:WaitForChild("Red"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Componentes = require(script.Parent:WaitForChild("Componentes"))
local Menu = require(script.Parent:WaitForChild("Menu"))
local Probabilidades = require(script.Parent:WaitForChild("Probabilidades"))
local Notificaciones = require(script.Parent:WaitForChild("Notificaciones"))

local ComprarMejoraEvent = Red.evento("ComprarMejoraEvent")
local ComprarSobreEvent = Red.evento("ComprarSobreEvent")
local ContenedorDoradoEvent = Red.evento("ContenedorDoradoEvent")
local VenderDuplicadosEvent = Red.evento("VenderDuplicadosEvent")
local PonerTrajeEvent = Red.evento("PonerTrajeEvent")
local PonerSkinBaseEvent = Red.evento("PonerSkinBaseEvent")
local ResultadoSobreEvent = Red.evento("ResultadoSobreEvent")

local jugador = Players.LocalPlayer

local Tienda = {}

local ANCHO, ALTO = 900, 600
local modal = Componentes.modal("Tienda", Textos.TIENDA.titulo, ANCHO, ALTO)
local contenido = modal.contenido

local cuerpo = Componentes.scroll(contenido, UDim2.new(1, 0, 1, -46), UDim2.fromOffset(0, 44))
Componentes.lista(cuerpo, 8)
Componentes.padding(cuerpo, 4)

local pestanaActual = 1

-- ===========================================================================
-- Helpers
-- ===========================================================================

local function fila(orden: number, alto: number?): Frame
	local f = Componentes.marco({ Parent = cuerpo, Size = UDim2.new(1, -12, 0, alto or 64), Color = Paleta.UI_PANEL, Radio = 10, Orden = orden, Nombre = "Fila" .. orden })
	Componentes.padding(f, 12, 8)
	return f
end

local function comprarRobuxPase(pase: Productos.Pase)
	if pase.gamePassId == 0 then
		Notificaciones.mostrar(Textos.TIENDA.sinIds, "aviso")
		return
	end
	MarketplaceService:PromptGamePassPurchase(jugador, pase.gamePassId)
end

local function comprarRobuxProducto(producto: Productos.Producto)
	if producto.productId == 0 then
		Notificaciones.mostrar(Textos.TIENDA.sinIds, "aviso")
		return
	end
	MarketplaceService:PromptProductPurchase(jugador, producto.productId)
end

-- ===========================================================================
-- Pestana 1: Mejoras
-- ===========================================================================

local function pintarMejoras()
	local p = EstadoCliente.perfil
	local dinero = if p then (p.dinero or 0) else 0
	for i, def in DefinicionesMejoras.LISTA do
		local nivel = EstadoCliente.nivelMejora(def.id)
		local coste = DefinicionesMejoras.coste(def.id, nivel)
		local f = fila(i, 70)
		Componentes.texto({ Parent = f, Texto = def.nombre, Size = UDim2.new(0.25, 0, 0, 24), Tamano = 17, Negrita = true })
		Componentes.texto({ Parent = f, Texto = def.descripcion, Size = UDim2.new(0.55, 0, 0, 18), Position = UDim2.fromOffset(0, 26), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE })
		local valorActual = DefinicionesMejoras.textoValor(def.id, nivel)
		local textoValor = if coste then valorActual .. "  →  " .. DefinicionesMejoras.textoValor(def.id, nivel + 1) else valorActual
		Componentes.texto({ Parent = f, Texto = textoValor, Size = UDim2.new(0.45, 0, 0, 20), Position = UDim2.new(0.25, 0, 0, 2), Tamano = 14, Color = Paleta.UI_ACENTO })
		Componentes.texto({ Parent = f, Texto = if coste then Textos.formatear(Textos.TIENDA.nivel, { n = nivel }) else Textos.TIENDA.maximo, Size = UDim2.new(0.2, 0, 0, 20), Position = UDim2.new(0.55, 0, 0, 26), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE })
		local b = Componentes.boton({
			Parent = f,
			Texto = if coste then Formato.dinero(coste) else Textos.TIENDA.maximo,
			Size = UDim2.fromOffset(130, 36),
			Position = UDim2.new(1, -130, 0.5, -18),
			Color = Paleta.UI_DINERO,
			ColorTexto = Paleta.UI_FONDO,
			Tamano = 14,
			Deshabilitado = coste == nil or dinero < coste,
			alPulsar = function()
				ComprarMejoraEvent:FireServer(def.id)
			end,
		})
		b.Name = "Comprar_" .. def.id
	end
end

-- ===========================================================================
-- Pestana 2: Mascotas
-- ===========================================================================

local function pintarMascotas()
	local p = EstadoCliente.perfil
	local gemas = if p then (p.gemas or 0) else 0
	local dinero = if p then (p.dinero or 0) else 0

	-- Sobre Premium
	local f = fila(1, 110)
	Componentes.texto({ Parent = f, Texto = Textos.TIENDA.sobrePremium, Size = UDim2.new(0.6, 0, 0, 24), Tamano = 17, Negrita = true, Color = Paleta.UI_GEMAS })
	Componentes.texto({ Parent = f, Texto = Productos.SOBRE_PREMIUM.descripcion, Size = UDim2.new(0.6, 0, 0, 40), Position = UDim2.fromOffset(0, 26), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE, AlinearY = Enum.TextYAlignment.Top })
	Componentes.boton({ Parent = f, Nombre = "VerProbabilidades", Texto = Textos.TIENDA.verProbabilidades, Size = UDim2.fromOffset(170, 34), Position = UDim2.new(0, 0, 1, -34), Tamano = 13, alPulsar = function()
		Probabilidades.abrir("sobre")
	end })
	local bSobre = Componentes.boton({ Parent = f, Texto = Textos.formatear(Textos.TIENDA.pagarGemas, { precio = GameConfig.PRECIO_SOBRE_GEMAS }), Size = UDim2.fromOffset(170, 40), Position = UDim2.new(1, -170, 0.5, -20), Color = Paleta.UI_GEMAS, ColorTexto = Paleta.UI_FONDO, Tamano = 14, Deshabilitado = gemas < GameConfig.PRECIO_SOBRE_GEMAS, alPulsar = function()
		ComprarSobreEvent:FireServer()
	end })
	bSobre.Name = "ComprarSobre"

	-- Contenedor Dorado
	local maxeadas = 0
	for _, def in DefinicionesMejoras.LISTA do
		if EstadoCliente.nivelMejora(def.id) >= DefinicionesMejoras.NIVEL_MAX then
			maxeadas += 1
		end
	end
	local desbloqueado = maxeadas >= #DefinicionesMejoras.LISTA
	local f2 = fila(2, 120)
	Componentes.texto({ Parent = f2, Texto = Textos.TIENDA.contenedorDorado, Size = UDim2.new(0.6, 0, 0, 24), Tamano = 17, Negrita = true, Color = Paleta.DORADO })
	Componentes.texto({ Parent = f2, Texto = Productos.CONTENEDOR_DORADO.descripcion, Size = UDim2.new(0.6, 0, 0, 40), Position = UDim2.fromOffset(0, 26), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE, AlinearY = Enum.TextYAlignment.Top })
	Componentes.boton({ Parent = f2, Nombre = "VerProbabilidades", Texto = Textos.TIENDA.verProbabilidades, Size = UDim2.fromOffset(170, 34), Position = UDim2.new(0, 0, 1, -34), Tamano = 13, alPulsar = function()
		Probabilidades.abrir("contenedor")
	end })
	if desbloqueado then
		local bDinero = Componentes.boton({ Parent = f2, Texto = Textos.formatear(Textos.TIENDA.pagarDinero, { precio = Formato.miles(GameConfig.PRECIO_CONTENEDOR_DORADO) }), Size = UDim2.fromOffset(170, 36), Position = UDim2.new(1, -170, 0, 8), Color = Paleta.UI_DINERO, ColorTexto = Paleta.UI_FONDO, Tamano = 13, Deshabilitado = dinero < GameConfig.PRECIO_CONTENEDOR_DORADO, alPulsar = function()
			ContenedorDoradoEvent:FireServer("dinero")
		end })
		bDinero.Name = "ContenedorDinero"
		local bGemas = Componentes.boton({ Parent = f2, Texto = Textos.formatear(Textos.TIENDA.pagarGemas, { precio = GameConfig.PRECIO_CONTENEDOR_DORADO_GEMAS }), Size = UDim2.fromOffset(170, 36), Position = UDim2.new(1, -170, 0, 52), Color = Paleta.UI_GEMAS, ColorTexto = Paleta.UI_FONDO, Tamano = 13, Deshabilitado = gemas < GameConfig.PRECIO_CONTENEDOR_DORADO_GEMAS, alPulsar = function()
			ContenedorDoradoEvent:FireServer("gemas")
		end })
		bGemas.Name = "ContenedorGemas"
	else
		Componentes.texto({ Parent = f2, Texto = Textos.formatear(Textos.TIENDA.contenedorBloqueado, { n = maxeadas }), Size = UDim2.fromOffset(220, 60), Position = UDim2.new(1, -220, 0, 12), Tamano = 13, Color = Paleta.UI_ENERGIA, Alinear = Enum.TextXAlignment.Right })
	end

	-- Vender duplicados
	local f3 = fila(3, 56)
	Componentes.texto({ Parent = f3, Texto = Textos.TIENDA.venderDuplicados, Size = UDim2.new(0.6, 0, 1, 0), Tamano = 15, Negrita = true })
	Componentes.boton({ Parent = f3, Texto = Textos.TIENDA.venderDuplicados, Size = UDim2.fromOffset(170, 36), Position = UDim2.new(1, -170, 0.5, -18), Color = Paleta.UI_PELIGRO, Tamano = 13, alPulsar = function()
		VenderDuplicadosEvent:FireServer()
	end })
end

-- ===========================================================================
-- Pestana 3: Trajes y skins
-- ===========================================================================

local function pintarTrajes()
	local p = EstadoCliente.perfil
	local puesto = if p then p.trajePuesto else nil
	local skinActual = if p then p.skinBase else nil
	local orden = 0
	for _, traje in DefinicionesColeccionables.TRAJES do
		orden += 1
		local f = fila(orden, 60)
		local muestra = Componentes.marco({ Parent = f, Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(0, 2), Color = traje.colorCuerpo, Radio = 8 })
		Componentes.marco({ Parent = muestra, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12), Color = traje.colorPiernas, Radio = 6 })
		Componentes.texto({ Parent = f, Texto = traje.nombre, Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.fromOffset(52, 0), Tamano = 16, Negrita = true })
		local tiene = EstadoCliente.tieneTraje(traje.id)
		local pase = Productos.paseParaTraje(traje.id)
		local sub = if traje.gratis then (if tiene then "Encontrado en el patio" else Textos.TIENDA.noEncontrado) elseif tiene then Textos.TIENDA.comprado else (pase and Textos.formatear(Textos.TIENDA.robux, { precio = pase.precioRobux }) or "")
		Componentes.texto({ Parent = f, Texto = sub, Size = UDim2.new(0.5, 0, 0, 18), Position = UDim2.fromOffset(52, 24), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE })
		if tiene then
			local esPuesto = puesto == traje.id
			Componentes.boton({ Parent = f, Texto = if esPuesto then Textos.TIENDA.quitar else Textos.TIENDA.equipar, Size = UDim2.fromOffset(150, 36), Position = UDim2.new(1, -150, 0.5, -18), Color = if esPuesto then Paleta.UI_PANEL_CLARO else Paleta.UI_ACENTO, ColorTexto = if esPuesto then Paleta.UI_TEXTO else Paleta.UI_FONDO, Tamano = 13, alPulsar = function()
				PonerTrajeEvent:FireServer(if esPuesto then nil else traje.id)
			end })
		elseif pase then
			Componentes.boton({ Parent = f, Texto = Textos.formatear(Textos.TIENDA.robux, { precio = pase.precioRobux }), Size = UDim2.fromOffset(150, 36), Position = UDim2.new(1, -150, 0.5, -18), Color = Paleta.UI_GEMAS, ColorTexto = Paleta.UI_FONDO, Tamano = 13, alPulsar = function()
				comprarRobuxPase(pase)
			end })
		end
	end
	for _, skin in DefinicionesColeccionables.SKINS_BASE do
		orden += 1
		local f = fila(orden, 60)
		local muestra = Componentes.marco({ Parent = f, Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(0, 2), Color = skin.colorLosa, Radio = 8 })
		Componentes.marco({ Parent = muestra, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(12, 12), Color = skin.colorMueble, Radio = 4 })
		Componentes.texto({ Parent = f, Texto = skin.nombre, Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.fromOffset(52, 0), Tamano = 16, Negrita = true })
		local tiene = EstadoCliente.tieneSkin(skin.id)
		local pase = Productos.paseParaSkin(skin.id)
		Componentes.texto({ Parent = f, Texto = if tiene then Textos.TIENDA.comprado else (pase and Textos.formatear(Textos.TIENDA.robux, { precio = pase.precioRobux }) or ""), Size = UDim2.new(0.5, 0, 0, 18), Position = UDim2.fromOffset(52, 24), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE })
		if tiene then
			local activa = skinActual == skin.id
			Componentes.boton({ Parent = f, Texto = if activa then Textos.TIENDA.quitar else Textos.TIENDA.equipar, Size = UDim2.fromOffset(150, 36), Position = UDim2.new(1, -150, 0.5, -18), Color = if activa then Paleta.UI_PANEL_CLARO else Paleta.UI_ACENTO, ColorTexto = if activa then Paleta.UI_TEXTO else Paleta.UI_FONDO, Tamano = 13, alPulsar = function()
				PonerSkinBaseEvent:FireServer(if activa then nil else skin.id)
			end })
		elseif pase then
			Componentes.boton({ Parent = f, Texto = Textos.formatear(Textos.TIENDA.robux, { precio = pase.precioRobux }), Size = UDim2.fromOffset(150, 36), Position = UDim2.new(1, -150, 0.5, -18), Color = Paleta.UI_GEMAS, ColorTexto = Paleta.UI_FONDO, Tamano = 13, alPulsar = function()
				comprarRobuxPase(pase)
			end })
		end
	end
end

-- ===========================================================================
-- Pestana 4: Gemas y pases
-- ===========================================================================

local function pintarGemas()
	local orden = 0
	for _, producto in Productos.PRODUCTOS do
		orden += 1
		local f = fila(orden, 56)
		Componentes.texto({ Parent = f, Texto = producto.nombre, Size = UDim2.new(0.5, 0, 0, 22), Tamano = 16, Negrita = true, Color = Paleta.UI_GEMAS })
		Componentes.texto({ Parent = f, Texto = Textos.formatear(Textos.TIENDA.packGemas, { gemas = producto.gemas }), Size = UDim2.new(0.5, 0, 0, 18), Position = UDim2.fromOffset(0, 22), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE })
		Componentes.boton({ Parent = f, Texto = Textos.formatear(Textos.TIENDA.robux, { precio = producto.precioRobux }), Size = UDim2.fromOffset(150, 36), Position = UDim2.new(1, -150, 0.5, -18), Color = Paleta.UI_GEMAS, ColorTexto = Paleta.UI_FONDO, Tamano = 13, alPulsar = function()
			comprarRobuxProducto(producto)
		end })
	end
	for _, pase in Productos.PASES do
		if pase.categoria ~= "cosmetico" then
			orden += 1
			local f = fila(orden, 64)
			Componentes.texto({ Parent = f, Texto = pase.nombre, Size = UDim2.new(0.6, 0, 0, 22), Tamano = 16, Negrita = true })
			Componentes.texto({ Parent = f, Texto = pase.descripcion, Size = UDim2.new(0.6, 0, 0, 30), Position = UDim2.fromOffset(0, 22), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE, AlinearY = Enum.TextYAlignment.Top })
			local tiene = EstadoCliente.tienePase(pase.id)
			local b = Componentes.boton({ Parent = f, Texto = if tiene then Textos.TIENDA.comprado else Textos.formatear(Textos.TIENDA.robux, { precio = pase.precioRobux }), Size = UDim2.fromOffset(150, 36), Position = UDim2.new(1, -150, 0.5, -18), Color = if tiene then Paleta.UI_PANEL_CLARO else Paleta.UI_GEMAS, ColorTexto = if tiene then Paleta.UI_TEXTO_SUAVE else Paleta.UI_FONDO, Tamano = 13, Deshabilitado = tiene, alPulsar = function()
				comprarRobuxPase(pase)
			end })
			b.Name = "Pase_" .. pase.id
		end
	end
end

-- ===========================================================================
-- Revelacion de sobres / contenedores
-- ===========================================================================

local revelacion = Componentes.modal("Revelacion", "", 720, 380)
revelacion.pantalla.DisplayOrder = 16
local filaRevelacion = Componentes.marco({ Parent = revelacion.contenido, Size = UDim2.new(1, 0, 1, -50), Transparencia = 1 })
Componentes.lista(filaRevelacion, 14, true, Enum.HorizontalAlignment.Center)
Componentes.boton({ Parent = revelacion.contenido, Texto = "¡Genial!", Size = UDim2.fromOffset(160, 40), Position = UDim2.new(0.5, -80, 1, -44), Color = Paleta.UI_ACENTO, ColorTexto = Paleta.UI_FONDO, alPulsar = function()
	revelacion.cerrar()
end })

local function mostrarRevelacion(resultados: { any }, origen: string)
	Componentes.limpiar(filaRevelacion)
	revelacion.titulo.Text = if origen == "sobre" then Textos.TIENDA.sobrePremium else Textos.TIENDA.contenedorDorado
	for i, r in resultados do
		local def = DefinicionesMascotas.obtener(r.id)
		if def then
			local tarjeta = Componentes.marco({ Parent = filaRevelacion, Size = UDim2.fromOffset(200, 270), Color = Paleta.UI_PANEL, Radio = 12, Orden = i })
			Componentes.borde(tarjeta, Paleta.RAREZA[def.rareza], 3)
			local v = Componentes.viewport(tarjeta, UDim2.new(1, -12, 0, 170))
			v.Position = UDim2.fromOffset(6, 6)
			Componentes.mostrarModelo(v, ModelosMascota.mascota(def, r.estado, false))
			Componentes.texto({ Parent = tarjeta, Texto = def.nombre, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 182), Tamano = 18, Negrita = true, Alinear = Enum.TextXAlignment.Center, Color = Paleta.RAREZA[def.rareza] })
			Componentes.texto({ Parent = tarjeta, Texto = DefinicionesMascotas.NOMBRE_RAREZA[def.rareza] .. " · " .. DefinicionesMascotas.nombreEstado(r.estado), Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 210), Tamano = 13, Alinear = Enum.TextXAlignment.Center, Color = Paleta.UI_TEXTO_SUAVE })
		end
	end
	revelacion.abrir()
end

ResultadoSobreEvent.OnClientEvent:Connect(function(resultados, origen)
	if typeof(resultados) == "table" then
		mostrarRevelacion(resultados, tostring(origen))
	end
end)

-- ===========================================================================
-- Pestanas y refresco
-- ===========================================================================

local PINTORES = { pintarMejoras, pintarMascotas, pintarTrajes, pintarGemas }

local function repintar()
	Componentes.limpiar(cuerpo)
	local pintor = PINTORES[pestanaActual]
	if pintor then
		pintor()
	end
end

local pestanas = Componentes.pestanas(contenido, { Textos.TIENDA.mejoras, Textos.TIENDA.mascotas, Textos.TIENDA.trajes, Textos.TIENDA.gemas }, function(i)
	pestanaActual = i
	repintar()
end)

EstadoCliente.alCambiarPerfil:Connect(function()
	if modal.estaAbierto() then
		repintar()
	end
end)

table.insert(modal.alCerrar, function()
	Probabilidades.cerrar()
	Menu.notificarCierre("Tienda")
end)

Menu.registrar("Tienda", {
	abrir = function(argumento)
		modal.abrir()
		local indice = 1
		if argumento == "mascotas" then
			indice = 2
		elseif argumento == "trajes" then
			indice = 3
		elseif argumento == "gemas" then
			indice = 4
		end
		pestanas.seleccionar(indice)
	end,
	cerrar = modal.cerrar,
	estaAbierto = modal.estaAbierto,
	primerSeleccionable = function()
		return Componentes.primerSeleccionable(cuerpo) or modal.botonCerrar
	end,
})

return Tienda
