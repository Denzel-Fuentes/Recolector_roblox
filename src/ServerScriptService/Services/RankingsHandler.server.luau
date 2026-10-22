--!strict
--[[
	RankingsHandler
	Cableado de los rankings (Services/Rankings): cada INTERVALO_ESCRITURA
	publica los valores de cada jugador (y al salir, en Perfiles.alSalir),
	cada INTERVALO_LECTURA lee los primeros puestos y los manda a todos
	(RankingsEvent). Un cliente que acaba de entrar pide la ultima lectura con
	RankingsEvent:FireServer(). Al cerrar el servidor se esperan las
	escrituras en curso (antes se perdian); las de los jugadores que quedan
	las lanza su alSalir, que el cierre de Guardado dispara.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DefinicionesRankings = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesRankings"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Perfiles = require(script.Parent:WaitForChild("Perfiles"))
local Rankings = require(script.Parent:WaitForChild("Rankings"))

local RankingsEvent = Red.evento("RankingsEvent")

local PEDIR_COOLDOWN = 5
local ultimoPedido: { [Player]: number } = {}

RankingsEvent.OnServerEvent:Connect(function(jugador)
	local ahora = os.clock()
	if ahora - (ultimoPedido[jugador] or -math.huge) < PEDIR_COOLDOWN then
		return
	end
	ultimoPedido[jugador] = ahora
	local datos = Rankings.ultimos()
	if datos then
		RankingsEvent:FireClient(jugador, datos)
	end
end)

Players.PlayerRemoving:Connect(function(jugador)
	ultimoPedido[jugador] = nil
end)

-- Antes del guardado de salida: Rankings.publicar calcula los valores sin
-- ceder (el perfil todavia esta: Guardado lo quita despues de guardar) y
-- solo entonces escribe
Perfiles.alSalir:Connect(function(jugador)
	Rankings.publicar(jugador)
	Rankings.olvidar(jugador)
end)

-- Al cerrar no se republica: el cierre de Guardado hace salir a cada jugador
-- y alSalir (arriba) publica. Se cede un momento para que esas escrituras
-- empiecen y se esperan.
game:BindToClose(function()
	task.wait()
	Rankings.esperarEscrituras(25)
end)

-- Escritura: cada jugador por su lado, repartidos en el intervalo para no
-- gastar el presupuesto de golpe
task.spawn(function()
	while true do
		task.wait(DefinicionesRankings.INTERVALO_ESCRITURA)
		local jugadores = Players:GetPlayers()
		local paso = DefinicionesRankings.INTERVALO_ESCRITURA / math.max(1, #jugadores) / 2
		for _, jugador in jugadores do
			if jugador.Parent then
				task.spawn(Rankings.publicar, jugador)
			end
			task.wait(paso)
		end
	end
end)

-- Lectura: la primera poco despues de arrancar (los perfiles ya cargados
-- escriben antes, para que el propio jugador salga si ya tenia valores)
task.spawn(function()
	task.wait(8)
	for _, jugador in Players:GetPlayers() do
		Rankings.publicar(jugador)
	end
	while true do
		local datos = Rankings.leer()
		RankingsEvent:FireAllClients(datos)
		task.wait(DefinicionesRankings.INTERVALO_LECTURA)
	end
end)
