--!strict
--[[
	Trayectoria
	Unica responsabilidad: las cuentas del tiro de la bolsa, iguales en el
	servidor (Services/Lanzamiento, que decide si entro) y en el cliente (la
	linea de trayectoria que ayuda en los primeros lanzamientos). Si cada lado
	tuviera su copia, la linea podria prometer un tiro que el servidor luego
	no hace.

	El tiro sale un poco por encima del personaje hacia el punto apuntado; el
	alcance es el menor entre la distancia a ese punto y fuerza x Brazo (la
	mejora). El vuelo dura mas cuanto mas lejos (0,7 a 1,5 s) y la velocidad
	inicial es la que lleva la bolsa justo al objetivo con la gravedad del
	juego. Lanzamiento integra esa parabola paso a paso para poder botar y
	chocar; aqui solo va el arco ideal.
]]

local Trayectoria = {}

Trayectoria.GRAVEDAD = Vector3.new(0, -55, 0)
-- La bolsa sale a esta altura sobre la raiz del personaje
Trayectoria.ALTURA_SALIDA = 1.5

function Trayectoria.origen(posicionRaiz: Vector3): Vector3
	return posicionRaiz + Vector3.new(0, Trayectoria.ALTURA_SALIDA, 0)
end

-- (objetivo, alcance) para un tiro hacia `punto` con esta fuerza (0..1) y
-- este alcance maximo (el Brazo)
function Trayectoria.objetivo(origen: Vector3, punto: Vector3, fuerza: number, alcanceMax: number): (Vector3, number)
	local delta = punto - origen
	if delta.Magnitude < 1e-3 then
		return origen, 0
	end
	local alcance = math.min(delta.Magnitude, math.clamp(fuerza, 0, 1) * alcanceMax)
	return origen + delta.Unit * alcance, alcance
end

-- Segundos de vuelo para ese alcance
function Trayectoria.vuelo(alcance: number): number
	return math.clamp(alcance / 22, 0.7, 1.5)
end

-- Velocidad inicial que lleva de origen a objetivo en `vuelo` segundos
function Trayectoria.velocidadInicial(origen: Vector3, objetivo: Vector3, vuelo: number): Vector3
	return (objetivo - origen - 0.5 * Trayectoria.GRAVEDAD * vuelo * vuelo) / vuelo
end

-- Posicion del arco ideal en el instante t
function Trayectoria.posicion(origen: Vector3, v0: Vector3, t: number): Vector3
	return origen + v0 * t + 0.5 * Trayectoria.GRAVEDAD * t * t
end

-- n+1 puntos del arco ideal, del origen al objetivo
function Trayectoria.puntos(origen: Vector3, objetivo: Vector3, n: number): { Vector3 }
	local vuelo = Trayectoria.vuelo((objetivo - origen).Magnitude)
	local v0 = Trayectoria.velocidadInicial(origen, objetivo, vuelo)
	local lista = table.create(n + 1)
	for i = 0, n do
		table.insert(lista, Trayectoria.posicion(origen, v0, vuelo * i / n))
	end
	return lista
end

return Trayectoria
