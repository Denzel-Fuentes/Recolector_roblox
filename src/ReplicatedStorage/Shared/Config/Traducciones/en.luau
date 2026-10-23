--!strict
--[[
	Traducciones/en
	El copy de Textos en ingles: misma forma, mismas claves y los mismos
	{marcadores} (la prueba "idioma" lo comprueba). Lo que falte aqui sale en
	espanol. DEF traduce los nombres de las definiciones de Config por id.

	Glosario (para que todo diga lo mismo): bolsa = bag, contenedor = bin,
	monton = pile, patio = junkyard, pedido = order, mejora = upgrade,
	insignia = badge, racha = streak, tesoro = treasure, encestar = score.
	"Rebirth", "Turbo" y "VIP" no se traducen (asi los llaman en Roblox).
]]

return {
	HUD = {
		bolsa = "Bag",
		bolsaLlena = "Bag full! Throw it into a bin",
		tienda = "Shop",
		rebirth = "Rebirth",
		pedidos = "Orders",
		camara = "Camera",
		mantenerLanzar = "HOLD TO THROW",
		tocarLanzar = "HOLD",
		mantenerRecoger = "HOLD TO PICK UP",
		tocarRecoger = "AIM AND HOLD PICK UP",
		botonRecoger = "PICK UP",
		clic = "CLICK",
		fuerza = "Power",
		bonusAqui = "+{pct} %",
		bolsaLlenaBarra = "FULL!",
		-- C3, 22 oct
		recompensas = "Rewards",
	},

	MUNDO = {
		contenedorGeneral = "GENERAL · ALL",
		contenedorTipo = "{tipo} · x2",
		placaGeneral = "♻ {tipo}",
		contenedorCandado = "REBIRTH {n}",
		chatarra = "RECYCLER",
		tendero = "Recycler",
		patio = "Junkyard ↑",
		barrera = "Rebirth {n} · {zona}",
		-- C3, 22 oct
		vip = "VIP",
	},

	ZONAS = {
		patio = "Junkyard",
		metal = "Metal zone",
		organico = "Organic zone",
	},

	TIPOS = {
		Papel = "Paper",
		Plastico = "Plastic",
		Metal = "Metal",
		Organico = "Organic",
		General = "General",
	},

	CONTENEDOR = {
		General = "general",
		Papel = "paper",
		Plastico = "plastic",
		Metal = "metal",
		Organico = "organic",
	},

	PATIO = {
		excavar = "Dig",
		montonAgotado = "Pile used up",
		reciclar = "Recycle bag",
		tienda = "Shop",
		bolsaVacia = "You have nothing to recycle",
		contenedorBloqueado = "Opens at Rebirth {n}",
		nadaQueLanzar = "Your bag is empty",
		bolsaDe = "{dueno}'s bag",
		bolsaAjena = "It's {dueno}'s: free in {s} s",
		bolsaTeLaQuitaron = "{quien} took your bag",
		temporizadorBolsa = "{s}s",
		bolsaLibre = "FREE!",
		demasiadoCerca = "Step back a bit to throw",
		sinDinero = "You can't afford it",
		figurinaEncontrada = "Figurine found: {nombre}!",
		patioLleno = "Junkyard full: wait a moment",
		montonPendiente = "Finish your pile first",
		monton = "Trash pile",
		montonRico = "Pile with lots of {material}",
		materialBloqueado = "{material}: Rebirth {n}",
		prioridad = "Wait {s} s: it's {dueno}'s",
		-- P3, 22 oct
		bolsaNoLlena = "Fill your bag to throw it",
		bolsaViejaReciclada = "Too many bags on the ground: your oldest one was recycled for {dinero}, no bonus",
	},

	CELEBRACION = {
		acierto = "SCORED!",
		entrega = "RECYCLED!",
		dinero = "+${dinero}",
		distancia = "{distancia} m",
		bonusDistancia = "+{pct} % distance",
		racha = "Streak ×{n}",
		separadas = "{n} sorted right ×2",
		malSeparadas = "{n} in the wrong bin",
		mas = "+{n}",
		billete = "+${dinero}",
		tesoro = "TREASURE!",
	},

	FEED = {
		montonGrande = "{jugador} opened a big pile",
		repoblacion = "More trash arrived at the junkyard!",
		rebirth = "{jugador} reached Rebirth {n}!",
		recordServidor = "Server record! {jugador} scored from {distancia} m",
	},

	RECORD = {
		titulo = "NEW RECORD!",
		distancia = "{distancia} m",
		personal = "Your best throw",
		servidor = "The best in the server!",
	},

	RANKING = {
		titulo = {
			dinero = "Money earned",
			racha = "Best streak",
			aciertos = "Bags scored",
		},
		historico = "All time",
		semanal = "This week",
		tu = "You: #{pos} · {valor}",
		tuFuera = "You: outside top {n} · {valor}",
		tuSinValor = "You: not ranked yet",
		cargando = "Loading…",
		noDisponible = "Ranking unavailable",
		vacio = "No one yet",
	},

	REBIRTH = {
		titulo = "Rebirth",
		siguiente = "Rebirth {n}",
		tienes = "Rebirths: {n} · money {mult}",
		requisitoDinero = "Have {dinero} on hand",
		requisitoMejoras = "All 4 upgrades maxed",
		mejora = "{nombre} {n}/10",
		premio = "Your money becomes {mult}",
		desbloquea = {
			metal = "Unlocks metal trash",
			organico = "Unlocks organic trash",
			bolsaPlateada = "Gives you the Silver bag",
			-- C3, 22 oct
			bolsaHielo = "Gives you the Ice bag",
			estelaFuego = "Gives you the Fire trail and a badge",
			multiplicador = "Raises your money multiplier",
			leyenda = "Gives you the Recycling legend badge",
		},
		reinicia = "Your money and upgrades reset",
		conserva = "You keep unlocked zones, records, badges and passes",
		renacer = "Rebirth",
		hecho = "Rebirth {n}! Your money is now worth {mult}",
		faltanMejoras = "Max out all 4 upgrades before you rebirth",
		faltaDinero = "You need {dinero} more to rebirth",
	},

	TIENDA = {
		titulo = "Recycling shed",
		mejoras = "Upgrades",
		pases = "Passes",
		estilo = "Style",
		proximamente = "Coming soon",
		loTienes = "You own it",
		dePago = "Robux pass",
		conRebirth = "Rebirth {n} reward",
		maximo = "MAX",
		comprado = "Bought",
		equipar = "Equip",
		quitar = "Remove",
		robux = "{precio} Robux",
		sinIds = "Product not available yet",
		mejoraComprada = "{nombre} → level {nivel}",
		-- C3, 22 oct
		conInsignia = "With the {nombre} badge",
		dePack = "From the Starter pack",
		deVip = "VIP exclusive",
		compraUnica = "One-time purchase",
		turboTope = "You already have over {horas} h of Turbo saved",
		cargandoPrecio = "Loading price…",
	},

	LOGROS = {
		desbloqueado = "Badge earned!",
	},

	PEDIDOS = {
		titulo = "Orders",
		pestanaPedidos = "Daily orders",
		pestanaInsignias = "Badges",
		aciertos = "Score {objetivo} bags",
		racha = "Get a streak of {objetivo}",
		lejos = "Score {objetivo} from {parametro} m or more",
		piezas = "Recycle {objetivo} pieces",
		separadas = "Recycle {objetivo} pieces in their color bin",
		material = "Recycle {objetivo} {parametro}",
		tesoros = "Find {objetivo} treasures",
		bolsasLlenas = "Recycle {objetivo} full bags",
		hecho = "Done!",
		premioDia = "Complete all 3: {minutos} min of x2 money",
		premioCobrado = "Daily Turbo earned",
		cerrados = "Orders open when you buy your first upgrade",
		nuevos = "New orders every day",
		insigniasConseguidas = "{n}/{total} earned",
		-- C3, 22 oct
		vip = "VIP order",
	},

	PEDIDOS_HUD = {
		aciertos = "Score",
		racha = "Streak",
		lejos = "From {parametro} m",
		piezas = "Recycle",
		separadas = "Sort",
		material = "{parametro}",
		tesoros = "Treasures",
		bolsasLlenas = "Full bags",
		formato = "{etiqueta} {n}/{total}",
	},

	PEDIDOS_AVISOS = {
		cumplido = "Order complete! +${dinero}",
		todos = "All 3 daily orders! x2 money for {minutos} min",
	},

	TURBO = {
		activo = "x2 {tiempo}",
		-- C3, 22 oct
		pausado = "x2 paused",
		soloJugando = "Turbo only runs while you play",
	},

	NOTIFICACIONES = {
		bienvenida = "Welcome to Recíclatas! Dig a pile in the junkyard and throw the bag into a bin. Sort by color and it pays double.",
		perfilNoCargado = "Your progress couldn't be loaded. This session won't be saved.",
		compraRobux = "Purchase complete: {nombre}",
		cintaEncontrada = "Tape found: {nombre}!",
		-- P1, 22 oct
		sesionEnOtroServidor = "Your game was opened on another server. Rejoin to keep playing.",
		-- C2, 22 oct
		versionNueva = "There's a new version of the game: rejoin to keep playing.",
		progresoRecuperado = "Your saved progress is back. What you played while it couldn't be saved isn't kept.",
		-- C3, 22 oct
		packTurbo = "Starter pack: +{minutos} min of Turbo",
	},

	MATERIALES = {
		Metal = "metal",
		Plastico = "plastic",
		Papel = "paper",
		Organico = "organic",
		Mixto = "everything",
	},

	TUTORIAL = {
		paso = "Step {n}/{total}",
		paso1 = "Go to the junkyard",
		paso2 = "Dig a pile: get close and hold Dig",
		paso3 = "Pick up trash until your bag is full",
		paso4 = "Throw the bag into the blue bin: hold Throw and release",
		paso5 = "Buy an upgrade in the Shop",
		paso6 = "Pick up trash of a single color and throw it into its bin: it pays double",
		paso7 = "Complete an order from the recycler",
		paso8 = "Goal: all 4 upgrades maxed and {dinero} for Rebirth 1",
		completado = "Tutorial complete! You're a real recycler",
	},

	-- C2, 22 oct
	SONIDO = {
		boton = "Sound",
		musica = "Music",
		efectos = "Effects",
		activado = "On",
		desactivado = "Off",
	},

	-- C2, 22 oct
	CARGA = {
		titulo = "Loading…",
		progreso = "Loading your progress…",
		consejo1 = "Sort trash by color: it pays double in its own bin.",
		consejo2 = "Hold F longer to throw farther.",
		consejo3 = "There are new orders at the recycler every day.",
		consejo4 = "Come back every day for your daily reward.",
		consejo5 = "Rebirths unlock new types of trash.",
	},

	-- C3, 22 oct
	RECOMPENSAS = {
		titulo = "Rewards",
		calendario = "Calendar",
		dia = "Day {n}",
		semana = "Week {n}",
		reclamar = "Claim",
		reclamado = "Claimed",
		vuelveManana = "Come back tomorrow for day {n}",
		listo = "Your daily reward is ready!",
		cobrado = "Day {n}: {premio}",
		sinPrisa = "Miss a day and you lose nothing: the calendar waits for you",
		regalos = "Playtime gifts",
		minutosHoy = "You've played {n} min today",
		siguiente = "Next gift at {n} min",
		todos = "You got all of today's gifts! More tomorrow",
		soloActivo = "Only minutes where you pick up, throw or dig count",
		regalo = "Gift for playing {n} min! {premio}",
		tramo = "{n} min",
		regresoTitulo = "Great to see you again!",
		regresoTexto = "For coming back, you get {premio}",
		genial = "Awesome!",
		cerradas = "Rewards open when you buy your first upgrade",
		abiertas = "New rewards! Check them on the Rewards button",
		premioTurbo = "Turbo {minutos} min",
		premioY = "{a} and {b}",
	},

	-- C3, 22 oct
	OFERTAS = {
		comprar = "Buy · {precio} Robux",
		ahoraNo = "Not now",
		packTitulo = "Starter pack",
		packTexto = "30 min of Turbo and the Recycler bag, which only comes in this pack. One-time purchase.",
		bolsaXLTitulo = "Is your bag always full?",
		bolsaXLTexto = "XL Bag: 10 more slots forever. Fewer trips to the bin.",
		turboTitulo = "Your Turbo ran out",
		turboTexto = "Turbo pays double while you play, and it only runs while you're in the game.",
		turboOpcion = "{minutos} min · {precio} Robux",
		dineroTitulo = "Your money is now worth {mult}",
		dineroTexto = "With x2 Money it would be worth {mult2}, forever.",
		vipTitulo = "VIP",
		vipTexto = "A VIP crown over your head, the VIP trail and one more order every day.",
		gracias = "Thanks! It's yours: {nombre}",
	},

	DEF = {
		Mejoras = {
			Bolsa = { nombre = "Bag", descripcion = "Fits more trash in your bag" },
			Alcance = { nombre = "Reach", descripcion = "Pick up from farther away" },
			Velocidad = { nombre = "Speed", descripcion = "Run faster" },
			Brazo = { nombre = "Arm", descripcion = "Throw the bag farther" },
		},
		Pases = {
			DineroX2 = { nombre = "x2 Money", descripcion = "Everything you recycle pays double, forever" },
			BolsaXL = { nombre = "XL Bag", descripcion = "10 more slots in your bag, forever" },
			EstelaArcoiris = { nombre = "Rainbow trail", descripcion = "Your bag leaves a rainbow when you throw it" },
			BolsaDorada = { nombre = "Golden bag", descripcion = "A bag made of gold to show off" },
			-- C3, 22 oct
			PackInicio = { nombre = "Starter pack", descripcion = "30 min of Turbo (once) and the Recycler bag, which only comes in this pack" },
			VIP = { nombre = "VIP", descripcion = "A VIP crown over your head, the VIP trail and one more order every day" },
		},
		Productos = {
			Turbo15 = { nombre = "Turbo 15 min", descripcion = "x2 money for 15 minutes of play (adds to any you have left)" },
			-- C3, 22 oct
			Turbo60 = { nombre = "Turbo 60 min", descripcion = "x2 money for 60 minutes of play (adds to any you have left)" },
		},
		Bolsas = {
			Plateada = { nombre = "Silver bag" },
			Dorada = { nombre = "Golden bag" },
			-- C3, 22 oct
			Carton = { nombre = "Cardboard bag" },
			Hielo = { nombre = "Ice bag" },
			Reciclador = { nombre = "Recycler bag" },
		},
		Estelas = {
			Arcoiris = { nombre = "Rainbow trail" },
			-- C3, 22 oct
			Fuego = { nombre = "Fire trail" },
			VIP = { nombre = "VIP trail" },
		},
		Insignias = {
			primerReciclaje = { nombre = "First recycle", descripcion = "Recycle your first bag" },
			primerAcierto = { nombre = "Scored!", descripcion = "Score your first bag" },
			tiro30 = { nombre = "Strong arm", descripcion = "Score from 30 m" },
			tiro60 = { nombre = "Sharpshooter", descripcion = "Score from 60 m" },
			racha5 = { nombre = "On a roll", descripcion = "Score 5 in a row" },
			racha10 = { nombre = "Unstoppable", descripcion = "Score 10 in a row" },
			piezas1000 = { nombre = "Recycler", descripcion = "Recycle 1,000 pieces" },
			piezas10000 = { nombre = "Master recycler", descripcion = "Recycle 10,000 pieces" },
			separadas500 = { nombre = "Good sorter", descripcion = "Recycle 500 pieces in their color bin" },
			primerTesoro = { nombre = "Treasure hunter", descripcion = "Find a treasure in the trash" },
			dinero10k = { nombre = "Saver", descripcion = "Earn $10,000 in total" },
			dinero1M = { nombre = "Millionaire", descripcion = "Earn $1,000,000 in total" },
			mejoraMax = { nombre = "Maxed out", descripcion = "Max out an upgrade" },
			todasMax = { nombre = "Fully geared", descripcion = "All 4 upgrades maxed" },
			rebirth1 = { nombre = "Reborn", descripcion = "Do your first Rebirth" },
			rebirth3 = { nombre = "Veteran", descripcion = "Reach Rebirth 3" },
			-- C3, 22 oct
			rebirth5 = { nombre = "Elite recycler", descripcion = "Reach Rebirth 5" },
			rebirth10 = { nombre = "Recycling legend", descripcion = "Reach Rebirth 10" },
			semanaCompleta = { nombre = "Dedicated", descripcion = "Claim all 7 calendar rewards" },
			pedidos30 = { nombre = "Reliable", descripcion = "Complete 30 orders" },
		},
	},
}
