--!strict
--[[
	ModelosObjetos
	Los modelos whitebox de lo que se recoge y se lleva: basura real (mallas
	low-poly de ReplicatedStorage.Arte.Basura si el place las tiene; si no,
	16 formas de primitivas, 4 por material), billetes, tesoros, figurinas,
	cintas y las dos bolsas (cerrada con nudo para lanzar; abierta para las
	manos, que se cierra al llenarse), con las mallas de Blender
	ServerStorage.Arte.Bolsa / .BolsaAbierta si el place las tiene. La colina
	de los montones va en ModelosMonton. Primitivas pone los ladrillos.

	Regla de lectura a distancia (Config/Paleta): el color del cuerpo es el del
	material; los detalles son tonos del mismo color (Paleta.escalar).
	Pivote de cada modelo en el suelo bajo el centro.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))
local Primitivas = require(Shared:WaitForChild("Utilidades"):WaitForChild("Primitivas"))

local cuna, cilindroVertical, cilindroHorizontal, esfera, bloque, semilla, nuevoModelo, pivoteEnSuelo =
	Primitivas.cuna, Primitivas.cilindroVertical, Primitivas.cilindroHorizontal, Primitivas.esfera, Primitivas.bloque, Primitivas.semilla, Primitivas.nuevoModelo, Primitivas.pivoteEnSuelo

local ModelosObjetos = {}

-- ===========================================================================
-- Basura real
-- ===========================================================================
--
-- Cuatro formas por material elegidas al azar: sobre la colina se ven latas,
-- llantas, cajas de carton, botellas, cascaras... (peticion del usuario: los
-- bloques de colores del lote 3 no eran "basura de verdad"). El cuerpo lleva
-- el color del material (regla de la paleta: color = set) y los detalles
-- tonos del mismo color, para que a distancia siga leyendose de que set es.
-- Pivote en el suelo bajo el centro; miden 1.2-2.4 studs.

type FormaBasura = (color: Color3, m: Model, rng: Random) -> BasePart

