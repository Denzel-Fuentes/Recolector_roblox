--!strict
--[[
	Tutorial (cliente)
	Pinta el paso actual del tutorial jugable: una PILDORA pequena arriba a
	la izquierda con lo que pide ("Paso 6/8 · Recoge basura de un solo
	color...", que abre el panel del paso al pulsarla) y una FLECHA (Beam)
	desde el jugador hasta el objetivo (el monton sin abrir mas cercano, un
	contenedor). Avisa al terminarlo.

	La tarjeta grande de abajo-centro se quito el 29 sep (en el movil tapaba
	media pantalla). La pildora del lote 9 va arriba a la izquierda: en PC
	ese rincon esta libre (la botonera va a media altura) y en tactil va
	debajo de la botonera; no tapa los avisos (arriba en el centro) ni las
	barras (derecha).

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
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local DefinicionesTutorial = require(Config:WaitForChild("DefinicionesTutorial"))
local DefinicionesRebirths = require(Config:WaitForChild("DefinicionesRebirths"))
local Formato = require(Shared:WaitForChild("Utilidades"):WaitForChild("Formato"))
local Cuadrantes = require(Shared:WaitForChild("Utilidades"):WaitForChild("Cuadrantes"))
local Contenedores = require(Shared:WaitForChild("Utilidades"):WaitForChild("Contenedores"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Menu = require(script.Parent:WaitForChild("Menu"))
local Notificaciones = require(script.Parent:WaitForChild("Notificaciones"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Escala = require(script.Parent:WaitForChild("Kit"):WaitForChild("Escala"))
local Tema = require(script.Parent:WaitForChild("Kit"):WaitForChild("Tema"))

local peek = Fusion.peek

local jugador = Players.LocalPlayer
local scope = Fusion.scoped(Fusion, Kit)
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

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
-- Pildora del paso
-- ===========================================================================

local textoPaso = scope:Computed(function(use)
	local n = use(completados)
	local paso = if n >= 0 then DefinicionesTutorial.actual(n) else nil
	if not paso then
		return ""
	end
	local texto = Textos.formatear((Textos.TUTORIAL :: any)[paso.texto] or "", {
		dinero = Formato.dinero(DefinicionesRebirths.rebirth(1).requisito),
	})
	return Textos.formatear(Textos.TUTORIAL.paso, { n = n + 1, total = DefinicionesTutorial.TOTAL }) .. " · " .. texto
end)
local panelPaso = scope:Computed(function(use)
	local n = use(completados)
	local paso = if n >= 0 then DefinicionesTutorial.actual(n) else nil
	return if paso and paso.panel then paso.panel else ""
end)
local tactil = scope:Computed(function(use)
	return use(Escala.disposicion) == "tactil"
end)

scope:Pantalla({
	Nombre = "Tutorial",
	Orden = 2,
	Hijos = {
		scope:New("TextButton")({
			Name = "Objetivo",
			Text = "",
			AutoButtonColor = false,
			-- PC: arriba a la izquierda (la botonera va a media altura).
			-- Tactil: debajo de la botonera, con sus medidas (Kit/Tema;
			-- desde el 22 oct son 3 filas: ~227 de alto)
			Position = scope:Computed(function(use)
				return if use(tactil)
					then UDim2.fromOffset(16, math.ceil(Tema.BOTONERA.ARRIBA_TACTIL + Tema.altoBotoneraTactil() + 10))
					else UDim2.fromOffset(16, 16)
			end),
			Size = scope:Computed(function(use)
				return UDim2.fromOffset(if use(tactil) then 240 else 330, 0)
			end),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Paleta.UI_PAPEL,
			Visible = scope:Computed(function(use)
				return use(activo) and use(sinPanel) and use(textoPaso) ~= ""
			end),
			SelectionImageObject = Tema.SELECCION_INVISIBLE,
			[OnEvent("Activated")] = function()
				local panel = peek(panelPaso)
				if panel ~= "" then
					Menu.alternar(panel)
				end
			end,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, Tema.RADIO) }),
				scope:New("UIStroke")({ Color = Paleta.UI_PRIMARIO, Thickness = Tema.GROSOR, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				scope:Relleno({ X = 10, Y = 6 }),
				scope:Texto({
					Texto = textoPaso,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Tamano = scope:Computed(function(use)
						return if use(tactil) then 13 else 15
					end),
					Fuente = "titulo",
				}),
			},
		}),
	},
})

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
	elseif objetivo == "Contenedor" then
		-- El general (el primer lanzamiento siempre entra en el)
		local general = Contenedores.general()
		return if general then general.zona.Position else nil
	elseif objetivo == "ContenedorTipo" then
		-- El de tipo mas cercano
		local mejor, dMejor = nil, math.huge
		for _, c in Contenedores.listar() do
			local d = (c.zona.Position - desde).Magnitude
			if c.material and d < dMejor then
				mejor, dMejor = c, d
			end
		end
		return if mejor then mejor.zona.Position else nil
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
