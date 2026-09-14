--!strict
--[[
	Bolsa (ModuleScript)
	Unica responsabilidad: lo que cada jugador lleva encima entre el patio y la
	caseta. Estado de SESION: no persiste.

	Capacidad = mejora Mochila. Cada objeto ocupa un hueco, sea basura o mascota.
	Los billetes NO pasan por aqui: son dinero directo al recogerlos.

	Depositar (prompt del Contenedor):
	  basura y tesoros  -> $ (basura x pasivas de mascotas exhibidas)
	  bonus +25%        si la bolsa estaba LLENA al depositar (KOTAMON: bonus por
	                    bolsa llena). Recompensa el viaje completo.
	  fragmentos        -> perfil (siempre caben)
	  mascotas          -> almacen si hay sitio; si no, SE QUEDAN EN LA BOLSA y se
	                    avisa: es la presion de la mejora Almacen
	  figurinas/cintas/trajes -> perfil

	Pase Auto-Reciclaje: la basura se convierte en $ al recogerla (sin bonus de
	bolsa llena) y no ocupa hueco. Conveniencia, no exclusividad.

	Al desconectar: la basura se recicla sin bonus y lo demas va al almacen si
	cabe. Perder una mascota rara por una caida de conexion seria cruel.
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
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))

local BolsaEvent = Red.evento("BolsaEvent")

export type Item = {
	tipo: string, -- basura | tesoro | fragmento | mascota | figurina | cinta | traje
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

local function reciclarDirecto(jugador: Player, item: Item): number
	local valor = Bolsa.valorBasura(jugador, item)
	Economia.ganar(jugador, valor)
	Perfiles.estadistica(jugador, "objetosReciclados", 1)
	return valor
end

function Bolsa.meter(jugador: Player, item: Item): boolean
	if item.tipo == "basura" and Monetizacion.tienePase(jugador, "AutoReciclaje") then
		reciclarDirecto(jugador, item)
		Perfiles.estadistica(jugador, "autoReciclados", 1)
		return true
	end
	if Bolsa.estaLlena(jugador) then
		return false
	end
	table.insert(itemsDe(jugador), item)
	Bolsa.publicar(jugador)
	return true
end

-- Saca el primer objeto lanzable (basura o tesoro) o nil
function Bolsa.sacarLanzable(jugador: Player): Item?
	local items = itemsDe(jugador)
	for i, item in items do
		if item.tipo == "basura" or item.tipo == "tesoro" then
			table.remove(items, i)
			Bolsa.publicar(jugador)
			return item
		end
	end
	return nil
end

function Bolsa.tieneLanzable(jugador: Player): boolean
	for _, item in itemsDe(jugador) do
		if item.tipo == "basura" or item.tipo == "tesoro" then
			return true
		end
	end
	return false
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

function Bolsa.depositar(jugador: Player): ResumenDeposito?
	local items = itemsDe(jugador)
	if #items == 0 then
		return nil
	end
	local estabaLlena = Bolsa.estaLlena(jugador)
	local resumen: ResumenDeposito = { objetos = 0, dinero = 0, bonus = false, quedaron = 0, mascotasNuevas = {}, fragmentosCompletos = {} }
	local paraPerfil = {}
	for _, item in items do
		if item.tipo == "basura" then
			resumen.dinero += Bolsa.valorBasura(jugador, item)
			resumen.objetos += 1
			Perfiles.estadistica(jugador, "objetosReciclados", 1)
		elseif item.tipo == "tesoro" then
			resumen.dinero += item.valor or GameConfig.VALOR_TESORO.min
			resumen.objetos += 1
			Perfiles.estadistica(jugador, "tesorosVendidos", 1)
		else
			table.insert(paraPerfil, item)
		end
	end
	if estabaLlena and resumen.dinero > 0 then
		resumen.dinero = math.floor(resumen.dinero * (1 + GameConfig.BONUS_BOLSA_LLENA) + 0.5)
		resumen.bonus = true
	end
	local quedaron = guardarEnPerfil(jugador, paraPerfil, resumen)
	resumen.quedaron = #quedaron
	bolsas[jugador] = quedaron
	if resumen.dinero > 0 then
		Economia.ganar(jugador, resumen.dinero)
	end
	Perfiles.estadistica(jugador, "depositos", 1)
	Bolsa.publicar(jugador)
	return resumen
end

-- Al desconectar: reciclar sin bonus y guardar lo que quepa.
local function vaciarAlSalir(jugador: Player)
	local items = bolsas[jugador]
	if not items or #items == 0 then
		bolsas[jugador] = nil
		return
	end
	local resumen: ResumenDeposito = { objetos = 0, dinero = 0, bonus = false, quedaron = 0, mascotasNuevas = {}, fragmentosCompletos = {} }
	local paraPerfil = {}
	for _, item in items do
		if item.tipo == "basura" then
			resumen.dinero += Bolsa.valorBasura(jugador, item)
		elseif item.tipo == "tesoro" then
			resumen.dinero += item.valor or 0
		else
			table.insert(paraPerfil, item)
		end
	end
	guardarEnPerfil(jugador, paraPerfil, resumen)
	if resumen.dinero > 0 then
		Economia.ganar(jugador, resumen.dinero)
	end
	bolsas[jugador] = nil
end

Players.PlayerRemoving:Connect(vaciarAlSalir)

Perfiles.alCargar:Connect(function(jugador)
	Bolsa.publicar(jugador)
end)

return Bolsa
