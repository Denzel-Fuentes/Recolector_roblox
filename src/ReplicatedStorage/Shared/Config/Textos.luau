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
	gemas = "Gemas",
	energia = "Energía",
	bolsa = "Bolsa",
	bolsaLlena = "¡Bolsa llena! Vuelve a la caseta",
	album = "Álbum",
	tienda = "Tienda",
	logros = "Logros",
	base = "Mi base",
	irCasa = "Ir a casa",
	irPatio = "Ir al patio",
	lanzar = "Lanzar",
	mantenerLanzar = "MANTÉN {tecla} PARA LANZAR",
	tocarLanzar = "MANTÉN EL BOTÓN PARA LANZAR",
	cartas = "Cartas",
	fuerza = "Fuerza",
	restaurarEnergia = "RESTAURAR ENERGÍA",
	telefono = "Teléfono",
	cerrar = "Cerrar",
}

Textos.PATIO = {
	excavar = "Excavar",
	montonAgotado = "Montón agotado",
	reciclar = "Reciclar bolsa",
	comprarRefresco = "Comprar refresco ($50)",
	hablar = "Hablar",
	meGusta = "Me gusta",
	sinEnergia = "Sin energía: compra un refresco en la máquina",
	bolsaLlena = "Bolsa llena: recicla en la caseta",
	almacenLleno = "Almacén lleno: vende o fusiona mascotas",
	bolsaVacia = "No llevas nada que reciclar",
	nadaQueLanzar = "La bolsa está vacía: no hay nada que lanzar",
	bolsaDe = "Bolsa de {dueno}",
	bolsaRecogida = "Recogiste la bolsa de {dueno} ({n} objetos)",
	demasiadoCerca = "Aléjate un poco para lanzar",
	demasiadoLejos = "Demasiado lejos para lanzar",
	acierto = "¡Dentro! +${bonus} desde {distancia} studs",
	fallo = "Fuera. La bolsa quedó en el suelo: cualquiera puede recogerla",
	reciclado = "Reciclaste {objetos} objetos por ${dinero}",
	recicladoBonus = "Reciclaste {objetos} objetos por ${dinero} (+25% bolsa llena)",
	refresco = "¡Glup! +{energia} energía",
	sinDinero = "No te alcanza el dinero",
	sinGemas = "No te alcanzan las Gemas",
	figurinaEncontrada = "¡Figurita encontrada: {nombre}!",
	figurinaYaTienes = "Ya tienes esta figurita",
	billete = "+${cantidad}",
}

Textos.FEED = {
	montonGrande = "{jugador} activó un montón grande",
	raraEncontrada = "¡{jugador} encontró una {mascota} ({rareza})!",
	repoblacion = "¡Doña Chatarra trajo más basura!",
	rey = "¡{jugador} obtuvo al Rey Reciclón!",
	logro = "{jugador} desbloqueó «{logro}»",
}

Textos.ALBUM = {
	titulo = "Álbum de mascotas",
	fragmentos = "Fragmentos {n}/5",
	sinCopias = "No la tienes todavía",
	copias = "{n} copias",
	limpiar = "Limpiar",
	fusionar = "Fusionar ×3",
	vender = "Vender ${valor}",
	exhibir = "Exhibir",
	quitarExhibir = "Quitar del pedestal",
	ensamblar = "Ensamblar",
	autoEnsamblar = "Ensamblar (automático)",
	sucia = "sucia",
	resistencia = "Resistencia",
	poder = "Poder",
	pasiva = "Pasiva (exhibida)",
	setCompleto = "¡Set completo!",
	reyBloqueado = "Completa los 4 sets para coronar al Rey Reciclón",
	exhibidas = "Exhibidas {n}/6",
	almacen = "Almacén {n}/{max}",
}

