--!strict
--[[
	Menu (ModuleScript)
	Registro de paneles (Album, Tienda, Logros, Base, Reparacion, ...) y quien
	decide cual esta abierto. Solo hay UN panel abierto a la vez; abrir otro
	cierra el anterior.

	Gamepad: al abrir un panel se selecciona su primer boton
	(GuiService.SelectedObject) y ButtonB / Esc lo cierran. El HUD llama a
	alternar(nombre) desde sus botones; los paneles se registran al cargar.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utilidades = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades")
local Senal = require(Utilidades:WaitForChild("Senal"))
local Entrada = require(Utilidades:WaitForChild("Entrada"))

export type Panel = {
	abrir: (argumento: any?) -> (),
	cerrar: () -> (),
	estaAbierto: () -> boolean,
	primerSeleccionable: (() -> GuiObject?)?,
}

local Menu = {}

Menu.alCambiar = Senal.nueva() :: Senal.Senal<string?>

local paneles: { [string]: Panel } = {}
local abierto: string? = nil

function Menu.registrar(nombre: string, panel: Panel)
	paneles[nombre] = panel
end

function Menu.abierto(): string?
	return abierto
end

function Menu.hayAbierto(): boolean
	return abierto ~= nil
end

function Menu.cerrarTodo()
	local previo = abierto
	abierto = nil
	if previo and paneles[previo] then
		paneles[previo].cerrar()
	end
	GuiService.SelectedObject = nil
	if previo then
		Menu.alCambiar:Fire(nil)
	end
end

function Menu.abrir(nombre: string, argumento: any?)
	local panel = paneles[nombre]
	if not panel then
		warn("Menu: panel no registrado: " .. nombre)
		return
	end
	if abierto and abierto ~= nombre then
		local previo = paneles[abierto]
		abierto = nil
		if previo then
			previo.cerrar()
		end
	end
	abierto = nombre
	panel.abrir(argumento)
	-- Solo con gamepad: en PC fijar SelectedObject fuerza la navegacion por
	-- teclado y el raton deja de sentirse natural.
	task.defer(function()
		if abierto == nombre and panel.primerSeleccionable and Entrada.esGamepad() then
			local sel = panel.primerSeleccionable()
			if sel then
				GuiService.SelectedObject = sel
			end
		end
	end)
	Menu.alCambiar:Fire(nombre)
end

function Menu.alternar(nombre: string, argumento: any?)
	if abierto == nombre then
		Menu.cerrarTodo()
	else
		Menu.abrir(nombre, argumento)
	end
end

-- Un panel que se cierra solo (boton X) avisa aqui
function Menu.notificarCierre(nombre: string)
	if abierto == nombre then
		abierto = nil
		GuiService.SelectedObject = nil
		Menu.alCambiar:Fire(nil)
	end
end

return Menu
