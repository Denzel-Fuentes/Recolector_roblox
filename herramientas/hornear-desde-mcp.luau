--!nonstrict
--[[
	hornear-desde-mcp.luau — HERRAMIENTA DE DISENO, no entra al juego.

	Lo mismo que construir-mundo.luau, pero para el hilo de execute_luau del
	MCP de Studio, que NO puede hacer require de los modulos del juego (falta
	la capacidad "LoadUnownedAsset"). Lo que si puede es leer `Source`,
	compilarlo con loadstring y crear partes: este `requiere` carga cada
	ModuleScript desde su Source con un entorno donde `require` es el mismo
	shim y `script` es el modulo (asi `script.Parent:WaitForChild(...)` y
	`ReplicatedStorage.Shared...` funcionan igual que en el juego).

	Se manda entero por execute_luau sobre el DataModel Edit (Studio parado).
	DESPUES HAY QUE GUARDAR EL PLACE (Ctrl+S): el mundo, las variantes de
	material (MaterialService) y las mallas de ServerStorage.Arte viven ahi.
]]

local cache = {}
local function requiere(modulo)
	if cache[modulo] ~= nil then
		return cache[modulo]
	end
	local fn, err = loadstring(modulo.Source, "=" .. modulo:GetFullName())
	if not fn then
		error("no compila " .. modulo:GetFullName() .. ": " .. tostring(err))
	end
	setfenv(fn, setmetatable({ require = requiere, script = modulo }, { __index = getfenv() }))
	local res = fn()
	cache[modulo] = res
	return res
end

local ok, res = xpcall(function()
	local ConstructorMundo = requiere(game:GetService("ServerStorage").Herramientas.ConstructorMundo)
	local mundo = ConstructorMundo.construir()
	local CS = game:GetService("CollectionService")
	return string.format(
		"v%s desc=%d ranuras=%d parcelas=%d contenedor=%d maquina=%d figurinas=%d",
		tostring(mundo:GetAttribute("Version")),
		#mundo:GetDescendants(),
		#CS:GetTagged("RanuraMonton"),
		#CS:GetTagged("Parcela"),
		#CS:GetTagged("Contenedor"),
		#CS:GetTagged("MaquinaRefrescos"),
		#CS:GetTagged("FigurinaFija")
	)
end, debug.traceback)
return tostring(ok) .. ": " .. tostring(res)
