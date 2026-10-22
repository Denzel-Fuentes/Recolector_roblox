--!strict
--[[
	Rankings (ModuleScript)
	Unica responsabilidad: los rankings globales de los tablones de la plaza
	(Config/DefinicionesRankings) en OrderedDataStores: escribir el valor de
	cada jugador y leer los primeros puestos. RankingsHandler lo mueve con
	relojes y lo manda a los clientes, que pintan los tablones
	(Client/Tablones).

	=== Por que asi ===
	- Un OrderedDataStore por ranking y periodo: "<prefijo>_<id>_Historico" y
	  "<prefijo>_<id>_S<semana>". El semanal cambia de nombre cada lunes y
	  empieza vacio solo, sin borrar nada.
	- En Studio el prefijo lleva "_Studio": las pruebas tocan el perfil
	  (dinero, rebirths...) y eso no debe acabar en los tablones del juego
	  publicado.
	- Solo se escribe lo que cambio desde la ultima vez, y si queda
	  presupuesto de escritura. Un perfil que no cargo no se publica (seria el
	  perfil por defecto, con todo a 0).
	- Se leen los LEER primeros (una pagina): cada cliente busca ahi su puesto
	  aunque no salga en el top 10. Los nombres (DisplayName) se piden solo
	  para el top 10, en lote y con cache.
	- Todo DataStore va en pcall: sin acceso a la API (Studio sin publicar)
	  los tablones dicen "no disponible" y el juego sigue igual.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local DefinicionesRankings = require(Config:WaitForChild("DefinicionesRankings"))

local Perfiles = require(script.Parent:WaitForChild("Perfiles"))

type Ranking = DefinicionesRankings.Ranking

export type Fila = { u: number, v: number }
export type Datos = {
	semana: number,
	disponible: boolean, -- se pudo leer al menos un ranking
	listas: { [string]: { [string]: { Fila } } }, -- listas[id][periodo]
	nombres: { [string]: string }, -- por tostring(UserId), solo el top
}

local Rankings = {}

local PREFIJO = "Ranking_v" .. DefinicionesRankings.VERSION .. (if RunService:IsStudio() then "_Studio" else "")

function Rankings.nombreStore(def: Ranking, periodo: string, semana: number): string
	return PREFIJO .. "_" .. def.id .. (if periodo == "historico" then "_Historico" else "_S" .. semana)
end

local stores: { [string]: OrderedDataStore } = {}

local function abrir(nombre: string): OrderedDataStore?
	local s = stores[nombre]
	if s then
		return s
	end
	local ok, resultado = pcall(function()
		return DataStoreService:GetOrderedDataStore(nombre)
	end)
	if not ok then
		return nil
	end
	stores[nombre] = resultado
	return resultado
end

local function hayPresupuesto(tipo: Enum.DataStoreRequestType): boolean
	local ok, n = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(tipo)
	end)
	return ok and n > 0
end

-- ===========================================================================
-- Escribir
-- ===========================================================================

-- Lo ultimo que se escribio de cada jugador, por store: solo se reescribe lo
-- que cambio
local escritos: { [Player]: { [string]: number } } = {}

-- Publicaciones con escrituras en curso: el cierre del servidor las espera
-- (antes las de los que salian al cerrar se perdian)
local enVuelo = 0

function Rankings.escriturasEnVuelo(): number
	return enVuelo
end

-- Espera a que acaben las escrituras en curso, como mucho `limite` s
function Rankings.esperarEscrituras(limite: number): boolean
	local fin = os.clock() + limite
	while enVuelo > 0 and os.clock() < fin do
		task.wait(0.1)
	end
	return enVuelo == 0
end

-- Escribe los valores del jugador que cambiaron. Devuelve cuantos escribio.
-- Los valores se calculan antes de la primera espera, asi que vale llamarlo
-- desde Perfiles.alSalir aunque el perfil desaparezca despues.
function Rankings.publicar(jugador: Player): number
	if not Perfiles.estaCargado(jugador) then
		return 0
	end
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0
	end
	local semana = Perfiles.semanaAlDia(perfil)
	local ahora = os.time()
	local mios = escritos[jugador] or {}
	escritos[jugador] = mios
	local pendientes = {}
	for _, def in DefinicionesRankings.LISTA do
		for _, periodo in DefinicionesRankings.PERIODOS do
			local valor = DefinicionesRankings.valor(perfil, def, periodo, ahora)
			local nombre = Rankings.nombreStore(def, periodo, semana.id)
			if valor > 0 and mios[nombre] ~= valor then
				table.insert(pendientes, { nombre = nombre, valor = valor })
			end
		end
	end
	if #pendientes == 0 then
		return 0
	end
	local clave = tostring(jugador.UserId)
	local escritas = 0
	enVuelo += 1
	for _, p in pendientes do
		if not hayPresupuesto(Enum.DataStoreRequestType.SetIncrementSortedAsync) then
			break
		end
		local s = abrir(p.nombre)
		if s then
			local ok, err = pcall(function()
				s:SetAsync(clave, p.valor)
			end)
			if ok then
				mios[p.nombre] = p.valor
				escritas += 1
			else
				warn("Rankings: no se pudo escribir " .. p.nombre .. ": " .. tostring(err))
				break -- sin acceso a la API fallaran todas: no insistir
			end
		end
	end
	enVuelo -= 1
	return escritas
end

function Rankings.olvidar(jugador: Player)
	escritos[jugador] = nil
end

-- ===========================================================================
-- Leer
-- ===========================================================================

local cacheNombres: { [number]: string } = {}

-- DisplayName de cada UserId: los del servidor directamente, el resto en un
-- lote de UserService. Los ids <= 0 son jugadores de prueba de Studio.
local function nombresDe(ids: { [number]: boolean }): { [string]: string }
	local faltan = {}
	for u in ids do
		if not cacheNombres[u] then
			local enServidor = Players:GetPlayerByUserId(u)
			if enServidor then
				cacheNombres[u] = enServidor.DisplayName
			elseif u <= 0 then
				cacheNombres[u] = "Player" .. tostring(-u)
			else
				table.insert(faltan, u)
			end
		end
	end
	if #faltan > 0 then
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(faltan)
		end)
		if ok and typeof(infos) == "table" then
			for _, info in infos do
				cacheNombres[info.Id] = if info.DisplayName ~= "" then info.DisplayName else info.Username
			end
		end
	end
	local salida = {}
	for u in ids do
		salida[tostring(u)] = cacheNombres[u] or ("#" .. tostring(u))
	end
	return salida
