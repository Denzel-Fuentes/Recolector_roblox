--!strict
--[[
	Paleta
	Colores del whitebox. Sin texturas: todo son colores planos.

	Escenario en ESCALA DE GRISES donde el valor codifica la funcion (misma regla
	que en Fly_Roblox: minimo 30 puntos entre escalones contiguos que se vean
	juntos, nada por debajo de ~80 para no aplastar el volumen):

	    82   silueta "no la tienes" en el album
	    110  suelo del patio (lo mas oscuro: es donde esta la basura)
	    140  montones y decorado del patio
	    165  caminos, muros, montones agotados (referencia neutra)
	    195  losas de parcela y contenedor de reciclaje (superficie "tuya")
	    215  muebles y NPC
	    240  caseta de Dona Chatarra (el hub es lo mas claro)

	Los OBJETOS y MASCOTAS llevan color plano por MATERIAL y un disco de RAREZA:
	set y rareza son informacion de juego y necesitan leerse a distancia.

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
Paleta.MUROS = gris(165)
Paleta.MONTON_AGOTADO = gris(165)
Paleta.LOSA_PARCELA = gris(195)
Paleta.CONTENEDOR = gris(195)
Paleta.MUEBLE = gris(215)
Paleta.NPC = gris(215)
Paleta.CASETA = gris(240)

-- Materiales (sets de mascotas y basura)
Paleta.MATERIAL = {
	Metal = Color3.fromRGB(150, 165, 185),
	Plastico = Color3.fromRGB(70, 190, 200),
	Papel = Color3.fromRGB(214, 196, 150),
	Organico = Color3.fromRGB(120, 150, 80),
	Mixto = Color3.fromRGB(230, 190, 60),
}

-- Rareza (disco bajo la mascota / borde de la tarjeta)
Paleta.RAREZA = {
	Comun = gris(165),
	Rara = Color3.fromRGB(90, 150, 230),
	Epica = Color3.fromRGB(200, 80, 200),
	Mitica = Color3.fromRGB(255, 210, 40),
}

-- Objetos sueltos
Paleta.BILLETE = Color3.fromRGB(90, 180, 90)
Paleta.TESORO = Color3.fromRGB(230, 190, 60)
Paleta.DORADO = Color3.fromRGB(230, 190, 60)
Paleta.FIGURINA = gris(215)
Paleta.CINTA = gris(50)
Paleta.FRAGMENTO_BORDE = gris(240)
-- La bolsa de basura (azul oscuro, como en KOTAMON): proyectil, objeto caido,
-- bolsa en manos y la "imagen" de manos del cliente
Paleta.BOLSA = Color3.fromRGB(52, 74, 128)
Paleta.PIEL = Color3.fromRGB(232, 196, 160)

-- UI: tema claro "papel y tinta" (estilo pegatina, referencia KOTAMON).
-- Todo lo que se dibuja en pantalla es papel crema con contorno de tinta y
-- una sombra dura; el color solo dice de que va cada cosa (dinero verde,
-- cartas azul, gemas morado, energia ambar, bolsa azul oscuro, fuerza naranja).
Paleta.UI_PAPEL = Color3.fromRGB(255, 247, 230) -- fondo de pegatinas y paneles
Paleta.UI_PAPEL_OSCURO = Color3.fromRGB(243, 231, 205) -- filas, viewports, pistas
Paleta.UI_PAPEL_SOMBRA = Color3.fromRGB(226, 211, 182) -- separadores, pips vacios, pestanas sin elegir
Paleta.UI_TINTA = Color3.fromRGB(48, 42, 60) -- contornos y texto principal
Paleta.UI_TINTA_SUAVE = Color3.fromRGB(122, 114, 132) -- texto secundario
Paleta.UI_SOMBRA = Color3.fromRGB(48, 42, 60) -- sombra dura (se usa con transparencia)
Paleta.UI_PRIMARIO = Color3.fromRGB(255, 200, 60) -- botones de accion y seleccion
Paleta.UI_DINERO = Color3.fromRGB(72, 160, 78)
Paleta.UI_DINERO_CLARO = Color3.fromRGB(150, 214, 120)
Paleta.UI_CARTAS = Color3.fromRGB(70, 130, 220)
Paleta.UI_GEMAS = Color3.fromRGB(150, 90, 210)
Paleta.UI_ENERGIA = Color3.fromRGB(255, 176, 50)
Paleta.UI_FUERZA = Color3.fromRGB(255, 120, 70)
Paleta.UI_BOLSA = Color3.fromRGB(84, 114, 184) -- Paleta.BOLSA aclarada para leerse sobre papel
Paleta.UI_PELIGRO = Color3.fromRGB(226, 76, 76)
Paleta.UI_EXITO = Color3.fromRGB(72, 160, 78)
Paleta.UI_BLOQUEADO = Color3.fromRGB(196, 190, 182)
Paleta.UI_TECLA = Paleta.UI_TINTA -- insignias de tecla (letra en papel)
Paleta.UI_SELECCION = Paleta.UI_PRIMARIO -- contorno del boton elegido con gamepad
-- Alias del tema oscuro anterior, mapeados al claro para que los paneles que
-- aun no se han rediseñado sigan siendo legibles. Se retiran con los paneles.
Paleta.UI_FONDO = Paleta.UI_PAPEL
Paleta.UI_PANEL = Paleta.UI_PAPEL_OSCURO
Paleta.UI_PANEL_CLARO = Paleta.UI_PAPEL_SOMBRA
Paleta.UI_TEXTO = Paleta.UI_TINTA
Paleta.UI_TEXTO_SUAVE = Paleta.UI_TINTA_SUAVE
Paleta.UI_ACENTO = Paleta.UI_PRIMARIO

-- ===========================================================================
-- Arte del mundo (pasada de color sobre el whitebox, referencia KOTAMON)
-- ===========================================================================
-- Los grises de arriba siguen siendo el respaldo y el vocabulario de las
-- mascotas; esto es lo que pinta ConstructorMundo/ArteMundo por encima.
Paleta.MUNDO = {
	CESPED = Color3.fromRGB(127, 198, 75),
	CESPED_OSCURO = Color3.fromRGB(96, 168, 58),
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

-- Lo que Parcelas repinta cuando una base no lleva skin (partes Pintable):
-- con el mundo vestido, madera y no gris. Sobrescriben los grises de arriba.
Paleta.LOSA_PARCELA = Paleta.MUNDO.MADERA_CLARA
Paleta.MUEBLE = Paleta.MUNDO.MADERA_CLARA
Paleta.MUROS = Paleta.MUNDO.VALLA

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

-- Colores vivos de la basura real, por material: cada pieza elige uno con
-- su rng (latas rojas/azules/plata, botellas cian/verdes...). El color del
-- set (Paleta.MATERIAL) sigue mandando en las mascotas y en el album.
Paleta.BASURA = {
	Metal = { Color3.fromRGB(210, 60, 60), Color3.fromRGB(60, 110, 200), Color3.fromRGB(190, 195, 205), Color3.fromRGB(230, 190, 60) },
	Plastico = { Color3.fromRGB(70, 190, 200), Color3.fromRGB(90, 200, 110), Color3.fromRGB(240, 240, 240), Color3.fromRGB(240, 120, 60) },
	Papel = { Color3.fromRGB(214, 176, 120), Color3.fromRGB(230, 220, 190), Color3.fromRGB(180, 140, 95), Color3.fromRGB(240, 200, 120) },
	Organico = { Color3.fromRGB(230, 200, 60), Color3.fromRGB(120, 170, 70), Color3.fromRGB(200, 90, 70), Color3.fromRGB(170, 120, 70) },
}

-- Estados de conservacion: como se apaga o brilla el color base
Paleta.FACTOR_ESTADO = { 0.7, 0.85, 1, 1, 1 }

function Paleta.escalar(color: Color3, factor: number): Color3
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

return Paleta
