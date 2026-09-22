--!strict
--[[
	GameConfig
	Todas las constantes compartidas entre servidor y cliente.

	Distancias en studs, tiempos en segundos, dinero en $ (billetes) o Gemas.
	Los numeros de balance (costes, valores, probabilidades base) son un punto de
	partida para las pruebas cerradas, no cifras finales: KOTAMON se termina en
	~5 h jugando gratis y ese es el objetivo de calibracion.
]]

local GameConfig = {}

GameConfig.NOMBRE_JUEGO = "Recíclatas"

-- === Persistencia ===
GameConfig.NOMBRE_DATASTORE = "ReciclatasPerfiles_v1"
GameConfig.VERSION_PERFIL = 1
GameConfig.INTERVALO_AUTOGUARDADO = 120
GameConfig.REINTENTOS_DATASTORE = 3

-- === Energia (mejoras Energia y Chispa) ===
GameConfig.ENERGIA_BASE = 100
GameConfig.ENERGIA_POR_NIVEL = 15
GameConfig.COSTE_EXCAVAR = 10
GameConfig.REFRESCO_BASE = 30
GameConfig.REFRESCO_POR_NIVEL = 8
GameConfig.PRECIO_REFRESCO = 50
-- Regeneracion pasiva: un punto cada tantos segundos. Existe para que quien no
-- compre refrescos nunca quede bloqueado del todo (queja evitable del original).
GameConfig.REGEN_ENERGIA_CADA = 2

-- === Bolsa y Almacen (mejoras Mochila y Almacen) ===
GameConfig.BOLSA_BASE = 8
GameConfig.BOLSA_POR_NIVEL = 3
GameConfig.ALMACEN_BASE = 30
GameConfig.ALMACEN_POR_NIVEL = 10
GameConfig.BONUS_BOLSA_LLENA = 0.25

-- === Movimiento, alcance e iman ===
GameConfig.VELOCIDAD_BASE = 16
GameConfig.VELOCIDAD_POR_NIVEL = 1.2
GameConfig.ALCANCE_BASE = 6
GameConfig.ALCANCE_POR_NIVEL = 1
GameConfig.IMAN_POR_NIVEL = 1.5
GameConfig.INTERVALO_IMAN = 0.2
-- Nada se recoge por pasar encima (decision del usuario): solo con clic (Alcance)
-- o arrastrado por el Iman. A esta distancia un objeto ARRASTRADO entra en la bolsa.
GameConfig.DISTANCIA_RECLAMO_IMAN = 2.5

-- === Mejoras ===
GameConfig.NIVEL_MAX_MEJORA = 10
GameConfig.FACTOR_COSTE_MEJORA = 1.6

-- === Montones ===
GameConfig.DURACION_EXCAVAR = 1.5
-- Los objetos liberados NO caducan: se quedan hasta que alguien los recoja.
GameConfig.UMBRAL_REPOBLACION = 4
-- Un monton activo cuenta como disponible mientras le quede esta fraccion de
-- sus objetos sin recoger (asi la repoblacion no espera al ultimo papel).
GameConfig.FRACCION_MONTON_DISPONIBLE = 0.25
GameConfig.RETRASO_REPOBLACION = 20
-- min/max = OBJETOS que aparecen al activar: al desbloquear, la colina se
-- sustituye entera por una montana de basura del mismo tamano (decision del
-- usuario: "mucha basura, equivalente al tamano del monton"), y cada pieza es
-- un objeto que se recoge. lotes = cuantas tiradas de TIPO_OBJETO se hacen
-- (mascotas, fragmentos, tesoros, billetes, coleccionables): el resto hasta
-- min/max es basura de relleno, asi los premios por monton no se disparan con
-- la cantidad de basura. cantidad = montones de ese tamano (12). radio = de
-- la montana (media base; la altura sale de min/max). Con columnas a 50 studs
-- y filas a 60, el radio 17 del grande deja pasillos de 16.
GameConfig.TAMANOS_MONTON = {
	chico = { min = 30, max = 40, lotes = { 14, 18 }, cantidad = 4, radio = 9 },
	mediano = { min = 80, max = 110, lotes = { 22, 28 }, cantidad = 5, radio = 12 },
	-- grande bajo de 200-280 a 160-200 piezas por rendimiento en movil: con tres
	-- grandes y dos medianos activos habia ~900 objetos (2.800 partes) en el patio
	grande = { min = 160, max = 200, lotes = { 34, 44 }, cantidad = 3, radio = 17 },
}
GameConfig.PATIO_LADO = 200

