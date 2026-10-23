--!strict
--[[
	GameConfig
	Todas las constantes compartidas entre servidor y cliente.

	Distancias en studs, tiempos en segundos, dinero en $ (la unica moneda).
	Los numeros de balance salen del Diseno v2 (docs/GDD.md), que los saco de
	una simulacion: son un punto de partida para las pruebas, no cifras
	finales. Lo primero que hay que medir es el tiempo de viaje y la tasa de
	acierto (PC y movil por separado).
]]

local GameConfig = {}

GameConfig.NOMBRE_JUEGO = "Recíclatas"

-- === Persistencia (Services/Guardado) ===
-- v4 (22 oct, lanzamiento): los perfiles empiezan de cero en un store nuevo
-- (decision del usuario: el de la v3 se abandona, no se borra). En Studio,
-- Guardado le anade "_Studio" (como los rankings): las pruebas tocan el
-- perfil y no deben acabar en el del juego publicado. Las versiones del
-- perfil se migran una a una (Perfiles.MIGRACIONES): la 5 (economia v4,
-- 22 oct) vive en el mismo store.
GameConfig.NOMBRE_DATASTORE = "ReciclatasPerfiles_v4"
GameConfig.VERSION_PERFIL = 5
GameConfig.INTERVALO_AUTOGUARDADO = 120
GameConfig.REINTENTOS_DATASTORE = 3
-- Bloqueo de sesion: cada autoguardado renueva el latido de la sesion. Una
-- sesion de otro servidor con el latido mas viejo que SESION_CADUCA es de un
-- servidor que murio sin liberarla y se toma sin esperar (5 autoguardados
-- seguidos sin escribir: un servidor vivo nunca llega). Si esta viva (el
-- jugador acaba de cambiar de servidor y el otro aun guarda su salida), se
-- reintenta cada SESION_REINTENTO s y a los SESION_ESPERA_ROBO s se roba.
-- SESION_ESPERA_ROBO va por encima del peor caso de una salida lenta (cola
-- detras de un autoguardado, 3 intentos con sus esperas y los reintentos de
-- salida): robar antes dejaria sin guardar lo ultimo que se jugo alli. Un
-- reintento sin escribir no gasta el limite de 1 escritura cada 6 s por
-- clave.
GameConfig.SESION_CADUCA = 600
GameConfig.SESION_ESPERA_ROBO = 60
GameConfig.SESION_REINTENTO = 5
-- Si el guardado de salida falla con la sesion aun nuestra, se reintenta
-- REINTENTOS_SALIDA veces mas, cada ESPERA_REINTENTO_SALIDA s, sin soltar el
-- turno de la clave, antes de dar el perfil por perdido
GameConfig.REINTENTOS_SALIDA = 2
GameConfig.ESPERA_REINTENTO_SALIDA = 5
-- Si la carga falla las REINTENTOS_DATASTORE veces, se juega con un perfil
-- que no se guarda y se reintenta en segundo plano: la primera vez a los
-- tantos segundos, y cada vez el doble (hasta 5 minutos) mientras siga
-- conectado
GameConfig.REINTENTO_CARGA_FONDO = 30

-- === Mejoras (valores y costes en DefinicionesMejoras) ===
GameConfig.NIVEL_MAX_MEJORA = 10
-- Economia v4 (22 oct, docs/Economia-v4.md §2.1): 1,35 (era 1,6) con los
-- mismos costes base. Las 4 al maximo pasan de $118.030 a $35.485: con 1,6
-- el 76 % del gasto estaba en los tres ultimos niveles y el final de cada
-- tramo se hacia eterno. Los requisitos de los rebirths, en
-- DefinicionesRebirths
GameConfig.FACTOR_COSTE_MEJORA = 1.35

