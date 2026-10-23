--!strict
--[[
	Textos
	Todo el copy de la UI en un solo sitio, en espanol. El codigo nunca lleva
	cadenas visibles al jugador sueltas: asi se revisa el tono de una pasada.

	Es el ORIGINAL de la localizacion (7 oct): las traducciones estan en
	Config/Traducciones (en, pt) con la misma forma, y el cliente no lee este
	modulo sino Utilidades/Idioma.textos. Toda clave nueva va tambien alli
	(la prueba "idioma" lo comprueba). El servidor no envia estos textos
	montados: envia Idioma.mensaje("SECCION.clave", valores).

	formatear(clave, {...}) sustituye {nombre} por el valor.
]]

local Textos = {}

Textos.HUD = {
	dinero = "$",
	bolsa = "Bolsa",
	bolsaLlena = "¡Bolsa llena! Lánzala a un contenedor",
	tienda = "Tienda",
	rebirth = "Rebirth",
	pedidos = "Pedidos",
	camara = "Cámara",
	-- La tecla/boton va en una insignia al lado, no en el texto
	mantenerLanzar = "MANTÉN PARA LANZAR",
	tocarLanzar = "MANTÉN",
	mantenerRecoger = "MANTÉN PARA RECOGER",
	-- En tactil se apunta con la mira y se mantiene el boton RECOGER (6 oct)
	tocarRecoger = "APUNTA Y MANTÉN RECOGER",
	botonRecoger = "RECOGER",
	clic = "CLIC",
	fuerza = "Fuerza",
	-- Sobre la barra de fuerza, en el patio: lo que daria acertar desde aqui
	bonusAqui = "+{pct} %",
	bolsaLlenaBarra = "¡LLENA!",
	-- C3, 22 oct: el boton del regalo (sexto hueco de la botonera), que abre
	-- el panel Recompensas
	recompensas = "Recompensas",
}

-- Carteles flotantes del mundo (los pinta el cliente sobre lo etiquetado)
Textos.MUNDO = {
	-- Carteles de los contenedores (3 oct): el general acepta todo; los de
	-- tipo pagan x2 lo suyo
	contenedorGeneral = "GENERAL · TODO",
	contenedorTipo = "{tipo} · x2",
	-- La placa del contenedor general cuando no esta la malla de la recicladora
	placaGeneral = "♻ {tipo}",
	-- Encima de un contenedor de un tipo aun bloqueado (ContenedoresBloqueados.client)
	contenedorCandado = "REBIRTH {n}",
	chatarra = "RECICLADORA",
	-- nombre del tendero en su prompt (5 oct: sin "Doña Chatarra")
	tendero = "Reciclador",
	-- rotulo de la tienda (el de la malla de Blender lleva las letras en 3D)
	tienda = "SHOP",
	patio = "Patio de basura ↑",
	-- Barrera de un cuadrante cerrado
	barrera = "Rebirth {n} · {zona}",
	-- C3, 22 oct: debajo de la corona sobre la cabeza de quien tiene el pase
	-- VIP (atributo VIP del Player; la pinta cada cliente)
	vip = "VIP",
}

-- Las zonas del patio (GameConfig.CUADRANTES): la mezcla de sus montones
Textos.ZONAS = {
	patio = "Patio",
	metal = "Zona de metal",
	organico = "Zona de orgánico",
}

-- Los tipos de basura (y sus contenedores), para carteles y titulos
Textos.TIPOS = {
	Papel = "Papel",
	Plastico = "Plástico",
	Metal = "Metal",
	Organico = "Orgánico",
	General = "General",
}

-- "del contenedor ...", para los avisos
Textos.CONTENEDOR = {
	General = "general",
	Papel = "del papel",
	Plastico = "del plástico",
	Metal = "del metal",
	Organico = "del orgánico",
}

