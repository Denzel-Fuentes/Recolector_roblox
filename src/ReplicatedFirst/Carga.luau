--!strict
--[[
	Carga (ModuleScript de ReplicatedFirst)
	Unica responsabilidad: la pantalla de carga. Tapa el juego desde el primer
	fotograma del cliente hasta que hay algo que jugar y se va con un fundido.
	Solo presentacion: no decide ni cambia nada del juego. La arranca su
	LocalScript hermano (PantallaCarga.client); la logica vive en este modulo
	para que PruebasCliente la consulte ("modulo", "Carga", ...).

	=== Por que existe ===
	El servidor solo crea el personaje cuando el perfil cargo
	(CharacterAutoLoads = false, Services/AparicionHandler). Con el DataStore
	lento el jugador veria hasta 15 s de nada, y justo en el primer minuto,
	el que el tutorial quiere cuidar.

	=== Cuando se quita ===
	Con game:IsLoaded() y ademas una de dos:
	  - el perfil respondio: atributo PerfilListo del Player (nil mientras
	    carga; true si cargo, false si se juega sin guardar, de lo que ya
	    avisa el servidor con una notificacion);
	  - ya hay personaje: AparicionHandler lo crea a los 15 s aunque el
	    perfil no llegue, y entonces el jugador ya puede moverse.
	Red de seguridad: a los SEGUNDOS_TOPE se quita pase lo que pase, para que
	un fallo nunca deje a nadie detras de la pantalla.

	=== Que se ve ===
	Fondo marino con studs; el titulo (CARGA.titulo, en mayusculas como las
	ventanas del Kit; si a los 8 s el perfil no ha respondido,
	CARGA.progreso); el indicador, los cinco contenedores, cada uno de su
	color, saltando por turnos; y un consejo en una pildora blanca que cambia
	cada SEGUNDOS_CONSEJO (CARGA.consejo1, consejo2...). consejo2 nombra la
	tecla F: en tactil y con mando no sale (alli se lanza con otro boton).

	=== Por que asi ===
	- Instancias simples, sin Fusion ni el Kit: esto corre antes de que llegue
	  ReplicatedStorage. El estilo del Kit (contorno marino, FredokaOne y
	  Nunito, esquinas redondeadas, studs) esta copiado aqui.
	- Los colores son COPIA de Config/Paleta con los mismos nombres de token
	  (PALETA, PALETA_TIPO): Paleta vive en ReplicatedStorage y la pantalla
	  tiene que pintarse antes. prueba.estado() los compara con la Paleta de
	  verdad y avisa si alguien cambia uno sin el otro.
	- Ningun require de ReplicatedStorage antes de game:IsLoaded(): un
	  ModuleScript que falla al cargarse (un require sin WaitForChild de un
	  hijo que aun no ha llegado) queda roto para TODO el cliente, HUD
	  incluido; y Idioma fija el idioma al cargarse, asi que tiene que ver ya
	  el atributo IdiomaStudio de ReplicatedStorage. Hasta entonces solo se ve
	  el indicador, que no lleva texto.
	- Precarga (ContentProvider:PreloadAsync) los iconos de Config/Iconos y,
	  si existe, Config/Sonidos, del que toma los ids sin depender de su
	  forma: textos "rbxassetid://N" y enteros de 7 cifras o mas, a cualquier
	  profundidad (volumenes, tonos y tiempos son numeros pequenos). Precarga
	  una ImageLabel (o un Sound) sin padre por id, nunca el texto suelto:
	  con el texto PreloadAsync pide el asset de otro tipo y falla ("Asset
	  type does not match requested type"; en Studio, 22 de 23 iconos el
	  22 oct). No se espera a que termine: nadie se queda en la pantalla por
	  un icono.
	- ResetOnSpawn = false: el personaje aparece con la pantalla puesta, y un
	  ScreenGui que se resetea moriria justo entonces. DisplayOrder 1000: por
	  encima de todo lo del juego (lo mas alto, Celebraciones, va en 25).
	- Movil: IgnoreGuiInset y ScreenInsets None cubren tambien la barra de
	  Roblox y el notch; el contenido va centrado, lejos de los bordes, y el
	  fondo es Active para que los toques no muevan la camara de detras.
	  Escala con la regla de Kit/Escala (alto / 900 entre 0,72 y 1,15; minimo
	  0,8 en tactil). Con mando no hay nada que seleccionar.
	- AutomaticSize solo crece dentro del padre: el consejo (que puede ocupar
	  varias lineas en un telefono) vive en una zona fija bajo el indicador, y
	  el titulo es una caja fija con el texto abajo (detalles en construir).

	=== Pruebas (Studio, por PruebasCliente) ===
	  ("modulo", "Carga", "estado")              que se ve y por que sigue o
	                                              por que se quito
	  ("modulo", "Carga", "mostrar", 10, modo?)  otra pantalla igual durante
	                                              10 s, con el juego cargado;
	                                              modo "progreso" o "indicador"
	  ("modulo", "Carga", "ocultar")             quita antes la de prueba
	Para verla de verdad: ServerStorage:SetAttribute("SimularCargaLenta", 15)
	en Edit, antes de Play (Services/Guardado retrasa la carga del perfil).
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Carga = {}

-- ===========================================================================
-- Estilo: copias de Config/Paleta y Kit/Tema (ver cabecera)
-- ===========================================================================

-- Config/Paleta, con sus mismos nombres de token
local PALETA: { [string]: Color3 } = {
	CABECERA_DEFECTO = Color3.fromRGB(38, 42, 86), -- el fondo, arriba
	UI_TINTA = Color3.fromRGB(27, 29, 58), -- el fondo abajo, contornos y texto del consejo
	UI_PAPEL = Color3.fromRGB(255, 255, 255), -- el titulo y la pildora del consejo
}
-- Config/Paleta.TIPO: los cinco contenedores, en el orden del indicador
local TIPOS = { "Papel", "Plastico", "Metal", "Organico", "General" }
local PALETA_TIPO: { [string]: Color3 } = {
	Papel = Color3.fromRGB(110, 200, 240),
	Plastico = Color3.fromRGB(246, 202, 36),
	Metal = Color3.fromRGB(118, 127, 139),
	Organico = Color3.fromRGB(78, 172, 70),
	General = Color3.fromRGB(44, 110, 216),
}

-- Kit/Tema
local FUENTE_TITULO = Font.new("rbxasset://fonts/families/FredokaOne.json")
local FUENTE_CUERPO = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.SemiBold)
local DEGRADADO = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210))
local RADIO = 12
local GROSOR = 3
local STUDS_BALDOSA = 32
local STUDS_TRANSPARENCIA = 0.9 -- sobre el marino, mas suaves que en las ventanas (0,86)

