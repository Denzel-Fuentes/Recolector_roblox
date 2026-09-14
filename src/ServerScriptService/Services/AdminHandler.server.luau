--!strict
--[[
	AdminHandler
	Comandos de chat para desarrollo y pruebas (TextChatService). Solo para
	Admin.esAdmin. Sirven para llegar a cualquier punto del juego sin jugar
	horas: probar el Contenedor Dorado, el Rey, la tienda con gemas, etc.

	    /dar dinero 5000       /dar gemas 300
	    /dar mascota latita 3  (id, estado 1..5, opcional "sucia")
	    /dar fragmentos tapita /dar figurina F7   /dar cinta C1   /dar traje T2
	    /dar todas             (una copia Regular de las 40: corona al Rey)
	    /maxmejoras            /pases on|off      /repoblar
	    /reset                 (perfil por defecto en memoria; se guarda al salir)
	    /energia               (barra llena)

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
local Energia = require(Servicios:WaitForChild("Energia"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))
local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Botin = require(Servicios:WaitForChild("Botin"))
local Parcelas = require(Servicios:WaitForChild("Parcelas"))

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
	elseif que == "gemas" then
		Economia.ganarGemas(jugador, tonumber(args[2]) or 100)
		return "gemas: " .. Economia.gemas(jugador)
	elseif que == "mascota" then
		local id = args[2] or ""
		if not DefinicionesMascotas.obtener(id) then
			return "mascota desconocida: " .. id
		end
		local uid = Mascotas.agregar(jugador, id, tonumber(args[3]) or 2, args[4] == "sucia")
		return if uid then ("copia " .. uid .. " de " .. id) else "no cabe en el almacen"
	elseif que == "fragmentos" then
		local id = args[2] or ""
		if not DefinicionesMascotas.obtener(id) then
			return "mascota desconocida: " .. id
		end
		for _ = 1, GameConfig.FRAGMENTOS_POR_MASCOTA do
			Mascotas.agregarFragmento(jugador, id)
		end
		return "fragmentos de " .. id .. ": " .. Mascotas.fragmentos(jugador, id)
	elseif que == "figurina" or que == "cinta" or que == "traje" then
		local nuevo = Coleccionables.agregar(jugador, que, args[2] or "")
		Parcelas.renderizarPronto(jugador)
		return que .. " " .. tostring(args[2]) .. (if nuevo then " anadida" else " ya la tenias o no existe")
	elseif que == "todas" then
		local n = 0
		for _, def in DefinicionesMascotas.LISTA do
			if def.rareza ~= "Mitica" and not Mascotas.tiene(jugador, def.id) then
				if Mascotas.agregar(jugador, def.id, 2, false) then
					n += 1
				end
			end
		end
		return n .. " mascotas anadidas; Rey=" .. tostring(Mascotas.tiene(jugador, DefinicionesMascotas.ID_REY))
	end
	return "uso: /dar dinero|gemas|mascota|fragmentos|figurina|cinta|traje|todas ..."
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
		return "las 7 mejoras al maximo"
	end,
	pases = function(_jugador, args)
		Monetizacion.fijarModoDev(args[1] == "on")
		return "modo dev de pases: " .. tostring(Monetizacion.modoDev())
	end,
	repoblar = function()
		Botin.repoblarAhora()
		return "montones repoblados"
	end,
	energia = function(jugador)
		Energia.fijar(jugador, Energia.maxima(jugador))
		return "energia llena"
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
		Parcelas.renderizarPronto(jugador)
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
