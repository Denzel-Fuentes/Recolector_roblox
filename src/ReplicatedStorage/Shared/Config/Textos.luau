--!strict
--[[
	Textos
	Todo el copy de la UI en un solo sitio, en espanol. El codigo nunca lleva
	cadenas visibles al jugador sueltas: asi se revisa el tono de una pasada y se
	podria localizar despues sin tocar logica.

	formatear(clave, {...}) sustituye {nombre} por el valor.
]]

local Textos = {}

Textos.HUD = {
	dinero = "$",
	bolsa = "Bolsa",
	bolsaLlena = "¡Bolsa llena! Lánzala al contenedor verde",
	tienda = "Tienda",
	mascotas = "Mascotas",
	rebirth = "Rebirth",
	pedidos = "Pedidos",
	lanzar = "Lanzar",
	-- La tecla/boton va en una insignia al lado, no en el texto
	mantenerLanzar = "MANTÉN PARA LANZAR",
	tocarLanzar = "MANTÉN",
	mantenerRecoger = "MANTÉN PARA RECOGER",
	-- En el movil se recoge lo que pasa por la mira mientras el dedo la mueve
	tocarRecoger = "DESLIZA EL DEDO: LA MIRA RECOGE",
	clic = "CLIC",
	fuerza = "Fuerza",
	-- Sobre la barra de fuerza, en el patio: lo que daria acertar desde aqui
	bonusAqui = "+{pct} %",
	bolsaLlenaBarra = "¡LLENA!",
	cerrar = "Cerrar",
}

-- Carteles flotantes del mundo (los pinta el cliente sobre lo etiquetado)
Textos.MUNDO = {
	venderBasura = "VENDER BASURA",
	chatarra = "DOÑA CHATARRA",
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

Textos.PATIO = {
	excavar = "Excavar",
	montonAgotado = "Montón agotado",
	reciclar = "Reciclar bolsa",
	-- El prompt de Dona Chatarra: abre la tienda (sin dialogos desde el 29 sep)
	tienda = "Tienda",
	bolsaLlena = "¡Bolsa llena! Lánzala al contenedor verde",
	bolsaVacia = "No llevas nada que reciclar",
	nadaQueLanzar = "La bolsa está vacía: no hay nada que lanzar",
	bolsaDe = "Bolsa de {dueno}",
	bolsaRecogida = "Recuperaste tu bolsa ({n} objetos)",
	bolsaAjena = "Esa bolsa es de {dueno}: solo su dueño puede recogerla",
	demasiadoCerca = "Aléjate un poco para lanzar",
	acierto = "¡Dentro! +${dinero} desde {distancia} studs",
	aciertoBonus = " · +{pct} %",
	aciertoRacha = " · racha {n}",
	fallo = "Fuera. Tu bolsa te espera en el suelo: ve a recogerla",
	reciclado = "Reciclaste {objetos} objetos por ${dinero}",
	sinDinero = "No te alcanza el dinero",
	figurinaEncontrada = "¡Figurita encontrada: {nombre}!",
	figurinaYaTienes = "Ya tienes esta figurita",
	patioLleno = "Hay demasiada basura en el patio: espera a que se recoja un poco",
	montonPendiente = "Termina tu montón antes de abrir otro",
	monton = "Montón de basura",
	montonRico = "Montón con mucho {material}",
	cuadranteBloqueado = "Se abre con el Rebirth {n}",
	prioridad = "Espera {s} s: es el montón de {dueno}",
}

Textos.FEED = {
	montonGrande = "{jugador} activó un montón grande",
	repoblacion = "¡Doña Chatarra trajo más basura!",
	rebirth = "¡{jugador} hizo el Rebirth {n}!",
	recordServidor = "¡Récord del servidor! {jugador} acertó desde {distancia} studs",
	mascota = "¡{jugador} completó a {mascota} ({rareza})!",
	rey = "¡{jugador} tiene las 40 mascotas: el Rey Reciclón es suyo!",
	recordPersonal = "Nuevo récord personal: {distancia} studs",
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
		metal = "Abre la zona de metal y el set Chatarrín",
		organico = "Abre la zona de orgánico y el set Mostrenco",
		segundaMascota = "Una segunda mascota equipada",
		insignia = "Solo multiplicador e insignia",
	},
	reinicia = "Se reinician el dinero y las mejoras",
	conserva = "Te quedas las mascotas, sus fragmentos, las zonas abiertas, los récords y los pases",
	renacer = "Renacer",
	hecho = "¡Rebirth {n}! Tu dinero ahora vale {mult}",
	faltanMejoras = "Antes de renacer, lleva las 4 mejoras al máximo",
	faltaDinero = "Te faltan {dinero} para renacer",
}

