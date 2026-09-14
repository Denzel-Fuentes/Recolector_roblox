--!strict
--[[
	ModelosMascota
	Construye por codigo TODOS los modelos whitebox del juego: mascotas,
	fragmentos, basura, billetes, tesoros, figurinas, cintas, trajes y montones.
	Solo primitivas (Part Block/Ball/Cylinder, WedgePart), sin texturas.

	Lo usa el servidor para lo que hay en el mundo y el cliente para las
	previsualizaciones del album (ViewportFrame): un solo vocabulario visual.

	Reglas de lectura a distancia:
	  - color del CUERPO = material del set (Paleta.MATERIAL);
	  - disco bajo la mascota = rareza (Paleta.RAREZA);
	  - tamano crece con la rareza (Comun 1x .. Mitica 2.2x);
	  - el ESTADO se ve: Danada = una pieza torcida y translucida, Regular =
	    color apagado, Excelente = reflectancia, Perfecta = detalles en Neon;
	  - sucia = manchas oscuras pegadas al cuerpo.

	Todas las partes van ANCLADAS: el modelo se mueve con PivotTo (arrastre del
	iman, salto al aparecer, pedestal). El origen del modelo esta en el suelo,
	bajo el centro, para poder colocarlo con PivotTo(CFrame.new(posSuelo)).

	La forma de cada mascota es determinista (Random con semilla de su id): dos
	copias de Latita son identicas y dos mascotas del mismo set no lo son.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))

type Mascota = DefinicionesMascotas.Mascota

local ModelosMascota = {}

local ESCALA_RAREZA = { Comun = 1, Rara = 1.25, Epica = 1.5, Mitica = 2.2 }
local GRIS_OJOS = Paleta.gris(40)

-- ===========================================================================
-- Primitivas
-- ===========================================================================

type Props = {
	Nombre: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Shape: Enum.PartType?,
	Transparency: number?,
	Reflectance: number?,
	Material: Enum.Material?,
	Parent: Instance,
}

local function parte(p: Props): Part
	local x = Instance.new("Part")
	x.Name = p.Nombre or "Parte"
	x.Anchored = true
	x.CanCollide = false
	x.CanTouch = false
	x.CanQuery = true
	x.CastShadow = true
	x.Material = p.Material or Enum.Material.SmoothPlastic
	x.TopSurface = Enum.SurfaceType.Smooth
	x.BottomSurface = Enum.SurfaceType.Smooth
	x.Size = p.Size
	x.CFrame = p.CFrame
	x.Color = p.Color or Paleta.MUEBLE
	if p.Shape then
		x.Shape = p.Shape
	end
	if p.Transparency then
		x.Transparency = p.Transparency
	end
	if p.Reflectance then
		x.Reflectance = p.Reflectance
	end
	x.Parent = p.Parent
	return x
end

local function cuna(p: Props): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = p.Nombre or "Cuna"
	w.Anchored = true
	w.CanCollide = false
	w.CanTouch = false
	w.Material = p.Material or Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Size = p.Size
	w.CFrame = p.CFrame
	w.Color = p.Color or Paleta.MUEBLE
	if p.Transparency then
		w.Transparency = p.Transparency
	end
	w.Parent = p.Parent
	return w
end

-- Cilindro con el eje VERTICAL (Roblox lo crea con el eje en X)
local function cilindroVertical(nombre: string, diametro: number, alto: number, cf: CFrame, color: Color3, padre: Instance): Part
	return parte({
		Nombre = nombre,
		Size = Vector3.new(alto, diametro, diametro),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Shape = Enum.PartType.Cylinder,
		Parent = padre,
	})
end

-- Cilindro con el eje en Z (tumbado hacia el frente)
local function cilindroHorizontal(nombre: string, diametro: number, largo: number, cf: CFrame, color: Color3, padre: Instance): Part
	return parte({
		Nombre = nombre,
		Size = Vector3.new(largo, diametro, diametro),
		CFrame = cf * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Shape = Enum.PartType.Cylinder,
		Parent = padre,
	})
end

