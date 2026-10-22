--!strict
--[[
	ControlPatio
	Input del patio en el cliente. Solo envia INTENCION; el servidor valida.

	  MANTENER clic / ButtonX                 -> ReclamarObjetoEvent(id) de lo que
	                                            pase por la mira, cada INTERVALO_RECOGIDA
	  MANTENER boton RECOGER (tactil)        -> lo mismo
	  MANTENER F / ButtonY / boton LANZAR    -> carga la fuerza; al soltar,
	                                            LanzarObjetoEvent(punto, fuerza)
	  Resaltado del objeto bajo la mira si esta al Alcance

	Excavar y reciclar a mano NO estan aqui: son ProximityPrompts y llegan al
	servidor directamente.

	En tactil (movil y tablet) se apunta con la mira del centro arrastrando
	la pantalla (gira la camara) y se recoge MANTENIENDO el boton RECOGER de
	la derecha (peticion del usuario, 6 oct). Hasta entonces se recogia
	solo con arrastrar el dedo, sin boton: se llevaba lo que pasaba por la
	mira sin querer. RECOGER y LANZAR ocupan el mismo sitio y se alternan:
	RECOGER en el patio con hueco en la bolsa, LANZAR con la bolsa llena. El
	resaltado sigue a la mira siempre, para ver que se va a llevar antes de
	pulsar.

	Solo se lanza con la BOLSA LLENA (decision del usuario, 29 sep): el boton
	tactil y la pista "MANTEN F" solo aparecen entonces, y F no hace nada
	antes. Es una regla de flujo, no de seguridad: el servidor sigue
	aceptando una bolsa a medias (no da ventaja) y a mano se entrega
	siempre en el contenedor.

	El punto de lanzamiento es donde apunta el jugador: raycast desde la camara
	por el cursor (raton libre) o por el centro de la pantalla (primera
	persona, gamepad y tactil: en el movil el ultimo toque es el del boton de
	lanzar, no un sitio al que apuntar). Si no hay nada delante, 40 studs en
	esa direccion. Apuntar al hueco del Contenedor es la habilidad: la
	ZonaAcierto no bloquea el raycast, asi que el rayo llega al piso interior
	del contenedor.
]]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Red = require(Utilidades:WaitForChild("Red"))
local Entrada = require(Utilidades:WaitForChild("Entrada"))
local Geometria = require(Utilidades:WaitForChild("Geometria"))

