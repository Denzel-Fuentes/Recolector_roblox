--!strict
--[[
	Paneles
	Carga todos los paneles (cada modulo se registra en Menu al cargarse) y
	pone los atajos globales: Esc / ButtonB cierran el panel abierto, y las
	teclas de acceso rapido abren la Tienda (Q o T), Rebirth (R) y Pedidos
	(P) (las que aun no existen se ignoran).

	Los paneles se buscan por nombre y se ignoran los que no existan, para que
	el juego arranque aunque una fase aun no este escrita. Ajustes (el panel
	del boton Sonido, A1) no tiene atajo de teclado.

	Y el sonido de abrir y cerrar ventanas (Client/Sonido): "panelAbrir" al
	pasar a un panel (tambien de uno a otro), "panelCerrar" al volver a no
	tener ninguno. Por Menu.alCambiar: suena igual se abra con el boton, el
	atajo, el prompt de la tienda o la pildora del tutorial.
]]

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent
local Menu = require(UI:WaitForChild("Menu"))
local Sonido = require(UI.Parent:WaitForChild("Sonido"))

local PANELES = { "Tienda", "Rebirth", "Pedidos", "Ajustes" }

-- (abrir el que ya estaba abierto, p. ej. el prompt de la tienda con la
-- tienda delante, vuelve a avisar: sin cambio, sin sonido)
local ultimoPanel: string? = nil
Menu.alCambiar:Connect(function(nombre: string?)
	if nombre == ultimoPanel then
		return
	end
	ultimoPanel = nombre
	Sonido.tocar(if nombre then "panelAbrir" else "panelCerrar")
end)

for _, nombre in PANELES do
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
	[Enum.KeyCode.T] = "Tienda",
	[Enum.KeyCode.R] = "Rebirth",
	[Enum.KeyCode.P] = "Pedidos",
}

UserInputService.InputBegan:Connect(function(input, procesado)
	if procesado then
		return
	end
	local panel = ATAJOS[input.KeyCode]
	if panel and UI:FindFirstChild(panel) then
		Menu.alternar(panel)
	end
end)