local function esfera(nombre: string, diametro: number, cf: CFrame, color: Color3, padre: Instance): Part
	return parte({ Nombre = nombre, Size = Vector3.new(diametro, diametro, diametro), CFrame = cf, Color = color, Shape = Enum.PartType.Ball, Parent = padre })
end

local function bloque(nombre: string, size: Vector3, cf: CFrame, color: Color3, padre: Instance): Part
	return parte({ Nombre = nombre, Size = size, CFrame = cf, Color = color, Parent = padre })
end

local function semilla(texto: string): Random
	local h = 7
	for i = 1, #texto do
		h = (h * 31 + string.byte(texto, i)) % 2147483647
	end
	return Random.new(h)
end

local function nuevoModelo(nombre: string): Model
	local m = Instance.new("Model")
	m.Name = nombre
	return m
end

local function aclarar(color: Color3, f: number): Color3
	return Color3.new(
		math.clamp(color.R + (1 - color.R) * f, 0, 1),
		math.clamp(color.G + (1 - color.G) * f, 0, 1),
		math.clamp(color.B + (1 - color.B) * f, 0, 1)
	)
end

-- ===========================================================================
-- Etiqueta flotante
-- ===========================================================================

function ModelosMascota.etiqueta(modelo: Model, texto: string, color: Color3?, altura: number?): BillboardGui?
	local base = modelo.PrimaryPart
	if not base then
		return nil
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Etiqueta"
	bb.Size = UDim2.fromOffset(140, 26)
	bb.StudsOffsetWorldSpace = Vector3.new(0, altura or 2.6, 0)
	bb.MaxDistance = 45
	bb.AlwaysOnTop = false
	bb.Parent = base
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundColor3 = Paleta.UI_FONDO
	tl.BackgroundTransparency = 0.35
	tl.TextColor3 = color or Paleta.UI_TEXTO
	tl.Text = texto
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamMedium
	tl.Parent = bb
	local esquinas = Instance.new("UICorner")
	esquinas.CornerRadius = UDim.new(0, 6)
	esquinas.Parent = tl
	return bb
end

-- ===========================================================================
-- Mascotas
-- ===========================================================================

-- Devuelve (parte principal, altura del tope del cuerpo). El cuerpo arranca en
-- y = yBase.
local function cuerpoMetal(forma: number, s: number, color: Color3, yBase: number, m: Model): (BasePart, number)
	if forma == 1 then -- lata
		local h = 1.6 * s
		local c = cilindroVertical("Cuerpo", 1.2 * s, h, CFrame.new(0, yBase + h / 2, 0), color, m)
		return c, yBase + h
	elseif forma == 2 then -- bloque con tornillo
		local h = 1.3 * s
		local c = bloque("Cuerpo", Vector3.new(1.3 * s, h, 1.3 * s), CFrame.new(0, yBase + h / 2, 0), color, m)
		cilindroVertical("Tornillo", 0.5 * s, 0.4 * s, CFrame.new(0.35 * s, yBase + h + 0.2 * s, 0.35 * s), aclarar(color, 0.2), m)
		return c, yBase + h + 0.1 * s
	elseif forma == 3 then -- clavo
		local h = 1.9 * s
		local c = bloque("Cuerpo", Vector3.new(0.55 * s, h, 0.55 * s), CFrame.new(0, yBase + h / 2, 0), color, m)
		bloque("Cabeza", Vector3.new(0.9 * s, 0.15 * s, 0.9 * s), CFrame.new(0, yBase + h, 0), aclarar(color, 0.15), m)
		return c, yBase + h + 0.15 * s
	else -- tubo en L
		local h = 1.4 * s
		local c = cilindroVertical("Cuerpo", 0.8 * s, h, CFrame.new(0, yBase + h / 2, 0), color, m)
		cilindroHorizontal("Codo", 0.8 * s, 1.1 * s, CFrame.new(0, yBase + h - 0.1 * s, -0.4 * s), color, m)
		return c, yBase + h + 0.3 * s
	end
end

