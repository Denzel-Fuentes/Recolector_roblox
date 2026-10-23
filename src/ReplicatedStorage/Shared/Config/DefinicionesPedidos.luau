--!strict
--[[
	DefinicionesPedidos
	Los pedidos de Dona Chatarra (diseno v2, lote 7): tres retos al dia
	ligados a jugar, para volver cada dia. Cada uno da dinero al cumplirse
	(se cobra solo, sin boton); completar los tres del dia da un TURBO: el
	dinero x2 durante unos minutos (3 oct: antes daba fragmentos de mascota,
	que se fueron con las mascotas). Solo datos y cuentas puras.

	Se abren al terminar la parte basica del tutorial (comprar la primera
	mejora, hacia el minuto 3-5): antes el jugador ya tiene bastante que
	aprender. El primero del dia es siempre de punteria. Los retos se
	adaptan a lo que el jugador puede hacer HOY (Services/Pedidos): la
	distancia de un reto de lejos no pasa de su Brazo, y el tipo de uno de
	reciclar un material es de los que abundan en sus zonas abiertas.

	=== Premios (economia v4, 22 oct; docs/Economia-v4.md §2.4) ===
	Un pedido paga un PORCENTAJE del coste del siguiente rebirth
	(DefinicionesRebirths.costeSiguiente: su requisito mas las 4 mejoras de 0
	a 10), en dos cifras significativas: 1,5 / 2 / 3 % segun la dificultad,
	$760 / 1.000 / 1.500 con 0 rebirths y $2.000 / 2.700 / 4.100 con 1. Asi
	vale lo mismo, en proporcion, con 0 rebirths que con 9, y los tres del
	dia suman ~6,5 % del siguiente rebirth (antes $250 / 500 / 900 x el
	multiplicador: un 1 % del R1, nadie lo notaba). Se calcula AL COBRAR
	(premio): si el jugador renace a media tarde, lo pendiente pasa a valer
	lo del rebirth nuevo. El panel ensena la misma cifra (premio, o el espejo
	que Services/Pedidos deja en pedido.recompensa). No lo multiplican pases
	ni Turbo: nadie paga por recibir mas dinero gratis.
	Con el pase VIP el dia trae POR_DIA_VIP pedidos: el de mas es el "Pedido
	VIP" (pedido.vip, Textos.PEDIDOS.vip), sale de las plantillas que no
	salieron, paga como DIFICULTAD_VIP y no cuenta para el Turbo de los tres.

	=== El dia ===
	Cambia a las 06:00 UTC (HORA_CAMBIO_DIA; decision del usuario, 22 oct).
	A medianoche UTC los pedidos cambiaban a las 19-21 h en Latinoamerica, en
	plena tarde de juego; a las 06:00 es de madrugada en America (00-03 h) y
	por la manana en Espana (07-08 h). El calendario y los regalos por jugar
	(Services/Recompensas) cuentan los dias con esta misma funcion.
]]

local Textos = require(script.Parent.Textos)
local DefinicionesRebirths = require(script.Parent.DefinicionesRebirths)

export type Plantilla = {
	id: string, -- tambien la clave de Textos.PEDIDOS
	objetivo: number,
	dificultad: string, -- "facil" | "medio" | "dificil": la recompensa
	punteria: boolean?, -- el primero del dia sale de estas
}

local DefinicionesPedidos = {}

DefinicionesPedidos.PLANTILLAS = {
	{ id = "aciertos", objetivo = 10, dificultad = "medio", punteria = true },
	{ id = "racha", objetivo = 5, dificultad = "dificil", punteria = true },
	-- Acertar N veces desde la distancia del parametro (o mas)
	{ id = "lejos", objetivo = 3, dificultad = "medio", punteria = true },
	{ id = "piezas", objetivo = 150, dificultad = "medio" },
	-- Basura reciclada en el contenedor de su tipo (x2)
	{ id = "separadas", objetivo = 40, dificultad = "facil" },
	-- Basura de un tipo (parametro) reciclada en cualquier contenedor
	{ id = "material", objetivo = 40, dificultad = "medio" },
	{ id = "tesoros", objetivo = 3, dificultad = "medio" },
	{ id = "bolsasLlenas", objetivo = 5, dificultad = "facil" },
} :: { Plantilla }

