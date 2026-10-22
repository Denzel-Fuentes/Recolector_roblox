--!strict
--[[
	Camara
	La vista del jugador en TODO el mapa (peticion del usuario, 6 oct: antes
	solo en el patio): primera persona, o tercera persona sobre el hombro
	(lote 9); la V o el boton del HUD cambian entre las dos, dentro o fuera
	del patio. Ademas la reticula (un punto en el centro en vez de la flecha
	del raton) y el arreglo del bug de los modales.

	  primera  -> CameraMode LockFirstPerson, flecha oculta, punto visible
	  tercera  -> CameraMode Classic a DISTANCIA_TERCERA sobre el hombro,
	              raton bloqueado al centro, el personaje girando con la
	              camara y el punto visible

	(Hasta el 6 oct, fuera del patio la camara era la Classic libre de
	Roblox y al salir se restauraba el zoom con que se entro; ya no hay
	camara libre, asi que eso se quito.)

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
	que no parece una mira. Sin panel abierto (en todo el mapa) se oculta la
	flecha (MouseIconEnabled) y se dibuja un punto en el centro de la
	pantalla: es donde sale el rayo de recoger y de lanzar. Un anillo fino
	alrededor crece cuando hay un objeto al alcance bajo la mira (el Highlight
	de ControlPatio), para que "se puede recoger" se vea sin mirar la basura.
	Tambien en tactil (29 sep: antes se ocultaba porque en el movil se recoge
	tocando la basura, y el usuario echaba de menos la mira para apuntar;
	ahora lanzar apunta a ella y recoge lo que tiene debajo, ver ControlPatio).

	=== Tercera persona (lote 9) ===
	Se cambia con la V o con el boton del HUD, y se guarda en el perfil
	(perfil.camara, CamaraEvent). La eleccion vive en el atributo LOCAL
	"Vista" del jugador ("primera" | "tercera"): el HUD y las manos 2D (que
	solo se ven en primera) lo leen sin depender de este script. En tercera
	la mira sigue siendo el centro de la pantalla, asi que recoger y lanzar
	funcionan igual (ControlPatio ya excluye al propio personaje del rayo).
	Es un "shift lock" propio: raton al centro y el personaje mirando hacia
	donde mira la camara, para que la bolsa y los brazos queden delante.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local UI = script.Parent:WaitForChild("UI")
local Menu = require(UI:WaitForChild("Menu"))
local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))

local CamaraEvent = Red.evento("CamaraEvent")

local jugador = Players.LocalPlayer
local NOMBRE_PASO = "ReciclatasLiberarRaton"
local NOMBRE_TERCERA = "ReciclatasTerceraPersona"
local liberando = false

-- Tercera persona: distancia de la camara y desplazamiento sobre el hombro
local DISTANCIA_TERCERA = 11
local HOMBRO = Vector3.new(1.8, 0.6, 0)

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

local function vistaTercera(): boolean
	return jugador:GetAttribute("Vista") == "tercera"
end

local function humanoide(): Humanoid?
	local personaje = jugador.Character
	return if personaje then personaje:FindFirstChildOfClass("Humanoid") else nil
end

local function actualizarReticula()
	local mostrar = not Menu.hayAbierto()
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

-- Los limites de zoom del juego (StarterPlayer): se devuelven al salir de
-- tercera persona
local ZOOM_MIN, ZOOM_MAX = jugador.CameraMinZoomDistance, jugador.CameraMaxZoomDistance

-- En tercera persona, despues del script de camara: raton al centro (sin
-- panel) y el personaje girado hacia donde mira la camara
local function pasoTercera()
	if Menu.hayAbierto() then
		return
	end
	if UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
	local personaje = jugador.Character
	local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local mira = workspace.CurrentCamera.CFrame.LookVector
		local plano = Vector3.new(mira.X, 0, mira.Z)
		if plano.Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + plano)
		end
	end
end

local enTercera = false
local function fijarTercera(activa: boolean)
	local hum = humanoide()
	if hum then
		hum.CameraOffset = if activa then HOMBRO else Vector3.zero
		hum.AutoRotate = not activa
	end
	if activa == enTercera then
		return
	end
	enTercera = activa
	-- Siempre se desengancha antes: BindToRenderStep con el mismo nombre no
	-- sustituye, acumula (al reaparecer se fuerza enTercera = false)
	RunService:UnbindFromRenderStep(NOMBRE_TERCERA)
	if activa then
		RunService:BindToRenderStep(NOMBRE_TERCERA, Enum.RenderPriority.Camera.Value + 2, pasoTercera)
		jugador.CameraMinZoomDistance = DISTANCIA_TERCERA
		jugador.CameraMaxZoomDistance = DISTANCIA_TERCERA
	else
		jugador.CameraMinZoomDistance = ZOOM_MIN
		jugador.CameraMaxZoomDistance = ZOOM_MAX
	end
end

local esperandoHumanoide = false
local function aplicarCamara()
	local tercera = vistaTercera()
	jugador.CameraMode = if tercera then Enum.CameraMode.Classic else Enum.CameraMode.LockFirstPerson
	fijarTercera(tercera)
	actualizarReticula()
	-- La vista guardada suele llegar (con el perfil) antes que el personaje:
	-- sin Humanoid no hay hombro ni giro, asi que se reaplica cuando exista
	-- (hasta el 6 oct lo tapaba que entrar al patio volvia a aplicarla)
	if not humanoide() and not esperandoHumanoide then
		esperandoHumanoide = true
		task.spawn(function()
			local personaje = jugador.Character or jugador.CharacterAdded:Wait()
			personaje:WaitForChild("Humanoid", 10)
			esperandoHumanoide = false
			aplicarCamara()
		end)
	end
end

-- Cambia de vista (V o el boton del HUD, que solo tocan el atributo) y la
-- guarda en el perfil
local function alternarVista()
	jugador:SetAttribute("Vista", if vistaTercera() then "primera" else "tercera")
end

jugador:GetAttributeChangedSignal("Vista"):Connect(function()
	aplicarCamara()
	CamaraEvent:FireServer(if vistaTercera() then "tercera" else "primera")
end)
jugador.CharacterAdded:Connect(function()
	enTercera = false
	task.defer(aplicarCamara)
end)
UserInputService.InputBegan:Connect(function(input, procesado)
	if not procesado and input.KeyCode == Enum.KeyCode.V then
		alternarVista()
	end
end)
-- La vista guardada en el perfil (primera la primera vez)
task.spawn(function()
	local perfil = EstadoCliente.esperar()
	if jugador:GetAttribute("Vista") == nil then
		jugador:SetAttribute("Vista", if perfil and perfil.camara == "tercera" then "tercera" else "primera")
	end
end)
Menu.alCambiar:Connect(function(nombre)
	liberarRaton(nombre ~= nil)
end)
UserInputService.LastInputTypeChanged:Connect(actualizarReticula)
aplicarCamara()
liberarRaton(Menu.hayAbierto())
