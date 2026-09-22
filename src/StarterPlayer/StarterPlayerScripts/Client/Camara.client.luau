--!strict
--[[
	Camara
	Primera persona automatica dentro del patio (como en KOTAMON), la reticula
	(un punto en el centro en vez de la flecha del raton) y el arreglo del bug
	de los modales.

	  EnPatio = true   -> CameraMode LockFirstPerson, flecha oculta, punto visible
	  EnPatio = false  -> CameraMode Classic, flecha normal

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

	=== La reticula ===
	Con el raton bloqueado en el centro, Roblox sigue pintando la flecha ahi,
	que no parece una mira. En el patio (sin panel abierto y sin tactil) se
	oculta la flecha (MouseIconEnabled) y se dibuja un punto en el centro de
	la pantalla: es donde sale el rayo de recoger y de lanzar. Un anillo fino
	alrededor crece cuando hay un objeto al alcance bajo la mira (el Highlight
	de ControlPatio), para que "se puede recoger" se vea sin mirar la basura.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local Entrada = require(Shared:WaitForChild("Utilidades"):WaitForChild("Entrada"))

local UI = script.Parent:WaitForChild("UI")
local Menu = require(UI:WaitForChild("Menu"))

local jugador = Players.LocalPlayer
local NOMBRE_PASO = "ReciclatasLiberarRaton"
local liberando = false

-- === Reticula ===
local pantalla = Instance.new("ScreenGui")
pantalla.Name = "Reticula"
pantalla.ResetOnSpawn = false
pantalla.IgnoreGuiInset = true -- el centro de la pantalla es el centro del viewport (el del rayo)
pantalla.DisplayOrder = 5
pantalla.Enabled = false
-- Punto de papel con contorno de tinta y un anillo fino alrededor; el anillo
-- crece cuando ControlPatio resalta un objeto al alcance (workspace.
-- ResaltadoObjeto): es la confirmacion de "esto se puede recoger".
local function circulo(nombre: string, diametro: number, relleno: boolean): Frame
	local f = Instance.new("Frame")
	f.Name = nombre
	f.Size = UDim2.fromOffset(diametro, diametro)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = Paleta.UI_PAPEL
	f.BackgroundTransparency = if relleno then 0 else 1
	f.BorderSizePixel = 0
	f.Parent = pantalla
	local redondo = Instance.new("UICorner")
	redondo.CornerRadius = UDim.new(1, 0)
	redondo.Parent = f
	local borde = Instance.new("UIStroke")
	borde.Color = Paleta.UI_TINTA
	borde.Thickness = if relleno then 1.5 else 2
	borde.Transparency = if relleno then 0 else 0.35
	borde.Parent = f
	return f
end
circulo("Punto", 7, true)
local anillo = circulo("Anillo", 22, false)
pantalla.Parent = jugador:WaitForChild("PlayerGui")

local resaltado = workspace:FindFirstChild("ResaltadoObjeto")
local function seguirResaltado()
	if not resaltado or not resaltado:IsA("Highlight") then
		return
	end
	resaltado:GetPropertyChangedSignal("Enabled"):Connect(function()
		local d = if resaltado.Enabled then 30 else 22
		TweenService:Create(anillo, TweenInfo.new(0.1), { Size = UDim2.fromOffset(d, d) }):Play()
		local borde = anillo:FindFirstChildOfClass("UIStroke")
		if borde then
			borde.Transparency = if resaltado.Enabled then 0 else 0.35
		end
	end)
end
if resaltado then
	seguirResaltado()
else
	workspace.ChildAdded:Connect(function(hijo)
		if hijo.Name == "ResaltadoObjeto" and not resaltado then
			resaltado = hijo
			seguirResaltado()
		end
	end)
end

local function enPatio(): boolean
	return jugador:GetAttribute("EnPatio") == true
end

local function actualizarReticula()
	local mostrar = enPatio() and not Menu.hayAbierto() and not Entrada.esTactil()
	pantalla.Enabled = mostrar
	if not liberando then
		UserInputService.MouseIconEnabled = not mostrar
	end
end

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
	actualizarReticula()
end

local function aplicarCamara()
	if enPatio() then
		jugador.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		jugador.CameraMode = Enum.CameraMode.Classic
	end
	actualizarReticula()
end

jugador:GetAttributeChangedSignal("EnPatio"):Connect(aplicarCamara)
jugador.CharacterAdded:Connect(function()
	task.defer(aplicarCamara)
end)
Menu.alCambiar:Connect(function(nombre)
	liberarRaton(nombre ~= nil)
end)
UserInputService.LastInputTypeChanged:Connect(actualizarReticula)
aplicarCamara()
liberarRaton(Menu.hayAbierto())