local FORMAS_BASURA: { [string]: { { nombre: string, construir: FormaBasura } } } = {
	Metal = {
		{ nombre = "Lata", construir = function(color, m, rng)
			local cf = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			local c = cilindroHorizontal("Cuerpo", 1.0, 1.6, cf, color, m)
			local oscuro = Paleta.escalar(color, 0.7)
			cilindroHorizontal("Aro1", 1.08, 0.14, cf * CFrame.new(0, 0, 0.74), oscuro, m)
			cilindroHorizontal("Aro2", 1.08, 0.14, cf * CFrame.new(0, 0, -0.74), oscuro, m)
			return c
		end },
		{ nombre = "Llanta", construir = function(color, m, rng)
			local cf = CFrame.new(0, 0.45, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, 0)
			local c = cilindroVertical("Cuerpo", 2.0, 0.75, cf, Paleta.escalar(color, 0.55), m)
			cilindroVertical("Cubo", 1.0, 0.81, cf, Paleta.escalar(color, 1.2), m)
			return c
		end },
		{ nombre = "Barril", construir = function(color, m, rng)
			local cf = CFrame.new(0, 1.0, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, 0)
			local c = cilindroVertical("Cuerpo", 1.4, 2.0, cf, color, m)
			local oscuro = Paleta.escalar(color, 0.7)
			cilindroVertical("Aro1", 1.5, 0.12, cf * CFrame.new(0, 0.45, 0), oscuro, m)
			cilindroVertical("Aro2", 1.5, 0.12, cf * CFrame.new(0, -0.45, 0), oscuro, m)
			return c
		end },
		{ nombre = "Tubo", construir = function(color, m, rng)
			local cf = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			local c = cilindroHorizontal("Cuerpo", 0.6, 2.6, cf, color, m)
			cilindroHorizontal("Brida", 0.9, 0.2, cf * CFrame.new(0, 0, 1.2), Paleta.escalar(color, 0.7), m)
			return c
		end },
	},
	Plastico = {
		{ nombre = "Botella", construir = function(color, m, rng)
			-- tumbada: el eje de la botella queda casi horizontal
			local cf = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(math.rad(85), 0, 0)
			local c = cilindroVertical("Cuerpo", 0.8, 1.5, cf, color, m)
			cilindroVertical("Cuello", 0.4, 0.35, cf * CFrame.new(0, 0.92, 0), color, m)
			cilindroVertical("Tapon", 0.46, 0.22, cf * CFrame.new(0, 1.2, 0), Paleta.escalar(color, 1.45), m)
			return c
		end },
		{ nombre = "Bidon", construir = function(color, m, rng)
			local cf = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			local c = bloque("Cuerpo", Vector3.new(1.2, 1.6, 0.9), cf, color, m)
			bloque("Asa", Vector3.new(0.7, 0.22, 0.22), cf * CFrame.new(0.15, 0.85, 0), Paleta.escalar(color, 0.8), m)
			cilindroVertical("Tapon", 0.42, 0.24, cf * CFrame.new(-0.35, 0.92, 0), Paleta.escalar(color, 1.45), m)
			return c
		end },
		{ nombre = "BolsaPlastico", construir = function(color, m, rng)
			local claro = Paleta.escalar(color, 1.25)
			local c = esfera("Cuerpo", 1.3, CFrame.new(0, 0.6, 0), claro, m)
			cilindroVertical("Nudo", 0.4, 0.3, CFrame.new(0, 1.3, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)), Paleta.escalar(color, 1.5), m)
			return c
		end },
		{ nombre = "Cubo", construir = function(color, m, rng)
			local cf = CFrame.new(0, 0.6, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, 0)
			local c = cilindroVertical("Cuerpo", 1.3, 1.2, cf, color, m)
			cilindroVertical("Borde", 1.42, 0.12, cf * CFrame.new(0, 0.56, 0), Paleta.escalar(color, 1.3), m)
			cilindroVertical("Interior", 1.1, 0.1, cf * CFrame.new(0, 0.6, 0), Paleta.escalar(color, 0.45), m) -- asoma sobre el borde
			return c
		end },
	},
	Papel = {
		{ nombre = "CajaCarton", construir = function(color, m, rng)
			local cf = CFrame.new(0, 0.65, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			local c = bloque("Cuerpo", Vector3.new(1.8, 1.3, 1.5), cf, color, m)
			-- la "boca" es una lamina oscura que asoma por encima de la tapa (las
			-- primitivas son macizas: dentro no se veria)
			bloque("Interior", Vector3.new(1.6, 0.1, 1.3), cf * CFrame.new(0, 0.66, 0), Paleta.escalar(color, 0.45), m)
			-- solapas abiertas, con bisagra en los bordes superiores
			local solapa = Paleta.escalar(color, 0.9)
			bloque("Solapa1", Vector3.new(0.9, 0.08, 1.5), cf * CFrame.new(0.9, 0.65, 0) * CFrame.Angles(0, 0, -math.rad(60)) * CFrame.new(-0.45, 0, 0), solapa, m)
			bloque("Solapa2", Vector3.new(0.9, 0.08, 1.5), cf * CFrame.new(-0.9, 0.65, 0) * CFrame.Angles(0, 0, math.rad(60)) * CFrame.new(0.45, 0, 0), solapa, m)
			return c
		end },
		{ nombre = "Periodico", construir = function(color, m, rng)
			local yaw = rng:NextNumber(0, math.pi)
			local c = bloque("Cuerpo", Vector3.new(1.4, 0.12, 1.0), CFrame.new(0, 0.06, 0) * CFrame.Angles(0, yaw, 0), color, m)
			bloque("Hoja2", Vector3.new(1.4, 0.12, 1.0), CFrame.new(0.1, 0.18, 0.05) * CFrame.Angles(0, yaw + 0.25, 0), Paleta.escalar(color, 1.12), m)
			bloque("Hoja3", Vector3.new(1.3, 0.12, 0.95), CFrame.new(-0.05, 0.3, -0.05) * CFrame.Angles(0, yaw - 0.2, 0), Paleta.escalar(color, 0.95), m)
			bloque("Titular", Vector3.new(0.9, 0.02, 0.18), CFrame.new(-0.05, 0.37, -0.35) * CFrame.Angles(0, yaw - 0.2, 0), Paleta.escalar(color, 0.5), m)
			return c
		end },
		{ nombre = "HojaArrugada", construir = function(color, m, rng)
			local claro = Paleta.escalar(color, 1.12)
			local c = esfera("Cuerpo", 0.95, CFrame.new(0, 0.47, 0), claro, m)
			bloque("Pico1", Vector3.new(0.35, 0.3, 0.25), CFrame.new(0.4, 0.55, 0.1) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 1), 0), claro, m)
			bloque("Pico2", Vector3.new(0.3, 0.35, 0.25), CFrame.new(-0.3, 0.7, -0.2) * CFrame.Angles(rng:NextNumber(0, 1), 0, rng:NextNumber(0, 1)), Paleta.escalar(color, 1.2), m)
			return c
		end },
		{ nombre = "Paquete", construir = function(color, m, rng)
			local cf = CFrame.new(0, 0.4, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			local c = bloque("Cuerpo", Vector3.new(1.0, 0.8, 1.2), cf, color, m)
			local cinta = Paleta.escalar(color, 0.65)
			bloque("Cinta1", Vector3.new(1.03, 0.83, 0.25), cf, cinta, m)
			bloque("Cinta2", Vector3.new(0.25, 0.83, 1.23), cf, cinta, m)
			return c
		end },
	},
	Organico = {
		{ nombre = "Manzana", construir = function(color, m, rng)
			local yaw = rng:NextNumber(0, math.pi * 2)
			local c = esfera("Cuerpo", 0.9, CFrame.new(0, 0.45, 0), color, m)
			cilindroVertical("Rabo", 0.1, 0.3, CFrame.new(0, 1.0, 0), Paleta.escalar(color, 0.5), m)
			cuna({ Nombre = "Hoja", Size = Vector3.new(0.4, 0.14, 0.3), CFrame = CFrame.new(0.2, 0.98, 0) * CFrame.Angles(0, yaw, 0), Color = Paleta.escalar(color, 1.3), Parent = m })
			cilindroHorizontal("Mordida", 0.5, 0.06, CFrame.new(0, 0.5, 0) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, 0.42), Paleta.escalar(color, 1.6), m)
			return c
		end },
		{ nombre = "Platano", construir = function(color, m, rng)
			local amarillo = Paleta.escalar(color, 1.45)
			local base = rng:NextNumber(0, math.pi * 2)
			local c = esfera("Cuerpo", 0.45, CFrame.new(0, 0.25, 0), Paleta.escalar(color, 0.6), m)
			for i = 1, 3 do
				local ang = base + (i / 3) * math.pi * 2
				cuna({ Nombre = "Cascara" .. i, Size = Vector3.new(0.35, 0.45, 1.2), CFrame = CFrame.Angles(0, ang, 0) * CFrame.new(0, 0.22, 0.6) * CFrame.Angles(-math.rad(30), 0, 0), Color = amarillo, Parent = m })
			end
			return c
		end },
		{ nombre = "Hueso", construir = function(color, m, rng)
			local hueso = Paleta.escalar(color, 1.7)
			local cf = CFrame.new(0, 0.28, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			local c = cilindroHorizontal("Cuerpo", 0.35, 1.4, cf, hueso, m)
			esfera("Punta1", 0.55, cf * CFrame.new(0, 0, 0.7), hueso, m)
			esfera("Punta2", 0.55, cf * CFrame.new(0, 0, -0.7), hueso, m)
			return c
		end },
		{ nombre = "Hojas", construir = function(color, m, rng)
			local yaw = rng:NextNumber(0, math.pi)
			local c = cuna({ Nombre = "Cuerpo", Size = Vector3.new(0.9, 0.12, 1.1), CFrame = CFrame.new(0, 0.06, 0) * CFrame.Angles(0, yaw, 0), Color = color, Parent = m })
			cuna({ Nombre = "Hoja2", Size = Vector3.new(0.8, 0.12, 1.0), CFrame = CFrame.new(0.3, 0.16, 0.2) * CFrame.Angles(0, yaw + 1.9, 0), Color = Paleta.escalar(color, 1.2), Parent = m })
			cuna({ Nombre = "Hoja3", Size = Vector3.new(0.7, 0.12, 0.9), CFrame = CFrame.new(-0.25, 0.26, -0.15) * CFrame.Angles(0, yaw + 3.9, 0), Color = Paleta.escalar(color, 0.85), Parent = m })
			return c
		end },
	},
}

