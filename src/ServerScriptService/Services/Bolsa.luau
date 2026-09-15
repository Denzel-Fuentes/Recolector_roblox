--!strict
--[[
	Bolsa (ModuleScript)
	Unica responsabilidad: lo que cada jugador lleva encima entre el patio y la
	caseta. Estado de SESION: no persiste.

	=== El dinero SOLO sale del contenedor (decision del usuario) ===
	Recoger nunca paga. Todo lo que se levanta del patio (basura, billetes,
	tesoros, mascotas...) ocupa un hueco de la bolsa y solo se convierte en $
	al depositarlo: con el prompt del Contenedor o lanzando la bolsa (Botin).
	Las dos vias pasan por depositarItems. Por eso no existe ningun "reciclaje
	al recoger" (el pase Auto-Reciclaje del GDD se retiro: rompia el viaje de
	vuelta, que es el bucle del juego).

	Capacidad = mejora "Bolsa" (id Mochila en el perfil). Cada objeto ocupa un
	hueco, sea basura o mascota.

	Depositar (prompt del Contenedor):
	  basura, billetes, tesoros -> $ (basura x pasivas de mascotas exhibidas)
	  bonus +25%        si la bolsa estaba LLENA al depositar (KOTAMON: bonus por
	                    bolsa llena). Recompensa el viaje completo.
	  fragmentos        -> perfil (siempre caben)
	  mascotas          -> almacen si hay sitio; si no, SE QUEDAN EN LA BOLSA y se
	                    avisa: es la presion de la mejora Almacen
	  figurinas/cintas/trajes -> perfil

	Al desconectar: lo que vale dinero se PIERDE (nadie lo deposito; si se
	pagara, salir y volver seria un atajo al contenedor) y lo demas va al
	almacen si cabe. Perder una mascota rara por una caida de conexion seria
	cruel; perder una bolsa de latas, no.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))
local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))

local BolsaEvent = Red.evento("BolsaEvent")

export type Item = {
	tipo: string, -- basura | billete | tesoro | fragmento | mascota | figurina | cinta | traje | bolsa (solo en el mundo)
	contenido: { any }?, -- bolsa caida: lo que llevaba
	estabaLlena: boolean?,
	dueno: string?,
	nombre: string,
	material: string?,
	valor: number?,
	id: string?,
	estado: number?,
	sucia: boolean?,
}

export type ResumenDeposito = {
	objetos: number,
	dinero: number,
	bonus: boolean,
	quedaron: number,
	mascotasNuevas: { string },
	fragmentosCompletos: { string },
}

local Bolsa = {}

Bolsa.alCambiar = Senal.nueva() :: Senal.Senal<Player>

local bolsas: { [Player]: { Item } } = {}

local function itemsDe(jugador: Player): { Item }
	local b = bolsas[jugador]
	if not b then
		b = {}
		bolsas[jugador] = b
	end
	return b
end

function Bolsa.capacidad(jugador: Player): number
	return Mejoras.valor(jugador, "Mochila")
end

function Bolsa.contenido(jugador: Player): { Item }
	return itemsDe(jugador)
end

function Bolsa.cuenta(jugador: Player): number
	return #itemsDe(jugador)
end

function Bolsa.estaLlena(jugador: Player): boolean
	return Bolsa.cuenta(jugador) >= Bolsa.capacidad(jugador)
end

function Bolsa.publicar(jugador: Player)
	if jugador.Parent then
		BolsaEvent:FireClient(jugador, itemsDe(jugador), Bolsa.capacidad(jugador))
	end
	Bolsa.alCambiar:Fire(jugador)
end

-- Valor en $ de un objeto de basura para este jugador (con pasivas exhibidas)
function Bolsa.valorBasura(jugador: Player, item: Item): number
	local base = item.valor or GameConfig.VALOR_BASURA[item.material or ""] or 0
	local bonus = Mascotas.bonusMaterial(jugador, item.material or "")
	return math.floor(base * (1 + bonus) + 0.5)
end

-- Lo que paga Dona Chatarra por un item al depositarlo (0 si no es dinero:
-- mascotas, fragmentos y coleccionables van al perfil)
function Bolsa.valorDeposito(jugador: Player, item: Item): number
	if item.tipo == "basura" then
		return Bolsa.valorBasura(jugador, item)
	elseif item.tipo == "billete" then
		return item.valor or GameConfig.VALOR_BILLETE.min
	elseif item.tipo == "tesoro" then
		return item.valor or GameConfig.VALOR_TESORO.min
	end
	return 0
end

function Bolsa.meter(jugador: Player, item: Item): boolean
	if Bolsa.estaLlena(jugador) then
		return false
	end
	table.insert(itemsDe(jugador), item)
	Bolsa.publicar(jugador)
	return true
end

-- Vacia la bolsa y devuelve (items, estabaLlena). Lo usa el lanzamiento: la
-- bolsa sale volando con todo lo que llevaba.
function Bolsa.vaciar(jugador: Player): ({ Item }, boolean)
	local items = itemsDe(jugador)
	local estabaLlena = Bolsa.estaLlena(jugador)
	bolsas[jugador] = {}
	Bolsa.publicar(jugador)
	return items, estabaLlena