Textos.PATIO = {
	excavar = "Excavar",
	montonAgotado = "Montón agotado",
	reciclar = "Reciclar bolsa",
	-- El prompt de Dona Chatarra: abre la tienda (sin dialogos desde el 29 sep)
	tienda = "Tienda",
	-- Burbujas en el mundo (AvisosMundo): cortas, se leen de un vistazo
	bolsaVacia = "No llevas nada que reciclar",
	contenedorBloqueado = "Se abre con el Rebirth {n}",
	nadaQueLanzar = "La bolsa está vacía",
	bolsaDe = "Bolsa de {dueno}",
	bolsaAjena = "Es de {dueno}: libre en {s} s",
	bolsaTeLaQuitaron = "{quien} se llevó tu bolsa",
	-- La cuenta atras encima de una bolsa caida (TemporizadorBolsas.client)
	temporizadorBolsa = "{s}s",
	bolsaLibre = "¡LIBRE!",
	demasiadoCerca = "Aléjate un poco para lanzar",
	sinDinero = "No te alcanza el dinero",
	figurinaEncontrada = "¡Figurita encontrada: {nombre}!",
	patioLleno = "Patio lleno: espera un poco",
	montonPendiente = "Termina tu montón primero",
	monton = "Montón de basura",
	montonRico = "Montón con mucho {material}",
	materialBloqueado = "{material}: Rebirth {n}",
	prioridad = "Espera {s} s: es de {dueno}",
	-- P3, 22 oct: el servidor no deja lanzar una bolsa que no esta llena
	bolsaNoLlena = "Llena la bolsa para poder lanzarla",
	-- P3, 22 oct: al dueno, cuando por pasar el tope de bolsas caidas su
	-- bolsa mas antigua se recicla sola y sin bonus. {dinero} es lo cobrado,
	-- con Idioma.dinero (ya trae el "$")
	bolsaViejaReciclada = "Demasiadas bolsas en el suelo: la más vieja se recicló sola por {dinero}, sin bonus",
}

-- Celebraciones (5 oct, peticion del usuario: sin toasts al cobrar): letras
-- grandes que aparecen un momento al encestar o entregar la bolsa
-- (UI/Celebraciones) y el "+1" que sale de cada objeto recogido
-- (EfectoRecogida)
Textos.CELEBRACION = {
	acierto = "¡DENTRO!",
	entrega = "¡RECICLADO!",
	dinero = "+${dinero}",
	distancia = "{distancia} m",
	bonusDistancia = "+{pct} % distancia",
	racha = "Racha ×{n}",
	separadas = "{n} bien separadas ×2",
	malSeparadas = "{n} en el equivocado",
	mas = "+{n}",
	billete = "+${dinero}",
	tesoro = "¡TESORO!",
}

Textos.FEED = {
	montonGrande = "{jugador} activó un montón grande",
	repoblacion = "¡Llegó más basura al patio!",
	rebirth = "¡{jugador} hizo el Rebirth {n}!",
	recordServidor = "¡Récord del servidor! {jugador} acertó desde {distancia} m",
}

-- La tarjeta grande de record de distancia (UI/Notificaciones, 7 oct)
Textos.RECORD = {
	titulo = "¡NUEVO RÉCORD!",
	distancia = "{distancia} m",
	personal = "Tu mejor lanzamiento",
	servidor = "¡El mejor del servidor!",
}

-- Los tablones de ranking de la plaza (Client/Tablones; DefinicionesRankings)
Textos.RANKING = {
	titulo = {
		dinero = "Dinero ganado",
		racha = "Racha máxima",
		aciertos = "Bolsas encestadas",
	},
	historico = "Histórico",
	semanal = "Esta semana",
	-- Tu fila, al pie de cada columna
	tu = "Tú: #{pos} · {valor}",
	tuFuera = "Tú: fuera del top {n} · {valor}",
	tuSinValor = "Tú: aún sin puesto",
	cargando = "Cargando…",
	noDisponible = "Ranking no disponible",
	vacio = "Aún nadie",
}

