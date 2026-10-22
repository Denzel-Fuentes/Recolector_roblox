--!strict
--[[
	Paleta
	Colores del whitebox. Sin texturas: todo son colores planos.

	Escenario en ESCALA DE GRISES donde el valor codifica la funcion (misma regla
	que en Fly_Roblox: minimo 30 puntos entre escalones contiguos que se vean
	juntos, nada por debajo de ~80 para no aplastar el volumen):

	    110  suelo del patio (lo mas oscuro: es donde esta la basura)
	    140  montones y decorado del patio
	    165  caminos, muros, montones agotados (referencia neutra)
	    195  losas de parcela y contenedor de reciclaje (superficie "tuya")
	    215  muebles y NPC
	    240  caseta de Dona Chatarra (el hub es lo mas claro)

	La BASURA lleva el color de su TIPO (Paleta.TIPO, decision del usuario,
	3 oct): papel celeste (era carton suave hasta el 6 oct), plastico
	amarillo, metal plomo, organico verde; y el contenedor general, azul. Cada pieza toma uno de varios
	tonos de su color (Paleta.BASURA) para que la montana no sea plana pero
	el tipo se lea de un vistazo: es lo que decide a que contenedor va.
	Contenedores, suelo de las zonas, barreras e iconos usan el mismo color.

	Sin NEON en el mapa (el usuario quito el anillo amarillo del monton activado):
	la senal de "aqui hay basura" es la propia montana, que pasa de gris a los
	colores de material al activarla.
]]

local Paleta = {}

local function gris(valor: number): Color3
	return Color3.fromRGB(valor, valor, valor)
end
Paleta.gris = gris

-- Escenario
Paleta.SILUETA = gris(82)
Paleta.SUELO_PATIO = gris(110)
Paleta.MONTON = gris(140)
Paleta.MONTON_BASURA = Color3.fromRGB(112, 124, 150) -- colina vestida: azul-gris de bolsas de basura
Paleta.DECORADO = gris(140)
Paleta.CAMINOS = gris(165)
Paleta.MONTON_AGOTADO = gris(165)
Paleta.CONTENEDOR = gris(195)
Paleta.MUEBLE = gris(215)
Paleta.NPC = gris(215)
Paleta.CASETA = gris(240)

-- Tipos de basura y sus contenedores (3 oct). General = el contenedor que
-- acepta de todo (el volquete de la recicladora)
Paleta.TIPO = {
	-- celeste (6 oct, peticion del usuario: el carton suave se confundia con
	-- el amarillo del plastico, sobre todo en sus tonos oscuros); claro y
	-- cian para no confundirse con el azul fuerte del general ni la bolsa
	Papel = Color3.fromRGB(110, 200, 240),
	Plastico = Color3.fromRGB(246, 202, 36), -- amarillo
	Metal = Color3.fromRGB(118, 127, 139), -- plomo (con material Metal brilla)
	Organico = Color3.fromRGB(78, 172, 70), -- verde
	General = Color3.fromRGB(44, 110, 216), -- azul
}
-- El color de cada material es el de su tipo (un solo sitio que cambiar)
Paleta.MATERIAL = Paleta.TIPO

-- Objetos sueltos
Paleta.BILLETE = Color3.fromRGB(90, 180, 90)
-- Violeta "epico" (7 oct, peticion del usuario: dorado se confundia con la
-- basura de plastico, amarilla). Ningun tipo de basura usa este color
Paleta.TESORO = Color3.fromRGB(170, 85, 235)
Paleta.DORADO = Color3.fromRGB(230, 190, 60)
Paleta.FIGURINA = gris(215)
Paleta.CINTA = gris(50)
-- La bolsa de basura (azul oscuro, como en KOTAMON): proyectil, objeto caido,
-- bolsa en manos y la "imagen" de manos del cliente
Paleta.BOLSA = Color3.fromRGB(52, 74, 128)
-- El cincho del atado de la bolsa cerrada: amarillo, como el cordon de las
-- bolsas de basura; contrasta con el azul y no cambia con los disenos
Paleta.CINCHO_BOLSA = Color3.fromRGB(242, 183, 5)
Paleta.PIEL = Color3.fromRGB(232, 196, 160)