local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))
local LineaTrayectoria = require(script.Parent:WaitForChild("LineaTrayectoria"))
local UI = script.Parent:WaitForChild("UI")
local Menu = require(UI:WaitForChild("Menu"))
local Kit = require(UI:WaitForChild("Kit"))
local Tema = require(UI:WaitForChild("Kit"):WaitForChild("Tema"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local ReclamarObjetoEvent = Red.evento("ReclamarObjetoEvent")
local LanzarObjetoEvent = Red.evento("LanzarObjetoEvent")

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera

local resaltado = Instance.new("Highlight")
resaltado.Name = "ResaltadoObjeto"
resaltado.FillTransparency = 0.7
resaltado.FillColor = Paleta.UI_PRIMARIO
resaltado.OutlineColor = Paleta.UI_PRIMARIO
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
	-- Las barreras de los cuadrantes cerrados se ven a traves: el rayo tambien
	-- (apuntar un lanzamiento por encima de ellas, ver lo que espera)
	for _, barrera in CollectionService:GetTagged("BarreraCuadrante") do
		table.insert(excluir, barrera)
	end
	p.FilterDescendantsInstances = excluir
	p.RespectCanCollide = false
	return p
end

local function alcanceActual(): number
	return DefinicionesMejoras.valor("Alcance", EstadoCliente.nivelMejora("Alcance")) + 2
end

-- Solo se lanza con la bolsa llena (ver cabecera); llena, la mira no recoge
local function bolsaLlena(bolsa: any): boolean
	return bolsa.capacidad > 0 and #bolsa.items >= bolsa.capacidad
end

-- Un objeto es una pieza de montana (BasePart con ObjetoId) o un modelo con
-- ObjetoId (tesoro metido en la montana, bolsa caida): lo primero que tenga
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
	-- Gamepad, tactil y primera persona (raton bloqueado en el centro): rayo central
	if plataforma == "gamepad" or plataforma == "tactil" or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
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

-- Un tipo de basura que el jugador aun no abrio no se resalta ni se pide:
-- el servidor lo rechazaria igual ("materialBloqueado")
local function tipoAbierto(objeto: PVInstance): boolean
	local material = objeto:GetAttribute("MaterialBasura")
	local perfil = EstadoCliente.perfil
	return GameConfig.materialAbierto(if typeof(material) == "string" then material else nil, if perfil then perfil.rebirths or 0 else 0)
end

-- === Resaltado del objeto bajo el cursor ===
local acumulado = 0
RunService.RenderStepped:Connect(function(dt)
	acumulado += dt
	if acumulado < 0.08 then
		return
	end
	acumulado = 0
	if Menu.hayAbierto() then
		resaltado.Enabled = false
		return
	end
	local resultado = rayoDesdePantalla(posicionCursor())
	local objeto = resultado and objetoDesde(resultado.Instance)
	if objeto and tipoAbierto(objeto) and distanciaAlPersonaje(objeto) <= alcanceActual() then
		resaltado.Adornee = objeto
		resaltado.Enabled = true
	else
		resaltado.Enabled = false
	end
end)

-- === Recoger ===
-- Mientras se mantiene el clic izquierdo (X en gamepad; en tactil, el boton
-- RECOGER) se recoge lo que vaya pasando por la mira, una pieza cada
-- INTERVALO_RECOGIDA: el servidor tiene su propio cooldown por remote
-- (COOLDOWN_REMOTE), asi que enviar mas rapido no recoge mas. Un mismo objeto
-- no se reenvia hasta que el servidor lo retira (o pasa medio segundo): al
-- reclamarlo vuela a la bolsa y el rayo ya pasa a la siguiente pieza.
local recogiendo = false
-- El boton RECOGER del tactil esta pulsado (ver cabecera)
local recogiendoTactil = false
local ultimoIntento = 0
local ultimoId: string? = nil
local ultimoIdEn = 0

-- Con la bolsa llena no se pide nada: el HUD sacude la barra de bolsa
-- (antes era un toast del servidor). Una pieza de un tipo bloqueado SI se
-- pide aunque no se resalte: el servidor la rechaza con una burbuja con el
-- candado encima (AvisosMundo), que es como el jugador se entera.
local function intentarReclamar(posPantalla: Vector2?)
	if bolsaLlena(EstadoCliente.bolsa) then
		EstadoCliente.alRecogerConBolsaLlena:Fire()
		return
	end
	local resultado = rayoDesdePantalla(posPantalla)
	local objeto = resultado and objetoDesde(resultado.Instance)
	if not objeto or distanciaAlPersonaje(objeto) > alcanceActual() then
		return
	end
	local id = objeto:GetAttribute("ObjetoId")
	if id then
		id = tostring(id)
		if id == ultimoId and os.clock() - ultimoIdEn < 0.5 then
			return
		end
		ultimoId, ultimoIdEn = id, os.clock()
		ReclamarObjetoEvent:FireServer(id, false)
	end
end

local function recogerAhora()
	ultimoIntento = os.clock()
	intentarReclamar(posicionCursor())
end

UserInputService.InputBegan:Connect(function(input, procesado)
	if procesado or Menu.hayAbierto() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		recogiendo = true
		recogerAhora()
	elseif input.KeyCode == Enum.KeyCode.ButtonX then
		-- Gamepad: lo que hay en el centro de la pantalla
		recogiendo = true
		recogerAhora()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonX then
		recogiendo = false
	end
end)

RunService.RenderStepped:Connect(function()
	if Menu.hayAbierto() or os.clock() - ultimoIntento < GameConfig.INTERVALO_RECOGIDA then
		return
	end
	if recogiendo or recogiendoTactil then
		-- (en tactil posicionCursor() es nil: el rayo central, la mira)
		recogerAhora()
	end
end)

-- Boton RECOGER del tactil (lo crea ContextActionService solo con pantalla
-- tactil): mantenerlo recoge lo que hay bajo la mira
local function recoger(_nombre: string, estado: Enum.UserInputState)
	if estado == Enum.UserInputState.Begin then
		if Menu.hayAbierto() then
			return Enum.ContextActionResult.Pass
		end
		recogiendoTactil = true
		recogerAhora()
		return Enum.ContextActionResult.Sink
	elseif estado == Enum.UserInputState.End or estado == Enum.UserInputState.Cancel then
		recogiendoTactil = false
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction("Recoger", recoger, true)
ContextActionService:SetTitle("Recoger", "")
ContextActionService:SetPosition("Recoger", UDim2.new(0.62, 0, 0.5, 0))

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
		if not bolsaLlena(EstadoCliente.bolsa) then
			return Enum.ContextActionResult.Pass
		end
		cargando = os.clock()
		return Enum.ContextActionResult.Sink
	elseif estado == Enum.UserInputState.End or estado == Enum.UserInputState.Cancel then
		local inicio = cargando
		cargando = nil
		local fuerza = EstadoCliente.cargaLanzamiento
		EstadoCliente.fijarCarga(0)
		LineaTrayectoria.ocultar()
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
		-- Ayuda de punteria en los primeros lanzamientos
		LineaTrayectoria.dibujar(puntoObjetivo(), EstadoCliente.cargaLanzamiento)
	end
end)

ContextActionService:BindAction("Lanzar", lanzar, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("Lanzar", "")
ContextActionService:SetPosition("Lanzar", UDim2.new(0.62, 0, 0.5, 0))

-- Los botones tactiles los crea ContextActionService (solo con pantalla
-- tactil); aqui se les pone el estilo pegatina del HUD: color, contorno de
-- tinta, icono y "MANTEN"/"RECOGER". Viven en ContextActionGui, sin UIScale:
-- los tamanos son pixeles reales, y 78 px es el dedo (el salto de Roblox
-- mide 70). LANZAR y RECOGER estan en el mismo sitio y nunca se ven a la vez.
local scopeBotones = Fusion.scoped(Fusion, Kit)
local enPatio = scopeBotones:Value(jugador:GetAttribute("EnPatio") == true)
jugador:GetAttributeChangedSignal("EnPatio"):Connect(function()
	enPatio:set(jugador:GetAttribute("EnPatio") == true)
end)

local function estilizarBotonTactil(accion: string, icono: string, texto: string, color: Color3, visible: any)
	local boton = ContextActionService:GetButton(accion)
	if not boton then
		return
	end
	for _, hijo in boton:GetChildren() do
		if hijo:IsA("GuiObject") then
			hijo.Visible = false
		end
	end
	-- El boton es de Roblox: Fusion lo "hidrata" con el estilo del Kit
	local scope = scopeBotones
	local pulsado = scope:Value(false)
	scope:Hydrate(boton)({
		Image = "",
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(78, 78),
		Visible = visible,
		[Fusion.OnEvent("MouseButton1Down")] = function()
			pulsado:set(true)
		end,
		[Fusion.OnEvent("MouseButton1Up")] = function()
			pulsado:set(false)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			pulsado:set(false)
		end,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			scope:New("UIStroke")({ Color = Paleta.UI_TINTA, Thickness = Tema.GROSOR }),
			scope:New("UIGradient")({ Color = Tema.DEGRADADO, Rotation = 90 }),
			scope:New("UIScale")({
				Scale = scope:Spring(
					scope:Computed(function(use)
						return if use(pulsado) then 0.9 else 1
					end),
					50,
					0.6
				),
			}),
			scope:Icono({ Clave = icono, Tamano = 40, Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 }),
			scope:Texto({ Texto = texto, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -20), Tamano = 12, Fuente = "titulo", Color = Paleta.UI_PAPEL, Contorno = Paleta.UI_TINTA, Alinear = Enum.TextXAlignment.Center, ZIndex = 3 }),
		},
	})
end
task.defer(function()
	-- LANZAR solo con la bolsa llena (ver cabecera); RECOGER en el patio
	-- mientras quepa algo
	estilizarBotonTactil("Lanzar", "lanzar", Textos.HUD.tocarLanzar, Paleta.UI_FUERZA, scopeBotones:Computed(function(use)
		return bolsaLlena(use(EstadoCliente.reactivo.bolsa))
	end))
	estilizarBotonTactil("Recoger", "mano", Textos.HUD.botonRecoger, Paleta.UI_PRIMARIO, scopeBotones:Computed(function(use)
		return use(enPatio) and not bolsaLlena(use(EstadoCliente.reactivo.bolsa))
	end))
end)

-- Refresca la camara si cambia (respawn)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camara = workspace.CurrentCamera
end)