-- === Montones ===
GameConfig.DURACION_EXCAVAR = 1.5
-- Los objetos liberados NO caducan mientras el monton sigue a medias.
-- Un monton activo cuenta como disponible mientras le quede esta fraccion de
-- sus objetos sin recoger; por debajo se da por TERMINADO (diseno v2).
GameConfig.FRACCION_MONTON_DISPONIBLE = 0.25
-- Un monton terminado vuelve a crecer a los tantos segundos: sus restos se
-- retiran y aparece la colina (diseno v2: "un monton agotado vuelve a los
-- 45 s"). Por monton, no cuando quedan pocos en el patio como antes: asi un
-- monton con tres piezas escondidas no se queda muerto para siempre.
GameConfig.REPOSICION_MONTON = 45
-- Prioridad del excavador: durante estos segundos solo quien excavo puede
-- recoger las piezas de su monton. Protege a los nuevos frente a veteranos
-- mas rapidos que llegan a la montana ajena.
GameConfig.PRIORIDAD_EXCAVADOR = 10
-- Rendimiento (decision del usuario, 23 sep): cada pieza de una montana es un
-- modelo con fisica replicado a todos; con los 12 activos habia ~700 objetos
-- (~3.000 partes) y se notaba. Dos frenos:
--  * cada jugador tiene como mucho MONTONES_POR_JUGADOR montones SUYOS a medias
--    (a medias = cuenta como disponible: le queda mas de
--    FRACCION_MONTON_DISPONIBLE; asi otro jugador no lo bloquea dejando 3
--    piezas enterradas).
--  * el patio entero no pasa de MAX_OBJETOS_PATIO objetos de montana: seis
--    grandes llenos o dieciocho chicos.
GameConfig.MONTONES_POR_JUGADOR = 1
GameConfig.MAX_OBJETOS_PATIO = 360
-- min/max = OBJETOS que aparecen al activar: la colina se sustituye entera
-- por una montana de basura del mismo tamano (decision del usuario: "mucha
-- basura, equivalente al tamano del monton") y cada pieza es un objeto que se
-- recoge. cantidad = montones de ese tamano; radio = de la montana (media
-- base; la altura sale de min/max).
-- Diseno v2: tres por cuadrante, 2 chicos de 20 piezas y 1 grande de 60 con
-- un tesoro garantizado (ConstructorMundo los reparte). Cada pieza se tira por separado (TablasProbabilidad.TIPO_PIEZA).
GameConfig.TAMANOS_MONTON = {
	chico = { min = 20, max = 20, cantidad = 12, radio = 7 },
	grande = { min = 60, max = 60, cantidad = 6, radio = 13, tesoroGarantizado = true },
}
-- El patio es un RECTANGULO: 97,5 (oeste-este) x 150 (norte-sur). Era un
-- cuadrado de 150 centrado en el origen y el usuario lo recorto un 35 % por
-- el lado contrario a las parcelas (el este). Patio.posicionEnPatio y
-- ConstructorMundo leen estos bordes.
GameConfig.PATIO = { oeste = -75, este = 22.5, norte = -75, sur = 75 }
-- Los 6 cuadrantes del patio: 2 columnas (oeste, este) x 3 filas (norte,
-- centro, sur), numerados en orden de lectura desde el noroeste. Decision
-- del usuario (5 oct): ya no hay cuadrantes cerrados ni barreras; los
-- rebirths desbloquean TIPOS de basura (MATERIAL_REBIRTH), no secciones.
-- Cada cuadrante tiene una ZONA que decide la mezcla de materiales
-- (TablasProbabilidad.MEZCLA); hoy todos son "patio".
-- Unica fuente: el constructor la hornea en las ranuras (atributos
-- Cuadrante y Zona) y el runtime la lee por el indice.
GameConfig.COLUMNAS_PATIO = 2
GameConfig.FILAS_PATIO = 3
GameConfig.CUADRANTES = {
	{ zona = "patio", rebirth = 0 },
	{ zona = "patio", rebirth = 0 },
	{ zona = "patio", rebirth = 0 },
	{ zona = "patio", rebirth = 0 },
	{ zona = "patio", rebirth = 0 },
	{ zona = "patio", rebirth = 0 },
}
-- Material que destaca en cada zona (color del suelo y cartel de la
-- barrera); las del patio abierto no destacan ninguno
GameConfig.ZONAS = {
	patio = { destaca = nil },
	metal = { destaca = "Metal" },
	organico = { destaca = "Organico" },
} :: { [string]: { destaca: string? } }

-- Rebirths que hacen falta para cada tipo de basura (decision del usuario,
-- 5 oct): un monton solo trae los tipos que tiene abiertos quien lo excava,
-- y nadie recoge una pieza de un tipo que aun no tiene, aunque la haya
-- sacado otro jugador.
GameConfig.MATERIAL_REBIRTH = { Papel = 0, Plastico = 0, Metal = 1, Organico = 2 } :: { [string]: number }

function GameConfig.materialAbierto(material: string?, rebirths: number): boolean
	if not material then
		return true
	end
	return rebirths >= (GameConfig.MATERIAL_REBIRTH[material] or 0)
end

-- === Punteria: lanzar la BOLSA entera al Contenedor de la caseta ===
GameConfig.DISTANCIA_MIN_LANZAR = 6
GameConfig.VIDA_PROYECTIL = 4
-- Mantener pulsado carga la fuerza: a fuerza 1 la bolsa llega al alcance del
-- Brazo del jugador (mejora Brazo, 25 -> 70 studs).
GameConfig.FUERZA_LANZAMIENTO = { segundosCarga = 1.2, minimo = 0.15 }
-- Una bolsa que falla es solo de su dueno durante BOLSA_LIBRE_SEGUNDOS desde
-- que se posa; despues la recoge cualquiera y se queda lo que lleva
-- (decision del usuario, 6 oct; todos ven la cuenta atras encima). La
-- auditoria del 26 sep la habia dejado solo para el dueno para siempre
-- (que cualquiera se la quedara castigaba al que arriesga): los 30 s son el
-- punto medio. No se recicla sola (29 sep). Ver Services/Lanzamiento.
GameConfig.BOLSA_LIBRE_SEGUNDOS = 30
-- Bonus por distancia y racha, ayuda de punteria: Config/DefinicionesPunteria

-- === Valores en $ ===
-- Todo se cobra al depositar en el contenedor (nunca al recoger): basura,
-- billetes y tesoros ocupan un hueco de la bolsa hasta entonces. Diseno v2:
-- el valor es el del MATERIAL de la pieza (los materiales que se abren con
-- rebirths pagan mas); un billete vale 6 piezas de su material y un tesoro
-- 40. Una bolsa inicial (10 piezas revueltas del patio) vale unos $125 de
-- media contando billetes y tesoros, sin bonus.
GameConfig.VALOR_MATERIAL = { Papel = 5, Plastico = 7, Metal = 15, Organico = 25 }
GameConfig.MULT_BILLETE = 6
GameConfig.MULT_TESORO = 40

-- === Contenedores por tipo (decision del usuario, 3 oct) ===
-- Un contenedor por tipo de basura y uno general. "Premio por separar": en
-- el de su tipo una pieza de basura paga x2; en el de otro tipo, x0,5; en
-- el general todo paga x1. Billetes y tesoros pagan lo suyo en cualquiera.
-- Asi recoger por colores (la basura es del color de su tipo) tiene premio
-- y una bolsa revuelta sigue teniendo su sitio. Orden de la fila del mundo
-- (ConstructorMundo), de la cabana hacia el este.
GameConfig.TIPOS_BASURA = { "Papel", "Plastico", "Metal", "Organico" }
GameConfig.MULT_SEPARADO = 2
GameConfig.MULT_MAL_SEPARADO = 0.5

-- === Red ===
GameConfig.COOLDOWN_REMOTE = 0.15
-- Mantener el clic recoge una pieza cada tanto (cliente); >= COOLDOWN_REMOTE,
-- que es lo que el servidor acepta por jugador.
GameConfig.INTERVALO_RECOGIDA = 0.16
GameConfig.DISTANCIA_INTERACCION = 12
-- Entre dos cambios de ajustes (AjustesEvent): el servidor ignora los que
-- llegan antes (Services/Ajustes) y el panel junta los seguidos en un envio
GameConfig.COOLDOWN_AJUSTES = 0.25

-- === Monetizacion ===
-- En Studio, con esta bandera, todos los pases cuentan como comprados para
-- poder probar sus efectos sin ids reales. Apagada por defecto desde que hay
-- Dinero x2 y Bolsa XL (lote 8): las pruebas miden el pago y la bolsa sin
-- ellos. /pases on la enciende en la sesion.
GameConfig.PASES_DEV_EN_STUDIO = false

-- === Funciones pospuestas (diseno v2, 26 sep) ===
-- Lo que la v2 QUITA se borro del codigo (energia, gemas, Sobre, Contenedor
-- Dorado, Pase de la Suerte, Monton extra, reparacion, fusion, venta, base;
-- el 5 oct, los trajes del avatar).
-- Lo que solo POSPONE queda aqui apagado: diluia los premios de los montones
-- y puede volver en una actualizacion. Servidor y cliente leen la misma tabla
-- (vive en ReplicatedStorage). Reactivar = cambiar el booleano (y, para las
-- figurinas fijas, rehornear el mundo).
GameConfig.FUNCIONES = {
	FIGURINAS = false, -- figuritas en los montones y escondidas en el decorado
	CINTAS = false, -- cintas de audio en los montones
}

function GameConfig.activa(nombre: string): boolean
	return (GameConfig.FUNCIONES :: any)[nombre] == true
end

return GameConfig