-- Medidas en px de diseno (las escala el UIScale del ScreenGui)
local ANCHO_MAXIMO = 620
local MARGEN = 24
local CUADRO = 34
local HUECO_CUADROS = 14
local SALTO = 18 -- lo que sube cada cuadro del indicador
local TAMANO_TITULO = 42
local ALTO_TITULO = 150 -- caja fija: hasta tres lineas del titulo
local GROSOR_TITULO = 4 -- Kit/Texto: el contorno es un 10 % del tamano
local TAMANO_CONSEJO = 22
local ALTO_ZONA_CONSEJO = 240 -- donde puede crecer la pildora (unas siete lineas)
local HUECO_TITULO = 14 -- encima del indicador ya queda el aire del salto
local HUECO_CONSEJO = 30

-- Tiempos (s)
local SEGUNDOS_PROGRESO = 8 -- sin perfil a los 8 s: CARGA.progreso en el titulo
local SEGUNDOS_CONSEJO = 6
local SEGUNDOS_FUNDIDO = 0.6
local SEGUNDOS_TOPE = 60 -- red de seguridad (ver cabecera)
local SALIDA_TEXTO = 0.18
local ENTRADA_TEXTO = 0.3

local ORDEN = 1000 -- DisplayOrder

-- Consejos que nombran una tecla del teclado: fuera en tactil y con mando
local CONSEJOS_DE_TECLADO: { [string]: boolean } = {
	consejo2 = true, -- "Mantén F más tiempo..." (con mando es Y; en tactil, un boton)
}

-- ===========================================================================
-- Estado
-- ===========================================================================

type Vista = {
	gui: ScreenGui,
	escala: UIScale,
	fondo: Frame,
	studs: ImageLabel,
	zoom: UIScale,
	titulo: TextLabel,
	contornoTitulo: UIStroke,
	contornoPildora: UIStroke,
	consejo: TextLabel, -- el texto y la pildora a la vez
	conexiones: { RBXScriptConnection },
	pedidos: { [Instance]: string }, -- el ultimo texto pedido por etiqueta
	mostrado: { [Instance]: string }, -- el ultimo texto puesto (lo lee prueba.estado)
	saliendo: boolean,
	destruida: boolean,
	pildoraVisible: boolean,
	conStuds: boolean,
	claveTitulo: string?,
	claveConsejo: string?,
}

type Precarga = {
	total: number,
	hechos: number,
	fallidos: number,
	terminada: boolean,
	sonidos: string,
}

local estado = {
	iniciada = false,
	inicio = 0,
	cargadoEn = nil :: number?, -- segundos desde el inicio
	textosEn = nil :: number?,
	quitadaEn = nil :: number?,
	motivo = nil :: string?,
	tarde = false, -- pasaron SEGUNDOS_PROGRESO
	errores = {} :: { string },
	precarga = { total = 0, hechos = 0, fallidos = 0, terminada = false, sonidos = "sin mirar aun" } :: Precarga,
}

local vistaReal: Vista? = nil
local demo: Vista? = nil -- la de prueba.mostrar

-- Lo que se lee de ReplicatedStorage: una vez y solo tras game:IsLoaded()
local recursos = {
	leidos = false,
	Idioma = nil :: any,
	Iconos = nil :: any,
	Entrada = nil :: any,
}

local function anotar(texto: string)
	table.insert(estado.errores, texto)
	warn("Carga: " .. texto)
end

-- ===========================================================================
-- Modulos del juego (tras game:IsLoaded)
-- ===========================================================================