Textos.REBIRTH = {
	titulo = "Rebirth",
	siguiente = "Rebirth {n}",
	tienes = "Rebirths: {n} · dinero {mult}",
	requisitoDinero = "Ten {dinero} en mano",
	requisitoMejoras = "Las 4 mejoras al máximo",
	mejora = "{nombre} {n}/10",
	premio = "Tu dinero pasa a {mult}",
	desbloquea = {
		metal = "Desbloquea la basura de metal",
		organico = "Desbloquea la basura orgánica",
		bolsaPlateada = "Regala la Bolsa plateada",
		-- C3, 22 oct (economia v4, §3): el R4 y el R5 regalan un cosmetico, del
		-- R6 al R9 solo sube el multiplicador y el R10 da la insignia Leyenda.
		-- "Solo multiplicador e insignia" se quito: prometia insignias que no
		-- existian
		bolsaHielo = "Regala la Bolsa de hielo",
		estelaFuego = "Regala la Estela de fuego y una insignia",
		multiplicador = "Sube tu multiplicador de dinero",
		leyenda = "Regala la insignia Leyenda del reciclaje",
	},
	reinicia = "Se reinician el dinero y las mejoras",
	conserva = "Te quedas los tipos de basura que abriste, los récords, las insignias y los pases",
	renacer = "Renacer",
	hecho = "¡Rebirth {n}! Tu dinero ahora vale {mult}",
	faltanMejoras = "Antes de renacer, lleva las 4 mejoras al máximo",
	faltaDinero = "Te faltan {dinero} para renacer",
}

Textos.TIENDA = {
	titulo = "Caseta de reciclaje",
	mejoras = "Mejoras",
	pases = "Pases",
	estilo = "Estilo",
	proximamente = "Próximamente",
	loTienes = "Es tuyo",
	dePago = "Pase de Robux",
	conRebirth = "Regalo del Rebirth {n}",
	maximo = "MÁXIMO",
	comprado = "Comprado",
	equipar = "Equipar",
	quitar = "Quitar",
	robux = "{precio} Robux",
	sinIds = "Producto no disponible todavía",
	mejoraComprada = "{nombre} → nivel {nivel}",
	-- C3, 22 oct (economia v4): de donde sale cada cosmetico nuevo (en Estilo;
	-- {nombre} es el de la insignia), la etiqueta del Pack de inicio, el tope
	-- de los botones de Turbo ({horas}, un numero) y el boton mientras llega
	-- de Roblox el precio de verdad
	conInsignia = "Con la insignia {nombre}",
	dePack = "Del Pack de inicio",
	deVip = "Exclusivo VIP",
	compraUnica = "Compra única",
	turboTope = "Ya tienes más de {horas} h de Turbo guardado",
	cargandoPrecio = "Cargando precio…",
}

Textos.LOGROS = {
	desbloqueado = "¡Insignia conseguida!",
}

-- Los pedidos de Dona Chatarra (DefinicionesPedidos): {objetivo}, {progreso}
-- y {parametro} (una distancia o un tipo de basura ya traducido)
Textos.PEDIDOS = {
	titulo = "Pedidos",
	pestanaPedidos = "Pedidos del día",
	pestanaInsignias = "Insignias",
	aciertos = "Encesta {objetivo} bolsas",
	racha = "Consigue una racha de {objetivo}",
	lejos = "Encesta {objetivo} desde {parametro} m o más",
	piezas = "Recicla {objetivo} piezas",
	separadas = "Recicla {objetivo} piezas en su contenedor de color",
	material = "Recicla {objetivo} de {parametro}",
	tesoros = "Encuentra {objetivo} tesoros",
	bolsasLlenas = "Recicla {objetivo} bolsas llenas",
	hecho = "¡Hecho!",
	premioDia = "Completa los 3: {minutos} min de dinero x2",
	premioCobrado = "Turbo del día conseguido",
	cerrados = "Los pedidos se abren cuando compres tu primera mejora",
	nuevos = "Pedidos nuevos cada día",
	insigniasConseguidas = "{n}/{total} conseguidas",
	-- C3, 22 oct: la etiqueta del 4.º pedido del dia, el del pase VIP
	vip = "Pedido VIP",
}

-- Version corta para la barra del HUD: "{etiqueta} n/objetivo"
Textos.PEDIDOS_HUD = {
	aciertos = "Encesta",
	racha = "Racha",
	lejos = "Desde {parametro} m",
	piezas = "Recicla",
	separadas = "Separa",
	material = "{parametro}",
	tesoros = "Tesoros",
	bolsasLlenas = "Bolsas llenas",
	formato = "{etiqueta} {n}/{total}",
}

Textos.PEDIDOS_AVISOS = {
	cumplido = "¡Pedido cumplido! +${dinero}",
	todos = "¡Los 3 pedidos del día! Dinero x2 durante {minutos} min",
}

