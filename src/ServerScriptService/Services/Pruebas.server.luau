--!nonstrict
--[[
	Pruebas
	SOLO EN STUDIO. Expone ServerStorage.EjecutarPrueba (BindableFunction):
	    EjecutarPrueba:Invoke(nombre, ...) -> resultado (string)
	que ejecuta la prueba con ese nombre de Services/PruebasDefinidas DENTRO de
	la VM del servidor.

	Por que existe: la herramienta execute_luau del MCP corre en la VM del
	plugin de Studio; alli require() devuelve COPIAS de los modulos con estado
	vacio, asi que no sirve para inspeccionar perfiles, bolsas o montones
	reales. Este gancho si: las pruebas corren con los mismos modulos que usan
	los scripts del juego. Fuera de Studio no crea nada.
]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
	return
end

local gancho = Instance.new("BindableFunction")
gancho.Name = "EjecutarPrueba"
gancho.Parent = ServerStorage

gancho.OnInvoke = function(nombre: string, ...)
	local ok, Pruebas = pcall(require, script.Parent:WaitForChild("PruebasDefinidas"))
	if not ok then
		return "error cargando PruebasDefinidas: " .. tostring(Pruebas)
	end
	local prueba = Pruebas[nombre]
	if not prueba then
		local nombres = {}
		for k in Pruebas do
			table.insert(nombres, k)
		end
		table.sort(nombres)
		return "no existe la prueba " .. tostring(nombre) .. ". Hay: " .. table.concat(nombres, ", ")
	end
	local exito, resultado = pcall(prueba, ...)
	if not exito then
		return "error: " .. tostring(resultado)
	end
	return tostring(resultado)
end
