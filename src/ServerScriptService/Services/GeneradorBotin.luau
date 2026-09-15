--!strict
--[[
	GeneradorBotin (ModuleScript)
	Unica responsabilidad: decidir QUE sale de un monton cuando alguien lo
	activa. Solo produce items (tablas): ni modelos, ni posiciones, ni fisica.

	=== RNG con pity (correccion deliberada de la queja #1 del original) ===
	Cada mascota completa tira "Rara o mejor" con probabilidad
	TablasProbabilidad.probabilidadRara(pity). Quien activa se lleva huboRara
	para subir o resetear su pity (lo hace Montones, que es quien toca el
	perfil). Los fragmentos usan una tabla plana pero se sesgan hacia
	mascotas que ya tienes a medias, para que el ensamblaje converja; los
	coleccionables solo salen entre los que te faltan.

	=== Lotes + relleno ===
	Los premios salen de `lotes` tiradas de TIPO_OBJETO (14-44 segun tamano) y
	el resto hasta `total` es basura de relleno: la montana necesita cientos
	de piezas para tener bulto, pero eso no debe multiplicar mascotas ni
	fragmentos. La lista se baraja para que los premios no queden todos en la
	base de la montana.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local TablasProbabilidad = require(Config:WaitForChild("TablasProbabilidad"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))

local Servicios = ServerScriptService:WaitForChild("Services")
local TiposPatio = require(Servicios:WaitForChild("TiposPatio"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))
local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))

type Item = TiposPatio.Item
type Contexto = { huboRara: boolean }

local GeneradorBotin = {}

local rng = Random.new()
local NOMBRE_BASURA = { Metal = "Chatarra", Plastico = "Plástico", Papel = "Papel", Organico = "Orgánico" }

local function mascotaAleatoria(rareza: string, excluir: { [string]: boolean }?): DefinicionesMascotas.Mascota?
	local candidatas = {}
	for _, def in DefinicionesMascotas.porRareza(rareza) do
		if def.id ~= DefinicionesMascotas.ID_REY and not (excluir and excluir[def.id]) then
			table.insert(candidatas, def)
		end
	end
	if #candidatas == 0 then
		return nil
	end
	return candidatas[rng:NextInteger(1, #candidatas)]
end

local function itemBasura(): Item
	local material = TablasProbabilidad.elegir(TablasProbabilidad.MATERIAL_BASURA, rng)
	return { tipo = "basura", nombre = NOMBRE_BASURA[material] or material, material = material, valor = GameConfig.VALOR_BASURA[material] }
end

local function itemTesoro(): Item
	return { tipo = "tesoro", nombre = "Tesoro", valor = rng:NextInteger(GameConfig.VALOR_TESORO.min, GameConfig.VALOR_TESORO.max) }
end

local function itemBillete(): Item
	return { tipo = "billete", nombre = "Billete", valor = rng:NextInteger(GameConfig.VALOR_BILLETE.min, GameConfig.VALOR_BILLETE.max) }
end

local function itemFragmento(jugador: Player): Item
	local enCurso = Mascotas.fragmentosEnCurso(jugador)
	local def: DefinicionesMascotas.Mascota? = nil
	if #enCurso > 0 and rng:NextNumber() < TablasProbabilidad.SESGO_FRAGMENTO_EN_CURSO then
		def = DefinicionesMascotas.obtener(enCurso[rng:NextInteger(1, #enCurso)])
	end
	if not def then
		-- Excluir las que ya tienen los 5 fragmentos esperando ensamblaje
		local perfil = Perfiles.obtener(jugador)
		local excluir = {}
		if perfil then
			for id, n in perfil.fragmentos do
				if n >= GameConfig.FRAGMENTOS_POR_MASCOTA then
					excluir[id] = true
				end
			end
		end
		def = mascotaAleatoria(TablasProbabilidad.elegir(TablasProbabilidad.RAREZA_FRAGMENTO, rng), excluir)
	end
	if not def then
		return itemTesoro()
	end
	return { tipo = "fragmento", nombre = "Fragmento de " .. def.nombre, id = def.id }
end

local function itemMascota(jugador: Player, contexto: Contexto): Item
	local perfil = Perfiles.obtener(jugador)
	local pity = if perfil then perfil.pity else 0
	local probRara = TablasProbabilidad.probabilidadRara(pity, Monetizacion.tienePase(jugador, "PaseSuerte"))
	local rareza = "Comun"
	if rng:NextNumber() < probRara then
		contexto.huboRara = true
		rareza = if rng:NextNumber() < GameConfig.PROB_EPICA_ENTRE_RARAS then "Epica" else "Rara"
	end
	local def = mascotaAleatoria(rareza)
	if not def then
		return itemTesoro()
	end
	local estado = tonumber(TablasProbabilidad.elegir(TablasProbabilidad.ESTADO_MASCOTA_MONTON, rng)) or 2
	return {
		tipo = "mascota",
		nombre = def.nombre,
		id = def.id,
		estado = estado,
		sucia = rng:NextNumber() < TablasProbabilidad.PROB_SUCIA_MONTON,
	}
end

local function itemColeccionable(jugador: Player): Item
	local orden = { TablasProbabilidad.elegir(TablasProbabilidad.COLECCIONABLE, rng), "figurina", "cinta", "traje" }
	for _, tipo in orden do
		local faltantes = Coleccionables.faltantes(jugador, tipo)
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
	return itemTesoro()
end

-- Una tirada de TIPO_OBJETO (un "lote")
local function generarItem(jugador: Player, contexto: Contexto): Item
	local tipo = TablasProbabilidad.elegir(TablasProbabilidad.TIPO_OBJETO, rng)
	if tipo == "basura" then
		return itemBasura()
	elseif tipo == "billete" then
		return itemBillete()
	elseif tipo == "fragmento" then
		return itemFragmento(jugador)
	elseif tipo == "mascota" then
		return itemMascota(jugador, contexto)
	elseif tipo == "tesoro" then
		return itemTesoro()
	end
	return itemColeccionable(jugador)
end

-- El contenido de un monton de `tamano` para `jugador`: `lotes` tiradas
-- (premios) + basura de relleno hasta `total`, barajado. Ambos numeros salen
-- de TAMANOS_MONTON si no se pasan. Devuelve (items, huboRara).
function GeneradorBotin.generar(jugador: Player, tamano: string, total: number?, lotes: number?): ({ Item }, boolean)
	local def = GameConfig.TAMANOS_MONTON[tamano] or GameConfig.TAMANOS_MONTON.chico
	local numLotes = lotes or rng:NextInteger(def.lotes[1], def.lotes[2])
	local cantidad = math.max(total or rng:NextInteger(def.min, def.max), numLotes)
	local contexto: Contexto = { huboRara = false }
	local lista: { Item } = {}
	for _ = 1, numLotes do
		table.insert(lista, generarItem(jugador, contexto))
	end
	for _ = numLotes + 1, cantidad do
		table.insert(lista, itemBasura())
	end
	for i = #lista, 2, -1 do
		local k = rng:NextInteger(1, i)
		lista[i], lista[k] = lista[k], lista[i]
	end
	return lista, contexto.huboRara
end

return GeneradorBotin
