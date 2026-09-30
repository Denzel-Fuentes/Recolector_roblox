--!strict
--[[
	GeneradorBotin (ModuleScript)
	Unica responsabilidad: decidir QUE sale de un monton cuando alguien lo
	activa. Solo produce items (tablas): ni modelos, ni posiciones, ni fisica.

	Diseno v2 (con los cambios del usuario del 29 sep): la basura de un
	monton va REVUELTA; la zona de su cuadrante decide la mezcla de
	materiales (TablasProbabilidad.MEZCLA: el patio abierto es casi todo
	papel y plastico; tras las barreras del norte sale mucho metal u
	organico). Cada pieza se tira por separado (TablasProbabilidad
	.TIPO_PIEZA: basura, 5 % billetes, 1 % tesoros, 2,5 % fragmentos).
	Billetes y tesoros tienen material: valen 6 y 40 piezas de el
	(Bolsa.valorDeposito). El grande trae siempre un tesoro y un fragmento.

	Un fragmento es del set de su material, sacado de la misma mezcla pero
	solo entre los sets que quien excava tiene abiertos: sin el Rebirth 1 no
	salen fragmentos de Chatarrin. Las mascotas se montan con ellos
	(Services/Fragmentos). Los coleccionables pospuestos (figurinas, cintas,
	trajes del botin) solo salen con su funcion encendida.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local TablasProbabilidad = require(Config:WaitForChild("TablasProbabilidad"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))

local Servicios = ServerScriptService:WaitForChild("Services")
local TiposPatio = require(Servicios:WaitForChild("TiposPatio"))
local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))

type Item = TiposPatio.Item

local GeneradorBotin = {}

local rng = Random.new()
local NOMBRE_BASURA = { Metal = "Chatarra", Plastico = "Plástico", Papel = "Papel", Organico = "Orgánico" }
-- Probabilidad de que un monton traiga un coleccionable pospuesto, si
-- alguna de sus funciones esta encendida
local PROB_COLECCIONABLE = 0.25

-- La funcion pospuesta de cada tipo de coleccionable (GameConfig.FUNCIONES)
local FUNCION_COLECCIONABLE = { figurina = "FIGURINAS", cinta = "CINTAS", traje = "TRAJES_BOTIN" }

-- La mezcla de materiales de una zona (la del patio si no existe)
local function mezcla(zona: string): TablasProbabilidad.Tabla
	return TablasProbabilidad.MEZCLA[zona] or TablasProbabilidad.MEZCLA.patio
end

-- La misma mezcla, solo con los materiales cuyo set tiene abierto quien
-- excava (el papel y el plastico lo estan siempre)
local function mezclaAbierta(zona: string, rebirths: number): TablasProbabilidad.Tabla
	local tabla = {}
	for _, e in mezcla(zona) do
		if DefinicionesMascotas.materialAbierto(e.id, rebirths) then
			table.insert(tabla, e)
		end
	end
	return if #tabla > 0 then tabla else mezcla("patio")
end

local function fragmento(material: string): Item
	local set = DefinicionesMascotas.SET_POR_MATERIAL[material]
	return {
		tipo = "fragmento",
		nombre = "Fragmento de " .. (if set then set.nombre else material),
		material = material,
		id = if set then set.id else nil,
	}
end

local function item(tipo: string, material: string): Item
	local nombre = if tipo == "billete" then "Billete" elseif tipo == "tesoro" then "Tesoro" else (NOMBRE_BASURA[material] or material)
	return { tipo = tipo, nombre = nombre, material = material }
end

-- Un coleccionable que le falte a quien excavo, o nil si no toca
local function itemColeccionable(jugador: Player): Item?
	local orden = { TablasProbabilidad.elegir(TablasProbabilidad.COLECCIONABLE, rng), "figurina", "cinta", "traje" }
	for _, tipo in orden do
		local faltantes = if GameConfig.activa(FUNCION_COLECCIONABLE[tipo]) then Coleccionables.faltantes(jugador, tipo) else {}
		if #faltantes > 0 then
			local id = faltantes[rng:NextInteger(1, #faltantes)]
			local nombre = id
			if tipo == "figurina" then
				nombre = DefinicionesColeccionables.FIGURINA_POR_ID[id].nombre
			elseif tipo == "cinta" then
				nombre = DefinicionesColeccionables.CINTA_POR_ID[id].nombre
			elseif tipo == "traje" then
				nombre = DefinicionesColeccionables.TRAJE_POR_ID[id].nombre
			end
			return { tipo = tipo, nombre = nombre, id = id }
		end
	end
	return nil
end

-- El contenido de un monton de `tamano` de la `zona` dada excavado por
-- `jugador` (sus fragmentos son de sus sets abiertos; los coleccionables,
-- de los que le faltan): `total` piezas (el min/max de TAMANOS_MONTON si no
-- se pasa), cada una con su tirada.
function GeneradorBotin.generar(jugador: Player, tamano: string, zona: string, total: number?): { Item }
	local def = GameConfig.TAMANOS_MONTON[tamano] or GameConfig.TAMANOS_MONTON.chico
	local cantidad = total or rng:NextInteger(def.min, def.max)
	local perfil = Perfiles.obtener(jugador)
	local abierta = mezclaAbierta(zona, if perfil then perfil.rebirths else 0)
	local lista: { Item } = {}
	local tesoros, fragmentos = 0, 0
	for _ = 1, cantidad do
		local tipo = TablasProbabilidad.elegir(TablasProbabilidad.TIPO_PIEZA, rng)
		if tipo == "fragmento" then
			fragmentos += 1
			table.insert(lista, fragmento(TablasProbabilidad.elegir(abierta, rng)))
		else
			if tipo == "tesoro" then
				tesoros += 1
			end
			table.insert(lista, item(tipo, TablasProbabilidad.elegir(mezcla(zona), rng)))
		end
	end
	-- Garantias y extras: sustituyen una pieza de basura (el numero de piezas
	-- no cambia, la montana tiene el bulto que tiene)
	local function sustituirBasura(nuevo: Item)
		for i, otro in lista do
			if otro.tipo == "basura" then
				lista[i] = nuevo
				return
			end
		end
	end
	if (def :: any).tesoroGarantizado and tesoros == 0 then
		sustituirBasura(item("tesoro", TablasProbabilidad.elegir(mezcla(zona), rng)))
	end
	if (def :: any).fragmentoGarantizado and fragmentos == 0 then
		sustituirBasura(fragmento(TablasProbabilidad.elegir(abierta, rng)))
	end
	if rng:NextNumber() < PROB_COLECCIONABLE then
		local coleccionable = itemColeccionable(jugador)
		if coleccionable then
			sustituirBasura(coleccionable)
		end
	end
	for i = #lista, 2, -1 do
		local k = rng:NextInteger(1, i)
		lista[i], lista[k] = lista[k], lista[i]
	end
	return lista
end

return GeneradorBotin
