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

-- UI
Paleta.UI_FONDO = Color3.fromRGB(30, 31, 36)
Paleta.UI_PANEL = Color3.fromRGB(44, 46, 54)
Paleta.UI_PANEL_CLARO = Color3.fromRGB(60, 63, 72)
Paleta.UI_TEXTO = Color3.fromRGB(240, 240, 240)
Paleta.UI_TEXTO_SUAVE = Color3.fromRGB(170, 172, 180)
Paleta.UI_ACENTO = Color3.fromRGB(190, 255, 60)
Paleta.UI_PELIGRO = Color3.fromRGB(230, 90, 90)
Paleta.UI_DINERO = Color3.fromRGB(120, 210, 120)
Paleta.UI_GEMAS = Color3.fromRGB(120, 170, 255)
Paleta.UI_ENERGIA = Color3.fromRGB(255, 190, 60)
Paleta.UI_BLOQUEADO = gris(110)

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