local function moduloEn(camino: { string }): ModuleScript?
	local actual: Instance? = ReplicatedStorage
	for _, nombre in camino do
		actual = if actual then actual:FindFirstChild(nombre) else nil
	end
	if actual and actual:IsA("ModuleScript") then
		return actual :: ModuleScript
	end
	return nil
end

-- require protegido: un modulo roto no tumba la pantalla y queda anotado
local function requerir(camino: { string }): any
	local modulo = moduloEn(camino)
	if not modulo then
		return nil
	end
	local ok, valor = pcall(require, modulo)
	if not ok then
		anotar(table.concat(camino, ".") .. " no cargo: " .. tostring(valor))
		return nil
	end
	return valor
end

local function leerRecursos()
	if recursos.leidos or not game:IsLoaded() then
		return
	end
	recursos.leidos = true
	recursos.Idioma = requerir({ "Shared", "Utilidades", "Idioma" })
	recursos.Iconos = requerir({ "Shared", "Config", "Iconos" })
	recursos.Entrada = requerir({ "Shared", "Utilidades", "Entrada" })
end

-- Idioma.textos.CARGA (ya traducido), o nil si aun no se puede leer
local function textosCarga(): { [string]: any }?
	local Idioma = recursos.Idioma
	local textos = if typeof(Idioma) == "table" then Idioma.textos else nil
	local carga = if typeof(textos) == "table" then textos.CARGA else nil
	return if typeof(carga) == "table" then carga else nil
end

local function mayusculas(texto: string): string
	local Idioma = recursos.Idioma
	if typeof(Idioma) == "table" and typeof(Idioma.mayusculas) == "function" then
		return Idioma.mayusculas(texto)
	end
	return texto
end

-- Tactil o mando (Utilidades/Entrada, como el HUD)
local function sinTeclado(): boolean
	local Entrada = recursos.Entrada
	if typeof(Entrada) == "table" and typeof(Entrada.plataforma) == "function" then
		local ok, plataforma = pcall(Entrada.plataforma)
		if ok then
			return plataforma ~= "teclado"
		end
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- ===========================================================================
-- Construccion
-- ===========================================================================

local function animar(instancia: Instance, duracion: number, propiedades: { [string]: any }): Tween
	local info = TweenInfo.new(duracion, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(instancia, info, propiedades)
	tween:Play()
	return tween
end

local function esquinas(padre: Instance, radio: number)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, radio)
	esquina.Parent = padre
end

local function contorno(padre: Instance, grosor: number): UIStroke
	local borde = Instance.new("UIStroke")
	borde.Color = PALETA.UI_TINTA
	borde.Thickness = grosor
	borde.Parent = padre
	return borde
end

-- La regla de Kit/Escala, sin Kit: por la altura de la pantalla, con un
-- minimo mayor en tactil para que el texto siga leyendose en el telefono
local function escalaPara(alto: number): number
	local minimo = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then 0.8 else 0.72
	return math.clamp(alto / 900, minimo, 1.15)
end

