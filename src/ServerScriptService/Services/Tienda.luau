--!strict
--[[
	Tienda (ModuleScript)
	Unica responsabilidad: lo que Dona Chatarra vende ademas de las mejoras:

	  Sobre de Mascotas Premium   149 Gemas -> 1 mascota limpia, rareza y estado
	                              segun TablasProbabilidad.SOBRE_PREMIUM.
	  Contenedor Dorado           endgame: solo con las 7 mejoras al maximo.
	                              $25.000 o 150 Gemas -> 3 mascotas Raras/Epicas
	                              en buen estado (TablasProbabilidad.CONTENEDOR_DORADO).

	Las probabilidades salen SIEMPRE de TablasProbabilidad, el mismo modulo que
	lee el cliente para el modal "Ver probabilidades": es la garantia de que lo
	mostrado coincide con lo otorgado (politica de Roblox sobre items aleatorios
	pagados).

	Se cobra ANTES de sortear y solo si hay sitio en el almacen para todo lo que
	pueda salir: nunca se cobra algo que no cabe.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local TablasProbabilidad = require(Config:WaitForChild("TablasProbabilidad"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))

export type Resultado = { id: string, uid: string, estado: number, rareza: string }

local Tienda = {}

local rng = Random.new()

local function sortearMascota(tablaRareza: TablasProbabilidad.Tabla, tablaEstado: TablasProbabilidad.Tabla): (DefinicionesMascotas.Mascota, number)
	local rareza = TablasProbabilidad.elegir(tablaRareza, rng)
	local candidatas = {}
	for _, def in DefinicionesMascotas.porRareza(rareza) do
		if def.id ~= DefinicionesMascotas.ID_REY then
			table.insert(candidatas, def)
		end
	end
	local def = candidatas[rng:NextInteger(1, #candidatas)]
	local estado = tonumber(TablasProbabilidad.elegir(tablaEstado, rng)) or 2
	return def, estado
end

local function espacioPara(jugador: Player, n: number): boolean
	return Mascotas.cuenta(jugador) + n <= Mascotas.capacidadAlmacen(jugador)
end

function Tienda.abrirSobre(jugador: Player): (boolean, string, { Resultado })
	if not Perfiles.obtener(jugador) then
		return false, "sinPerfil", {}
	end
	if not espacioPara(jugador, 1) then
		return false, "almacenLleno", {}
	end
	if not Economia.gastarGemas(jugador, GameConfig.PRECIO_SOBRE_GEMAS) then
		return false, "sinGemas", {}
	end
	local def, estado = sortearMascota(TablasProbabilidad.SOBRE_PREMIUM.rareza, TablasProbabilidad.SOBRE_PREMIUM.estado)
	local uid = Mascotas.agregar(jugador, def.id, estado, false)
	Perfiles.estadistica(jugador, "sobres", 1)
	return true, "ok", { { id = def.id, uid = uid or "", estado = estado, rareza = def.rareza } }
end

function Tienda.contenedorDesbloqueado(jugador: Player): boolean
	return Mejoras.todasAlMaximo(jugador)
end

function Tienda.abrirContenedorDorado(jugador: Player, pagarCon: string): (boolean, string, { Resultado })
	if not Perfiles.obtener(jugador) then
		return false, "sinPerfil", {}
	end
	if not Tienda.contenedorDesbloqueado(jugador) then
		return false, "bloqueado", {}
	end
	local n = GameConfig.MASCOTAS_CONTENEDOR_DORADO
	if not espacioPara(jugador, n) then
		return false, "almacenLleno", {}
	end
	if pagarCon == "gemas" then
		if not Economia.gastarGemas(jugador, GameConfig.PRECIO_CONTENEDOR_DORADO_GEMAS) then
			return false, "sinGemas", {}
		end
	else
		if not Economia.gastar(jugador, GameConfig.PRECIO_CONTENEDOR_DORADO) then
			return false, "sinDinero", {}
		end
	end
	local resultados = {}
	for _ = 1, n do
		local def, estado = sortearMascota(TablasProbabilidad.CONTENEDOR_DORADO.rareza, TablasProbabilidad.CONTENEDOR_DORADO.estado)
		local uid = Mascotas.agregar(jugador, def.id, estado, false)
		table.insert(resultados, { id = def.id, uid = uid or "", estado = estado, rareza = def.rareza })
	end
	Perfiles.estadistica(jugador, "contenedoresDorados", 1)
	return true, "ok", resultados
end

return Tienda
