--!strict
--[[
	Perfiles (ModuleScript)
	Unica responsabilidad: el perfil de cada jugador EN MEMORIA y su
	publicacion al cliente. No sabe nada de DataStore: eso es DataService, que
	llama a registrar() al entrar y lee snapshot() al guardar.

	=== Dos banderas distintas (leccion de Fly_Roblox) ===

	  cargado    la lectura del DataStore tuvo exito. Solo entonces se puede
	             GUARDAR: escribir un perfil por defecto encima del real seria
	             destruir el progreso. Un perfil no cargado se juega igual, pero
	             DataService se niega a persistirlo.
	  sucio      hubo cambios desde la ultima publicacion al cliente. Se vacia en
	             el siguiente Heartbeat (maximo 4 envios/s por jugador).

	Se envia el perfil ENTERO cada vez (PerfilEvent). Con ~120 copias de mascota
	son unos pocos KB; a cambio el cliente nunca puede quedarse desincronizado
	por un parche perdido.

	Lo que NO esta en el perfil porque no persiste: la bolsa, la energia actual,
	la parcela asignada, los minijuegos en curso.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

export type Copia = {
	id: string,
	estado: number, -- 1 Danada .. 5 Perfecta
	sucia: boolean,
}

export type Perfil = {
	version: number,
	dinero: number,
	gemas: number,
	mejoras: { [string]: number },
	mascotas: { [string]: Copia },
	fragmentos: { [string]: number },
	exhibidas: { [string]: string }, -- indice pedestal (como string) -> uid
	figurinas: { [string]: boolean },
	cintas: { [string]: boolean },
	trajes: { [string]: boolean },
	skins: { [string]: boolean },
	trajePuesto: string?,
	cintaPuesta: string?,
	skinBase: string?,
	logros: { [string]: boolean },
	estadisticas: { [string]: number },
	pity: number,
	recibos: { string },
	pasesCache: { [string]: boolean },
	meGusta: number,
	tiempoJugado: number,
	ultimaSesion: number,
	siguienteUid: number,
}

local Perfiles = {}

-- Datos de sesion que viajan con el snapshot pero NO se guardan (p. ej. si el
-- modo dev de pases esta activo). Lo fija Monetizacion para evitar un require
-- circular.
Perfiles.extrasSnapshot = nil :: ((Player) -> any)?

Perfiles.alCargar = Senal.nueva() :: Senal.Senal<Player, Perfil>
Perfiles.alCambiar = Senal.nueva() :: Senal.Senal<Player, Perfil>

local perfiles: { [Player]: Perfil } = {}
local cargados: { [Player]: boolean } = {}
local sucios: { [Player]: boolean } = {}
local ultimoEnvio: { [Player]: number } = {}

local PerfilEvent = Red.evento("PerfilEvent")

function Perfiles.porDefecto(): Perfil
	local mejoras = {}
	for _, id in { "Mochila", "Energia", "Chispa", "Almacen", "Velocidad", "Alcance", "Iman" } do
		mejoras[id] = 0
	end
	return {
		version = GameConfig.VERSION_PERFIL,
		dinero = 0,
		gemas = 0,
		mejoras = mejoras,
		mascotas = {},
		fragmentos = {},
		exhibidas = {},
		figurinas = {},
		cintas = {},
		trajes = {},
		skins = {},
		trajePuesto = nil,
		cintaPuesta = nil,
		skinBase = nil,
		logros = {},
		estadisticas = {},
		pity = 0,
		recibos = {},
		pasesCache = {},
		meGusta = 0,
		tiempoJugado = 0,
		ultimaSesion = 0,
		siguienteUid = 1,
	}
end

-- Rellena lo que falte con el perfil por defecto (campos nuevos de versiones
-- posteriores) sin tocar lo que ya hay. Nunca borra datos.
function Perfiles.migrar(datos: any): Perfil
	local base = Perfiles.porDefecto()
	if typeof(datos) ~= "table" then
		return base
	end
	for clave, valorDefecto in pairs(base :: any) do
		local v = datos[clave]
		if v == nil then
			(datos :: any)[clave] = valorDefecto
		elseif typeof(valorDefecto) == "table" and typeof(v) == "table" and clave == "mejoras" then
			for id, nivel in pairs(valorDefecto) do
				if v[id] == nil then
					v[id] = nivel
				end
			end
		end
	end
	datos.version = GameConfig.VERSION_PERFIL
	return datos :: Perfil
end

function Perfiles.registrar(jugador: Player, perfil: Perfil, cargado: boolean)
	perfiles[jugador] = perfil
	cargados[jugador] = cargado
	perfil.ultimaSesion = os.time()
	sucios[jugador] = true
	Perfiles.alCargar:Fire(jugador, perfil)
end

function Perfiles.obtener(jugador: Player): Perfil?
	return perfiles[jugador]
end

function Perfiles.esperar(jugador: Player, tiempoMax: number?): Perfil?
	local limite = os.clock() + (tiempoMax or 15)
	while not perfiles[jugador] and os.clock() < limite and jugador.Parent do
		task.wait(0.1)
	end
	return perfiles[jugador]
end

function Perfiles.estaCargado(jugador: Player): boolean
	return cargados[jugador] == true
end

function Perfiles.quitar(jugador: Player)
	perfiles[jugador] = nil
	cargados[jugador] = nil
	sucios[jugador] = nil
	ultimoEnvio[jugador] = nil
end

function Perfiles.todos(): { [Player]: Perfil }
	return perfiles
end

-- Copia plana para enviar o guardar. El perfil ya es data pura (sin Instances
-- ni funciones), asi que basta con devolverlo; existe como punto unico por si
-- algun dia hay que filtrar campos.
function Perfiles.snapshot(perfil: Perfil): Perfil
	return perfil
end

function Perfiles.marcarSucio(jugador: Player)
	if perfiles[jugador] then
		sucios[jugador] = true
	end
end

function Perfiles.nuevoUid(perfil: Perfil): string
	local uid = tostring(perfil.siguienteUid)
	perfil.siguienteUid += 1
	return uid
end

-- Suma delta a una estadistica y devuelve el valor nuevo.
function Perfiles.estadistica(jugador: Player, clave: string, delta: number): number
	local perfil = perfiles[jugador]
	if not perfil then
		return 0
	end
	local nuevo = (perfil.estadisticas[clave] or 0) + delta
	perfil.estadisticas[clave] = nuevo
	sucios[jugador] = true
	return nuevo
end

-- Fija una estadistica al maximo entre lo que habia y el valor dado.
function Perfiles.estadisticaMaxima(jugador: Player, clave: string, valor: number): number
	local perfil = perfiles[jugador]
	if not perfil then
		return 0
	end
	local actual = perfil.estadisticas[clave] or 0
	if valor > actual then
		perfil.estadisticas[clave] = valor
		sucios[jugador] = true
		return valor
	end
	return actual
end

function Perfiles.leerEstadistica(jugador: Player, clave: string): number
	local perfil = perfiles[jugador]
	return if perfil then (perfil.estadisticas[clave] or 0) else 0
end

local function publicar(jugador: Player)
	local perfil = perfiles[jugador]
	if not perfil then
		return
	end
	sucios[jugador] = nil
	ultimoEnvio[jugador] = os.clock()
	local extras = if Perfiles.extrasSnapshot then Perfiles.extrasSnapshot(jugador) else nil
	PerfilEvent:FireClient(jugador, Perfiles.snapshot(perfil), cargados[jugador] == true, extras)
	Perfiles.alCambiar:Fire(jugador, perfil)
end

function Perfiles.publicarAhora(jugador: Player)
	publicar(jugador)
end

RunService.Heartbeat:Connect(function()
	local ahora = os.clock()
	for jugador in sucios do
		if not jugador.Parent then
			sucios[jugador] = nil
		elseif ahora - (ultimoEnvio[jugador] or 0) >= 0.25 then
			publicar(jugador)
		end
	end
end)

-- Tiempo jugado: un tick por minuto
task.spawn(function()
	while true do
		task.wait(60)
		for jugador, perfil in perfiles do
			perfil.tiempoJugado += 60
		end
	end
end)

-- La limpieza al salir la hace DataService (quitar) DESPUES de guardar, para
-- que el guardado siempre vea el perfil.

return Perfiles