local function construir(nombre: string, padre: Instance): Vista
	local gui = Instance.new("ScreenGui")
	gui.Name = nombre
	gui.DisplayOrder = ORDEN
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.AutoLocalize = false -- el texto ya llega traducido (Idioma)
	pcall(function()
		-- Tambien el notch y la barra de gestos; si un cliente no tuviera
		-- estas propiedades, basta IgnoreGuiInset
		gui.ScreenInsets = Enum.ScreenInsets.None
		gui.ClipToDeviceSafeArea = false
	end)

	local escala = Instance.new("UIScale")
	escala.Parent = gui

	local fondo = Instance.new("Frame")
	fondo.Name = "Fondo"
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = Color3.new(1, 1, 1) -- el color lo pone el degradado
	fondo.BorderSizePixel = 0
	fondo.Active = true -- que los clics y toques no lleguen al juego de detras
	fondo.Parent = gui
	local degradado = Instance.new("UIGradient")
	degradado.Color = ColorSequence.new(PALETA.CABECERA_DEFECTO, PALETA.UI_TINTA)
	degradado.Rotation = 90
	degradado.Parent = fondo

	local studs = Instance.new("ImageLabel")
	studs.Name = "Studs"
	studs.Size = UDim2.fromScale(1, 1)
	studs.BackgroundTransparency = 1
	studs.ScaleType = Enum.ScaleType.Tile
	studs.TileSize = UDim2.fromOffset(STUDS_BALDOSA, STUDS_BALDOSA)
	studs.ImageTransparency = 1 -- la imagen llega con Config/Iconos (ponerStuds)
	studs.ZIndex = 1
	studs.Parent = fondo

	-- Centro: la franja del indicador. El titulo cuelga por encima y el
	-- consejo por debajo, asi nada se mueve cuando llegan o cambian los textos
	local centro = Instance.new("Frame")
	centro.Name = "Centro"
	centro.AnchorPoint = Vector2.new(0.5, 0.5)
	centro.Position = UDim2.fromScale(0.5, 0.45) -- algo por encima: el consejo pesa mas que el titulo
	centro.Size = UDim2.new(1, -2 * MARGEN, 0, CUADRO + SALTO)
	centro.BackgroundTransparency = 1
	centro.ZIndex = 2 -- siempre encima de los studs, su hermano
	centro.Parent = fondo
	local limite = Instance.new("UISizeConstraint")
	limite.MaxSize = Vector2.new(ANCHO_MAXIMO, math.huge)
	limite.Parent = centro
	local zoom = Instance.new("UIScale")
	zoom.Name = "Zoom" -- crece un poco al fundirse
	zoom.Parent = centro

	local indicador = Instance.new("Frame")
	indicador.Name = "Indicador"
	indicador.AnchorPoint = Vector2.new(0.5, 0.5)
	indicador.Position = UDim2.fromScale(0.5, 0.5)
	indicador.Size = UDim2.fromOffset(#TIPOS * CUADRO + (#TIPOS - 1) * HUECO_CUADROS, CUADRO + SALTO)
	indicador.BackgroundTransparency = 1
	indicador.Parent = centro
	local cuadros: { Frame } = {}
	for i, tipo in TIPOS do
		local cuadro = Instance.new("Frame")
		cuadro.Name = tipo
		cuadro.Size = UDim2.fromOffset(CUADRO, CUADRO)
		cuadro.Position = UDim2.fromOffset((i - 1) * (CUADRO + HUECO_CUADROS), SALTO)
		cuadro.BackgroundColor3 = PALETA_TIPO[tipo]
		cuadro.BorderSizePixel = 0
		cuadro.Parent = indicador
		esquinas(cuadro, 9)
		local brillo = Instance.new("UIGradient")
		brillo.Color = DEGRADADO
		brillo.Rotation = 90
		brillo.Parent = cuadro
		contorno(cuadro, GROSOR)
		table.insert(cuadros, cuadro)
	end

	-- Caja FIJA de hasta tres lineas con el texto abajo: si no cabe en una,
	-- crece hacia arriba sin tocar el indicador. Sin AutomaticSize: cuelga
	-- fuera de Centro y alli no creceria (ver ZonaConsejo)
	local titulo = Instance.new("TextLabel")
	titulo.Name = "Titulo"
	titulo.AnchorPoint = Vector2.new(0.5, 1)
	titulo.Position = UDim2.new(0.5, 0, 0, -HUECO_TITULO)
	titulo.Size = UDim2.new(1, 0, 0, ALTO_TITULO)
	titulo.TextYAlignment = Enum.TextYAlignment.Bottom
	titulo.BackgroundTransparency = 1
	titulo.FontFace = FUENTE_TITULO
	titulo.TextSize = TAMANO_TITULO
	titulo.TextColor3 = PALETA.UI_PAPEL
	titulo.TextWrapped = true
	titulo.AutoLocalize = false
	titulo.Text = ""
	titulo.TextTransparency = 1
	titulo.Parent = centro
	local contornoTitulo = contorno(titulo, GROSOR_TITULO)
	contornoTitulo.Transparency = 1

	-- El consejo es UNA TextLabel que hace de pildora (fondo, borde y
	-- relleno) con AutomaticSize Y, arriba del todo de una ZONA fija y
	-- transparente bajo el indicador. AutomaticSize solo crece dentro de su
	-- padre: colgada de Centro por fuera de sus limites, o dentro de un marco
	-- que tambien era AutomaticSize, se quedaba en una linea y cortaba el
	-- resto en pantallas estrechas (Studio, 22 oct)
	local zona = Instance.new("Frame")
	zona.Name = "ZonaConsejo"
	zona.AnchorPoint = Vector2.new(0.5, 0)
	zona.Position = UDim2.new(0.5, 0, 1, HUECO_CONSEJO)
	zona.Size = UDim2.new(1, 0, 0, ALTO_ZONA_CONSEJO)
	zona.BackgroundTransparency = 1
	zona.Parent = centro
	local consejo = Instance.new("TextLabel")
	consejo.Name = "Consejo"
	consejo.AnchorPoint = Vector2.new(0.5, 0)
	consejo.Position = UDim2.fromScale(0.5, 0)
	consejo.Size = UDim2.fromScale(1, 0)
	consejo.AutomaticSize = Enum.AutomaticSize.Y
	consejo.BackgroundColor3 = PALETA.UI_PAPEL
	consejo.BackgroundTransparency = 1
	consejo.BorderSizePixel = 0
	consejo.FontFace = FUENTE_CUERPO
	consejo.TextSize = TAMANO_CONSEJO
	consejo.TextColor3 = PALETA.UI_TINTA
	consejo.TextWrapped = true
	consejo.AutoLocalize = false
	consejo.Text = ""
	consejo.TextTransparency = 1
	consejo.Parent = zona
	esquinas(consejo, RADIO)
	local contornoPildora = contorno(consejo, GROSOR)
	-- En una TextLabel, Contextual contornearia las letras: aqui es el borde
	contornoPildora.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	contornoPildora.Transparency = 1
	local relleno = Instance.new("UIPadding")
	relleno.PaddingTop = UDim.new(0, 14)
	relleno.PaddingBottom = UDim.new(0, 14)
	relleno.PaddingLeft = UDim.new(0, 20)
	relleno.PaddingRight = UDim.new(0, 20)
	relleno.Parent = consejo

	local vista: Vista = {
		gui = gui,
		escala = escala,
		fondo = fondo,
		studs = studs,
		zoom = zoom,
		titulo = titulo,
		contornoTitulo = contornoTitulo,
		contornoPildora = contornoPildora,
		consejo = consejo,
		conexiones = {},
		pedidos = {},
		mostrado = {},
		saliendo = false,
		destruida = false,
		pildoraVisible = false,
		conStuds = false,
		claveTitulo = nil,
		claveConsejo = nil,
	}

	-- Los cuadros saltan por turnos (una ola de izquierda a derecha) y se
	-- inclinan un poco en el aire. Un solo Heartbeat mientras viva la pantalla.
	local reloj = os.clock()
	table.insert(vista.conexiones, RunService.Heartbeat:Connect(function()
		local t = os.clock() - reloj
		for i, cuadro in cuadros do
			local subida = math.max(0, math.sin(t * 5.6 - (i - 1) * 0.6))
			cuadro.Position = UDim2.fromOffset((i - 1) * (CUADRO + HUECO_CUADROS), SALTO * (1 - subida))
			cuadro.Rotation = subida * (if i % 2 == 0 then 6 else -6)
		end
	end))

	local function reescalar()
		local alto = gui.AbsoluteSize.Y
		if alto > 0 then
			escala.Scale = escalaPara(alto)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(reescalar)
	local camara = workspace.CurrentCamera
	if camara and camara.ViewportSize.Y > 0 then
		escala.Scale = escalaPara(camara.ViewportSize.Y)
	end
	-- Se cuelga al final: si algo de arriba fallara no queda media pantalla
	gui.Parent = padre
	reescalar()
	return vista
end

-- ===========================================================================
-- Textos
-- ===========================================================================

-- Cambia el texto de una etiqueta con un fundido corto (sale el viejo, entra
-- el nuevo); el contorno, si lo tiene, va con ella. Cede: va en su hilo.
local function cambiarTexto(vista: Vista, etiqueta: TextLabel, borde: UIStroke?, texto: string)
	if vista.saliendo or vista.pedidos[etiqueta] == texto then
		return
	end
	vista.pedidos[etiqueta] = texto
	if etiqueta.Text ~= "" then
		animar(etiqueta, SALIDA_TEXTO, { TextTransparency = 1 })
		if borde then
			animar(borde, SALIDA_TEXTO, { Transparency = 1 })
		end
		task.wait(SALIDA_TEXTO)
		if vista.saliendo or vista.pedidos[etiqueta] ~= texto then
			return -- se va la pantalla, o mientras tanto se pidio otro texto
		end
	end
	etiqueta.Text = texto
	vista.mostrado[etiqueta] = texto
	animar(etiqueta, ENTRADA_TEXTO, { TextTransparency = 0 })
	if borde then
		animar(borde, ENTRADA_TEXTO, { Transparency = 0 })
	end
end

local function ponerTitulo(vista: Vista, clave: string)
	local carga = textosCarga()
	local texto = if carga then carga[clave] else nil
	if typeof(texto) ~= "string" then
		return
	end
	vista.claveTitulo = clave
	cambiarTexto(vista, vista.titulo, vista.contornoTitulo, mayusculas(texto))
end

-- El titulo de la pantalla real: CARGA.progreso si pasaron los 8 s y el
-- perfil sigue sin responder; si no, CARGA.titulo
local function actualizarTitulo()
	local vista = vistaReal
	if not vista or vista.saliendo then
		return
	end
	local tarde = estado.tarde and Players.LocalPlayer:GetAttribute("PerfilListo") == nil
	ponerTitulo(vista, if tarde then "progreso" else "titulo")
end

-- consejo1, consejo2... mientras existan en CARGA (si se anaden, salen
-- solos), menos los de teclado cuando se juega sin el
local function clavesConsejos(carga: { [string]: any }): { string }
	local claves = {}
	local fueraTeclado = sinTeclado()
	local i = 1
	while typeof(carga["consejo" .. i]) == "string" do
		local clave = "consejo" .. i
		if not (fueraTeclado and CONSEJOS_DE_TECLADO[clave]) then
			table.insert(claves, clave)
		end
		i += 1
	end
	return claves
end

-- Un consejo al azar, y otro distinto cada SEGUNDOS_CONSEJO
local function rotarConsejos(vista: Vista)
	local azar = Random.new()
	while not vista.saliendo do
		local carga = textosCarga()
		if not carga then
			return
		end
		local opciones = {}
		for _, clave in clavesConsejos(carga) do
			if clave ~= vista.claveConsejo then
				table.insert(opciones, clave)
			end
		end
		if #opciones == 0 then
			if not vista.claveConsejo then
				return -- no hay ninguno que ensenar
			end
		else
			local clave = opciones[azar:NextInteger(1, #opciones)]
			vista.claveConsejo = clave
			if not vista.pildoraVisible then
				vista.pildoraVisible = true
				animar(vista.consejo, ENTRADA_TEXTO, { BackgroundTransparency = 0 })
				animar(vista.contornoPildora, ENTRADA_TEXTO, { Transparency = 0 })
			end
			cambiarTexto(vista, vista.consejo, nil, carga[clave])
		end
		task.wait(SEGUNDOS_CONSEJO)
	end
end

-- La textura de studs del Kit (Config/Iconos "studs"), que entra fundida
-- cuando ya se ha descargado
local function ponerStuds(vista: Vista)
	local Iconos = recursos.Iconos
	local id = if typeof(Iconos) == "table" and typeof(Iconos.id) == "function" then Iconos.id("studs") else nil
	if typeof(id) ~= "string" then
		return
	end
	vista.studs.Image = id
	vista.conStuds = true
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ vista.studs })
		end)
		if not vista.saliendo then
			animar(vista.studs, 0.8, { ImageTransparency = STUDS_TRANSPARENCIA })
		end
	end)
