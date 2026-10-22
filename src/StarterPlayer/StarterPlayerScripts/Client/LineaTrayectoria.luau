--!strict
--[[
	LineaTrayectoria (ModuleScript)
	Unica responsabilidad: la ayuda de punteria del diseno v2, una linea de
	puntos que dibuja por donde ira la bolsa mientras se carga el tiro, solo
	en los primeros LANZAMIENTOS_CON_LINEA lanzamientos (despues hay que
	aprender a tirar: la linea no se vende, haria el trabajo por el jugador).

	Usa las mismas cuentas que el servidor (Utilidades/Trayectoria) con la
	fuerza de la carga y el Brazo del jugador; en el primer lanzamiento, que
	siempre entra, dibuja el arco al contenedor general. Son partes LOCALES (solo las
	ve este cliente), sin colision ni raycast.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local DefinicionesPunteria = require(Config:WaitForChild("DefinicionesPunteria"))
local Trayectoria = require(Shared:WaitForChild("Utilidades"):WaitForChild("Trayectoria"))
local Contenedores = require(Shared:WaitForChild("Utilidades"):WaitForChild("Contenedores"))

local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))

local LineaTrayectoria = {}

local PUNTOS = 22
local jugador = Players.LocalPlayer

local carpeta: Folder? = nil
local bolas: { BasePart } = {}

local function asegurarBolas()
	if carpeta and carpeta.Parent then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "LineaTrayectoria"
	f.Parent = workspace
	carpeta = f
	bolas = {}
	for i = 1, PUNTOS do
		local p = Instance.new("Part")
		p.Name = "Punto" .. i
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * (0.45 - 0.2 * i / PUNTOS)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Paleta.UI_PAPEL
		p.Transparency = 1
		p.Parent = f
		table.insert(bolas, p)
	end
end

-- Hay que dibujarla: quedan lanzamientos con ayuda
function LineaTrayectoria.activa(): boolean
	return EstadoCliente.estadistica("lanzamientos") < DefinicionesPunteria.LANZAMIENTOS_CON_LINEA
end

function LineaTrayectoria.ocultar()
	for _, p in bolas do
		p.Transparency = 1
	end
end

-- Dibuja el arco de un tiro hacia `punto` con la fuerza `carga` (0..1)
function LineaTrayectoria.dibujar(punto: Vector3, carga: number)
	local root = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or not LineaTrayectoria.activa() then
		LineaTrayectoria.ocultar()
		return
	end
	asegurarBolas()
	local origen = Trayectoria.origen(root.Position)
	local objetivo: Vector3
	local general = Contenedores.general()
	if EstadoCliente.estadistica("lanzamientos") == 0 and general then
		objetivo = general.zona.Position
	else
		local brazo = DefinicionesMejoras.valor("Brazo", EstadoCliente.nivelMejora("Brazo"))
		objetivo = Trayectoria.objetivo(origen, punto, math.max(carga, 0.1), brazo)
	end
	local puntos = Trayectoria.puntos(origen, objetivo, PUNTOS)
	for i, p in bolas do
		p.CFrame = CFrame.new(puntos[i + 1])
		p.Transparency = 0.15
	end
end

return LineaTrayectoria
