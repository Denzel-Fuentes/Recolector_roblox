--!strict
--[[
	Colisiones (ModuleScript)
	Unica responsabilidad: los grupos de colision del juego.

	  Basura     la basura de las montanas MIENTRAS CAE (sin anclar). Choca
	             con el suelo y consigo misma (asi forma monton), pero no con
	             los personajes: si chocara, el jugador la empujaria al andar
	             (una lluvia de 270 piezas sueltas seria un caos). Una vez
	             asentada, Botin la ancla y la pasa a Default: entonces si
	             choca, y la montana se sube como escombros (el usuario no
	             quiere atravesar la basura).
	  Personaje  todas las partes de los personajes (se marcan al aparecer y
	             cuando se anaden accesorios).

	Lo demas (suelo, muros, muebles) queda en Default y choca con ambos.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local Colisiones = {}

Colisiones.BASURA = "Basura"
Colisiones.PERSONAJE = "Personaje"

local iniciado = false

local function marcarPersonaje(personaje: Model)
	local function marcar(inst: Instance)
		if inst:IsA("BasePart") then
			inst.CollisionGroup = Colisiones.PERSONAJE
		end
	end
	for _, d in personaje:GetDescendants() do
		marcar(d)
	end
	personaje.DescendantAdded:Connect(marcar)
end

function Colisiones.iniciar()
	if iniciado then
		return
	end
	iniciado = true
	for _, nombre in { Colisiones.BASURA, Colisiones.PERSONAJE } do
		if not PhysicsService:IsCollisionGroupRegistered(nombre) then
			PhysicsService:RegisterCollisionGroup(nombre)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(Colisiones.BASURA, Colisiones.PERSONAJE, false)
	PhysicsService:CollisionGroupSetCollidable(Colisiones.BASURA, Colisiones.BASURA, true)
	PhysicsService:CollisionGroupSetCollidable(Colisiones.BASURA, "Default", true)

	local function enganchar(jugador: Player)
		if jugador.Character then
			marcarPersonaje(jugador.Character)
		end
		jugador.CharacterAdded:Connect(marcarPersonaje)
	end
	Players.PlayerAdded:Connect(enganchar)
	for _, jugador in Players:GetPlayers() do
		enganchar(jugador)
	end
end

return Colisiones
