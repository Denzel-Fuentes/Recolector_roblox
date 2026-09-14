--!strict
--[[
	Prompts
	Los ProximityPrompts que SOLO abren interfaz se atienden en el cliente, sin
	pasar por el servidor: los muebles de la parcela (atributo Mueble) y el
	dialogo de Dona Chatarra (DialogoEvent, que el servidor manda tras el
	prompt "Hablar").

	  Telefono        -> Tienda
	  Almacen         -> Album
	  MesaReparacion  -> Reparacion
	  Estanteria / Radio / Exhibidor -> Base (en esa pestana)

	Solo en TU parcela. En la de otro, el prompt muestra de quien es: visitar
	es mirar, no tocar (GDD: like/visita, sin edicion ajena).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local UI = script.Parent:WaitForChild("UI")
local Menu = require(UI:WaitForChild("Menu"))
local Notificaciones = require(UI:WaitForChild("Notificaciones"))

local jugador = Players.LocalPlayer

local PANEL_POR_MUEBLE = {
	Telefono = { "Tienda", nil },
	Almacen = { "Album", nil },
	MesaReparacion = { "Reparacion", nil },
	Estanteria = { "Base", "estanteria" },
	Radio = { "Base", "radio" },
	Exhibidor = { "Base", "exhibidor" },
}

local function parcelaDe(inst: Instance): Model?
	local actual: Instance? = inst
	while actual and actual ~= workspace do
		if actual:IsA("Model") and actual:GetAttribute("IndiceParcela") ~= nil then
			return actual
		end
		actual = actual.Parent
	end
	return nil
end

local function muebleDe(inst: Instance): string?
	local actual: Instance? = inst
	while actual and actual ~= workspace do
		local mueble = actual:GetAttribute("Mueble")
		if typeof(mueble) == "string" then
			return mueble
		end
		actual = actual.Parent
	end
	return nil
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, quien)
	if quien ~= jugador then
		return
	end
	local mueble = muebleDe(prompt)
	if not mueble then
		return
	end
	local destino = PANEL_POR_MUEBLE[mueble]
	if not destino then
		return
	end
	local parcela = parcelaDe(prompt)
	if parcela and parcela:GetAttribute("Dueno") ~= jugador.UserId then
		local nombre = parcela:GetAttribute("NombreDueno")
		if nombre then
			Notificaciones.mostrar(Textos.formatear(Textos.BASE.visitando, { nombre = nombre }), "info")
		else
			Notificaciones.mostrar(Textos.BASE.parcelaLibre, "info")
		end
		return
	end
	Menu.abrir(destino[1], destino[2])
end)

Red.evento("DialogoEvent").OnClientEvent:Connect(function(npc, texto, abrirTienda)
	if typeof(texto) == "string" then
		Notificaciones.mostrar("Doña Chatarra: " .. texto, "info")
	end
	if abrirTienda then
		task.delay(0.4, function()
			Menu.abrir("Tienda")
		end)
	end
end)
