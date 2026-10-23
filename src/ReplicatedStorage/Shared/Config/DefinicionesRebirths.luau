--!strict
--[[
	DefinicionesRebirths
	Los rebirths del diseno v2: reinician el dinero y las mejoras y a cambio
	dan un multiplicador de dinero permanente y abren material. Solo datos y
	cuentas puras (servidor, panel y pruebas las comparten).

	Para renacer hace falta tener las 4 mejoras al maximo y el dinero del
	requisito en mano. Los cinco primeros estan a mano (el primero hacia la
	hora de juego abre el metal; el segundo, hacia la hora y media, el
	organico; el tercero regala la Bolsa plateada); desde el sexto el
	requisito se multiplica por 4 y el multiplicador sube 0,5 cada vez.
	Aviso del diseno: desde el Rebirth 4 no se abre nada nuevo; es el hueco
	que deberan llenar las actualizaciones.

	El Rebirth 3 daba la segunda mascota equipada; al quitar las mascotas
	(3 oct) regala un diseno de bolsa (DefinicionesCosmeticos). Lo que abre
	cada rebirth no se repite aqui: las zonas las dice GameConfig.CUADRANTES.

	=== Coste del siguiente rebirth (economia v4, C3 22 oct) ===
	costeSiguiente(rebirths) es la base de todos los premios en dinero: los
	pedidos (E1) y el calendario, los regalos y el bono de regreso (R1) pagan
	un porcentaje de el (docs/Economia-v4.md §2.4 y §4.1). Es el tramo
	entero: el requisito en mano del rebirth rebirths + 1 mas las 4 mejoras
	de 0 a 10 (DefinicionesMejoras.costeTotal), como lo define el documento,
	y NO lo que le falta al jugador: asi un premio solo cambia al renacer
	(los pedidos pendientes pasan a valer lo del rebirth nuevo), no baja al
	comprar mejoras y vale lo mismo para todos los del mismo rebirth. El
	segundo argumento (niveles de las mejoras) se acepta y se ignora, para
	que la firma no cambie si algun dia se decide medir lo que falta. Lee las
	tablas al llamarlo: sigue valiendo cuando cambien los numeros.
]]

local DefinicionesMejoras = require(script.Parent.DefinicionesMejoras)

export type Rebirth = {
	requisito: number, -- $ en mano para hacerlo
	multiplicador: number, -- multiplicador de dinero con este rebirth hecho
	desbloquea: string, -- clave de Textos.REBIRTH.desbloquea
}

local DefinicionesRebirths = {}

DefinicionesRebirths.TABLA = {
	{ requisito = 50000, multiplicador = 1.5, desbloquea = "metal" },
	{ requisito = 200000, multiplicador = 2, desbloquea = "organico" },
	{ requisito = 800000, multiplicador = 2.5, desbloquea = "bolsaPlateada" },
	{ requisito = 3200000, multiplicador = 3, desbloquea = "insignia" },
	{ requisito = 12800000, multiplicador = 3.5, desbloquea = "insignia" },
} :: { Rebirth }

-- Pasado el ultimo de la tabla: requisito x4 y multiplicador +0,5 por rebirth
DefinicionesRebirths.FACTOR_REQUISITO = 4
DefinicionesRebirths.PASO_MULTIPLICADOR = 0.5

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

-- Lo que cuesta el siguiente rebirth con `rebirths` hechos: su requisito mas
-- las 4 mejoras de 0 a 10. La base de los premios en dinero (ver cabecera,
-- tambien por que se ignoran los niveles)
function DefinicionesRebirths.costeSiguiente(rebirths: number, _nivelesMejoras: { [string]: number }?): number
	return DefinicionesRebirths.rebirth(rebirths + 1).requisito + DefinicionesMejoras.costeTotal()
end

return DefinicionesRebirths
