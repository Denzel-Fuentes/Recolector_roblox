--!strict
--[[
	Formato
	Como se escriben numeros y tiempos en la UI. Separador de miles con punto
	(convencion del espanol): $12.500.
]]

local Formato = {}

function Formato.miles(n: number): string
	local entero = math.floor(math.abs(n) + 0.5)
	local texto = tostring(entero)
	local conPuntos = texto:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if conPuntos:sub(1, 1) == "." then
		conPuntos = conPuntos:sub(2)
	end
	if n < 0 then
		return "-" .. conPuntos
	end
	return conPuntos
end

function Formato.dinero(n: number): string
	return "$" .. Formato.miles(n)
end

function Formato.gemas(n: number): string
	return Formato.miles(n) .. " Gemas"
end

function Formato.porcentaje(fraccion: number, decimales: number?): string
	local d = decimales or 0
	return string.format("%." .. d .. "f%%", fraccion * 100)
end

function Formato.tiempo(segundos: number): string
	local s = math.floor(segundos)
	local m = math.floor(s / 60)
	return string.format("%d:%02d", m, s % 60)
end

function Formato.studs(n: number): string
	return string.format("%d studs", math.floor(n + 0.5))
end

return Formato
