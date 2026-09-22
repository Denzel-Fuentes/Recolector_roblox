--!strict
--[[
	ControlPatio
	Input del patio en el cliente. Solo envia INTENCION; el servidor valida.

	  MANTENER clic / dedo / ButtonX          -> ReclamarObjetoEvent(id) de lo que
	                                            pase por la mira, cada INTERVALO_RECOGIDA
	  MANTENER F / ButtonY / boton tactil    -> carga la fuerza; al soltar,
	                                            LanzarObjetoEvent(punto, fuerza)
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
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Red = require(Utilidades:WaitForChild("Red"))
local Entrada = require(Utilidades:WaitForChild("Entrada"))
local Geometria = require(Utilidades:WaitForChild("Geometria"))

local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))
local UI = script.Parent:WaitForChild("UI")
local Menu = require(UI:WaitForChild("Menu"))
local Componentes = require(UI:WaitForChild("Componentes"))

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

-- Un objeto es una pieza de montana (BasePart con ObjetoId) o un modelo con
-- ObjetoId (mascota metida en la montana, bolsa caida): lo primero que tenga
-- el atributo subiendo desde lo que toco el rayo.
local function objetoDesde(inst: Instance?): PVInstance?
	local actual = inst
	while actual and actual ~= workspace do
		if actual:IsA("PVInstance") and actual:GetAttribute("ObjetoId") then
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
	-- Gamepad y primera persona (raton bloqueado en el centro): rayo central
	if plataforma == "gamepad" or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return nil
	end
	local pos = UserInputService:GetMouseLocation()
	return Vector2.new(pos.X, pos.Y - GuiService:GetGuiInset().Y)
end

-- Distancia del personaje a la superficie del objeto: la misma medida que
-- usa el servidor para aceptar el reclamo (Utilidades/Geometria)
local function distanciaAlPersonaje(objeto: PVInstance): number
	local personaje = jugador.Character
	local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return math.huge
	end
	return Geometria.distanciaASuperficie(objeto, root.Position)
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
	if objeto and distanciaAlPersonaje(objeto) <= alcanceActual() then
		resaltado.Adornee = objeto
		resaltado.Enabled = true
	else
		resaltado.Enabled = false
	end
end)

-- === Mantener el clic para recoger ===
-- Mientras se mantiene el clic izquierdo (el dedo en tactil, X en gamepad) se
-- recoge lo que vaya pasando por la mira, una pieza cada INTERVALO_RECOGIDA:
-- el servidor tiene su propio cooldown por remote (COOLDOWN_REMOTE), asi que
-- enviar mas rapido no recoge mas. Un mismo objeto no se reenvia hasta que el
-- servidor lo retira (o pasa medio segundo): al reclamarlo vuela a la bolsa y
-- el rayo ya pasa a la siguiente pieza.
local recogiendo = false
local posicionTactil: Vector2? = nil
local ultimoIntento = 0
local ultimoId: string? = nil
local ultimoIdEn = 0

local function intentarReclamar(posPantalla: Vector2?)
	local resultado = rayoDesdePantalla(posPantalla)
	local objeto = resultado and objetoDesde(resultado.Instance)
	if not objeto then
		return
	end
	if distanciaAlPersonaje(objeto) > alcanceActual() then
		return
	end
	local id = objeto:GetAttribute("ObjetoId")
	if id then
		id = tostring(id)
		if id == ultimoId and os.clock() - ultimoIdEn < 0.5 then
			return
		end
		ultimoId, ultimoIdEn = id, os.clock()
		ReclamarObjetoEvent:FireServer(id)
	end
end

local function recogerAhora()
	ultimoIntento = os.clock()
	intentarReclamar(if posicionTactil then posicionTactil else posicionCursor())
end

