--!strict
--[[
	AdminHandler
	Comandos de chat para desarrollo y pruebas (TextChatService). Solo para
	Admin.esAdmin. Sirven para llegar a cualquier punto del juego sin jugar
	horas.

	    /dar dinero 5000
	    /dar mascota latita (una mas: nueva, o sube de nivel)
	    /dar fragmento Plastin 3 (fragmentos de ese set, como reciclados)
	    /dar todas         (una de cada una de las 40: corona al Rey)
	    /dar figurina F7   /dar cinta C1   /dar traje T2
	    /maxmejoras        /pases on|off   /repoblar
	    /rebirths 2        (fija cuantos rebirths tiene; abre sus cuadrantes)
	    /tutorial 0        (pasos del tutorial completados)
	    /reset             (perfil por defecto en memoria; se guarda al salir)

	Responde por NotificacionEvent. Los comandos se registran como
	TextChatCommand para que el chat los reconozca y no los publique.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local DefinicionesMascotas = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMascotas"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Admin = require(Servicios:WaitForChild("Admin"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Botin = require(Servicios:WaitForChild("Botin"))
local Tutorial = require(Servicios:WaitForChild("Tutorial"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))
local Fragmentos = require(Servicios:WaitForChild("Fragmentos"))

local NotificacionEvent = Red.evento("NotificacionEvent")

local function responder(jugador: Player, texto: string)
	NotificacionEvent:FireClient(jugador, "[admin] " .. texto, "info")
end

local function dar(jugador: Player, args: { string })
	local que = args[1]
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return "sin perfil"
	end
	if que == "dinero" then
		Economia.ganar(jugador, tonumber(args[2]) or 1000)
		return "dinero: " .. Economia.dinero(jugador)
	elseif que == "mascota" then
		local id = args[2] or ""
		if not DefinicionesMascotas.obtener(id) then
			return "mascota desconocida: " .. id
		end
		local r = Mascotas.agregar(jugador, id)
		return string.format("%s nivel %d%s", id, r.nivel, if r.dinero > 0 then " (+$" .. r.dinero .. ")" else "")
	elseif que == "fragmento" then
		local set = args[2] or "Plastin"
		local ultimo = nil
		for _ = 1, math.clamp(tonumber(args[3]) or 1, 1, 100) do
			ultimo = Fragmentos.agregar(jugador, set, "admin") or ultimo
		end
		if not ultimo then
			return "set desconocido o cerrado: " .. set
		end
		return string.format("%s: %s %d/%d%s", set, ultimo.id, ultimo.n, ultimo.total, if ultimo.completa then " (completada)" else "")
	elseif que == "todas" then
		local n = 0
		for _, def in DefinicionesMascotas.LISTA do
			if def.id ~= DefinicionesMascotas.ID_REY and not Mascotas.tiene(jugador, def.id) then
				Mascotas.agregar(jugador, def.id)
				n += 1
			end
		end
		return string.format("%d mascotas anadidas; coleccion %d/40; rey=%s", n, Mascotas.distintas(jugador), tostring(Mascotas.tiene(jugador, DefinicionesMascotas.ID_REY)))
	elseif que == "figurina" or que == "cinta" or que == "traje" then
		local nuevo = Coleccionables.agregar(jugador, que, args[2] or "")
		return que .. " " .. tostring(args[2]) .. (if nuevo then " anadida" else " ya la tenias o no existe")
	end
	return "uso: /dar dinero|mascota|fragmento|todas|figurina|cinta|traje ..."
end

local COMANDOS: { [string]: (Player, { string }) -> string } = {
	dar = dar,
	maxmejoras = function(jugador)
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
	pases = function(_jugador, args)
		Monetizacion.fijarModoDev(args[1] == "on")
		return "modo dev de pases: " .. tostring(Monetizacion.modoDev())
	end,
	repoblar = function()
		Botin.repoblarAhora()
		return "montones repoblados"
	end,
	rebirths = function(jugador, args)
		local perfil = Perfiles.obtener(jugador)
		if not perfil then
			return "sin perfil"
		end
		perfil.rebirths = math.max(0, math.floor(tonumber(args[1]) or 0))
		Perfiles.marcarSucio(jugador)
		return "rebirths: " .. perfil.rebirths
	end,
	tutorial = function(jugador, args)
		Tutorial.fijar(jugador, tonumber(args[1]) or 0)
		return "tutorial: " .. Tutorial.completados(jugador) .. " pasos completados"
	end,
	reset = function(jugador)
		local nuevo = Perfiles.porDefecto()
		local actual = Perfiles.obtener(jugador)
		if actual then
			for clave, valor in pairs(nuevo :: any) do
				(actual :: any)[clave] = valor
			end
		end
		Perfiles.marcarSucio(jugador)
		Coleccionables.vestir(jugador)
		Mejoras.aplicarVelocidad(jugador)
		return "perfil reiniciado (se guardara asi al salir)"
	end,
}

local function registrar(nombre: string)
	local comando = Instance.new("TextChatCommand")
	comando.Name = "Admin_" .. nombre
	comando.PrimaryAlias = "/" .. nombre
	comando.Parent = TextChatService
	comando.Triggered:Connect(function(origen: TextSource, textoCompleto: string)
		local jugador = game:GetService("Players"):GetPlayerByUserId(origen.UserId)
		if not jugador or not Admin.esAdmin(jugador) then
			return
		end
		local args = {}
		for palabra in textoCompleto:gmatch("%S+") do
			table.insert(args, palabra)
		end
		table.remove(args, 1)
		local ok, resultado = pcall(COMANDOS[nombre], jugador, args)
		responder(jugador, if ok then tostring(resultado) else ("error: " .. tostring(resultado)))
	end)
end

for nombre in COMANDOS do
	registrar(nombre)
end
