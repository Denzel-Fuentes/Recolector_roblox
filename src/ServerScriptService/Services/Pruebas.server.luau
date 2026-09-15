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

	Segunda via, por ATRIBUTOS: en algunas versiones de Studio el hilo del MCP
	no puede invocar BindableFunctions ("additional values for the
	Capabilities property"), pero si leer y escribir atributos. Escribir
	    ServerStorage:SetAttribute("Prueba", "nombre|arg1|arg2")
	ejecuta la prueba y deja el texto en el atributo "Resultado" (y lo imprime).
	Con SignalBehavior Deferred el handler de un cambio lee el valor ACTUAL, asi
	que dos escrituras seguidas ejecutarian dos veces la ultima: se antepone un
	numero de orden ("3:nombre|arg") y se ignoran los repetidos.
]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if not RunService:IsStudio() then
	return
end

local function ejecutar(nombre: string, ...): string
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

local gancho = Instance.new("BindableFunction")
gancho.Name = "EjecutarPrueba"
gancho.Parent = ServerStorage
gancho.OnInvoke = ejecutar

local ultimaOrden = nil
ServerStorage:GetAttributeChangedSignal("Prueba"):Connect(function()
	local orden = ServerStorage:GetAttribute("Prueba")
	if typeof(orden) ~= "string" or orden == "" or orden == ultimaOrden then
		return
	end
	ultimaOrden = orden
	orden = orden:gsub("^%d+:", "")
	ServerStorage:SetAttribute("Resultado", "")
	local partes = string.split(orden, "|")
	local nombre = table.remove(partes, 1)
	local args = {}
	for _, p in partes do
		table.insert(args, tonumber(p) or p)
	end
	local resultado = ejecutar(nombre, table.unpack(args))
	print("[Prueba " .. nombre .. "] " .. resultado)
	ServerStorage:SetAttribute("Resultado", resultado)
end)