Textos.TIENDA = {
	titulo = "Caseta de Doña Chatarra",
	mejoras = "Mejoras",
	trajes = "Trajes",
	pases = "Pases",
	nivel = "Nivel {n}/10",
	maximo = "MÁXIMO",
	comprar = "Comprar",
	comprado = "Comprado",
	equipar = "Equipar",
	equipado = "Equipado",
	quitar = "Quitar",
	noEncontrado = "Aún no lo has encontrado",
	robux = "{precio} Robux",
	sinIds = "Producto no disponible todavía",
	mejoraComprada = "{nombre} → nivel {nivel}",
}

Textos.MASCOTAS = {
	titulo = "Mascotas",
	coleccion = "{n}/10",
	equipadas = "Equipadas {n}/{max}",
	nivel = "Nv {n}",
	noLaTienes = "Aún no la tienes",
	bonus = "+{pct} % al {material}",
	bonusRey = "+{pct} % a todo",
	iman = "Atrae {material} a {radio} studs",
	sinIman = "Sin imán",
	equipar = "Equipar",
	quitar = "Quitar",
	equipada = "Equipada",
	siempreContigo = "Siempre contigo",
	huecosLlenos = "No te quedan huecos: quita una antes",
	-- La mascota que monta cada set con sus fragmentos
	montando = "Montando {nombre} ({rareza}): {n}/{total} fragmentos",
	sinMontar = "Busca fragmentos de {set} en los montones",
	fragmentosHud = "{nombre} {n}/{total}",
	sinFragmentosHud = "Busca fragmentos ✦",
	probabilidades = "Siguiente mascota: {texto}",
	pity = "Rara o mejor cada 5; Épica cada 20",
	bloqueado = "Se abre con el Rebirth {n}",
	fragmentosLibres = "Fragmentos libres: {n}",
	usarLibre = "Usar uno aquí",
	rey = "Consíguelas todas para coronar al Rey Reciclón",
}

-- La ventana que ensena una mascota completada con sus fragmentos
Textos.REVELACION = {
	titulo = "¡Mascota completa!",
	nueva = "¡Nueva!",
	subeNivel = "Sube a nivel {n}",
	convertida = "Ya la tienes al máximo: +{dinero}",
	genial = "¡Genial!",
	deSet = "¡Mascota de {set}!",
}

Textos.LOGROS = {
	desbloqueado = "¡Insignia conseguida!",
}

Textos.NOTIFICACIONES = {
	bienvenida = "¡Bienvenido a Recíclatas! Excava un montón del patio y lanza la bolsa al contenedor verde.",
	perfilNoCargado = "No se pudo cargar tu progreso. Esta sesión no se guardará.",
	guardado = "Progreso guardado",
	compraRobux = "Compra completada: {nombre}",
	trajePuesto = "Traje: {nombre}",
	cintaEncontrada = "¡Cinta encontrada: {nombre}!",
	trajeEncontrado = "¡Traje encontrado: {nombre}!",
	tesoro = "Tesoro guardado en la bolsa",
	mascotaEquipada = "{nombre} te sigue",
	fragmentoRecogido = "¡{nombre}! Recíclalo para que cuente",
	-- Al reciclar un fragmento (el primero de una mascota dice cual es)
	fragmentoNuevo = "¡Fragmento! Estás montando a {nombre} ({rareza}): {n}/{total}",
	fragmento = "Fragmento de {nombre}: {n}/{total}",
	fragmentoCerrado = "Fragmento de {set}: se abre con el Rebirth {n}. Doña Chatarra te lo paga",
}

-- Nombres de los materiales en minuscula, para frases ("atrae metal")
Textos.MATERIALES = {
	Metal = "metal",
	Plastico = "plástico",
	Papel = "papel",
	Organico = "orgánico",
	Mixto = "de todo",
}

-- Tutorial jugable (<90 s): un paso a la vez, lo avanza el servidor. Los
-- pasoN son lo que pide cada paso (DefinicionesTutorial); ya no se ensenan
-- en una tarjeta (quitada el 29 sep), el L9 decidira como
Textos.TUTORIAL = {
	paso1 = "Ve al patio de basura",
	paso2 = "Excava un montón: acércate y mantén Excavar",
	paso3 = "Recoge basura hasta llenar la bolsa",
	paso4 = "Lanza la bolsa al contenedor verde: mantén Lanzar y suelta",
	paso5 = "Compra una mejora en la Tienda",
	completado = "¡Ya sabes reciclar!",
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
