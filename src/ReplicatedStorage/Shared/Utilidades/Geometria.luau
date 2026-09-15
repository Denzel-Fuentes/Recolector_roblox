--!strict
--[[
	Geometria
	Medidas espaciales que servidor y cliente tienen que calcular IGUAL: si el
	cliente resalta un objeto como "al alcance" y el servidor lo rechaza por
	"lejos", el jugador ve un fallo. Por eso viven en Shared.
]]

local Geometria = {}

-- Distancia de un punto a la SUPERFICIE de la caja de un objeto (0 si esta
-- dentro). Se usa en vez de la distancia al centro porque la basura mide
-- hasta 4 studs: medir al centro dejaba las piezas grandes fuera de alcance
-- estando pegado a ellas.
function Geometria.distanciaASuperficie(objeto: PVInstance, punto: Vector3): number
	local cf: CFrame, size: Vector3
	if objeto:IsA("BasePart") then
		cf, size = objeto.CFrame, objeto.Size
	elseif objeto:IsA("Model") then
		cf, size = objeto:GetBoundingBox()
	else
		cf, size = objeto:GetPivot(), Vector3.zero
	end
	local l = cf:PointToObjectSpace(punto)
	local mitad = size / 2
	return Vector3.new(
		math.max(0, math.abs(l.X) - mitad.X),
		math.max(0, math.abs(l.Y) - mitad.Y),
		math.max(0, math.abs(l.Z) - mitad.Z)
	).Magnitude
end

-- Esta dentro de la caja (eje a eje) de una parte
function Geometria.dentroDe(parte: BasePart, pos: Vector3): boolean
	local l = parte.CFrame:PointToObjectSpace(pos)
	local mitad = parte.Size / 2
	return math.abs(l.X) <= mitad.X and math.abs(l.Y) <= mitad.Y and math.abs(l.Z) <= mitad.Z
end

return Geometria
