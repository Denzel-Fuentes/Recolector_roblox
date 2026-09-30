--!strict
--[[
	Bolsa (ModuleScript)
	Unica responsabilidad: lo que cada jugador lleva encima entre el patio y el
	contenedor, y lo que paga al depositarlo. Estado de SESION: no persiste.

	=== El dinero SOLO sale del contenedor (decision del usuario) ===
	Recoger nunca paga. Todo lo que se levanta del patio (basura, billetes,
	tesoros, fragmentos) ocupa un hueco de la bolsa y solo se convierte en $ al
	depositarlo: con el prompt del Contenedor ("entregar a mano", sin bonus)
	o lanzando la bolsa (Lanzamiento, con el bonus del tiro). Las dos vias
	pasan por depositarItems, que es la unica formula de pago.

	Capacidad = mejora Bolsa. Cada objeto ocupa un hueco.

	Depositar:
	  basura, billetes, tesoros -> $ (cada pieza x (1 + bonus de las mascotas
	                               de su material), el total x el bonus del
	                               lanzamiento, si lo hubo, x el multiplicador
	                               de los rebirths)
	  fragmentos                -> a la mascota que monta su set (Fragmentos);
	                               uno de un set que el jugador aun no tiene
	                               abierto (lo excavo otro) se paga como un
	                               billete de su material
	  figurinas/cintas/trajes   -> perfil (pospuestos en la v2: solo aparecen
	                               con su funcion encendida)
	El bonus +25 % por bolsa llena se fue con la v2: el riesgo y el premio
	estan en la distancia del tiro.

	Al desconectar: la bolsa se RECICLA sin bonus (auditoria 26 sep: perder
	el dinero por una caida de conexion es un castigo injusto).
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
local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))
local Rebirths = require(Servicios:WaitForChild("Rebirths"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))
local Fragmentos = require(Servicios:WaitForChild("Fragmentos"))

local BolsaEvent = Red.evento("BolsaEvent")

export type Item = {
	tipo: string, -- basura | billete | tesoro | fragmento | figurina | cinta | traje | bolsa (solo en el mundo)
	contenido: { any }?, -- bolsa caida: lo que llevaba
	dueno: string?, -- nombre visible del dueno de una bolsa caida
	duenoId: number?, -- UserId: el unico que puede recogerla
	nombre: string,
	material: string?,
	valor: number?,
	id: string?, -- coleccionables; el set de un fragmento
}

export type ResumenDeposito = {
	objetos: number, -- piezas que se pagaron
	dinero: number,
	bonus: number, -- bonus del lanzamiento aplicado (0 = entregado a mano)
	porMaterial: { [string]: number }, -- piezas pagadas de cada material
	fragmentos: number, -- fragmentos que contaron para una mascota
	cerrados: { string }, -- sets de los fragmentos pagados por no tenerlos abiertos
}

local Bolsa = {}

Bolsa.alCambiar = Senal.nueva() :: Senal.Senal<Player>
-- Cada deposito (prompt o bolsa lanzada que entro) con lo que se vacio y su
-- resumen: la recicladora lo muestra por la cinta
Bolsa.alDepositar = Senal.nueva() :: Senal.Senal<Player, { Item }, ResumenDeposito>
-- El resumen de cada deposito, sea cual sea la via
Bolsa.alResumen = Senal.nueva() :: Senal.Senal<Player, ResumenDeposito>

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
	return Mejoras.valor(jugador, "Bolsa")
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

-- Lo que vale una pieza antes de multiplicadores (0 si no es dinero). La
-- UNICA tabla de precios: el valor del material de la pieza, x6 un billete
-- y x40 un tesoro. `valor` fijo (pruebas) manda si viene.
function Bolsa.valorDeposito(_jugador: Player, item: Item): number
	if item.valor then
		return item.valor
	end
	local base = GameConfig.VALOR_MATERIAL[item.material or ""] or 0
	if item.tipo == "basura" then
		return base
	elseif item.tipo == "billete" then
		return base * GameConfig.MULT_BILLETE
	elseif item.tipo == "tesoro" then
		return base * GameConfig.MULT_TESORO
	end
	return 0
end

function Bolsa.resumenVacio(): ResumenDeposito
	return { objetos = 0, dinero = 0, bonus = 0, porMaterial = {}, fragmentos = 0, cerrados = {} }
end

