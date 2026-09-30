--!strict
--[[
	Tienda (ModuleScript)
	La caseta de Dona Chatarra. Diseno v2: mejoras y pases, nada mas.

	  Mejoras    las 4 (Bolsa, Alcance, Velocidad, Brazo), con nivel, valor
	             actual -> siguiente y coste en $. Vuelven a 0 al renacer.
	  Trajes     los de pago (Robux) y, con la funcion TRAJES_BOTIN, los 3
	             gratis que salian de los montones (pospuestos en la v2).
	             (El resto de pases y cosmeticos llega en el lote 8.)

	Compras con Robux: el cliente llama a MarketplaceService directamente; con
	id 0 (placeholder) se avisa de que el producto no existe aun. El servidor
	resuelve la compra en MonetizacionHandler.

	Las paginas se montan UNA vez desde las definiciones (Config) y cada fila
	deriva del perfil solo primitivos: nivel, "me alcanza", "lo tengo", "lo
	llevo puesto". El perfil llega varias veces por segundo; una fila solo
	cambia si cambio lo suyo.
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
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))
local Productos = require(Config:WaitForChild("Productos"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Formato = require(Utilidades:WaitForChild("Formato"))
local Red = require(Utilidades:WaitForChild("Red"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Navegacion = require(script.Parent:WaitForChild("Kit"):WaitForChild("Navegacion"))
local Menu = require(script.Parent:WaitForChild("Menu"))
local Notificaciones = require(script.Parent:WaitForChild("Notificaciones"))

local Children = Fusion.Children
local peek = Fusion.peek

local ComprarMejoraEvent = Red.evento("ComprarMejoraEvent")
local PonerTrajeEvent = Red.evento("PonerTrajeEvent")

local NOMBRE = "Tienda"
local jugador = Players.LocalPlayer
local reactivo = EstadoCliente.reactivo

local scope = Fusion.scoped(Fusion, Kit)
local pestana = scope:Value(1)

-- Icono de cada mejora (claves de Config/Iconos)
local ICONO_MEJORA = {
	Bolsa = "bolsa",
	Alcance = "mano",
	Velocidad = "bota",
	Brazo = "lanzar",
}

local function comprarRobuxPase(pase: Productos.Pase)
	if pase.gamePassId == 0 then
		Notificaciones.mostrar(Textos.TIENDA.sinIds, "aviso")
		return
	end
	MarketplaceService:PromptGamePassPurchase(jugador, pase.gamePassId)
end

-- Primitivos del perfil que usan varias filas
local dinero = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	return if p then (p.dinero or 0) else 0
end)
local function nivelDe(id: string)
	return scope:Computed(function(use)
		use(reactivo.perfil)
		return EstadoCliente.nivelMejora(id)
	end)
end

-- Textos de una fila: titulo gordo + descripcion debajo
local function titulos(titulo: any, descripcion: any, color: Color3?, desde: number?, ancho: number?)
	local x = desde or 0
	return {
		scope:Texto({
			Texto = titulo,
			Size = UDim2.new(ancho or 0.55, -x, 0, 24),
			Position = UDim2.fromOffset(x, 0),
			Tamano = 18,
			Fuente = "titulo",
			Color = color or Paleta.UI_TINTA,
		}),
		scope:Texto({
			Texto = descripcion,
			Size = UDim2.new(ancho or 0.55, -x, 0, 34),
			Position = UDim2.fromOffset(x, 25),
			Tamano = 13,
			Color = Paleta.UI_TINTA_SUAVE,
			AlinearY = Enum.TextYAlignment.Top,
		}),
	}
end

-- ===========================================================================
-- Pestana 1: Mejoras
-- ===========================================================================

local function paginaMejoras()
	local filas = {}
	for i, def in DefinicionesMejoras.LISTA do
		local nivel = nivelDe(def.id)
		local coste = scope:Computed(function(use)
			return DefinicionesMejoras.coste(def.id, use(nivel))
		end)
		table.insert(filas, scope:Tarjeta({
			Nombre = "Mejora_" .. def.id,
			Orden = i,
			Size = UDim2.new(1, 0, 0, 80),
			Hijos = {
				scope:Icono({ Clave = ICONO_MEJORA[def.id] or "estrella", Tamano = 52, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) }),
				titulos(def.nombre, def.descripcion, nil, 62, 0.42),
				-- "valor -> siguiente" y el nivel, como las filas de mejoras del kit
				scope:Texto({
					Texto = scope:Computed(function(use)
						local n = use(nivel)
						local actual = DefinicionesMejoras.textoValor(def.id, n)
						return if use(coste) then actual .. "  →  " .. DefinicionesMejoras.textoValor(def.id, n + 1) else actual
					end),
					Size = UDim2.new(0.3, 0, 0, 26),
					Position = UDim2.new(0.42, 0, 0, 4),
					Tamano = 17,
					Fuente = "titulo",
					Color = Paleta.UI_CARTAS,
					Alinear = Enum.TextXAlignment.Center,
				}),
				scope:Texto({
					Texto = scope:Computed(function(use)
						return if use(coste) then Textos.formatear(Textos.TIENDA.nivel, { n = use(nivel) }) else Textos.TIENDA.maximo
					end),
					Size = UDim2.new(0.3, 0, 0, 20),
					Position = UDim2.new(0.42, 0, 0, 32),
					Tamano = 14,
					Fuente = "negrita",
					Color = Paleta.UI_TINTA_SUAVE,
					Alinear = Enum.TextXAlignment.Center,
				}),
				scope:Boton({
					Nombre = "Comprar_" .. def.id,
					Texto = scope:Computed(function(use)
						local c = use(coste)
						return if c then Formato.dinero(c) else Textos.TIENDA.maximo
					end),
					Color = Paleta.UI_EXITO,
					Tamano = 18,
					Size = UDim2.fromOffset(140, 48),
					Position = UDim2.new(1, 0, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					Deshabilitado = scope:Computed(function(use)
						local c = use(coste)
						return c == nil or use(dinero) < c
					end),
					alPulsar = function()
						ComprarMejoraEvent:FireServer(def.id)
					end,
				}),
			},
		}))
	end
	return filas
end

-- ===========================================================================
-- Pestana 2: Trajes
-- ===========================================================================

-- Muestra de color del traje (dos bloques)
local function muestra(colorArriba: Color3, colorAbajo: Color3)
	return scope:New("Frame")({
		Name = "Muestra",
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = colorArriba,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
			scope:New("UIStroke")({ Color = Paleta.UI_TINTA, Thickness = 2 }),
			scope:New("Frame")({
				Size = UDim2.new(1, 0, 0, 14),
				Position = UDim2.new(0, 0, 1, -14),
				BackgroundColor3 = colorAbajo,
				[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			}),
		},
	})
end

-- Una fila de traje: equipar/quitar si lo tienes, Robux si es de pago
local function filaVestible(orden: number, nombre: string, fondo: any, tiene: any, puesto: any, pase: Productos.Pase?, subTexto: any, alEquipar: (poner: boolean) -> ())
	return scope:Tarjeta({
		Nombre = "Vestible" .. orden,
		Orden = orden,
		Size = UDim2.new(1, 0, 0, 70),
		Color = scope:Computed(function(use)
			return if use(puesto) then Color3.fromRGB(215, 245, 215) else Paleta.UI_PAPEL_OSCURO
		end),
		Hijos = {
			fondo,
			scope:Texto({ Texto = nombre, Size = UDim2.new(0.55, -58, 0, 24), Position = UDim2.fromOffset(58, 6), Tamano = 18, Fuente = "titulo" }),
			scope:Texto({ Texto = subTexto, Size = UDim2.new(0.55, -58, 0, 18), Position = UDim2.fromOffset(58, 32), Tamano = 13, Color = Paleta.UI_TINTA_SUAVE }),
			scope:Boton({
				Nombre = "Equipar",
				Texto = scope:Computed(function(use)
					return if use(puesto) then Textos.TIENDA.quitar else Textos.TIENDA.equipar
				end),
				Color = scope:Computed(function(use)
					return if use(puesto) then Paleta.UI_PELIGRO else Paleta.UI_EXITO
				end),
				Visible = tiene,
				Tamano = 15,
				Size = UDim2.fromOffset(160, 44),
				Position = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				alPulsar = function()
					alEquipar(not peek(puesto))
				end,
			}),
			if pase
				then scope:Boton({
					Nombre = "Robux",
					Texto = Textos.formatear(Textos.TIENDA.robux, { precio = pase.precioRobux }),
					Color = Paleta.UI_GEMAS,
					Visible = scope:Computed(function(use)
						return not use(tiene)
					end),
					Tamano = 15,
					Size = UDim2.fromOffset(160, 44),
					Position = UDim2.new(1, 0, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					alPulsar = function()
						comprarRobuxPase(pase)
					end,
				})
				else nil,
		},
	})
end

local function paginaTrajes()
	local filas = {}
	local orden = 0
	for _, traje in DefinicionesColeccionables.TRAJES do
		if traje.gratis and not GameConfig.activa("TRAJES_BOTIN") then
			continue
		end
		orden += 1
		local pase = Productos.paseParaTraje(traje.id)
		local tiene = scope:Computed(function(use)
			use(reactivo.perfil)
			use(reactivo.modoDev)
			return EstadoCliente.tieneTraje(traje.id)
		end)
		local puesto = scope:Computed(function(use)
			local p = use(reactivo.perfil)
			return p ~= nil and p.trajePuesto == traje.id
		end)
		local sub = scope:Computed(function(use)
			local t = use(tiene)
			if traje.gratis then
				return if t then "Encontrado en el patio" else Textos.TIENDA.noEncontrado
			end
			return if t then Textos.TIENDA.comprado elseif pase then Textos.formatear(Textos.TIENDA.robux, { precio = pase.precioRobux }) else ""
		end)
		table.insert(filas, filaVestible(orden, traje.nombre, muestra(traje.colorCuerpo, traje.colorPiernas), tiene, puesto, pase, sub, function(poner)
			PonerTrajeEvent:FireServer(if poner then traje.id else nil)
		end))
	end
	return filas
end

-- ===========================================================================
-- Ventana
-- ===========================================================================

local PAGINAS = { paginaMejoras, paginaTrajes }
local paginas = {}
for i, pintar in PAGINAS do
	paginas[i] = scope:Scroll({
		Nombre = "Pagina" .. i,
		Espacio = 8,
		Relleno = 4,
		Size = UDim2.new(1, 0, 1, -48),
		Position = UDim2.fromOffset(0, 48),
		Visible = scope:Computed(function(use)
			return use(pestana) == i
		end),
		Hijos = pintar(),
	})
end

scope:Ventana({
	Nombre = NOMBRE,
	Titulo = Textos.TIENDA.titulo,
	Ancho = 920,
	Alto = 620,
	Abierta = scope:Computed(function(use)
		return use(Menu.abiertoR) == NOMBRE
	end),
	alCerrar = Menu.cerrarTodo,
	Hijos = {
		scope:Pestanas({
			Nombres = { Textos.TIENDA.mejoras, Textos.TIENDA.trajes },
			Seleccion = pestana,
		}),
		paginas,
	},
})

Menu.registrar(NOMBRE, {
	abrir = function(argumento)
		pestana:set(if argumento == "trajes" then 2 else 1)
	end,
	primerSeleccionable = function()
		return Navegacion.primerSeleccionable(paginas[peek(pestana)])
	end,
})

return {}