local function cuerpoPlastico(forma: number, s: number, color: Color3, yBase: number, m: Model): (BasePart, number)
	if forma == 1 then -- botella
		local h = 1.5 * s
		local c = cilindroVertical("Cuerpo", 1.0 * s, h, CFrame.new(0, yBase + h / 2, 0), color, m)
		cilindroVertical("Cuello", 0.5 * s, 0.5 * s, CFrame.new(0, yBase + h + 0.25 * s, 0), aclarar(color, 0.2), m)
		return c, yBase + h + 0.5 * s
	elseif forma == 2 then -- tapa
		local h = 0.6 * s
		local c = cilindroVertical("Cuerpo", 1.6 * s, h, CFrame.new(0, yBase + h / 2, 0), color, m)
		return c, yBase + h
	elseif forma == 3 then -- bolsa
		local d = 1.4 * s
		local c = esfera("Cuerpo", d, CFrame.new(0, yBase + d / 2, 0), color, m)
		cuna({ Nombre = "Asa", Size = Vector3.new(0.5 * s, 0.6 * s, 0.4 * s), CFrame = CFrame.new(0, yBase + d + 0.2 * s, 0), Color = color, Parent = m })
		return c, yBase + d + 0.3 * s
	else -- pajita
		local h = 2.0 * s
		local c = cilindroVertical("Cuerpo", 0.4 * s, h, CFrame.new(0, yBase + h / 2, 0), color, m)
		bloque("Codo", Vector3.new(0.4 * s, 0.4 * s, 0.7 * s), CFrame.new(0, yBase + h, -0.2 * s), aclarar(color, 0.2), m)
		return c, yBase + h + 0.2 * s
	end
end

local function cuerpoPapel(forma: number, s: number, color: Color3, yBase: number, m: Model): (BasePart, number)
	if forma == 1 then -- caja
		local h = 1.2 * s
		local c = bloque("Cuerpo", Vector3.new(1.4 * s, h, 1.4 * s), CFrame.new(0, yBase + h / 2, 0), color, m)
		bloque("Solapa", Vector3.new(1.4 * s, 0.1 * s, 0.6 * s), CFrame.new(0, yBase + h + 0.15 * s, -0.4 * s) * CFrame.Angles(math.rad(-25), 0, 0), aclarar(color, 0.1), m)
		return c, yBase + h
	elseif forma == 2 then -- periodico
		local h = 0.5 * s
		local c = bloque("Cuerpo", Vector3.new(1.7 * s, h, 1.2 * s), CFrame.new(0, yBase + h / 2, 0), color, m)
		bloque("Titular", Vector3.new(1.2 * s, 0.05 * s, 0.25 * s), CFrame.new(0, yBase + h + 0.02 * s, -0.3 * s), Paleta.gris(70), m)
		return c, yBase + h
	elseif forma == 3 then -- rollo
		local d = 0.95 * s
		local c = cilindroHorizontal("Cuerpo", d, 1.6 * s, CFrame.new(0, yBase + d / 2, 0), color, m)
		return c, yBase + d
	else -- bola de papel
		local d = 1.35 * s
		local c = esfera("Cuerpo", d, CFrame.new(0, yBase + d / 2, 0), color, m)
		return c, yBase + d
	end
end

