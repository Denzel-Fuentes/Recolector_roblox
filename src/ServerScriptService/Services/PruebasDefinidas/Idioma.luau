--!nonstrict
--[[
	Pruebas de idioma (7 oct): que cada traduccion (Config/Traducciones)
	cubra todo el copy de Textos y los nombres de Config (DEF), con los mismos
	{marcadores} que el espanol, y que los mensajes servidor -> cliente
	(Utilidades/Idioma) se resuelvan bien.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Traducciones = require(Shared:WaitForChild("Config"):WaitForChild("Traducciones"))
local Idioma = require(Shared:WaitForChild("Utilidades"):WaitForChild("Idioma"))

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

-- Iguales en todos los idiomas a proposito: no hace falta traducirlas
local SIN_TRADUCIR = {
	["HUD.dinero"] = true, -- "$"
	["MUNDO.tienda"] = true, -- "SHOP": el rotulo de la malla lleva las letras en 3D
}

-- Todas las hojas string de un arbol: { ["SECCION.clave"] = texto }
local function hojas(arbol, camino, salida)
	salida = salida or {}
	for nombre, valor in arbol do
		local clave = if camino == "" then nombre else camino .. "." .. nombre
		if typeof(valor) == "table" then
			hojas(valor, clave, salida)
		elseif typeof(valor) == "string" then
			salida[clave] = valor
		end
	end
	return salida
end

-- Los {marcadores} de una plantilla, ordenados y unidos ("dinero,n")
local function marcadores(texto: string): string
	local lista = {}
	for m in string.gmatch(texto, "{(%w+)}") do
		table.insert(lista, m)
	end
	table.sort(lista)
	return table.concat(lista, ",")
end

function Pruebas.idioma()
	local original = hojas(Idioma.original(), "")
	local partes, bien = {}, true
	for codigo, traduccion in Traducciones.IDIOMAS do
		local suyas = hojas(traduccion, "")
		local faltan, sobran, rotas = {}, {}, {}
		for clave, texto in original do
			local t = suyas[clave]
			if t == nil then
				if not SIN_TRADUCIR[clave] then
					table.insert(faltan, clave)
				end
			elseif marcadores(t) ~= marcadores(texto) then
				table.insert(rotas, clave)
			end
		end
		for clave in suyas do
			if original[clave] == nil then
				table.insert(sobran, clave)
			end
		end
		table.sort(faltan)
		table.sort(sobran)
		table.sort(rotas)
		local esteBien = #faltan == 0 and #sobran == 0 and #rotas == 0
		bien = bien and esteBien
		table.insert(partes, string.format("%s: %d faltan%s, %d sobran%s, %d con marcadores distintos%s",
			codigo,
			#faltan, if #faltan > 0 then " (" .. table.concat(faltan, " ", 1, math.min(#faltan, 8)) .. ")" else "",
			#sobran, if #sobran > 0 then " (" .. table.concat(sobran, " ", 1, math.min(#sobran, 8)) .. ")" else "",
			#rotas, if #rotas > 0 then " (" .. table.concat(rotas, " ") .. ")" else ""))
		if not Traducciones.FORMATO[codigo] then
			bien = false
			table.insert(partes, codigo .. ": sin separadores en Traducciones.FORMATO")
		end
	end

	-- Mensajes: anidados, numeros con formato, clave mala, literales
	local m = Idioma.mensaje("PATIO.montonRico", { material = Idioma.mensaje("MATERIALES.Papel") })
	local es, en = Idioma.resolver(m, "es"), Idioma.resolver(m, "en")
	local dinero = Idioma.resolver(Idioma.mensaje("REBIRTH.faltaDinero", { dinero = Idioma.dinero(12500) }), "pt")
	local claveMala = not pcall(Idioma.mensaje, "PATIO.noExiste")
	local literal = Idioma.literal("Excavar", "en")
	local nombre = Idioma.resolver(Idioma.mensajeNombre("Mejoras", { id = "Brazo", nombre = "Brazo" }), "pt")
	local normal = Idioma.normalizar("en-us") == "en" and Idioma.normalizar("pt-br") == "pt" and Idioma.normalizar("fr-fr") == "es"
	local mensajesBien = es == "Montón con mucho papel" and en == "Pile with lots of paper"
		and string.find(dinero, "$", 1, true) ~= nil and claveMala and literal == "Dig" and nombre == "Braço" and normal
	bien = bien and mensajesBien
	table.insert(partes, string.format("mensajes: '%s' / '%s' / '%s', clave mala falla=%s, literal Excavar->'%s', mejora Brazo pt->'%s', locales=%s",
		es, en, dinero, tostring(claveMala), literal, nombre, tostring(normal)))

	return table.concat(partes, "; ") .. " => " .. ok(bien)
end

return Pruebas
