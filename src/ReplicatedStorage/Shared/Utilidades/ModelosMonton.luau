--!strict
--[[
	ModelosMonton
	La COLINA de un monton sin activar y la geometria que la describe: donde
	esta su superficie y como repartir n puntos por su volumen. Botin la usa
	para colocar la basura al activar; ConstructorMundo no (los montones se
	instancian en runtime sobre las ranuras del mundo).

	Un monton sin activar es una colina lisa (peticion del usuario: despues le
	pondra una textura de basura; con primitivas son bolas hundidas en el
	suelo, cuando quiera textura tendra que ser un MeshPart). Al activarlo, la
	colina se SUSTITUYE por una montana de basura real que rellena su mismo
	volumen (puntosEnColina) y cae con fisica (Services/FisicaBasura).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Primitivas = require(Shared:WaitForChild("Utilidades"):WaitForChild("Primitivas"))

local bloque, esfera, semilla, nuevoModelo, pivoteEnSuelo = Primitivas.bloque, Primitivas.esfera, Primitivas.semilla, Primitivas.nuevoModelo, Primitivas.pivoteEnSuelo

local ModelosMonton = {}

export type Loma = { cx: number, cz: number, R: number, cy: number }
export type ParamsColina = { lomas: { Loma }, r: number, h: number }

function ModelosMonton.radioMonton(tamano: string): number
	local def = GameConfig.TAMANOS_MONTON[tamano]
	return if def then def.radio else 7
end

-- Casquete de una bola hundida que asoma con radio r y altura h en el suelo
local function loma(cx: number, cz: number, r: number, h: number): Loma
	local R = (r * r + h * h) / (2 * h)
	return { cx = cx, cz = cz, R = R, cy = h - R }
end

-- Radio y altura de la colina: el radio es el de TAMANOS_MONTON y la altura
-- crece con numPiezas dentro de su rango (mas basura, colina mas alta).
function ModelosMonton.parametrosColina(tamano: string, indice: number?, numPiezas: number): ParamsColina
	local def = GameConfig.TAMANOS_MONTON[tamano] or GameConfig.TAMANOS_MONTON.chico
	local rng = semilla("colina" .. tamano .. tostring(indice or 0))
	local r = def.radio
	local llenado = if def.max > def.min then (numPiezas - def.min) / (def.max - def.min) else 1
	local h = r * (0.6 + 0.4 * math.clamp(llenado, 0, 1))
	local lomas = { loma(0, 0, r, h) }
	-- 2-3 lomas secundarias con semilla fija por monton: la misma silueta
	-- aunque se reconstruya
	local secundarias = rng:NextInteger(2, 3)
	for i = 1, secundarias do
		local ang = (i / secundarias) * math.pi * 2 + rng:NextNumber(-0.5, 0.5)
		-- hacia el borde, donde la loma principal ya es baja: si no quedan dentro
		local dist = r * rng:NextNumber(0.55, 0.8)
		local rs = r * rng:NextNumber(0.4, 0.55)
		local hs = h * rng:NextNumber(0.5, 0.7)
		table.insert(lomas, loma(math.cos(ang) * dist, math.sin(ang) * dist, rs, hs))
	end
	return { lomas = lomas, r = r, h = h }
end

-- Altura de la superficie de la colina en (x, z) locales; 0 fuera de ella
function ModelosMonton.alturaColina(params: ParamsColina, x: number, z: number): number
	local y = 0
	for _, l in params.lomas do
		local dx, dz = x - l.cx, z - l.cz
		local d2 = dx * dx + dz * dz
		if d2 < l.R * l.R then
			y = math.max(y, l.cy + math.sqrt(l.R * l.R - d2))
		end
	end
	return y
end

-- n puntos que RELLENAN el volumen de la colina (no solo su superficie): al
-- activar, la colina se sustituye entera por una montana hecha de basura con
-- el mismo bulto. Muestreo "mejor candidato": para cada punto se prueban
-- varios al azar dentro del casquete y se toma el mas alejado de los ya
-- puestos, asi quedan repartidos sin recuento de vecinos. Cerca de la
-- superficie se aprieta un poco mas (candidatos con y alta se prefieren) para
-- que la capa exterior no deje ver el interior.
function ModelosMonton.puntosEnColina(params: ParamsColina, n: number, rng: Random): { Vector3 }
	local puntos: { Vector3 } = {}
	local r = params.r
	for _ = 1, n do
		local mejor: Vector3? = nil
		local mejorDist = -1
		for _ = 1, 10 do
			local ang = rng:NextNumber(0, math.pi * 2)
			local d = math.sqrt(rng:NextNumber(0, 1)) * r * 0.8 -- algo mas estrecho: al caer se desparrama
			local x, z = math.cos(ang) * d, math.sin(ang) * d
			local techo = ModelosMonton.alturaColina(params, x, z)
			if techo > 0.6 then
				-- sesgo hacia arriba: la raiz cuadrada acumula candidatos en la capa exterior
				local y = 0.2 + (techo - 0.4) * math.sqrt(rng:NextNumber(0, 1))
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
		table.insert(puntos, mejor or Vector3.new(0, 0.5, 0))
	end
	return puntos
end

-- Modelo de la colina (o las marcas planas si esta agotado). Pivote en el
-- suelo, bajo el centro: se coloca con PivotTo(CFrame.new(ranura)).
function ModelosMonton.monton(tamano: string, agotado: boolean, indice: number?, numPiezas: number?): Model
	local m = nuevoModelo("Monton")
	local radio = ModelosMonton.radioMonton(tamano)
	if agotado then
		local rng = semilla("resto" .. tamano .. tostring(indice or 0))
		local c = bloque("Resto", Vector3.new(radio * 1.6, 0.4, radio * 1.4), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Paleta.MONTON_AGOTADO, m)
		bloque("Resto2", Vector3.new(radio * 1.0, 0.3, radio * 0.9), CFrame.new(radio * 0.3, 0.15, -radio * 0.2) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Paleta.MONTON_AGOTADO, m)
		m.PrimaryPart = c
		pivoteEnSuelo(m)
		return m
	end
	local n = numPiezas or GameConfig.TAMANOS_MONTON[tamano].min
	local params = ModelosMonton.parametrosColina(tamano, indice, n)
	local principal: BasePart? = nil
	for i, l in params.lomas do
		local bola = esfera("Loma_" .. i, l.R * 2, CFrame.new(l.cx, l.cy, l.cz), Paleta.MONTON, m)
		bola.CanCollide = true -- se puede subir
		bola.CanQuery = true
		if i == 1 then
			principal = bola
		end
	end
	m.PrimaryPart = principal
	pivoteEnSuelo(m)
	return m
end


return ModelosMonton
