--!strict
--[[
	ModelosObjetos
	Los modelos whitebox de lo que se recoge y se lleva: basura real (16
	formas, 4 por material), billetes, tesoros, figurinas, cintas, trajes y
	las dos bolsas (cerrada con nudo para lanzar, abierta para las manos).
	Las mascotas y sus fragmentos van en ModelosMascota; la colina de los
	montones en ModelosMonton. Primitivas pone los ladrillos.

	Regla de lectura a distancia (Config/Paleta): el color del cuerpo es el del
	material; los detalles son tonos del mismo color (Paleta.escalar).
	Pivote de cada modelo en el suelo bajo el centro.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- Una pieza de basura de un material, con forma al azar (rng opcional para
-- pruebas deterministas). Atributo Forma = nombre de la forma.
function ModelosObjetos.basura(material: string, rng: Random?): Model
	local formas = FORMAS_BASURA[material] or FORMAS_BASURA.Papel
	local r = rng or rngBasura
	local forma = formas[r:NextInteger(1, #formas)]
	local m = nuevoModelo("Basura_" .. forma.nombre)
	m:SetAttribute("Forma", forma.nombre)
	local color = Paleta.MATERIAL[material] or Paleta.MUEBLE
	local c = forma.construir(color, m, r)
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

-- La bolsa de basura cerrada (con nudo): proyectil y objeto caido. fraccion
-- 0..1 de llenado escala el tamano.
function ModelosObjetos.bolsaLlena(fraccion: number): Model
	local m = nuevoModelo("Bolsa")
	local d = 1.4 * (0.8 + 0.6 * math.clamp(fraccion, 0, 1))
	local c = esfera("Cuerpo", d, CFrame.new(0, d / 2, 0), Paleta.BOLSA, m)
	cilindroVertical("Nudo", d * 0.35, d * 0.3, CFrame.new(0, d + d * 0.1, 0), Paleta.escalar(Paleta.BOLSA, 1.25), m)
	bloque("Asa", Vector3.new(d * 0.5, d * 0.12, d * 0.12), CFrame.new(0, d + d * 0.3, 0), Paleta.escalar(Paleta.BOLSA, 1.25), m)
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
	local boca = d * 0.8
	cilindroVertical("Boca", boca, 0.24, CFrame.new(0, alto, 0), Paleta.escalar(Paleta.BOLSA, 1.35), m)
	cilindroVertical("Interior", boca * 0.78, 0.1, CFrame.new(0, alto + 0.08, 0), Paleta.gris(28), m)
	m.PrimaryPart = c
	pivoteEnSuelo(m)
	return m, alto
end


return ModelosObjetos