DefinicionesPedidos.POR_ID = {} :: { [string]: Plantilla }
for _, p in DefinicionesPedidos.PLANTILLAS do
	DefinicionesPedidos.POR_ID[p.id] = p
end

-- Premio por dificultad: fraccion del coste del siguiente rebirth (ver
-- cabecera; sustituye a los $250 / 500 / 900 x multiplicador)
DefinicionesPedidos.PORCENTAJE = { facil = 0.015, medio = 0.02, dificil = 0.03 } :: { [string]: number }
DefinicionesPedidos.POR_DIA = 3
-- Con el pase VIP: uno mas, el Pedido VIP, que paga como esta dificultad
DefinicionesPedidos.POR_DIA_VIP = 4
DefinicionesPedidos.DIFICULTAD_VIP = "dificil"
-- Se abren con este paso del tutorial completado (DefinicionesTutorial)
DefinicionesPedidos.PASO_DESBLOQUEO = "mejora"
-- Premio por completar los tres del dia (sin el VIP): minutos de Turbo
-- (dinero x2)
DefinicionesPedidos.MINUTOS_TURBO = 10
-- Distancias posibles del reto "lejos" (las de los tramos del bonus)
DefinicionesPedidos.DISTANCIAS = { 10, 20, 30, 45, 60 }
-- Hora UTC a la que empieza el dia de los pedidos (ver cabecera)
DefinicionesPedidos.HORA_CAMBIO_DIA = 6

-- El numero de dia de un instante (os.time()): cambia a las
-- HORA_CAMBIO_DIA UTC. Lo comparten los pedidos, el calendario y los regalos
function DefinicionesPedidos.dia(ahora: number): number
	return math.floor((ahora - DefinicionesPedidos.HORA_CAMBIO_DIA * 3600) / 86400)
end

-- Lo que paga un pedido de esa dificultad con `rebirths` hechos: su
-- porcentaje del coste del siguiente rebirth, en dos cifras significativas.
-- Una dificultad desconocida no paga
function DefinicionesPedidos.recompensa(dificultad: string, rebirths: number): number
	local porcentaje = DefinicionesPedidos.PORCENTAJE[dificultad]
	if not porcentaje then
		return 0
	end
	return DefinicionesRebirths.redondear(porcentaje * DefinicionesRebirths.costeSiguiente(rebirths))
end

-- La dificultad con la que paga un pedido del dia: la de su plantilla, salvo
-- el Pedido VIP (DIFICULTAD_VIP)
function DefinicionesPedidos.dificultad(pedido: { id: string, vip: boolean? }): string
	if pedido.vip then
		return DefinicionesPedidos.DIFICULTAD_VIP
	end
	local plantilla = DefinicionesPedidos.POR_ID[pedido.id]
	return if plantilla then plantilla.dificultad else ""
end

-- Lo que paga ese pedido con `rebirths` hechos: el servidor lo cobra con
-- esto y el panel lo ensena con esto, asi siempre coinciden
function DefinicionesPedidos.premio(pedido: { id: string, vip: boolean? }, rebirths: number): number
	return DefinicionesPedidos.recompensa(DefinicionesPedidos.dificultad(pedido), rebirths)
end

-- El texto de un pedido ("Recicla 40 de papel"), para el panel y el HUD.
-- textos: el copy en el idioma del jugador (Idioma.textos en el cliente);
-- por defecto el espanol
function DefinicionesPedidos.texto(pedido: { id: string, objetivo: number, parametro: any? }, textos: typeof(Textos)?): string
	local t = textos or Textos
	local parametro = pedido.parametro
	if typeof(parametro) == "string" then
		parametro = t.MATERIALES[parametro] or parametro
	end
	return t.formatear((t.PEDIDOS :: any)[pedido.id] or pedido.id, { objetivo = pedido.objetivo, parametro = parametro })
end

return DefinicionesPedidos