local rngBasura = Random.new()
local ESCALA_BASURA = 1.35

-- Material de Roblox con el que se ve cada tipo de basura (pasada de color:
-- latas metalicas, botellas de plastico brillante, carton, restos mate)
local MATERIAL_BASURA = {
	Metal = Enum.Material.Metal,
	Plastico = Enum.Material.SmoothPlastic,
	Papel = Enum.Material.Cardboard,
	Organico = Enum.Material.SmoothPlastic,
}

-- Mallas low-poly modeladas en Blender (ReplicatedStorage.Arte.Basura, un
-- MeshPart "Basura_<Material>_<Forma>" con atributos Material, Forma y
-- ColorVivo). Viven solo en el place, como Arte.Bolsa, pero en
-- ReplicatedStorage y no en ServerStorage: la cinta de la recicladora
-- construye basura en el cliente. El importador de Roblox ignora los colores
-- de material de Blender: los colores iban en una textura de paleta
-- (assets/modelos/basura/Basura_Paleta.png). Desde el 3 oct la basura es del
-- color de su TIPO (decision del usuario: decide a que contenedor va), asi
-- que al clonar se le quita la textura y toma un tono de Paleta.BASURA, como
-- las primitivas. TextureID se puede escribir en runtime (medido en Studio).
-- Las rarezas (Material = "Rareza") no son un set: salen de vez en cuando
-- dentro del material que dice RAREZA_EN.
local RAREZA_EN = { Televisor = "Metal", PatoGoma = "Plastico" }
local PROB_RAREZA = 0.04
local TAMANO_MALLA = 1.6 -- lado mayor antes de ESCALA_BASURA (las formas de primitivas miden 1.2-2.4)

