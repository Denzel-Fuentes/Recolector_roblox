--!strict
--[[
	Fragmentos (ModuleScript)
	Unica responsabilidad: montar mascotas con los fragmentos que salen entre
	la basura (decision del usuario, 29 sep: sustituye a las capsulas del
	medidor, que daban mascotas demasiado rapido y sin salir del patio).

	  Un fragmento   es una pieza mas del monton (TablasProbabilidad
	                 .TIPO_PIEZA, 2,5 %; el grande trae uno seguro) de un
	                 set: el de su material. Ocupa un hueco de la bolsa y
	                 cuenta al RECICLARLO, como todo (Bolsa).
	  Montaje        cada set monta UNA mascota a la vez. El primer fragmento
	                 decide cual: la rareza (TablasProbabilidad.RAREZA_MASCOTA
	                 con pity POR SET: la 5.a seguida sin Rara o mejor lo es,
	                 la 20.a sin Epica es Epica) y, dentro de ella, una que no
	                 tengas. Desde ese momento el jugador sabe a quien monta
	                 ("Latita 1/5") y cada fragmento de ese set la acerca.
	  Completar      con DefinicionesMascotas.fragmentos(rareza) (5/8/12) sale
	                 la mascota: nueva a nivel 1, o repetida sube de nivel y,
	                 pasado el 5, dinero (Mascotas.agregar).
	  La primera     la primera mascota del jugador es Comun y pide solo
	                 FRAGMENTOS_PRIMERA (3): el gancho de los primeros minutos.
	  Cerrados       los sets de Metal y Organico se abren con el Rebirth 1 y
	                 2. Sus fragmentos no se generan para quien no los tiene;
	                 si alguien recoge uno ajeno sin el rebirth, agregar
	                 devuelve nil y Bolsa lo paga como un billete.
	  Libres         perfil.fragmentosLibres (premio de los pedidos): el
	                 jugador elige el set y cuenta como uno encontrado.

	Tirar la rareza y elegir la mascota son puras sobre el perfil: las
	pruebas las tiran miles de veces con uno de mentira. Quien necesita
	enterarse escucha alAgregar (el aviso y la revelacion en MascotasHandler,
	los pedidos y las insignias).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local TablasProbabilidad = require(Config:WaitForChild("TablasProbabilidad"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))

export type Resultado = {
	set: string,
	origen: string, -- "patio" | "pedido" | "admin"
	id: string, -- la mascota que se monta (o que se acaba de completar)
	rareza: string,
	n: number, -- fragmentos que lleva tras este (= total si se completo)
	total: number,
	empezada: boolean, -- este fragmento decidio la mascota
	completa: Mascotas.Resultado?, -- se completo con este fragmento
}

local Fragmentos = {}

Fragmentos.alAgregar = Senal.nueva() :: Senal.Senal<Player, Resultado>

local rng = Random.new()

-- La rareza cuando el pity obliga a Rara o mejor
local RARA_O_MEJOR = {}
for _, e in TablasProbabilidad.RAREZA_MASCOTA do
	if e.id ~= "Comun" then
		table.insert(RARA_O_MEJOR, e)
	end
end

type PerfilFragmentos = {
	fragmentos: { [string]: Perfiles.Montaje },
	pityMascotas: { [string]: { sinRara: number, sinEpica: number } },
	mascotas: { [string]: number },
}

-- La rareza de la siguiente mascota de un set, aplicando y avanzando el pity
function Fragmentos.tirarRareza(perfil: PerfilFragmentos, setId: string, r: Random?): string
	local pity = perfil.pityMascotas[setId]
	if not pity then
		pity = { sinRara = 0, sinEpica = 0 }
		perfil.pityMascotas[setId] = pity
	end
	local rareza
	if pity.sinEpica >= DefinicionesMascotas.PITY.epica - 1 then
		rareza = "Epica"
	elseif pity.sinRara >= DefinicionesMascotas.PITY.rara - 1 then
		rareza = TablasProbabilidad.elegir(RARA_O_MEJOR, r or rng)
	else
		rareza = TablasProbabilidad.elegir(TablasProbabilidad.RAREZA_MASCOTA, r or rng)
	end
	if rareza == "Epica" then
		pity.sinRara, pity.sinEpica = 0, 0
	elseif rareza == "Rara" then
		pity.sinRara = 0
		pity.sinEpica += 1
	else
		pity.sinRara += 1
		pity.sinEpica += 1
	end
	return rareza
end

-- La mascota de esa rareza que se monta: una que no tenga, si queda alguna
function Fragmentos.elegirMascota(perfil: PerfilFragmentos, setId: string, rareza: string, r: Random?): string?
	local todas, nuevas = {}, {}
	for _, def in DefinicionesMascotas.porSet(setId) do
		if def.rareza == rareza then
			table.insert(todas, def.id)
			if (perfil.mascotas[def.id] or 0) == 0 then
				table.insert(nuevas, def.id)
			end
		end
	end
	local lista = if #nuevas > 0 then nuevas else todas
	if #lista == 0 then
		return nil
	end
	return lista[(r or rng):NextInteger(1, #lista)]
end

-- Sin ninguna mascota ni ningun montaje: la siguiente es la primera
local function esLaPrimera(perfil: PerfilFragmentos): boolean
	return next(perfil.mascotas) == nil and next(perfil.fragmentos) == nil
end

-- Empieza a montar una mascota en un set (el primer fragmento). Pura sobre
-- el perfil.
function Fragmentos.empezar(perfil: PerfilFragmentos, setId: string, r: Random?): Perfiles.Montaje?
	local rareza, total
	if esLaPrimera(perfil) then
		rareza, total = "Comun", DefinicionesMascotas.FRAGMENTOS_PRIMERA
	else
		rareza = Fragmentos.tirarRareza(perfil, setId, r)
		total = DefinicionesMascotas.fragmentos(rareza)
	end
	local id = Fragmentos.elegirMascota(perfil, setId, rareza, r)
	if not id then
		return nil
	end
	local montaje: Perfiles.Montaje = { id = id, n = 0, total = total }
	perfil.fragmentos[setId] = montaje
	return montaje
end

-- Suma un fragmento de un set al jugador. nil si el set no existe o no lo
-- tiene abierto (el que llama decide que hacer con el fragmento).
function Fragmentos.agregar(jugador: Player, setId: string, origen: string): Resultado?
	local perfil = Perfiles.obtener(jugador)
	if not perfil or not DefinicionesMascotas.setAbierto(setId, perfil.rebirths) then
		return nil
	end
	local montaje = perfil.fragmentos[setId]
	local empezada = false
	if not montaje then
		montaje = Fragmentos.empezar(perfil, setId)
		empezada = true
	end
	if not montaje then
		return nil
	end
	local def = DefinicionesMascotas.obtener(montaje.id)
	montaje.n += 1
	Perfiles.estadistica(jugador, "fragmentosEncontrados", 1)
	local resultado: Resultado = {
		set = setId,
		origen = origen,
		id = montaje.id,
		rareza = if def then def.rareza else "Comun",
		n = montaje.n,
		total = montaje.total,
		empezada = empezada,
		completa = nil,
	}
	if montaje.n >= montaje.total then
		perfil.fragmentos[setId] = nil
		Perfiles.estadistica(jugador, "mascotasCompletadas", 1)
		if resultado.rareza == "Epica" then
			Perfiles.estadistica(jugador, "epicasSacadas", 1)
		end
		resultado.completa = Mascotas.agregar(jugador, montaje.id)
	end
	Perfiles.marcarSucio(jugador)
	Fragmentos.alAgregar:Fire(jugador, resultado)
	return resultado
end

-- Fragmento libre (pedidos): el jugador elige el set, que tiene que tener
-- abierto. Devuelve (ok, motivo)
function Fragmentos.usarLibre(jugador: Player, setId: string): (boolean, string)
	local perfil = Perfiles.obtener(jugador)
	if not perfil or not DefinicionesMascotas.SET_POR_ID[setId] then
		return false, "noExiste"
	end
	if perfil.fragmentosLibres <= 0 then
		return false, "sinFragmentos"
	end
	if not DefinicionesMascotas.setAbierto(setId, perfil.rebirths) then
		return false, "bloqueado"
	end
	perfil.fragmentosLibres -= 1
	Perfiles.marcarSucio(jugador)
	Fragmentos.agregar(jugador, setId, "pedido")
	return true, "usado"
end

return Fragmentos
