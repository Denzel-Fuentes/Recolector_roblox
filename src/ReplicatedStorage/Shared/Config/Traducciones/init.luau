--!strict
--[[
	Traducciones
	Unica responsabilidad: las traducciones del copy de Textos, por codigo de
	idioma (la parte de Player.LocaleId antes del guion: "en-us" -> "en").
	El espanol no esta aqui: es Textos mismo, el original y el respaldo de
	todo lo que falte. Las resuelve Utilidades/Idioma.

	Para anadir un idioma: un modulo hermano con la forma de en.luau, una
	linea en IDIOMAS y sus separadores en FORMATO; la prueba "idioma" dice
	que claves faltan.
]]

local Traducciones = {}

Traducciones.IDIOMAS = {
	en = require(script:WaitForChild("en")),
	pt = require(script:WaitForChild("pt")),
} :: { [string]: { [string]: any } }

-- Separadores de miles y decimales por idioma (el espanol: "." y ",")
Traducciones.FORMATO = {
	es = { miles = ".", decimal = "," },
	en = { miles = ",", decimal = "." },
	pt = { miles = ".", decimal = "," },
} :: { [string]: { miles: string, decimal: string } }

return Traducciones