-- UI: estilo "UI Kit" de simulador (referencia del usuario, 23 sep): blanco
-- con contorno azul marino grueso, barras de titulo de color, botones de
-- colores intensos con texto blanco contorneado y studs donde el kit pone
-- cuadros. Lo pinta Client/UI/Kit (Fusion). El color sigue diciendo de que va
-- cada cosa (dinero verde, cartas azul, gemas morado, energia ambar...).
Paleta.UI_PAPEL = Color3.fromRGB(255, 255, 255) -- cuerpo de ventanas y pildoras
Paleta.UI_PAPEL_OSCURO = Color3.fromRGB(233, 236, 243) -- tarjetas, filas, viewports
Paleta.UI_PAPEL_SOMBRA = Color3.fromRGB(203, 208, 222) -- separadores, pips vacios, huecos de barra
Paleta.UI_TINTA = Color3.fromRGB(27, 29, 58) -- contornos y texto principal (marino)
Paleta.UI_TINTA_SUAVE = Color3.fromRGB(104, 108, 138) -- texto secundario
Paleta.UI_SOMBRA = Color3.fromRGB(27, 29, 58) -- sombra dura (se usa con transparencia)
Paleta.UI_PRIMARIO = Color3.fromRGB(255, 196, 28) -- amarillo de seleccion y destacados
Paleta.UI_DINERO = Color3.fromRGB(58, 206, 62)
Paleta.UI_DINERO_CLARO = Color3.fromRGB(150, 232, 120)
Paleta.UI_CARTAS = Color3.fromRGB(42, 140, 255)
Paleta.UI_GEMAS = Color3.fromRGB(146, 70, 245)
Paleta.UI_ENERGIA = Color3.fromRGB(255, 168, 20)
Paleta.UI_FUERZA = Color3.fromRGB(255, 110, 50)
Paleta.UI_BOLSA = Color3.fromRGB(64, 104, 200) -- Paleta.BOLSA aclarada para leerse sobre blanco
Paleta.UI_PELIGRO = Color3.fromRGB(240, 52, 64)
Paleta.UI_EXITO = Color3.fromRGB(58, 206, 62)
Paleta.UI_BLOQUEADO = Color3.fromRGB(176, 181, 196)
Paleta.UI_TECLA = Paleta.UI_TINTA -- insignias de tecla (letra blanca sobre marino)
Paleta.UI_SELECCION = Paleta.UI_PRIMARIO -- contorno del boton elegido con gamepad

-- Botones: colores intensos del kit. Cada boton toma uno FIJO segun su
-- nombre (Kit/Tema.colorBoton, decision del usuario: "diferentes colores"),
-- salvo los que significan algo: rojo peligro/cerrar, morado Robux/Gemas,
-- verde comprar/aceptar. Todos oscuros: el texto va en blanco contorneado.
Paleta.UI_KIT = {
	Color3.fromRGB(58, 206, 62), -- verde
	Color3.fromRGB(42, 140, 255), -- azul
	Color3.fromRGB(146, 70, 245), -- morado
	Color3.fromRGB(255, 142, 20), -- naranja
	Color3.fromRGB(255, 72, 150), -- rosa
	Color3.fromRGB(16, 190, 214), -- cian
}
Paleta.UI_KIT_PELIGRO = Paleta.UI_PELIGRO
Paleta.UI_KIT_GEMAS = Paleta.UI_GEMAS
Paleta.UI_KIT_EXITO = Paleta.UI_EXITO
-- Barra de titulo de cada ventana (por nombre de panel); el resto, marino
Paleta.CABECERA_PANEL = {
	Tienda = Color3.fromRGB(240, 52, 64),
	Rebirth = Color3.fromRGB(146, 70, 245),
	Pedidos = Color3.fromRGB(255, 142, 20),
}
Paleta.CABECERA_DEFECTO = Color3.fromRGB(38, 42, 86)
-- Los tres primeros puestos de los tablones de ranking (Client/Tablones)
Paleta.UI_ORO = Color3.fromRGB(255, 196, 28)
Paleta.UI_PLATA = Color3.fromRGB(196, 204, 220)
Paleta.UI_BRONCE = Color3.fromRGB(214, 130, 64)

