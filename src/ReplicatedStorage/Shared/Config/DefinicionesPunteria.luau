--!strict
--[[
	DefinicionesPunteria
	Los premios del lanzamiento del diseno v2. Solo datos y cuentas puras
	(servidor, HUD y pruebas las comparten).

	El bonus ya no es un +50 % fijo: crece con la DISTANCIA al contenedor,
	de +20 % a 10 studs hasta +150 % desde 60. Tirar de lejos vale la pena,
	pero se falla mas; el alcance lo pone la mejora Brazo (25 -> 70 studs).
	Por debajo de 10 studs (o entregando a mano) no hay bonus.

	Racha: cada acierto seguido suma +10 %, hasta +50 % a partir del quinto;
	fallar la pone a 0. Un tiro desde menos de 10 studs ni suma ni corta (si
	no, la racha se farmearia a quemarropa).

	Pago de una bolsa (Services/Bolsa):
	  valor de las piezas x (1 + bonus distancia + racha) x multiplicador de
	  rebirth x (1 + bonus mascotas, por pieza) x pase de dinero
]]

local DefinicionesPunteria = {}

-- Desde esta distancia (studs, horizontal al contenedor) este bonus
DefinicionesPunteria.BONUS_DISTANCIA = {
	{ desde = 10, bonus = 0.2 },
	{ desde = 20, bonus = 0.4 },
	{ desde = 30, bonus = 0.7 },
	{ desde = 45, bonus = 1.0 },
	{ desde = 60, bonus = 1.5 },
}
DefinicionesPunteria.DISTANCIA_SIN_BONUS = 10

DefinicionesPunteria.RACHA_PASO = 0.1
DefinicionesPunteria.RACHA_TOPE = 5

-- Ayuda de punteria: la linea de trayectoria se ve en los primeros
-- lanzamientos, y el primero de todos siempre entra
DefinicionesPunteria.LANZAMIENTOS_CON_LINEA = 5

function DefinicionesPunteria.bonusDistancia(distancia: number): number
	local bonus = 0
	for _, tramo in DefinicionesPunteria.BONUS_DISTANCIA do
		if distancia >= tramo.desde then
			bonus = tramo.bonus
		end
	end
	return bonus
end

-- Bonus de una racha de n aciertos seguidos (contando el de ahora)
function DefinicionesPunteria.bonusRacha(n: number): number
	return math.min(n, DefinicionesPunteria.RACHA_TOPE) * DefinicionesPunteria.RACHA_PASO
end

-- Cuenta para la racha un acierto desde esa distancia
function DefinicionesPunteria.cuentaParaRacha(distancia: number): boolean
	return distancia >= DefinicionesPunteria.DISTANCIA_SIN_BONUS
end

return DefinicionesPunteria
