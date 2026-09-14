--!nonstrict
--[[
	ConstructorMundo
	Construye TODA la geometria whitebox del juego bajo workspace.Mundo a partir
	de la tabla LAYOUT de abajo. Solo primitivas, sin texturas, colores de
	Config/Paleta.

	Se usa de dos formas:
	  1. Horneado (la normal): herramientas/construir-mundo.luau lo llama desde la
	     barra de comandos / execute_luau sobre el DataModel Edit. La geometria
	     queda GUARDADA en el place y se puede retocar a mano en Studio.
	  2. Fallback: SetupMundo lo llama al arrancar si no existe workspace.Mundo,
	     para que un place recien hecho con rojo build sea jugable. Avisa por
	     consola, porque lo generado en runtime desaparece al parar.

	Todo lo que el runtime necesita encontrar lleva TAG de CollectionService o
	ATRIBUTO, nunca se busca por nombre:

	    RanuraMonton      marcador donde Botin instancia un monton (attr Tamano)
	    FigurinaFija      marcador de figurina escondida (attr FigurinaId)
	    Contenedor        el contenedor de reciclaje (hijo ZonaAcierto = punteria)
	    MaquinaRefrescos  la maquina de refrescos
	    Parcela           cada base (attr IndiceParcela; hijos con attr Mueble,
	                      marcadores SlotEstanteria y Pedestal con attr Indice)
	    Limite            muros del patio y del mapa
	    SoloDecorado      arte que no hace nada

	Las partes de una parcela que cambian con una skin llevan attr Pintable
	("losa" | "mueble" | "borde").

	Plano (N = z negativa):

	       [P1] [P2]   PLAZA / CASETA   [P3] [P4]      z = -165
	                        spawn
	   [P16]  +---------------------------+  [P5]
	   [P15]  |     PATIO 200 x 200       |  [P6]      x = +-165
	   [P14]  |   24 ranuras de monton    |  [P7]
	   [P13]  |   decorado y escondites   |  [P8]
	          +---------------------------+
	       [P12] [P11]               [P10] [P9]      z = +165
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Textos = require(Config:WaitForChild("Textos"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))

local ConstructorMundo = {}
ConstructorMundo.VERSION = 1

-- ===========================================================================
-- LAYOUT
-- ===========================================================================

local LAYOUT = {
	PATIO_LADO = 200,
	MURO_ALTURA = 4,
	MURO_GRUESO = 2,
	MURO_HUECO = 24,
	RANURA_PASO = 40, -- rejilla 5x5 sin el centro = 24 ranuras
	RANURA_JITTER = 6,
	CASETA_Z = -120,
	SPAWN_Z = -134,
	PARCELA_LADO = 36,
	PARCELA_RADIO = 165,
	PARCELA_OFFSETS = { -120, -40, 40, 120 },
	LIMITE = 240,
	LIMITE_ALTURA = 60,
}

-- ===========================================================================
-- Helpers de construccion
-- ===========================================================================

local function parte(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
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
	if props.Material then
		p.Material = props.Material
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
	w.Material = Enum.Material.SmoothPlastic
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

local function letrero(parteBase, texto, cara, tamanoTexto)
	local sg = Instance.new("SurfaceGui")
	sg.Face = cara or Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = parteBase
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = texto
	tl.TextColor3 = Paleta.gris(40)
	tl.TextScaled = tamanoTexto == nil
	if tamanoTexto then
		tl.TextSize = tamanoTexto
	end
	tl.Font = Enum.Font.GothamBold
	tl.Parent = sg
	return sg
end

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
	tl.BackgroundColor3 = Paleta.UI_FONDO
	tl.BackgroundTransparency = 0.25
	tl.Text = texto
	tl.TextColor3 = Paleta.UI_TEXTO
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.Parent = bb
	local esquinas = Instance.new("UICorner")
	esquinas.CornerRadius = UDim.new(0, 8)
	esquinas.Parent = tl
	return bb
end

-- ===========================================================================
-- Limpieza del place
-- ===========================================================================

local function limpiarPlace()
	local viejo = workspace:FindFirstChild("Mundo")
	if viejo then
		viejo:Destroy()
	end
	-- El SpawnLocation y la textura del baseplate vienen de la plantilla de
	-- Studio: el spawn real esta en la plaza y el whitebox no lleva texturas.
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
		baseplate.Color = Paleta.CAMINOS
		baseplate.Material = Enum.Material.SmoothPlastic
	end
end

-- ===========================================================================
-- Patio compartido
-- ===========================================================================

local function construirMuros(patio)
	local muros = carpeta("Muros", patio)
	local lado = LAYOUT.PATIO_LADO
	local mitad = lado / 2
	local h = LAYOUT.MURO_ALTURA
	local g = LAYOUT.MURO_GRUESO
	local hueco = LAYOUT.MURO_HUECO / 2
	local largoSegmento = mitad - hueco
	local centroSegmento = hueco + largoSegmento / 2
	local y = 1 + h / 2

	local function segmento(nombre, size, pos)
		local m = parte({ Name = nombre, Size = size, Position = pos, Color = Paleta.MUROS, Parent = muros })
		etiquetar(m, "Limite")
	end

	-- Norte y sur (a lo largo de X), con hueco central
	for _, z in { -mitad, mitad } do
		local nombreLado = if z < 0 then "Norte" else "Sur"
		segmento("Muro" .. nombreLado .. "Oeste", Vector3.new(largoSegmento, h, g), Vector3.new(-centroSegmento, y, z))
		segmento("Muro" .. nombreLado .. "Este", Vector3.new(largoSegmento, h, g), Vector3.new(centroSegmento, y, z))
	end
	-- Este y oeste (a lo largo de Z)
	for _, x in { -mitad, mitad } do
		local nombreLado = if x < 0 then "Oeste" else "Este"
		segmento("Muro" .. nombreLado .. "Norte", Vector3.new(g, h, largoSegmento), Vector3.new(x, y, -centroSegmento))
		segmento("Muro" .. nombreLado .. "Sur", Vector3.new(g, h, largoSegmento), Vector3.new(x, y, centroSegmento))
	end
end

-- 24 ranuras: rejilla 5x5 a paso 40 sin el centro, con jitter determinista.
-- Los tamanos se reparten con la misma semilla para que hornear dos veces de
-- el mismo patio.
local function posicionesRanuras()
	local rng = Random.new(GameConfig.NUM_PARCELAS * 7 + 3)
	local posiciones = {}
	for ix = -2, 2 do
		for iz = -2, 2 do
			if not (ix == 0 and iz == 0) then
				local x = ix * LAYOUT.RANURA_PASO + rng:NextNumber(-LAYOUT.RANURA_JITTER, LAYOUT.RANURA_JITTER)
				local z = iz * LAYOUT.RANURA_PASO + rng:NextNumber(-LAYOUT.RANURA_JITTER, LAYOUT.RANURA_JITTER)
				table.insert(posiciones, Vector3.new(x, 1, z))
			end
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

-- Seis siluetas estaticas que ademas son los escondites de las figurinas
-- fijas. Devuelve los CFrames de escondite por FigurinaId.
local function construirDecorado(patio)
	local decorado = carpeta("Decorado", patio)
	local escondites = {}
	local color = Paleta.DECORADO

	local function pieza(props)
		props.Color = props.Color or color
		props.Parent = decorado
		local p = parte(props)
		etiquetar(p, "SoloDecorado")
		return p
	end

	-- Lavadora vieja (F5 dentro, a la altura de la puerta)
	local lavadora = modelo("LavadoraVieja", decorado)
	pieza({ Name = "Cuerpo", Size = Vector3.new(6, 7, 6), Position = Vector3.new(-70, 4.5, -70) }).Parent = lavadora
	local puerta = pieza({ Name = "Puerta", Size = Vector3.new(0.4, 3.6, 3.6), CFrame = CFrame.new(-70, 4, -66.8) * CFrame.Angles(0, math.rad(90), 0), Shape = Enum.PartType.Cylinder, Color = Paleta.gris(110) })
	puerta.Parent = lavadora
	escondites.F5 = CFrame.new(-70, 1.8, -66)

	-- Pila de neumaticos (F6 encima)
	local neumaticos = modelo("PilaNeumaticos", decorado)
	for i = 0, 2 do
		local n = pieza({ Name = "Neumatico" .. i, Size = Vector3.new(1.4, 6, 6), CFrame = CFrame.new(75, 1.7 + i * 1.4, -75) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder })
		n.Parent = neumaticos
	end
	escondites.F6 = CFrame.new(75, 5.4, -75)

	-- Tubo tumbado (F2 en la boca)
	local tubo = pieza({ Name = "TuboTumbado", Size = Vector3.new(14, 5, 5), CFrame = CFrame.new(78, 3.5, 60) * CFrame.Angles(0, math.rad(90), 0), Shape = Enum.PartType.Cylinder })
	tubo.Name = "TuboTumbado"
	escondites.F2 = CFrame.new(78, 1.6, 68)

	-- Rampa a un puente bajo (F4 debajo del puente)
	local puente = modelo("Puente", decorado)
	pieza({ Name = "Tablero", Size = Vector3.new(10, 1, 10), Position = Vector3.new(-75, 6.5, 70) }).Parent = puente
	pieza({ Name = "PilarA", Size = Vector3.new(1, 5, 1), Position = Vector3.new(-79.5, 3.5, 74.5) }).Parent = puente
	pieza({ Name = "PilarB", Size = Vector3.new(1, 5, 1), Position = Vector3.new(-70.5, 3.5, 74.5) }).Parent = puente
	pieza({ Name = "PilarC", Size = Vector3.new(1, 5, 1), Position = Vector3.new(-79.5, 3.5, 65.5) }).Parent = puente
	pieza({ Name = "PilarD", Size = Vector3.new(1, 5, 1), Position = Vector3.new(-70.5, 3.5, 65.5) }).Parent = puente
	local rampa = cuna({ Name = "Rampa", Size = Vector3.new(10, 6, 14), CFrame = CFrame.new(-75, 4, 82) * CFrame.Angles(0, math.rad(180), 0), Color = color, Parent = puente })
	etiquetar(rampa, "SoloDecorado")
	escondites.F4 = CFrame.new(-75, 1.6, 70)

	-- Contenedor grande (F3 encima)
	local contenedor = pieza({ Name = "ContenedorGrande", Size = Vector3.new(10, 6, 5), Position = Vector3.new(0, 4, 85) })
	contenedor.Name = "ContenedorGrande"
	escondites.F3 = CFrame.new(0, 7.6, 85)

	-- Esquina de muro caida, en medio del patio
	local esquina = modelo("EsquinaMuro", decorado)
	pieza({ Name = "TramoA", Size = Vector3.new(12, 3.5, 1.5), Position = Vector3.new(-14, 2.75, 30) }).Parent = esquina
	pieza({ Name = "TramoB", Size = Vector3.new(1.5, 3.5, 10), Position = Vector3.new(-8.75, 2.75, 35.75) }).Parent = esquina

	-- F1: detras de la caseta (fuera del patio)
	escondites.F1 = CFrame.new(0, 1.6, LAYOUT.CASETA_Z - 6)

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

local function construirPatio(mundo)
	local patio = modelo("Patio", mundo)
	local lado = LAYOUT.PATIO_LADO
	parte({ Name = "Suelo", Size = Vector3.new(lado, 1, lado), Position = Vector3.new(0, 0.5, 0), Color = Paleta.SUELO_PATIO, Parent = patio })
	construirMuros(patio)
	local numRanuras = construirRanuras(patio)
	local escondites = construirDecorado(patio)
	local numFigurinas = construirFigurinasFijas(patio, escondites)
	return numRanuras, numFigurinas
end

-- ===========================================================================
-- Caseta de Dona Chatarra, contenedor, maquina de refrescos y plaza
-- ===========================================================================

local function construirNPC(caseta, z)
	local npc = modelo("DonaChatarra", caseta)
	npc:SetAttribute("NPC", "DonaChatarra")
	local color = Paleta.NPC
	local torso = parte({ Name = "Torso", Size = Vector3.new(2.2, 2.4, 1.1), Position = Vector3.new(0, 4.2, z), Color = color, Parent = npc })
	parte({ Name = "Cabeza", Size = Vector3.new(1.5, 1.5, 1.5), Position = Vector3.new(0, 6.15, z), Color = color, Shape = Enum.PartType.Ball, Parent = npc })
	parte({ Name = "Mono", Size = Vector3.new(1, 0.7, 1), Position = Vector3.new(0, 7.1, z), Color = Paleta.gris(120), Shape = Enum.PartType.Ball, Parent = npc })
	parte({ Name = "BrazoIzq", Size = Vector3.new(0.7, 2.2, 0.7), Position = Vector3.new(-1.5, 4.2, z), Color = color, Parent = npc })
	parte({ Name = "BrazoDer", Size = Vector3.new(0.7, 2.2, 0.7), Position = Vector3.new(1.5, 4.2, z), Color = color, Parent = npc })
	parte({ Name = "Piernas", Size = Vector3.new(2, 2, 1), Position = Vector3.new(0, 2, z), Color = Paleta.gris(150), Parent = npc })
	npc.PrimaryPart = torso
	cartelFlotante(torso, "Doña Chatarra", 4, 200)
	prompt(torso, Textos.PATIO.hablar, "Doña Chatarra", 10)
	return npc
end

local function construirContenedor(caseta, x, z)
	local cont = modelo("Contenedor", caseta)
	etiquetar(cont, "Contenedor")
	local color = Paleta.CONTENEDOR
	local ancho, alto, fondo, grosor = 8, 6, 6, 0.5
	local y = 1 + alto / 2
	parte({ Name = "Piso", Size = Vector3.new(ancho, grosor, fondo), Position = Vector3.new(x, 1 + grosor / 2, z), Color = color, Parent = cont })
	parte({ Name = "ParedNorte", Size = Vector3.new(ancho, alto, grosor), Position = Vector3.new(x, y, z - fondo / 2), Color = color, Parent = cont })
	local frente = parte({ Name = "ParedSur", Size = Vector3.new(ancho, alto, grosor), Position = Vector3.new(x, y, z + fondo / 2), Color = color, Parent = cont })
	parte({ Name = "ParedOeste", Size = Vector3.new(grosor, alto, fondo), Position = Vector3.new(x - ancho / 2, y, z), Color = color, Parent = cont })
	parte({ Name = "ParedEste", Size = Vector3.new(grosor, alto, fondo), Position = Vector3.new(x + ancho / 2, y, z), Color = color, Parent = cont })
	-- Zona de acierto: el volumen interior. Un proyectil que la toque entro.
	local zona = parte({
		Name = "ZonaAcierto",
		Size = Vector3.new(ancho - grosor * 2, alto - 1, fondo - grosor * 2),
		Position = Vector3.new(x, y + 0.5, z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = true,
		Parent = cont,
	})
	cont.PrimaryPart = frente
	letrero(frente, "RECICLAJE", Enum.NormalId.Front)
	cartelFlotante(frente, "Contenedor de reciclaje", 4.5, 240)
	prompt(frente, Textos.PATIO.reciclar, "Contenedor", 10)
	return cont, zona
end

local function construirMaquinaRefrescos(caseta, x, z)
	local maq = modelo("MaquinaRefrescos", caseta)
	etiquetar(maq, "MaquinaRefrescos")
	local cuerpo = parte({ Name = "Cuerpo", Size = Vector3.new(4, 7, 3), Position = Vector3.new(x, 4.5, z), Color = Paleta.MUEBLE, Parent = maq })
	parte({ Name = "Ventana", Size = Vector3.new(3, 4, 0.3), Position = Vector3.new(x, 5.5, z + 1.55), Color = Paleta.gris(90), Parent = maq })
	parte({ Name = "Ranura", Size = Vector3.new(2.5, 0.8, 0.4), Position = Vector3.new(x, 2.2, z + 1.55), Color = Paleta.gris(60), Parent = maq })
	maq.PrimaryPart = cuerpo
	letrero(cuerpo, "REFRESCOS", Enum.NormalId.Front, 60)
	prompt(cuerpo, Textos.PATIO.comprarRefresco, "Máquina", 8)
	return maq
end

local function construirCaseta(mundo)
	local caseta = modelo("Caseta", mundo)
	local z = LAYOUT.CASETA_Z
	local color = Paleta.CASETA
	-- Cabina abierta al frente (hacia el patio, +Z): fondo, dos lados y techo
	parte({ Name = "Fondo", Size = Vector3.new(14, 8, 0.6), Position = Vector3.new(0, 5, z - 4), Color = color, Parent = caseta })
	parte({ Name = "LadoOeste", Size = Vector3.new(0.6, 8, 8), Position = Vector3.new(-7, 5, z), Color = color, Parent = caseta })
	parte({ Name = "LadoEste", Size = Vector3.new(0.6, 8, 8), Position = Vector3.new(7, 5, z), Color = color, Parent = caseta })
	local techo = parte({ Name = "Techo", Size = Vector3.new(15, 0.6, 9.5), Position = Vector3.new(0, 9.3, z + 0.5), Color = color, Parent = caseta })
	local mostrador = parte({ Name = "Mostrador", Size = Vector3.new(14, 3.5, 2), Position = Vector3.new(0, 2.75, z + 4), Color = Paleta.MUEBLE, Parent = caseta })
	mostrador.Name = "Mostrador"
	local rotulo = parte({ Name = "Rotulo", Size = Vector3.new(15, 2, 0.6), Position = Vector3.new(0, 10.6, z + 4.5), Color = color, Parent = caseta })
	letrero(rotulo, "DOÑA CHATARRA", Enum.NormalId.Front)
	construirNPC(caseta, z + 1.5)
	local _, zona = construirContenedor(caseta, 14, z + 6)
	construirMaquinaRefrescos(caseta, -13, z + 6)
	return zona
end

local function construirPlaza(mundo)
	local plaza = modelo("Plaza", mundo)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = Vector3.new(0, 0.5, LAYOUT.SPAWN_Z)
	spawn.Anchored = true
	spawn.Color = Paleta.LOSA_PARCELA
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = plaza
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	-- Postes indicadores
	local function poste(x, z, texto)
		local p = parte({ Name = "Poste", Size = Vector3.new(0.6, 6, 0.6), Position = Vector3.new(x, 4, z), Color = Paleta.MUROS, Parent = plaza })
		cartelFlotante(p, texto, 3.8, 260)
	end
	poste(-10, LAYOUT.SPAWN_Z + 8, "Patio de basura ↓")
	poste(10, LAYOUT.SPAWN_Z - 8, "Parcelas ↑ ← →")
	return plaza
end

-- ===========================================================================
-- Parcelas
-- ===========================================================================

-- CFrame del centro de cada parcela, mirando hacia el centro del mapa
-- (LookVector apunta al centro: local -Z es el frente, +Z el fondo).
local function cframesParcelas()
	local lista = {}
	local r = LAYOUT.PARCELA_RADIO
	local offs = LAYOUT.PARCELA_OFFSETS
	-- Norte 1-4 (de oeste a este), Este 5-8 (de norte a sur), Sur 9-12 (de
	-- este a oeste), Oeste 13-16 (de sur a norte): sentido horario.
	for _, x in offs do
		table.insert(lista, Vector3.new(x, 0, -r))
	end
	for _, z in offs do
		table.insert(lista, Vector3.new(r, 0, z))
	end
	for i = #offs, 1, -1 do
		table.insert(lista, Vector3.new(offs[i], 0, r))
	end
	for i = #offs, 1, -1 do
		table.insert(lista, Vector3.new(-r, 0, offs[i]))
	end
	local cframes = {}
	for i, pos in lista do
		local objetivo = Vector3.new(0, 0, 0)
		-- Solo la componente que mira al centro del lado: las parcelas de un
		-- mismo lado quedan paralelas (mas legible que un abanico).
		if math.abs(pos.X) > math.abs(pos.Z) then
			objetivo = Vector3.new(0, 0, pos.Z)
		else
			objetivo = Vector3.new(pos.X, 0, 0)
		end
		cframes[i] = CFrame.lookAt(pos, objetivo)
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

	-- Losa
	local losa = pintable(parte({ Name = "Losa", Size = Vector3.new(lado, 1, lado), CFrame = local_(0, 0.5, 0), Color = Paleta.LOSA_PARCELA, Parent = parcela }), "losa")
	parcela.PrimaryPart = losa

	-- Borde con entrada al frente (frente = -Z local)
	local bordes = carpeta("Borde", parcela)
	local grosor, alto = 0.6, 1
	local yB = 1 + alto / 2
	pintable(parte({ Name = "Fondo", Size = Vector3.new(lado, alto, grosor), CFrame = local_(0, yB, mitad), Color = Paleta.MUROS, Parent = bordes }), "borde")
	pintable(parte({ Name = "Izq", Size = Vector3.new(grosor, alto, lado), CFrame = local_(-mitad, yB, 0), Color = Paleta.MUROS, Parent = bordes }), "borde")
	pintable(parte({ Name = "Der", Size = Vector3.new(grosor, alto, lado), CFrame = local_(mitad, yB, 0), Color = Paleta.MUROS, Parent = bordes }), "borde")
	local entrada = 8
	local tramo = (lado - entrada) / 2
	pintable(parte({ Name = "FrenteIzq", Size = Vector3.new(tramo, alto, grosor), CFrame = local_(-(entrada / 2 + tramo / 2), yB, -mitad), Color = Paleta.MUROS, Parent = bordes }), "borde")
	pintable(parte({ Name = "FrenteDer", Size = Vector3.new(tramo, alto, grosor), CFrame = local_(entrada / 2 + tramo / 2, yB, -mitad), Color = Paleta.MUROS, Parent = bordes }), "borde")

	-- Cartel del dueno, junto a la entrada
	local cartel = parte({ Name = "Cartel", Size = Vector3.new(0.6, 6, 0.6), CFrame = local_(-6, 4, -mitad - 1), Color = Paleta.MUROS, Parent = parcela })
	local bb = cartelFlotante(cartel, Textos.BASE.parcelaLibre, 3.8, 240)
	bb.Name = "CartelDueno"
	prompt(cartel, Textos.PATIO.meGusta, "Base", 10)

	-- Spawn de la parcela (teletransporte a casa)
	marcador("Spawn", local_(0, 3, -10), parcela)

	-- Estanteria al fondo: tablero + 2 estantes + 12 slots
	local estanteria = modelo("Estanteria", parcela)
	estanteria:SetAttribute("Mueble", "Estanteria")
	pintable(parte({ Name = "Tablero", Size = Vector3.new(13, 8, 0.6), CFrame = local_(0, 5, mitad - 1.3), Color = Paleta.MUEBLE, Parent = estanteria }), "mueble")
	local slotsEstanteria = 0
	for fila = 0, 1 do
		local yEst = 3.2 + fila * 3
		local estante = pintable(parte({ Name = "Estante" .. (fila + 1), Size = Vector3.new(13, 0.4, 1.8), CFrame = local_(0, yEst, mitad - 2.5), Color = Paleta.MUEBLE, Parent = estanteria }), "mueble")
		estante.Name = "Estante" .. (fila + 1)
		for col = 0, 5 do
			local xS = -5.5 + col * 2.2
			local slot = marcador("SlotEstanteria", local_(xS, yEst + 1.1, mitad - 2.5), estanteria)
			slotsEstanteria += 1
			slot:SetAttribute("Indice", slotsEstanteria)
		end
	end
	prompt(estanteria:FindFirstChild("Tablero"), Textos.BASE.estanteria, "Estantería", 10)

	-- Radio, en la esquina del fondo a la izquierda
	local radio = modelo("Radio", parcela)
	radio:SetAttribute("Mueble", "Radio")
	local cuerpoRadio = pintable(parte({ Name = "Cuerpo", Size = Vector3.new(3.4, 2.2, 1.6), CFrame = local_(-12, 2.1, mitad - 4), Color = Paleta.MUEBLE, Parent = radio }), "mueble")
	for i, xR in { -0.9, 0.9 } do
		local carrete = parte({ Name = "Carrete" .. i, Size = Vector3.new(0.3, 1.2, 1.2), CFrame = local_(-12 + xR, 2.4, mitad - 4 - 0.95) * CFrame.Angles(0, math.rad(90), 0), Color = Paleta.gris(90), Shape = Enum.PartType.Cylinder, Parent = radio })
		carrete.Name = "Carrete" .. i
	end
	parte({ Name = "Antena", Size = Vector3.new(0.15, 2.5, 0.15), CFrame = local_(-10.6, 4.3, mitad - 4.2), Color = Paleta.gris(90), Parent = radio })
	radio.PrimaryPart = cuerpoRadio
	prompt(cuerpoRadio, Textos.BASE.radio, "Radio", 10)

	-- Mesa de reparacion, a la derecha del fondo
	local mesa = modelo("MesaReparacion", parcela)
	mesa:SetAttribute("Mueble", "MesaReparacion")
	local tablero = pintable(parte({ Name = "Tablero", Size = Vector3.new(6, 0.5, 3), CFrame = local_(11, 3, 10), Color = Paleta.MUEBLE, Parent = mesa }), "mueble")
	for _, dx in { -2.6, 2.6 } do
		for _, dz in { -1.1, 1.1 } do
			parte({ Name = "Pata", Size = Vector3.new(0.5, 2.75, 0.5), CFrame = local_(11 + dx, 1.62, 10 + dz), Color = Paleta.MUEBLE, Parent = mesa })
		end
	end
	parte({ Name = "Lampara", Size = Vector3.new(0.3, 2, 0.3), CFrame = local_(13.5, 4.2, 11), Color = Paleta.gris(90), Parent = mesa })
	mesa.PrimaryPart = tablero
	prompt(tablero, Textos.REPARACION.titulo, "Mesa", 10)

	-- Exhibidor: 6 pedestales a lo largo del lado izquierdo
	local exhibidor = modelo("Exhibidor", parcela)
	exhibidor:SetAttribute("Mueble", "Exhibidor")
	for i = 1, GameConfig.PEDESTALES do
		local zP = -10 + (i - 1) * 4.2
		local ped = pintable(parte({ Name = "Pedestal" .. i, Size = Vector3.new(1.8, 2.4, 1.8), CFrame = local_(-14, 2.2, zP) * CFrame.Angles(0, 0, math.rad(90)), Color = Paleta.MUEBLE, Shape = Enum.PartType.Cylinder, Parent = exhibidor }), "mueble")
		ped.Name = "Pedestal" .. i
		local top = marcador("Pedestal", local_(-14, 3.6, zP), exhibidor)
		top:SetAttribute("Indice", i)
		if i == 1 then
			exhibidor.PrimaryPart = ped
			prompt(ped, Textos.BASE.exhibidor, "Exhibidor", 10)
		end
	end

	-- Telefono para llamar a Dona Chatarra (abre la tienda)
	local telefono = modelo("Telefono", parcela)
	telefono:SetAttribute("Mueble", "Telefono")
	parte({ Name = "Poste", Size = Vector3.new(0.6, 5, 0.6), CFrame = local_(14, 3.5, -8), Color = Paleta.MUROS, Parent = telefono })
	local auricular = pintable(parte({ Name = "Caja", Size = Vector3.new(1.6, 2.2, 1), CFrame = local_(14, 4.6, -7.3), Color = Paleta.MUEBLE, Parent = telefono }), "mueble")
	telefono.PrimaryPart = auricular
	prompt(auricular, "Llamar a Doña Chatarra", "Teléfono", 10)

	-- Almacen (cofre): abre el album / inventario
	local almacen = modelo("Almacen", parcela)
	almacen:SetAttribute("Mueble", "Almacen")
	local cofre = pintable(parte({ Name = "Cofre", Size = Vector3.new(4, 2.4, 3), CFrame = local_(14, 2.2, 3), Color = Paleta.MUEBLE, Parent = almacen }), "mueble")
	parte({ Name = "Tapa", Size = Vector3.new(4.2, 0.5, 3.2), CFrame = local_(14, 3.65, 3), Color = Paleta.gris(190), Parent = almacen })
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
-- Limites del mapa
-- ===========================================================================

local function construirLimites(mundo)
	local limites = carpeta("Limites", mundo)
	local l = LAYOUT.LIMITE
	local h = LAYOUT.LIMITE_ALTURA
	local largo = l * 2 + 2
	local specs = {
		{ Vector3.new(largo, h, 2), Vector3.new(0, h / 2, -l) },
		{ Vector3.new(largo, h, 2), Vector3.new(0, h / 2, l) },
		{ Vector3.new(2, h, largo), Vector3.new(-l, h / 2, 0) },
		{ Vector3.new(2, h, largo), Vector3.new(l, h / 2, 0) },
	}
	for i, s in specs do
		local m = parte({ Name = "Limite" .. i, Size = s[1], Position = s[2], Transparency = 1, CanQuery = false, Parent = limites })
		etiquetar(m, "Limite")
	end
end

-- ===========================================================================
-- API
-- ===========================================================================

function ConstructorMundo.construir(): Model
	limpiarPlace()
	local mundo = modelo("Mundo", workspace)
	mundo:SetAttribute("Version", ConstructorMundo.VERSION)
	local numRanuras, numFigurinas = construirPatio(mundo)
	construirCaseta(mundo)
	construirPlaza(mundo)
	local numParcelas = construirParcelas(mundo)
	construirLimites(mundo)
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
	print(string.format("Patio %dx%d, %d ranuras de monton:", LAYOUT.PATIO_LADO, LAYOUT.PATIO_LADO, #posiciones))
	for t, n in conteo do
		print(string.format("  %s: %d", t, n))
	end
	print(string.format("%d parcelas de %dx%d en anillo a %d studs", GameConfig.NUM_PARCELAS, LAYOUT.PARCELA_LADO, LAYOUT.PARCELA_LADO, LAYOUT.PARCELA_RADIO))
	for i, cf in cframesParcelas() do
		print(string.format("  Parcela_%d en (%.0f, %.0f)", i, cf.Position.X, cf.Position.Z))
	end
	print(string.format("Caseta en z=%d, spawn en z=%d, limites en +-%d", LAYOUT.CASETA_Z, LAYOUT.SPAWN_Z, LAYOUT.LIMITE))
	local existente = workspace:FindFirstChild("Mundo")
	if existente then
		print(string.format("Ya existe workspace.Mundo v%s con %d instancias: construir() lo reemplaza", tostring(existente:GetAttribute("Version")), #existente:GetDescendants()))
	else
		print("No existe workspace.Mundo todavia")
	end
end

ConstructorMundo.LAYOUT = LAYOUT

return ConstructorMundo
