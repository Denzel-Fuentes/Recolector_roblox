--!strict
--[[
	DefinicionesRebirths
	Los rebirths del diseno v2: reinician el dinero y las mejoras y a cambio
	dan un multiplicador de dinero permanente y abren material. Solo datos y
	cuentas puras (servidor, panel y pruebas las comparten).

	Para renacer hace falta tener las 4 mejoras al maximo y el dinero del
	requisito en mano.

	=== La curva (economia v4, 22 oct; docs/Economia-v4.md §2.2 y §3) ===
	Los diez primeros estan a mano. Requisitos de $15.000 a $5M para que
	cada rebirth dure un 16-26 % mas que el anterior: el jugador medio,
	jugando seguido, hace el R1 hacia los 58 min y el R5 hacia las 7 h 26 min
	(antes 3 h y 66 h; la prueba "ritmoR1" rehace la cuenta). Multiplicadores
	x1,5 / 2 / 3 / 4 / 5 ... x10: numeros redondos que el panel lee bien, y
	desde el R3 cada salto se nota (con +0,5, renacer valia un 17-20 % y
	dejaba de notarse). Desde el 11, el requisito x FACTOR_REQUISITO (1,4)
	por rebirth, en dos cifras significativas (redondear), y el
	multiplicador + PASO_MULTIPLICADOR (1): cada uno dura ~1,26 veces el
	anterior. Los costes de las mejoras no crecen con los rebirths, a
	proposito: tras renacer, recomprarlas va cada vez mas rapido.

	`desbloquea` es solo la clave del texto que lo anuncia
	(Textos.REBIRTH.desbloquea); lo que se abre de verdad lo decide quien lo
	da: R1 metal y R2 organico (GameConfig.MATERIAL_REBIRTH), R3 Bolsa
	plateada, R4 Bolsa de hielo y R5 Estela de fuego (DefinicionesCosmeticos,
	por rebirth), la insignia del R5 y la del R10 (DefinicionesInsignias, por
	rebirthMaximo). Del R6 al R9 y desde el 11 solo sube el multiplicador
	("multiplicador": el panel lo dice tal cual, sin prometer nada). Antes, el
	R4 y el R5 decian "Solo multiplicador e insignia" con unas insignias que
	no existian.

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
	redondear(n) deja un premio en dos cifras significativas, como los
	redondea el documento ($757,3 -> $760, $1.009,7 -> $1.000; por debajo de
	100, a la unidad): asi pedidos y recompensas dan cifras redondas iguales.
]]

local DefinicionesMejoras = require(script.Parent.DefinicionesMejoras)

export type Rebirth = {
	requisito: number, -- $ en mano para hacerlo
	multiplicador: number, -- multiplicador de dinero con este rebirth hecho
	desbloquea: string, -- clave de Textos.REBIRTH.desbloquea
}

local DefinicionesRebirths = {}

DefinicionesRebirths.TABLA = {
	{ requisito = 15000, multiplicador = 1.5, desbloquea = "metal" },
	{ requisito = 100000, multiplicador = 2, desbloquea = "organico" },
	{ requisito = 250000, multiplicador = 3, desbloquea = "bolsaPlateada" },
	{ requisito = 500000, multiplicador = 4, desbloquea = "bolsaHielo" },
	{ requisito = 800000, multiplicador = 5, desbloquea = "estelaFuego" },
	{ requisito = 1200000, multiplicador = 6, desbloquea = "multiplicador" },
	{ requisito = 1800000, multiplicador = 7, desbloquea = "multiplicador" },
	{ requisito = 2500000, multiplicador = 8, desbloquea = "multiplicador" },
	{ requisito = 3500000, multiplicador = 9, desbloquea = "multiplicador" },
	{ requisito = 5000000, multiplicador = 10, desbloquea = "leyenda" },
} :: { Rebirth }

-- Pasado el ultimo de la tabla: requisito x1,4 y multiplicador +1 por
-- rebirth (eran x4 y +0,5)
DefinicionesRebirths.FACTOR_REQUISITO = 1.4
DefinicionesRebirths.PASO_MULTIPLICADOR = 1

-- El rebirth numero n (1 = el primero): requisito, multiplicador y que abre.
-- Desde el 11 el requisito sale del ultimo de la tabla (no del anterior ya
-- redondeado): asi el redondeo no se acumula de un rebirth a otro
function DefinicionesRebirths.rebirth(n: number): Rebirth
	local tabla = DefinicionesRebirths.TABLA
	if n <= #tabla then
		return tabla[math.max(n, 1)]
	end
	local ultimo = tabla[#tabla]
	local extra = n - #tabla
	return {
		requisito = DefinicionesRebirths.redondear(ultimo.requisito * DefinicionesRebirths.FACTOR_REQUISITO ^ extra),
		multiplicador = ultimo.multiplicador + DefinicionesRebirths.PASO_MULTIPLICADOR * extra,
		desbloquea = "multiplicador",
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

-- Dos cifras significativas (1.009,7 -> 1.000; 757,3 -> 760); por debajo de
-- 100, a la unidad (docs/Economia-v4.md §2.4). Para los premios en dinero y
-- los requisitos que no estan en la tabla
function DefinicionesRebirths.redondear(n: number): number
	if n < 100 then
		return math.floor(n + 0.5)
	end
	-- La potencia de 10 de n. log10 de una potencia exacta (1.000) puede
	-- quedarse un pelo corto o largo: se corrige con la potencia misma
	local exponente = math.floor(math.log10(n))
	if 10 ^ (exponente + 1) <= n then
		exponente += 1
	elseif 10 ^ exponente > n then
		exponente -= 1
	end
	local paso = 10 ^ (exponente - 1)
	return math.floor(n / paso + 0.5) * paso
end

return DefinicionesRebirths