UserInputService.InputBegan:Connect(function(input, procesado)
	if procesado or Menu.hayAbierto() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		recogiendo = true
		recogerAhora()
	elseif input.UserInputType == Enum.UserInputType.Touch then
		posicionTactil = Vector2.new(input.Position.X, input.Position.Y)
		recogiendo = true
		recogerAhora()
	elseif input.KeyCode == Enum.KeyCode.ButtonX then
		-- Gamepad: lo que hay en el centro de la pantalla
		recogiendo = true
		recogerAhora()
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch and posicionTactil then
		posicionTactil = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonX then
		recogiendo = false
	elseif input.UserInputType == Enum.UserInputType.Touch then
		recogiendo = false
		posicionTactil = nil
	end
end)

RunService.RenderStepped:Connect(function()
	if recogiendo and not Menu.hayAbierto() and os.clock() - ultimoIntento >= GameConfig.INTERVALO_RECOGIDA then
		recogerAhora()
	end
end)

-- === Lanzar la bolsa: mantener para cargar, soltar para lanzar ===
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

local cargando: number? = nil -- os.clock() del inicio de la carga

local function lanzar(_nombre: string, estado: Enum.UserInputState)
	if Menu.hayAbierto() then
		return Enum.ContextActionResult.Pass
	end
	if estado == Enum.UserInputState.Begin then
		if #EstadoCliente.bolsa.items == 0 then
			return Enum.ContextActionResult.Pass
		end
		cargando = os.clock()
		return Enum.ContextActionResult.Sink
	elseif estado == Enum.UserInputState.End or estado == Enum.UserInputState.Cancel then
		local inicio = cargando
		cargando = nil
		local fuerza = EstadoCliente.cargaLanzamiento
		EstadoCliente.fijarCarga(0)
		if inicio and estado == Enum.UserInputState.End and os.clock() - inicio >= GameConfig.FUERZA_LANZAMIENTO.minimo then
			LanzarObjetoEvent:FireServer(puntoObjetivo(), math.max(fuerza, 0.15))
		end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

RunService.RenderStepped:Connect(function()
	if cargando then
		EstadoCliente.fijarCarga((os.clock() - cargando) / GameConfig.FUERZA_LANZAMIENTO.segundosCarga)
	end
end)

ContextActionService:BindAction("Lanzar", lanzar, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("Lanzar", "")
ContextActionService:SetPosition("Lanzar", UDim2.new(0.62, 0, 0.5, 0))

-- El boton tactil lo crea ContextActionService (solo con pantalla tactil);
-- aqui se le pone el estilo pegatina del HUD: papel, contorno de tinta, la
-- bolsa volando y "MANTEN". Vive en ContextActionGui, sin UIScale: los
-- tamanos son pixeles reales, y 78 px es el dedo (el salto de Roblox mide 70).
local function estilizarBotonTactil()
	local boton = ContextActionService:GetButton("Lanzar")
	if not boton then
		return
	end
	boton.Image = ""
	boton.BackgroundTransparency = 0
	boton.BackgroundColor3 = Paleta.UI_PAPEL
	boton.Size = UDim2.fromOffset(78, 78)
	for _, hijo in boton:GetChildren() do
		if hijo:IsA("GuiObject") then
			hijo.Visible = false
		end
	end
	Componentes.esquinas(boton, 39)
	Componentes.borde(boton, Paleta.UI_TINTA, 3)
	Componentes.icono({ Parent = boton, Clave = "lanzar", Tamano = 40, Position = UDim2.new(0.5, 0, 0, 8), Anchor = Vector2.new(0.5, 0), ZIndex = 3 })
	Componentes.texto({ Parent = boton, Texto = Textos.HUD.tocarLanzar, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -20), Tamano = 11, Titulo = true, Alinear = Enum.TextXAlignment.Center, ZIndex = 3 })
	local escala = Instance.new("UIScale")
	escala.Parent = boton
	boton.MouseButton1Down:Connect(function()
		escala.Scale = 0.92
	end)
	boton.MouseButton1Up:Connect(function()
		escala.Scale = 1
	end)
	boton.MouseLeave:Connect(function()
		escala.Scale = 1
	end)
end
task.defer(estilizarBotonTactil)

-- Refresca la camara si cambia (respawn)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camara = workspace.CurrentCamera
end)