-- === Pity (correccion deliberada del RNG "duro" del original) ===
GameConfig.PITY_BASE = 0.08
GameConfig.PITY_PASO = 0.02
GameConfig.PITY_PASO_PASE = 0.03
GameConfig.PITY_TOPE = 0.60
GameConfig.PROB_EPICA_ENTRE_RARAS = 0.25

-- === Punteria: lanzar la BOLSA entera al Contenedor de la caseta ===
GameConfig.DISTANCIA_MIN_LANZAR = 6
GameConfig.DISTANCIA_MAX_LANZAR = 70
GameConfig.BONUS_ACIERTO = 0.5
GameConfig.VIDA_PROYECTIL = 4
-- Mantener pulsado carga la fuerza: a fuerza 1 la bolsa llega a alcanceMax.
GameConfig.FUERZA_LANZAMIENTO = { segundosCarga = 1.2, alcanceMax = 70, minimo = 0.15 }

-- === Reparacion ===
GameConfig.FRAGMENTOS_POR_MASCOTA = 5
GameConfig.MIN_SEGUNDOS_LIMPIEZA = 3
GameConfig.MIN_SEGUNDOS_ENSAMBLAJE = 2
GameConfig.MANCHAS_LIMPIEZA = { min = 8, max = 12 }

-- === Valores en $ ===
-- Todo se cobra al depositar en el contenedor (nunca al recoger): basura,
-- billetes y tesoros ocupan un hueco de la bolsa hasta entonces.
GameConfig.VALOR_BASURA = { Metal = 12, Plastico = 8, Papel = 6, Organico = 5 }
GameConfig.VALOR_BILLETE = { min = 20, max = 80 }
GameConfig.VALOR_TESORO = { min = 150, max = 600 }
GameConfig.VALOR_BASE_RAREZA = { Comun = 40, Rara = 200, Epica = 900, Mitica = 5000 }
-- Indice = estado (1 Danada .. 5 Perfecta)
GameConfig.MULT_ESTADO = { 0.5, 1, 1.6, 2.5, 4 }
GameConfig.MULT_SUCIA = 0.5
GameConfig.RECOMPENSA_LOGRO = 100

-- === Tienda de Dona Chatarra ===
GameConfig.PRECIO_SOBRE_GEMAS = 149
GameConfig.PRECIO_CONTENEDOR_DORADO = 25000
GameConfig.PRECIO_CONTENEDOR_DORADO_GEMAS = 150
GameConfig.MASCOTAS_CONTENEDOR_DORADO = 3

-- === Parcelas ===
GameConfig.NUM_PARCELAS = 6
GameConfig.PEDESTALES = 6
GameConfig.SLOTS_ESTANTERIA = 12

-- === Red ===
GameConfig.COOLDOWN_REMOTE = 0.15
-- Mantener el clic recoge una pieza cada tanto (cliente); >= COOLDOWN_REMOTE,
-- que es lo que el servidor acepta por jugador.
GameConfig.INTERVALO_RECOGIDA = 0.16
GameConfig.DISTANCIA_INTERACCION = 12

-- === Monetizacion ===
-- En Studio, con esta bandera, todos los pases cuentan como comprados para
-- poder probar sus efectos sin ids reales. /pases off la desactiva en sesion.
GameConfig.PASES_DEV_EN_STUDIO = true

return GameConfig