end

local ultimos: Datos? = nil

-- Lee los primeros LEER de cada ranking y periodo. Lo que no se pudo leer
-- (sin presupuesto, fallo) conserva la lectura anterior de la misma semana.
function Rankings.leer(): Datos
	local semana = DefinicionesRankings.semana(os.time())
	local anteriores = if ultimos and ultimos.semana == semana then ultimos else nil
	local datos: Datos = { semana = semana, disponible = false, listas = {}, nombres = {} }
	local ids: { [number]: boolean } = {}
	for _, def in DefinicionesRankings.LISTA do
		local porPeriodo = {}
		for _, periodo in DefinicionesRankings.PERIODOS do
			local filas: { Fila }? = nil
			local s = abrir(Rankings.nombreStore(def, periodo, semana))
			if s and hayPresupuesto(Enum.DataStoreRequestType.GetSortedAsync) then
				local ok, pagina = pcall(function()
					return s:GetSortedAsync(false, DefinicionesRankings.LEER):GetCurrentPage()
				end)
				if ok and typeof(pagina) == "table" then
					filas = {}
					for _, entrada in pagina do
						local u = tonumber(entrada.key)
						if u then
							table.insert(filas :: { Fila }, { u = u, v = entrada.value })
						end
					end
					datos.disponible = true
				end
			end
			if not filas and anteriores then
				filas = anteriores.listas[def.id] and anteriores.listas[def.id][periodo]
				datos.disponible = datos.disponible or anteriores.disponible
			end
			porPeriodo[periodo] = filas or {}
			for i, fila in porPeriodo[periodo] do
				if i > DefinicionesRankings.TOP then
					break
				end
				ids[fila.u] = true
			end
		end
		datos.listas[def.id] = porPeriodo
	end
	datos.nombres = nombresDe(ids)
	ultimos = datos
	return datos
end

-- La ultima lectura (nil hasta la primera)
function Rankings.ultimos(): Datos?
	return ultimos
end

return Rankings
