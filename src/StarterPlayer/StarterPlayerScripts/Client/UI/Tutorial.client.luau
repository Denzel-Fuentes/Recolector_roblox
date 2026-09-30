--!strict
--[[
	Tutorial (cliente)
	Pinta el paso actual del tutorial jugable con una FLECHA (Beam) desde el
	jugador hasta el objetivo del paso (el monton sin abrir mas cercano, el
	contenedor) y avisa al terminarlo.

	Sin tarjeta en pantalla: la de abajo-centro ("Primeros pasos 3/5 ·
	Recoge basura hasta llenar la bolsa", con un boton "Abrir Tienda" en el
	paso de la mejora) se quito el 29 sep a peticion del usuario. El L9
	decidira como se explica cada paso sin ella.

	Solo presentacion: el paso lo decide el servidor (Services/Tutorial) y
	llega en el perfil (perfil.tutorial = pasos completados). Se deriva un
	primitivo con Computed, asi los snapshots del perfil no reconstruyen nada.
	La flecha es local (Beam entre un Attachment en tu HumanoidRootPart y
	otro en una parte invisible que se mueve al objetivo).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local DefinicionesTutorial = require(Config:WaitForChild("DefinicionesTutorial"))
local Cuadrantes = require(Shared:WaitForChild("Utilidades"):WaitForChild("Cuadrantes"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Menu = require(script.Parent:WaitForChild("Menu"))
local Notificaciones = require(script.Parent:WaitForChild("Notificaciones"))

local peek = Fusion.peek

local jugador = Players.LocalPlayer
local scope = Fusion.scoped(Fusion)

-- Pasos completados (-1 = perfil aun sin cargar)
local completados = scope:Computed(function(use)
	local p = use(EstadoCliente.reactivo.perfil)
	return if p then (p.tutorial or 0) else -1
end)
local activo = scope:Computed(function(use)
	local n = use(completados)
	return n >= 0 and n < DefinicionesTutorial.TOTAL
end)
local sinPanel = scope:Computed(function(use)
	return use(Menu.abiertoR) == nil
end)

local function pasoActual(): DefinicionesTutorial.Paso?
	return DefinicionesTutorial.actual(math.max(0, peek(completados)))
end

-- Al terminar: aviso (solo si se vio terminar en esta sesion)
do
	local anterior = peek(completados)
	scope:Observer(completados):onChange(function()
		local n = peek(completados)
		if anterior >= 0 and anterior < DefinicionesTutorial.TOTAL and n >= DefinicionesTutorial.TOTAL then
			Notificaciones.mostrar(Textos.TUTORIAL.completado, "exito")
		end
		anterior = n
	end)
end

-- ===========================================================================
-- Flecha
-- ===========================================================================

local destino = Instance.new("Part")
destino.Name = "DestinoTutorial"
destino.Anchored = true
destino.CanCollide = false
destino.CanQuery = false
destino.CanTouch = false
destino.Transparency = 1
destino.Size = Vector3.one
destino.Parent = workspace
local adjuntoDestino = Instance.new("Attachment")
adjuntoDestino.Parent = destino

local adjuntoJugador = Instance.new("Attachment")
adjuntoJugador.Name = "AdjuntoTutorial"

local flecha = Instance.new("Beam")
flecha.Name = "FlechaTutorial"
flecha.Attachment0 = adjuntoJugador
flecha.Attachment1 = adjuntoDestino
flecha.Color = ColorSequence.new(Paleta.UI_PRIMARIO)
flecha.Transparency = NumberSequence.new(0.15, 0.5)
flecha.Width0 = 0.8
flecha.Width1 = 0.3
flecha.FaceCamera = true
flecha.LightEmission = 0.4
flecha.Segments = 12
flecha.CurveSize0 = 4 -- arco suave hacia arriba
flecha.CurveSize1 = -4
flecha.Enabled = false
flecha.Parent = destino

-- El monton sin abrir mas cercano de un cuadrante que el jugador tiene abierto
local function montonLlenoMasCercano(desde: Vector3): Vector3?
	local carpeta = workspace:FindFirstChild("Montones")
	local perfil = EstadoCliente.perfil
	local rebirths = if perfil then (perfil.rebirths or 0) else 0
	local mejor, distMejor = nil, math.huge
	if carpeta then
		for _, m in carpeta:GetChildren() do
			local cuadrante = m:GetAttribute("Cuadrante")
			local abierto = typeof(cuadrante) ~= "number" or Cuadrantes.abierto(cuadrante, rebirths)
			if m:IsA("Model") and m:GetAttribute("Estado") == "lleno" and abierto then
				local pos = m:GetPivot().Position
				local d = (pos - desde).Magnitude
				if d < distMejor then
					mejor, distMejor = pos, d
				end
			end
		end
	end
	return mejor
end

local function posicionObjetivo(objetivo: string, desde: Vector3): Vector3?
	if objetivo == "montonLleno" then
		return montonLlenoMasCercano(desde)
	end
	for _, inst in CollectionService:GetTagged(objetivo) do
		if inst:IsA("Model") then
			return inst:GetPivot().Position
		elseif inst:IsA("BasePart") then
			return inst.Position
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function()
	local personaje = jugador.Character
	local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
	local paso = if peek(activo) then pasoActual() else nil
	local objetivo = paso and paso.objetivo
	if not root or not root:IsA("BasePart") or not objetivo or not peek(sinPanel) then
		flecha.Enabled = false
		return
	end
	if adjuntoJugador.Parent ~= root then
		adjuntoJugador.Parent = root
	end
	local pos = posicionObjetivo(objetivo, root.Position)
	if not pos then
		flecha.Enabled = false
		return
	end
	destino.Position = pos + Vector3.new(0, 4, 0)
	-- Ya encima del objetivo sobra la flecha
	flecha.Enabled = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude > 8
end)
