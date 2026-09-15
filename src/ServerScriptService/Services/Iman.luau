--!strict
--[[
	Iman (ModuleScript)
	Unica responsabilidad: la mejora Iman, lo UNICO que recoge basura sin
	clic (decision del usuario). Cada INTERVALO_IMAN, para cada jugador con
	Iman: lo que esta dentro de su radio se suelta de la montana y se arrastra
	hacia el; cuando un objeto arrastrado llega a DISTANCIA_RECLAMO_IMAN entra
	en la bolsa. No se usa .Touched.

	Con cientos de objetos por montana, primero se descartan montanas enteras
	por distancia a su centro y solo despues se mide objeto a objeto (a la
	SUPERFICIE, Utilidades/Geometria). La bolsa llena corta la atraccion: todo
	ocupa un hueco, billetes incluidos (el dinero solo sale del contenedor).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Geometria = require(Utilidades:WaitForChild("Geometria"))
local ModelosMonton = require(Utilidades:WaitForChild("ModelosMonton"))

local Servicios = ServerScriptService:WaitForChild("Services")
local TiposPatio = require(Servicios:WaitForChild("TiposPatio"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))
local FisicaBasura = require(Servicios:WaitForChild("FisicaBasura"))
local Montones = require(Servicios:WaitForChild("Montones"))

type Monton = TiposPatio.Monton

local Iman = {}

local VELOCIDAD_ARRASTRE = 14 -- studs por segundo
local ALTURA_MINIMA = 1.5 -- los objetos arrastrados no se hunden en el suelo

local function montonesCercanos(posicion: Vector3, radio: number): { [Monton]: boolean }
	local cerca = {}
	for _, monton in Montones.todos() do
		if (monton.ranura.Position - posicion).Magnitude <= radio + ModelosMonton.radioMonton(monton.tamano) * 1.1 then
			cerca[monton] = true
		end
	end
	return cerca
end

local function atraer(jugador: Player, posicion: Vector3, radioIman: number)
	local paso = VELOCIDAD_ARRASTRE * GameConfig.INTERVALO_IMAN
	local bolsaLlena = Bolsa.estaLlena(jugador)
	local alcance = radioIman + 6 -- filtro barato antes de medir la caja
	local cerca = montonesCercanos(posicion, alcance)
	for id, obj in ObjetosPatio.todos() do
		if obj.reclamadoPor or obj.item.tipo == "bolsa" or not (obj.suelto or (obj.monton and cerca[obj.monton])) then
			continue
		end
		local pivot = obj.modelo:GetPivot()
		local delta = posicion - pivot.Position
		if delta.Magnitude > alcance then
			continue
		end
		local d = Geometria.distanciaASuperficie(obj.modelo, posicion)
		if obj.suelto and d <= GameConfig.DISTANCIA_RECLAMO_IMAN then
			-- Solo lo que el iman ha arrastrado entra solo en la bolsa
			ObjetosPatio.reclamar(jugador, id, "iman")
		elseif d <= radioIman and not bolsaLlena then
			FisicaBasura.soltar(obj)
			local avance = math.min(paso, delta.Magnitude - 1.5)
			if avance > 0 then
				local nuevo = pivot.Position + delta.Unit * avance
				obj.modelo:PivotTo(CFrame.new(Vector3.new(nuevo.X, math.max(ALTURA_MINIMA, nuevo.Y), nuevo.Z)) * pivot.Rotation)
			end
		end
	end
end

local function bucle()
	for _, jugador in Players:GetPlayers() do
		local personaje = jugador.Character
		local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
		local radioIman = Mejoras.valor(jugador, "Iman")
		if root and root:IsA("BasePart") and radioIman > 0 and Perfiles.obtener(jugador) then
			atraer(jugador, root.Position, radioIman)
		end
	end
end

function Iman.iniciar()
	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if acumulado >= GameConfig.INTERVALO_IMAN then
			acumulado = 0
			bucle()
		end
	end)
end

return Iman
