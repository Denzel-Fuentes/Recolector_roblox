--!strict
--[[
	ModelosObjetos
	Los modelos whitebox de lo que se recoge y se lleva: basura real (mallas
	low-poly de ReplicatedStorage.Arte.Basura si el place las tiene; si no,
	16 formas de primitivas, 4 por material), billetes, tesoros, fragmentos
	de mascota, figurinas, cintas, trajes y
	las dos bolsas (cerrada con nudo para lanzar, que usa la malla IA
	ServerStorage.Arte.Bolsa si el place la tiene; abierta para las manos).
	Las mascotas van en ModelosMascota; la colina de los
	montones en ModelosMonton. Primitivas pone los ladrillos.

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
-- de material de Blender: los colores van en una textura de paleta
-- (assets/modelos/basura/Basura_Paleta.png, cada cara mapeada a su cuadro).
-- Sin textura la malla es de un solo color y las de ColorVivo toman uno de
-- Paleta.BASURA como las primitivas.
-- Las rarezas (Material = "Rareza") no son un set: salen de vez en cuando
-- dentro del material que dice RAREZA_EN.
local RAREZA_EN = { Televisor = "Metal", PatoGoma = "Plastico" }
local PROB_RAREZA = 0.04
local TAMANO_MALLA = 1.6 -- lado mayor antes de ESCALA_BASURA (las formas de primitivas miden 1.2-2.4)

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
	local vivos = Paleta.BASURA[material]
	-- Con textura de paleta los colores ya vienen en la malla (y Color no se ve)
	local texturizada = c.TextureID ~= "" or c:FindFirstChildOfClass("SurfaceAppearance") ~= nil
	if malla:GetAttribute("ColorVivo") and vivos and not texturizada then
		c.Color = vivos[r:NextInteger(1, #vivos)]
	end
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
-- primitivas de arriba. Con primitivas el color es uno vivo de
-- Paleta.BASURA (latas rojas y azules, botellas cian...), como la montana
-- de la referencia; el material del set sigue en el atributo y en la
-- bolsa/album.
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
	local vivos = Paleta.BASURA[material]
	local color = if vivos then vivos[r:NextInteger(1, #vivos)] else (Paleta.MATERIAL[material] or Paleta.MUEBLE)
	local c = forma.construir(color, m, r)
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
	if forma.nombre == "Llanta" then
		-- Los neumaticos son de goma negra, no del color de la lata
		c.Material = Enum.Material.Rubber
		c.Color = Paleta.MUNDO.GOMA
	end
	m.PrimaryPart = c
	pivoteEnSuelo(m)
	-- Un poco mas grandes que a escala real: sobre la colina, 14-44 piezas de
	-- 1-2 studs se veian escasas (la superficie es grande)
	m:ScaleTo(ESCALA_BASURA)
	return m
end

function ModelosObjetos.billete(): Model
	local m = nuevoModelo("Billete")
	local c = bloque("Cuerpo", Vector3.new(1.3, 0.06, 0.65), CFrame.new(0, 0.05, 0) * CFrame.Angles(0, math.rad(20), 0), Paleta.BILLETE, m)
	bloque("Sello", Vector3.new(0.4, 0.07, 0.4), c.CFrame * CFrame.new(0, 0.01, 0), Paleta.escalar(Paleta.BILLETE, 0.75), m)
	m.PrimaryPart = c
	pivoteEnSuelo(m)
	return m
end

-- Fragmento de mascota (29 sep): una esquirla del color del set de su
-- material con un rombo de neon encima y luz propia, para que asome entre
-- la basura de la montana (es lo que el jugador busca con la vista).
function ModelosObjetos.fragmento(material: string): Model
	local m = nuevoModelo("Fragmento")
	local color = Paleta.MATERIAL[material] or Paleta.TESORO
	local c = cuna({
		Nombre = "Cuerpo",
		Size = Vector3.new(1.4, 0.9, 1.2),
		CFrame = CFrame.new(0, 0.45, 0),
		Color = color,
		Parent = m,
	})
	bloque("Borde", Vector3.new(1.46, 0.12, 1.26), CFrame.new(0, 0.06, 0), Primitivas.aclarar(color, 0.5), m).Material = Enum.Material.Neon
	local rombo = bloque("Rombo", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 1.25, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Primitivas.aclarar(color, 0.6), m)
	rombo.Material = Enum.Material.Neon
	local luz = Instance.new("PointLight")
	luz.Color = Primitivas.aclarar(color, 0.5)
	luz.Range = 7
	luz.Brightness = 2
	luz.Parent = rombo
	m.PrimaryPart = c
	pivoteEnSuelo(m)
	return m
end

function ModelosObjetos.tesoro(): Model
	local m = nuevoModelo("Tesoro")
	local c = bloque("Cuerpo", Vector3.new(1.1, 0.8, 0.8), CFrame.new(0, 0.4, 0), Paleta.TESORO, m)
	bloque("Tapa", Vector3.new(1.15, 0.2, 0.85), CFrame.new(0, 0.9, 0), Paleta.escalar(Paleta.TESORO, 0.8), m)
	bloque("Cierre", Vector3.new(0.2, 0.3, 0.1), CFrame.new(0, 0.75, -0.42), Paleta.gris(60), m)
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

function ModelosObjetos.traje(def: DefinicionesColeccionables.Traje): Model
	local m = nuevoModelo(def.nombre)
	m:SetAttribute("TrajeId", def.id)
	local c = bloque("Cuerpo", Vector3.new(1.3, 0.25, 1.2), CFrame.new(0, 0.125, 0), def.colorCuerpo, m)
	bloque("Pliegue", Vector3.new(1.3, 0.2, 0.5), CFrame.new(0, 0.35, -0.2), def.colorBrazos, m)
	bloque("Pliegue2", Vector3.new(0.6, 0.15, 1.2), CFrame.new(0.3, 0.32, 0.1), def.colorPiernas, m)
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

-- Malla de la bolsa generada por IA (ServerStorage.Arte.Bolsa: saco
-- facetado low-poly atado con banda amarilla, referencia del usuario). Vive
-- solo en el place, como el camion; sin ella se construye con partes. Solo
-- el servidor construye bolsas (Lanzamiento, ObjetosPatio), y el clon
-- replica con su MeshId, asi que en el cliente no hace falta buscarla.
local function mallaBolsa(): MeshPart?
	if not RunService:IsServer() then
		return nil
	end
	local arte = ServerStorage:FindFirstChild("Arte")
	local b = arte and arte:FindFirstChild("Bolsa")
	return if b and b:IsA("MeshPart") then b else nil
end

-- La bolsa de basura cerrada (con nudo): proyectil y objeto caido. fraccion
-- 0..1 de llenado escala el tamano. Con malla: el saco facetado escalado
-- (al 100 % mide ~2,6 x 3,2). Sin malla: saco abombado con bultos, base
-- achatada (apoya, no rueda), cuello fruncido y las dos orejas del nudo.
function ModelosObjetos.bolsaLlena(fraccion: number): Model
	local m = nuevoModelo("Bolsa")
	local malla = mallaBolsa()
	if malla then
		local c = malla:Clone()
		c.Name = "Cuerpo"
		local s = 0.55 + 0.32 * math.clamp(fraccion, 0, 1)
		c.Size = malla.Size * s
		c.CFrame = CFrame.new(0, c.Size.Y / 2, 0)
		c.Anchored = true
		c.CanCollide = false
		c.CanTouch = false
		c.CanQuery = true
		c.CastShadow = false
		c.Parent = m
		m.PrimaryPart = c
		pivoteEnSuelo(m)
		return m
	end
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

-- La bolsa ABIERTA que se lleva en las manos dentro del patio: un saco que
-- se abomba con el llenado, con la boca abierta arriba (borde claro e
-- interior oscuro) para que se lea como "bolsa en la que cae la basura".
-- Pivote en el fondo del saco. Devuelve (modelo, altura total).
function ModelosObjetos.bolsaAbierta(fraccion: number): (Model, number)
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