end

-- ===========================================================================
-- Salida
-- ===========================================================================

local function desvanecer(vista: Vista)
	if vista.saliendo then
		return
	end
	vista.saliendo = true
	vista.fondo.Active = false -- el juego ya responde durante el fundido
	local ok, err = pcall(function()
		for _, d in vista.gui:GetDescendants() do
			if d:IsA("TextLabel") then
				animar(d, SEGUNDOS_FUNDIDO, { TextTransparency = 1, BackgroundTransparency = 1 })
			elseif d:IsA("ImageLabel") then
				animar(d, SEGUNDOS_FUNDIDO, { ImageTransparency = 1, BackgroundTransparency = 1 })
			elseif d:IsA("Frame") then
				animar(d, SEGUNDOS_FUNDIDO, { BackgroundTransparency = 1 })
			elseif d:IsA("UIStroke") then
				animar(d, SEGUNDOS_FUNDIDO, { Transparency = 1 })
			end
		end
		animar(vista.zoom, SEGUNDOS_FUNDIDO, { Scale = 1.06 })
	end)
	if not ok then
		anotar("fundido: " .. tostring(err))
	end
	task.delay(if ok then SEGUNDOS_FUNDIDO else 0, function()
		for _, conexion in vista.conexiones do
			conexion:Disconnect()
		end
		table.clear(vista.conexiones)
		vista.destruida = true
		vista.gui:Destroy()
	end)
