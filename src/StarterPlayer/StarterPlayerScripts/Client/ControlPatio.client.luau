--!strict
--[[
	ControlPatio
	Input del patio en el cliente. Solo envia INTENCION; el servidor valida.

	  Clic / toque sobre un objeto del patio  -> ReclamarObjetoEvent(id)
	  F / ButtonY / boton tactil "Lanzar"     -> LanzarObjetoEvent(punto)
	  Resaltado del objeto bajo el cursor si esta al Alcance

	Excavar, reciclar, refresco y hablar NO estan aqui: son ProximityPrompts y
	llegan al servidor directamente.

	El punto de lanzamiento es donde apunta el jugador: raycast desde la camara
	por el cursor (raton) o por el centro de la pantalla (gamepad/tactil). Si no
	hay nada delante, 40 studs en esa direccion. Apuntar al hueco del Contenedor
	es la habilidad: la ZonaAcierto no bloquea el raycast, asi que el rayo llega
	al piso interior del contenedor.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Red = require(Utilidades:WaitForChild("Red"))
local Entrada = require(Utilidades:WaitForChild("Entrada"))

local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))
local Menu = require(script.Parent:WaitForChild("UI"):WaitForChild("Menu"))

local ReclamarObjetoEvent = Red.evento("ReclamarObjetoEvent")
local LanzarObjetoEvent = Red.evento("LanzarObjetoEvent")

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera

local resaltado = Instance.new("Highlight")
resaltado.Name = "ResaltadoObjeto"
resaltado.FillTransparency = 0.7
resaltado.FillColor = Paleta.UI_ACENTO
resaltado.OutlineColor = Paleta.UI_ACENTO
resaltado.OutlineTransparency = 0
resaltado.Enabled = false
resaltado.Parent = workspace

local function parametrosRay(): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local excluir = {}
	if jugador.Character then
		table.insert(excluir, jugador.Character)
	end
	p.FilterDescendantsInstances = excluir
	p.RespectCanCollide = false
	return p
end

local function alcanceActual(): number
	return DefinicionesMejoras.valor("Alcance", EstadoCliente.nivelMejora("Alcance")) + 2
end

local function objetoDesde(inst: Instance?): Model?
	local actual = inst
	while actual and actual ~= workspace do
		if actual:IsA("Model") and actual:GetAttribute("ObjetoId") then
			return actual
		end
		actual = actual.Parent
	end
	return nil
end

local function rayoDesdePantalla(posPantalla: Vector2?): RaycastResult?
	if not camara then
		return nil
	end
	local rayo: Ray
	if posPantalla then
		rayo = camara:ViewportPointToRay(posPantalla.X, posPantalla.Y)
	else
		local centro = camara.ViewportSize / 2
		rayo = camara:ViewportPointToRay(centro.X, centro.Y)
	end
	return workspace:Raycast(rayo.Origin, rayo.Direction * 300, parametrosRay())
end

local function posicionCursor(): Vector2?
	local plataforma = Entrada.plataforma()
	if plataforma == "gamepad" then
		return nil
	end
	local pos = UserInputService:GetMouseLocation()
	return Vector2.new(pos.X, pos.Y - GuiService:GetGuiInset().Y)
end

local function distanciaAlPersonaje(pos: Vector3): number
	local personaje = jugador.Character
	local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return (root.Position - pos).Magnitude
	end
	return math.huge
end

-- === Resaltado del objeto bajo el cursor ===
local acumulado = 0
RunService.RenderStepped:Connect(function(dt)
	acumulado += dt
	if acumulado < 0.08 then
		return
	end
	acumulado = 0
	if Menu.hayAbierto() or Entrada.plataforma() == "tactil" then
		resaltado.Enabled = false
		return
	end
	local resultado = rayoDesdePantalla(posicionCursor())
	local objeto = resultado and objetoDesde(resultado.Instance)
	if objeto and distanciaAlPersonaje(objeto:GetPivot().Position) <= alcanceActual() then
		resaltado.Adornee = objeto
		resaltado.Enabled = true
	else
		resaltado.Enabled = false
	end
end)

-- === Clic / toque para reclamar ===
local function intentarReclamar(posPantalla: Vector2?)
	local resultado = rayoDesdePantalla(posPantalla)
	local objeto = resultado and objetoDesde(resultado.Instance)
	if not objeto then
		return
	end
	if distanciaAlPersonaje(objeto:GetPivot().Position) > alcanceActual() then
		return
	end
	local id = objeto:GetAttribute("ObjetoId")
	if id then
		ReclamarObjetoEvent:FireServer(tostring(id))
	end
end

UserInputService.InputBegan:Connect(function(input, procesado)
	if procesado or Menu.hayAbierto() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		intentarReclamar(posicionCursor())
	elseif input.UserInputType == Enum.UserInputType.Touch then
		local pos = input.Position
		intentarReclamar(Vector2.new(pos.X, pos.Y))
	elseif input.KeyCode == Enum.KeyCode.ButtonX then
		-- Gamepad: reclamar lo que hay en el centro de la pantalla
		intentarReclamar(nil)
	end
end)

-- === Lanzar ===
local function puntoObjetivo(): Vector3
	local resultado = rayoDesdePantalla(posicionCursor())
	if resultado then
		return resultado.Position
	end
	if camara then
		local cf = camara.CFrame
		return cf.Position + cf.LookVector * 40
	end
	return Vector3.zero
end

local function lanzar(_nombre: string, estado: Enum.UserInputState)
	if estado ~= Enum.UserInputState.Begin or Menu.hayAbierto() then
		return Enum.ContextActionResult.Pass
	end
	LanzarObjetoEvent:FireServer(puntoObjetivo())
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("Lanzar", lanzar, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("Lanzar", Textos.HUD.lanzar)
ContextActionService:SetPosition("Lanzar", UDim2.new(0.72, 0, 0.62, 0))

-- Refresca la camara si cambia (respawn)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camara = workspace.CurrentCamera
end)
