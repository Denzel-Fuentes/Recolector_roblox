--!strict
--[[
	Cosmeticos (ModuleScript)
	Unica responsabilidad: que diseno de bolsa y que estela lleva cada
	jugador (perfil.disenoBolsa, perfil.estela; Config/DefinicionesCosmeticos)
	y validar que solo se pone lo que tiene. Quien pinta la bolsa (Patio, la
	de las manos; Lanzamiento, la lanzada) pregunta aqui y escucha alCambiar.

	Si un jugador deja de tener algo puesto (un pase reembolsado, el modo dev
	de pases apagado), se le quita al consultarlo: nunca se ve un cosmetico
	que no se tiene.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefinicionesCosmeticos = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesCosmeticos"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))

local Cosmeticos = {}

-- (jugador) al ponerse o quitarse algo
Cosmeticos.alCambiar = Senal.nueva() :: Senal.Senal<Player>

local CAMPO = { bolsa = "disenoBolsa", estela = "estela" }

function Cosmeticos.tiene(jugador: Player, tipo: string, id: string): boolean
	local def = DefinicionesCosmeticos.obtener(tipo, id)
	local perfil = Perfiles.obtener(jugador)
	if not def or not perfil then
		return false
	end
	return DefinicionesCosmeticos.loTiene(def, perfil.rebirths, function(pase)
		return Monetizacion.tienePase(jugador, pase)
	end)
end

-- Lo que lleva puesto de un tipo (la definicion), o nil
function Cosmeticos.puesto(jugador: Player, tipo: string): any
	local perfil = Perfiles.obtener(jugador)
	local campo = CAMPO[tipo]
	local id = perfil and campo and (perfil :: any)[campo]
	if typeof(id) ~= "string" then
		return nil
	end
	if not Cosmeticos.tiene(jugador, tipo, id) then
		return nil
	end
	return DefinicionesCosmeticos.obtener(tipo, id)
end

-- Pone (id) o quita (nil) un cosmetico. Devuelve si se pudo.
function Cosmeticos.equipar(jugador: Player, tipo: string, id: string?): boolean
	local perfil = Perfiles.obtener(jugador)
	local campo = CAMPO[tipo]
	if not perfil or not campo then
		return false
	end
	if id ~= nil and not Cosmeticos.tiene(jugador, tipo, id) then
		return false
	end
	;(perfil :: any)[campo] = id
	Perfiles.marcarSucio(jugador)
	Cosmeticos.alCambiar:Fire(jugador)
	return true
end

-- Al cambiar los pases (compra, modo dev) lo que se ve puede cambiar
Monetizacion.alCambiarPases:Connect(function(jugador)
	Cosmeticos.alCambiar:Fire(jugador)
end)

return Cosmeticos
