--!strict
--[[
	Formato
	Como se escriben numeros y tiempos en la UI. Por defecto la convencion del
	espanol (miles con punto, decimales con coma: $12.500, x1,5); el cliente la
	cambia segun su idioma con Formato.configurar (lo hace Utilidades/Idioma al
	cargar: en ingles $12,500 y x1.5). El servidor nunca la cambia: no formatea
	nada que vea un jugador, manda numeros (Idioma.dinero).
]]

local Formato = {}

local separadorMiles = "."
local separadorDecimal = ","

function Formato.configurar(miles: string, decimal: string)
	separadorMiles = miles
	separadorDecimal = decimal
end

function Formato.miles(n: number): string
	local entero = math.floor(math.abs(n) + 0.5)
	local texto = tostring(entero)
	local conPuntos = texto:reverse():gsub("(%d%d%d)", "%1" .. separadorMiles):reverse()
	if conPuntos:sub(1, #separadorMiles) == separadorMiles then
		conPuntos = conPuntos:sub(#separadorMiles + 1)
	end
	if n < 0 then
		return "-" .. conPuntos
	end
	return conPuntos
end

function Formato.dinero(n: number): string
	return "$" .. Formato.miles(n)
end

-- "x1,5", "x2": el multiplicador de dinero (sin ",0")
function Formato.multiplicador(m: number): string
	if m % 1 == 0 then
		return "x" .. tostring(math.floor(m))
	end
	return "x" .. (string.format("%.1f", m):gsub("%.", separadorDecimal))
end

function Formato.porcentaje(fraccion: number, decimales: number?): string
	local d = decimales or 0
	return (string.format("%." .. d .. "f%%", fraccion * 100):gsub("%.", separadorDecimal))
end

function Formato.tiempo(segundos: number): string
	local s = math.floor(segundos)
	local m = math.floor(s / 60)
	return string.format("%d:%02d", m, s % 60)
end

return Formato
