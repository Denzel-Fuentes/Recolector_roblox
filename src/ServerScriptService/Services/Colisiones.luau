--!strict
--[[
	Colisiones (ModuleScript)
	Unica responsabilidad: los grupos de colision del juego.

	  Basura       la basura de las montanas MIENTRAS CAE (sin anclar). Choca
	               con el suelo y consigo misma (asi forma monton), pero no con
	               los personajes: si chocara, el jugador la empujaria al andar
	               (una lluvia de piezas sueltas seria un caos). Una vez
	               asentada, FisicaBasura la ancla y la pasa a Default:
	               entonces si choca, y la montana se sube como escombros (el
	               usuario no quiere atravesar la basura).
	  Personaje    todas las partes de un personaje con 0 rebirths (se marcan
	  PersonajeR1  al aparecer, cuando se anaden accesorios y cuando cambian
	  PersonajeR2  sus rebirths: R2 = 2 o mas).
	  BarreraR1    las paredes de los cuadrantes que se abren con el Rebirth 1
	  BarreraR2    y 2 (tag BarreraCuadrante, atributo Rebirth).

	Diseno v2: el bloqueo de un cuadrante es POR JUGADOR ("quien tiene el
	rebirth pasa y los demas ven lo que les espera"). Se resuelve aqui, en el
	servidor: el grupo PersonajeRk choca con BarreraRr solo si k < r. El
	grupo de las partes del personaje se replica y el cliente, que simula su
	propio personaje, lo respeta. Sin script de cliente y valido con
	streaming. No es la autoridad (un cliente modificado puede atravesar
	paredes): excavar, reclamar y el iman se validan en el servidor.

	Lo demas (suelo, muros, muebles) queda en Default y choca con todos.
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Perfiles = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Perfiles"))

local Colisiones = {}

Colisiones.BASURA = "Basura"
Colisiones.PERSONAJE = "Personaje"
-- Grupo del personaje por rebirths (indice = min(rebirths, 2) + 1)
Colisiones.PERSONAJE_POR_NIVEL = { "Personaje", "PersonajeR1", "PersonajeR2" }
-- Grupo de la barrera por el rebirth que pide
Colisiones.BARRERA_POR_REBIRTH = { [1] = "BarreraR1", [2] = "BarreraR2" }
Colisiones.TAG_BARRERA = "BarreraCuadrante"

local iniciado = false
local nivelActual: { [Player]: number } = {}

local function grupoDe(jugador: Player): string
	local perfil = Perfiles.obtener(jugador)
	local nivel = math.clamp(if perfil then perfil.rebirths else 0, 0, #Colisiones.PERSONAJE_POR_NIVEL - 1)
	return Colisiones.PERSONAJE_POR_NIVEL[nivel + 1]
end

local function marcarPersonaje(jugador: Player, personaje: Model)
	local grupo = grupoDe(jugador)
	for _, d in personaje:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = grupo
		end
	end
end

-- Grupo de colision del personaje de un jugador (pruebas)
function Colisiones.grupoPersonaje(jugador: Player): string
	return grupoDe(jugador)
end

local function marcarBarrera(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local grupo = Colisiones.BARRERA_POR_REBIRTH[inst:GetAttribute("Rebirth") :: any]
	if grupo then
		inst.CollisionGroup = grupo
	end
end

local function registrar(nombre: string)
	if not PhysicsService:IsCollisionGroupRegistered(nombre) then
		PhysicsService:RegisterCollisionGroup(nombre)
	end
end

function Colisiones.iniciar()
	if iniciado then
		return
	end
	iniciado = true
	registrar(Colisiones.BASURA)
	for _, g in Colisiones.PERSONAJE_POR_NIVEL do
		registrar(g)
	end
	for _, g in Colisiones.BARRERA_POR_REBIRTH do
		registrar(g)
	end
	PhysicsService:CollisionGroupSetCollidable(Colisiones.BASURA, Colisiones.BASURA, true)
	PhysicsService:CollisionGroupSetCollidable(Colisiones.BASURA, "Default", true)
	for nivel, personaje in Colisiones.PERSONAJE_POR_NIVEL do
		PhysicsService:CollisionGroupSetCollidable(Colisiones.BASURA, personaje, false)
		for rebirth, barrera in Colisiones.BARRERA_POR_REBIRTH do
			-- nivel = rebirths + 1: choca mientras no tenga los que pide
			PhysicsService:CollisionGroupSetCollidable(personaje, barrera, nivel - 1 < rebirth)
		end
	end

	for _, inst in CollectionService:GetTagged(Colisiones.TAG_BARRERA) do
		marcarBarrera(inst)
	end
	CollectionService:GetInstanceAddedSignal(Colisiones.TAG_BARRERA):Connect(marcarBarrera)

	local function enganchar(jugador: Player)
		local function alPersonaje(personaje: Model)
			marcarPersonaje(jugador, personaje)
			personaje.DescendantAdded:Connect(function(d)
				if d:IsA("BasePart") then
					d.CollisionGroup = grupoDe(jugador)
				end
			end)
		end
		if jugador.Character then
			alPersonaje(jugador.Character)
		end
		jugador.CharacterAdded:Connect(alPersonaje)
	end
	Players.PlayerAdded:Connect(enganchar)
	for _, jugador in Players:GetPlayers() do
		enganchar(jugador)
	end
	-- Al renacer (o al cargar el perfil) cambia el grupo: se repinta solo si
	-- cambio el nivel (el perfil se publica varias veces por segundo)
	Perfiles.alCambiar:Connect(function(jugador, perfil)
		local nivel = math.min(perfil.rebirths, #Colisiones.PERSONAJE_POR_NIVEL - 1)
		if nivelActual[jugador] ~= nivel then
			nivelActual[jugador] = nivel
			if jugador.Character then
				marcarPersonaje(jugador, jugador.Character)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(jugador)
		nivelActual[jugador] = nil
	end)
end

return Colisiones