local function cuerpoOrganico(forma: number, s: number, color: Color3, yBase: number, m: Model): (BasePart, number)
	if forma == 1 then -- cascaron
		local d = 1.35 * s
		local c = esfera("Cuerpo", d, CFrame.new(0, yBase + d / 2, 0), aclarar(color, 0.35), m)
		cuna({ Nombre = "Grieta", Size = Vector3.new(0.5 * s, 0.35 * s, 0.35 * s), CFrame = CFrame.new(0.3 * s, yBase + d * 0.8, -0.5 * s), Color = color, Parent = m })
		return c, yBase + d
	elseif forma == 2 then -- semilla
		local d = 1.05 * s
		local c = esfera("Cuerpo", d, CFrame.new(0, yBase + d / 2, 0), color, m)
		bloque("Tallo", Vector3.new(0.12 * s, 0.6 * s, 0.12 * s), CFrame.new(0, yBase + d + 0.25 * s, 0), aclarar(color, 0.1), m)
		return c, yBase + d + 0.4 * s
	elseif forma == 3 then -- hojarasca
		local h = 0.8 * s
		local c = cuna({ Nombre = "Cuerpo", Size = Vector3.new(1.6 * s, h, 1.4 * s), CFrame = CFrame.new(0, yBase + h / 2, 0), Color = color, Parent = m })
		cuna({ Nombre = "Hoja", Size = Vector3.new(1.1 * s, 0.5 * s, 1.0 * s), CFrame = CFrame.new(0.2 * s, yBase + h + 0.2 * s, 0.1 * s) * CFrame.Angles(0, math.rad(140), 0), Color = aclarar(color, 0.15), Parent = m })
		return c, yBase + h + 0.4 * s
	else -- pepita
		local d = 1.15 * s
		local c = esfera("Cuerpo", d, CFrame.new(0, yBase + d / 2, 0), color, m)
		cuna({ Nombre = "Punta", Size = Vector3.new(0.7 * s, 0.6 * s, 0.7 * s), CFrame = CFrame.new(0, yBase + d + 0.25 * s, 0), Color = color, Parent = m })
		return c, yBase + d + 0.5 * s
	end
end

local function cuerpoRey(s: number, yBase: number, m: Model): (BasePart, number)
	local h = 2.2 * s
	local c = bloque("Cuerpo", Vector3.new(2.0 * s, h, 1.4 * s), CFrame.new(0, yBase + h / 2, 0), Paleta.MATERIAL.Mixto, m)
	local materiales = { "Metal", "Plastico", "Papel", "Organico" }
	for i, mat in materiales do
		local yF = yBase + h * (i - 0.5) / 4
		bloque("Franja" .. i, Vector3.new(2.05 * s, h / 8, 1.45 * s), CFrame.new(0, yF, 0), Paleta.MATERIAL[mat], m)
	end
	return c, yBase + h
end

local function detalles(def: Mascota, s: number, color: Color3, yCabeza: number, dCabeza: number, m: Model): { BasePart }
	local lista = {}
	local claro = aclarar(color, 0.25)
	if def.set == "Chatarrin" then
		for _, dx in { -0.3, 0.3 } do
			table.insert(lista, cilindroVertical("Antena", 0.1 * s, 0.6 * s, CFrame.new(dx * s, yCabeza + dCabeza / 2 + 0.25 * s, 0), claro, m))
		end
	elseif def.set == "Plastin" then
		for _, dx in { -0.45, 0.45 } do
			table.insert(lista, esfera("Oreja", 0.4 * s, CFrame.new(dx * s, yCabeza + dCabeza * 0.35, 0), claro, m))
		end
	elseif def.set == "Cartonin" then
		for _, dx in { -0.42, 0.42 } do
			table.insert(lista, bloque("Oreja", Vector3.new(0.3 * s, 0.55 * s, 0.1 * s), CFrame.new(dx * s, yCabeza + dCabeza * 0.45, 0), claro, m))
		end
	elseif def.set == "Mostrenco" then
		table.insert(lista, cuna({ Nombre = "Brote", Size = Vector3.new(0.35 * s, 0.5 * s, 0.35 * s), CFrame = CFrame.new(0.1 * s, yCabeza + dCabeza / 2 + 0.2 * s, 0), Color = claro, Parent = m }))
	else -- Rey: corona
		table.insert(lista, cilindroVertical("Corona", dCabeza * 0.9, 0.35 * s, CFrame.new(0, yCabeza + dCabeza / 2 + 0.1 * s, 0), Paleta.RAREZA.Mitica, m))
	end
	return lista
end

local function manchas(def: Mascota, s: number, cuerpo: BasePart, m: Model)
	local rng = semilla(def.id .. "sucia")
	local size = cuerpo.Size
	for i = 1, 3 do
		local dx = rng:NextNumber(-0.4, 0.4) * size.X
		local dy = rng:NextNumber(-0.3, 0.3) * size.Y
		local d = rng:NextNumber(0.3, 0.5) * s
		esfera("Mancha" .. i, d, cuerpo.CFrame * CFrame.new(dx, dy, -size.Z / 2), Paleta.gris(60), m)
	end