-- Uno de los tonos del color del tipo de basura (Paleta.BASURA)
function ModelosObjetos.tonoBasura(material: string, r: Random): Color3
	local tonos = Paleta.BASURA[material]
	if not tonos then
		return Paleta.MATERIAL[material] or Paleta.MUEBLE
	end
	return tonos[r:NextInteger(1, #tonos)]
end

local function mallasBasura(material: string): ({ MeshPart }, { MeshPart })
	local comunes, rarezas = {}, {}
	local arte = ReplicatedStorage:FindFirstChild("Arte")
	local carpeta = arte and arte:FindFirstChild("Basura")
	if not carpeta then
		return comunes, rarezas
	end
	for _, p in carpeta:GetChildren() do
		if p:IsA("MeshPart") then
			local mat = p:GetAttribute("Material")
			if mat == material then
				table.insert(comunes, p)
			elseif mat == "Rareza" and RAREZA_EN[p:GetAttribute("Forma") :: string] == material then
				table.insert(rarezas, p)
			end
		end
	end
	return comunes, rarezas
end

local function basuraDeMalla(material: string, r: Random): Model?
	local comunes, rarezas = mallasBasura(material)
	if #comunes == 0 then
		return nil
	end
	local lista = if #rarezas > 0 and r:NextNumber() < PROB_RAREZA then rarezas else comunes
	local malla = lista[r:NextInteger(1, #lista)]
	local forma = malla:GetAttribute("Forma") :: string
	local m = nuevoModelo("Basura_" .. forma)
	m:SetAttribute("Forma", forma)
	local c = malla:Clone()
	c.Name = "Cuerpo"
	for _, a in { "Material", "Forma", "ColorVivo" } do
		c:SetAttribute(a, nil)
	end
	local mayor = math.max(c.Size.X, c.Size.Y, c.Size.Z)
	c.Size *= TAMANO_MALLA / mayor
	c.CFrame = CFrame.new(0, c.Size.Y / 2, 0) * CFrame.Angles(0, r:NextNumber(0, math.pi * 2), 0)
	c.TextureID = ""
	local apariencia = c:FindFirstChildOfClass("SurfaceAppearance")
	if apariencia then
		apariencia:Destroy()
	end
	c.Color = ModelosObjetos.tonoBasura(material, r)
	c.Material = MATERIAL_BASURA[material] or Enum.Material.SmoothPlastic
	c.CastShadow = false
	c.Parent = m
	m.PrimaryPart = c
	pivoteEnSuelo(m)
	m:ScaleTo(ESCALA_BASURA)
	return m
end

-- Una pieza de basura de un material, con forma al azar (rng opcional para
-- pruebas deterministas). Atributo Forma = nombre de la forma. Usa las
-- mallas de Arte.Basura si el place las tiene; si no, las formas de
-- primitivas de arriba. El color es uno de los tonos del de su tipo
-- (Paleta.BASURA), sea malla o primitivas, y el material de Roblox el de su
-- tipo (latas de Metal, carton de Cardboard).
function ModelosObjetos.basura(material: string, rng: Random?): Model
	local r = rng or rngBasura
	local deMalla = basuraDeMalla(material, r)
	if deMalla then
		return deMalla
	end
	local formas = FORMAS_BASURA[material] or FORMAS_BASURA.Papel
	local forma = formas[r:NextInteger(1, #formas)]
	local m = nuevoModelo("Basura_" .. forma.nombre)
	m:SetAttribute("Forma", forma.nombre)
	local c = forma.construir(ModelosObjetos.tonoBasura(material, r), m, r)
	local materialRoblox = MATERIAL_BASURA[material] or Enum.Material.SmoothPlastic
	for _, parte in m:GetDescendants() do
		if parte:IsA("BasePart") then
			parte.Material = materialRoblox
			-- Son cientos de piezas pequenas: sin sombra propia (la montana y el
			-- suelo ya dan la lectura). Colision y masa en todas las partes: ver
			-- FisicaBasura.darFisica para por que no se dejo solo el Cuerpo
			parte.CastShadow = false
		end
	end
	m.PrimaryPart = c
	pivoteEnSuelo(m)
	-- Un poco mas grandes que a escala real: sobre la colina, 14-44 piezas de
	-- 1-2 studs se veian escasas (la superficie es grande)
	m:ScaleTo(ESCALA_BASURA)
	return m
end

-- Brillo de lo valioso (peticion del usuario, 6 oct: tesoros y billetes
-- "parecian simple plastico"): destellos que suben alrededor y, en el
-- tesoro, una luz dorada que lo ilumina desde dentro. Va en el propio
-- modelo (lo construye el servidor y replica solo). El efecto de
-- recogerlos esta en EfectoRecogida.client.
local DESTELLO = "rbxasset://textures/particles/sparkles_main.dds"

local function destellos(parte: BasePart, color: Color3, cuantos: number, tamano: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Brillo"
	e.Texture = DESTELLO
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = cuantos
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(0.4, 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, tamano), NumberSequenceKeypoint.new(1, 0) })
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Parent = parte
end

function ModelosObjetos.billete(): Model
	local m = nuevoModelo("Billete")
	local c = bloque("Cuerpo", Vector3.new(1.3, 0.06, 0.65), CFrame.new(0, 0.05, 0) * CFrame.Angles(0, math.rad(20), 0), Paleta.BILLETE, m)
	bloque("Sello", Vector3.new(0.4, 0.07, 0.4), c.CFrame * CFrame.new(0, 0.01, 0), Paleta.escalar(Paleta.BILLETE, 0.75), m)
	-- Destello verde suave, sin luz: hay muchos billetes en una montana
	destellos(c, Paleta.UI_DINERO, 2.5, 0.35)
	m.PrimaryPart = c
	pivoteEnSuelo(m)
	return m
end

function ModelosObjetos.tesoro(): Model
	local m = nuevoModelo("Tesoro")
	local c = bloque("Cuerpo", Vector3.new(1.1, 0.8, 0.8), CFrame.new(0, 0.4, 0), Paleta.TESORO, m)
	local tapa = bloque("Tapa", Vector3.new(1.15, 0.2, 0.85), CFrame.new(0, 0.9, 0), Paleta.escalar(Paleta.TESORO, 0.8), m)
	bloque("Cierre", Vector3.new(0.2, 0.3, 0.1), CFrame.new(0, 0.75, -0.42), Paleta.DORADO, m)
	-- Metalico y brillante, no plastico (violeta desde el 7 oct: el dorado se
	-- confundia con la basura de plastico)
	c.Material = Enum.Material.Foil
	tapa.Material = Enum.Material.Foil
	c.Reflectance = 0.15
	tapa.Reflectance = 0.15
	local luz = Instance.new("PointLight")
	luz.Name = "Aura"
	luz.Color = Paleta.TESORO
	luz.Range = 7
	luz.Brightness = 2
	luz.Shadows = false
	luz.Parent = c
	destellos(c, Paleta.TESORO, 7, 0.6)
	m.PrimaryPart = c
	pivoteEnSuelo(m)
	return m
end

function ModelosObjetos.figurina(def: DefinicionesColeccionables.Figurina): Model
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
	pivoteEnSuelo(m)
	return m
end

function ModelosObjetos.cinta(def: DefinicionesColeccionables.Cinta): Model
	local m = nuevoModelo(def.nombre)
	m:SetAttribute("CintaId", def.id)
	local c = bloque("Cuerpo", Vector3.new(1.1, 0.2, 0.7), CFrame.new(0, 0.1, 0), Paleta.CINTA, m)
	for _, dx in { -0.28, 0.28 } do
		cilindroVertical("Carrete", 0.3, 0.22, CFrame.new(dx, 0.11, 0), Paleta.gris(200), m)
	end
	m.PrimaryPart = c
	pivoteEnSuelo(m)
	return m
end

-- Pliegues y bultos de una bolsa de basura: bolas pequenas medio metidas en
-- el cuerpo (lo que hay dentro marca la bolsa) y un tono por bulto para que
-- no se lea como una sola bola lisa. rng con semilla fija: la misma bolsa
-- siempre tiene los mismos bultos.
local function bultosBolsa(m: Model, d: number, centroY: number, cuantos: number, rng: Random)
	for i = 1, cuantos do
		local ang = (i / cuantos) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local alt = rng:NextNumber(-0.35, 0.3) -- fraccion de d, desde el centro
		local radio = d * 0.5 * math.sqrt(math.max(0.1, 1 - (alt * 2) ^ 2)) -- sobre la superficie de la bola
		local db = d * rng:NextNumber(0.3, 0.5)
		local cf = CFrame.new(math.cos(ang) * radio * 0.85, centroY + alt * d, math.sin(ang) * radio * 0.85)
		local b = esfera("Bulto" .. i, db, cf, Paleta.escalar(Paleta.BOLSA, 0.9 + rng:NextNumber(0, 0.3)), m)
		b.Material = Enum.Material.SmoothPlastic
	end
end

-- Mallas de la bolsa modeladas en Blender (assets/3d/Bolsa.fbx y
-- BolsaAbierta.fbx, importadas como ServerStorage.Arte.Bolsa y
-- .BolsaAbierta: un Model con un MeshPart por color). El mismo saco azul
-- facetado en dos estados: cerrada con nudo (Cuerpo, Nudo y el Cincho
-- amarillo del atado, Paleta.CINCHO_BOLSA) y abierta
-- (Cuerpo, Boca, Interior). Viven solo en el place; sin ellas se construye
-- con partes. Solo el servidor construye bolsas (Lanzamiento, ObjetosPatio,
-- Patio) y el clon replica con su MeshId: en el cliente no se buscan.
--
-- El importador de Roblox pierde los colores de Blender: cada parte se
-- pinta por su nombre con un tono de Paleta.BOLSA, y el factor queda en el
-- atributo Tono para que vestirBolsa conserve el claroscuro con otro color.
-- La escala se calcula del alto real del clon (no se fia de la escala con
-- la que importe Studio): ALTO_MALLA_BOLSA es lo que mide al 100 %.
-- La abierta es un saco casi recto y arrugado, abierto de par en par: la
-- Boca es solo el canto fino del plastico (un borde grueso parecia jarra).
local ALTO_MALLA_BOLSA: { [string]: number } = { Bolsa = 3.6, BolsaAbierta = 2.6 }
local TONO_BOLSA: { [string]: number } = { Cuerpo = 1, Nudo = 1, Boca = 1.12, Interior = 0.5 }

local function mallaBolsa(nombre: string): Model?
	if not RunService:IsServer() then
		return nil
	end
	local arte = ServerStorage:FindFirstChild("Arte")
	local b = arte and arte:FindFirstChild(nombre)
	return if b and b:IsA("Model") and b:FindFirstChild("Cuerpo") then b else nil
end

-- Clon de una malla de bolsa pintado, escalado a `escala` de su alto de
-- diseno y con el pivote en el suelo bajo el centro
local function clonarMallaBolsa(original: Model, nombre: string, escala: number): Model
	local m = original:Clone()
	m.Name = nombre
	m.PrimaryPart = nil
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			if p:IsA("MeshPart") then
				p.TextureID = ""
			end
			local apariencia = p:FindFirstChildOfClass("SurfaceAppearance")
			if apariencia then
				apariencia:Destroy()
			end
			if p.Name == "Cincho" then
				-- Sin Tono: vestirBolsa no lo repinta
				p.Color = Paleta.CINCHO_BOLSA
			else
				local tono = TONO_BOLSA[p.Name] or 1
				p:SetAttribute("Tono", tono)
				p.Color = Paleta.escalar(Paleta.BOLSA, tono)
			end
			p.Material = Enum.Material.SmoothPlastic
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = true
			p.CastShadow = false
		end
	end
	m:ScaleTo(m:GetScale() * ALTO_MALLA_BOLSA[original.Name] * escala / m:GetExtentsSize().Y)
	-- Base de la caja envolvente en el origen: pivoteEnSuelo cuenta con ello
	local cf, size = m:GetBoundingBox()
	m:TranslateBy(Vector3.new(-cf.X, size.Y / 2 - cf.Y, -cf.Z))
	m.PrimaryPart = m:FindFirstChild("Cuerpo") :: BasePart
	pivoteEnSuelo(m)
	return m
end

-- La bolsa de basura cerrada (con nudo): proyectil y objeto caido. fraccion
-- 0..1 de llenado escala el tamano. Con malla: la de Blender, saco ancho
-- atado arriba con pliegues hacia el nudo (al 100 % mide ~2,7 x 3,6). Sin
-- malla: saco abombado con bultos, base achatada (apoya, no
-- rueda), cuello fruncido y las dos orejas del nudo.
function ModelosObjetos.bolsaLlena(fraccion: number): Model
	local malla = mallaBolsa("Bolsa")
	if malla then
		return clonarMallaBolsa(malla, "Bolsa", 0.55 + 0.32 * math.clamp(fraccion, 0, 1))
	end
	local m = nuevoModelo("Bolsa")
	local rng = semilla("bolsa" .. tostring(math.floor(fraccion * 10)))
	local d = 1.5 * (0.8 + 0.6 * math.clamp(fraccion, 0, 1))
	local claro = Paleta.escalar(Paleta.BOLSA, 1.3)
	-- Cuerpo: bola con una base ancha y plana debajo (la bolsa se aplasta
	-- contra el suelo) y un segundo abombado un poco mas arriba
	local c = esfera("Cuerpo", d, CFrame.new(0, d * 0.48, 0), Paleta.BOLSA, m)
	cilindroVertical("Base", d * 0.9, d * 0.22, CFrame.new(0, d * 0.11, 0), Paleta.escalar(Paleta.BOLSA, 0.85), m)
	esfera("Panza", d * 0.8, CFrame.new(d * 0.08, d * 0.7, -d * 0.05), Paleta.escalar(Paleta.BOLSA, 1.08), m)
	bultosBolsa(m, d, d * 0.48, 5, rng)
	-- Cuello fruncido y nudo
	local cuelloY = d * 1.02
	cilindroVertical("Cuello", d * 0.3, d * 0.2, CFrame.new(0, cuelloY, 0), Paleta.escalar(Paleta.BOLSA, 0.8), m)
	esfera("Nudo", d * 0.28, CFrame.new(0, cuelloY + d * 0.14, 0), claro, m)
	-- Las dos orejas del nudo, abiertas en V
	for i, lado in { -1, 1 } do
		cuna({
			Nombre = "Oreja" .. i,
			Size = Vector3.new(d * 0.14, d * 0.32, d * 0.24),
			CFrame = CFrame.new(lado * d * 0.16, cuelloY + d * 0.3, 0) * CFrame.Angles(0, 0, lado * math.rad(-40)) * CFrame.Angles(math.rad(180), 0, 0),
			Color = claro,
			Parent = m,
		})
	end
	m.PrimaryPart = c
	pivoteEnSuelo(m)
	return m
end

-- Pinta una bolsa (cerrada o abierta) con un diseno de bolsa
-- (DefinicionesCosmeticos.BOLSAS: color y material). Mantiene el claroscuro
-- de cada parte respecto al azul de siempre (atributo Tono en las mallas,
-- el brillo en las partes). El agujero gris de la bolsa de partes y el
-- cincho amarillo de la malla no se tocan; el Interior de la malla es el
-- mismo plastico por dentro y si.
function ModelosObjetos.vestirBolsa(modelo: Model, diseno: { color: Color3, material: Enum.Material }?)
	if not diseno then
		return
	end
	local _, _, brilloBase = Paleta.BOLSA:ToHSV()
	for _, p in modelo:GetDescendants() do
		local tono = p:GetAttribute("Tono")
		if p:IsA("BasePart") and p.Name ~= "Cincho" and (p.Name ~= "Interior" or tono ~= nil) then
			local _, _, brillo = p.Color:ToHSV()
			local factor = if typeof(tono) == "number" then tono elseif brilloBase > 0 then brillo / brilloBase else 1
			if p:IsA("MeshPart") then
				p.TextureID = ""
			end
			p.Color = Paleta.escalar(diseno.color, math.clamp(factor, 0.5, 1.4))
			p.Material = diseno.material
		end
	end
end

-- Estela de una bolsa lanzada (DefinicionesCosmeticos.ESTELAS): un Trail
-- entre dos attachments que cruzan la bolsa
function ModelosObjetos.estelaBolsa(modelo: Model, estela: { colores: ColorSequence }?)
	local cuerpo = modelo.PrimaryPart
	if not estela or not cuerpo then
		return
	end
	local mitad = cuerpo.Size.Y * 0.35
	local a0 = Instance.new("Attachment")
	a0.Name = "Estela0"
	a0.Position = Vector3.new(0, mitad, 0)
	a0.Parent = cuerpo
	local a1 = Instance.new("Attachment")
	a1.Name = "Estela1"
	a1.Position = Vector3.new(0, -mitad, 0)
	a1.Parent = cuerpo
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = estela.colores
	trail.Lifetime = 0.6
	trail.LightEmission = 0.4
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = cuerpo
end

-- La bolsa que se lleva en las manos dentro del patio, crece con el
-- llenado. Abierta (boca con interior oscuro: "bolsa en la que cae la
-- basura") mientras cabe algo; llena, cerrada y atada, como el dibujo
-- de primera persona (Manos.client). Pivote en el fondo del saco. Devuelve
-- (modelo, altura total): Patio la cuelga de las manos por arriba.
function ModelosObjetos.bolsaAbierta(fraccion: number): (Model, number)
	local f = math.clamp(fraccion, 0, 1)
	local cerrada = if f >= 1 then mallaBolsa("Bolsa") else nil
	local abierta = if cerrada then nil else mallaBolsa("BolsaAbierta")
	if cerrada or abierta then
		-- La cerrada mide mas por el nudo: x0,81 para que el saco no cambie
		-- de ancho al atarla (medido sobre las dos mallas de Blender)
		local escala = 0.85 + 0.35 * f
		local m = if cerrada
			then clonarMallaBolsa(cerrada, "BolsaAbierta", escala * 0.81)
			else clonarMallaBolsa(abierta :: Model, "BolsaAbierta", escala)
		return m, m:GetExtentsSize().Y
	end
	local m = nuevoModelo("BolsaAbierta")
	-- Ball siempre es una esfera (Roblox iguala los tres ejes): el saco es una
	-- bola y la boca un cilindro que le corta la coronilla.
	local s = 0.85 + 0.35 * math.clamp(fraccion, 0, 1)
	local d = 2.3 * s
	local alto = d * 0.9
	local c = esfera("Cuerpo", d, CFrame.new(0, d / 2, 0), Paleta.BOLSA, m)
	-- Bultos de lo que ya lleva dentro (mas cuantos mas llena)
	bultosBolsa(m, d, d / 2, 2 + math.floor(fraccion * 3), semilla("abierta"))
	local boca = d * 0.8
	cilindroVertical("Boca", boca, 0.24, CFrame.new(0, alto, 0), Paleta.escalar(Paleta.BOLSA, 1.35), m)
	cilindroVertical("Interior", boca * 0.78, 0.1, CFrame.new(0, alto + 0.08, 0), Paleta.gris(28), m)
	m.PrimaryPart = c
	pivoteEnSuelo(m)
	return m, alto
end


return ModelosObjetos
