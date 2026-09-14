--!strict
--[[
	Mascotas (ModuleScript)
	Unica responsabilidad: la coleccion de mascotas de cada jugador y sus reglas.

	  Copias        cada mascota encontrada es una COPIA con uid propio, estado de
	                conservacion (1 Danada .. 5 Perfecta) y bandera sucia.
	  Almacen       tope de copias = mejora Almacen. Si no cabe, agregar() falla y
	                la copia se queda donde estuviera (la bolsa).
	  Fragmentos    contador por mascota (0..5). Con 5, Reparacion ensambla.
	  Fusion        3 copias LIMPIAS de la misma mascota y mismo estado -> 1 copia
	                en estado+1. Perfecta no se fusiona. Igual que KOTAMON.
	  Venta         valor = base por rareza x multiplicador de estado; sucia x0.5.
	  Exhibicion    hasta 6 copias limpias en los pedestales de la parcela. Solo
	                las exhibidas dan su pasiva (bonus al reciclar su material).
	  Rey Reciclon  se otorga UNA vez al tener las 10 mascotas de los 4 sets.

	Las sucias no se pueden fusionar ni exhibir: primero se limpian en la mesa.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local DefinicionesMascotas = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMascotas"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))

local Mascotas = {}

-- (jugador, id, uid, esNueva) al entrar una copia al almacen
Mascotas.alAgregar = Senal.nueva() :: Senal.Senal<Player, string, string, boolean>
-- (jugador) cuando cambian los pedestales
Mascotas.alCambiarExhibidas = Senal.nueva() :: Senal.Senal<Player>
-- (jugador) al obtener al Rey
Mascotas.alCoronar = Senal.nueva() :: Senal.Senal<Player>

function Mascotas.capacidadAlmacen(jugador: Player): number
	return Mejoras.valor(jugador, "Almacen")
end

function Mascotas.cuenta(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0
	end
	local n = 0
	for _ in perfil.mascotas do
		n += 1
	end
	return n
end

function Mascotas.hayEspacio(jugador: Player): boolean
	return Mascotas.cuenta(jugador) < Mascotas.capacidadAlmacen(jugador)
end

function Mascotas.copias(jugador: Player, id: string): { string }
	local perfil = Perfiles.obtener(jugador)
	local lista = {}
	if perfil then
		for uid, copia in perfil.mascotas do
			if copia.id == id then
				table.insert(lista, uid)
			end
		end
	end
	return lista
end

function Mascotas.tiene(jugador: Player, id: string): boolean
	return #Mascotas.copias(jugador, id) > 0
end

function Mascotas.tieneSetCompleto(jugador: Player, setId: string): boolean
	for _, def in DefinicionesMascotas.porSet(setId) do
		if not Mascotas.tiene(jugador, def.id) then
			return false
		end
	end
	return true
end

function Mascotas.setsCompletos(jugador: Player): number
	local n = 0
	for _, set in DefinicionesMascotas.SETS do
		if Mascotas.tieneSetCompleto(jugador, set.id) then
			n += 1
		end
	end
	return n
end

-- Numero de mascotas DISTINTAS con al menos una copia Perfecta (sin el Rey)
function Mascotas.perfectasDistintas(jugador: Player): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0
	end
	local vistas = {}
	for _, copia in perfil.mascotas do
		if copia.estado >= DefinicionesMascotas.ESTADO_MAX and copia.id ~= DefinicionesMascotas.ID_REY then
			vistas[copia.id] = true
		end
	end
	local n = 0
	for _ in vistas do
		n += 1
	end
	return n
end

function Mascotas.mejorEstado(jugador: Player, id: string): number
	local perfil = Perfiles.obtener(jugador)
	local mejor = 0
	if perfil then
		for _, copia in perfil.mascotas do
			if copia.id == id and copia.estado > mejor then
				mejor = copia.estado
			end
		end
	end
	return mejor
end

-- Otorga el Rey si corresponde y no lo tiene. Ignora el tope de almacen: es la
-- recompensa del juego entero y no puede perderse por falta de sitio.
function Mascotas.comprobarRey(jugador: Player): boolean
	local perfil = Perfiles.obtener(jugador)
	if not perfil or Mascotas.tiene(jugador, DefinicionesMascotas.ID_REY) then
		return false
	end
	if Mascotas.setsCompletos(jugador) < #DefinicionesMascotas.SETS then
		return false
	end
	local uid = Perfiles.nuevoUid(perfil)
	perfil.mascotas[uid] = { id = DefinicionesMascotas.ID_REY, estado = 3, sucia = false }
	Perfiles.marcarSucio(jugador)
	Mascotas.alAgregar:Fire(jugador, DefinicionesMascotas.ID_REY, uid, true)
	Mascotas.alCoronar:Fire(jugador)
	return true
end

-- Devuelve el uid de la copia nueva, o nil si no cabe / no existe la mascota.
function Mascotas.agregar(jugador: Player, id: string, estado: number, sucia: boolean): string?
	local perfil = Perfiles.obtener(jugador)
	local def = DefinicionesMascotas.obtener(id)
	if not perfil or not def then
		return nil
	end
	if not Mascotas.hayEspacio(jugador) then
		return nil
	end
	local esNueva = not Mascotas.tiene(jugador, id)
	local uid = Perfiles.nuevoUid(perfil)
	perfil.mascotas[uid] = {
		id = id,
		estado = math.clamp(estado, 1, DefinicionesMascotas.ESTADO_MAX),
		sucia = sucia,
	}
	Perfiles.estadistica(jugador, "mascotasEncontradas", 1)
	Perfiles.marcarSucio(jugador)
	Mascotas.alAgregar:Fire(jugador, id, uid, esNueva)
	if esNueva then
		Mascotas.comprobarRey(jugador)
	end
	return uid
end

-- Fragmentos: devuelve el contador nuevo (0..5). No pasa de 5.
function Mascotas.agregarFragmento(jugador: Player, id: string): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil or not DefinicionesMascotas.obtener(id) then
		return 0
	end
	local n = math.min(GameConfig.FRAGMENTOS_POR_MASCOTA, (perfil.fragmentos[id] or 0) + 1)
	perfil.fragmentos[id] = n
	Perfiles.estadistica(jugador, "fragmentosEncontrados", 1)
	Perfiles.marcarSucio(jugador)
	return n
end

function Mascotas.fragmentos(jugador: Player, id: string): number
	local perfil = Perfiles.obtener(jugador)
	return if perfil then (perfil.fragmentos[id] or 0) else 0
end

-- Mascotas con 1..4 fragmentos: el Botin sesga hacia ellas
function Mascotas.fragmentosEnCurso(jugador: Player): { string }
	local perfil = Perfiles.obtener(jugador)
	local lista = {}
	if perfil then
		for id, n in perfil.fragmentos do
			if n > 0 and n < GameConfig.FRAGMENTOS_POR_MASCOTA then
				table.insert(lista, id)
			end
		end
	end
	return lista
end

function Mascotas.valorVenta(copia: Perfiles.Copia): number
	local def = DefinicionesMascotas.obtener(copia.id)
	if not def then
		return 0
	end
	local base = GameConfig.VALOR_BASE_RAREZA[def.rareza] or 0
	local mult = GameConfig.MULT_ESTADO[math.clamp(copia.estado, 1, 5)] or 1
	local valor = base * mult
	if copia.sucia then
		valor *= GameConfig.MULT_SUCIA
	end
	return math.floor(valor + 0.5)
end

function Mascotas.estaExhibida(jugador: Player, uid: string): boolean
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false
	end
	for _, u in perfil.exhibidas do
		if u == uid then
			return true
		end
	end
	return false
end

local function quitarDeExhibidas(perfil: Perfiles.Perfil, uid: string)
	for indice, u in perfil.exhibidas do
		if u == uid then
			perfil.exhibidas[indice] = nil
		end
	end
end

function Mascotas.vender(jugador: Player, uid: string): (boolean, number)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false, 0
	end
	local copia = perfil.mascotas[uid]
	if not copia or copia.id == DefinicionesMascotas.ID_REY then
		return false, 0
	end
	local valor = Mascotas.valorVenta(copia)
	perfil.mascotas[uid] = nil
	quitarDeExhibidas(perfil, uid)
	Economia.ganar(jugador, valor)
	Perfiles.estadistica(jugador, "mascotasVendidas", 1)
	Perfiles.marcarSucio(jugador)
	Mascotas.alCambiarExhibidas:Fire(jugador)
	return true, valor
end

-- Vende todas las copias sobrantes: de cada mascota conserva la mejor copia
-- limpia (o la mejor a secas) y las exhibidas. Devuelve (cantidad, dinero).
function Mascotas.venderDuplicados(jugador: Player): (number, number)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0, 0
	end
	local mejorPorId: { [string]: string } = {}
	for uid, copia in perfil.mascotas do
		local actual = mejorPorId[copia.id]
		if not actual then
			mejorPorId[copia.id] = uid
		else
			local c = perfil.mascotas[actual]
			if copia.estado > c.estado or (copia.estado == c.estado and c.sucia and not copia.sucia) then
				mejorPorId[copia.id] = uid
			end
		end
	end
	local cantidad, dinero = 0, 0
	for uid, copia in perfil.mascotas do
		if mejorPorId[copia.id] ~= uid and not Mascotas.estaExhibida(jugador, uid) and copia.id ~= DefinicionesMascotas.ID_REY then
			local ok, valor = Mascotas.vender(jugador, uid)
			if ok then
				cantidad += 1
				dinero += valor
			end
		end
	end
	return cantidad, dinero
end

-- 3 copias limpias del mismo id y estado -> 1 copia en estado+1
function Mascotas.fusionar(jugador: Player, id: string, estado: number): (boolean, string)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false, "sinPerfil"
	end
	if estado >= DefinicionesMascotas.ESTADO_MAX then
		return false, "yaPerfecta"
	end
	local candidatas = {}
	for uid, copia in perfil.mascotas do
		if copia.id == id and copia.estado == estado and not copia.sucia and not Mascotas.estaExhibida(jugador, uid) then
			table.insert(candidatas, uid)
		end
	end
	if #candidatas < 3 then
		return false, "faltanCopias"
	end
	for i = 1, 3 do
		perfil.mascotas[candidatas[i]] = nil
	end
	local uid = Perfiles.nuevoUid(perfil)
	perfil.mascotas[uid] = { id = id, estado = estado + 1, sucia = false }
	Perfiles.estadistica(jugador, "fusiones", 1)
	Perfiles.marcarSucio(jugador)
	Mascotas.alAgregar:Fire(jugador, id, uid, false)
	return true, uid
end

function Mascotas.limpiar(jugador: Player, uid: string): boolean
	local perfil = Perfiles.obtener(jugador)
	local copia = perfil and perfil.mascotas[uid]
	if not perfil or not copia or not copia.sucia then
		return false
	end
	copia.sucia = false
	Perfiles.estadistica(jugador, "limpiezas", 1)
	Perfiles.marcarSucio(jugador)
	return true
end

-- uid nil = vaciar el pedestal
function Mascotas.exhibir(jugador: Player, uid: string?, indice: number): (boolean, string)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false, "sinPerfil"
	end
	if indice < 1 or indice > GameConfig.PEDESTALES or indice ~= math.floor(indice) then
		return false, "pedestalInvalido"
	end
	local clave = tostring(indice)
	if uid == nil then
		perfil.exhibidas[clave] = nil
	else
		local copia = perfil.mascotas[uid]
		if not copia then
			return false, "noExiste"
		end
		if copia.sucia then
			return false, "sucia"
		end
		quitarDeExhibidas(perfil, uid)
		perfil.exhibidas[clave] = uid
	end
	Perfiles.marcarSucio(jugador)
	Mascotas.alCambiarExhibidas:Fire(jugador)
	return true, clave
end

-- Suma de pasivas de las exhibidas para un material ("Metal", ...)
function Mascotas.bonusMaterial(jugador: Player, material: string): number
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0
	end
	local bonus = 0
	for _, uid in perfil.exhibidas do
		local copia = perfil.mascotas[uid]
		local def = copia and DefinicionesMascotas.obtener(copia.id)
		if def then
			if def.pasiva.tipo == "bonusTodo" then
				bonus += def.pasiva.valor
			elseif def.pasiva.tipo == "bonusMaterial" and def.pasiva.material == material then
				bonus += def.pasiva.valor
			end
		end
	end
	return bonus
end

return Mascotas
