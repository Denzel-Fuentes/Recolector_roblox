--!strict
--[[
	ModelosMascota
	Construye por codigo las 41 mascotas (en sus 5 estados, sucias o no) y sus
	fragmentos. Solo primitivas (Primitivas.luau), sin texturas. La basura,
	tesoros, coleccionables y bolsas estan en ModelosObjetos; la colina de los
	montones en ModelosMonton.

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
	iman, pedestal). El origen del modelo esta en el suelo, bajo el centro.

	La forma de cada mascota es determinista (Random con semilla de su id): dos
	copias de Latita son identicas y dos mascotas del mismo set no lo son.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local Primitivas = require(Shared:WaitForChild("Utilidades"):WaitForChild("Primitivas"))

local cuna, cilindroVertical, cilindroHorizontal, esfera, bloque, semilla, nuevoModelo, pivoteEnSuelo, aclarar =
	Primitivas.cuna, Primitivas.cilindroVertical, Primitivas.cilindroHorizontal, Primitivas.esfera, Primitivas.bloque, Primitivas.semilla, Primitivas.nuevoModelo, Primitivas.pivoteEnSuelo, Primitivas.aclarar

type Mascota = DefinicionesMascotas.Mascota

local ModelosMascota = {}

local ESCALA_RAREZA = { Comun = 1, Rara = 1.25, Epica = 1.5, Mitica = 2.2 }
local GRIS_OJOS = Paleta.gris(40)

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
	pivoteEnSuelo(m)
	return m
end

-- Altura util para colocar la etiqueta encima
function ModelosMascota.alturaMascota(def: Mascota): number
	local s = ESCALA_RAREZA[def.rareza] or 1
	return 3.2 * s
end

-- ===========================================================================
-- Fragmentos
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
	pivoteEnSuelo(m)
	return m
end

return ModelosMascota
