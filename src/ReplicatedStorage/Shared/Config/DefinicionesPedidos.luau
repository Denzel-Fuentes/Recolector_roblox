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
	reciclar un material es de los que abundan en sus zonas abiertas. Las
	recompensas son un punto de partida: a calibrar con jugadores.
]]

local Textos = require(script.Parent.Textos)

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

-- Dinero por dificultad (x el multiplicador de rebirth al generarse)
DefinicionesPedidos.RECOMPENSA = { facil = 250, medio = 500, dificil = 900 }
DefinicionesPedidos.POR_DIA = 3
-- Se abren con este paso del tutorial completado (DefinicionesTutorial)
DefinicionesPedidos.PASO_DESBLOQUEO = "mejora"
-- Premio por completar los tres del dia: minutos de Turbo (dinero x2)
DefinicionesPedidos.MINUTOS_TURBO = 10
-- Distancias posibles del reto "lejos" (las de los tramos del bonus)
DefinicionesPedidos.DISTANCIAS = { 10, 20, 30, 45, 60 }

-- El dia (UTC) de un instante: los pedidos cambian a medianoche UTC
function DefinicionesPedidos.dia(ahora: number): number
	return math.floor(ahora / 86400)
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
