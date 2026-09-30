--!strict
--[[
	DataService
	Unica responsabilidad: que el progreso sobreviva a la sesion. Es lo unico
	que habla con el DataStore. Perfiles lleva los datos en memoria; aqui solo se
	leen al entrar y se escriben al salir, cada INTERVALO_AUTOGUARDADO y al
	cerrar el servidor.

	=== Las dos reglas que evitan perder datos (de Fly_Roblox) ===

	1. TODA llamada al DataStore va dentro de pcall con reintentos, y los fallos
	   se reportan con warn, nunca con error. Un DataStore caido no puede impedir
	   jugar: es mejor perder una sesion de progreso que dejar al jugador fuera.

	2. UN PERFIL QUE NO SE PUDO LEER NUNCA SE GUARDA. Si GetAsync falla, el
	   jugador arranca con el perfil por defecto en memoria y se le avisa;
	   escribir eso encima de su progreso real seria destruirlo. Lo controla
	   Perfiles.estaCargado.

	Se guarda con UpdateAsync: si algun dia dos servidores escriben el mismo
	perfil, el ultimo gana, pero nunca se corrompe a medias. Sin bloqueo de
	sesion completo (ProfileStore) por decision: cero dependencias en esta fase.

	En Studio sin "Enable Studio Access to API Services" (place sin publicar)
	todo falla con warn y se juega sin guardar. Es lo esperado.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))

local NotificacionEvent = Red.evento("NotificacionEvent")

-- GetDataStore no falla aunque el acceso a la API este desactivado; el error
-- aparece al leer o escribir. Por eso tambien va con pcall.
local okStore, almacen = pcall(function()
	return DataStoreService:GetDataStore(GameConfig.NOMBRE_DATASTORE)
end)
if not okStore then
	warn("DataService: no se pudo abrir el DataStore. La sesion no se guardara. " .. tostring(almacen))
	almacen = nil
end
local store: DataStore? = if okStore then almacen :: DataStore else nil

-- Por UserId, nunca por nombre: el nombre puede cambiar.
local function claveDe(jugador: Player): string
	return "Perfil_" .. jugador.UserId
end

local function conReintentos(descripcion: string, fn: () -> any): (boolean, any)
	local ultimoError: any = nil
	for intento = 1, GameConfig.REINTENTOS_DATASTORE do
		local ok, resultado = pcall(fn)
		if ok then
			return true, resultado
		end
		ultimoError = resultado
		if intento < GameConfig.REINTENTOS_DATASTORE then
			task.wait(1 + intento)
		end
	end
	warn(string.format("DataService: %s fallo tras %d intentos: %s", descripcion, GameConfig.REINTENTOS_DATASTORE, tostring(ultimoError)))
	return false, ultimoError
end

local guardando: { [Player]: boolean } = {}

local function cargar(jugador: Player)
	local cargado = false
	local datos: any = nil
	if store then
		local ok, resultado = conReintentos("leer " .. claveDe(jugador), function()
			return store:GetAsync(claveDe(jugador))
		end)
		if ok then
			cargado = true
			datos = resultado
		end
	end
	if not jugador.Parent then
		return
	end
	Perfiles.registrar(jugador, Perfiles.completar(datos), cargado)
	if not cargado then
		-- El cliente puede no tener aun la UI: se reintenta un poco despues.
		task.delay(3, function()
			if jugador.Parent then
				NotificacionEvent:FireClient(jugador, Textos.NOTIFICACIONES.perfilNoCargado, "peligro")
			end
		end)
	end
end

local function guardar(jugador: Player, motivo: string): boolean
	if not store then
		return false
	end
	if not Perfiles.estaCargado(jugador) then
		return false
	end
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false
	end
	if guardando[jugador] then
		return false
	end
	guardando[jugador] = true
	local snapshot = Perfiles.snapshot(perfil)
	local ok = conReintentos("guardar " .. claveDe(jugador) .. " (" .. motivo .. ")", function()
		store:UpdateAsync(claveDe(jugador), function()
			return snapshot
		end)
	end)
	guardando[jugador] = nil
	return ok
end

Players.PlayerAdded:Connect(cargar)
for _, jugador in Players:GetPlayers() do
	task.spawn(cargar, jugador)
end

Players.PlayerRemoving:Connect(function(jugador)
	-- Otros modulos (Bolsa, Lanzamiento) tambien escuchan PlayerRemoving y tocan
	-- el perfil al salir. El orden entre conexiones no esta garantizado, asi que
	-- se cede un instante para guardar DESPUES de ellos.
	task.wait(0.2)
	guardar(jugador, "salida")
	Perfiles.quitar(jugador)
end)

task.spawn(function()
	while true do
		task.wait(GameConfig.INTERVALO_AUTOGUARDADO)
		for jugador in Perfiles.todos() do
			if jugador.Parent then
				task.spawn(guardar, jugador, "autoguardado")
			end
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() and not store then
		return
	end
	local pendientes = 0
	for jugador in Perfiles.todos() do
		pendientes += 1
		task.spawn(function()
			guardar(jugador, "cierre")
			pendientes -= 1
		end)
	end
	local limite = os.clock() + 25
	while pendientes > 0 and os.clock() < limite do
		task.wait(0.1)
	end
end)
