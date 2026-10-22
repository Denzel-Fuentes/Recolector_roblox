--!strict
--[[
	Traducciones/pt
	El copy de Textos en portugues (de Brasil, el de casi todo el publico de
	Roblox que habla portugues): misma forma, mismas claves y los mismos
	{marcadores} (la prueba "idioma" lo comprueba). Lo que falte aqui sale en
	espanol. DEF traduce los nombres de las definiciones de Config por id.

	Glosario: bolsa = saco, contenedor = lixeira, monton = pilha, patio =
	lixao, pedido = pedido, mejora = melhoria, insignia = emblema (asi lo
	llama Roblox en pt-br), racha = sequencia, tesoro = tesouro, encestar =
	acertar. "Rebirth" y "Turbo" no se traducen.
	Bolsa llena = saco LOTADO, llenar la bolsa = LOTAR o saco (22 oct): en
	Brasil "encher o saco" es fastidiar y "estar de saco cheio", estar harto;
	con "saco" como termino del juego, nunca "cheio" ni "encher".
]]

return {
	HUD = {
		bolsa = "Saco",
		bolsaLlena = "Saco lotado! Jogue numa lixeira",
		tienda = "Loja",
		rebirth = "Rebirth",
		pedidos = "Pedidos",
		camara = "Câmera",
		mantenerLanzar = "SEGURE PARA JOGAR",
		tocarLanzar = "SEGURE",
		mantenerRecoger = "SEGURE PARA PEGAR",
		tocarRecoger = "MIRE E SEGURE PEGAR",
		botonRecoger = "PEGAR",
		clic = "CLIQUE",
		fuerza = "Força",
		bonusAqui = "+{pct} %",
		bolsaLlenaBarra = "LOTADO!",
	},

	MUNDO = {
		contenedorGeneral = "GERAL · TUDO",
		contenedorTipo = "{tipo} · x2",
		placaGeneral = "♻ {tipo}",
		contenedorCandado = "REBIRTH {n}",
		chatarra = "RECICLADORA",
		tendero = "Reciclador",
		patio = "Lixão ↑",
		barrera = "Rebirth {n} · {zona}",
	},

	ZONAS = {
		patio = "Lixão",
		metal = "Zona de metal",
		organico = "Zona orgânica",
	},

	TIPOS = {
		Papel = "Papel",
		Plastico = "Plástico",
		Metal = "Metal",
		Organico = "Orgânico",
		General = "Geral",
	},

	CONTENEDOR = {
		General = "geral",
		Papel = "do papel",
		Plastico = "do plástico",
		Metal = "do metal",
		Organico = "do orgânico",
	},

	PATIO = {
		excavar = "Cavar",
		montonAgotado = "Pilha esgotada",
		reciclar = "Reciclar saco",
		tienda = "Loja",
		bolsaVacia = "Você não tem nada para reciclar",
		contenedorBloqueado = "Abre no Rebirth {n}",
		nadaQueLanzar = "O saco está vazio",
		bolsaDe = "Saco de {dueno}",
		bolsaAjena = "É de {dueno}: livre em {s} s",
		bolsaTeLaQuitaron = "{quien} pegou seu saco",
		temporizadorBolsa = "{s}s",
		bolsaLibre = "LIVRE!",
		demasiadoCerca = "Afaste-se um pouco para jogar",
		sinDinero = "Você não tem dinheiro suficiente",
		figurinaEncontrada = "Figurinha encontrada: {nombre}!",
		patioLleno = "Lixão cheio: espere um pouco",
		montonPendiente = "Termine sua pilha primeiro",
		monton = "Pilha de lixo",
		montonRico = "Pilha com muito {material}",
		materialBloqueado = "{material}: Rebirth {n}",
		prioridad = "Espere {s} s: é de {dueno}",
		-- P3, 22 oct
		bolsaNoLlena = "O saco precisa estar lotado para ser jogado",
		bolsaViejaReciclada = "Sacos demais no chão: o mais antigo foi reciclado sozinho por {dinero}, sem bônus",
	},

	CELEBRACION = {
		acierto = "ACERTOU!",
		entrega = "RECICLADO!",
		dinero = "+${dinero}",
		distancia = "{distancia} m",
		bonusDistancia = "+{pct} % distância",
		racha = "Sequência ×{n}",
		separadas = "{n} bem separadas ×2",
		malSeparadas = "{n} na lixeira errada",
		mas = "+{n}",
		billete = "+${dinero}",
		tesoro = "TESOURO!",
	},

	FEED = {
		montonGrande = "{jugador} abriu uma pilha grande",
		repoblacion = "Chegou mais lixo no lixão!",
		rebirth = "{jugador} fez o Rebirth {n}!",
		recordServidor = "Recorde do servidor! {jugador} acertou de {distancia} m",
	},

	RECORD = {
		titulo = "NOVO RECORDE!",
		distancia = "{distancia} m",
		personal = "Seu melhor arremesso",
		servidor = "O melhor do servidor!",
	},

	RANKING = {
		titulo = {
			dinero = "Dinheiro ganho",
			racha = "Maior sequência",
			aciertos = "Sacos acertados",
		},
		historico = "Geral",
		semanal = "Esta semana",
		tu = "Você: #{pos} · {valor}",
		tuFuera = "Você: fora do top {n} · {valor}",
		tuSinValor = "Você: ainda sem posição",
		cargando = "Carregando…",
		noDisponible = "Ranking indisponível",
		vacio = "Ninguém ainda",
	},

	REBIRTH = {
		titulo = "Rebirth",
		siguiente = "Rebirth {n}",
		tienes = "Rebirths: {n} · dinheiro {mult}",
		requisitoDinero = "Tenha {dinero} em mãos",
		requisitoMejoras = "As 4 melhorias no máximo",
		mejora = "{nombre} {n}/10",
		premio = "Seu dinheiro passa a {mult}",
		desbloquea = {
			metal = "Desbloqueia o lixo de metal",
			organico = "Desbloqueia o lixo orgânico",
			bolsaPlateada = "Dá o Saco prateado",
			insignia = "Só multiplicador e emblema",
		},
		reinicia = "O dinheiro e as melhorias são zerados",
		conserva = "Você mantém as zonas abertas, os recordes, os emblemas e os passes",
		renacer = "Renascer",
		hecho = "Rebirth {n}! Seu dinheiro agora vale {mult}",
		faltanMejoras = "Antes de renascer, leve as 4 melhorias ao máximo",
		faltaDinero = "Faltam {dinero} para renascer",
	},

	TIENDA = {
		titulo = "Cabana de reciclagem",
		mejoras = "Melhorias",
		pases = "Passes",
		estilo = "Estilo",
		proximamente = "Em breve",
		loTienes = "É seu",
		dePago = "Passe de Robux",
		conRebirth = "Prêmio do Rebirth {n}",
		maximo = "MÁXIMO",
		comprado = "Comprado",
		equipar = "Equipar",
		quitar = "Tirar",
		robux = "{precio} Robux",
		sinIds = "Produto ainda não disponível",
		mejoraComprada = "{nombre} → nível {nivel}",
	},

	LOGROS = {
		desbloqueado = "Emblema conquistado!",
	},

	PEDIDOS = {
		titulo = "Pedidos",
		pestanaPedidos = "Pedidos do dia",
		pestanaInsignias = "Emblemas",
		aciertos = "Acerte {objetivo} sacos",
		racha = "Faça uma sequência de {objetivo}",
		lejos = "Acerte {objetivo} de {parametro} m ou mais",
		piezas = "Recicle {objetivo} peças",
		separadas = "Recicle {objetivo} peças na lixeira da sua cor",
		material = "Recicle {objetivo} de {parametro}",
		tesoros = "Encontre {objetivo} tesouros",
		bolsasLlenas = "Recicle {objetivo} sacos lotados",
		hecho = "Feito!",
		premioDia = "Complete os 3: {minutos} min de dinheiro x2",
		premioCobrado = "Turbo do dia conquistado",
		cerrados = "Os pedidos abrem quando você comprar sua primeira melhoria",
		nuevos = "Pedidos novos todo dia",
		insigniasConseguidas = "{n}/{total} conquistados",
	},

	PEDIDOS_HUD = {
		aciertos = "Acerte",
		racha = "Sequência",
		lejos = "De {parametro} m",
		piezas = "Recicle",
		separadas = "Separe",
		material = "{parametro}",
		tesoros = "Tesouros",
		bolsasLlenas = "Sacos lotados",
		formato = "{etiqueta} {n}/{total}",
	},

	PEDIDOS_AVISOS = {
		cumplido = "Pedido cumprido! +${dinero}",
		todos = "Os 3 pedidos do dia! Dinheiro x2 por {minutos} min",
	},

	TURBO = {
		activo = "x2 {tiempo}",
	},

	NOTIFICACIONES = {
		bienvenida = "Bem-vindo ao Recíclatas! Cave uma pilha do lixão e jogue o saco numa lixeira. Se separar por cores, paga o dobro.",
		perfilNoCargado = "Não foi possível carregar seu progresso. Esta sessão não será salva.",
		compraRobux = "Compra concluída: {nombre}",
		cintaEncontrada = "Fita encontrada: {nombre}!",
		-- P1, 22 oct
		sesionEnOtroServidor = "Sua partida foi aberta em outro servidor. Entre de novo para continuar jogando.",
		-- C2, 22 oct
		versionNueva = "Há uma versão nova do jogo: entre de novo para continuar jogando.",
		progresoRecuperado = "Seu progresso salvo voltou. O que você jogou enquanto não dava para salvar não fica guardado.",
	},

	MATERIALES = {
		Metal = "metal",
		Plastico = "plástico",
		Papel = "papel",
		Organico = "orgânico",
		Mixto = "tudo",
	},

	TUTORIAL = {
		paso = "Passo {n}/{total}",
		paso1 = "Vá até o lixão",
		paso2 = "Cave uma pilha: chegue perto e segure Cavar",
		paso3 = "Pegue lixo até lotar o saco",
		paso4 = "Jogue o saco na lixeira azul: segure Jogar e solte",
		paso5 = "Compre uma melhoria na Loja",
		paso6 = "Pegue lixo de uma só cor e jogue na lixeira dela: paga o dobro",
		paso7 = "Cumpra um pedido da recicladora",
		paso8 = "Meta: as 4 melhorias no máximo e {dinero} para o Rebirth 1",
		completado = "Tutorial concluído! Agora você é um reciclador",
	},

	-- C2, 22 oct
	SONIDO = {
		boton = "Som",
		musica = "Música",
		efectos = "Efeitos",
		activado = "Ligado",
		desactivado = "Desligado",
	},

	-- C2, 22 oct
	CARGA = {
		titulo = "Carregando…",
		progreso = "Carregando seu progresso…",
		consejo1 = "Separe o lixo por cores: na lixeira da sua cor paga o dobro.",
		consejo2 = "Segure F por mais tempo para jogar mais longe.",
		consejo3 = "Todo dia tem pedidos novos na recicladora.",
		consejo4 = "Volte todo dia para pegar sua recompensa diária.",
		consejo5 = "Os rebirths liberam novos tipos de lixo.",
	},

	DEF = {
		Mejoras = {
			Bolsa = { nombre = "Saco", descripcion = "Cabe mais lixo no saco" },
			Alcance = { nombre = "Alcance", descripcion = "Pegue de mais longe" },
			Velocidad = { nombre = "Velocidade", descripcion = "Corra mais rápido" },
			Brazo = { nombre = "Braço", descripcion = "Jogue o saco mais longe" },
		},
		Pases = {
			DineroX2 = { nombre = "Dinheiro x2", descripcion = "Tudo o que você recicla paga o dobro, para sempre" },
			BolsaXL = { nombre = "Saco XL", descripcion = "10 espaços a mais no saco, para sempre" },
			EstelaArcoiris = { nombre = "Rastro arco-íris", descripcion = "Seu saco deixa um arco-íris ao ser jogado" },
			BolsaDorada = { nombre = "Saco dourado", descripcion = "Um saco de ouro para exibir" },
		},
		Productos = {
			Turbo15 = { nombre = "Turbo 15 min", descripcion = "Dinheiro x2 por 15 minutos (soma ao que você ainda tiver)" },
		},
		Bolsas = {
			Plateada = { nombre = "Saco prateado" },
			Dorada = { nombre = "Saco dourado" },
		},
		Estelas = {
			Arcoiris = { nombre = "Rastro arco-íris" },
		},
		Insignias = {
			primerReciclaje = { nombre = "Primeira reciclagem", descripcion = "Recicle seu primeiro saco" },
			primerAcierto = { nombre = "Acertou!", descripcion = "Acerte seu primeiro saco" },
			tiro30 = { nombre = "Braço forte", descripcion = "Acerte de 30 m" },
			tiro60 = { nombre = "Atirador de elite", descripcion = "Acerte de 60 m" },
			racha5 = { nombre = "Embalado", descripcion = "Acerte 5 seguidas" },
			racha10 = { nombre = "Imparável", descripcion = "Acerte 10 seguidas" },
			piezas1000 = { nombre = "Reciclador", descripcion = "Recicle 1.000 peças" },
			piezas10000 = { nombre = "Grande reciclador", descripcion = "Recicle 10.000 peças" },
			separadas500 = { nombre = "Separa bem", descripcion = "Recicle 500 peças na lixeira da sua cor" },
			primerTesoro = { nombre = "Caça-tesouros", descripcion = "Encontre um tesouro no lixo" },
			dinero10k = { nombre = "Poupador", descripcion = "Ganhe $10.000 no total" },
			dinero1M = { nombre = "Milionário", descripcion = "Ganhe $1.000.000 no total" },
			mejoraMax = { nombre = "No talo", descripcion = "Leve uma melhoria ao máximo" },
			todasMax = { nombre = "Equipe completa", descripcion = "As 4 melhorias no máximo" },
			rebirth1 = { nombre = "Renascido", descripcion = "Faça seu primeiro Rebirth" },
			rebirth3 = { nombre = "Veterano", descripcion = "Chegue ao Rebirth 3" },
		},
	},
}
