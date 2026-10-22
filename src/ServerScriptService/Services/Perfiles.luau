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

	Se envia el perfil ENTERO cada vez (PerfilEvent): son unos pocos KB y el
	cliente nunca puede quedarse desincronizado por un parche perdido.

	Lo que NO esta en el perfil porque no persiste: la bolsa y lo que vuela.

	=== Version 3 (diseno v2, 26 sep) ===
	El esquema entero de la v2 esta aqui desde el primer lote (rebirths,
	pedidos, cosmeticos), aunque cada sistema llegue en su lote: asi no hace
	falta migrar entre lotes. Las mascotas y sus fragmentos se quitaron el
	3 oct y los trajes el 5: completar borra sus campos (OBSOLETOS) de un
	perfil guardado antes, para que no viajen al cliente ni se vuelvan a
	guardar.
	No hay migracion desde la v2: el juego nunca se publico, no existen
	perfiles reales, y el DataStore cambia de nombre (GameConfig).
	`completar` solo rellena las claves que falten.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local DefinicionesMejoras = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMejoras"))
local DefinicionesRankings = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesRankings"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

-- Pedidos de Dona Chatarra del dia (Services/Pedidos)
export type Pedido = {
	id: string, -- plantilla (Config/DefinicionesPedidos)
	objetivo: number,
	progreso: number,
	parametro: any?, -- material, distancia...
	cobrado: boolean,
	recompensa: number?, -- $ al cumplirlo (con el multiplicador de rebirth del dia)
}

export type Perfil = {
	version: number,
	dinero: number,
	mejoras: { [string]: number },
	rebirths: number,
	pedidos: { dia: number, lista: { Pedido }, premioCobrado: boolean },
	racha: number, -- aciertos seguidos al contenedor
	-- Cosmeticos (los de pago se validan contra el pase)
	estela: string?, -- DefinicionesCosmeticos.ESTELAS
	disenoBolsa: string?, -- DefinicionesCosmeticos.BOLSAS
	camara: string?, -- "primera" | "tercera" en el patio (Client/Camara)
	turboHasta: number, -- os.time() hasta el que dura el Turbo de dinero
	-- Pospuesto (GameConfig.FUNCIONES): se guarda para no migrar al volver
	figurinas: { [string]: boolean },
	cintas: { [string]: boolean },
	logros: { [string]: boolean },
	estadisticas: { [string]: number },
	-- Para los rankings semanales (DefinicionesRankings): la semana, la foto de
	-- las estadisticas al empezarla (las sumas se restan) y los maximos de la
	-- semana (la racha no se puede restar)
	semana: { id: number, base: { [string]: number }, maximos: { [string]: number } },
	recibos: { string },
	pasesCache: { [string]: boolean },
	tiempoJugado: number,
	ultimaSesion: number,
	tutorial: number, -- pasos completados (DefinicionesTutorial)
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
	for _, def in DefinicionesMejoras.LISTA do
		mejoras[def.id] = 0
	end
	return {
		version = GameConfig.VERSION_PERFIL,
		dinero = 0,
		mejoras = mejoras,
		rebirths = 0,
		pedidos = { dia = 0, lista = {}, premioCobrado = false },
		racha = 0,
		estela = nil,
		disenoBolsa = nil,
		turboHasta = 0,
		figurinas = {},
		cintas = {},
		logros = {},
		estadisticas = {},
		semana = { id = 0, base = {}, maximos = {} },
		recibos = {},
		pasesCache = {},
		tiempoJugado = 0,
		ultimaSesion = 0,
		tutorial = 0,
	}
end

-- Campos de sistemas quitados (las mascotas, 3 oct; los trajes, 5 oct)
local OBSOLETOS = { "mascotas", "equipadas", "fragmentos", "pityMascotas", "fragmentosLibres", "trajes", "trajePuesto" }

-- Rellena lo que falte con el perfil por defecto (campos nuevos) sin tocar lo
-- que ya hay, y borra lo OBSOLETO. Las mejoras se completan por id por si se
-- anade una.
function Perfiles.completar(datos: any): Perfil
	local base = Perfiles.porDefecto()
	if typeof(datos) ~= "table" then
		return base
	end
	for _, clave in OBSOLETOS do
		datos[clave] = nil
	end
	for clave, valorDefecto in pairs(base :: any) do
		local v = datos[clave]
		if v == nil then
			(datos :: any)[clave] = valorDefecto
		elseif clave == "mejoras" and typeof(v) == "table" then
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

-- La semana de los rankings al dia: si empezo otra, la base de las sumas
-- son las estadisticas de ahora y los maximos vuelven a 0. Lo que se gane
-- entre el cambio de semana y la primera llamada cuenta para la anterior
-- (minutos como mucho: la llaman registrar, estadisticaMaxima y Rankings).
function Perfiles.semanaAlDia(perfil: Perfil): { id: number, base: { [string]: number }, maximos: { [string]: number } }
	local id = DefinicionesRankings.semana(os.time())
	if typeof(perfil.semana) ~= "table" or perfil.semana.id ~= id then
		perfil.semana = { id = id, base = table.clone(perfil.estadisticas), maximos = {} }
	end
	return perfil.semana
end

function Perfiles.registrar(jugador: Player, perfil: Perfil, cargado: boolean)
	perfiles[jugador] = perfil
	cargados[jugador] = cargado
	perfil.ultimaSesion = os.time()
	Perfiles.semanaAlDia(perfil)
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
	local semana = Perfiles.semanaAlDia(perfil)
	if valor > (semana.maximos[clave] or 0) then
		semana.maximos[clave] = valor
		sucios[jugador] = true
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
		for _, perfil in perfiles do
			perfil.tiempoJugado += 60
		end
	end
end)

-- La limpieza al salir la hace DataService (quitar) DESPUES de guardar, para
-- que el guardado siempre vea el perfil.

return Perfiles