end

-- Mete varios items de golpe (una bolsa caida que se recoge). Solo si caben
-- TODOS: si no, no se toca nada y devuelve false.
function Bolsa.meterVarios(jugador: Player, items: { Item }): boolean
	local propios = itemsDe(jugador)
	if #propios + #items > Bolsa.capacidad(jugador) then
		return false
	end
	for _, item in items do
		table.insert(propios, item)
	end
	Bolsa.publicar(jugador)
	return true
end

-- Pasa al perfil todo lo que no es dinero. Devuelve los items que NO cupieron.
local function guardarEnPerfil(jugador: Player, items: { Item }, resumen: ResumenDeposito): { Item }
	local quedaron = {}
	for _, item in items do
		if item.tipo == "fragmento" and item.id then
			local n = Mascotas.agregarFragmento(jugador, item.id)
			if n >= GameConfig.FRAGMENTOS_POR_MASCOTA then
				table.insert(resumen.fragmentosCompletos, item.id)
			end
		elseif item.tipo == "mascota" and item.id then
			local eraNueva = not Mascotas.tiene(jugador, item.id)
			local uid = Mascotas.agregar(jugador, item.id, item.estado or 2, item.sucia == true)
			if uid then
				if eraNueva then
					table.insert(resumen.mascotasNuevas, item.id)
				end
			else
				table.insert(quedaron, item)
			end
		elseif (item.tipo == "figurina" or item.tipo == "cinta" or item.tipo == "traje") and item.id then
			if not Coleccionables.agregar(jugador, item.tipo, item.id) then
				-- Duplicado (no deberia pasar): Dona Chatarra lo compra como tesoro
				resumen.dinero += GameConfig.VALOR_TESORO.min
			end
		end
	end
	return quedaron
end

-- Recicla una lista de items para un jugador (los de su bolsa, o los de una
-- bolsa lanzada). multiplicador extra: +50% si entro lanzada (punteria).
-- Devuelve el resumen; los items que no quepan en el almacen vuelven a la
-- bolsa del jugador.
function Bolsa.depositarItems(jugador: Player, items: { Item }, estabaLlena: boolean, multiplicadorExtra: number?): ResumenDeposito
	local resumen: ResumenDeposito = { objetos = 0, dinero = 0, bonus = false, quedaron = 0, mascotasNuevas = {}, fragmentosCompletos = {} }
	local paraPerfil = {}
	for _, item in items do
		local valor = Bolsa.valorDeposito(jugador, item)
		if valor > 0 then
			resumen.dinero += valor
			resumen.objetos += 1
			Perfiles.estadistica(jugador, "objetosReciclados", 1)
			if item.tipo == "tesoro" then
				Perfiles.estadistica(jugador, "tesorosVendidos", 1)
			end
		else
			table.insert(paraPerfil, item)
		end
	end
	if estabaLlena and resumen.dinero > 0 then
		resumen.dinero = math.floor(resumen.dinero * (1 + GameConfig.BONUS_BOLSA_LLENA) + 0.5)
		resumen.bonus = true
	end
	if multiplicadorExtra and multiplicadorExtra > 1 then
		resumen.dinero = math.floor(resumen.dinero * multiplicadorExtra + 0.5)
	end
	local quedaron = guardarEnPerfil(jugador, paraPerfil, resumen)
	resumen.quedaron = #quedaron
	local propios = itemsDe(jugador)
	for _, item in quedaron do
		table.insert(propios, item)
	end
	if resumen.dinero > 0 then
		Economia.ganar(jugador, resumen.dinero)
	end
	Perfiles.estadistica(jugador, "depositos", 1)
	Bolsa.publicar(jugador)
	return resumen
end

-- Deposito por el prompt del Contenedor: vaciar y reciclar lo propio.
function Bolsa.depositar(jugador: Player): ResumenDeposito?
	if Bolsa.cuenta(jugador) == 0 then
		return nil
	end
	local items, estabaLlena = Bolsa.vaciar(jugador)
	return Bolsa.depositarItems(jugador, items, estabaLlena)
end

-- Al desconectar: guardar lo que quepa en el perfil; lo que valia dinero se
-- pierde (ver cabecera).
local function vaciarAlSalir(jugador: Player)
	local items = bolsas[jugador]
	bolsas[jugador] = nil
	if not items or #items == 0 then
		return
	end
	local resumen: ResumenDeposito = { objetos = 0, dinero = 0, bonus = false, quedaron = 0, mascotasNuevas = {}, fragmentosCompletos = {} }
	local paraPerfil = {}
	for _, item in items do
		if Bolsa.valorDeposito(jugador, item) == 0 then
			table.insert(paraPerfil, item)
		end
	end
	guardarEnPerfil(jugador, paraPerfil, resumen)
end

Players.PlayerRemoving:Connect(vaciarAlSalir)

Perfiles.alCargar:Connect(function(jugador)
	Bolsa.publicar(jugador)
end)

return Bolsa
