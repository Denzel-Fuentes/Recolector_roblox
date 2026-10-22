--!strict
--[[
	Pedidos (ModuleScript)
	El panel de Dona Chatarra con dos pestanas (lote 7):

	  Pedidos del dia   los tres retos de hoy con su barra y lo que pagan, y
	                    el premio por completar los tres (Turbo: dinero x2
	                    unos minutos). Se cobran solos al cumplirse
	                    (Services/Pedidos): aqui solo se ve como vas.
	  Insignias         las 16 (Config/DefinicionesInsignias), conseguidas o
	                    con su progreso.

	Solo presentacion. El perfil llega varias veces por segundo como tablas
	nuevas: cada fila deriva un primitivo (un texto "progreso|objetivo|...")
	y se monta una vez sobre los tres huecos fijos y las 16 definiciones.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local DefinicionesPedidos = require(Config:WaitForChild("DefinicionesPedidos"))
local DefinicionesInsignias = require(Config:WaitForChild("DefinicionesInsignias"))
local DefinicionesTutorial = require(Config:WaitForChild("DefinicionesTutorial"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Formato = require(Utilidades:WaitForChild("Formato"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Navegacion = require(script.Parent:WaitForChild("Kit"):WaitForChild("Navegacion"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local peek = Fusion.peek

local NOMBRE = "Pedidos"
local reactivo = EstadoCliente.reactivo

local scope = Fusion.scoped(Fusion, Kit)
local pestana = scope:Value(1)

local abiertos = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	return p ~= nil and (p.tutorial or 0) >= DefinicionesTutorial.indice(DefinicionesPedidos.PASO_DESBLOQUEO)
end)

-- ===========================================================================
-- Pestana 1: pedidos del dia
-- ===========================================================================

-- El pedido del hueco i como texto plano "texto|progreso|objetivo|cobrado|$"
local function pedidoEn(i: number)
	return scope:Computed(function(use)
		local p = use(reactivo.perfil)
		local pedido = p and p.pedidos and p.pedidos.lista and p.pedidos.lista[i]
		if not pedido then
			return ""
		end
		return string.format("%s|%d|%d|%s|%d", DefinicionesPedidos.texto(pedido, Textos), pedido.progreso, pedido.objetivo, tostring(pedido.cobrado), pedido.recompensa or 0)
	end)
end

local function partes(texto: string): (string, number, number, boolean, number)
	local t = string.split(texto, "|")
	return t[1] or "", tonumber(t[2]) or 0, tonumber(t[3]) or 1, t[4] == "true", tonumber(t[5]) or 0
end

local function filaPedido(i: number)
	local dato = pedidoEn(i)
	local hecho = scope:Computed(function(use)
		local _, _, _, cobrado = partes(use(dato))
		return cobrado
	end)
	return scope:Tarjeta({
		Nombre = "Pedido" .. i,
		Orden = i,
		Size = UDim2.new(1, 0, 0, 84),
		Visible = scope:Computed(function(use)
			return use(abiertos) and use(dato) ~= ""
		end),
		Color = scope:Computed(function(use)
			return if use(hecho) then Color3.fromRGB(215, 245, 215) else Paleta.UI_PAPEL_OSCURO
		end),
		Hijos = {
			scope:Icono({
				Clave = scope:Computed(function(use)
					return if use(hecho) then "trofeo" else "libreta"
				end),
				Tamano = 48,
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
			}),
			scope:Texto({
				Texto = scope:Computed(function(use)
					return (partes(use(dato)))
				end),
				Size = UDim2.new(1, -190, 0, 26),
				Position = UDim2.fromOffset(58, 2),
				Tamano = 17,
				Fuente = "titulo",
			}),
			scope:Barra({
				Fraccion = scope:Computed(function(use)
					local _, n, total = partes(use(dato))
					return if total > 0 then n / total else 0
				end),
				Texto = scope:Computed(function(use)
					local _, n, total, cobrado = partes(use(dato))
					return if cobrado then Textos.PEDIDOS.hecho else string.format("%d/%d", n, total)
				end),
				Color = scope:Computed(function(use)
					return if use(hecho) then Paleta.UI_EXITO else Paleta.UI_CARTAS
				end),
				Size = UDim2.new(1, -190, 0, 24),
				Position = UDim2.fromOffset(58, 36),
				Radio = 12,
			}),
			scope:Pildora({
				Nombre = "Premio",
				Icono = "billete",
				Texto = scope:Computed(function(use)
					local _, _, _, _, dinero = partes(use(dato))
					return Formato.dinero(dinero)
				end),
				Color = Paleta.UI_DINERO,
				Ancho = 118,
				Alto = 40,
				TamanoTexto = 18,
				Position = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
			}),
		},
	})
end

local function paginaPedidos()
	local hijos: { any } = {
		scope:Texto({
			Nombre = "Cerrados",
			Texto = Textos.PEDIDOS.cerrados,
			Size = UDim2.new(1, 0, 0, 60),
			Tamano = 18,
			Fuente = "titulo",
			Color = Paleta.UI_TINTA_SUAVE,
			Alinear = Enum.TextXAlignment.Center,
			Visible = scope:Computed(function(use)
				return not use(abiertos)
			end),
			Orden = 0,
		}),
	}
	for i = 1, DefinicionesPedidos.POR_DIA do
		table.insert(hijos, filaPedido(i))
	end
	-- El premio del dia: 3 cuadros, uno por pedido cobrado
	local cobrados = scope:Computed(function(use)
		local p = use(reactivo.perfil)
		local n = 0
		for _, pedido in (p and p.pedidos and p.pedidos.lista) or {} do
			if pedido.cobrado then
				n += 1
			end
		end
		return n
	end)
	local premioCobrado = scope:Computed(function(use)
		local p = use(reactivo.perfil)
		return p ~= nil and p.pedidos ~= nil and p.pedidos.premioCobrado == true
	end)
	table.insert(hijos, scope:Tarjeta({
		Nombre = "PremioDia",
		Orden = 10,
		Size = UDim2.new(1, 0, 0, 74),
		Color = Paleta.UI_PRIMARIO,
		Visible = abiertos,
		Hijos = {
			scope:Icono({ Clave = "rayo", Tamano = 46, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) }),
			scope:Texto({
				Texto = scope:Computed(function(use)
					return if use(premioCobrado) then Textos.PEDIDOS.premioCobrado else Textos.formatear(Textos.PEDIDOS.premioDia, { minutos = DefinicionesPedidos.MINUTOS_TURBO })
				end),
				Size = UDim2.new(1, -60, 0, 24),
				Position = UDim2.fromOffset(56, 2),
				Tamano = 17,
				Fuente = "titulo",
				Color = Paleta.UI_PAPEL,
				Contorno = Paleta.UI_TINTA,
			}),
			scope:Segmentos({
				Total = DefinicionesPedidos.POR_DIA,
				Llenos = cobrados,
				Color = Paleta.UI_EXITO,
				Size = UDim2.new(0.6, -56, 0, 20),
				Position = UDim2.fromOffset(56, 32),
				Espacio = 6,
			}),
		},
	}))
	table.insert(hijos, scope:Texto({
		Nombre = "Nuevos",
		Texto = Textos.PEDIDOS.nuevos,
		Size = UDim2.new(1, 0, 0, 22),
		Tamano = 13,
		Color = Paleta.UI_TINTA_SUAVE,
		Alinear = Enum.TextXAlignment.Center,
		Orden = 11,
	}))
	return hijos
end

-- ===========================================================================
-- Pestana 2: insignias
-- ===========================================================================

local function filaInsignia(orden: number, def: DefinicionesInsignias.Insignia)
	-- "actual|meta|conseguida"
	local dato = scope:Computed(function(use)
		local p = use(reactivo.perfil)
		if not p then
			return "0|1|false"
		end
		local actual, meta = DefinicionesInsignias.progreso(def, p)
		return string.format("%d|%d|%s", math.min(actual, meta), meta, tostring(p.logros ~= nil and p.logros[def.id] == true))
	end)
	local conseguida = scope:Computed(function(use)
		return string.split(use(dato), "|")[3] == "true"
	end)
	return scope:Tarjeta({
		Nombre = "Insignia_" .. def.id,
		Orden = orden,
		Size = UDim2.new(1, 0, 0, 70),
		Color = scope:Computed(function(use)
			return if use(conseguida) then Color3.fromRGB(255, 236, 170) else Paleta.UI_PAPEL_OSCURO
		end),
		Hijos = {
			scope:Icono({
				Clave = scope:Computed(function(use)
					return if use(conseguida) then "trofeo" else def.icono
				end),
				Tamano = 44,
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
			}),
			scope:Texto({ Texto = Idioma.nombre("Insignias", def), Size = UDim2.new(0.5, -56, 0, 24), Position = UDim2.fromOffset(54, 2), Tamano = 17, Fuente = "titulo" }),
			scope:Texto({ Texto = Idioma.descripcion("Insignias", def), Size = UDim2.new(0.5, -56, 0, 30), Position = UDim2.fromOffset(54, 26), Tamano = 13, Color = Paleta.UI_TINTA_SUAVE, AlinearY = Enum.TextYAlignment.Top }),
			scope:Barra({
				Fraccion = scope:Computed(function(use)
					local t = string.split(use(dato), "|")
					local meta = tonumber(t[2]) or 1
					return if meta > 0 then (tonumber(t[1]) or 0) / meta else 0
				end),
				Texto = scope:Computed(function(use)
					local t = string.split(use(dato), "|")
					return if t[3] == "true" then Textos.PEDIDOS.hecho else Formato.miles(tonumber(t[1]) or 0) .. "/" .. Formato.miles(tonumber(t[2]) or 1)
				end),
				Color = scope:Computed(function(use)
					return if use(conseguida) then Paleta.UI_PRIMARIO else Paleta.UI_CARTAS
				end),
				Size = UDim2.new(0.5, -8, 0, 24),
				Position = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Radio = 12,
			}),
		},
	})
end

local function paginaInsignias()
	local hijos: { any } = {
		scope:Texto({
			Nombre = "Cuenta",
			Texto = scope:Computed(function(use)
				local p = use(reactivo.perfil)
				local n = 0
				for _ in (p and p.logros) or {} do
					n += 1
				end
				return Textos.formatear(Textos.PEDIDOS.insigniasConseguidas, { n = n, total = #DefinicionesInsignias.LISTA })
			end),
			Size = UDim2.new(1, 0, 0, 26),
			Tamano = 17,
			Fuente = "titulo",
			Alinear = Enum.TextXAlignment.Center,
			Orden = 0,
		}),
	}
	for i, def in DefinicionesInsignias.LISTA do
		table.insert(hijos, filaInsignia(i, def))
	end
	return hijos
end

-- ===========================================================================
-- Ventana
-- ===========================================================================

local PAGINAS = { paginaPedidos, paginaInsignias }
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
	Titulo = Textos.PEDIDOS.titulo,
	Ancho = 720,
	Alto = 560,
	Abierta = scope:Computed(function(use)
		return use(Menu.abiertoR) == NOMBRE
	end),
	alCerrar = Menu.cerrarTodo,
	Hijos = {
		scope:Pestanas({
			Nombres = { Textos.PEDIDOS.pestanaPedidos, Textos.PEDIDOS.pestanaInsignias },
			Seleccion = pestana,
		}),
		paginas,
	},
})

Menu.registrar(NOMBRE, {
	abrir = function(argumento)
		pestana:set(if argumento == "insignias" then 2 else 1)
	end,
	primerSeleccionable = function()
		return Navegacion.primerSeleccionable(paginas[peek(pestana)])
	end,
})

return {}
