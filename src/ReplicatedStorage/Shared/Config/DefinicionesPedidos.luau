--!strict
--[[
	DefinicionesPedidos
	Los pedidos de Dona Chatarra (diseno v2): tres retos al dia ligados a
	jugar, para volver cada dia. Cada uno da dinero; completar los tres da
	fragmentos de mascota libres para el set que elijas (antes, una capsula:
	las capsulas se quitaron el 29 sep). Solo datos.

	Se abren al completar la primera mascota (hacia el minuto 6-8), y el
	primero del dia es siempre de punteria. Los retos se adaptan a lo que el jugador puede
	hacer HOY: la distancia de un reto de punteria no pasa de su Brazo, y el
	material de uno de reciclaje es de los que tiene abiertos
	(Services/Pedidos). Las recompensas son un punto de partida: a calibrar
	con jugadores.
]]

export type Plantilla = {
	id: string,
	texto: string, -- clave de Textos.PEDIDOS
	objetivo: number,
	dificultad: string, -- "facil" | "medio" | "dificil": la recompensa
	punteria: boolean?, -- el primero del dia sale de estas
}

local DefinicionesPedidos = {}

DefinicionesPedidos.PLANTILLAS = {
	{ id = "aciertos", texto = "aciertos", objetivo = 10, dificultad = "medio", punteria = true },
	{ id = "racha", texto = "racha", objetivo = 5, dificultad = "dificil", punteria = true },
	{ id = "piezas", texto = "piezas", objetivo = 150, dificultad = "medio" },
	{ id = "tesoros", texto = "tesoros", objetivo = 3, dificultad = "medio" },
	{ id = "fragmentos", texto = "fragmentos", objetivo = 3, dificultad = "facil" },
	{ id = "bolsasLlenas", texto = "bolsasLlenas", objetivo = 5, dificultad = "facil" },
} :: { Plantilla }

DefinicionesPedidos.POR_ID = {} :: { [string]: Plantilla }
for _, p in DefinicionesPedidos.PLANTILLAS do
	DefinicionesPedidos.POR_ID[p.id] = p
end

-- Dinero por dificultad (x el multiplicador de rebirth al generarse)
DefinicionesPedidos.RECOMPENSA = { facil = 250, medio = 500, dificil = 900 }
DefinicionesPedidos.POR_DIA = 3
-- Se abren con tantas mascotas completadas (estadistica mascotasCompletadas)
DefinicionesPedidos.DESBLOQUEO_MASCOTAS = 1
-- Fragmentos libres por completar los tres del dia (perfil.fragmentosLibres)
DefinicionesPedidos.PREMIO_FRAGMENTOS = 2
-- Distancias posibles de un reto de punteria (las de los tramos del bonus)
DefinicionesPedidos.DISTANCIAS = { 10, 20, 30, 45, 60 }

-- El dia (UTC) de un instante: los pedidos cambian a medianoche UTC
function DefinicionesPedidos.dia(ahora: number): number
	return math.floor(ahora / 86400)
end

return DefinicionesPedidos
