--!strict
--[[
	DefinicionesRebirths
	Los rebirths del diseno v2: reinician el dinero y las mejoras y a cambio
	dan un multiplicador de dinero permanente y abren material. Solo datos y
	cuentas puras (servidor, panel y pruebas las comparten).

	Para renacer hace falta tener las 4 mejoras al maximo y el dinero del
	requisito en mano. Los cinco primeros estan a mano (el primero hacia la
	hora de juego abre el metal; el segundo, hacia la hora y media, el
	organico; el tercero da la segunda mascota equipada); desde el sexto el
	requisito se multiplica por 4 y el multiplicador sube 0,5 cada vez.
	Aviso del diseno: desde el Rebirth 4 no se abre nada nuevo; es el hueco
	que deberan llenar las actualizaciones.

	Lo que abre cada rebirth no se repite aqui: las zonas las dice
	GameConfig.CUADRANTES y los sets de mascotas DefinicionesMascotas.SETS.
]]

export type Rebirth = {
	requisito: number, -- $ en mano para hacerlo
	multiplicador: number, -- multiplicador de dinero con este rebirth hecho
	desbloquea: string, -- clave de Textos.REBIRTH.desbloquea
}

local DefinicionesRebirths = {}

DefinicionesRebirths.TABLA = {
	{ requisito = 50000, multiplicador = 1.5, desbloquea = "metal" },
	{ requisito = 200000, multiplicador = 2, desbloquea = "organico" },
	{ requisito = 800000, multiplicador = 2.5, desbloquea = "segundaMascota" },
	{ requisito = 3200000, multiplicador = 3, desbloquea = "insignia" },
	{ requisito = 12800000, multiplicador = 3.5, desbloquea = "insignia" },
} :: { Rebirth }

-- Pasado el ultimo de la tabla: requisito x4 y multiplicador +0,5 por rebirth
DefinicionesRebirths.FACTOR_REQUISITO = 4
DefinicionesRebirths.PASO_MULTIPLICADOR = 0.5
-- Rebirths con los que se equipa una mascota mas (diseno v2: 2 huecos desde
-- el Rebirth 3; el pase Tercera mascota da otro)
DefinicionesRebirths.REBIRTH_SEGUNDA_MASCOTA = 3

-- El rebirth numero n (1 = el primero): requisito, multiplicador y que abre
function DefinicionesRebirths.rebirth(n: number): Rebirth
	local tabla = DefinicionesRebirths.TABLA
	if n <= #tabla then
		return tabla[math.max(n, 1)]
	end
	local ultimo = tabla[#tabla]
	local extra = n - #tabla
	return {
		requisito = ultimo.requisito * DefinicionesRebirths.FACTOR_REQUISITO ^ extra,
		multiplicador = ultimo.multiplicador + DefinicionesRebirths.PASO_MULTIPLICADOR * extra,
		desbloquea = "insignia",
	}
end

-- Multiplicador de dinero con `rebirths` hechos (0 -> x1)
function DefinicionesRebirths.multiplicador(rebirths: number): number
	if rebirths <= 0 then
		return 1
	end
	return DefinicionesRebirths.rebirth(rebirths).multiplicador
end

-- Huecos de mascota equipada que dan los rebirths (sin contar pases)
function DefinicionesRebirths.huecosMascota(rebirths: number): number
	return if rebirths >= DefinicionesRebirths.REBIRTH_SEGUNDA_MASCOTA then 2 else 1
end

return DefinicionesRebirths
