--!strict
--[[
	Bolsa (ModuleScript)
	Unica responsabilidad: lo que cada jugador lleva encima entre el patio y el
	contenedor, y lo que paga al depositarlo. Estado de SESION: no persiste.

	=== El dinero SOLO sale del contenedor (decision del usuario) ===
	Recoger nunca paga. Todo lo que se levanta del patio (basura, billetes,
	tesoros) ocupa un hueco de la bolsa y solo se convierte en $ al
	depositarlo: con el prompt de un contenedor ("entregar a mano", sin
	bonus) o lanzando la bolsa (Lanzamiento, con el bonus del tiro). Las dos
	vias pasan por depositarItems, que es la unica formula de pago.

	=== Cinco contenedores: premio por separar (decision del usuario, 3 oct) ===
	Uno por tipo de basura y uno general. Cada pieza de BASURA paga
	GameConfig.MULT_SEPARADO (x2) en el contenedor de su tipo y
	MULT_MAL_SEPARADO (x0,5) en el de otro tipo; en el general, x1. Billetes,
	tesoros y lo demas no son de ningun contenedor: x1 en todos. La bolsa
	entera va al contenedor donde cae (no se reparte): separar es recoger por
	colores antes de lanzar.

	Capacidad = mejora Bolsa. Cada objeto ocupa un hueco.

	Depositar:
	  basura, billetes, tesoros -> $ (cada pieza x el factor del contenedor,
	                               el total x el bonus del lanzamiento, si
	                               lo hubo, x multiplicadorDinero: rebirths,
	                               pase Dinero x2 y Turbo)
	  figurinas/cintas          -> perfil (pospuestos en la v2: solo aparecen
	                               con su funcion encendida)
	El bonus +25 % por bolsa llena se fue con la v2: el riesgo y el premio
	estan en la distancia del tiro.

	Al desconectar: la bolsa se RECICLA sin bonus (auditoria 26 sep: perder
	el dinero por una caida de conexion es un castigo injusto).
]]

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
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Turbo = require(Servicios:WaitForChild("Turbo"))

local BolsaEvent = Red.evento("BolsaEvent")

export type Item = {
	tipo: string, -- basura | billete | tesoro | figurina | cinta | bolsa (solo en el mundo)
	contenido: { any }?, -- bolsa caida: lo que llevaba
	dueno: string?, -- nombre visible del dueno de una bolsa caida
	duenoId: number?, -- UserId: el unico que puede recogerla hasta libreEn
	libreEn: number?, -- workspace:GetServerTimeNow() desde el que la recoge cualquiera
	nombre: string,
	material: string?,
	valor: number?,
	id: string?, -- coleccionables
}