function Bolsa.meter(jugador: Player, item: Item): boolean
	if Bolsa.estaLlena(jugador) then
		return false
	end
	table.insert(itemsDe(jugador), item)
	Bolsa.publicar(jugador)
	return true
end

-- Vacia la bolsa y devuelve lo que llevaba. Lo usa el lanzamiento: la bolsa
-- sale volando con todo.
function Bolsa.vaciar(jugador: Player): { Item }
	local items = itemsDe(jugador)
	bolsas[jugador] = {}
	Bolsa.publicar(jugador)
	return items
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

-- Calcula el pago (sin tocar nada) y pasa al perfil lo que no es dinero.
local function cobrar(jugador: Player, items: { Item }, bonus: number): ResumenDeposito
	local resumen = Bolsa.resumenVacio()
	resumen.bonus = bonus
	local bruto = 0
	for _, item in items do
		local valor = Bolsa.valorDeposito(jugador, item)
		if valor > 0 then
			local material = item.material or "Mixto"
			bruto += valor * (1 + Mascotas.bonusMaterial(jugador, material))
			resumen.objetos += 1
			resumen.porMaterial[material] = (resumen.porMaterial[material] or 0) + 1
		elseif item.tipo == "fragmento" and item.id then
			if Fragmentos.agregar(jugador, item.id, "patio") then
				resumen.fragmentos += 1
			else
				bruto += (GameConfig.VALOR_MATERIAL[item.material or ""] or 0) * GameConfig.MULT_BILLETE
				table.insert(resumen.cerrados, item.id)
			end
		elseif (item.tipo == "figurina" or item.tipo == "cinta" or item.tipo == "traje") and item.id then
			if not Coleccionables.agregar(jugador, item.tipo, item.id) then
				-- Duplicado (no deberia pasar): Dona Chatarra lo paga como un
				-- tesoro de papel
				bruto += GameConfig.VALOR_MATERIAL.Papel * GameConfig.MULT_TESORO
			end
		end
	end
	resumen.dinero = math.floor(bruto * (1 + bonus) * Rebirths.multiplicador(jugador) + 0.5)
	if resumen.dinero > 0 then
		Economia.ganar(jugador, resumen.dinero)
	end
	return resumen
end

-- Recicla una lista de items (los de su bolsa, o los de una bolsa lanzada que
-- entro). bonus = lo que suma el lanzamiento (0 entregando a mano).
function Bolsa.depositarItems(jugador: Player, items: { Item }, bonus: number?): ResumenDeposito
	local resumen = cobrar(jugador, items, bonus or 0)
	Perfiles.estadistica(jugador, "objetosReciclados", resumen.objetos)
	Perfiles.estadistica(jugador, "depositos", 1)
	Bolsa.publicar(jugador)
	Bolsa.alDepositar:Fire(jugador, items, resumen)
	Bolsa.alResumen:Fire(jugador, resumen)
	return resumen
end

-- Deposito por el prompt del Contenedor: entregar a mano, sin bonus.
function Bolsa.depositar(jugador: Player): ResumenDeposito?
	if Bolsa.cuenta(jugador) == 0 then
		return nil
	end
	return Bolsa.depositarItems(jugador, Bolsa.vaciar(jugador), 0)
end

-- Recicla sin bonus, sin senales y sin tocar la bolsa en mano: al
-- desconectar (DataService espera un instante antes del guardado final) y
-- para una bolsa perdida que nadie recogio (Lanzamiento).
function Bolsa.reciclarSinBonus(jugador: Player, items: { Item }): ResumenDeposito
	local resumen = cobrar(jugador, items, 0)
	Perfiles.estadistica(jugador, "objetosReciclados", resumen.objetos)
	return resumen
end

local function vaciarAlSalir(jugador: Player)
	local items = bolsas[jugador]
	bolsas[jugador] = nil
	if not items or #items == 0 then
		return
	end
	Bolsa.reciclarSinBonus(jugador, items)
end

Players.PlayerRemoving:Connect(vaciarAlSalir)

Perfiles.alCargar:Connect(function(jugador)
	Bolsa.publicar(jugador)
end)

-- La capacidad cambia al subir la mejora o al renacer (vuelve a 0): el
-- cliente tiene que verlo ya
Mejoras.alComprar:Connect(function(jugador, id)
	if id == "Bolsa" then
		Bolsa.publicar(jugador)
	end
end)
Rebirths.alRenacer:Connect(function(jugador)
	Bolsa.publicar(jugador)
end)

return Bolsa