end

function ModelosMascota.mascota(def: Mascota, estado: number, sucia: boolean?): Model
	local m = nuevoModelo(def.nombre)
	m:SetAttribute("MascotaId", def.id)
	m:SetAttribute("Estado", estado)
	local s = ESCALA_RAREZA[def.rareza] or 1
	estado = math.clamp(estado, 1, 5)
	local color = Paleta.escalar(Paleta.MATERIAL[def.material] or Paleta.MUEBLE, Paleta.FACTOR_ESTADO[estado])

	-- Disco de rareza en el suelo
	local disco = cilindroVertical("Disco", 2.2 * s, 0.25, CFrame.new(0, 0.125, 0), Paleta.RAREZA[def.rareza] or Paleta.RAREZA.Comun, m)
	local yBase = 0.25

	local cuerpo: BasePart
	local tope: number
	if def.set == "Chatarrin" then
		cuerpo, tope = cuerpoMetal(def.forma, s, color, yBase, m)
	elseif def.set == "Plastin" then
		cuerpo, tope = cuerpoPlastico(def.forma, s, color, yBase, m)
	elseif def.set == "Cartonin" then
		cuerpo, tope = cuerpoPapel(def.forma, s, color, yBase, m)
	elseif def.set == "Mostrenco" then
		cuerpo, tope = cuerpoOrganico(def.forma, s, color, yBase, m)
	else
		cuerpo, tope = cuerpoRey(s, yBase, m)
	end

	-- Cabeza y ojos: lo que convierte un trozo de basura en una mascota
	local dCabeza = 0.95 * s
	local yCabeza = tope + dCabeza / 2 - 0.1 * s
	local cabeza = esfera("Cabeza", dCabeza, CFrame.new(0, yCabeza, 0), aclarar(color, 0.15), m)
	for _, dx in { -0.2, 0.2 } do
		bloque("Ojo", Vector3.new(0.14 * s, 0.18 * s, 0.08 * s), CFrame.new(dx * s, yCabeza + 0.08 * s, -dCabeza / 2 + 0.02 * s), GRIS_OJOS, m)
	end
	local lista = detalles(def, s, color, yCabeza, dCabeza, m)

	-- Estado de conservacion
	if estado == 1 and #lista > 0 then
		local pieza = lista[1]
		pieza.CFrame = pieza.CFrame * CFrame.Angles(0, 0, math.rad(28))
		pieza.Transparency = 0.35
		cabeza.CFrame = cabeza.CFrame * CFrame.Angles(0, 0, math.rad(-12))
	elseif estado == 4 then
		cuerpo.Reflectance = 0.3
		cabeza.Reflectance = 0.3
	elseif estado == 5 then
		for _, pieza in lista do
			pieza.Material = Enum.Material.Neon
		end
		disco.Material = Enum.Material.Neon
		cuerpo.Reflectance = 0.15
	end

	if sucia then
		manchas(def, s, cuerpo, m)
	end

	m.PrimaryPart = cuerpo
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end

-- Altura util para colocar la etiqueta encima
function ModelosMascota.alturaMascota(def: Mascota): number
	local s = ESCALA_RAREZA[def.rareza] or 1
	return 3.2 * s
end

-- ===========================================================================
-- Objetos sueltos
-- ===========================================================================