export type ResumenDeposito = {
	objetos: number, -- piezas que se pagaron
	dinero: number,
	bonus: number, -- bonus del lanzamiento aplicado (0 = entregado a mano)
	porMaterial: { [string]: number }, -- piezas pagadas de cada material
	contenedor: string, -- "General" o el tipo del contenedor
	separadas: number, -- basura en el contenedor de su tipo (x2)
	malSeparadas: number, -- basura en el contenedor de otro tipo (x0,5)
	llena: boolean, -- la bolsa iba llena (pedidos)
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
	return { objetos = 0, dinero = 0, bonus = 0, porMaterial = {}, contenedor = "General", separadas = 0, malSeparadas = 0, llena = false }
end

-- Lo que multiplica todo el dinero de un deposito: el de los rebirths, el
-- pase Dinero x2 y el Turbo (pedidos o Robux)
function Bolsa.multiplicadorDinero(jugador: Player): number
	local pase = if Monetizacion.tienePase(jugador, "DineroX2") then 2 else 1
	return Rebirths.multiplicador(jugador) * pase * Turbo.multiplicador(jugador)
end

-- Lo que multiplica el contenedor a una pieza (materialContenedor nil = el
-- general): x2 la basura de su tipo, x0,5 la de otro, x1 todo lo demas
function Bolsa.factorContenedor(item: Item, materialContenedor: string?): number
	if not materialContenedor or item.tipo ~= "basura" then
		return 1
	end
	return if item.material == materialContenedor then GameConfig.MULT_SEPARADO else GameConfig.MULT_MAL_SEPARADO
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
local function cobrar(jugador: Player, items: { Item }, bonus: number, materialContenedor: string?): ResumenDeposito
	local resumen = Bolsa.resumenVacio()
	resumen.bonus = bonus
	resumen.contenedor = materialContenedor or "General"
	local bruto = 0
	for _, item in items do
		local valor = Bolsa.valorDeposito(jugador, item)
		if valor > 0 then
			local material = item.material or "General"
			local factor = Bolsa.factorContenedor(item, materialContenedor)
			bruto += valor * factor
			if factor > 1 then
				resumen.separadas += 1
			elseif factor < 1 then
				resumen.malSeparadas += 1
			end
			resumen.objetos += 1
			resumen.porMaterial[material] = (resumen.porMaterial[material] or 0) + 1
		elseif (item.tipo == "figurina" or item.tipo == "cinta") and item.id then
			if not Coleccionables.agregar(jugador, item.tipo, item.id) then
				-- Duplicado (no deberia pasar): Dona Chatarra lo paga como un
				-- tesoro de papel
				bruto += GameConfig.VALOR_MATERIAL.Papel * GameConfig.MULT_TESORO
			end
		end
	end
	resumen.dinero = math.floor(bruto * (1 + bonus) * Bolsa.multiplicadorDinero(jugador) + 0.5)
	if resumen.dinero > 0 then
		Economia.ganar(jugador, resumen.dinero)
	end
	return resumen
end

-- Recicla una lista de items (los de su bolsa, o los de una bolsa lanzada que
-- entro) en el contenedor de `materialContenedor` (nil = el general). bonus =
-- lo que suma el lanzamiento (0 entregando a mano).
function Bolsa.depositarItems(jugador: Player, items: { Item }, bonus: number?, materialContenedor: string?): ResumenDeposito
	local resumen = cobrar(jugador, items, bonus or 0, materialContenedor)
	resumen.llena = #items >= Bolsa.capacidad(jugador)
	Perfiles.estadistica(jugador, "objetosReciclados", resumen.objetos)
	Perfiles.estadistica(jugador, "depositos", 1)
	if resumen.separadas > 0 then
		Perfiles.estadistica(jugador, "piezasSeparadas", resumen.separadas)
	end
	Bolsa.publicar(jugador)
	Bolsa.alDepositar:Fire(jugador, items, resumen)
	Bolsa.alResumen:Fire(jugador, resumen)
	return resumen
end

-- Si el contenedor de `materialContenedor` acepta la bolsa de este jugador
-- (nil = el general, siempre). El de un tipo que aun no tiene abierto
-- (GameConfig.MATERIAL_REBIRTH: metal con el Rebirth 1, organico con el 2)
-- esta cerrado: ni lanzando ni a mano (peticion del usuario, 6 oct).
function Bolsa.contenedorAbierto(jugador: Player, materialContenedor: string?): boolean
	local perfil = Perfiles.obtener(jugador)
	return GameConfig.materialAbierto(materialContenedor, if perfil then perfil.rebirths else 0)
end

-- Deposito por el prompt de un contenedor: entregar a mano, sin bonus.
-- (nil, motivo) si no se pudo: "vacia" o "bloqueado"
function Bolsa.depositar(jugador: Player, materialContenedor: string?): (ResumenDeposito?, string?)
	if Bolsa.cuenta(jugador) == 0 then
		return nil, "vacia"
	end
	if not Bolsa.contenedorAbierto(jugador, materialContenedor) then
		return nil, "bloqueado"
	end
	return Bolsa.depositarItems(jugador, Bolsa.vaciar(jugador), 0, materialContenedor)
end

-- Recicla sin bonus, sin senales y sin tocar la bolsa en mano: al
-- desconectar (Perfiles.alSalir, antes del guardado de salida) y para una
-- bolsa perdida que nadie recogio (Lanzamiento).
function Bolsa.reciclarSinBonus(jugador: Player, items: { Item }): ResumenDeposito
	local resumen = cobrar(jugador, items, 0)
	Perfiles.estadistica(jugador, "objetosReciclados", resumen.objetos)
	return resumen
end

-- Al salir, en Perfiles.alSalir: Guardado lo dispara ANTES del guardado de
-- salida, asi que el dinero ya esta en el perfil que se escribe. Sin ceder
-- en ningun momento (el guardado empieza en cuanto esto acaba). Llega
-- tambien sin perfil (se fue antes de cargar): entonces solo se limpia.
local function vaciarAlSalir(jugador: Player)
	local items = bolsas[jugador]
	bolsas[jugador] = nil
	if not items or #items == 0 then
		return
	end
	Bolsa.reciclarSinBonus(jugador, items)
end

Perfiles.alSalir:Connect(vaciarAlSalir)

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
-- Comprar Bolsa XL (o encender el modo dev de pases) cambia la capacidad
Monetizacion.alCambiarPases:Connect(function(jugador)
	Bolsa.publicar(jugador)
end)

return Bolsa
