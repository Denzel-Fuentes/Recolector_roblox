--!strict
--[[
	AparicionHandler
	Unica responsabilidad: cuando y donde aparece el personaje de cada jugador.

	Diseno v2: no hay base; todos aparecen en la plaza, junto al patio y
	mirandolo (Mundo.cframeAparicion), y vuelven ahi al morir.

	CharacterAutoLoads esta apagado (aqui y en default.project.json, para que
	no haya un primer personaje antes de que corra este script): el primer
	personaje se carga cuando el perfil ya esta registrado. Asi nada que
	dependa del perfil (velocidad, grupo de colision por rebirth) ve
	un personaje sin perfil. Si el perfil no llega nunca, a los
	15 s se carga igual: un jugador sin personaje es peor que uno sin guardar.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mundo = require(Servicios:WaitForChild("Mundo"))

local RESPALDO_SIN_PERFIL = 15

Players.CharacterAutoLoads = false

local function cargarSiFalta(jugador: Player)
	if jugador.Parent and not jugador.Character then
		jugador:LoadCharacter()
	end
end

local function alAparecer(jugador: Player, personaje: Model)
	personaje:PivotTo(Mundo.cframeAparicion())
	local humanoide = personaje:WaitForChild("Humanoid", 5) :: Humanoid?
	if humanoide then
		humanoide.Died:Connect(function()
			task.wait(Players.RespawnTime)
			if jugador.Parent then
				jugador:LoadCharacter()
			end
		end)
	end
end

local function conectar(jugador: Player)
	jugador.CharacterAdded:Connect(function(personaje)
		alAparecer(jugador, personaje)
	end)
	task.delay(RESPALDO_SIN_PERFIL, cargarSiFalta, jugador)
end

Perfiles.alCargar:Connect(cargarSiFalta)

Players.PlayerAdded:Connect(conectar)
for _, jugador in Players:GetPlayers() do
	conectar(jugador)
	-- DataService pudo registrar el perfil antes de que este script conectara
	if Perfiles.obtener(jugador) then
		task.spawn(cargarSiFalta, jugador)
	end
end
