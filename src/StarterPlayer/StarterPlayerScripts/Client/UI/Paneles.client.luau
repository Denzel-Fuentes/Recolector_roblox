--!strict
--[[
	Paneles
	Carga todos los paneles (cada modulo se registra en Menu al cargarse) y
	pone los atajos globales: Esc / ButtonB cierran el panel abierto, y las
	teclas de acceso rapido abren Tienda/telefono (Q), Album (J), Logros (L) y Base (B).

	Los paneles se buscan por nombre y se ignoran los que no existan, para que
	el juego arranque aunque una fase aun no este escrita.
]]

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent
local Menu = require(UI:WaitForChild("Menu"))

for _, nombre in { "Album", "Reparacion", "Tienda", "Logros", "Base", "Probabilidades" } do
	local modulo = UI:FindFirstChild(nombre)
	if modulo and modulo:IsA("ModuleScript") then
		local ok, err = pcall(require, modulo)
		if not ok then
			warn("Paneles: no se pudo cargar " .. nombre .. ": " .. tostring(err))
		end
	end
end

local function cerrar(_nombre: string, estado: Enum.UserInputState)
	if estado ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if Menu.hayAbierto() then
		Menu.cerrarTodo()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction("CerrarPanel", cerrar, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Escape)

local ATAJOS = {
	[Enum.KeyCode.Q] = "Tienda", -- telefono, como en KOTAMON
	[Enum.KeyCode.J] = "Album",
	[Enum.KeyCode.T] = "Tienda",
	[Enum.KeyCode.L] = "Logros",
	[Enum.KeyCode.B] = "Base",
}

UserInputService.InputBegan:Connect(function(input, procesado)
	if procesado then
		return
	end
	local panel = ATAJOS[input.KeyCode]
	if panel then
		Menu.alternar(panel)
	elseif input.KeyCode == Enum.KeyCode.ButtonSelect then
		Menu.alternar("Album")
	end
end)