-- El Turbo en el HUD (dinero x2 un rato)
Textos.TURBO = {
	activo = "x2 {tiempo}",
	-- C3, 22 oct (economia v4): el Turbo solo corre mientras se juega. En
	-- pausa (tras un rato sin hacer nada) el HUD lo dice; la tienda lo explica
	pausado = "x2 en pausa",
	soloJugando = "El Turbo solo corre mientras juegas",
}

Textos.NOTIFICACIONES = {
	bienvenida = "¡Bienvenido a Recíclatas! Excava un montón del patio y lanza la bolsa a un contenedor. Si separas por colores, pagan el doble.",
	perfilNoCargado = "No se pudo cargar tu progreso. Esta sesión no se guardará.",
	compraRobux = "Compra completada: {nombre}",
	cintaEncontrada = "¡Cinta encontrada: {nombre}!",
	-- P1, 22 oct: con esto se expulsa (Player:Kick) a quien abrio su partida
	-- en otro servidor (bloqueo de sesion). Kick solo admite texto plano: el
	-- servidor tiene que resolverlo en el idioma del jugador antes de enviarlo
	sesionEnOtroServidor = "Tu partida se abrió en otro servidor. Vuelve a entrar para seguir jugando.",
	-- C2, 22 oct: el perfil guardado es de una version mas nueva que la de
	-- este servidor: se juega, pero sin guardar (Guardado.prepararPerfil)
	versionNueva = "Hay una versión nueva del juego: vuelve a entrar para seguir jugando.",
	-- C2, 22 oct: la carga en segundo plano encontro la partida guardada y
	-- sustituye al perfil provisional (lo jugado con el se pierde)
	progresoRecuperado = "Ya cargó tu progreso guardado. Lo que jugaste mientras no se podía guardar no se conserva.",
	-- C3, 22 oct: el Turbo del Pack de inicio, que se da una sola vez
	packTurbo = "Pack de inicio: +{minutos} min de Turbo",
}

-- Nombres de los materiales en minuscula, para frases ("recicla 40 de papel")
Textos.MATERIALES = {
	Metal = "metal",
	Plastico = "plástico",
	Papel = "papel",
	Organico = "orgánico",
	Mixto = "de todo",
}

-- Tutorial jugable: un paso a la vez, lo avanza el servidor. Los pasoN son
-- lo que pide cada paso (DefinicionesTutorial); se ensenan en una pildora
-- arriba a la izquierda (lote 9; la tarjeta de abajo se quito el 29 sep)
Textos.TUTORIAL = {
	paso = "Paso {n}/{total}",
	paso1 = "Ve al patio de basura",
	paso2 = "Excava un montón: acércate y mantén Excavar",
	paso3 = "Recoge basura hasta llenar la bolsa",
	paso4 = "Lanza la bolsa al contenedor azul: mantén Lanzar y suelta",
	paso5 = "Compra una mejora en la Tienda",
	paso6 = "Recoge basura de un solo color y lánzala a su contenedor: paga el doble",
	paso7 = "Cumple un pedido de la recicladora",
	paso8 = "Meta: las 4 mejoras al máximo y {dinero} para el Rebirth 1",
	completado = "¡Tutorial completado! Ya eres un reciclador",
}

-- C2, 22 oct: el sonido (lo hace A1): el boton del HUD y los dos ajustes
-- (perfil.ajustes), cada uno activado o desactivado
Textos.SONIDO = {
	boton = "Sonido",
	musica = "Música",
	efectos = "Efectos",
	activado = "Activado",
	desactivado = "Desactivado",
}

-- C2, 22 oct: la pantalla de carga (la hace L1). progreso sale si la carga
-- tarda (a los 8 s); los consejos van rotando, de consejo1 a consejo5
-- (claves con nombre y no una lista: Idioma traduce por clave)
Textos.CARGA = {
	titulo = "Cargando…",
	progreso = "Cargando tu progreso…",
	consejo1 = "Separa la basura por colores: en su contenedor paga el doble.",
	consejo2 = "Mantén F más tiempo para lanzar más lejos.",
	consejo3 = "Cada día hay pedidos nuevos en la recicladora.",
	consejo4 = "Vuelve cada día a por tu recompensa diaria.",
	consejo5 = "Los rebirths abren tipos nuevos de basura.",
}

