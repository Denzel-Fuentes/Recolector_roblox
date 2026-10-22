--!strict
--[[
	Idioma
	Unica responsabilidad: elegir el idioma del jugador y convertir el copy
	(Config/Textos, en espanol) al suyo. Servidor y cliente.

	=== Por que asi ===
	Las traducciones son modulos Luau con la forma de Textos
	(Config/Traducciones), no una LocalizationTable: funcionan igual en Studio
	y en produccion, no hay que exportar nada y la prueba "idioma" ve las
	claves que faltan o los {marcadores} rotos. El espanol es el original y el
	respaldo de todo lo que falte. La traduccion automatica de Roblox no se usa
	(AutoLocalize = false en nuestras GUIs).

	=== Reglas ===
	- El cliente lee Idioma.textos en vez de Config/Textos: misma forma y
	  mismas funciones (formatear), con las hojas ya traducidas.
	- El servidor NUNCA envia texto montado (no sabe el idioma de cada uno):
	  envia Idioma.mensaje("SECCION.clave", valores) y el cliente lo pasa por
	  Idioma.resolver. Un valor puede ser otro mensaje (un material, el nombre
	  de una mejora) o un numero con formato (Idioma.dinero, multiplicador),
	  que cada cliente escribe con sus separadores.
	- Lo que el servidor escribe en instancias (prompts, etiquetas) lleva el
	  mensaje en un atributo (Idioma.codificar): Prompts.client y
	  TraducirMundo.client lo traducen. Lo horneado sin atributo se traduce por
	  busqueda inversa del literal (Idioma.literal).
	- Los nombres de Config (mejoras, pases, productos, insignias, cosmeticos)
	  van en la seccion DEF por id: Idioma.nombre / Idioma.descripcion.

	El idioma se elige al cargar (Player.LocaleId); cambiarlo a mitad de
	partida se aplica al volver a entrar. Para probar otro en Studio: atributo
	IdiomaStudio = "en" en ReplicatedStorage (en Edit, antes de Play; solo
	cuenta dentro de Studio). El emulador de Studio (Test > Player Emulator >
	Locale) tambien vale.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = script.Parent.Parent:WaitForChild("Config")
local Textos = require(Config:WaitForChild("Textos"))
local Traducciones = require(Config:WaitForChild("Traducciones"))
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local DefinicionesInsignias = require(Config:WaitForChild("DefinicionesInsignias"))
local DefinicionesCosmeticos = require(Config:WaitForChild("DefinicionesCosmeticos"))
local Productos = require(Config:WaitForChild("Productos"))
local Formato = require(script.Parent:WaitForChild("Formato"))

-- mayus: el texto final en mayusculas (las placas horneadas)
export type Mensaje = { k: string, v: { [string]: any }?, mayus: boolean? }
export type Numero = { f: "dinero" | "miles" | "mult", n: number }
export type Definicion = { id: string, nombre: string, descripcion: string? }

local Idioma = {}

-- ===========================================================================
-- El original en espanol: Textos + DEF (los nombres de Config por id)
-- ===========================================================================

local function seccionDef(lista: { any }): { [string]: { nombre: string, descripcion: string? } }
	local seccion = {}
	for _, def in lista do
		seccion[def.id] = { nombre = def.nombre, descripcion = def.descripcion }
	end
	return seccion
end

local ORIGINAL: { [string]: any } = table.clone(Textos :: any)
ORIGINAL.DEF = {
	Mejoras = seccionDef(DefinicionesMejoras.LISTA),
	Pases = seccionDef(Productos.PASES),
	Productos = seccionDef(Productos.PRODUCTOS),
	Insignias = seccionDef(DefinicionesInsignias.LISTA),
	Bolsas = seccionDef(DefinicionesCosmeticos.BOLSAS),
	Estelas = seccionDef(DefinicionesCosmeticos.ESTELAS),
}

-- "REBIRTH.desbloquea.metal" -> la hoja de ese camino en un arbol
local function buscar(arbol: any, clave: string): any
	local nodo = arbol
	for parte in string.gmatch(clave, "[^%.]+") do
		if typeof(nodo) ~= "table" then
			return nil
		end
		nodo = nodo[parte]
	end
	return nodo
end

-- ===========================================================================
-- Idioma activo
-- ===========================================================================

-- "en-us" -> "en"; lo que no tenga traduccion se queda en "es"
function Idioma.normalizar(localeId: string?): string
	local codigo = string.lower(string.match(localeId or "", "^(%a+)") or "es")
	return if Traducciones.IDIOMAS[codigo] then codigo else "es"
end

local function detectar(): string
	local jugador = Players.LocalPlayer
	if not jugador then
		return "es" -- servidor o barra de comandos
	end
	local forzado = if RunService:IsStudio() then ReplicatedStorage:GetAttribute("IdiomaStudio") else nil
	return Idioma.normalizar(if typeof(forzado) == "string" then forzado else jugador.LocaleId)
end

Idioma.codigo = detectar()

-- ===========================================================================
-- Plantillas
-- ===========================================================================

-- La plantilla de una clave en un idioma (con {marcadores}), o nil si la
-- clave no existe ni en espanol
function Idioma.plantilla(clave: string, codigo: string?): string?
	local traduccion = Traducciones.IDIOMAS[codigo or Idioma.codigo]
	if traduccion then
		local t = buscar(traduccion, clave)
		if typeof(t) == "string" then
			return t
		end
	end
	local original = buscar(ORIGINAL, clave)
	return if typeof(original) == "string" then original else nil
end

-- El arbol original (Textos + DEF), para las pruebas
function Idioma.original(): { [string]: any }
	return ORIGINAL
end

-- ===========================================================================
-- Mensajes (servidor -> cliente)
-- ===========================================================================

function Idioma.mensaje(clave: string, valores: { [string]: any }?): Mensaje
	assert(typeof(buscar(ORIGINAL, clave)) == "string", "Idioma.mensaje: no hay texto para " .. clave)
	return { k = clave, v = valores }
end

-- El nombre de una definicion de Config como mensaje (para anidarlo)
function Idioma.mensajeNombre(categoria: string, def: Definicion): Mensaje | string
	local clave = "DEF." .. categoria .. "." .. def.id .. ".nombre"
	return if buscar(ORIGINAL, clave) then { k = clave } else def.nombre
end

-- El mismo mensaje, en mayusculas al resolverlo
function Idioma.enMayusculas(m: Mensaje): Mensaje
	return { k = m.k, v = m.v, mayus = true }
end

function Idioma.dinero(n: number): Numero
	return { f = "dinero", n = n }
end

function Idioma.miles(n: number): Numero
	return { f = "miles", n = n }
end

function Idioma.multiplicador(m: number): Numero
	return { f = "mult", n = m }
end

local function resolverValor(v: any, codigo: string?): string
	if typeof(v) == "table" then
		if typeof(v.k) == "string" then
			return Idioma.resolver(v, codigo)
		elseif v.f == "dinero" then
			return Formato.dinero(v.n)
		elseif v.f == "miles" then
			return Formato.miles(v.n)
		elseif v.f == "mult" then
			return Formato.multiplicador(v.n)
		end
	end
	return tostring(v)
end

-- Texto final de un mensaje (o de un string suelto, que se traduce si es un
-- literal conocido del original). Lo que no es ninguna de las dos cosas (llega
-- de un remote) da "".
function Idioma.resolver(m: any, codigo: string?): string
	if typeof(m) == "string" then
		return Idioma.literal(m, codigo)
	end
	if typeof(m) ~= "table" or typeof(m.k) ~= "string" then
		return ""
	end
	local mensaje = m :: Mensaje
	local texto = Idioma.plantilla(mensaje.k, codigo) or mensaje.k
	if typeof(mensaje.v) == "table" then
		local valores = {}
		for nombre, v in mensaje.v :: { [string]: any } do
			valores[nombre] = resolverValor(v, codigo)
		end
		texto = Textos.formatear(texto, valores)
	end
	return if mensaje.mayus == true then Idioma.mayusculas(texto) else texto
end

-- Un mensaje en un atributo (los atributos no guardan tablas)
function Idioma.codificar(m: Mensaje): string
	return HttpService:JSONEncode(m)
end

function Idioma.decodificar(texto: any): Mensaje?
	if typeof(texto) ~= "string" then
		return nil
	end
	local ok, m = pcall(HttpService.JSONDecode, HttpService, texto)
	return if ok and typeof(m) == "table" and typeof(m.k) == "string" then m else nil
end

-- ===========================================================================
-- Literales (texto horneado sin atributo)
-- ===========================================================================

local inverso: { [string]: string }? = nil

local function indiceInverso(): { [string]: string }
	if inverso then
		return inverso
	end
	local indice = {}
	local function recorrer(nodo: any, camino: string)
		for nombre, valor in nodo do
			local clave = if camino == "" then nombre else camino .. "." .. nombre
			if typeof(valor) == "table" then
				recorrer(valor, clave)
			elseif typeof(valor) == "string" and not string.find(valor, "{", 1, true) and indice[valor] == nil then
				indice[valor] = clave
			end
		end
	end
	recorrer(ORIGINAL, "")
	inverso = indice
	return indice
end

-- "Excavar" -> "Dig": el texto exacto del original en el idioma activo; lo
-- que no reconoce lo devuelve tal cual (un nombre, un numero)
function Idioma.literal(texto: string, codigo: string?): string
	if (codigo or Idioma.codigo) == "es" then
		return texto
	end
	local clave = indiceInverso()[texto]
	return if clave then (Idioma.plantilla(clave, codigo) or texto) else texto
end

-- ===========================================================================
-- Definiciones de Config
-- ===========================================================================

function Idioma.nombre(categoria: string, def: Definicion): string
	return Idioma.plantilla("DEF." .. categoria .. "." .. def.id .. ".nombre") or def.nombre
end

function Idioma.descripcion(categoria: string, def: Definicion): string
	return Idioma.plantilla("DEF." .. categoria .. "." .. def.id .. ".descripcion") or def.descripcion or ""
end

-- ===========================================================================
-- Mayusculas (string.upper solo sabe ASCII: "montón" saldria "MONTóN")
-- ===========================================================================

local MAYUSCULAS_UTF8 = {
	["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü",
	["à"] = "À", ["â"] = "Â", ["ê"] = "Ê", ["ô"] = "Ô", ["ã"] = "Ã", ["õ"] = "Õ", ["ç"] = "Ç",
}

function Idioma.mayusculas(texto: string): string
	local resultado = string.upper(texto):gsub("\xC3[\xA0-\xBF]", function(letra: string)
		return MAYUSCULAS_UTF8[letra] or letra
	end)
	return resultado
end

-- ===========================================================================
-- Textos traducidos (lo que lee el cliente)
-- ===========================================================================

local function traducirArbol(nodo: { [string]: any }, camino: string): { [string]: any }
	local copia = {}
	for nombre, valor in nodo do
		local clave = if camino == "" then nombre else camino .. "." .. nombre
		if typeof(valor) == "table" then
			copia[nombre] = traducirArbol(valor, clave)
		elseif typeof(valor) == "string" then
			copia[nombre] = Idioma.plantilla(clave) or valor
		else
			copia[nombre] = valor -- formatear y demas funciones
		end
	end
	return copia
end

Idioma.textos = (traducirArbol(Textos :: any, "") :: any) :: typeof(Textos)

do
	local separadores = Traducciones.FORMATO[Idioma.codigo] or Traducciones.FORMATO.es
	Formato.configurar(separadores.miles, separadores.decimal)
end

return Idioma
