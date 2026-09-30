--!strict
--[[
	Seguidores (ModuleScript)
	Unica responsabilidad: los modelos de las mascotas que siguen a cada
	jugador por el mapa (diseno v2: "la mascota equipada te sigue y todos la
	ven"). Una por mascota equipada, con su aspecto de nivel, mas el Rey
	Reciclon si lo tiene (va siempre contigo sin ocupar hueco).

	Los mueve el servidor en cada Heartbeat detras del jugador, en abanico,
	con un suavizado exponencial (y de golpe si se alejan mas de 40 studs:
	teletransporte, reaparicion). Anclados, sin colision ni raycast: no
	empujan, no tapan el apuntado y no cuestan fisica. Estan en
	workspace.Seguidores con el tag MascotaSeguidor.

	Se rehacen cuando cambian las equipadas o su nivel
	(Mascotas.alCambiarEquipadas) y al cargar el perfil.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefinicionesMascotas = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMascotas"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosMascota = require(Utilidades:WaitForChild("ModelosMascota"))
local Primitivas = require(Utilidades:WaitForChild("Primitivas"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))

local Seguidores = {}

Seguidores.TAG = "MascotaSeguidor"

-- Donde va cada una respecto al jugador (x a su derecha, z detras)
local HUECOS = {
	Vector3.new(2.8, 0, 3.2),
	Vector3.new(-2.8, 0, 3.2),
	Vector3.new(0, 0, 4.6),
}
local HUECO_REY = Vector3.new(0, 0, 7.5)
local SUAVIZADO = 6
local DISTANCIA_SALTO = 40

type Seguidor = { modelo: Model, desplazamiento: Vector3 }

local carpeta: Folder
local porJugador: { [Player]: { Seguidor } } = {}

local function quitar(jugador: Player)
	for _, s in porJugador[jugador] or {} do
		s.modelo:Destroy()
	end
	porJugador[jugador] = nil
end

local function crear(jugador: Player, id: string, nivel: number, desplazamiento: Vector3): Seguidor?
	local def = DefinicionesMascotas.obtener(id)
	if not def then
		return nil
	end
	local modelo = ModelosMascota.mascota(def, nivel)
	modelo.Name = jugador.Name .. "_" .. id
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	modelo:SetAttribute("Dueno", jugador.UserId)
	CollectionService:AddTag(modelo, Seguidores.TAG)
	Primitivas.etiqueta(modelo, def.nombre, nil, ModelosMascota.alturaMascota(def) + 0.4)
	modelo.Parent = carpeta
	return { modelo = modelo, desplazamiento = desplazamiento }
end

function Seguidores.reconstruir(jugador: Player)
	quitar(jugador)
	local perfil = Perfiles.obtener(jugador)
	if not perfil or not jugador.Parent then
		return
	end
	local lista: { Seguidor } = {}
	for i, id in perfil.equipadas do
		local s = crear(jugador, id, perfil.mascotas[id] or 1, HUECOS[i] or HUECOS[#HUECOS] + Vector3.new(0, 0, 2 * i))
		if s then
			table.insert(lista, s)
		end
	end
	if (perfil.mascotas[DefinicionesMascotas.ID_REY] or 0) > 0 then
		local s = crear(jugador, DefinicionesMascotas.ID_REY, perfil.mascotas[DefinicionesMascotas.ID_REY], HUECO_REY)
		if s then
			table.insert(lista, s)
		end
	end
	porJugador[jugador] = lista
	-- Aparecen ya en su sitio (sin volar desde el origen)
	local root = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		for _, s in lista do
			s.modelo:PivotTo(CFrame.new(root.Position) * CFrame.new(s.desplazamiento))
		end
	end
end

-- Los modelos de un jugador (pruebas)
function Seguidores.de(jugador: Player): { Model }
	local modelos = {}
	for _, s in porJugador[jugador] or {} do
		table.insert(modelos, s.modelo)
	end
	return modelos
end

local function mover(dt: number)
	local alfa = 1 - math.exp(-SUAVIZADO * dt)
	for jugador, lista in porJugador do
		local personaje = jugador.Character
		local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
		local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoide then
			continue
		end
		-- Al suelo bajo el jugador, girado solo en horizontal como el
		local suelo = root.Position.Y - humanoide.HipHeight - root.Size.Y / 2
		local mira = root.CFrame.LookVector
		local base = CFrame.lookAt(Vector3.new(root.Position.X, suelo, root.Position.Z), Vector3.new(root.Position.X + mira.X, suelo, root.Position.Z + mira.Z))
		for _, s in lista do
			local destino = base * CFrame.new(s.desplazamiento)
			local actual = s.modelo:GetPivot()
			if (actual.Position - destino.Position).Magnitude > DISTANCIA_SALTO then
				s.modelo:PivotTo(destino)
			else
				s.modelo:PivotTo(actual:Lerp(destino, alfa))
			end
		end
	end
end

function Seguidores.iniciar()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Seguidores"
	carpeta.Parent = workspace
	Perfiles.alCargar:Connect(function(jugador)
		Seguidores.reconstruir(jugador)
	end)
	for jugador in Perfiles.todos() do
		Seguidores.reconstruir(jugador)
	end
	Mascotas.alCambiarEquipadas:Connect(Seguidores.reconstruir)
	Players.PlayerRemoving:Connect(quitar)
	RunService.Heartbeat:Connect(mover)
end

return Seguidores