end

local function quitar(motivo: string)
	local vista = vistaReal
	if not vista or estado.quitadaEn then
		return
	end
	estado.quitadaEn = os.clock() - estado.inicio
	estado.motivo = motivo
	desvanecer(vista)
end

-- La regla de la cabecera ("Cuando se quita")
local function comprobar()
	if estado.quitadaEn or not game:IsLoaded() then
		return
	end
	local jugador = Players.LocalPlayer
	local listo = jugador:GetAttribute("PerfilListo")
	if listo == true then
		quitar("PerfilListo = true (el perfil cargo)")
	elseif listo ~= nil then
		quitar("PerfilListo = " .. tostring(listo) .. " (se juega sin guardar; el servidor ya avisa)")
	elseif jugador.Character then
		quitar("ya hay personaje (PerfilListo sin valor: el servidor lo creo sin perfil)")
	end
end

-- ===========================================================================
-- Precarga
-- ===========================================================================

local function idsIconos(lista: { string }, vistos: { [string]: boolean })
	local Iconos = recursos.Iconos
	if typeof(Iconos) ~= "table" or typeof(Iconos.IMAGENES) ~= "table" or typeof(Iconos.id) ~= "function" then
		return
	end
	for clave in Iconos.IMAGENES do
		local id = Iconos.id(clave)
		if typeof(id) == "string" and not vistos[id] then
			vistos[id] = true
			table.insert(lista, id)
		end
	end
end

-- Ids de Config/Sonidos sin depender de su forma (ver cabecera)
local function idsSonidos(valor: any, lista: { string }, vistos: { [string]: boolean }, profundidad: number)
	if profundidad > 5 or typeof(valor) ~= "table" then
		return
	end
	for _, v in valor do
		local id: string? = nil
		if typeof(v) == "string" and string.match(v, "^rbxassetid://%d+$") then
			id = v
		elseif typeof(v) == "number" and v >= 1e6 and v == math.floor(v) then
			id = string.format("rbxassetid://%d", v)
		elseif typeof(v) == "table" then
			idsSonidos(v, lista, vistos, profundidad + 1)
		end
		if id and not vistos[id] then
			vistos[id] = true
			table.insert(lista, id)
		end
	end
end

-- Por instancias, no por texto (ver cabecera): una ImageLabel o un Sound
-- sin padre por id, que se destruyen al acabar; lo que queda es la cache de
-- ContentProvider, que es lo que aprovechan el HUD y los sonidos
local function precargarLista(lista: { string }, clase: "ImageLabel" | "Sound")
	if #lista == 0 then
		return
	end
	local cuenta = estado.precarga
	cuenta.total += #lista
	local instancias: { Instance } = {}
	for _, id in lista do
		if clase == "Sound" then
			local sonido = Instance.new("Sound")
			sonido.SoundId = id
			table.insert(instancias, sonido)
		else
			local imagen = Instance.new("ImageLabel")
			imagen.Image = id
			table.insert(instancias, imagen)
		end
	end
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(instancias, function(_contenido: string, resultado: Enum.AssetFetchStatus)
			if resultado == Enum.AssetFetchStatus.Success then
				cuenta.hechos += 1
			else
				cuenta.fallidos += 1
			end
		end)
	end)
	for _, instancia in instancias do
		instancia:Destroy()
	end
	if not ok then
		anotar("precarga: " .. tostring(err))
	end