Textos.TIENDA = {
	titulo = "Caseta de Doña Chatarra",
	mejoras = "Mejoras",
	mascotas = "Mascotas",
	trajes = "Trajes",
	gemas = "Gemas y Pases",
	nivel = "Nivel {n}/10",
	maximo = "MÁXIMO",
	comprar = "Comprar",
	comprado = "Comprado",
	equipar = "Equipar",
	equipado = "Equipado",
	quitar = "Quitar",
	noEncontrado = "Aún no lo has encontrado",
	verProbabilidades = "Ver probabilidades",
	sobrePremium = "Sobre de Mascotas Premium",
	contenedorDorado = "Contenedor Dorado",
	contenedorBloqueado = "Se desbloquea con las 7 mejoras al máximo ({n}/7)",
	pagarDinero = "Pagar ${precio}",
	pagarGemas = "Pagar {precio} Gemas",
	robux = "{precio} Robux",
	packGemas = "{gemas} Gemas",
	venderDuplicados = "Vender duplicados",
	sinDuplicados = "No tienes duplicados que vender",
	vendidos = "Vendiste {n} mascotas por ${dinero}",
	sinIds = "Producto no disponible todavía",
	mejoraComprada = "{nombre} → nivel {nivel}",
}

Textos.PROBABILIDADES = {
	titulo = "Probabilidades de {producto}",
	rareza = "Rareza",
	estado = "Estado de conservación",
	nota = "Cada resultado se elige al azar con estas probabilidades exactas. Suman 100%.",
	pityActual = "Tu probabilidad actual de Rara o mejor en montones: {pct}%",
}

Textos.REPARACION = {
	titulo = "Mesa de reparación",
	limpieza = "Limpieza",
	ensamblaje = "Ensamblaje",
	instruccionLimpieza = "Arrastra sobre las manchas para limpiarlas",
	instruccionEnsamblaje = "Toca cada pieza para girarla hasta que encaje",
	completado = "¡Listo!",
	autoEnsamblado = "Auto-Ensamblaje: piezas encajadas al instante",
	nadaQueReparar = "No tienes mascotas sucias ni fragmentos completos",
	elegir = "Elige qué reparar",
}

Textos.BASE = {
	titulo = "Mi base",
	estanteria = "Estantería de figuritas",
	radio = "Radio",
	exhibidor = "Exhibidor",
	meGusta = "Me gusta recibidos: {n}",
	reproducir = "Reproducir",
	parar = "Parar",
	sinAudio = "(sin audio todavía)",
	cintaNoTienes = "Cinta no encontrada",
	visitando = "Base de {nombre}",
	parcelaLibre = "Parcela libre",
	miParcela = "Tu base",
	graciasMeGusta = "¡A {nombre} le gusta tu base!",
	yaDisteMeGusta = "Ya diste me gusta a esta base",
}

Textos.LOGROS = {
	titulo = "Logros",
	desbloqueado = "¡Logro desbloqueado!",
	progreso = "{actual}/{umbral}",
	completado = "Completado",
	total = "{n}/40 logros",
}

Textos.NOTIFICACIONES = {
	bienvenida = "Bienvenido a Recíclatas. Habla con Doña Chatarra para empezar.",
	perfilNoCargado = "No se pudo cargar tu progreso. Esta sesión no se guardará.",
	guardado = "Progreso guardado",
	mascotaNueva = "¡Nueva mascota: {nombre}!",
	fragmento = "Fragmento de {nombre} ({n}/5)",
	fragmentosCompletos = "¡Tienes los 5 fragmentos de {nombre}! Ve a la mesa de reparación",
	fusion = "Fusión: {nombre} ahora es {estado}",
	sobre = "Del sobre salió: {nombre} ({rareza}, {estado})",
	contenedor = "Del Contenedor Dorado salieron 3 mascotas",
	compraRobux = "Compra completada: {nombre}",
	gemasRecibidas = "+{n} Gemas",
	rey = "¡Los 4 sets completos! El Rey Reciclón es tuyo",
	trajePuesto = "Traje: {nombre}",
	cintaEncontrada = "¡Cinta encontrada: {nombre}!",
	trajeEncontrado = "¡Traje encontrado: {nombre}!",
	tesoro = "Tesoro guardado en la bolsa",
}

Textos.NPC = {
	saludo1 = "¡Otro reciclador! Excava en los montones, tráeme lo que encuentres y te pago.",
	saludo2 = "Si un montón se activa, cualquiera cerca puede recoger. Avisa a los demás.",
	saludo3 = "Cuando tengas las 7 mejoras al máximo te enseño el Contenedor Dorado.",
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
