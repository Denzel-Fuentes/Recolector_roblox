--!strict
--[[
	Tema (ModuleScript)
	Unica responsabilidad: las constantes visuales del Kit y las reglas de
	color que no son un token de Paleta (que color toma un boton, que texto va
	encima de un color). Solo datos y funciones puras: sin instancias vivas
	salvo SELECCION_INVISIBLE, que se comparte.

	Estilo "UI Kit" de simulador (referencia del usuario): contorno azul
	marino grueso, texto blanco FredokaOne con contorno sobre los colores,
	esquinas redondeadas y studs donde el kit original pone cuadros.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Iconos = require(Config:WaitForChild("Iconos"))

local Tema = {}

Tema.FUENTE_TITULO = Font.new("rbxasset://fonts/families/FredokaOne.json")
Tema.FUENTE_CUERPO = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.SemiBold)
Tema.FUENTE_NEGRITA = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)

Tema.RADIO = 12
Tema.RADIO_VENTANA = 18
Tema.GROSOR = 3 -- contorno marino de botones y tarjetas
Tema.GROSOR_VENTANA = 4
Tema.SOMBRA = 4 -- px que asoma la sombra dura por debajo de un boton
Tema.ALTO_CABECERA = 52 -- barra de titulo de las ventanas
Tema.TEXTO_MINIMO_COMPACTO = 13 -- en telefono nada por debajo de esto (px de diseno)

-- Textura de studs: id en Config/Iconos (clave "studs"); sin id, no hay studs
Tema.STUDS_BALDOSA = 32
Tema.STUDS_VENTANA = 0.86 -- transparencia de la imagen segun donde va
Tema.STUDS_TARJETA = 0.62
Tema.STUDS_BOTON = 0.78

-- Degradado de los botones y pildoras: arriba el color, abajo algo mas oscuro
Tema.DEGRADADO = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210))

-- Sustituye el recuadro azul de seleccion de Roblox: la seleccion se pinta
-- con el contorno del propio boton (amarillo)
Tema.SELECCION_INVISIBLE = Instance.new("ImageLabel")
Tema.SELECCION_INVISIBLE.BackgroundTransparency = 1
Tema.SELECCION_INVISIBLE.ImageTransparency = 1

function Tema.idStuds(): string?
	return Iconos.id("studs")
end

-- Blanco sobre los colores del kit (todos intensos); tinta sobre los claros
function Tema.textoSobre(color: Color3): Color3
	local luminancia = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if luminancia < 0.72 then Paleta.UI_PAPEL else Paleta.UI_TINTA
end

-- El contorno del texto solo hace falta cuando el texto es blanco
function Tema.contornoSobre(color: Color3): boolean
	return Tema.textoSobre(color) == Paleta.UI_PAPEL
end

function Tema.oscurecer(color: Color3, cuanto: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), cuanto)
end

local function hashTexto(texto: string): number
	local h = 0
	for i = 1, #texto do
		h = (h * 31 + string.byte(texto, i)) % 16777216
	end
	return h
end

-- El color de un boton. `clave` lo identifica (su nombre, o su texto si no
-- tiene): el mismo boton sale siempre del mismo color. `color` es el que
-- pidio quien lo crea: si significa algo (peligro, Gemas/Robux, exito) se
-- respeta; cualquier otro se sustituye por el de la clave en Paleta.UI_KIT.
function Tema.colorBoton(clave: string, color: Color3?): Color3
	if color == Paleta.UI_PELIGRO then
		return Paleta.UI_KIT_PELIGRO
	elseif color == Paleta.UI_GEMAS then
		return Paleta.UI_KIT_GEMAS
	elseif color == Paleta.UI_EXITO or color == Paleta.UI_DINERO then
		return Paleta.UI_KIT_EXITO
	end
	return Paleta.UI_KIT[hashTexto(clave) % #Paleta.UI_KIT + 1]
end

-- string.upper solo sabe ASCII: "montón" saldria "MONTóN". Las letras
-- acentuadas del espanol son dos bytes (C3 xx) y la mayuscula esta 0x20 antes.
local MAYUSCULAS_UTF8 = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü" }
function Tema.mayusculas(texto: string): string
	local resultado = string.upper(texto):gsub("\xC3[\xA0-\xBF]", function(letra: string)
		return MAYUSCULAS_UTF8[letra] or letra
	end)
	return resultado
end

function Tema.cabecera(nombrePanel: string): Color3
	return Paleta.CABECERA_PANEL[nombrePanel] or Paleta.CABECERA_DEFECTO
end

return Tema
