--!strict
--[[
	FisicaBasura (ModuleScript)
	Unica responsabilidad: que la basura de las montanas caiga, se amontone y
	se quede quieta sin costar fisica para siempre.

	Peticion del usuario: sin fisica, al recoger las de abajo las de arriba se
	quedaban flotando. Cada objeto es un modelo soldado a su parte principal.
	Mientras CAE va sin anclar en el grupo de colision Basura (choca con el
	suelo y con otra basura, atraviesa a los personajes: que una lluvia de
	barriles no los empuje ni los encajone; ver Colisiones). Cuando lleva ~1 s
	quieto se ANCLA y pasa a Default: entonces SI choca con los personajes y la
	montana se sube como escombros (el usuario no quiere atravesarla); nunca se
	ancla con un personaje metido en la pieza, que quedaria encajonado. Asi el
	servidor tampoco simula cientos de cuerpos (ni una bola rueda hasta la
	caseta: tope de 8 s suelto).

	Cuando alguien recoge una pieza (ObjetosPatio.alRetirar), las vecinas de
	encima se sueltan otra vez, caen y se vuelven a asentar; una pieza suelta
	que se mueve mas de un stud despierta a su vez a las suyas (cascada).

	Todo es del servidor (SetNetworkOwner(nil)): posiciones deterministas y
	nadie empuja basura desde su cliente. El estado por objeto que solo importa
	aqui (cuando se solto, desde donde) vive en una tabla propia, no en el
	Objeto: los demas modulos solo leen `asentado`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Geometria = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Geometria"))

local Servicios = ServerScriptService:WaitForChild("Services")
local TiposPatio = require(Servicios:WaitForChild("TiposPatio"))
local Colisiones = require(Servicios:WaitForChild("Colisiones"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))

type Objeto = TiposPatio.Objeto
type Monton = TiposPatio.Monton

local FisicaBasura = {}

local PROPIEDADES_BASURA = PhysicalProperties.new(1, 2, 0, 1, 1) -- densidad, friccion, elasticidad: mucha friccion para que amontone
local VELOCIDAD_QUIETO = 0.4
local SEGUNDOS_QUIETO = 1
local SEGUNDOS_MAX_SUELTO = 8 -- por si algo rueda y rueda
local RADIO_VECINOS = 5
local INTERVALO_ASENTAR = 0.5
local DISTANCIA_PERSONAJE = 1.6 -- a menos de esto de un personaje no se ancla (lo encajonaria)

type Caida = { desde: number, quietoDesde: number?, posSuelta: Vector3, propago: boolean }
local caidas: { [Objeto]: Caida } = {} -- solo los objetos sueltos (sin anclar)

-- ===========================================================================
-- Soltar y anclar
-- ===========================================================================

-- Suelda las partes a la principal y suelta el modelo: a partir de aqui cae
function FisicaBasura.darFisica(obj: Objeto)
	local modelo = obj.modelo
	if not modelo:IsA("Model") then
		return
	end
	local principal = modelo.PrimaryPart
	if not principal then
		return
	end
	local partes: { BasePart } = {}
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(partes, p)
			p.CustomPhysicalProperties = PROPIEDADES_BASURA
			p.CollisionGroup = Colisiones.BASURA
			p.CanCollide = true
			p.CanTouch = false
			if p ~= principal and not p:FindFirstChildOfClass("WeldConstraint") then
				local w = Instance.new("WeldConstraint")
				w.Part0 = principal
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	for _, p in partes do
		p.Anchored = false
	end
	obj.asentado = false
	caidas[obj] = { desde = os.clock(), quietoDesde = nil, posSuelta = principal.Position, propago = false }
	if modelo.Parent then
		pcall(principal.SetNetworkOwner, principal, nil)
	end
end

-- Quieto: se ancla (deja de costar fisica) y pasa a Default, que choca con
-- los personajes.
local function anclar(obj: Objeto)
	for _, p in obj.modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CollisionGroup = "Default"
		end
	end
	obj.asentado = true
	caidas[obj] = nil
end

-- El iman se lo lleva: se ancla (lo arrastra PivotTo) y deja de chocar
function FisicaBasura.soltar(obj: Objeto)
	if obj.suelto then
		return
	end
	obj.suelto = true
	anclar(obj)
	for _, p in obj.modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
		end
	end
	if obj.monton then
		FisicaBasura.despertarVecinos(obj.monton, obj.modelo:GetPivot().Position)
	end
end

-- ===========================================================================
-- Asentar y despertar
-- ===========================================================================

-- Hay un personaje metido en la caja del objeto (o pegado a ella)
local function personajeEncima(obj: Objeto): boolean
	for _, jugador in Players:GetPlayers() do
		local personaje = jugador.Character
		local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and Geometria.distanciaASuperficie(obj.modelo, root.Position) < DISTANCIA_PERSONAJE then
			return true
		end
	end
	return false
end

-- Al desaparecer (o moverse) una pieza, lo que tenia alrededor y por encima
-- vuelve a caer
function FisicaBasura.despertarVecinos(monton: Monton, posicion: Vector3)
	for _, otro in ObjetosPatio.todos() do
		if otro.monton == monton and otro.asentado and not otro.suelto and not otro.reclamadoPor and otro.modelo.Parent then
			local p = otro.modelo:GetPivot().Position
			if (p - posicion).Magnitude <= RADIO_VECINOS and p.Y >= posicion.Y - 1.5 then
				FisicaBasura.darFisica(otro)
			end
		end
	end
end

local function estaQuieto(principal: BasePart): boolean
	return principal.AssemblyLinearVelocity.Magnitude < VELOCIDAD_QUIETO and principal.AssemblyAngularVelocity.Magnitude < VELOCIDAD_QUIETO
end

-- Cada INTERVALO_ASENTAR: ancla lo que lleva un rato quieto, rescata lo que
-- se haya colado por el suelo y propaga la cascada.
local function bucleAsentar()
	local ahora = os.clock()
	for obj, caida in caidas do
		local monton = obj.monton
		local principal = if obj.modelo:IsA("Model") then obj.modelo.PrimaryPart else nil
		if not monton or obj.suelto or obj.reclamadoPor or not obj.modelo.Parent or not principal then
			caidas[obj] = nil
			continue
		end
		local pos = principal.Position
		if pos.Y < monton.ranura.Position.Y - 3 then
			-- Se colo por el suelo: de vuelta al centro de la montana, desde arriba
			obj.modelo:PivotTo(CFrame.new(monton.ranura.Position + Vector3.new(0, monton.params.h + 2, 0)))
			principal.AssemblyLinearVelocity = Vector3.zero
		end
		if estaQuieto(principal) then
			caida.quietoDesde = caida.quietoDesde or ahora
		else
			caida.quietoDesde = nil
		end
		if not caida.propago and (pos - caida.posSuelta).Magnitude > 1 then
			caida.propago = true
			FisicaBasura.despertarVecinos(monton, caida.posSuelta)
		end
		local llevaQuieto = caida.quietoDesde ~= nil and ahora - caida.quietoDesde >= SEGUNDOS_QUIETO
		if (llevaQuieto or ahora - caida.desde > SEGUNDOS_MAX_SUELTO) and not personajeEncima(obj) then
			anclar(obj)
		end
	end
end

function FisicaBasura.iniciar()
	ObjetosPatio.alRetirar:Connect(function(obj)
		caidas[obj] = nil
		if obj.monton and not obj.suelto then
			FisicaBasura.despertarVecinos(obj.monton, obj.modelo:GetPivot().Position)
		end
	end)
	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if acumulado >= INTERVALO_ASENTAR then
			acumulado = 0
			bucleAsentar()
		end
	end)
end

return FisicaBasura
