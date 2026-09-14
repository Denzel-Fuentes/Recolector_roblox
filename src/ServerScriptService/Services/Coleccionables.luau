--!strict
--[[
	Coleccionables (ModuleScript)
	Unica responsabilidad: figurinas, cintas y trajes de cada jugador, y vestir
	al personaje con el traje puesto.

	Figurinas fijas: el objeto del patio es visible para todos; cada jugador la
	recoge UNA vez (queda en su perfil) y su cliente la oculta localmente.

	Traje puesto (cambio frente a KOTAMON, donde se regalan a Jenny): se recolora
	el personaje (BodyColors) y se le suelda un accesorio de bloques a la cabeza.
	Al quitarlo se restauran los colores que tenia al aparecer, guardados por
	personaje. Nunca se destruyen ropas del jugador: solo se ocultan mientras
	lleva el traje.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefinicionesColeccionables = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesColeccionables"))
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))

local Coleccionables = {}

-- (jugador, tipo, id) tipo = "figurina" | "cinta" | "traje"
Coleccionables.alAgregar = Senal.nueva() :: Senal.Senal<Player, string, string>
Coleccionables.alCambiarTraje = Senal.nueva() :: Senal.Senal<Player>

local function mapa(perfil: Perfiles.Perfil, tipo: string): { [string]: boolean }
	if tipo == "figurina" then
		return perfil.figurinas
	elseif tipo == "cinta" then
		return perfil.cintas
	elseif tipo == "traje" then
		return perfil.trajes
	end
	return {}
end

function Coleccionables.tiene(jugador: Player, tipo: string, id: string): boolean
	local perfil = Perfiles.obtener(jugador)
	return perfil ~= nil and mapa(perfil, tipo)[id] == true
end

function Coleccionables.cuenta(jugador: Player, tipo: string): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0
	end
	local n = 0
	for _ in mapa(perfil, tipo) do
		n += 1
	end
	return n
end

-- Devuelve true si era nuevo
function Coleccionables.agregar(jugador: Player, tipo: string, id: string): boolean
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false
	end
	local m = mapa(perfil, tipo)
	if m[id] then
		return false
	end
	m[id] = true
	Perfiles.estadistica(jugador, tipo .. "sEncontradas", 1)
	Perfiles.marcarSucio(jugador)
	Coleccionables.alAgregar:Fire(jugador, tipo, id)
	return true
end

-- Ids que le faltan al jugador de un tipo. Para figurinas, solo las aleatorias
-- (las fijas se encuentran en el patio, no en montones).
function Coleccionables.faltantes(jugador: Player, tipo: string): { string }
	local lista = {}
	if tipo == "figurina" then
		for _, f in DefinicionesColeccionables.figurinasAleatorias() do
			if not Coleccionables.tiene(jugador, "figurina", f.id) then
				table.insert(lista, f.id)
			end
		end
	elseif tipo == "cinta" then
		for _, c in DefinicionesColeccionables.CINTAS do
			if not Coleccionables.tiene(jugador, "cinta", c.id) then
				table.insert(lista, c.id)
			end
		end
	elseif tipo == "traje" then
		for _, t in DefinicionesColeccionables.trajesGratis() do
			if not Coleccionables.tiene(jugador, "traje", t.id) then
				table.insert(lista, t.id)
			end
		end
	end
	return lista
end

-- === Trajes en el personaje ===

type ColoresOriginales = {
	colores: { [string]: Color3 },
	ropaOculta: { Instance },
}
local originales: { [Player]: ColoresOriginales } = {}

local PARTES_COLOR = { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }

local function guardarOriginales(jugador: Player, personaje: Model)
	local bc = personaje:FindFirstChildOfClass("BodyColors")
	local colores = {}
	if bc then
		for _, prop in PARTES_COLOR do
			colores[prop] = (bc :: any)[prop]
		end
	end
	originales[jugador] = { colores = colores, ropaOculta = {} }
end

local function quitarAccesorio(personaje: Model)
	local viejo = personaje:FindFirstChild("AccesorioTraje")
	if viejo then
		viejo:Destroy()
	end
end

