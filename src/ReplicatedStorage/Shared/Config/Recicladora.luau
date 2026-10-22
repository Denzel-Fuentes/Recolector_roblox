--!strict
--[[
	Recicladora (datos)
	Unica responsabilidad: la geometria y los tiempos de la animacion de la
	recicladora (malla de Blender ServerStorage.Arte.Recicladora): por donde
	circula la basura, que piezas giran y a que ritmo.

	Coordenadas en el marco del PIVOTE del modelo que coloca
	ArteMundo.recicladora: suelo bajo el centro del contenedor verde, +Z hacia
	el patio (el frente), +Y arriba. Salen del .blend (1 unidad = 1 stud):
	local = (x + 0.5, z, -(y + 3.4)) con el contenedor en (-0.5, -3.4) de
	Blender. Si se reexporta el modelo con otras medidas hay que recalcularlas.
]]

local Recicladora = {}

-- La basura nace dentro de la caja gris junto al contenedor, sube a la cinta
-- (tramo 1 hacia atras, esquina, tramo 2 hacia la tolva) y cae en la tolva.
-- Cada punto es el centro del objeto, ~0.5 por encima de la banda.
Recicladora.RUTA_BASURA = {
	Vector3.new(-7.9, 3.8, 0.4), -- dentro de la caja (oculto)
	Vector3.new(-7.9, 5.45, 0.4), -- sale a la banda del tramo 1
	Vector3.new(-7.9, 8.55, -4.8), -- final del tramo 1
	Vector3.new(-7.9, 8.42, -6.4), -- plataforma de la esquina
	Vector3.new(-6.3, 8.55, -6.4), -- inicio del tramo 2
	Vector3.new(-0.8, 11.63, -6.4), -- final del tramo 2, sobre la tolva
	Vector3.new(0, 9.2, -6.4), -- cae dentro de la tolva y desaparece
}
-- Tramos por los que la basura va sobre la banda (indices de RUTA_BASURA):
-- los listones de cada tramo avanzan en esa direccion
Recicladora.TRAMOS = {
	{ listones = "Listones_Tramo1", desde = 2, hasta = 3 },
	{ listones = "Listones_Tramo2", desde = 5, hasta = 6 },
}
Recicladora.PASO_LISTONES = 0.75 -- separacion entre listones: el ciclo del desplazamiento

-- El bloque compactado nace dentro de la caja de salida, asoma por el tunel
-- y baja por la rampa hasta el tope
Recicladora.RUTA_BLOQUE = {
	Vector3.new(9.4, 2.3, -5.8),
	Vector3.new(9.4, 2.21, -4.4),
	Vector3.new(9.4, 1.27, 0.32),
}

-- Eje de giro de cada pieza de Moviles en el marco del pivote. Los rodillos
-- de la trituradora giran siempre; los de la cinta y la rampa solo con la
-- cinta en marcha.
Recicladora.EJE_GIRO = ({
	Rodillo_Inf = "X",
	Rodillo_Sup = "X",
	RodilloCinta_1A = "X",
	RodilloCinta_1B = "X",
	RodilloCinta_2A = "Z",
	RodilloCinta_2B = "Z",
	RodilloRampa_0 = "X",
	RodilloRampa_1 = "X",
	RodilloRampa_2 = "X",
	RodilloRampa_3 = "X",
	RodilloRampa_4 = "X",
	RodilloRampa_5 = "X",
}) :: { [string]: string }
-- Sentido de giro: los dos rodillos muerden hacia dentro
Recicladora.SIEMPRE_GIRAN = ({ Rodillo_Inf = 1, Rodillo_Sup = -1 }) :: { [string]: number }