function ModelosMascota.fragmento(def: Mascota, indice: number): Model
	local m = nuevoModelo("Fragmento de " .. def.nombre)
	m:SetAttribute("MascotaId", def.id)
	local color = Paleta.MATERIAL[def.material] or Paleta.MUEBLE
	local rng = semilla(def.id .. tostring(indice))
	local c = cuna({
		Nombre = "Cuerpo",
		Size = Vector3.new(1.1, 0.7, 1.0),
		CFrame = CFrame.new(0, 0.35, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		Color = color,
		Parent = m,
	})
	bloque("Borde", Vector3.new(1.15, 0.08, 1.05), c.CFrame * CFrame.new(0, -0.31, 0), Paleta.FRAGMENTO_BORDE, m)
	m.PrimaryPart = c
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end

function ModelosMascota.basura(material: string): Model
	local m = nuevoModelo("Basura")
	local color = Paleta.MATERIAL[material] or Paleta.MUEBLE
	local c: BasePart
	if material == "Metal" then
		c = cilindroHorizontal("Cuerpo", 0.7, 1.0, CFrame.new(0, 0.35, 0) * CFrame.Angles(0, math.rad(30), 0), color, m)
	elseif material == "Plastico" then
		c = cilindroVertical("Cuerpo", 0.6, 1.2, CFrame.new(0, 0.55, 0) * CFrame.Angles(math.rad(70), 0, math.rad(20)), color, m)
	elseif material == "Papel" then
		c = bloque("Cuerpo", Vector3.new(1.1, 0.15, 1.3), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, math.rad(15), 0), color, m)
	else
		c = esfera("Cuerpo", 0.8, CFrame.new(0, 0.4, 0), color, m)
		cuna({ Nombre = "Hoja", Size = Vector3.new(0.5, 0.25, 0.5), CFrame = CFrame.new(0.2, 0.85, 0), Color = Paleta.escalar(color, 1.2), Parent = m })
	end
	m.PrimaryPart = c
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end

function ModelosMascota.billete(): Model
	local m = nuevoModelo("Billete")
	local c = bloque("Cuerpo", Vector3.new(1.3, 0.06, 0.65), CFrame.new(0, 0.05, 0) * CFrame.Angles(0, math.rad(20), 0), Paleta.BILLETE, m)
	bloque("Sello", Vector3.new(0.4, 0.07, 0.4), c.CFrame * CFrame.new(0, 0.01, 0), Paleta.escalar(Paleta.BILLETE, 0.75), m)
	m.PrimaryPart = c
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end

function ModelosMascota.tesoro(): Model
	local m = nuevoModelo("Tesoro")
	local c = bloque("Cuerpo", Vector3.new(1.1, 0.8, 0.8), CFrame.new(0, 0.4, 0), Paleta.TESORO, m)
	bloque("Tapa", Vector3.new(1.15, 0.2, 0.85), CFrame.new(0, 0.9, 0), Paleta.escalar(Paleta.TESORO, 0.8), m)
	bloque("Cierre", Vector3.new(0.2, 0.3, 0.1), CFrame.new(0, 0.75, -0.42), Paleta.gris(60), m)
	m.PrimaryPart = c
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end

function ModelosMascota.figurina(def: DefinicionesColeccionables.Figurina): Model
	local m = nuevoModelo(def.nombre)
	m:SetAttribute("FigurinaId", def.id)
	local rng = semilla(def.id)
	local color = Paleta.FIGURINA
	local base = cilindroVertical("Base", 0.9, 0.2, CFrame.new(0, 0.1, 0), Paleta.gris(120), m)
	bloque("Cuerpo", Vector3.new(0.5, 0.9, 0.4), CFrame.new(0, 0.65, 0), color, m)
	esfera("Cabeza", 0.5, CFrame.new(0, 1.3, 0), color, m)
	if rng:NextNumber() > 0.5 then
		bloque("Sombrero", Vector3.new(0.6, 0.15, 0.6), CFrame.new(0, 1.6, 0), Paleta.gris(120), m)
	else
		cuna({ Nombre = "Sombrero", Size = Vector3.new(0.4, 0.4, 0.4), CFrame = CFrame.new(0, 1.7, 0), Color = Paleta.gris(120), Parent = m })
	end
	m.PrimaryPart = base
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end

function ModelosMascota.cinta(def: DefinicionesColeccionables.Cinta): Model
	local m = nuevoModelo(def.nombre)
	m:SetAttribute("CintaId", def.id)
	local c = bloque("Cuerpo", Vector3.new(1.1, 0.2, 0.7), CFrame.new(0, 0.1, 0), Paleta.CINTA, m)
	for _, dx in { -0.28, 0.28 } do
		cilindroVertical("Carrete", 0.3, 0.22, CFrame.new(dx, 0.11, 0), Paleta.gris(200), m)
	end
	m.PrimaryPart = c
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end

