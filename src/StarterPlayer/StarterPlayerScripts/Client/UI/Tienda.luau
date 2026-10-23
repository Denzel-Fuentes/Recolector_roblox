--!strict
--[[
	Tienda (ModuleScript)
	La caseta de Dona Chatarra. Diseno v2: mejoras y pases, nada mas.

	  Mejoras    las 4 (Bolsa, Alcance, Velocidad, Brazo): su nivel como una
	             barra de 10 cuadros (Kit/Segmentos; decision del usuario,
	             3 oct: sin numeros ni studs) y el coste en $. Vuelven a 0 al
	             renacer.
	  Pases      las ventajas de Robux y el Turbo (Config/Productos). Arriba
	             el Pack de inicio, con "Compra unica", y el VIP (economia v4,
	             §5.3: el Pack siempre a la vista arriba hasta tenerlo;
	             comprado, baja al final con su "Comprado"); despues las
	             demas ventajas, la linea "El Turbo solo corre mientras
	             juegas" y los Turbos. Con TURBO_TOPE_COMPRA s guardados (3 h)
	             los botones de Turbo se desactivan y la fila lo dice
	             (TIENDA.turboTope): el tope solo existe aqui y en las ofertas,
	             porque el servidor nunca rechaza un recibo.
	  Estilo     disenos de bolsa y estelas (DefinicionesCosmeticos) con su
	             origen: "Regalo del Rebirth N", "Con la insignia X", "Del
	             Pack de inicio", "Exclusivo VIP" o "Pase de Robux". Los del
	             Pack y del VIP no se venden sueltos: sin boton de Robux.

	Compras con Robux: el cliente llama a MarketplaceService directamente; con
	id 0 (placeholder, aun sin crear en el Creator Dashboard) el boton dice
	"Proximamente" y no hace nada. El precio que se pinta es el DE VERDAD
	(Client/PreciosRobux: GetProductInfo, "Cargando precio…" mientras llega,
	el de Config si falla); el servidor resuelve la compra en
	MonetizacionHandler.

	Las paginas se montan UNA vez desde las definiciones (Config) y cada fila
	deriva del perfil solo primitivos: nivel, "me alcanza", "lo tengo", "lo
	llevo puesto", "Turbo al tope". El perfil llega varias veces por segundo;
	una fila solo cambia si cambio lo suyo.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local DefinicionesCosmeticos = require(Config:WaitForChild("DefinicionesCosmeticos"))
local DefinicionesInsignias = require(Config:WaitForChild("DefinicionesInsignias"))
local Productos = require(Config:WaitForChild("Productos"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Formato = require(Utilidades:WaitForChild("Formato"))
local Red = require(Utilidades:WaitForChild("Red"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local PreciosRobux = require(Cliente:WaitForChild("PreciosRobux"))
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

-- Los pases que van arriba de la pestana Pases, en este orden (§5.3)
local PRIMEROS = { PackInicio = 1, VIP = 2 }
-- Orden de las filas de la pestana Pases: pases 1..9, la linea del Turbo,
-- los productos y, al final, el Pack ya comprado
local ORDEN_LINEA_TURBO = 50
local ORDEN_PRODUCTOS = 51
local ORDEN_PACK_COMPRADO = 99

-- Las horas del tope, para el texto
local HORAS_TOPE = math.floor(GameConfig.TURBO_TOPE_COMPRA / 3600 + 0.5)

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
-- Con el Turbo guardado al tope no se compra mas (ver cabecera)
local turboAlTope = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	local r = p and p.turboRestante
	return typeof(r) == "number" and r >= GameConfig.TURBO_TOPE_COMPRA
end)

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
	if producto.turboMinutos and peek(turboAlTope) then
		Notificaciones.mostrar(Textos.formatear(Textos.TIENDA.turboTope, { horas = HORAS_TOPE }), "aviso")
		return
	end
	MarketplaceService:PromptProductPurchase(jugador, producto.productId)
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

-- Titulo con una etiqueta de color a su derecha ("Compra unica" del Pack)
local function tituloConEtiqueta(titulo: string, etiqueta: string, descripcion: any, desde: number, ancho: number)
	return {
		scope:New("Frame")({
			Name = "Titulo",
			Size = UDim2.new(ancho, -desde, 0, 24),
			Position = UDim2.fromOffset(desde, 0),
			BackgroundTransparency = 1,
			[Children] = {
				scope:Lista({ Espacio = 8, Horizontal = true, AlinearV = Enum.VerticalAlignment.Center }),
				scope:Texto({
					Texto = titulo,
					Size = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					Tamano = 18,
					Fuente = "titulo",
					Ajustar = false,
					Orden = 1,
				}),
				scope:New("Frame")({
					Name = "Etiqueta",
					Size = UDim2.fromOffset(0, 20),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = Paleta.UI_GEMAS,
					LayoutOrder = 2,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						scope:Relleno({ X = 8, Y = 0 }),
						scope:Texto({
							Texto = etiqueta,
							Size = UDim2.new(0, 0, 1, 0),
							AutomaticSize = Enum.AutomaticSize.X,
							Tamano = 12,
							Fuente = "titulo",
							Color = Paleta.UI_PAPEL,
							Ajustar = false,
						}),
					},
				}),
			},
		}),
		scope:Texto({
			Texto = descripcion,
			Size = UDim2.new(ancho, -desde, 0, 34),
			Position = UDim2.fromOffset(desde, 25),
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

-- Si no esta a la venta: id 0, o Roblox dice que no (o sin precio)
local function noALaVenta(idRoblox: number, info: PreciosRobux.Info): boolean
	return idRoblox == 0 or (info.estado ~= "cargando" and not info.aLaVenta)
end

-- Boton de Robux: "Comprado" si ya lo tiene; "Proximamente" con id 0 (aun
-- sin crear en el Creator Dashboard) o si no esta a la venta; "Cargando
-- precio…" mientras pregunta; si no, el precio de verdad (PreciosRobux).
-- `bloqueado` lo desactiva sin cambiar el texto (el tope del Turbo)
local function botonRobux(nombre: string, tipo: string, id: string, idRoblox: number, tiene: any?, bloqueado: any?, comprar: () -> ())
	local info = PreciosRobux.de(tipo, id)
	return scope:Boton({
		Nombre = nombre,
		Texto = scope:Computed(function(use)
			if tiene and use(tiene) then
				return Textos.TIENDA.comprado
			end
			local i = use(info) :: PreciosRobux.Info
			if noALaVenta(idRoblox, i) then
				return Textos.TIENDA.proximamente
			elseif i.estado == "cargando" then
				return Textos.TIENDA.cargandoPrecio
			end
			return Textos.formatear(Textos.TIENDA.robux, { precio = i.precio })
		end),
		Color = Paleta.UI_GEMAS,
		Tamano = 16,
		Size = UDim2.fromOffset(160, 46),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Deshabilitado = scope:Computed(function(use)
			local i = use(info) :: PreciosRobux.Info
			return (tiene ~= nil and use(tiene)) or noALaVenta(idRoblox, i) or (bloqueado ~= nil and use(bloqueado))
		end),
		alPulsar = comprar,
	})
end

local function filaProducto(nombreFila: string, orden: any, icono: string, cabecera: any, boton: any)
	return scope:Tarjeta({
		Nombre = nombreFila,
		Orden = orden,
		Size = UDim2.new(1, 0, 0, 76),
		Hijos = {
			scope:Icono({ Clave = icono, Tamano = 50, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) }),
			cabecera,
			boton,
		},
	})
end

local function paginaPases()
	local filas = {}
	-- Las ventajas: el Pack y el VIP primero, las demas en el orden de Config
	local ventajas: { { pase: Productos.Pase, orden: number } } = {}
	for i, pase in Productos.PASES do
		if pase.categoria == "ventaja" then
			table.insert(ventajas, { pase = pase, orden = PRIMEROS[pase.id] or (10 + i) })
		end
	end
	table.sort(ventajas, function(a, b)
		return a.orden < b.orden
	end)
	for i, v in ventajas do
		local pase = v.pase
		local tiene = scope:Computed(function(use)
			use(reactivo.perfil)
			use(reactivo.modoDev)
			return EstadoCliente.tienePase(pase.id)
		end)
		local nombre = Idioma.nombre("Pases", pase)
		local descripcion = Idioma.descripcion("Pases", pase)
		local cabecera = if pase.compraUnica
			then tituloConEtiqueta(nombre, Textos.TIENDA.compraUnica, descripcion, 62, 0.62)
			else titulos(nombre, descripcion, nil, 62, 0.62)
		-- La compra unica, ya comprada, deja el sitio de arriba (ver cabecera)
		local orden = if pase.compraUnica
			then scope:Computed(function(use)
				return if use(tiene) then ORDEN_PACK_COMPRADO else i
			end)
			else i
		table.insert(filas, filaProducto("Pase_" .. pase.id, orden, pase.icono or "estrella", cabecera, botonRobux("Robux_" .. pase.id, "pase", pase.id, pase.gamePassId, tiene, nil, function()
			comprarRobuxPase(pase)
		end)))
	end
	-- "El Turbo solo corre mientras juegas", encima de los Turbos
	table.insert(filas, scope:Texto({
		Nombre = "TurboSoloJugando",
		Texto = Textos.TURBO.soloJugando,
		Size = UDim2.new(1, 0, 0, 22),
		Tamano = 14,
		Fuente = "negrita",
		Color = Paleta.UI_TINTA_SUAVE,
		Alinear = Enum.TextXAlignment.Center,
		Orden = ORDEN_LINEA_TURBO,
	}))
	for i, producto in Productos.PRODUCTOS do
		local esTurbo = producto.turboMinutos ~= nil
		local descripcionBase = Idioma.descripcion("Productos", producto)
		-- Al tope de Turbo, la fila dice por que no se puede
		local descripcion = if esTurbo
			then scope:Computed(function(use)
				return if use(turboAlTope) then Textos.formatear(Textos.TIENDA.turboTope, { horas = HORAS_TOPE }) else descripcionBase
			end)
			else descripcionBase
		table.insert(filas, filaProducto("Producto_" .. producto.id, ORDEN_PRODUCTOS + i, producto.icono or "estrella",
			titulos(Idioma.nombre("Productos", producto), descripcion, nil, 62, 0.62),
			botonRobux("Robux_" .. producto.id, "producto", producto.id, producto.productId, nil, if esTurbo then turboAlTope else nil, function()
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
-- de Robux (si se vende suelto) o como se consigue (subTexto)
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
				then scope:New("Frame")({
					Name = "Robux",
					Size = UDim2.fromOffset(160, 44),
					Position = UDim2.new(1, 0, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					Visible = scope:Computed(function(use)
						return not use(tiene)
					end),
					[Children] = botonRobux("Robux", "pase", pase.id, pase.gamePassId, nil, nil, function()
						comprarRobuxPase(pase)
					end),
				})
				else nil,
		},
	})
end

-- De donde sale un cosmetico que aun no se tiene (economia v4, §5.4)
local function origen(def: any): string
	if def.rebirth then
		return Textos.formatear(Textos.TIENDA.conRebirth, { n = def.rebirth })
	elseif def.insignia then
		local insignia = DefinicionesInsignias.POR_ID[def.insignia]
		return Textos.formatear(Textos.TIENDA.conInsignia, { nombre = if insignia then Idioma.nombre("Insignias", insignia) else def.insignia })
	elseif def.pase == "PackInicio" then
		return Textos.TIENDA.dePack
	elseif def.pase == "VIP" then
		return Textos.TIENDA.deVip
	end
	return Textos.TIENDA.dePago
end

local function paginaEstilo()
	local filas = {}
	local orden = 0
	-- Disenos de bolsa y estelas (DefinicionesCosmeticos)
	local function cosmetico(tipo: string, def: any, campo: string, fondo: any)
		orden += 1
		local pase = if def.pase then Productos.PASE_POR_ID[def.pase] else nil
		-- Solo los pases de cosmetico se venden sueltos: los del Pack y del
		-- VIP van dentro de su pase (la fila dice de donde salen)
		local paseSuelto = if pase and pase.categoria == "cosmetico" then pase else nil
		local tiene = scope:Computed(function(use)
			local p = use(reactivo.perfil)
			use(reactivo.modoDev)
			local logros = if p and p.logros then p.logros else {}
			return DefinicionesCosmeticos.loTiene(def, if p then (p.rebirths or 0) else 0, EstadoCliente.tienePase, function(insignia)
				return logros[insignia] == true
			end)
		end)
		local puesto = scope:Computed(function(use)
			local p = use(reactivo.perfil)
			return p ~= nil and (p :: any)[campo] == def.id
		end)
		local textoOrigen = origen(def)
		local sub = scope:Computed(function(use)
			return if use(tiene) then Textos.TIENDA.loTienes else textoOrigen
		end)
		table.insert(filas, filaVestible(orden, Idioma.nombre(if tipo == "bolsa" then "Bolsas" else "Estelas", def), fondo, tiene, puesto, paseSuelto, sub, function(poner)
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
