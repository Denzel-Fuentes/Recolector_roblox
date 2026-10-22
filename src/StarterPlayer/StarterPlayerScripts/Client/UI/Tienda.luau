--!strict
--[[
	Tienda (ModuleScript)
	La caseta de Dona Chatarra. Diseno v2: mejoras y pases, nada mas.

	  Mejoras    las 4 (Bolsa, Alcance, Velocidad, Brazo): su nivel como una
	             barra de 10 cuadros (Kit/Segmentos; decision del usuario,
	             3 oct: sin numeros ni studs) y el coste en $. Vuelven a 0 al
	             renacer.
	  Pases      las ventajas de Robux (Dinero x2, Bolsa XL) y el Turbo de
	             15 min (Config/Productos)
	  Estilo     disenos de bolsa y estelas (DefinicionesCosmeticos, de
	             pago o regalo de un rebirth). Los trajes del avatar se
	             quitaron el 5 oct.

	Compras con Robux: el cliente llama a MarketplaceService directamente; con
	id 0 (placeholder, aun sin crear en el Creator Dashboard) el boton dice
	"Proximamente" y no hace nada. El servidor resuelve la compra en
	MonetizacionHandler.

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
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local DefinicionesCosmeticos = require(Config:WaitForChild("DefinicionesCosmeticos"))
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
local EquiparCosmeticoEvent = Red.evento("EquiparCosmeticoEvent")

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

local function comprarRobuxProducto(producto: Productos.Producto)
	if producto.productId == 0 then
		Notificaciones.mostrar(Textos.TIENDA.sinIds, "aviso")
		return
	end
	MarketplaceService:PromptProductPurchase(jugador, producto.productId)
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
				titulos(Idioma.nombre("Mejoras", def), Idioma.descripcion("Mejoras", def), nil, 62, 0.4),
				-- El nivel: 10 cuadros que se llenan (sin valores ni unidades)
				scope:Segmentos({
					Nombre = "Nivel",
					Total = DefinicionesMejoras.NIVEL_MAX,
					Llenos = nivel,
					Color = scope:Computed(function(use)
						return if use(coste) then Paleta.UI_CARTAS else Paleta.UI_PRIMARIO
					end),
					Size = UDim2.new(0.6, -176, 0, 24),
					Position = UDim2.new(0.4, 8, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
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
-- Pestana 2: Pases (ventajas personales y el Turbo)
-- ===========================================================================

-- Boton de Robux: "Comprado" si ya lo tiene, "Proximamente" con id 0 (aun
-- sin crear en el Creator Dashboard), el precio si se puede comprar
local function botonRobux(nombre: string, precio: number, idRoblox: number, tiene: any?, comprar: () -> ())
	return scope:Boton({
		Nombre = nombre,
		Texto = scope:Computed(function(use)
			if tiene and use(tiene) then
				return Textos.TIENDA.comprado
			end
			return if idRoblox == 0 then Textos.TIENDA.proximamente else Textos.formatear(Textos.TIENDA.robux, { precio = precio })
		end),
		Color = Paleta.UI_GEMAS,
		Tamano = 16,
		Size = UDim2.fromOffset(160, 46),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Deshabilitado = scope:Computed(function(use)
			return (tiene ~= nil and use(tiene)) or idRoblox == 0
		end),
		alPulsar = comprar,
	})
end

local function filaProducto(orden: number, nombre: string, descripcion: string, icono: string, boton: any)
	return scope:Tarjeta({
		Nombre = "Producto" .. orden,
		Orden = orden,
		Size = UDim2.new(1, 0, 0, 76),
		Hijos = {
			scope:Icono({ Clave = icono, Tamano = 50, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) }),
			titulos(nombre, descripcion, nil, 62, 0.62),
			boton,
		},
	})
end

local function paginaPases()
	local filas = {}
	local orden = 0
	for _, pase in Productos.PASES do
		if pase.categoria ~= "ventaja" then
			continue
		end
		orden += 1
		local tiene = scope:Computed(function(use)
			use(reactivo.perfil)
			use(reactivo.modoDev)
			return EstadoCliente.tienePase(pase.id)
		end)
		table.insert(filas, filaProducto(orden, Idioma.nombre("Pases", pase), Idioma.descripcion("Pases", pase), pase.icono or "estrella", botonRobux("Robux_" .. pase.id, pase.precioRobux, pase.gamePassId, tiene, function()
			comprarRobuxPase(pase)
		end)))
	end
	for _, producto in Productos.PRODUCTOS do
		orden += 1
		table.insert(filas, filaProducto(orden, Idioma.nombre("Productos", producto), Idioma.descripcion("Productos", producto), producto.icono or "estrella", botonRobux("Robux_" .. producto.id, producto.precioRobux, producto.productId, nil, function()
			comprarRobuxProducto(producto)
		end)))
	end
	return filas
end

-- ===========================================================================
-- Pestana 3: Estilo (disenos de bolsa y estelas)
-- ===========================================================================

-- Muestra de color del cosmetico (dos bloques)
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

-- Una fila de algo que se pone: equipar/quitar si lo tienes; si no, el boton
-- de Robux (si es de pago) o como se consigue (subTexto)
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
					Texto = if pase.gamePassId == 0 then Textos.TIENDA.proximamente else Textos.formatear(Textos.TIENDA.robux, { precio = pase.precioRobux }),
					Color = Paleta.UI_GEMAS,
					Visible = scope:Computed(function(use)
						return not use(tiene)
					end),
					Deshabilitado = pase.gamePassId == 0,
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

local function paginaEstilo()
	local filas = {}
	local orden = 0
	-- Disenos de bolsa y estelas (DefinicionesCosmeticos)
	local function cosmetico(tipo: string, def: any, campo: string, fondo: any)
		orden += 1
		local pase = if def.pase then Productos.PASE_POR_ID[def.pase] else nil
		local tiene = scope:Computed(function(use)
			local p = use(reactivo.perfil)
			use(reactivo.modoDev)
			return DefinicionesCosmeticos.loTiene(def, if p then (p.rebirths or 0) else 0, EstadoCliente.tienePase)
		end)
		local puesto = scope:Computed(function(use)
			local p = use(reactivo.perfil)
			return p ~= nil and (p :: any)[campo] == def.id
		end)
		local sub = scope:Computed(function(use)
			if use(tiene) then
				return Textos.TIENDA.loTienes
			end
			return if def.rebirth then Textos.formatear(Textos.TIENDA.conRebirth, { n = def.rebirth }) else Textos.TIENDA.dePago
		end)
		table.insert(filas, filaVestible(orden, Idioma.nombre(if tipo == "bolsa" then "Bolsas" else "Estelas", def), fondo, tiene, puesto, pase, sub, function(poner)
			EquiparCosmeticoEvent:FireServer(tipo, if poner then def.id else nil)
		end))
	end
	for _, def in DefinicionesCosmeticos.BOLSAS do
		cosmetico("bolsa", def, "disenoBolsa", muestra(def.color, Paleta.escalar(def.color, 0.7)))
	end
	for _, def in DefinicionesCosmeticos.ESTELAS do
		local inicio = def.colores.Keypoints[1].Value
		local fin = def.colores.Keypoints[#def.colores.Keypoints].Value
		cosmetico("estela", def, "estela", muestra(inicio, fin))
	end
	return filas
end

-- ===========================================================================
-- Ventana
-- ===========================================================================

local PAGINAS = { paginaMejoras, paginaPases, paginaEstilo }
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
			Nombres = { Textos.TIENDA.mejoras, Textos.TIENDA.pases, Textos.TIENDA.estilo },
			Seleccion = pestana,
		}),
		paginas,
	},
})

Menu.registrar(NOMBRE, {
	abrir = function(argumento)
		pestana:set(if argumento == "pases" then 2 elseif argumento == "estilo" then 3 else 1)
	end,
	primerSeleccionable = function()
		return Navegacion.primerSeleccionable(paginas[peek(pestana)])
	end,
})

return {}
