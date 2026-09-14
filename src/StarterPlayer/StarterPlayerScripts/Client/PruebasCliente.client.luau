--!nonstrict
--[[
	PruebasCliente
	SOLO EN STUDIO. Expone ReplicatedStorage.EjecutarPruebaCliente
	(BindableFunction) con acciones con nombre que corren DENTRO de la VM del
	cliente (la de execute_luau es la del plugin y no comparte modulos):

	    Invoke("abrir", "Album", argumento)   Menu.abrir
	    Invoke("cerrar")                      Menu.cerrarTodo
	    Invoke("estado")                      resumen de EstadoCliente
	    Invoke("panel", "Album")              descripcion del panel abierto
	Fuera de Studio no crea nada.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

if not RunService:IsStudio() then
	return
end

local UI = script.Parent:WaitForChild("UI")
local Menu = require(UI:WaitForChild("Menu"))
local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))

local gancho = Instance.new("BindableFunction")
gancho.Name = "EjecutarPruebaCliente"
gancho.Parent = ReplicatedStorage

local acciones = {}

function acciones.abrir(nombre, argumento)
	Menu.abrir(nombre, argumento)
	task.wait(0.3)
	return "abierto: " .. tostring(Menu.abierto())
end

function acciones.cerrar()
	Menu.cerrarTodo()
	return "cerrado"
end

function acciones.estado()
	local p = EstadoCliente.perfil
	return string.format("perfil=%s cargado=%s modoDev=%s dinero=%s bolsa=%d/%d energia=%d/%d mascotas=%d",
		tostring(p ~= nil), tostring(EstadoCliente.cargado), tostring(EstadoCliente.modoDev), tostring(p and p.dinero),
		#EstadoCliente.bolsa.items, EstadoCliente.bolsa.capacidad, EstadoCliente.energia.actual, EstadoCliente.energia.max, EstadoCliente.cuentaMascotas())
end

function acciones.panel(nombre)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local sg = pg:FindFirstChild(nombre)
	if not sg then
		return "no existe " .. nombre
	end
	local botones, textos, viewports = 0, 0, 0
	for _, d in sg:GetDescendants() do
		if d:IsA("GuiButton") and d.Visible then
			botones += 1
		elseif d:IsA("TextLabel") and d.Visible then
			textos += 1
		elseif d:IsA("ViewportFrame") then
			viewports += 1
		end
	end
	return string.format("%s enabled=%s botones=%d textos=%d viewports=%d", nombre, tostring(sg.Enabled), botones, textos, viewports)
end

gancho.OnInvoke = function(nombre, ...)
	local accion = acciones[nombre]
	if not accion then
		return "accion desconocida: " .. tostring(nombre)
	end
	local ok, res = pcall(accion, ...)
	return ok and tostring(res) or ("error: " .. tostring(res))
end
