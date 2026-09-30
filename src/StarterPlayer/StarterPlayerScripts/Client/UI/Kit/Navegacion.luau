--!strict
--[[
	Navegacion (ModuleScript)
	Unica responsabilidad: ayudar a Menu a elegir que boton se selecciona al
	abrir un panel con gamepad. Sin Fusion: recorre instancias ya montadas.

	  Navegacion.primerSeleccionable(raiz) -> GuiObject?
	  (el primer GuiButton visible y Selectable dentro de raiz, en orden de
	  arbol; los Botones del Kit exponen su "Cuerpo")
]]

local Navegacion = {}

local function visibleDeVerdad(obj: GuiObject, raiz: Instance): boolean
	local actual: Instance? = obj
	while actual and actual ~= raiz do
		if actual:IsA("GuiObject") and not actual.Visible then
			return false
		end
		actual = actual.Parent
	end
	return true
end

function Navegacion.primerSeleccionable(raiz: Instance?): GuiObject?
	if not raiz then
		return nil
	end
	for _, d in raiz:GetDescendants() do
		if d:IsA("GuiButton") and d.Selectable and visibleDeVerdad(d, raiz) then
			return d
		end
	end
	return nil
end

return Navegacion
