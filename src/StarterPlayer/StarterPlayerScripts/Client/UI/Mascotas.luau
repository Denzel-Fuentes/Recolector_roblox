--!strict
--[[
	Mascotas (ModuleScript)
	El album de mascotas del diseno v2: una pestana por set (Cartonin,
	Plastin, Chatarrin, Mostrenco), cada una con sus 10 mascotas en rejilla,
	y a la derecha el detalle de la elegida (nivel, bonus, iman) con el boton
	Equipar/Quitar. Arriba, la mascota que el set esta montando con
	fragmentos ("Latita (Comun): 3/5 fragmentos"; su tarjeta lo marca con ✦)
	y, si hay, los fragmentos libres de los pedidos para usar en ese set.
	Abajo, los huecos, el Rey Reciclon y las probabilidades de la rareza de
	la siguiente mascota (se decide con su primer fragmento).

	Los sets cerrados (Metal con el Rebirth 1, Organico con el 2) se ven,
	con candado: el album tambien ensena lo que espera.

	Rendimiento: el perfil llega varias veces por segundo como tablas nuevas.
	Cada tarjeta deriva solo el NIVEL de su mascota (un numero) y su modelo
	se rehace solo si cambia, y solo cuando su set ya se ha visto una vez
	(los 41 modelos no se construyen al entrar al juego). Las mascotas que
	no tienes se ven como silueta oscura.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local DefinicionesRebirths = require(Config:WaitForChild("DefinicionesRebirths"))
local TablasProbabilidad = require(Config:WaitForChild("TablasProbabilidad"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosMascota = require(Utilidades:WaitForChild("ModelosMascota"))
local Red = require(Utilidades:WaitForChild("Red"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Encuadre = require(script.Parent:WaitForChild("Kit"):WaitForChild("Encuadre"))
local Navegacion = require(script.Parent:WaitForChild("Kit"):WaitForChild("Navegacion"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local EquiparMascotaEvent = Red.evento("EquiparMascotaEvent")
local UsarFragmentoEvent = Red.evento("UsarFragmentoEvent")

local NOMBRE = "Mascotas"
local reactivo = EstadoCliente.reactivo
local scope = Fusion.scoped(Fusion, Kit)

local SETS = DefinicionesMascotas.SETS
local ICONO_SET = { Papel = "setPapel", Plastico = "setPlastico", Metal = "setMetal", Organico = "setOrganico" }

local pestana = scope:Value(1)
local elegida = scope:Value(SETS[1] and DefinicionesMascotas.porSet(SETS[1].id)[1].id or "")

-- ===========================================================================
-- Primitivos del perfil
-- ===========================================================================

local rebirths = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	return if p then (p.rebirths or 0) else 0
end)
local niveles: { [string]: any } = {}
for _, def in DefinicionesMascotas.LISTA do
	niveles[def.id] = scope:Computed(function(use)
		local p = use(reactivo.perfil)
		return if p and p.mascotas then (p.mascotas[def.id] or 0) else 0
	end)
end
-- Lista de equipadas como texto ("a,b"): un primitivo que solo cambia al
-- equipar o quitar
local equipadasTexto = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	return if p and p.equipadas then table.concat(p.equipadas, ",") else ""
end)
local function estaEquipada(id: string)
	return scope:Computed(function(use)
		return table.find(string.split(use(equipadasTexto), ","), id) ~= nil
	end)
end
local huecos = scope:Computed(function(use)
	-- (el pase Tercera mascota suma en el servidor; el cliente lo sabra en el lote 8)
	return DefinicionesRebirths.huecosMascota(use(rebirths))
end)
local numEquipadas = scope:Computed(function(use)
	local t = use(equipadasTexto)
	return if t == "" then 0 else #string.split(t, ",")
end)
local fragmentosLibres = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	return if p then (p.fragmentosLibres or 0) else 0
end)

local function setAbierto(set: DefinicionesMascotas.Set)
	return scope:Computed(function(use)
		return DefinicionesMascotas.setAbierto(set.id, use(rebirths))
	end)
end

-- La mascota que monta cada set: id ("" si ninguna), fragmentos que lleva
-- y los que pide (tres primitivos: un Computed solo guarda un valor)
type Montaje = { id: any, n: any, total: any }
local montajes: { [string]: Montaje } = {}
for _, set in SETS do
	local function campo(clave: string, defecto: any)
		return scope:Computed(function(use)
			local p = use(reactivo.perfil)
			local m = p and p.fragmentos and p.fragmentos[set.id]
			return if m then m[clave] else defecto
		end)
	end
	montajes[set.id] = { id = campo("id", ""), n = campo("n", 0), total = campo("total", 0) }
end

-- "Comun 67 % · Rara 28 % · Epica 5 %" (la tabla del servidor)
local partesProbabilidad = {}
for _, e in TablasProbabilidad.RAREZA_MASCOTA do
	table.insert(partesProbabilidad, string.format("%s %d %%", DefinicionesMascotas.NOMBRE_RAREZA[e.id] or e.id, math.floor(e.peso + 0.5)))
end
local TEXTO_PROBABILIDADES = Textos.formatear(Textos.MASCOTAS.probabilidades, { texto = table.concat(partesProbabilidad, " · ") }) .. ". " .. Textos.MASCOTAS.pity

-- ===========================================================================
-- Modelos (perezosos: al ver el set por primera vez)
-- ===========================================================================

-- Silueta: la mascota en negro, para las que aun no tienes
local function silueta(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = Paleta.UI_TINTA
			d.Material = Enum.Material.SmoothPlastic
			d.Reflectance = 0
		end
	end
end

local function modeloPara(def: DefinicionesMascotas.Mascota, nivel: number): Model
	local m = ModelosMascota.mascota(def, math.max(nivel, 1))
	if nivel <= 0 then
		silueta(m)
	end
	return m
end

local setsVistos: { [string]: boolean } = {}
local pintores: { [string]: { () -> () } } = {} -- set -> repintar sus tarjetas
local pintarDetalle: () -> () = function() end -- se define con el detalle

local function verSet(setId: string)
	if not setsVistos[setId] then
		setsVistos[setId] = true
		for _, pintar in pintores[setId] or {} do
			pintar()
		end
	end
	pintarDetalle()
end

-- ===========================================================================
-- Tarjetas
-- ===========================================================================

local LADO = 132

local function tarjeta(def: DefinicionesMascotas.Mascota, orden: number)
	local nivel = niveles[def.id]
	local equipada = estaEquipada(def.id)
	local montaje = montajes[def.set]
	local vista = scope:Viewport({ Nombre = "Vista", Size = UDim2.new(1, 0, 0, LADO - 44), Color = Paleta.UI_PAPEL })
	local function pintar()
		if setsVistos[def.set] then
			Encuadre.mostrar(vista, modeloPara(def, peek(nivel)))
		end
	end
	pintores[def.set] = pintores[def.set] or {}
	table.insert(pintores[def.set], pintar)
	scope:Observer(nivel):onChange(pintar)
	return scope:New("TextButton")({
		Name = "Mascota_" .. def.id,
		Text = "",
		Size = UDim2.fromOffset(LADO, LADO + 12),
		LayoutOrder = orden,
		BackgroundColor3 = Paleta.RAREZA[def.rareza] or Paleta.UI_PAPEL_OSCURO,
		AutoButtonColor = false,
		[OnEvent("Activated")] = function()
			elegida:set(def.id)
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = scope:Computed(function(use)
					return if use(elegida) == def.id then Paleta.UI_PAPEL else Paleta.UI_TINTA
				end),
				Thickness = scope:Computed(function(use)
					return if use(elegida) == def.id then 4 else 2
				end),
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 5),
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
			}),
			vista,
			scope:Texto({
				Texto = def.nombre,
				Size = UDim2.new(1, 0, 0, 22),
				Position = UDim2.new(0, 0, 0, LADO - 42),
				Tamano = 15,
				Fuente = "titulo",
				Color = Paleta.UI_PAPEL,
				Contorno = Paleta.UI_TINTA,
				Alinear = Enum.TextXAlignment.Center,
				Ajustar = false,
			}),
			scope:Texto({
				Texto = scope:Computed(function(use)
					local n = use(nivel)
					local fragmentos = if montaje and use(montaje.id) == def.id then string.format("✦%d/%d", use(montaje.n), use(montaje.total)) else ""
					if n <= 0 then
						return if fragmentos ~= "" then fragmentos else "—"
					end
					return Textos.formatear(Textos.MASCOTAS.nivel, { n = n }) .. (if use(equipada) then " ★" else "") .. (if fragmentos ~= "" then " " .. fragmentos else "")
				end),
				Size = UDim2.new(1, 0, 0, 18),
				Position = UDim2.new(0, 0, 0, LADO - 20),
				Tamano = 14,
				Fuente = "negrita",
				Color = Paleta.UI_PAPEL,
				Contorno = Paleta.UI_TINTA,
				Alinear = Enum.TextXAlignment.Center,
			}),
		},
	})
end

-- ===========================================================================
-- Paginas (una por set)
-- ===========================================================================

local function pagina(i: number, set: DefinicionesMascotas.Set)
	local abierto = setAbierto(set)
	local montaje = montajes[set.id]
	local tarjetas = {}
	for k, def in DefinicionesMascotas.porSet(set.id) do
		table.insert(tarjetas, tarjeta(def, k))
	end
	local tengo = scope:Computed(function(use)
		local n = 0
		for _, def in DefinicionesMascotas.porSet(set.id) do
			if use(niveles[def.id]) > 0 then
				n += 1
			end
		end
		return n
	end)
	return scope:New("Frame")({
		Name = "Pagina_" .. set.id,
		Size = UDim2.new(1, -330, 1, -104),
		Position = UDim2.fromOffset(0, 104),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			return use(pestana) == i
		end),
		[Children] = {
			scope:New("Frame")({
				Name = "Rejilla",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[Children] = {
					scope:Rejilla({ Celda = UDim2.fromOffset(LADO, LADO + 12), Espacio = 10 }),
					tarjetas,
				},
			}),
			-- Cabecera del set: coleccion y la mascota que monta
			scope:New("Frame")({
				Name = "Cabecera",
				Size = UDim2.new(1, 0, 0, 52),
				Position = UDim2.fromOffset(0, -54),
				BackgroundTransparency = 1,
				[Children] = {
					scope:Icono({ Clave = ICONO_SET[set.material] or "estrella", Tamano = 44, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) }),
					scope:Texto({
						Texto = scope:Computed(function(use)
							return set.nombre .. "  " .. Textos.formatear(Textos.MASCOTAS.coleccion, { n = use(tengo) })
						end),
						Size = UDim2.new(0.4, -50, 1, 0),
						Position = UDim2.fromOffset(50, 0),
						Tamano = 20,
						Fuente = "titulo",
					}),
					scope:Barra({
						Nombre = "Montaje",
						Fraccion = scope:Computed(function(use)
							local total = use(montaje.total)
							return if total > 0 then math.clamp(use(montaje.n) / total, 0, 1) else 0
						end),
						Texto = scope:Computed(function(use)
							if not use(abierto) then
								return Textos.formatear(Textos.MASCOTAS.bloqueado, { n = set.rebirth })
							end
							local d = DefinicionesMascotas.obtener(use(montaje.id))
							if not d then
								return Textos.formatear(Textos.MASCOTAS.sinMontar, { set = set.nombre })
							end
							return Textos.formatear(Textos.MASCOTAS.montando, {
								nombre = d.nombre,
								rareza = DefinicionesMascotas.NOMBRE_RAREZA[d.rareza] or d.rareza,
								n = use(montaje.n),
								total = use(montaje.total),
							})
						end),
						Color = Paleta.MATERIAL[set.material] or Paleta.UI_DINERO,
						Size = UDim2.new(0.6, 0, 0, 30),
						Position = UDim2.new(1, 0, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						Radio = 15,
						TamanoTexto = 14,
					}),
				},
			}),
		},
	})
end

local paginas = {}
for i, set in SETS do
	table.insert(paginas, pagina(i, set))
end

-- ===========================================================================
-- Detalle de la elegida
-- ===========================================================================

local defElegida = scope:Computed(function(use)
	return DefinicionesMascotas.obtener(use(elegida))
end)
local nivelElegida = scope:Computed(function(use)
	local def = use(defElegida)
	return if def then use(niveles[def.id]) else 0
end)
local equipadaElegida = scope:Computed(function(use)
	local def = use(defElegida)
	return def ~= nil and table.find(string.split(use(equipadasTexto), ","), def.id) ~= nil
end)
local vistaDetalle = scope:Viewport({ Nombre = "VistaDetalle", Size = UDim2.new(1, 0, 0, 200), Color = Paleta.UI_PAPEL, Orden = 1 })
pintarDetalle = function()
	local def = peek(defElegida)
	if def and setsVistos[def.set] then
		Encuadre.mostrar(vistaDetalle, modeloPara(def, peek(nivelElegida)))
	end
end
scope:Observer(scope:Computed(function(use)
	local def = use(defElegida)
	return (if def then def.id else "") .. ":" .. use(nivelElegida)
end)):onBind(pintarDetalle)

local function textoBonus(def: DefinicionesMascotas.Mascota, nivel: number): string
	local pct = math.floor(DefinicionesMascotas.bonus(def, math.max(nivel, 1)) * 100 + 0.5)
	if def.rareza == "Mitica" then
		return Textos.formatear(Textos.MASCOTAS.bonusRey, { pct = pct })
	end
	return Textos.formatear(Textos.MASCOTAS.bonus, { pct = pct, material = Textos.MATERIALES[def.material] or def.material })
end

local detalle = scope:Tarjeta({
	Nombre = "Detalle",
	Size = UDim2.new(0, 318, 1, -54),
	Position = UDim2.new(1, 0, 0, 54),
	AnchorPoint = Vector2.new(1, 0),
	Hijos = {
		scope:Lista({ Espacio = 6, Alinear = Enum.HorizontalAlignment.Center }),
		vistaDetalle,
		scope:Texto({
			Texto = scope:Computed(function(use)
				local def = use(defElegida)
				return if def then def.nombre else ""
			end),
			Size = UDim2.new(1, 0, 0, 28),
			Tamano = 22,
			Fuente = "titulo",
			Alinear = Enum.TextXAlignment.Center,
			Orden = 2,
		}),
		scope:Texto({
			Texto = scope:Computed(function(use)
				local def = use(defElegida)
				if not def then
					return ""
				end
				local n = use(nivelElegida)
				local rareza = DefinicionesMascotas.NOMBRE_RAREZA[def.rareza] or def.rareza
				return if n > 0 then rareza .. " · " .. Textos.formatear(Textos.MASCOTAS.nivel, { n = n }) .. "/5" else rareza .. " · " .. Textos.MASCOTAS.noLaTienes
			end),
			Size = UDim2.new(1, 0, 0, 20),
			Tamano = 15,
			Fuente = "negrita",
			Color = scope:Computed(function(use)
				local def = use(defElegida)
				return if def then (Paleta.RAREZA[def.rareza] or Paleta.UI_TINTA) else Paleta.UI_TINTA
			end),
			Alinear = Enum.TextXAlignment.Center,
			Orden = 3,
		}),
		scope:Texto({
			Texto = scope:Computed(function(use)
				local def = use(defElegida)
				return if def then textoBonus(def, use(nivelElegida)) else ""
			end),
			Size = UDim2.new(1, 0, 0, 20),
			Tamano = 16,
			Fuente = "titulo",
			Color = Paleta.UI_EXITO,
			Alinear = Enum.TextXAlignment.Center,
			Orden = 4,
		}),
		scope:Texto({
			Texto = scope:Computed(function(use)
				local def = use(defElegida)
				if not def then
					return ""
				end
				local radio = DefinicionesMascotas.iman(def)
				return if radio > 0 then Textos.formatear(Textos.MASCOTAS.iman, { material = Textos.MATERIALES[def.material] or def.material, radio = radio }) else Textos.MASCOTAS.sinIman
			end),
			Size = UDim2.new(1, 0, 0, 18),
			Tamano = 14,
			Fuente = "negrita",
			Color = Paleta.UI_TINTA_SUAVE,
			Alinear = Enum.TextXAlignment.Center,
			Orden = 5,
		}),
		scope:Texto({
			Texto = scope:Computed(function(use)
				local def = use(defElegida)
				return if def then def.descripcion else ""
			end),
			Size = UDim2.new(1, 0, 0, 36),
			Tamano = 13,
			Color = Paleta.UI_TINTA_SUAVE,
			Alinear = Enum.TextXAlignment.Center,
			Orden = 6,
		}),
		scope:Boton({
			Nombre = "Equipar",
			Texto = scope:Computed(function(use)
				return if use(equipadaElegida) then Textos.MASCOTAS.quitar else Textos.MASCOTAS.equipar
			end),
			Color = scope:Computed(function(use)
				return if use(equipadaElegida) then Paleta.UI_PELIGRO else Paleta.UI_EXITO
			end),
			Tamano = 18,
			Size = UDim2.fromOffset(200, 46),
			Orden = 7,
			Visible = scope:Computed(function(use)
				local def = use(defElegida)
				return def ~= nil and def.rareza ~= "Mitica" and use(nivelElegida) > 0
			end),
			Deshabilitado = scope:Computed(function(use)
				return not use(equipadaElegida) and use(numEquipadas) >= use(huecos)
			end),
			alPulsar = function()
				local def = peek(defElegida)
				if def then
					EquiparMascotaEvent:FireServer(def.id, not peek(equipadaElegida))
				end
			end,
		}),
	},
})

-- ===========================================================================
-- Ventana
-- ===========================================================================

local nombresSets, coloresSets = {}, {}
for _, set in SETS do
	table.insert(nombresSets, set.nombre)
	table.insert(coloresSets, Paleta.MATERIAL[set.material] or Paleta.UI_PRIMARIO)
end

local setActual = scope:Computed(function(use)
	return SETS[use(pestana)]
end)

local pie = scope:New("Frame")({
	Name = "Pie",
	Size = UDim2.new(1, -330, 0, 40),
	Position = UDim2.new(0, 0, 1, 0),
	AnchorPoint = Vector2.new(0, 1),
	BackgroundTransparency = 1,
	[Children] = {
		scope:Texto({
			Texto = scope:Computed(function(use)
				return Textos.formatear(Textos.MASCOTAS.equipadas, { n = use(numEquipadas), max = use(huecos) })
			end),
			Size = UDim2.new(0.35, 0, 1, 0),
			Tamano = 16,
			Fuente = "titulo",
		}),
		scope:Texto({
			Texto = scope:Computed(function(use)
				local rey = use(niveles[DefinicionesMascotas.ID_REY])
				if rey > 0 then
					return "Rey Reciclón · " .. Textos.MASCOTAS.siempreContigo .. " · " .. Textos.formatear(Textos.MASCOTAS.bonusRey, { pct = math.floor(DefinicionesMascotas.BONUS_REY * 100 + 0.5) })
				end
				return Textos.MASCOTAS.rey
			end),
			Size = UDim2.new(0.65, 0, 0.5, 0),
			Position = UDim2.fromScale(0.35, 0),
			Tamano = 13,
			Fuente = "negrita",
			Color = Paleta.RAREZA.Mitica,
			Contorno = Paleta.UI_TINTA,
		}),
		scope:Texto({
			Nombre = "Probabilidades",
			Texto = TEXTO_PROBABILIDADES,
			Size = UDim2.new(0.65, 0, 0.5, 0),
			Position = UDim2.fromScale(0.35, 0.5),
			Tamano = 12,
			Fuente = "negrita",
			Color = Paleta.UI_TINTA_SUAVE,
		}),
	},
})

local botonLibre = scope:Boton({
	Nombre = "FragmentoLibre",
	Texto = scope:Computed(function(use)
		return Textos.formatear(Textos.MASCOTAS.fragmentosLibres, { n = use(fragmentosLibres) }) .. " · " .. Textos.MASCOTAS.usarLibre
	end),
	Color = Paleta.CABECERA_PANEL.Revelacion,
	Tamano = 14,
	Size = UDim2.fromOffset(318, 44),
	Position = UDim2.new(1, 0, 0, 0),
	AnchorPoint = Vector2.new(1, 0),
	Visible = scope:Computed(function(use)
		local set = use(setActual)
		return use(fragmentosLibres) > 0 and set ~= nil and DefinicionesMascotas.setAbierto(set.id, use(rebirths))
	end),
	alPulsar = function()
		local set = peek(setActual)
		if set then
			UsarFragmentoEvent:FireServer(set.id)
		end
	end,
})

local contenido = scope:New("Frame")({
	Name = "Cuerpo",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	[Children] = {
		scope:Pestanas({
			Nombres = nombresSets,
			Colores = coloresSets,
			Seleccion = pestana,
			Size = UDim2.new(1, -330, 0, 44),
			alCambiar = function(i)
				local set = SETS[i]
				if set then
					verSet(set.id)
					elegida:set(DefinicionesMascotas.porSet(set.id)[1].id)
				end
			end,
		}),
		botonLibre,
		paginas,
		detalle,
		pie,
	},
})

scope:Ventana({
	Nombre = NOMBRE,
	Titulo = Textos.MASCOTAS.titulo,
	Ancho = 1060,
	Alto = 640,
	Abierta = scope:Computed(function(use)
		return use(Menu.abiertoR) == NOMBRE
	end),
	alCerrar = Menu.cerrarTodo,
	Hijos = { contenido },
})

Menu.registrar(NOMBRE, {
	abrir = function(argumento)
		local i = peek(pestana)
		for k, set in SETS do
			if set.id == argumento then
				i = k
			end
		end
		pestana:set(i)
		verSet(SETS[i].id)
		local def = DefinicionesMascotas.obtener(peek(elegida))
		if def then
			verSet(def.set)
		end
	end,
	primerSeleccionable = function()
		return Navegacion.primerSeleccionable(paginas[peek(pestana)])
	end,
})

return {}
