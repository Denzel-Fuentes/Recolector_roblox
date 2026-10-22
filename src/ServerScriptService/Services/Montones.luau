--!strict
--[[
	Montones (ModuleScript)
	Unica responsabilidad: el ciclo de vida de cada monton del patio:
	lleno (colina con prompt) -> activo (montana de basura) -> terminado
	(menos del 25 %) -> a los REPOSICION_MONTON s, lleno otra vez.

	=== La colina se convierte en una montana de basura ===
	Cada monton es una COLINA lisa (ModelosMonton) cuyo tamano depende de
	numPiezas (en las zonas del norte, tenida del material que destaca). Al activarlo,
	GeneradorBotin decide que sale, cada item recibe su modelo real
	(ObjetosPatio.modeloPara) y se reparte por TODO el volumen de la colina
	(ModelosMonton.puntosEnColina): la colina se sustituye por una montana de
	basura con su mismo bulto (decision del usuario: "mucha basura,
	equivalente al tamano del monton"). Las lomas se destruyen (chocarian con
	la basura) y el modelo del monton queda como contenedor. La basura brota
	de abajo arriba en DURACION_BROTE y cae con fisica (FisicaBasura).

	=== Diseno v2 ===
	  Zona       la basura de un monton va revuelta; la zona de su
	             cuadrante decide la mezcla (GameConfig.CUADRANTES; el
	             cuadrante es el atributo de la ranura horneada o, en un place
	             anterior al mundo v2, se deduce de la posicion).
	  Bloqueo    (5 oct) ya no hay cuadrantes cerrados: todo monton se
	             excava. Los rebirths abren TIPOS de basura: el monton solo
	             trae los del excavador (GeneradorBotin) y nadie recoge un tipo
	             que no tiene (ObjetosPatio, "materialBloqueado").
	  Prioridad  se anota quien lo excavo y cuando: ObjetosPatio no deja a
	             nadie mas recoger sus piezas durante PRIORIDAD_EXCAVADOR s.
	  Reposicion un monton que baja del 25 % (terminado) o se vacia vuelve a
	             crecer a los REPOSICION_MONTON s: sus restos se retiran y
	             aparece la colina. Antes se reponian los agotados cuando
	             quedaban pocos en el patio, y un monton con tres piezas
	             escondidas se quedaba muerto para siempre.

	La cuenta de objetos vivos la lleva este modulo escuchando
	ObjetosPatio.alRetirar; asi ObjetosPatio no sabe que existe un monton.

	=== Limites (rendimiento) ===
	Cada pieza es un modelo con fisica replicado a todos, asi que excavar
	tiene dos frenos (GameConfig): el patio no pasa de MAX_OBJETOS_PATIO
	objetos, y cada jugador tiene como mucho MONTONES_POR_JUGADOR montones
	suyos a medias. "A medias" = estaDisponible: al bajar del 25 % ya no
	cuenta, para que nadie quede bloqueado por las piezas que otro dejo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Textos = require(Config:WaitForChild("Textos"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosMonton = require(Utilidades:WaitForChild("ModelosMonton"))
local Cuadrantes = require(Utilidades:WaitForChild("Cuadrantes"))
local Red = require(Utilidades:WaitForChild("Red"))
local Idioma = require(Utilidades:WaitForChild("Idioma"))
local Senal = require(Utilidades:WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local TiposPatio = require(Servicios:WaitForChild("TiposPatio"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mundo = require(Servicios:WaitForChild("Mundo"))
local GeneradorBotin = require(Servicios:WaitForChild("GeneradorBotin"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))
local FisicaBasura = require(Servicios:WaitForChild("FisicaBasura"))

local FeedEvent = Red.evento("FeedEvent")

type Monton = TiposPatio.Monton
type Item = TiposPatio.Item

local Montones = {}

-- (jugador, tamano, zona) tras activar un monton; la escucha el Tutorial
Montones.alExcavar = Senal.nueva() :: Senal.Senal<Player, string, string>

local DURACION_BROTE = 1.5 -- segundos que tarda en brotar toda la montana (de abajo arriba, para que lo de abajo asiente antes)
local MARGEN_EXCAVAR = 14 -- studs mas alla del radio desde los que se acepta el prompt

local montones: { Monton } = {}
local carpeta: Folder -- workspace.Montones
local rng = Random.new()

-- ===========================================================================
-- Modelo y estados
-- ===========================================================================

-- La colina (lleno), o las marcas planas (agotado)
local function crearModelo(monton: Monton)
	if monton.modelo then
		monton.modelo:Destroy()
	end
	local destaca = (GameConfig.ZONAS[monton.zona] or {}).destaca
	local modelo = ModelosMonton.monton(monton.tamano, monton.estado == "agotado", monton.id, monton.numPiezas, destaca)
	modelo.Name = "Monton_" .. monton.id
	modelo:SetAttribute("MontonId", monton.id)
	modelo:SetAttribute("Tamano", monton.tamano)
	modelo:SetAttribute("Estado", monton.estado)
	modelo:SetAttribute("Piezas", monton.numPiezas)
	modelo:SetAttribute("Cuadrante", monton.cuadrante)
	modelo:SetAttribute("Zona", monton.zona)
	modelo:PivotTo(CFrame.new(monton.ranura.Position))
	modelo.Parent = carpeta
	monton.modelo = modelo
	if monton.estado == "lleno" and modelo.PrimaryPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PromptExcavar"
		prompt.ActionText = Textos.PATIO.excavar
		local objeto = if destaca
			then Idioma.mensaje("PATIO.montonRico", { material = Idioma.mensaje("MATERIALES." .. destaca) })
			else Idioma.mensaje("PATIO.monton")
		-- El texto en espanol es el respaldo; el cliente usa el atributo (Prompts)
		prompt.ObjectText = Idioma.resolver(objeto)
		prompt:SetAttribute("MensajeObjeto", Idioma.codificar(objeto))
		prompt.HoldDuration = GameConfig.DURACION_EXCAVAR
		prompt.MaxActivationDistance = ModelosMonton.radioMonton(monton.tamano) + 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = modelo.PrimaryPart
	end
end

-- Un monton nuevo (al arrancar o al reponerse): tantos objetos dara como piezas
local function llenar(monton: Monton)
	local def = GameConfig.TAMANOS_MONTON[monton.tamano] or GameConfig.TAMANOS_MONTON.chico
	monton.estado = "lleno"
	monton.numPiezas = rng:NextInteger(def.min, def.max)
	monton.objetosIniciales = 0
	monton.objetosVivos = 0
	monton.activadoPor = nil
	monton.excavador = nil
	monton.params = ModelosMonton.parametrosColina(monton.tamano, monton.id, monton.numPiezas)
	crearModelo(monton)
end

local function agotar(monton: Monton)
	monton.estado = "agotado"
	monton.activadoPor = nil
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

-- Objetos de montana que hay ahora en el patio (lo que cuesta rendimiento)
local function objetosEnPatio(): number
	local n = 0
	for _, monton in montones do
		if monton.estado == "activo" then
			n += monton.objetosVivos
		end
	end
	return n
end

-- Montones que el jugador abrio y aun tiene a medias
function Montones.activosDe(jugador: Player): number
	local n = 0
	for _, monton in montones do
		if monton.activadoPor == jugador and monton.estado == "activo" and estaDisponible(monton) then
			n += 1
		end
	end
	return n
end

-- El monton que el jugador tiene a medias (el que le impide abrir otro), o
-- nil. El aviso de "termina tu montón" lo hace latir para que lo encuentre
function Montones.pendienteDe(jugador: Player): Monton?
	for _, monton in montones do
		if monton.activadoPor == jugador and monton.estado == "activo" and estaDisponible(monton) then
			return monton
		end
	end
	return nil
end

-- Deja de contar sus montones contra el limite (sale del servidor, o pruebas)
function Montones.liberar(jugador: Player)
	for _, monton in montones do
		if monton.activadoPor == jugador then
			monton.activadoPor = nil
		end
		if monton.excavador == jugador then
			monton.excavador = nil
		end
	end
end

-- ===========================================================================
-- Reposicion
-- ===========================================================================

-- Retira los restos que no se esta llevando nadie y vuelve a la colina
local function reponer(monton: Monton)
	if monton.estado == "lleno" then
		return
	end
	monton.estado = "reponiendo" -- que alRetirar no lo agote mientras se vacia
	for id, obj in ObjetosPatio.todos() do
		if obj.monton == monton then
			ObjetosPatio.retirar(id)
		end
	end
	llenar(monton)
end

-- Una sola reposicion pendiente por monton, REPOSICION_MONTON s despues de
-- que se termine
local function programarReposicion(monton: Monton)
	if monton.reposicion then
		return
	end
	monton.reposicion = true
	task.delay(GameConfig.REPOSICION_MONTON, function()
		monton.reposicion = false
		reponer(monton)
	end)
end

-- Para pruebas y admin: repone ya todo lo que no esta lleno
function Montones.repoblarAhora()
	for _, monton in montones do
		reponer(monton)
	end
	FeedEvent:FireAllClients(Idioma.mensaje("FEED.repoblacion"))
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

local function anunciar(jugador: Player, monton: Monton)
	if monton.tamano == "grande" then
		FeedEvent:FireAllClients(Idioma.mensaje("FEED.montonGrande", { jugador = jugador.DisplayName }))
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
	local modelo = monton.modelo
	if not modelo then
		return false, "sinModelo"
	end
	if objetosEnPatio() + monton.numPiezas > GameConfig.MAX_OBJETOS_PATIO then
		return false, "patioLleno"
	end
	if Montones.activosDe(jugador) >= GameConfig.MONTONES_POR_JUGADOR then
		return false, "yaTienesUno"
	end
	monton.estado = "activo"
	monton.activadoPor = jugador
	monton.excavador = jugador
	monton.activadoEn = os.clock()
	modelo:SetAttribute("Estado", "activo")
	modelo:SetAttribute("Excavador", jugador.UserId)
	for _, hijo in modelo:GetChildren() do
		if hijo:IsA("ProximityPrompt") or (hijo:IsA("BasePart") and hijo.Name:match("^Loma_")) then
			hijo:Destroy()
		end
	end

	local contenido = GeneradorBotin.generar(jugador, monton.tamano, monton.zona, monton.numPiezas)
	monton.objetosIniciales = #contenido
	Perfiles.estadistica(jugador, "montonesActivados", 1)

	desplegarBasura(monton, modelo, contenido)
	anunciar(jugador, monton)
	Montones.alExcavar:Fire(jugador, monton.tamano, monton.zona)
	return true, "activado"
end

-- ===========================================================================
-- Arranque
-- ===========================================================================

function Montones.iniciar()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Montones"
	carpeta.Parent = workspace

	for i, ranura in Mundo.ranuras() do
		local tamano = ranura:GetAttribute("Tamano")
		if typeof(tamano) ~= "string" or not GameConfig.TAMANOS_MONTON[tamano] then
			tamano = "chico"
		end
		-- El mundo v2 hornea el cuadrante; uno anterior, se deduce del sitio
		local cuadrante = ranura:GetAttribute("Cuadrante")
		if typeof(cuadrante) ~= "number" then
			cuadrante = Cuadrantes.en(ranura.Position) or 1
		end
		local monton: Monton = {
			id = i,
			ranura = ranura,
			tamano = tamano :: string,
			cuadrante = cuadrante :: number,
			zona = Cuadrantes.zona(cuadrante :: number),
			estado = "lleno",
			modelo = nil,
			numPiezas = 0,
			objetosIniciales = 0,
			objetosVivos = 0,
			params = ModelosMonton.parametrosColina(tamano :: string, i, 0),
			activadoEn = 0,
			reposicion = false,
		}
		montones[i] = monton
		llenar(monton)
	end

	Players.PlayerRemoving:Connect(Montones.liberar)

	ObjetosPatio.alRetirar:Connect(function(obj)
		local monton = obj.monton
		if not monton then
			return
		end
		monton.objetosVivos = math.max(0, monton.objetosVivos - 1)
		if monton.estado == "activo" then
			if monton.objetosVivos == 0 then
				agotar(monton)
			end
			if not estaDisponible(monton) then
				programarReposicion(monton)
			end
		end
	end)
end

return Montones