end

local function precargar()
	local iconos, sonidos, vistos = {}, {}, {}
	idsIconos(iconos, vistos)
	if moduloEn({ "Shared", "Config", "Sonidos" }) then
		local Sonidos = requerir({ "Shared", "Config", "Sonidos" })
		idsSonidos(Sonidos, sonidos, vistos, 1)
		estado.precarga.sonidos = if Sonidos == nil
			then "Config/Sonidos no cargo"
			else string.format("Config/Sonidos: %d ids", #sonidos)
	else
		estado.precarga.sonidos = "sin Config/Sonidos"
	end
	-- Primero los iconos: son pocos y el HUD los quiere en cuanto se vea
	precargarLista(iconos, "ImageLabel")
	precargarLista(sonidos, "Sound")
	estado.precarga.terminada = true
end

-- ===========================================================================
-- Arranque
-- ===========================================================================

-- Lo llama PantallaCarga.client, lo primero que corre en el cliente
function Carga.iniciar()
	if estado.iniciada then
		return
	end
	estado.iniciada = true
	estado.inicio = os.clock()
	local jugador = Players.LocalPlayer

	local ok, err = pcall(function()
		vistaReal = construir("PantallaCarga", jugador:WaitForChild("PlayerGui"))
	end)
	local vista = vistaReal
	if not ok or not vista then
		-- Sin pantalla propia se queda la de Roblox, que se va sola al cargar
		anotar("no se pudo montar la pantalla: " .. tostring(err))
		return
	end
	ReplicatedFirst:RemoveDefaultLoadingScreen()
	task.delay(SEGUNDOS_TOPE, quitar, string.format("tope de %d s (red de seguridad)", SEGUNDOS_TOPE))

	-- Pueden llegar antes que game.Loaded: comprobar no hace nada hasta
	-- entonces, y se repite al cargar el juego
	table.insert(vista.conexiones, jugador:GetAttributeChangedSignal("PerfilListo"):Connect(comprobar))
	table.insert(vista.conexiones, jugador.CharacterAdded:Connect(comprobar))
	task.delay(SEGUNDOS_PROGRESO, function()
		estado.tarde = true
		actualizarTitulo()
	end)

	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		estado.cargadoEn = os.clock() - estado.inicio
		-- Antes que cualquier require: si algo de abajo se colgara, la
		-- pantalla ya sabria irse sola
		comprobar()
		leerRecursos()
		task.spawn(precargar) -- tambien si ya se va: el HUD lo agradece igual
		if vista.saliendo or not textosCarga() then
			return
		end
		estado.textosEn = os.clock() - estado.inicio
		ponerStuds(vista)
		task.spawn(rotarConsejos, vista)
		actualizarTitulo()
	end)
end

-- ===========================================================================
-- Pruebas (Studio, por PruebasCliente: ver cabecera)
-- ===========================================================================

local prueba = {}

local function segundos(s: number?): string
	return if s then string.format("%.1f s", s) else "-"
end

local function mismoColor(a: Color3, b: any): boolean
	return typeof(b) == "Color3"
		and math.round(a.R * 255) == math.round(b.R * 255)
		and math.round(a.G * 255) == math.round(b.G * 255)
		and math.round(a.B * 255) == math.round(b.B * 255)
end

-- Las copias de arriba contra la Paleta de verdad
local function compararPaleta(): string
	local Paleta = requerir({ "Shared", "Config", "Paleta" })
	if typeof(Paleta) ~= "table" then
		return "sin Config/Paleta para comparar los colores"
	end
	local distintos = {}
	for token, color in PALETA do
		if not mismoColor(color, Paleta[token]) then
			table.insert(distintos, token)
		end
	end
	local tipos = if typeof(Paleta.TIPO) == "table" then Paleta.TIPO else {}
	for _, tipo in TIPOS do
		if not mismoColor(PALETA_TIPO[tipo], tipos[tipo]) then
			table.insert(distintos, "TIPO." .. tipo)
		end
	end
	table.sort(distintos)
	if #distintos == 0 then
		return "colores iguales que Config/Paleta"
	end
	return "colores DISTINTOS de Config/Paleta (copiarlos aqui): " .. table.concat(distintos, ", ")
end

-- Lo ultimo que se puso en la vista (vale tambien cuando ya se destruyo)
local function describirVista(vista: Vista): string
	local partes = {}
	local titulo = vista.mostrado[vista.titulo]
	if titulo then
		table.insert(partes, string.format("titulo \"%s\" (CARGA.%s)", titulo, vista.claveTitulo or "?"))
	end
	local consejo = vista.mostrado[vista.consejo]
	if consejo then
		table.insert(partes, string.format("%s \"%s\"", vista.claveConsejo or "consejo", consejo))
	end
	if #partes == 0 then
		table.insert(partes, "solo el indicador (aun sin textos)")
	else
		table.insert(partes, "indicador")
	end
	table.insert(partes, if vista.conStuds then "studs" else "sin studs")
	return table.concat(partes, " | ")
