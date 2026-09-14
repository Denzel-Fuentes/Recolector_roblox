--!strict
--[[
	Camara
	Primera persona automatica dentro del patio (como en KOTAMON) y el arreglo
	del bug de los modales.

	  EnPatio = true   -> CameraMode LockFirstPerson
	  EnPatio = false  -> CameraMode Classic

	=== El bug ===
	En primera persona el script de camara de Roblox bloquea el raton en el
	centro (MouseBehavior LockCenter) en CADA frame, en su paso de render
	(RenderPriority.Camera). Un modal abierto solo se puede manejar con
	teclado. Ponerle MouseBehavior = Default una vez no sirve: al frame
	siguiente vuelve a estar bloqueado. Y cambiar CameraMode a Classic tampoco
	basta, porque con el zoom a distancia de primera persona el script sigue
	considerandose "en primera persona" y bloquea igual.

	Lo que si funciona: mientras hay un panel abierto, un BindToRenderStep con
	prioridad Camera + 1 (es decir, DESPUES del script de camara) que deja el
	raton libre y el cursor visible. Al cerrar el panel se desengancha y la
	primera persona vuelve a bloquear el raton sola. La vista no salta.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent:WaitForChild("UI")
local Menu = require(UI:WaitForChild("Menu"))

local jugador = Players.LocalPlayer
local NOMBRE_PASO = "ReciclatasLiberarRaton"
local liberando = false

local function liberarRaton(activo: boolean)
	if activo == liberando then
		return
	end
	liberando = activo
	if activo then
		RunService:BindToRenderStep(NOMBRE_PASO, Enum.RenderPriority.Camera.Value + 1, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	else
		RunService:UnbindFromRenderStep(NOMBRE_PASO)
	end
end

local function aplicarCamara()
	if jugador:GetAttribute("EnPatio") == true then
		jugador.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		jugador.CameraMode = Enum.CameraMode.Classic
	end
end

jugador:GetAttributeChangedSignal("EnPatio"):Connect(aplicarCamara)
jugador.CharacterAdded:Connect(function()
	task.defer(aplicarCamara)
end)
Menu.alCambiar:Connect(function(nombre)
	liberarRaton(nombre ~= nil)
end)
aplicarCamara()
liberarRaton(Menu.hayAbierto())