function ModelosMascota.traje(def: DefinicionesColeccionables.Traje): Model
	local m = nuevoModelo(def.nombre)
	m:SetAttribute("TrajeId", def.id)
	local c = bloque("Cuerpo", Vector3.new(1.3, 0.25, 1.2), CFrame.new(0, 0.125, 0), def.colorCuerpo, m)
	bloque("Pliegue", Vector3.new(1.3, 0.2, 0.5), CFrame.new(0, 0.35, -0.2), def.colorBrazos, m)
	bloque("Pliegue2", Vector3.new(0.6, 0.15, 1.2), CFrame.new(0.3, 0.32, 0.1), def.colorPiernas, m)
	m.PrimaryPart = c
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end

-- ===========================================================================
-- Montones
-- ===========================================================================

local PIEZAS_MONTON = { chico = 4, mediano = 6, grande = 9 }
local RADIO_MONTON = { chico = 2.2, mediano = 3.2, grande = 4.4 }

function ModelosMascota.radioMonton(tamano: string): number
	return RADIO_MONTON[tamano] or 3
end

function ModelosMascota.monton(tamano: string, agotado: boolean, indice: number?): Model
	local m = nuevoModelo("Monton")
	local rng = semilla("monton" .. tamano .. tostring(indice or 0))
	local radio = RADIO_MONTON[tamano] or 3
	if agotado then
		local c = bloque("Resto", Vector3.new(radio * 1.6, 0.4, radio * 1.4), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Paleta.MONTON_AGOTADO, m)
		bloque("Resto2", Vector3.new(radio * 1.0, 0.3, radio * 0.9), CFrame.new(radio * 0.3, 0.15, -radio * 0.2) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Paleta.MONTON_AGOTADO, m)
		m.PrimaryPart = c
		m.WorldPivot = CFrame.new(0, 0, 0)
		return m
	end
	local n = PIEZAS_MONTON[tamano] or 3
	local principal: BasePart? = nil
	for i = 1, n do
		local ang = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(0, radio * 0.55)
		local sx = rng:NextNumber(1.6, 2.8) * radio / 2.6 * 1.9
		local sy = rng:NextNumber(1.2, 2.4) * radio / 2.6 * 2.2
		local sz = rng:NextNumber(1.6, 2.8) * radio / 2.6 * 1.9
		local cf = CFrame.new(math.cos(ang) * dist, sy / 2 + (i - 1) * 0.25, math.sin(ang) * dist)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local pieza: BasePart
		if i % 2 == 0 then
			pieza = cuna({ Nombre = "Pieza" .. i, Size = Vector3.new(sx, sy, sz), CFrame = cf, Color = Paleta.MONTON, Parent = m })
		else
			pieza = bloque("Pieza" .. i, Vector3.new(sx, sy, sz), cf, Paleta.MONTON, m)
		end
		pieza.CanCollide = true
		pieza.CanQuery = true
		if not principal then
			principal = pieza
		end
	end
	-- Corona del monton: una pieza mas alta en el centro
	local cima = bloque("Cima", Vector3.new(radio * 1.4, radio * 1.2, radio * 1.4), CFrame.new(0, radio * 1.4, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Paleta.escalar(Paleta.MONTON, 1.08), m)
	cima.CanCollide = true
	m.PrimaryPart = cima
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end

-- Anillo neon bajo un monton activado: la unica luz del mapa
function ModelosMascota.anilloActivado(radio: number): Part
	local anillo = Instance.new("Part")
	anillo.Name = "AnilloActivado"
	anillo.Anchored = true
	anillo.CanCollide = false
	anillo.CanQuery = false
	anillo.CanTouch = false
	anillo.Material = Enum.Material.Neon
	anillo.Color = Paleta.NEON_ACTIVADO
	anillo.Shape = Enum.PartType.Cylinder
	anillo.Size = Vector3.new(0.2, radio * 3.6 + 2, radio * 3.6 + 2)
	anillo.CFrame = CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(90))
	return anillo
end

return ModelosMascota