end

local function describirPantalla(vista: Vista): string
	local gui = vista.gui
	local insets = "?"
	pcall(function()
		insets = tostring(gui.ScreenInsets)
	end)
	return string.format(
		"pantalla %dx%d, escala %.2f, DisplayOrder %d, IgnoreGuiInset %s, ScreenInsets %s, ResetOnSpawn %s",
		math.round(gui.AbsoluteSize.X),
		math.round(gui.AbsoluteSize.Y),
		vista.escala.Scale,
		gui.DisplayOrder,
		tostring(gui.IgnoreGuiInset),
		insets,
		tostring(gui.ResetOnSpawn)
	)
end

-- Que se ve, por que sigue (o por que se quito) y lo que hay detras
function prueba.estado(): string
	if not estado.iniciada then
		return "Carga sin iniciar: no ha corrido ReplicatedFirst.PantallaCarga"
	end
	local jugador = Players.LocalPlayer
	local listo = jugador:GetAttribute("PerfilListo")
	local vista = vistaReal
	local lineas = {}
	if not vista then
		table.insert(lineas, "SIN PANTALLA PROPIA (no se pudo montar): queda la de Roblox")
	elseif estado.quitadaEn then
		table.insert(lineas, string.format("QUITADA a los %s (%s): %s",
			segundos(estado.quitadaEn),
			if vista.destruida then "ya no existe" else "fundiendose",
			estado.motivo or "?"))
	else
		local porque = if game:IsLoaded()
			then "espera al perfil (PerfilListo sin valor y sin personaje)"
			else "espera a game:IsLoaded()"
		table.insert(lineas, string.format("VISIBLE desde hace %s: %s; tope a los %d s",
			segundos(os.clock() - estado.inicio), porque, SEGUNDOS_TOPE))
	end
	local Idioma = recursos.Idioma
	table.insert(lineas, string.format("  juego cargado a los %s | textos a los %s (idioma %s) | PerfilListo %s | personaje %s",
		segundos(estado.cargadoEn),
		segundos(estado.textosEn),
		if typeof(Idioma) == "table" then tostring(Idioma.codigo) else "-",
		tostring(listo),
		if jugador.Character then "si" else "no"))
	if vista then
		local quitadaEn = estado.quitadaEn
		table.insert(lineas, "  se ve: " .. describirVista(vista))
		table.insert(lineas, string.format("  CARGA.progreso a los %d s: %s", SEGUNDOS_PROGRESO,
			if vista.claveTitulo == "progreso" then "puesto"
				elseif quitadaEn and quitadaEn < SEGUNDOS_PROGRESO then "no hizo falta (se quito antes)"
				elseif estado.tarde then "no puesto (el perfil ya habia respondido, o no hay textos)"
				else "aun no"))
		if not vista.destruida then
			table.insert(lineas, "  " .. describirPantalla(vista))
		end
	end
	local p = estado.precarga
	table.insert(lineas, string.format("  precarga: %d de %d (%d fallidos%s) | %s",
		p.hechos, p.total, p.fallidos, if p.terminada then ", terminada" else "", p.sonidos))
	if recursos.leidos then
		table.insert(lineas, "  " .. compararPaleta())
	end
	if demo then
		table.insert(lineas, "  de prueba: " .. describirVista(demo))
	end
	table.insert(lineas, "  errores: " .. (if #estado.errores == 0 then "ninguno" else table.concat(estado.errores, " / ")))
	return table.concat(lineas, "\n")
end

-- Otra pantalla igual durante `duracion` s, para capturarla con el juego ya
-- cargado. modo: "progreso" (el titulo de los 8 s) o "indicador" (como se
-- ve antes de que lleguen los textos)
function prueba.mostrar(duracion: any, modo: any): string
	if not RunService:IsStudio() then
		return "solo en Studio"
	end
	leerRecursos()
	if demo then
		desvanecer(demo)
		demo = nil
	end
	local vista = construir("PantallaCargaPrueba", Players.LocalPlayer:WaitForChild("PlayerGui"))
	demo = vista
	local tiempo = tonumber(duracion) or 10
	if modo ~= "indicador" then
		ponerStuds(vista)
		task.spawn(ponerTitulo, vista, if modo == "progreso" then "progreso" else "titulo")
		task.spawn(rotarConsejos, vista)
	end
	task.delay(tiempo, function()
		if demo == vista then
			demo = nil
			desvanecer(vista)
		end
	end)
	return string.format("%s durante %.1f s (modo %s); textos %s",
		vista.gui.Name, tiempo, tostring(modo or "titulo"), if textosCarga() then "si" else "no (sin Idioma)")
end

function prueba.ocultar(): string
	local vista = demo
	if not vista then
		return "no hay pantalla de prueba"
	end
	demo = nil
	desvanecer(vista)
	return vista.gui.Name .. " fundiendose"
end

Carga.prueba = prueba

return Carga
