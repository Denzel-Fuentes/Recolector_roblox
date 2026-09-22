--!nonstrict
--[[
	ConstructorMundo
	Construye TODA la geometria del juego bajo workspace.Mundo a partir de la
	tabla LAYOUT de abajo, en dos capas:

	  1. El ESQUELETO funcional (lo de siempre): suelo, ranuras de monton,
	     caseta, contenedor, maquina, plaza, parcelas, limites. Todo lo que el
	     runtime necesita encontrar lleva TAG de CollectionService o ATRIBUTO,
	     nunca se busca por nombre.
	  2. El ARTE (pasada de color, referencia KOTAMON): ArteMundo viste el
	     esqueleto con piezas `SoloDecorado` sin colision (cabana de madera,
	     trituradora, vallas, camion, postes con cables...) y pinta con
	     materiales las cajas funcionales que se ven. Las que quedan tapadas se
	     vuelven invisibles pero siguen colisionando y llevando sus prompts.
	     Ninguna prueba ni servicio distingue un mundo vestido de uno desnudo.

	Se usa de dos formas:
	  1. Horneado (la normal): herramientas/construir-mundo.luau lo llama desde la
	     barra de comandos / execute_luau sobre el DataModel Edit. La geometria
	     queda GUARDADA en el place y se puede retocar a mano en Studio.
	  2. Fallback: SetupMundo lo llama al arrancar si no existe workspace.Mundo,
	     para que un place recien hecho con rojo build sea jugable. Avisa por
	     consola, porque lo generado en runtime desaparece al parar.

	Materiales generados por IA (MaterialService) y mallas (ServerStorage.Arte)
	viven en el place y se usan por nombre; sin ellos el mundo se ve igual de
	entero, solo con materiales base y props de partes.

	    RanuraMonton      marcador donde Botin instancia un monton (attr Tamano)
	    FigurinaFija      marcador de figurina escondida (attr FigurinaId)
	    Contenedor        el contenedor de reciclaje (hijo ZonaAcierto = punteria)
	    MaquinaRefrescos  la maquina de refrescos
	    Parcela           cada base (attr IndiceParcela; hijos con attr Mueble,
	                      marcadores SlotEstanteria y Pedestal con attr Indice)
	    Limite            muros invisibles del borde del mapa
	    SoloDecorado      arte que no hace nada
	    Mundo.Manual      carpeta que el horneado NUNCA borra: lo que el
	                      usuario edita a mano en Studio va ahi

	Las partes de una parcela que cambian con una skin llevan attr Pintable
	("losa" | "mueble" | "borde").

	Plano v3 (N = z negativa, E = x positiva). La valla de madera del
	vertedero rodea TODO el mapa (antes solo el patio); el patio no tiene
	muros, es la explanada de cesped claro con los montones. 6 parcelas = 6
	jugadores por servidor, en columna al oeste:

	    +-----------------------------------------------+  z = -124
	    | [P1]  |  +---------------------------+         |
	    | [P2]  |  |     PATIO 200 x 200       |         |
	    | [P3]  c  |   12 ranuras de monton    |         |
	    | [P4]  a  +---------------------------+         |  z = 100
	    | [P5]  l  ====== calle + PLAZA (spawn) ======   |
	    | [P6]  l  | RECICLADORA: caseta al centro     | |  z = 140..186
	    |       e  | (mira al norte), maquina, conten. | |
	    +-----------------------------------------------+  z = 202
	   x = -196   -132     -100                 100    124
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Textos = require(Config:WaitForChild("Textos"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))
local ArteMundo = require(script.Parent:WaitForChild("ArteMundo"))

local M = Paleta.MUNDO
local V = Paleta.VARIANTES

local ConstructorMundo = {}
ConstructorMundo.VERSION = 3

-- ===========================================================================
-- LAYOUT
-- ===========================================================================

local LAYOUT = {
	-- El patio es un cuadrado centrado en el origen: Patio.posicionEnPatio lo
	-- da por hecho (|x|, |z| < PATIO_LADO / 2), asi que el patio no se mueve
	-- y el resto del mapa se coloca a su alrededor.
	PATIO_LADO = GameConfig.PATIO_LADO,
	-- Rejilla 4x3 = 12 ranuras. Los montones son montanas de hasta 14 studs de
	-- radio: 50 studs entre columnas y 60 entre filas dejan pasillos.
	RANURA_X = { -75, -25, 25, 75 },
	RANURA_Z = { -60, 0, 60 },
	RANURA_JITTER = 5,
	CAMINO_ANCHO = 10,
	-- Al sur del patio, la calle con la plaza del spawn (pavimento pegado al
	-- borde del patio) y detras el lote de tierra de la recicladora, del
	-- mismo ancho que el patio, con la caseta en el centro mirando al norte
	PLAZA_ANCHO = 40,
	PLAZA_FONDO = 38,
	SPAWN_Z = 121,
	LOTE_NORTE = 140,
	LOTE_SUR = 186,
	CASETA_Z = 158,
	-- 6 parcelas en columna al oeste, de norte a sur, mirando a la calle y al
	-- patio; la calle de tierra baja entre ellas y el patio
	PARCELA_LADO = 36,
	PARCELA_X = -150,
	PARCELA_Z = { -87, -37, 13, 63, 113, 163 },
	CALLE_X = -116,
	CALLE_ANCHO = 12,
	-- Limite del mapa: rectangulo con muro invisible alto y la valla de
	-- madera del vertedero por dentro
	LIMITE = { oeste = -196, este = 124, norte = -124, sur = 202 },
	LIMITE_ALTURA = 60,
	-- 10 studs: un personaje salta ~7,5, asi que la valla no se salta aunque
	-- alguien apague el muro invisible
	VALLA_ALTURA = 10,
	VALLA_MARGEN = 1.6,
}

-- ===========================================================================
-- Helpers de construccion
-- ===========================================================================

local function parte(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = props.Material or Enum.Material.SmoothPlastic
	if props.Variante then
		p.MaterialVariant = props.Variante
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	p.Name = props.Name or "Parte"
	p.Size = props.Size or Vector3.new(1, 1, 1)
	if props.CFrame then
		p.CFrame = props.CFrame
	elseif props.Position then
		p.CFrame = CFrame.new(props.Position)
	end
	p.Color = props.Color or Paleta.MUEBLE
	if props.Shape then
		p.Shape = props.Shape
	end
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	if props.CanCollide ~= nil then
		p.CanCollide = props.CanCollide
	end
	if props.CanQuery ~= nil then
		p.CanQuery = props.CanQuery
	end
	if props.CanTouch ~= nil then
		p.CanTouch = props.CanTouch
	end
	if props.Reflectance then
		p.Reflectance = props.Reflectance
	end
	p.Parent = props.Parent
	return p
end

local function cuna(props)
	-- WedgePart con los mismos props que parte()
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Material = props.Material or Enum.Material.SmoothPlastic
	if props.Variante then
		w.MaterialVariant = props.Variante
	end
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Name = props.Name or "Cuna"
	w.Size = props.Size or Vector3.new(1, 1, 1)
	w.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	w.Color = props.Color or Paleta.MUEBLE
	w.Parent = props.Parent
	return w
end

local function modelo(nombre, padre)
	local m = Instance.new("Model")
	m.Name = nombre
	m.Parent = padre
	return m
end

local function carpeta(nombre, padre)
	local f = Instance.new("Folder")
	f.Name = nombre
	f.Parent = padre
	return f
end

-- Parte invisible que solo existe para marcar una posicion. No colisiona, no
-- se toca y no entra en raycasts, asi no molesta ni al jugador ni al iman.
local function marcador(nombre, cframe, padre)
	return parte({
		Name = nombre,
		Size = Vector3.new(1, 1, 1),
		CFrame = cframe,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = padre,
	})
end

local function etiquetar(inst, tag)
	CollectionService:AddTag(inst, tag)
end

-- Silueta grande de decorado: colisiona (se puede subir a ella, y alguna
-- figurina se esconde encima o debajo) pero no entra en raycasts ni tiene
-- tag de juego
local function pieza(props)
	props.CanQuery = false
	local p = parte(props)
	etiquetar(p, "SoloDecorado")
	return p
end

local function prompt(padre, accion, objeto, distancia, hold)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = accion
	pp.ObjectText = objeto
	pp.MaxActivationDistance = distancia or GameConfig.DISTANCIA_INTERACCION
	pp.HoldDuration = hold or 0
	pp.RequiresLineOfSight = false
	pp.Parent = padre
	return pp
end

-- Cartel flotante horneado (el cliente lo restiliza como pegatina y pone el
-- texto de Textos.MUNDO en los etiquetados; ver Escena.client)
local function cartelFlotante(parteBase, texto, altura, ancho)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Cartel"
	bb.Size = UDim2.fromOffset(ancho or 220, 44)
	bb.StudsOffset = Vector3.new(0, altura or 3, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	bb.Parent = parteBase
	local tl = Instance.new("TextLabel")
	tl.Name = "Texto"
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundColor3 = Paleta.UI_PAPEL
	tl.BackgroundTransparency = 0
	tl.Text = texto
	tl.TextColor3 = Paleta.UI_TINTA
	tl.TextScaled = true
	tl.Font = Enum.Font.FredokaOne
	tl.Parent = bb
	local esquinas = Instance.new("UICorner")
	esquinas.CornerRadius = UDim.new(0, 8)
	esquinas.Parent = tl
	return bb
end

-- Poste-senal de madera con una tabla y el texto en pegatina por las dos
-- caras. `suelo` es la altura del suelo donde se clava (0 en el baseplate,
-- 0.9 en el pavimento de la plaza). Con giro 0 la cara Back mira a +Z (sur);
-- con giro 90 mira a +X (este).
local function posteSenal(padre, x, z, texto, giro, suelo)
	local m = modelo("PosteSenal", padre)
	etiquetar(m, "SoloDecorado")
	local cf = CFrame.new(x, suelo or 0, z) * CFrame.Angles(0, math.rad(giro or 0), 0)
	parte({ Name = "Poste", Size = Vector3.new(0.6, 6.5, 0.6), CFrame = cf * CFrame.new(0, 3.25, 0), Color = M.VIGA, Material = Enum.Material.Wood, CanQuery = false, Parent = m })
	local tabla = parte({ Name = "Tabla", Size = Vector3.new(7, 1.8, 0.4), CFrame = cf * CFrame.new(0, 5.6, 0) * CFrame.Angles(0, 0, math.rad(-3)), Color = M.MADERA_CLARA, Material = Enum.Material.WoodPlanks, Variante = V.madera, CanCollide = false, CanQuery = false, Parent = m })
	ArteMundo.letreroPegatina(tabla, texto, Enum.NormalId.Front, {})
	ArteMundo.letreroPegatina(tabla, texto, Enum.NormalId.Back, {})
	return m
end

local function centroMapa()
	local L = LAYOUT.LIMITE
	return (L.oeste + L.este) / 2, (L.norte + L.sur) / 2
end

-- ===========================================================================
-- Limpieza del place
-- ===========================================================================

-- Borra el mundo anterior y devuelve su carpeta `Manual`, si la habia: lo
-- que el usuario edita a mano en Studio va ahi y sobrevive a cada horneado
-- (construir() la vuelve a colgar del Mundo nuevo). El resto de Mundo se
-- rehace desde el codigo.
local function limpiarPlace(): Folder?
	local manual = nil
	local viejo = workspace:FindFirstChild("Mundo")
	if viejo then
		manual = viejo:FindFirstChild("Manual")
		if manual then
			manual.Parent = nil
		end
		viejo:Destroy()
	end
	-- El SpawnLocation y la textura del baseplate vienen de la plantilla de
	-- Studio: el spawn real esta en la plaza.
	for _, hijo in workspace:GetChildren() do
		if hijo:IsA("SpawnLocation") then
			hijo:Destroy()
		end
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		for _, hijo in baseplate:GetChildren() do
			if hijo:IsA("Texture") or hijo:IsA("Decal") then
				hijo:Destroy()
			end
		end
		-- El terreno llega justo hasta la valla (LAYOUT.LIMITE): fuera no hay
		-- nada. default.project.json e instalar-desde-http llevan el mismo
		-- tamano y posicion
		local L = LAYOUT.LIMITE
		local cx, cz = centroMapa()
		baseplate.Size = Vector3.new(L.este - L.oeste, 20, L.sur - L.norte)
		baseplate.Position = Vector3.new(cx, -baseplate.Size.Y / 2, cz)
		-- Todo lo que no es patio ni parcela es cesped un poco mas oscuro
		ArteMundo.pintar(baseplate, Enum.Material.SmoothPlastic, M.CESPED_OSCURO, V.cesped)
	end
	return manual
end

-- ===========================================================================
-- Patio compartido
-- ===========================================================================

-- 12 ranuras: rejilla 4x3 con jitter determinista. Los tamanos se reparten
-- con la misma semilla para que hornear dos veces de el mismo patio.
local function posicionesRanuras()
	local rng = Random.new(GameConfig.NUM_PARCELAS * 7 + 3)
	local posiciones = {}
	for _, x0 in LAYOUT.RANURA_X do
		for _, z0 in LAYOUT.RANURA_Z do
			local x = x0 + rng:NextNumber(-LAYOUT.RANURA_JITTER, LAYOUT.RANURA_JITTER)
			local z = z0 + rng:NextNumber(-LAYOUT.RANURA_JITTER, LAYOUT.RANURA_JITTER)
			table.insert(posiciones, Vector3.new(x, 1, z))
		end
	end
	local tamanos = {}
	for nombre, def in GameConfig.TAMANOS_MONTON do
		for _ = 1, def.cantidad do
			table.insert(tamanos, nombre)
		end
	end
	table.sort(tamanos)
	for i = #tamanos, 2, -1 do
		local j = rng:NextInteger(1, i)
		tamanos[i], tamanos[j] = tamanos[j], tamanos[i]
	end
	return posiciones, tamanos
end

local function construirRanuras(patio)
	local ranuras = carpeta("Ranuras", patio)
	local posiciones, tamanos = posicionesRanuras()
	for i, pos in posiciones do
		local m = marcador("Ranura_" .. i, CFrame.new(pos), ranuras)
		m:SetAttribute("Indice", i)
		m:SetAttribute("Tamano", tamanos[i] or "chico")
		etiquetar(m, "RanuraMonton")
	end
	return #posiciones
end

-- Caminos de tierra por los pasillos entre montones (entre las columnas y
-- filas de ranuras); el central llega hasta el borde sur, donde empieza la
-- plaza, y se ensancha en la entrada
local function construirCaminos(patio)
	local caminos = carpeta("Caminos", patio)
	local lado = LAYOUT.PATIO_LADO
	local ancho = LAYOUT.CAMINO_ANCHO
	local semilla = 10
	for _, x in { -50, 50 } do
		semilla += 1
		ArteMundo.caminoTierra(caminos, CFrame.new(x, 1, 0), ancho, lado - 4, semilla)
	end
	ArteMundo.caminoTierra(caminos, CFrame.new(0, 1, 1), ancho, lado - 2, 13)
	for _, z in { -30, 30 } do
		semilla += 1
		ArteMundo.caminoTierra(caminos, CFrame.new(0, 1, z) * CFrame.Angles(0, math.rad(90), 0), ancho, lado - 4, semilla)
	end
	ArteMundo.caminoTierra(caminos, CFrame.new(0, 1, lado / 2 - 6), ancho + 8, 12, 99)
end

-- Seis siluetas estaticas que ademas son los escondites de las figurinas.
-- Todas a mas de 20 studs de cualquier ranura: la basura que brota dentro
-- de una silueta con colision sale disparada hacia el suelo.
-- Devuelve los CFrames de escondite por FigurinaId.
local function construirDecorado(patio)
	local decorado = carpeta("Decorado", patio)
	local escondites = {}

	local function silueta(props)
		props.Parent = decorado
		return pieza(props)
	end

	-- Lavadora vieja (F5 dentro, a la altura de la puerta)
	local lavadora = modelo("LavadoraVieja", decorado)
	silueta({ Name = "Cuerpo", Size = Vector3.new(6, 7, 6), Position = Vector3.new(-95, 4.5, -85), Color = M.PARED, Material = Enum.Material.Plaster }).Parent = lavadora
	local puerta = silueta({ Name = "Puerta", Size = Vector3.new(0.4, 3.6, 3.6), CFrame = CFrame.new(-95, 4, -81.8) * CFrame.Angles(0, math.rad(90), 0), Shape = Enum.PartType.Cylinder, Color = M.CRISTAL, Material = Enum.Material.Glass })
	puerta.Parent = lavadora
	silueta({ Name = "Marco", Size = Vector3.new(0.5, 4.2, 4.2), CFrame = CFrame.new(-95, 4, -81.9) * CFrame.Angles(0, math.rad(90), 0), Shape = Enum.PartType.Cylinder, Color = M.METAL, Material = Enum.Material.Metal }).Parent = lavadora
	silueta({ Name = "Oxido", Size = Vector3.new(2, 1.4, 0.1), Position = Vector3.new(-93.5, 2.2, -81.95), Color = M.OXIDO, Material = Enum.Material.CorrodedMetal }).Parent = lavadora
	escondites.F5 = CFrame.new(-95, 1.8, -81)

	-- Pila de neumaticos (F6 encima)
	local neumaticos = modelo("PilaNeumaticos", decorado)
	for i = 0, 2 do
		local n = silueta({ Name = "Neumatico" .. i, Size = Vector3.new(1.4, 6, 6), CFrame = CFrame.new(92, 1.7 + i * 1.4, -90) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = M.GOMA, Material = Enum.Material.Rubber })
		n.Parent = neumaticos
		silueta({ Name = "Llanta" .. i, Size = Vector3.new(1.46, 3, 3), CFrame = CFrame.new(92, 1.7 + i * 1.4, -90) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = M.METAL, Material = Enum.Material.Metal }).Parent = neumaticos
	end
	escondites.F6 = CFrame.new(92, 5.4, -90)

	-- Tubo tumbado (F2 en la boca)
	local tubo = silueta({ Name = "TuboTumbado", Size = Vector3.new(14, 5, 5), CFrame = CFrame.new(92, 3.5, 28) * CFrame.Angles(0, math.rad(90), 0), Shape = Enum.PartType.Cylinder, Color = M.OXIDO, Material = Enum.Material.CorrodedMetal })
	tubo.Name = "TuboTumbado"
	escondites.F2 = CFrame.new(92, 1.6, 36)

	-- Rampa a un puente bajo (F4 debajo del puente)
	local puente = modelo("Puente", decorado)
	local madera = Enum.Material.WoodPlanks
	silueta({ Name = "Tablero", Size = Vector3.new(10, 1, 10), Position = Vector3.new(-90, 6.5, 30), Color = M.MADERA, Material = madera, Variante = V.madera }).Parent = puente
	for nombre, pos in { PilarA = Vector3.new(-94.5, 3.5, 34.5), PilarB = Vector3.new(-85.5, 3.5, 34.5), PilarC = Vector3.new(-94.5, 3.5, 25.5), PilarD = Vector3.new(-85.5, 3.5, 25.5) } do
		silueta({ Name = nombre, Size = Vector3.new(1, 5, 1), Position = pos, Color = M.VIGA, Material = Enum.Material.Wood }).Parent = puente
	end
	local rampa = cuna({ Name = "Rampa", Size = Vector3.new(10, 6, 14), CFrame = CFrame.new(-90, 4, 42) * CFrame.Angles(0, math.rad(180), 0), Color = M.MADERA, Material = madera, Variante = V.madera, Parent = puente })
	rampa.CanQuery = false
	etiquetar(rampa, "SoloDecorado")
	escondites.F4 = CFrame.new(-90, 1.6, 30)

	-- Contenedor grande al fondo del patio, lejos de la entrada (F3 encima)
	local contenedor = silueta({ Name = "ContenedorGrande", Size = Vector3.new(10, 6, 5), Position = Vector3.new(0, 4, -85), Color = M.OXIDO, Material = Enum.Material.CorrodedMetal })
	contenedor.Name = "ContenedorGrande"
	escondites.F3 = CFrame.new(0, 7.6, -85)

	-- Esquina de muro caida, en medio del patio
	local esquina = modelo("EsquinaMuro", decorado)
	silueta({ Name = "TramoA", Size = Vector3.new(12, 3.5, 1.5), Position = Vector3.new(-14, 2.75, 30), Color = M.HORMIGON, Material = Enum.Material.Concrete }).Parent = esquina
	silueta({ Name = "TramoB", Size = Vector3.new(1.5, 3.5, 10), Position = Vector3.new(-8.75, 2.75, 35.75), Color = M.HORMIGON, Material = Enum.Material.Concrete }).Parent = esquina

	-- Props sueltos por el patio: barriles, bolsas y neumaticos
	ArteMundo.barril(decorado, CFrame.new(-92, 1, -40), M.AZUL_MAQUINA)
	ArteMundo.barril(decorado, CFrame.new(-94, 1, -36.5), M.OXIDO)
	ArteMundo.bolsaBasura(decorado, CFrame.new(90, 1, 20), 21)
	ArteMundo.bolsaBasura(decorado, CFrame.new(92.5, 1, 22), 22)
	ArteMundo.pilaNeumaticos(decorado, CFrame.new(-90, 1, 88), 2, 23)
	ArteMundo.pilaNeumaticos(decorado, CFrame.new(40, 1, 92), 4, 24)

	-- F1: detras de la caseta, en el lote de la recicladora
	escondites.F1 = CFrame.new(0, 1.6, LAYOUT.CASETA_Z + 7.5)

	return escondites
end

local function construirFigurinasFijas(patio, escondites)
	local folder = carpeta("FigurinasFijas", patio)
	local n = 0
	for _, f in DefinicionesColeccionables.figurinasFijas() do
		local cf = escondites[f.id]
		if cf then
			local m = marcador("Figurina_" .. f.id, cf, folder)
			m:SetAttribute("FigurinaId", f.id)
			etiquetar(m, "FigurinaFija")
			n += 1
		else
			warn("ConstructorMundo: la figurina fija " .. f.id .. " no tiene escondite")
		end
	end
	return n
end

-- El patio ya no lleva muros: la valla del vertedero rodea todo el mapa
-- (construirLimites) y el patio es la explanada de cesped claro, un stud
-- mas alta que el resto, con los caminos y los montones.
local function construirPatio(mundo)
	local patio = modelo("Patio", mundo)
	local lado = LAYOUT.PATIO_LADO
	-- 4 studs de grosor (hundido en el baseplate): con 1 stud, la basura que
	-- cae desde lo alto de las montanas atravesaba el suelo y acababa sobre
	-- el baseplate
	parte({ Name = "Suelo", Size = Vector3.new(lado, 4, lado), Position = Vector3.new(0, -1, 0), Color = M.CESPED, Material = Enum.Material.SmoothPlastic, Variante = V.cesped, Parent = patio })
	local numRanuras = construirRanuras(patio)
	construirCaminos(patio)
	local escondites = construirDecorado(patio)
	local numFigurinas = construirFigurinasFijas(patio, escondites)
	return numRanuras, numFigurinas
end

-- ===========================================================================
-- Recicladora de Dona Chatarra: caseta, contenedor, maquina y el lote
-- ===========================================================================

-- cf = suelo bajo el NPC, con +Z local hacia los clientes (la cara y el
-- delantal que le pone ArteMundo.vestirChatarra van en +Z local)
local function construirNPC(caseta, cf)
	local npc = modelo("DonaChatarra", caseta)
	npc:SetAttribute("NPC", "DonaChatarra")
	local color = Paleta.NPC
	local torso = parte({ Name = "Torso", Size = Vector3.new(2.2, 2.4, 1.1), CFrame = cf * CFrame.new(0, 4.2, 0), Color = color, Parent = npc })
	parte({ Name = "Cabeza", Size = Vector3.new(1.5, 1.5, 1.5), CFrame = cf * CFrame.new(0, 6.15, 0), Color = color, Shape = Enum.PartType.Ball, Parent = npc })
	parte({ Name = "Mono", Size = Vector3.new(1, 0.7, 1), CFrame = cf * CFrame.new(0, 7.1, 0), Color = Paleta.gris(120), Shape = Enum.PartType.Ball, Parent = npc })
	parte({ Name = "BrazoIzq", Size = Vector3.new(0.7, 2.2, 0.7), CFrame = cf * CFrame.new(-1.5, 4.2, 0), Color = color, Parent = npc })
	parte({ Name = "BrazoDer", Size = Vector3.new(0.7, 2.2, 0.7), CFrame = cf * CFrame.new(1.5, 4.2, 0), Color = color, Parent = npc })
	parte({ Name = "Piernas", Size = Vector3.new(2, 2, 1), CFrame = cf * CFrame.new(0, 2, 0), Color = Paleta.gris(150), Parent = npc })
	npc.PrimaryPart = torso
	prompt(torso, Textos.PATIO.hablar, "Doña Chatarra", 10)
	ArteMundo.vestirChatarra(npc)
	return npc
end

-- cf = suelo bajo el centro del contenedor; la pared del frente (con el
-- prompt) queda en +Z local, hacia la plaza
local function construirContenedor(caseta, cf)
	local cont = modelo("Contenedor", caseta)
	etiquetar(cont, "Contenedor")
	local color = Paleta.CONTENEDOR
	local ancho, alto, fondo, grosor = 8, 6, 6, 0.5
	local y = 1 + alto / 2
	parte({ Name = "Piso", Size = Vector3.new(ancho, grosor, fondo), CFrame = cf * CFrame.new(0, 1 + grosor / 2, 0), Color = color, Parent = cont })
	parte({ Name = "ParedFondo", Size = Vector3.new(ancho, alto, grosor), CFrame = cf * CFrame.new(0, y, -fondo / 2), Color = color, Parent = cont })
	local frente = parte({ Name = "ParedFrente", Size = Vector3.new(ancho, alto, grosor), CFrame = cf * CFrame.new(0, y, fondo / 2), Color = color, Parent = cont })
	parte({ Name = "ParedIzq", Size = Vector3.new(grosor, alto, fondo), CFrame = cf * CFrame.new(-ancho / 2, y, 0), Color = color, Parent = cont })
	parte({ Name = "ParedDer", Size = Vector3.new(grosor, alto, fondo), CFrame = cf * CFrame.new(ancho / 2, y, 0), Color = color, Parent = cont })
	-- Zona de acierto: el volumen interior. Un proyectil que la toque entro.
	local zona = parte({
		Name = "ZonaAcierto",
		Size = Vector3.new(ancho - grosor * 2, alto - 1, fondo - grosor * 2),
		CFrame = cf * CFrame.new(0, y + 0.5, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = true,
		Parent = cont,
	})
	cont.PrimaryPart = frente
	cartelFlotante(frente, Textos.MUNDO.venderBasura, 4.5, 240)
	prompt(frente, Textos.PATIO.reciclar, "Contenedor", 10)
	ArteMundo.contenedorVerde(caseta, cont)
	-- La trituradora amarilla detras (decorado)
	ArteMundo.trituradora(caseta, cf * CFrame.new(0, 1, -6.8))
	return cont, zona
end

-- cf = suelo bajo la maquina; la ventana y la ranura miran a +Z local
local function construirMaquinaRefrescos(caseta, cf)
	local maq = modelo("MaquinaRefrescos", caseta)
	etiquetar(maq, "MaquinaRefrescos")
	local cuerpo = parte({ Name = "Cuerpo", Size = Vector3.new(4, 7, 3), CFrame = cf * CFrame.new(0, 4.5, 0), Color = Paleta.MUEBLE, Parent = maq })
	parte({ Name = "Ventana", Size = Vector3.new(3, 4, 0.3), CFrame = cf * CFrame.new(0, 5.5, 2.0), Color = Paleta.gris(90), Parent = maq })
	parte({ Name = "Ranura", Size = Vector3.new(2.5, 0.8, 0.4), CFrame = cf * CFrame.new(0, 2.2, 1.6), Color = Paleta.gris(60), Parent = maq })
	maq.PrimaryPart = cuerpo
	prompt(cuerpo, Textos.PATIO.comprarRefresco, "Máquina", 8)
	ArteMundo.maquinaRefrescos(caseta, maq)
	return maq
end

local function construirCaseta(mundo)
	local caseta = modelo("Caseta", mundo)
	-- La recicladora esta al SUR del patio y mira al norte. ArteMundo espera
	-- el frente de la caseta y de sus maquinas en +Z local (CARA_PATIO), asi
	-- que todo se construye en coordenadas locales sobre un pivote girado
	-- 180 grados: +Z local = norte (la plaza y el patio), +X local = oeste.
	local base = CFrame.new(0, 0, LAYOUT.CASETA_Z) * CFrame.Angles(0, math.pi, 0)
	local function en(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local tierra = 0.12 -- altura del lote de tierra
	-- Lote de tierra pisada de toda la recicladora, del ancho del patio
	ArteMundo.loteTierra(caseta, CFrame.new(0, 0, (LAYOUT.LOTE_NORTE + LAYOUT.LOTE_SUR) / 2), LAYOUT.PATIO_LADO, LAYOUT.LOTE_SUR - LAYOUT.LOTE_NORTE, 50)
	-- Solera de hormigon bajo la caseta, la maquina, el contenedor y la
	-- trituradora (ancha para que las patas de la cinta apoyen)
	parte({ Name = "Solera", Size = Vector3.new(64, 1, 30), CFrame = en(0, 0.5, 1), Color = M.HORMIGON, Material = Enum.Material.Concrete, Parent = caseta })
	-- Cabina abierta al frente (+Z local): fondo, dos lados y techo. Son la
	-- colision; ArteMundo.caseta construye la cabana alrededor.
	local madera = Enum.Material.WoodPlanks
	parte({ Name = "Fondo", Size = Vector3.new(14, 8, 0.6), CFrame = en(0, 5, -4), Color = M.MADERA, Material = madera, Variante = V.madera, Parent = caseta })
	parte({ Name = "LadoIzq", Size = Vector3.new(0.6, 8, 8), CFrame = en(-7, 5, 0), Color = M.MADERA, Material = madera, Variante = V.madera, Parent = caseta })
	parte({ Name = "LadoDer", Size = Vector3.new(0.6, 8, 8), CFrame = en(7, 5, 0), Color = M.MADERA, Material = madera, Variante = V.madera, Parent = caseta })
	parte({ Name = "Techo", Size = Vector3.new(15, 0.6, 9.5), CFrame = en(0, 9.3, 0.5), Color = M.VIGA, Material = Enum.Material.Wood, Parent = caseta })
	parte({ Name = "Mostrador", Size = Vector3.new(14, 3.5, 2), CFrame = en(0, 2.75, 4), Color = M.MADERA_CLARA, Material = madera, Variante = V.madera, Parent = caseta })
	parte({ Name = "Encimera", Size = Vector3.new(14.4, 0.3, 2.4), CFrame = en(0, 4.6, 4), Color = M.VIGA, Material = Enum.Material.Wood, CanQuery = false, Parent = caseta })
	-- El rotulo de la cabina queda bajo el balcon de la cabana: invisible, el
	-- texto grande va en el tejado
	parte({ Name = "Rotulo", Size = Vector3.new(15, 2, 0.6), CFrame = en(0, 10.6, 4.5), Color = M.MADERA_CLARA, Material = madera, Variante = V.madera, Transparency = 1, Parent = caseta })
	ArteMundo.caseta(caseta, en(0, 1, 0))
	construirNPC(caseta, en(0, 0, 1.5))
	local _, zona = construirContenedor(caseta, en(14, 0, 6))
	construirMaquinaRefrescos(caseta, en(-13, 0, 6))
	-- Chatarra sobre la solera, junto a la cabana
	ArteMundo.pilaNeumaticos(caseta, en(-29, 1, 4), 3, 31)
	ArteMundo.barril(caseta, en(-30, 1, 11), M.OXIDO)
	ArteMundo.bolsaBasura(caseta, en(-27, 1, 10), 32)
	-- El resto del lote, sobre la tierra: camiones abandonados, neumaticos,
	-- barriles, cajas y un contenedor viejo en cada extremo
	ArteMundo.camion(caseta, en(44, tierra, 6) * CFrame.Angles(0, math.rad(-25), 0))
	ArteMundo.pilaNeumaticos(caseta, en(66, tierra, 8), 4, 33)
	ArteMundo.barril(caseta, en(72, tierra, 2), M.AZUL_MAQUINA)
	ArteMundo.barril(caseta, en(74.6, tierra, 4.4), M.OXIDO)
	ArteMundo.caja(caseta, en(84, tierra, -2), Vector3.new(3, 2.6, 2.8))
	ArteMundo.caja(caseta, en(84.3, tierra + 2.6, -1.7) * CFrame.Angles(0, math.rad(20), 0), Vector3.new(2.4, 2, 2.2))
	ArteMundo.bolsaBasura(caseta, en(90, tierra, 6), 34)
	ArteMundo.bolsaBasura(caseta, en(92.5, tierra, 3.4), 35)
	pieza({ Name = "ContenedorViejo", Size = Vector3.new(10, 6, 5), CFrame = en(88, tierra + 3, -9) * CFrame.Angles(0, math.rad(8), 0), Color = M.OXIDO, Material = Enum.Material.CorrodedMetal, Parent = caseta })
	ArteMundo.barril(caseta, en(-58, tierra, 12), M.OXIDO)
	ArteMundo.barril(caseta, en(-60.6, tierra, 9.6), M.AZUL_MAQUINA)
	ArteMundo.barril(caseta, en(-58.4, tierra, 7.3), M.AMARILLO)
	ArteMundo.pilaNeumaticos(caseta, en(-76, tierra, 4), 5, 36)
	ArteMundo.caja(caseta, en(-86, tierra, 10), Vector3.new(2.8, 2.4, 2.6))
	ArteMundo.caja(caseta, en(-89.2, tierra, 8.6) * CFrame.Angles(0, math.rad(-30), 0), Vector3.new(2.2, 1.8, 2))
	ArteMundo.bolsaBasura(caseta, en(-91, tierra, -3), 37)
	ArteMundo.camion(caseta, en(-80, tierra, -6) * CFrame.Angles(0, math.rad(150), 0))
	-- Postes de luz con cables a lo largo del frente del lote (la calle)
	local anteriores = nil
	for _, x in { -90, -54, -18, 18, 54, 90 } do
		local _, puntos = ArteMundo.posteLuz(caseta, en(x, tierra, 17.4))
		if anteriores then
			ArteMundo.cables(anteriores, puntos)
		end
		anteriores = puntos
	end
	return zona
end

-- Plaza del spawn: pavimento pegado al borde sur del patio, en la calle que
-- lo separa de la recicladora. Se aparece mirando a la caseta.
local function construirPlaza(mundo)
	local plaza = modelo("Plaza", mundo)
	local fondo = LAYOUT.PLAZA_FONDO
	local zCentro = LAYOUT.PATIO_LADO / 2 + fondo / 2
	parte({ Name = "Pavimento", Size = Vector3.new(LAYOUT.PLAZA_ANCHO, 0.9, fondo), Position = Vector3.new(0, 0.45, zCentro), Color = M.HORMIGON, Material = Enum.Material.Concrete, Parent = plaza })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, LAYOUT.SPAWN_Z) * CFrame.Angles(0, math.pi, 0)
	spawn.Anchored = true
	spawn.Color = Paleta.escalar(M.HORMIGON, 1.06)
	spawn.Material = Enum.Material.Concrete
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = plaza
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	-- Postes indicadores sobre el pavimento: el de las parcelas mira al este
	-- (se lee desde la plaza, y "arriba" es el oeste); el del patio mira al
	-- sur y "arriba" es el norte
	posteSenal(plaza, -17, LAYOUT.SPAWN_Z, "Parcelas ↑", 90, 0.9)
	posteSenal(plaza, 17, LAYOUT.PATIO_LADO / 2 + 4, "Patio de basura ↑", 0, 0.9)
	return plaza
end

-- ===========================================================================
-- Parcelas
-- ===========================================================================

-- CFrame del centro de cada parcela, mirando a la calle y al patio (LookVector
-- apunta a +X: local -Z es el frente, +Z el fondo, +X local es el sur).
local function cframesParcelas()
	assert(#LAYOUT.PARCELA_Z >= GameConfig.NUM_PARCELAS, "faltan posiciones de parcela en LAYOUT.PARCELA_Z")
	local cframes = {}
	for i, z in LAYOUT.PARCELA_Z do
		local pos = Vector3.new(LAYOUT.PARCELA_X, 0, z)
		cframes[i] = CFrame.lookAt(pos, Vector3.new(0, 0, z))
	end
	return cframes
end

local function construirParcela(carpetaParcelas, indice, base)
	local parcela = modelo("Parcela_" .. indice, carpetaParcelas)
	parcela:SetAttribute("IndiceParcela", indice)
	etiquetar(parcela, "Parcela")

	local lado = LAYOUT.PARCELA_LADO
	local mitad = lado / 2
	local function local_(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local function pintable(p, tipo)
		p:SetAttribute("Pintable", tipo)
		return p
	end
	-- Parcelas minimalistas: color liso, sin veta ni textura
	local madera = Enum.Material.SmoothPlastic

	-- Losa lisa (la skin la tine)
	local losa = pintable(parte({ Name = "Losa", Size = Vector3.new(lado, 1, lado), CFrame = local_(0, 0.5, 0), Color = Paleta.LOSA_PARCELA, Material = madera, Variante = V.madera, Parent = parcela }), "losa")
	parcela.PrimaryPart = losa

	-- Borde con entrada al frente (frente = -Z local): cerca baja de madera
	local bordes = carpeta("Borde", parcela)
	local grosor, alto = 0.6, 1
	local yB = 1 + alto / 2
	local function borde(nombre, size, cf)
		return pintable(parte({ Name = nombre, Size = size, CFrame = cf, Color = Paleta.MUROS, Material = Enum.Material.SmoothPlastic, Parent = bordes }), "borde")
	end
	borde("Fondo", Vector3.new(lado, alto, grosor), local_(0, yB, mitad))
	borde("Izq", Vector3.new(grosor, alto, lado), local_(-mitad, yB, 0))
	borde("Der", Vector3.new(grosor, alto, lado), local_(mitad, yB, 0))
	local entrada = 8
	local tramo = (lado - entrada) / 2
	borde("FrenteIzq", Vector3.new(tramo, alto, grosor), local_(-(entrada / 2 + tramo / 2), yB, -mitad))
	borde("FrenteDer", Vector3.new(tramo, alto, grosor), local_(entrada / 2 + tramo / 2, yB, -mitad))
	-- Postes de esquina de la cerca (decorado)
	for _, dx in { -mitad, mitad } do
		for _, dz in { -mitad, mitad } do
			local poste = parte({ Name = "PosteCerca", Size = Vector3.new(0.9, 1.8, 0.9), CFrame = local_(dx, 1.9, dz), Color = M.VIGA, Material = Enum.Material.SmoothPlastic, CanQuery = false, Parent = bordes })
			etiquetar(poste, "SoloDecorado")
		end
	end

	-- Cartel del dueno, junto a la entrada
	local cartel = parte({ Name = "Cartel", Size = Vector3.new(0.6, 6, 0.6), CFrame = local_(-6, 4, -mitad - 1), Color = M.VIGA, Material = Enum.Material.SmoothPlastic, Parent = parcela })
	local bb = cartelFlotante(cartel, Textos.BASE.parcelaLibre, 3.8, 240)
	bb.Name = "CartelDueno"
	prompt(cartel, Textos.PATIO.meGusta, "Base", 10)

	-- Spawn de la parcela (teletransporte a casa)
	marcador("Spawn", local_(0, 3, -10), parcela)

	-- Estanteria al fondo: tablero + 2 estantes + 12 slots
	local estanteria = modelo("Estanteria", parcela)
	estanteria:SetAttribute("Mueble", "Estanteria")
	pintable(parte({ Name = "Tablero", Size = Vector3.new(13, 8, 0.6), CFrame = local_(0, 5, mitad - 1.3), Color = Paleta.MUEBLE, Material = madera, Variante = V.madera, Parent = estanteria }), "mueble")
	local slotsEstanteria = 0
	for fila = 0, 1 do
		local yEst = 3.2 + fila * 3
		local estante = pintable(parte({ Name = "Estante" .. (fila + 1), Size = Vector3.new(13, 0.4, 1.8), CFrame = local_(0, yEst, mitad - 2.5), Color = Paleta.MUEBLE, Material = Enum.Material.SmoothPlastic, Parent = estanteria }), "mueble")
		estante.Name = "Estante" .. (fila + 1)
		for col = 0, 5 do
			local xS = -5.5 + col * 2.2
			local slot = marcador("SlotEstanteria", local_(xS, yEst + 1.1, mitad - 2.5), estanteria)
			slotsEstanteria += 1
			slot:SetAttribute("Indice", slotsEstanteria)
		end
	end
	for _, x in { -6.3, 6.3 } do
		parte({ Name = "Lateral", Size = Vector3.new(0.4, 8, 1.8), CFrame = local_(x, 5, mitad - 2.5), Color = M.VIGA, Material = Enum.Material.SmoothPlastic, CanQuery = false, Parent = estanteria })
	end
	prompt(estanteria:FindFirstChild("Tablero"), Textos.BASE.estanteria, "Estantería", 10)

	-- Radio, en la esquina del fondo a la izquierda: radio retro naranja
	local radio = modelo("Radio", parcela)
	radio:SetAttribute("Mueble", "Radio")
	local cuerpoRadio = pintable(parte({ Name = "Cuerpo", Size = Vector3.new(3.4, 2.2, 1.6), CFrame = local_(-12, 2.1, mitad - 4), Color = Paleta.MUEBLE, Material = Enum.Material.SmoothPlastic, Parent = radio }), "mueble")
	for i, xR in { -0.9, 0.9 } do
		local carrete = parte({ Name = "Carrete" .. i, Size = Vector3.new(0.3, 1.2, 1.2), CFrame = local_(-12 + xR, 2.4, mitad - 4 - 0.95) * CFrame.Angles(0, math.rad(90), 0), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, Shape = Enum.PartType.Cylinder, Parent = radio })
		carrete.Name = "Carrete" .. i
	end
	parte({ Name = "Antena", Size = Vector3.new(0.15, 2.5, 0.15), CFrame = local_(-10.6, 4.3, mitad - 4.2), Color = M.METAL, Material = Enum.Material.Metal, Parent = radio })
	parte({ Name = "Dial", Size = Vector3.new(0.5, 0.5, 0.15), CFrame = local_(-12, 1.55, mitad - 4 - 0.85), Color = M.AMARILLO, Material = Enum.Material.SmoothPlastic, CanQuery = false, Parent = radio })
	parte({ Name = "Pie", Size = Vector3.new(3.6, 0.3, 1.8), CFrame = local_(-12, 1.15, mitad - 4), Color = M.VIGA, Material = Enum.Material.SmoothPlastic, CanQuery = false, Parent = radio })
	radio.PrimaryPart = cuerpoRadio
	prompt(cuerpoRadio, Textos.BASE.radio, "Radio", 10)

	-- Mesa de reparacion, a la derecha del fondo: banco de trabajo
	local mesa = modelo("MesaReparacion", parcela)
	mesa:SetAttribute("Mueble", "MesaReparacion")
	local tablero = pintable(parte({ Name = "Tablero", Size = Vector3.new(6, 0.5, 3), CFrame = local_(11, 3, 10), Color = Paleta.MUEBLE, Material = madera, Variante = V.madera, Parent = mesa }), "mueble")
	for _, dx in { -2.6, 2.6 } do
		for _, dz in { -1.1, 1.1 } do
			parte({ Name = "Pata", Size = Vector3.new(0.5, 2.75, 0.5), CFrame = local_(11 + dx, 1.62, 10 + dz), Color = M.VIGA, Material = Enum.Material.SmoothPlastic, Parent = mesa })
		end
	end
	parte({ Name = "Lampara", Size = Vector3.new(0.3, 2, 0.3), CFrame = local_(13.5, 4.2, 11), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, Parent = mesa })
	parte({ Name = "Pantalla", Size = Vector3.new(1.4, 0.7, 1.4), CFrame = local_(13.2, 5.2, 10.6) * CFrame.Angles(0, 0, math.rad(20)), Color = M.AMARILLO, Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Cylinder, CanQuery = false, Parent = mesa })
	parte({ Name = "Herramienta", Size = Vector3.new(1.4, 0.2, 0.4), CFrame = local_(9.8, 3.35, 9.6) * CFrame.Angles(0, math.rad(25), 0), Color = M.METAL, Material = Enum.Material.Metal, CanQuery = false, Parent = mesa })
	mesa.PrimaryPart = tablero
	prompt(tablero, Textos.REPARACION.titulo, "Mesa", 10)

	-- Exhibidor: 6 pedestales a lo largo del lado izquierdo
	local exhibidor = modelo("Exhibidor", parcela)
	exhibidor:SetAttribute("Mueble", "Exhibidor")
	for i = 1, GameConfig.PEDESTALES do
		local zP = -10 + (i - 1) * 4.2
		local ped = pintable(parte({ Name = "Pedestal" .. i, Size = Vector3.new(1.8, 2.4, 1.8), CFrame = local_(-14, 2.2, zP) * CFrame.Angles(0, 0, math.rad(90)), Color = Paleta.MUEBLE, Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Cylinder, Parent = exhibidor }), "mueble")
		ped.Name = "Pedestal" .. i
		parte({ Name = "Remate", Size = Vector3.new(0.25, 2.6, 2.6), CFrame = local_(-14, 3.25, zP) * CFrame.Angles(0, 0, math.rad(90)), Color = M.HORMIGON, Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Cylinder, CanQuery = false, Parent = exhibidor })
		local top = marcador("Pedestal", local_(-14, 3.6, zP), exhibidor)
		top:SetAttribute("Indice", i)
		if i == 1 then
			exhibidor.PrimaryPart = ped
			prompt(ped, Textos.BASE.exhibidor, "Exhibidor", 10)
		end
	end

	-- Telefono para llamar a Dona Chatarra (abre la tienda): cabina azul
	local telefono = modelo("Telefono", parcela)
	telefono:SetAttribute("Mueble", "Telefono")
	parte({ Name = "Poste", Size = Vector3.new(0.6, 5, 0.6), CFrame = local_(14, 3.5, -8), Color = M.VIGA, Material = Enum.Material.SmoothPlastic, Parent = telefono })
	local auricular = pintable(parte({ Name = "Caja", Size = Vector3.new(1.6, 2.2, 1), CFrame = local_(14, 4.6, -7.3), Color = Paleta.MUEBLE, Material = Enum.Material.SmoothPlastic, Parent = telefono }), "mueble")
	parte({ Name = "Auricular", Size = Vector3.new(0.4, 1.4, 0.4), CFrame = local_(13.3, 4.6, -6.9), Color = M.NEGRO, Material = Enum.Material.SmoothPlastic, CanQuery = false, Parent = telefono })
	parte({ Name = "Tejadillo", Size = Vector3.new(2.2, 0.3, 1.6), CFrame = local_(14, 5.85, -7.3), Color = M.LONA, Material = Enum.Material.SmoothPlastic, CanQuery = false, Parent = telefono })
	telefono.PrimaryPart = auricular
	prompt(auricular, "Llamar a Doña Chatarra", "Teléfono", 10)

	-- Almacen (cofre): abre el album / inventario. Baul de madera con herrajes
	local almacen = modelo("Almacen", parcela)
	almacen:SetAttribute("Mueble", "Almacen")
	local cofre = pintable(parte({ Name = "Cofre", Size = Vector3.new(4, 2.4, 3), CFrame = local_(14, 2.2, 3), Color = Paleta.MUEBLE, Material = madera, Variante = V.madera, Parent = almacen }), "mueble")
	parte({ Name = "Tapa", Size = Vector3.new(4.2, 0.5, 3.2), CFrame = local_(14, 3.65, 3), Color = M.VIGA, Material = Enum.Material.SmoothPlastic, Parent = almacen })
	for _, dx in { -1.3, 1.3 } do
		parte({ Name = "Herraje", Size = Vector3.new(0.4, 2.7, 3.3), CFrame = local_(14 + dx, 2.4, 3), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, CanQuery = false, Parent = almacen })
	end
	parte({ Name = "Cerradura", Size = Vector3.new(0.6, 0.6, 0.2), CFrame = local_(14, 2.6, 1.42), Color = M.AMARILLO, Material = Enum.Material.Metal, CanQuery = false, Parent = almacen })
	almacen.PrimaryPart = cofre
	prompt(cofre, "Almacén", "Almacén", 10)

	return parcela
end

local function construirParcelas(mundo)
	local carpetaParcelas = carpeta("Parcelas", mundo)
	local cframes = cframesParcelas()
	for i = 1, GameConfig.NUM_PARCELAS do
		construirParcela(carpetaParcelas, i, cframes[i])
	end
	return GameConfig.NUM_PARCELAS
end

-- ===========================================================================
-- Calles y limites del mapa
-- ===========================================================================

-- Calles de tierra fuera del patio (sobre el baseplate, a y = 0): la que baja
-- entre las parcelas y el patio con un ramal a la entrada de cada parcela, y
-- la de la plaza, que cruza de esa calle al extremo este del lote pasando
-- por debajo del pavimento.
local function construirCalles(mundo)
	local calles = carpeta("Calles", mundo)
	local ancho = LAYOUT.CALLE_ANCHO
	local x = LAYOUT.CALLE_X
	local zNorte = LAYOUT.PARCELA_Z[1] - LAYOUT.PARCELA_LADO / 2 - 6
	local zSur = LAYOUT.LOTE_SUR - 6
	ArteMundo.caminoTierra(calles, CFrame.new(x, 0, (zNorte + zSur) / 2), ancho, zSur - zNorte, 60)
	local frente = LAYOUT.PARCELA_X + LAYOUT.PARCELA_LADO / 2
	for i, z in LAYOUT.PARCELA_Z do
		ArteMundo.caminoTierra(calles, CFrame.new((frente + x) / 2, 0, z) * CFrame.Angles(0, math.rad(90), 0), 8, x - frente + 2, 60 + i)
	end
	local xEste = LAYOUT.PATIO_LADO / 2 - 4
	ArteMundo.caminoTierra(calles, CFrame.new((x + xEste) / 2, 0, LAYOUT.SPAWN_Z) * CFrame.Angles(0, math.rad(90), 0), ancho, xEste - x + ancho, 70)
end

-- Borde del mapa: muro invisible alto por cada lado (tag Limite, nadie sale)
-- y, por dentro, la valla de madera del vertedero que antes rodeaba solo el
-- patio, ahora alrededor de todo.
local function construirLimites(mundo)
	local limites = carpeta("Limites", mundo)
	local L = LAYOUT.LIMITE
	local h = LAYOUT.LIMITE_ALTURA
	local cx, cz = centroMapa()
	local ancho, fondo = L.este - L.oeste, L.sur - L.norte
	local specs = {
		{ "Norte", Vector3.new(ancho + 2, h, 2), Vector3.new(cx, h / 2, L.norte) },
		{ "Sur", Vector3.new(ancho + 2, h, 2), Vector3.new(cx, h / 2, L.sur) },
		{ "Oeste", Vector3.new(2, h, fondo + 2), Vector3.new(L.oeste, h / 2, cz) },
		{ "Este", Vector3.new(2, h, fondo + 2), Vector3.new(L.este, h / 2, cz) },
	}
	for _, s in specs do
		local m = parte({ Name = "Limite" .. s[1], Size = s[2], Position = s[3], Transparency = 1, CanQuery = false, Parent = limites })
		etiquetar(m, "Limite")
	end
	local d = LAYOUT.VALLA_MARGEN
	local esquinas = {
		Vector3.new(L.oeste + d, 0, L.norte + d),
		Vector3.new(L.este - d, 0, L.norte + d),
		Vector3.new(L.este - d, 0, L.sur - d),
		Vector3.new(L.oeste + d, 0, L.sur - d),
	}
	for i = 1, 4 do
		ArteMundo.valla(limites, esquinas[i], esquinas[i % 4 + 1], LAYOUT.VALLA_ALTURA, 40 + i)
	end
end

-- ===========================================================================
-- Iluminacion y cielo (idempotente)
-- ===========================================================================

local function asegurar(padre, clase, nombre)
	local existente = padre:FindFirstChild(nombre)
	if existente and existente:IsA(clase) then
		return existente
	end
	local nuevo = Instance.new(clase)
	nuevo.Name = nombre
	nuevo.Parent = padre
	return nuevo
end

function ConstructorMundo.iluminar()
	Lighting.Brightness = 2.6
	Lighting.ClockTime = 13.5
	Lighting.Ambient = Color3.fromRGB(130, 130, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 170, 175)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 250, 235)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.ExposureCompensation = 0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4
	-- Technology es de plugin: desde el hilo del MCP ni se lee; lo fija
	-- default.project.json (Rojo) o instalar-desde-http
	pcall(function()
		Lighting.Technology = Enum.Technology.ShadowMap
	end)
	local atmosfera = asegurar(Lighting, "Atmosphere", "Atmosphere")
	atmosfera.Density = 0.3
	atmosfera.Offset = 0.2
	atmosfera.Color = Color3.fromRGB(199, 210, 226)
	atmosfera.Decay = Color3.fromRGB(106, 140, 190)
	atmosfera.Glare = 0.2
	atmosfera.Haze = 1.6
	local correccion = asegurar(Lighting, "ColorCorrectionEffect", "ColorCorrection")
	correccion.Saturation = 0.15
	correccion.Contrast = 0.06
	correccion.Brightness = 0.02
	correccion.TintColor = Color3.fromRGB(255, 252, 246)
	local bloom = asegurar(Lighting, "BloomEffect", "Bloom")
	bloom.Intensity = 0.25
	bloom.Size = 20
	bloom.Threshold = 1.6
	local nubes = asegurar(workspace.Terrain, "Clouds", "Clouds")
	nubes.Cover = 0.45
	nubes.Density = 0.6
	nubes.Color = Color3.fromRGB(255, 255, 255)
	nubes.Enabled = true
end

-- ===========================================================================
-- API
-- ===========================================================================

function ConstructorMundo.construir(): Model
	local manual = limpiarPlace()
	local mundo = modelo("Mundo", workspace)
	mundo:SetAttribute("Version", ConstructorMundo.VERSION)
	-- Lo editado a mano por el usuario vuelve a su sitio (ver limpiarPlace)
	if manual then
		manual.Parent = mundo
	else
		carpeta("Manual", mundo)
	end
	local numRanuras, numFigurinas = construirPatio(mundo)
	construirCaseta(mundo)
	construirPlaza(mundo)
	local numParcelas = construirParcelas(mundo)
	construirCalles(mundo)
	construirLimites(mundo)
	ConstructorMundo.iluminar()
	print(string.format(
		"ConstructorMundo: mundo v%d construido (%d ranuras, %d figurinas fijas, %d parcelas, %d instancias)",
		ConstructorMundo.VERSION,
		numRanuras,
		numFigurinas,
		numParcelas,
		#mundo:GetDescendants()
	))
	return mundo
end

function ConstructorMundo.previsualizar()
	local posiciones, tamanos = posicionesRanuras()
	local conteo = {}
	for _, t in tamanos do
		conteo[t] = (conteo[t] or 0) + 1
	end
	print(string.format("Patio %dx%d en el origen, %d ranuras de monton:", LAYOUT.PATIO_LADO, LAYOUT.PATIO_LADO, #posiciones))
	for t, n in conteo do
		print(string.format("  %s: %d", t, n))
	end
	print(string.format("%d parcelas de %dx%d en columna en x=%d", GameConfig.NUM_PARCELAS, LAYOUT.PARCELA_LADO, LAYOUT.PARCELA_LADO, LAYOUT.PARCELA_X))
	for i, cf in cframesParcelas() do
		print(string.format("  Parcela_%d en (%.0f, %.0f)", i, cf.Position.X, cf.Position.Z))
	end
	local L = LAYOUT.LIMITE
	print(string.format("Recicladora en z=%d..%d (caseta en z=%d), spawn en z=%d, valla en x=%d..%d z=%d..%d", LAYOUT.LOTE_NORTE, LAYOUT.LOTE_SUR, LAYOUT.CASETA_Z, LAYOUT.SPAWN_Z, L.oeste, L.este, L.norte, L.sur))
	local existente = workspace:FindFirstChild("Mundo")
	if existente then
		print(string.format("Ya existe workspace.Mundo v%s con %d instancias: construir() lo reemplaza", tostring(existente:GetAttribute("Version")), #existente:GetDescendants()))
	else
		print("No existe workspace.Mundo todavia")
	end
end

ConstructorMundo.LAYOUT = LAYOUT

return ConstructorMundo
