--!strict
--[[
	Admin (ModuleScript)
	Unica responsabilidad: los comandos de desarrollo y quien puede usarlos.
	AdminHandler solo los cablea al chat.

	=== Solo en Studio (decision del usuario, 22 oct) ===
	En el juego publicado no hay admins ni comandos: AdminHandler no crea los
	TextChatCommand y esAdmin es false para todos, el creador incluido. En
	Studio todos los de la sesion son admin y los comandos no salen en el
	autocompletado del chat (AutocompleteVisible = false). "Estar en Studio"
	es esStudio(), sustituible en pruebas.

	    /dar dinero 5000   (1..TOPE_DINERO; no cuenta como dinero ganado:
	                        ni estadisticas, ni rankings, ni insignias)
	    /dar figurina F7   /dar cinta C1
	    /maxmejoras        /pases on|off   /repoblar
	    /rebirths 2        (0..TOPE_REBIRTHS; abre sus materiales)
	    /tutorial 0        (pasos del tutorial completados)
	    /reset             (perfil por defecto en memoria; se guarda al salir)
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Botin = require(Servicios:WaitForChild("Botin"))
local Tutorial = require(Servicios:WaitForChild("Tutorial"))

local Admin = {}

-- Sustituible en pruebas
Admin.esStudio = function(): boolean
	return RunService:IsStudio()
end

-- Lo que puede dar un /dar dinero de una vez, y hasta donde llegan los
-- rebirths: de sobra para probar cualquier punto del juego, y sin numeros
-- que rompan el formato o los multiplicadores
Admin.TOPE_DINERO = 1e9
Admin.TOPE_REBIRTHS = 20

function Admin.esAdmin(_jugador: Player): boolean
	return Admin.esStudio()
end

-- Un numero de verdad (ni nil, ni NaN, ni infinito), entero
local function entero(texto: string?): number?
	local n = tonumber(texto)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return math.floor(n)
end

local function dar(jugador: Player, args: { string }): string
	local que = args[1]
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return "sin perfil"
	end
	if que == "dinero" then
		local cantidad = if args[2] == nil then 1000 else entero(args[2])
		if not cantidad or cantidad < 1 or cantidad > Admin.TOPE_DINERO then
			return string.format("uso: /dar dinero <1..%d>", Admin.TOPE_DINERO)
		end
		-- Directo al saldo, sin Economia.ganar: no es dinero ganado (no sube
		-- dineroGanadoTotal ni dineroMaximo, ni los rankings ni las insignias)
		perfil.dinero += cantidad
		Perfiles.marcarSucio(jugador)
		return "dinero: " .. perfil.dinero
	elseif que == "figurina" or que == "cinta" then
		local nuevo = Coleccionables.agregar(jugador, que, args[2] or "")
		return que .. " " .. tostring(args[2]) .. (if nuevo then " anadida" else " ya la tenias o no existe")
	end
	return "uso: /dar dinero|figurina|cinta ..."
end

Admin.COMANDOS = {
	dar = dar,
	maxmejoras = function(jugador: Player, _args: { string }): string
		local perfil = Perfiles.obtener(jugador)
		if not perfil then
			return "sin perfil"
		end
		for id in perfil.mejoras do
			perfil.mejoras[id] = GameConfig.NIVEL_MAX_MEJORA
		end
		Perfiles.marcarSucio(jugador)
		Mejoras.aplicarVelocidad(jugador)
		return "las mejoras al maximo"
	end,
	pases = function(_jugador: Player, args: { string }): string
		Monetizacion.fijarModoDev(args[1] == "on")
		return "modo dev de pases: " .. tostring(Monetizacion.modoDev())
	end,
	repoblar = function(_jugador: Player, _args: { string }): string
		Botin.repoblarAhora()
		return "montones repoblados"
	end,
	rebirths = function(jugador: Player, args: { string }): string
		local perfil = Perfiles.obtener(jugador)
		if not perfil then
			return "sin perfil"
		end
		local n = entero(args[1])
		if not n then
			return string.format("uso: /rebirths <0..%d>", Admin.TOPE_REBIRTHS)
		end
		perfil.rebirths = math.clamp(n, 0, Admin.TOPE_REBIRTHS)
		Perfiles.marcarSucio(jugador)
		return "rebirths: " .. perfil.rebirths
	end,
	tutorial = function(jugador: Player, args: { string }): string
		Tutorial.fijar(jugador, entero(args[1]) or 0)
		return "tutorial: " .. Tutorial.completados(jugador) .. " pasos completados"
	end,
	reset = function(jugador: Player, _args: { string }): string
		local nuevo = Perfiles.porDefecto()
		local actual = Perfiles.obtener(jugador)
		if actual then
			for clave, valor in pairs(nuevo :: any) do
				(actual :: any)[clave] = valor
			end
		end
		Perfiles.marcarSucio(jugador)
		Mejoras.aplicarVelocidad(jugador)
		return "perfil reiniciado (se guardara asi al salir)"
	end,
} :: { [string]: (Player, { string }) -> string }

-- Ejecuta un comando y devuelve la respuesta; nil si no es admin o no
-- existe (no se le responde nada: fuera de Studio no hay comandos)
function Admin.ejecutar(jugador: Player, nombre: string, args: { string }): string?
	local comando = Admin.COMANDOS[nombre]
	if not comando or not Admin.esAdmin(jugador) then
		return nil
	end
	local ok, resultado = pcall(comando, jugador, args)
	return if ok then tostring(resultado) else ("error: " .. tostring(resultado))
end

-- Crea un TextChatCommand por comando en `padre` (solo en Studio; si no,
-- ninguno) y llama a alDisparar(jugador, nombre, args) al usarlo.
function Admin.crearComandos(padre: Instance, alDisparar: (Player, string, { string }) -> ()): { TextChatCommand }
	local creados = {}
	if not Admin.esStudio() then
		return creados
	end
	for nombre in Admin.COMANDOS do
		local comando = Instance.new("TextChatCommand")
		comando.Name = "Admin_" .. nombre
		comando.PrimaryAlias = "/" .. nombre
		comando.AutocompleteVisible = false
		comando.Triggered:Connect(function(origen: TextSource, textoCompleto: string)
			local jugador = game:GetService("Players"):GetPlayerByUserId(origen.UserId)
			if not jugador then
				return
			end
			local args = {}
			for palabra in textoCompleto:gmatch("%S+") do
				table.insert(args, palabra)
			end
			table.remove(args, 1)
			alDisparar(jugador, nombre, args)
		end)
		comando.Parent = padre
		table.insert(creados, comando)
	end
	return creados
end

return Admin
