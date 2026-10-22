--!strict
--[[
	DataService
	Cableado de la persistencia: conecta entrar, salir, el autoguardado y el
	cierre del servidor con Services/Guardado, que es quien habla con el
	DataStore (reglas, cola de guardado y bloqueo de sesion en su cabecera).
	Aqui no hay logica: si algo de guardar cambia, cambia en Guardado.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local Guardado = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Guardado"))

Players.PlayerAdded:Connect(Guardado.cargar)
for _, jugador in Players:GetPlayers() do
	task.spawn(Guardado.cargar, jugador)
end

-- Dispara Perfiles.alSalir, guarda soltando la sesion y quita el perfil
Players.PlayerRemoving:Connect(Guardado.salir)

-- Cada autoguardado renueva tambien el latido de la sesion
task.spawn(function()
	while true do
		task.wait(GameConfig.INTERVALO_AUTOGUARDADO)
		Guardado.autoguardar()
	end
end)

game:BindToClose(function()
	Guardado.cerrar()
end)
