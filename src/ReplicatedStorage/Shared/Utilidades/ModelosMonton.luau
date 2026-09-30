--!strict
--[[
	ModelosMonton
	La MONTANA de un monton sin activar y la geometria que la describe: donde
	esta su superficie y como repartir n puntos por su volumen. Botin la usa
	para colocar la basura al activar; ConstructorMundo no (los montones se
	instancian en runtime sobre las ranuras del mundo).

	Un monton sin activar es una MONTANA DE ESCOMBROS: un monticulo principal
	de cono redondeado (PERFIL) con 2-3 monticulos secundarios por la falda,
	como la referencia del usuario (una pila de escombros y basura, ni bolas
	lisas ni piramides puntiagudas). Cada monticulo es la malla generada por
	IA `ServerStorage.Arte.Monton` estirada a su tamano si el place la tiene
	(vive solo en el place, como el camion) y, si no, capas de cilindro de
	roca con la variante "MontanaBasura" mas bultos por la falda. Al
	activarlo, la montana se SUSTITUYE por una montana de basura real que
	rellena su volumen (puntosEnColina) y cae con fisica
	(Services/FisicaBasura).

	Las partes se llaman "Loma_..." porque Montones y las pruebas las
	reconocen por ese prefijo (era el nombre de las colinas redondas).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Primitivas = require(Shared:WaitForChild("Utilidades"):WaitForChild("Primitivas"))

local bloque, semilla, nuevoModelo, pivoteEnSuelo = Primitivas.bloque, Primitivas.semilla, Primitivas.nuevoModelo, Primitivas.pivoteEnSuelo

local ModelosMonton = {}

-- Exponente del perfil del monticulo: y = h * (1 - d/r) ^ PERFIL. Con 1 seria
-- un cono puntiagudo; 1.6 redondea la cima y ensancha la falda, como una
-- montana de escombros
local PERFIL = 1.6

-- Un pico: monticulo de radio r y altura h, centrado
-- en (cx, cz) y girado ang radianes sobre Y
export type Loma = { cx: number, cz: number, r: number, h: number, ang: number }
export type ParamsColina = { lomas: { Loma }, r: number, h: number }

function ModelosMonton.radioMonton(tamano: string): number
	local def = GameConfig.TAMANOS_MONTON[tamano]
	return if def then def.radio else 9
end

-- Radio y altura de la montana: el radio es el de TAMANOS_MONTON y la altura
-- crece con numPiezas dentro de su rango (mas basura, montana mas alta).
-- Picos secundarios con semilla fija por monton: la misma silueta aunque
-- se reconstruya.
function ModelosMonton.parametrosColina(tamano: string, indice: number?, numPiezas: number): ParamsColina
	local def = GameConfig.TAMANOS_MONTON[tamano] or GameConfig.TAMANOS_MONTON.chico
	local rng = semilla("colina" .. tamano .. tostring(indice or 0))
	local r = def.radio
	local llenado = if def.max > def.min then (numPiezas - def.min) / (def.max - def.min) else 1
	local h = r * (0.8 + 0.35 * math.clamp(llenado, 0, 1))
	local lomas: { Loma } = { { cx = 0, cz = 0, r = r, h = h, ang = rng:NextNumber(0, math.pi / 2) } }
	local secundarias = rng:NextInteger(2, 3)
	for i = 1, secundarias do
		local ang = (i / secundarias) * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
		-- hacia el borde, donde el pico principal ya es bajo: si no quedan dentro
		local dist = r * rng:NextNumber(0.5, 0.75)
		table.insert(lomas, {
			cx = math.cos(ang) * dist,
			cz = math.sin(ang) * dist,
			r = r * rng:NextNumber(0.4, 0.6),
			h = h * rng:NextNumber(0.4, 0.65),
			ang = rng:NextNumber(0, math.pi / 2),
		})
	end
	return { lomas = lomas, r = r, h = h }
end

-- Altura de la superficie de la montana en (x, z) locales; 0 fuera de ella.
-- Cono redondeado (PERFIL) por la distancia al centro de cada pico
function ModelosMonton.alturaColina(params: ParamsColina, x: number, z: number): number
	local y = 0
	for _, l in params.lomas do
		local dx, dz = x - l.cx, z - l.cz
		local d = math.sqrt(dx * dx + dz * dz)
		if d < l.r then
			y = math.max(y, l.h * (1 - d / l.r) ^ PERFIL)
		end
	end
	return y
end

-- n puntos que RELLENAN el volumen de la montana (no solo su superficie): al
-- activar, la montana se sustituye entera por una de basura con el mismo
-- bulto. Muestreo "mejor candidato": para cada punto se prueban varios al
-- azar dentro del volumen y se toma el mas alejado de los ya puestos, asi
-- quedan repartidos sin recuento de vecinos. Cerca de la superficie se
-- aprieta un poco mas (candidatos con y alta se prefieren) para que la capa
-- exterior no deje ver el interior.
function ModelosMonton.puntosEnColina(params: ParamsColina, n: number, rng: Random): { Vector3 }
	local puntos: { Vector3 } = {}
	local r = params.r
	for _ = 1, n do
		local mejor: Vector3? = nil
		local mejorDist = -1
		for _ = 1, 10 do
			local ang = rng:NextNumber(0, math.pi * 2)
			-- mas estrecho que la montana: al caer se desparrama, y apretadas
			-- unas sobre otras se asientan antes que sueltas por el suelo
			local d = math.sqrt(rng:NextNumber(0, 1)) * r * 0.65
			local x, z = math.cos(ang) * d, math.sin(ang) * d
			-- La montana de roca es mas alta de lo que la basura puede apilarse:
			-- las piezas se reparten en el 60 % de su altura, porque cayendo desde
			-- mas de ~8 studs se clavaban en el suelo y tardaban en asentarse
			local techo = ModelosMonton.alturaColina(params, x, z) * 0.6
			if techo > 1.6 then
				-- sesgo hacia arriba: la raiz cuadrada acumula candidatos en la capa exterior
				-- desde 1.2 y no desde el suelo: una pieza larga inclinada con el
				-- pivote a ras se clavaba en el suelo y la fisica no la sacaba
				local y = 1.2 + (techo - 1.4) * math.sqrt(rng:NextNumber(0, 1))
				local candidato = Vector3.new(x, y, z)
				local cercano = math.huge
				for _, otro in puntos do
					cercano = math.min(cercano, (otro - candidato).Magnitude)
				end
				if cercano > mejorDist then
					mejor, mejorDist = candidato, cercano
				end
			end
		end
		table.insert(puntos, mejor or Vector3.new(0, 1.5, 0))
	end
	return puntos
end

-- Malla de montana generada por IA (ServerStorage.Arte.Monton, o
-- workspace.Arte si el hilo del MCP no pudo moverla). nil si no existe:
-- entonces el monticulo se construye con partes.
local function mallaMonton(): MeshPart?
	for _, raiz in { game:GetService("ServerStorage"), workspace } do
		local arte = raiz:FindFirstChild("Arte")
		local m = arte and arte:FindFirstChild("Monton")
		if m then
			if m:IsA("MeshPart") then
				return m
			end
			local hija = m:FindFirstChildWhichIsA("MeshPart", true)
			if hija then
				return hija
			end
		end
	end
	return nil
end

local function preparar(p: BasePart)
	p.Anchored = true
	p.CanCollide = true -- se puede subir
	p.CanQuery = true
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

-- Un pico como monticulo: la malla IA estirada a (2r, h, 2r) si existe;
-- si no, bolas de roca superpuestas que siguen el perfil de cono redondeado
-- (alturaColina). Las partes se llaman
-- "Loma_<nombre>_k" (prefijo que Montones y las pruebas reconocen).
local function monticulo(nombre: string, l: Loma, color: Color3, rng: Random, padre: Instance): BasePart
	local base = CFrame.new(l.cx, 0, l.cz) * CFrame.Angles(0, l.ang, 0)
	local malla = mallaMonton()
	if malla then
		local p = malla:Clone()
		for _, hijo in p:GetChildren() do
			hijo:Destroy()
		end
		p.Name = nombre .. "_0"
		preparar(p)
		p.Size = Vector3.new(l.r * 2, l.h, l.r * 2)
		p.CFrame = base * CFrame.new(0, l.h / 2, 0)
		p.Parent = padre
		return p
	end
	-- Respaldo de partes: un cuerpo grande hundido que da el bulto y un
	-- punado de bolas de tamanos distintos medio enterradas por la falda,
	-- cada una con su tono: superpuestas se leen como una pila de escombros
	-- irregular (las capas de cilindro parecian una tarta de pisos)
	local function bola(k: number, x: number, z: number, diam: number, y: number): BasePart
		local p = Primitivas.esfera(nombre .. "_" .. k, diam, base * CFrame.new(x, y, z), Paleta.escalar(color, 0.85 + rng:NextNumber(0, 0.3)), padre)
		preparar(p)
		Primitivas.materializar(p, Enum.Material.Rock, Paleta.VARIANTES.basura)
		return p
	end
	local cuerpo = l.r * 1.1
	local primera = bola(0, 0, 0, cuerpo, l.h * 0.85 - cuerpo / 2)
	local bultos = math.max(6, math.floor(l.r * 1.1))
	for k = 1, bultos do
		local ang = rng:NextNumber(0, math.pi * 2)
		local d = l.r * rng:NextNumber(0.2, 0.95)
		local x, z = math.cos(ang) * d, math.sin(ang) * d
		local yS = l.h * (1 - d / l.r) ^ PERFIL
		local diam = l.r * rng:NextNumber(0.25, 0.55)
		bola(k, x, z, diam, yS - diam * 0.3)
	end
	-- Cima: bolas medianas apinadas que suben hasta h (sin ellas el cuerpo
	-- redondo se leia como una cupula, no como un pico de escombros)
	for k = 1, 4 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local d = l.r * rng:NextNumber(0, 0.18)
		local diam = l.r * rng:NextNumber(0.4, 0.55)
		bola(bultos + 10 + k, math.cos(ang) * d, math.sin(ang) * d, diam, l.h - diam / 2 - l.r * 0.02 * k)
	end
	-- Piedras pequenas por la cima
	for k = 1, 3 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local d = l.r * rng:NextNumber(0, 0.25)
		local diam = l.r * rng:NextNumber(0.15, 0.25)
		bola(bultos + k, math.cos(ang) * d, math.sin(ang) * d, diam, l.h - diam * 0.2)
	end
	return primera
end

-- `material` tine la colina hacia el color de ese material: el que destaca
-- en las zonas ricas del norte (GameConfig.ZONAS); las del patio abierto,
-- de basura revuelta, no llevan
function ModelosMonton.monton(tamano: string, agotado: boolean, indice: number?, numPiezas: number?, material: string?): Model
	local m = nuevoModelo("Monton")
	local radio = ModelosMonton.radioMonton(tamano)
	if agotado then
		-- Parches de tierra pisada donde estuvo la montana
		local rng = semilla("resto" .. tamano .. tostring(indice or 0))
		local c = bloque("Resto", Vector3.new(radio * 1.6, 0.4, radio * 1.4), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Paleta.MUNDO.TIERRA, m)
		local c2 = bloque("Resto2", Vector3.new(radio * 1.0, 0.3, radio * 0.9), CFrame.new(radio * 0.3, 0.15, -radio * 0.2) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Paleta.MUNDO.TIERRA_OSCURA, m)
		Primitivas.materializar(c, Enum.Material.Ground, Paleta.VARIANTES.tierra)
		Primitivas.materializar(c2, Enum.Material.Ground, Paleta.VARIANTES.tierra)
		m.PrimaryPart = c
		pivoteEnSuelo(m)
		return m
	end
	local n = numPiezas or GameConfig.TAMANOS_MONTON[tamano].min
	local params = ModelosMonton.parametrosColina(tamano, indice, n)
	-- Cada pico con un tono distinto del azul-gris de bolsas para que no se
	-- lea como un solo bloque
	local rngColor = semilla("color" .. tamano .. tostring(indice or 0))
	local colorBase = Paleta.MONTON_BASURA
	local colorMaterial = material and Paleta.MATERIAL[material]
	if colorMaterial then
		colorBase = colorBase:Lerp(colorMaterial, 0.5)
	end
	local principal: BasePart? = nil
	for i, l in params.lomas do
		local tono = 0.85 + rngColor:NextNumber(0, 0.3)
		local p = monticulo("Loma_" .. i, l, Paleta.escalar(colorBase, tono), rngColor, m)
		if i == 1 then
			principal = p
		end
	end
	m.PrimaryPart = principal
	pivoteEnSuelo(m)
	return m
end

return ModelosMonton
