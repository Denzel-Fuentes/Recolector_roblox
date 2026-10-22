--!strict
--[[
	Traducciones/en
	El copy de Textos en ingles: misma forma, mismas claves y los mismos
	{marcadores} (la prueba "idioma" lo comprueba). Lo que falte aqui sale en
	espanol. DEF traduce los nombres de las definiciones de Config por id.

	Glosario (para que todo diga lo mismo): bolsa = bag, contenedor = bin,
	monton = pile, patio = junkyard, pedido = order, mejora = upgrade,
	insignia = badge, racha = streak, tesoro = treasure, encestar = score.
	"Rebirth" y "Turbo" no se traducen (asi los llaman en Roblox).
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
			insignia = "Multiplier and badge only",
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
	},

	NOTIFICACIONES = {
		bienvenida = "Welcome to Recíclatas! Dig a pile in the junkyard and throw the bag into a bin. Sort by color and it pays double.",
		perfilNoCargado = "Your progress couldn't be loaded. This session won't be saved.",
		compraRobux = "Purchase complete: {nombre}",
		cintaEncontrada = "Tape found: {nombre}!",
		-- P1, 22 oct
		sesionEnOtroServidor = "Your game was opened on another server. Rejoin to keep playing.",
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
		},
		Productos = {
			Turbo15 = { nombre = "Turbo 15 min", descripcion = "x2 money for 15 minutes (adds to any you have left)" },
		},
		Bolsas = {
			Plateada = { nombre = "Silver bag" },
			Dorada = { nombre = "Golden bag" },
		},
		Estelas = {
			Arcoiris = { nombre = "Rainbow trail" },
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
		},
	},
}
