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
	lanzar = "Lanzar",
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
	cerrar = "Cerrar",
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
	figurinaYaTienes = "Ya tienes esta figurita",
	patioLleno = "Patio lleno: espera un poco",
	montonPendiente = "Termina tu montón primero",
	monton = "Montón de basura",
	montonRico = "Montón con mucho {material}",
	materialBloqueado = "{material}: Rebirth {n}",
	prioridad = "Espera {s} s: es de {dueno}",
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
		insignia = "Solo multiplicador e insignia",
	},
	reinicia = "Se reinician el dinero y las mejoras",
	conserva = "Te quedas las zonas abiertas, los récords, las insignias y los pases",
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
	comprar = "Comprar",
	comprado = "Comprado",
	equipar = "Equipar",
	equipado = "Equipado",
	quitar = "Quitar",
	robux = "{precio} Robux",
	sinIds = "Producto no disponible todavía",
	mejoraComprada = "{nombre} → nivel {nivel}",
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
}

Textos.NOTIFICACIONES = {
	bienvenida = "¡Bienvenido a Recíclatas! Excava un montón del patio y lanza la bolsa a un contenedor. Si separas por colores, pagan el doble.",
	perfilNoCargado = "No se pudo cargar tu progreso. Esta sesión no se guardará.",
	guardado = "Progreso guardado",
	compraRobux = "Compra completada: {nombre}",
	cintaEncontrada = "¡Cinta encontrada: {nombre}!",
	tesoro = "Tesoro guardado en la bolsa",
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