-- ===========================================================================
-- Arte del mundo (pasada de color sobre el whitebox, referencia KOTAMON)
-- ===========================================================================
-- Los grises de arriba siguen siendo el respaldo; esto es lo que pinta
-- ConstructorMundo/ArteMundo por encima.
Paleta.MUNDO = {
	CESPED = Color3.fromRGB(127, 198, 75),
	CESPED_OSCURO = Color3.fromRGB(96, 168, 58),
	-- borde del patio: separa su cesped del cesped de alrededor
	BORDE_PATIO = Color3.fromRGB(214, 48, 49),
	TIERRA = Color3.fromRGB(172, 138, 96),
	TIERRA_OSCURA = Color3.fromRGB(150, 116, 80),
	MADERA = Color3.fromRGB(216, 168, 107),
	MADERA_CLARA = Color3.fromRGB(236, 196, 140),
	VIGA = Color3.fromRGB(138, 90, 51),
	VALLA = Color3.fromRGB(110, 74, 43),
	LONA = Color3.fromRGB(59, 91, 165),
	AZUL_MAQUINA = Color3.fromRGB(47, 95, 191),
	PARED = Color3.fromRGB(241, 217, 192),
	AMARILLO = Color3.fromRGB(242, 183, 5),
	NARANJA = Color3.fromRGB(242, 138, 30),
	NEGRO = Color3.fromRGB(38, 36, 40),
	VERDE_CONTENEDOR = Color3.fromRGB(79, 175, 92),
	METAL = Color3.fromRGB(154, 163, 173),
	METAL_OSCURO = Color3.fromRGB(96, 104, 114),
	OXIDO = Color3.fromRGB(164, 90, 50),
	CRISTAL = Color3.fromRGB(40, 52, 70),
	HORMIGON = Color3.fromRGB(190, 186, 178),
	TRONCO = Color3.fromRGB(120, 80, 48),
	HOJA = Color3.fromRGB(88, 170, 70),
	HOJA_CLARA = Color3.fromRGB(128, 200, 84),
	GOMA = Color3.fromRGB(45, 45, 48),
	PIEL_NPC = Color3.fromRGB(232, 190, 150),
	PELO_NPC = Color3.fromRGB(200, 200, 205),
	DELANTAL = Color3.fromRGB(59, 91, 165),
	CAMISA = Color3.fromRGB(230, 120, 80),
	CIELO = Color3.fromRGB(150, 205, 245),
}

-- Con el mundo vestido, el color por defecto de las partes es madera y no
-- gris: sobrescribe el gris de arriba.
Paleta.MUEBLE = Paleta.MUNDO.MADERA_CLARA

-- Variantes de material generadas por IA en Studio (MaterialService). Se
-- usan por NOMBRE: si en un place no existen, la parte se queda con el
-- material base de Roblox y no pasa nada.
Paleta.VARIANTES = {
	-- cesped y madera: sin variante. Las texturas IA (CespedCartoon,
	-- MaderaVieja) no convencieron al usuario: el look es plano y minimalista,
	-- color liso (SmoothPlastic) en suelo y parcelas
	cesped = nil :: string?,
	basura = "MontanaBasura",
	-- tierra: sin variante a proposito; las generadas salian agrietadas y naranjas,
	-- y el Ground base de Roblox ya es un camino de tierra convincente
	tierra = nil :: string?,
	madera = nil :: string?,
}

-- Aclara u oscurece un color multiplicando sus canales
function Paleta.escalar(color: Color3, factor: number): Color3
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

-- Tonos de un color, del mas oscuro al mas claro: hacia negro y hacia
-- blanco (multiplicar no aclara un color ya saturado, como el amarillo)
local NEGRO, BLANCO = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
function Paleta.tonos(color: Color3): { Color3 }
	return {
		color:Lerp(NEGRO, 0.32),
		color:Lerp(NEGRO, 0.16),
		color,
		color:Lerp(BLANCO, 0.2),
		color:Lerp(BLANCO, 0.38),
	}
end

-- La basura real: cada pieza elige con su rng uno de los tonos del color de
-- su tipo (peticion del usuario, 3 oct: "diferentes tonalidades de su
-- color"). Antes eran colores vivos sueltos (latas rojas, botellas cian) y el
-- tipo no se distinguia.
Paleta.BASURA = {
	Papel = Paleta.tonos(Paleta.TIPO.Papel),
	Plastico = Paleta.tonos(Paleta.TIPO.Plastico),
	Metal = Paleta.tonos(Paleta.TIPO.Metal),
	Organico = Paleta.tonos(Paleta.TIPO.Organico),
}

return Paleta
