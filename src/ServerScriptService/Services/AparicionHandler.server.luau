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
	un personaje sin perfil. Si el DataStore falla, Guardado registra
	enseguida un perfil provisional (se juega sin guardar) y el personaje
	sale. Sin ningun perfil es que Guardado espera la sesion de otro servidor
	(hasta SESION_ESPERA_ROBO s): el respaldo va 15 s por encima, como
	Monetizacion.ESPERA_PERFIL. Con los 15 s de antes se jugaban ~45 s sin
	perfil y lo reciclado se perdia (Economia.ganar no tiene donde sumar;
	revision Q4b, 23 oct). Si aun asi no llega, se carga igual: un jugador
	sin personaje es peor que uno sin guardar.

	Llevarlo a la plaza es un salto del servidor: se avisa a Movimiento
	(permitirSalto, con el destino) para que no lo tome por un teletransporte
	del cliente (el personaje nace donde Roblox lo pone y una muestra podria
	caer entre eso y el PivotTo) y mida desde la plaza.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mundo = require(Servicios:WaitForChild("Mundo"))
local Movimiento = require(Servicios:WaitForChild("Movimiento"))

-- (ver cabecera; Client/Carga quita la pantalla de carga a los 90 s pase lo
-- que pase: tiene que ir por encima)
local RESPALDO_SIN_PERFIL = GameConfig.SESION_ESPERA_ROBO + 15

Players.CharacterAutoLoads = false

local function cargarSiFalta(jugador: Player)
	if jugador.Parent and not jugador.Character then
		jugador:LoadCharacter()
	end
end

local function alAparecer(jugador: Player, personaje: Model)
	local destino = Mundo.cframeAparicion()
	Movimiento.permitirSalto(jugador, destino.Position)
	personaje:PivotTo(destino)
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