-- Colision: cajas invisibles del esqueleto (ConstructorMundo) que siguen la
-- silueta de la malla, que no colisiona. No se usa la colision de las
-- mallas porque cada una junta piezas sueltas del mismo color (la de
-- GrisOscuro va de las patas de la cinta a las rejillas) y su casco cerraria
-- los huecos. El volquete no esta aqui: sus paredes son las del Contenedor
-- funcional. Cajas = centro y tamano; losas = de un extremo al otro de la
-- banda (grosor hacia abajo), para las dos cintas y la rampa.
export type CajaColision = { nombre: string, centro: Vector3, tamano: Vector3 }
export type LosaColision = { nombre: string, desde: Vector3, hasta: Vector3, ancho: number, grosor: number }
Recicladora.COLISION_CAJAS = {
	{ nombre = "Base", centro = Vector3.new(0.5, 0.3, -6.4), tamano = Vector3.new(13.8, 0.6, 5.8) },
	{ nombre = "Cuerpo", centro = Vector3.new(0, 4.27, -6.4), tamano = Vector3.new(8.3, 8.53, 5.3) },
	{ nombre = "Tolva", centro = Vector3.new(0, 9.1, -6.4), tamano = Vector3.new(4.2, 1.2, 4.2) },
	{ nombre = "Boca", centro = Vector3.new(0, 5, -3.43), tamano = Vector3.new(7.4, 4, 0.95) },
	{ nombre = "Pilar", centro = Vector3.new(-5.1, 3.7, -6.6), tamano = Vector3.new(2.2, 7.4, 4.6) },
	{ nombre = "Carcasa", centro = Vector3.new(5.5, 4.85, -6.4), tamano = Vector3.new(3.3, 9.7, 5.7) },
	{ nombre = "CajaGris", centro = Vector3.new(-6.9, 2.2, 0), tamano = Vector3.new(4.3, 4.4, 4.3) },
	{ nombre = "Esquina", centro = Vector3.new(-7.9, 8.05, -6.4), tamano = Vector3.new(3.2, 1.5, 3.2) },
	{ nombre = "EsquinaPata", centro = Vector3.new(-9.25, 3.65, -5.05), tamano = Vector3.new(0.35, 7.3, 0.35) },
	{ nombre = "EsquinaPata", centro = Vector3.new(-6.55, 3.65, -5.05), tamano = Vector3.new(0.35, 7.3, 0.35) },
	{ nombre = "EsquinaPata", centro = Vector3.new(-9.25, 3.65, -7.75), tamano = Vector3.new(0.35, 7.3, 0.35) },
	{ nombre = "EsquinaPata", centro = Vector3.new(-6.55, 3.65, -7.75), tamano = Vector3.new(0.35, 7.3, 0.35) },
	{ nombre = "CintaPata", centro = Vector3.new(-9.1, 2.9, -2.6), tamano = Vector3.new(0.35, 5.8, 0.35) },
	{ nombre = "CintaPata", centro = Vector3.new(-6.7, 2.9, -2.6), tamano = Vector3.new(0.35, 5.8, 0.35) },
	{ nombre = "Salida", centro = Vector3.new(9.4, 2.32, -6.4), tamano = Vector3.new(4.5, 4.65, 4.9) },
	{ nombre = "Conducto", centro = Vector3.new(7.25, 2.6, -6.4), tamano = Vector3.new(0.6, 2.2, 2.8) },
} :: { CajaColision }
Recicladora.COLISION_LOSAS = {
	{ nombre = "Tramo1", desde = Vector3.new(-7.9, 4.95, 0.4), hasta = Vector3.new(-7.9, 8.05, -4.8), ancho = 3, grosor = 0.9 },
	{ nombre = "Tramo2", desde = Vector3.new(-6.3, 8.05, -6.4), hasta = Vector3.new(-0.8, 11.13, -6.4), ancho = 3, grosor = 0.9 },
	{ nombre = "Rampa", desde = Vector3.new(9.4, 1.55, -4.4), hasta = Vector3.new(9.4, 0.45, 1.1), ancho = 2.6, grosor = 0.5 },
} :: { LosaColision }

Recicladora.GIRO_TRITURADORA = 2.5 -- rad/s en reposo
Recicladora.GIRO_TRITURANDO = 7 -- rad/s mientras cae basura en la tolva
Recicladora.GIRO_RODILLOS_CINTA = 9 -- rad/s de los rodillos de la cinta en marcha
Recicladora.VELOCIDAD_CINTA = 4 -- studs/s de la basura sobre la banda
Recicladora.VELOCIDAD_BLOQUE = 2.5 -- studs/s del bloque por la rampa
Recicladora.INTERVALO_BASURA = 0.45 -- s entre un objeto y el siguiente
Recicladora.MAX_BASURA_POR_DEPOSITO = 10 -- una bolsa de 60 no llena la cinta de 60 objetos
Recicladora.MIN_BASURA_POR_DEPOSITO = 3 -- aunque la bolsa solo lleve billetes o tesoros
Recicladora.LARGO_OBJETO = 1.1 -- la basura se escala a esto por su eje mayor (la banda mide 2,3)
Recicladora.ESPERA_TRITURAR = 1.2 -- s desde que cae el ultimo objeto hasta que sale el bloque
Recicladora.VIDA_BLOQUE = 8 -- s que el bloque se queda al final de la rampa
Recicladora.MAX_BLOQUES = 3 -- en la rampa a la vez; el mas viejo se va antes

return Recicladora