local function crearAccesorio(personaje: Model, traje: DefinicionesColeccionables.Traje)
	quitarAccesorio(personaje)
	if traje.accesorio == "ninguno" then
		return
	end
	local cabeza = personaje:FindFirstChild("Head")
	if not cabeza or not cabeza:IsA("BasePart") then
		return
	end
	local acc = Instance.new("Part")
	acc.Name = "AccesorioTraje"
	acc.Material = Enum.Material.SmoothPlastic
	acc.Color = traje.colorAccesorio
	acc.CanCollide = false
	acc.CanQuery = false
	acc.Massless = true
	local offset = CFrame.new(0, 0.9, 0)
	if traje.accesorio == "gorra" then
		acc.Size = Vector3.new(1.6, 0.4, 1.9)
		offset = CFrame.new(0, 0.7, -0.2)
	elseif traje.accesorio == "casco" then
		acc.Shape = Enum.PartType.Ball
		acc.Size = Vector3.new(1.7, 1.7, 1.7)
		offset = CFrame.new(0, 0.45, 0)
	elseif traje.accesorio == "escafandra" then
		acc.Shape = Enum.PartType.Ball
		acc.Size = Vector3.new(2.2, 2.2, 2.2)
		acc.Transparency = 0.45
		offset = CFrame.new(0, 0.1, 0)
	elseif traje.accesorio == "corona" then
		acc.Shape = Enum.PartType.Cylinder
		acc.Size = Vector3.new(0.5, 1.4, 1.4)
		acc.Material = Enum.Material.Neon
		offset = CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90))
	end
	acc.CFrame = cabeza.CFrame * offset
	acc.Parent = personaje
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = cabeza
	weld.Part1 = acc
	weld.Parent = acc
end

local function aplicarColores(personaje: Model, traje: DefinicionesColeccionables.Traje?, orig: ColoresOriginales?)
	local bc = personaje:FindFirstChildOfClass("BodyColors")
	if not bc then
		return
	end
	if traje then
		bc.TorsoColor3 = traje.colorCuerpo
		bc.LeftArmColor3 = traje.colorBrazos
		bc.RightArmColor3 = traje.colorBrazos
		bc.LeftLegColor3 = traje.colorPiernas
		bc.RightLegColor3 = traje.colorPiernas
	elseif orig then
		for prop, color in orig.colores do
			(bc :: any)[prop] = color
		end
	end
end

-- La ropa (Shirt/Pants) tapa los BodyColors: se oculta mientras hay traje
-- moviendola a ServerStorage-like (Parent nil) y se devuelve al quitarlo.
local function ocultarRopa(personaje: Model, orig: ColoresOriginales, ocultar: boolean)
	if ocultar then
		for _, hijo in personaje:GetChildren() do
			if hijo:IsA("Shirt") or hijo:IsA("Pants") or hijo:IsA("ShirtGraphic") then
				hijo.Parent = nil
				table.insert(orig.ropaOculta, hijo)
			end
		end
	else
		for _, ropa in orig.ropaOculta do
			ropa.Parent = personaje
		end
		orig.ropaOculta = {}
	end
end

function Coleccionables.vestir(jugador: Player)
	local personaje = jugador.Character
	local perfil = Perfiles.obtener(jugador)
	if not personaje or not perfil then
		return
	end
	local orig = originales[jugador]
	if not orig then
		guardarOriginales(jugador, personaje)
		orig = originales[jugador]
	end
	local traje = if perfil.trajePuesto then DefinicionesColeccionables.TRAJE_POR_ID[perfil.trajePuesto] else nil
	if traje then
		ocultarRopa(personaje, orig :: ColoresOriginales, true)
		aplicarColores(personaje, traje, nil)
		crearAccesorio(personaje, traje)
	else
		ocultarRopa(personaje, orig :: ColoresOriginales, false)
		aplicarColores(personaje, nil, orig)
		quitarAccesorio(personaje)
	end
end

-- id nil = quitar el traje
function Coleccionables.ponerTraje(jugador: Player, id: string?): (boolean, string)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false, "sinPerfil"
	end
	if id ~= nil then
		local traje = DefinicionesColeccionables.TRAJE_POR_ID[id]
		if not traje then
			return false, "trajeDesconocido"
		end
		if not Coleccionables.tiene(jugador, "traje", id) then
			return false, "noEncontrado"
		end
	end
	perfil.trajePuesto = id
	Perfiles.marcarSucio(jugador)
	Coleccionables.vestir(jugador)
	Coleccionables.alCambiarTraje:Fire(jugador)
	return true, id or ""
end

local function engancharPersonaje(jugador: Player)
	jugador.CharacterAdded:Connect(function(personaje)
		originales[jugador] = nil
		-- BodyColors llega un instante despues del personaje
		task.delay(0.2, function()
			if jugador.Character == personaje and personaje.Parent then
				guardarOriginales(jugador, personaje)
				Coleccionables.vestir(jugador)
			end
		end)
	end)
end

Players.PlayerAdded:Connect(engancharPersonaje)
for _, jugador in Players:GetPlayers() do
	engancharPersonaje(jugador)
end
Players.PlayerRemoving:Connect(function(jugador)
	originales[jugador] = nil
end)

Perfiles.alCargar:Connect(function(jugador)
	if jugador.Character then
		Coleccionables.vestir(jugador)
	end
end)

-- Color del whitebox de una figurina en la estanteria (para Parcelas)
function Coleccionables.colorFigurina(): Color3
	return Paleta.FIGURINA
end

return Coleccionables
