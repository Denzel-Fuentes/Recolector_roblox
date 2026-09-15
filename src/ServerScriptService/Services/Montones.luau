--!strict
--[[
	Montones (ModuleScript)
	Unica responsabilidad: el ciclo de vida de cada monton del patio:
	lleno (colina con prompt) -> activo (montana de basura) -> agotado (marca
	plana) -> repoblado.

	=== La colina se convierte en una montana de basura ===
	Cada monton es una COLINA lisa (ModelosMonton) cuyo tamano depende de
	numPiezas. Al activarlo, GeneradorBotin decide que sale, cada item recibe
	su modelo real (ObjetosPatio.modeloPara) y se reparte por TODO el volumen
	de la colina (ModelosMonton.puntosEnColina): la colina se sustituye por una
	montana de basura con su mismo bulto (decision del usuario: "mucha basura,
	equivalente al tamano del monton"). Las lomas se destruyen (chocarian con
	la basura) y el modelo del monton queda como contenedor. La basura brota
	de abajo arriba en DURACION_BROTE y cae con fisica (FisicaBasura).

	Los objetos NO caducan: se quedan hasta que alguien los recoja. Con 0
	objetos el monton pasa a "agotado", y Dona Chatarra repone los agotados
	cuando quedan pocos disponibles (un activo con menos del 25% de sus
	objetos ya no cuenta como disponible: que la repoblacion no espere al
	ultimo papel).

	La cuenta de objetos vivos la lleva este modulo escuchando
	ObjetosPatio.alRetirar; asi ObjetosPatio no sabe que existe un monton.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Textos = require(Config:WaitForChild("Textos"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosMonton = require(Utilidades:WaitForChild("ModelosMonton"))
local Red = require(Utilidades:WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local TiposPatio = require(Servicios:WaitForChild("TiposPatio"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Energia = require(Servicios:WaitForChild("Energia"))
local Mundo = require(Servicios:WaitForChild("Mundo"))
local GeneradorBotin = require(Servicios:WaitForChild("GeneradorBotin"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))
local FisicaBasura = require(Servicios:WaitForChild("FisicaBasura"))

local FeedEvent = Red.evento("FeedEvent")

type Monton = TiposPatio.Monton
type Item = TiposPatio.Item

local Montones = {}

local DURACION_BROTE = 1.5 -- segundos que tarda en brotar toda la montana (de abajo arriba, para que lo de abajo asiente antes)
local INTERVALO_REPOBLACION = 5
local MARGEN_EXCAVAR = 14 -- studs mas alla del radio desde los que se acepta el prompt

local montones: { Monton } = {}
local carpeta: Folder -- workspace.Montones
local repoblacionPendiente = false
local rng = Random.new()

-- ===========================================================================
-- Modelo y estados
-- ===========================================================================

-- La colina (lleno), o las marcas planas (agotado)
local function crearModelo(monton: Monton)
	if monton.modelo then
		monton.modelo:Destroy()
	end
	local modelo = ModelosMonton.monton(monton.tamano, monton.estado == "agotado", monton.id, monton.numPiezas)
	modelo.Name = "Monton_" .. monton.id
	modelo:SetAttribute("MontonId", monton.id)
	modelo:SetAttribute("Tamano", monton.tamano)
	modelo:SetAttribute("Estado", monton.estado)
	modelo:SetAttribute("Piezas", monton.numPiezas)
	modelo:PivotTo(CFrame.new(monton.ranura.Position))
	modelo.Parent = carpeta
	monton.modelo = modelo
	if monton.estado == "lleno" and modelo.PrimaryPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PromptExcavar"
		prompt.ActionText = Textos.PATIO.excavar
		prompt.ObjectText = "Montón " .. monton.tamano .. " (" .. monton.numPiezas .. ")"
		prompt.HoldDuration = GameConfig.DURACION_EXCAVAR
		prompt.MaxActivationDistance = ModelosMonton.radioMonton(monton.tamano) + 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = modelo.PrimaryPart
	end
end

-- Un monton nuevo (al arrancar o al repoblar): tantos objetos dara como piezas
local function llenar(monton: Monton)
	local def = GameConfig.TAMANOS_MONTON[monton.tamano] or GameConfig.TAMANOS_MONTON.chico
	monton.estado = "lleno"
	monton.numPiezas = rng:NextInteger(def.min, def.max)
	monton.objetosIniciales = 0
	monton.objetosVivos = 0
	monton.params = ModelosMonton.parametrosColina(monton.tamano, monton.id, monton.numPiezas)
	crearModelo(monton)
end

local function agotar(monton: Monton)
	monton.estado = "agotado"
	crearModelo(monton)
end

-- ===========================================================================
-- Consultas
-- ===========================================================================

function Montones.todos(): { Monton }
	return montones
end

-- El monton al que pertenece una instancia (el prompt de excavar)
function Montones.de(inst: Instance): Monton?
	local actual: Instance? = inst
	while actual and actual ~= workspace do
		local id = actual:GetAttribute("MontonId")
		if id then
			return montones[id]
		end
		actual = actual.Parent
	end
	return nil
end

-- Disponible = lleno, o activo con bastante basura sin recoger todavia
local function estaDisponible(monton: Monton): boolean
	if monton.estado == "lleno" then
		return true
	end
	if monton.estado == "activo" then
		return monton.objetosVivos >= math.max(1, math.floor(monton.objetosIniciales * GameConfig.FRACCION_MONTON_DISPONIBLE))
	end
	return false
end

-- ===========================================================================
-- Activar
-- ===========================================================================

local function distanciaAlCentro(jugador: Player, monton: Monton): number?
	local personaje = jugador.Character
	local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	return (root.Position - monton.ranura.Position).Magnitude
end

-- Coloca los objetos por el volumen de la colina, revueltos como en un
-- vertedero, y los hace brotar de abajo arriba
local function desplegarBasura(monton: Monton, modelo: Model, contenido: { Item })
	local puntos = ModelosMonton.puntosEnColina(monton.params, #contenido, rng)
	table.sort(puntos, function(a, b)
		return a.Y < b.Y
	end)
	local base = monton.ranura.Position
	for i, item in contenido do
		local propio = ObjetosPatio.modeloPara(item)
		propio:PivotTo(CFrame.new(base + puntos[i]) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(rng:NextNumber(-0.7, 0.7), 0, rng:NextNumber(-0.7, 0.7)))
		-- Se registra ya (reclamable por id) pero brota en su momento
		local obj = ObjetosPatio.registrar(item, propio, monton)
		task.delay((i / #contenido) * DURACION_BROTE, function()
			if propio.Parent == nil and ObjetosPatio.obtener(obj.id) == obj and monton.estado == "activo" then
				propio.Parent = modelo
				FisicaBasura.darFisica(obj)
			end
		end)
	end
end

local function anunciar(jugador: Player, monton: Monton, contenido: { Item })
	if monton.tamano == "grande" then
		FeedEvent:FireAllClients(Textos.formatear(Textos.FEED.montonGrande, { jugador = jugador.DisplayName }))
	end
	for _, item in contenido do
		if item.tipo == "mascota" and item.id then
			local def = DefinicionesMascotas.obtener(item.id)
			if def and def.rareza ~= "Comun" then
				FeedEvent:FireAllClients(Textos.formatear(Textos.FEED.raraEncontrada, {
					jugador = jugador.DisplayName,
					mascota = def.nombre,
					rareza = DefinicionesMascotas.NOMBRE_RAREZA[def.rareza],
				}))
			end
		end
	end
end

function Montones.excavar(jugador: Player, monton: Monton): (boolean, string)
	if monton.estado ~= "lleno" then
		return false, "agotado"
	end
	local d = distanciaAlCentro(jugador, monton)
	if not d or d > ModelosMonton.radioMonton(monton.tamano) + MARGEN_EXCAVAR then
		return false, "lejos"
	end
	if not Energia.gastar(jugador, GameConfig.COSTE_EXCAVAR) then
		return false, "sinEnergia"
	end
	local modelo = monton.modelo
	if not modelo then
		return false, "sinModelo"
	end
	monton.estado = "activo"
	modelo:SetAttribute("Estado", "activo")
	for _, hijo in modelo:GetChildren() do
		if hijo:IsA("ProximityPrompt") or (hijo:IsA("BasePart") and hijo.Name:match("^Loma_")) then
			hijo:Destroy()
		end
	end

	local contenido, huboRara = GeneradorBotin.generar(jugador, monton.tamano, monton.numPiezas)
	monton.objetosIniciales = #contenido
	local perfil = Perfiles.obtener(jugador)
	if perfil then
		perfil.pity = if huboRara then 0 else perfil.pity + 1
		Perfiles.marcarSucio(jugador)
	end
	Perfiles.estadistica(jugador, "montonesActivados", 1)

	desplegarBasura(monton, modelo, contenido)
	anunciar(jugador, monton, contenido)
	return true, "activado"
end

-- ===========================================================================
-- Repoblacion
-- ===========================================================================

local function repoblar()
	for _, monton in montones do
		if monton.estado == "agotado" then
			llenar(monton)
		end
	end
	FeedEvent:FireAllClients(Textos.FEED.repoblacion)
end

local function bucleRepoblacion()
	if repoblacionPendiente then
		return
	end
	local disponibles, agotados = 0, 0
	for _, monton in montones do
		if estaDisponible(monton) then
			disponibles += 1
		end
		if monton.estado == "agotado" then
			agotados += 1
		end
	end
	if disponibles <= GameConfig.UMBRAL_REPOBLACION and agotados > 0 then
		repoblacionPendiente = true
		task.delay(GameConfig.RETRASO_REPOBLACION, function()
			repoblar()
			repoblacionPendiente = false
		end)
	end
end

-- Para pruebas: fuerza la repoblacion ya
function Montones.repoblarAhora()
	repoblar()
end

-- ===========================================================================
-- Arranque
-- ===========================================================================

function Montones.iniciar()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Montones"
	carpeta.Parent = workspace

	for i, ranura in Mundo.ranuras() do
		local tamano = ranura:GetAttribute("Tamano") or "chico"
		local monton: Monton = {
			id = i,
			ranura = ranura,
			tamano = tamano,
			estado = "lleno",
			modelo = nil,
			numPiezas = 0,
			objetosIniciales = 0,
			objetosVivos = 0,
			params = ModelosMonton.parametrosColina(tamano, i, 0),
		}
		montones[i] = monton
		llenar(monton)
	end

	ObjetosPatio.alRetirar:Connect(function(obj)
		local monton = obj.monton
		if monton then
			monton.objetosVivos = math.max(0, monton.objetosVivos - 1)
			if monton.estado == "activo" and monton.objetosVivos == 0 then
				agotar(monton)
			end
		end
	end)

	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if acumulado >= INTERVALO_REPOBLACION then
			acumulado = 0
			bucleRepoblacion()
		end
	end)
end

return Montones