-- C3, 22 oct (economia v4, docs/Economia-v4.md §4; lo hace R1): el panel
-- Recompensas, que abre el boton del regalo del HUD. Tiene el calendario de
-- 7 casillas (una por dia jugado: saltarse un dia no reinicia nada), los
-- regalos por minutos activos del dia y la ventana del bono de regreso.
-- {premio} es un dinero (Idioma.dinero, ya trae el "$") o un mensaje anidado
-- (premioTurbo, premioY, el nombre de un cosmetico con Idioma.mensajeNombre);
-- {n} y {minutos} son numeros sueltos. El documento ponia las recompensas en
-- una pestana de Pedidos: tienen panel y boton propios, y "abiertas" lo dice
Textos.RECOMPENSAS = {
	titulo = "Recompensas",
	calendario = "Calendario",
	dia = "Día {n}",
	-- La vuelta al calendario (tras la casilla 7 se vuelve a la 1)
	semana = "Semana {n}",
	reclamar = "Reclamar",
	reclamado = "Reclamado",
	vuelveManana = "Vuelve mañana para el día {n}",
	listo = "¡Tu premio del día está listo!",
	cobrado = "Día {n}: {premio}",
	sinPrisa = "Si un día no juegas, no pierdes nada: el calendario te espera",
	regalos = "Regalos por jugar",
	minutosHoy = "Hoy llevas {n} min jugando",
	siguiente = "Siguiente regalo a los {n} min",
	todos = "¡Ya tienes todos los regalos de hoy! Mañana hay más",
	soloActivo = "Cuentan los minutos en los que recoges, lanzas o excavas",
	regalo = "¡Regalo por jugar {n} min! {premio}",
	-- La etiqueta de cada tramo de regalos
	tramo = "{n} min",
	regresoTitulo = "¡Qué bien verte otra vez!",
	regresoTexto = "Por volver te llevas {premio}",
	-- El boton que cierra la ventana del regreso (el premio ya se dio solo)
	genial = "¡Genial!",
	cerradas = "Las recompensas se abren cuando compres tu primera mejora",
	abiertas = "¡Recompensas nuevas! Míralas en el botón Recompensas",
	premioTurbo = "Turbo {minutos} min",
	premioY = "{a} y {b}",
}

-- C3, 22 oct (economia v4, §5.6; lo hace K1): las ofertas en el momento
-- justo. Normas de Roblox con menores: "Comprar" y "Ahora no" igual de
-- visibles, sin cuentas atras, sin "solo hoy", sin precios tachados y sin la
-- palabra oferta en pantalla (el precio no cambia nunca). {precio} y
-- {minutos} son numeros; {mult} y {mult2}, Idioma.multiplicador; {nombre},
-- el nombre de lo comprado (Idioma.mensajeNombre)
Textos.OFERTAS = {
	comprar = "Comprar · {precio} Robux",
	ahoraNo = "Ahora no",
	packTitulo = "Pack de inicio",
	packTexto = "30 min de Turbo y la Bolsa del reciclador, que solo está en este pack. Se compra una sola vez.",
	bolsaXLTitulo = "¿Se te llena la bolsa?",
	bolsaXLTexto = "Bolsa XL: 10 huecos más para siempre. Menos viajes al contenedor.",
	turboTitulo = "Se acabó tu Turbo",
	turboTexto = "El Turbo paga el doble mientras juegas y solo corre mientras estás en el juego.",
	-- Cada boton de la oferta de Turbo (15 y 60 min), al lado de "Ahora no"
	turboOpcion = "{minutos} min · {precio} Robux",
	dineroTitulo = "Tu dinero ya vale {mult}",
	dineroTexto = "Con Dinero x2 valdría {mult2}, para siempre.",
	vipTitulo = "VIP",
	vipTexto = "Corona VIP sobre tu cabeza, la Estela VIP y un pedido más cada día.",
	gracias = "¡Gracias! Ya es tuyo: {nombre}",
}

function Textos.formatear(plantilla: string, valores: { [string]: any }): string
	local resultado = plantilla:gsub("{(%w+)}", function(clave)
		local v = valores[clave]
		if v == nil then
			return "{" .. clave .. "}"
		end
		return tostring(v)
	end)
	return resultado
end

return Textos
