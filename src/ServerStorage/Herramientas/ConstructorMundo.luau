--!nonstrict
--[[
	ConstructorMundo
	Construye TODA la geometria del juego bajo workspace.Mundo a partir de la
	tabla LAYOUT de abajo, en dos capas:

	  1. El ESQUELETO funcional (lo de siempre): suelo, ranuras de monton,
	     caseta, contenedor, plaza, barreras de los cuadrantes, limites. Todo
	     lo que el runtime necesita encontrar lleva TAG de CollectionService o
	     ATRIBUTO, nunca se busca por nombre.
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

	    RanuraMonton      marcador donde Botin instancia un monton (attr
	                      Tamano, Cuadrante y Zona)
	    BarreraCuadrante  pared de un cuadrante que se abre con rebirths
	                      (attr Cuadrante y Rebirth; el servidor le da su
	                      grupo de colision)
	    PuntoAparicion    donde aparece todo el mundo (plaza, mirando al patio)
	    FigurinaFija      marcador de figurina escondida (attr FigurinaId;
	                      solo con la funcion FIGURINAS, pospuesta)
	    Contenedor        el contenedor de reciclaje (hijo ZonaAcierto = punteria)
	    Limite            muros invisibles del borde del mapa
	    SoloDecorado      arte que no hace nada
	    Mundo.Manual      carpeta que el horneado NUNCA borra: lo que el
	                      usuario edita a mano en Studio va ahi

	Plano v4 (diseno v2, 26 sep; N = z negativa, E = x positiva). Sin bases:
	el mapa se recorto por el oeste, donde estaban las parcelas, y la valla
	queda a 24 studs del patio por los tres lados. Cada cuadrante es de un
	material (GameConfig.CUADRANTES); los dos del norte llevan barrera hasta
	el Rebirth 1 (Metal) y 2 (Organico):

	    +------------------------------+  z = -99
	    |  +------------+------------+ |
	    |  | METAL  R1  | ORGANICO R2| |  z = -75..-25 (barreras)
	    |  +------------+------------+ |
	    |  | PAPEL      | PLASTICO   | |
	    |  | PAPEL      | PLASTICO   | |  z = 75
	    |  +------------+------------+ |
	    |  ===== calle + PLAZA (aparicion) ====   z = 96
	    |  | RECICLADORA: caseta      | |  z = 115..161
	    +------------------------------+  z = 177
	   x = -99  -75     -26,25      22,5  46,5

	Entre el borde del patio y la valla queda una franja de cesped de 24
	studs: ahi va el decorado (y los escondites de las figurinas).
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
local Recicladora = require(Config:WaitForChild("Recicladora"))
local ArteMundo = require(script.Parent:WaitForChild("ArteMundo"))

local M = Paleta.MUNDO
local V = Paleta.VARIANTES

local ConstructorMundo = {}
ConstructorMundo.VERSION = 5

-- ===========================================================================
-- LAYOUT
-- ===========================================================================

local LAYOUT = {
	-- El patio es un rectangulo (GameConfig.PATIO, bordes en x y z): lo lee
	-- tambien Patio.posicionEnPatio, asi que manda la config.
	PATIO = GameConfig.PATIO,
	-- Rejilla de 2 columnas x 3 filas de cuadrantes iguales (~49 x 50),
	-- separados por caminos en sus bordes interiores. Cada cuadrante lleva
	-- DOS montones en diagonal (peticion del usuario: se veia vacio) y un
	-- TERCERO chico en la otra diagonal (peticion del usuario: mas montones).
	COLUMNAS = GameConfig.COLUMNAS_PATIO,
	FILAS = GameConfig.FILAS_PATIO,
	-- Hueco entre las faldas de los dos montones de un cuadrante: la basura
	-- de uno no debe brotar dentro de las lomas del otro
	SEPARACION_MONTONES = 6,
	JITTER_MONTON = 1.5,
	-- Los 6 pares {mayor, menor}, uno por cuadrante. Diseno v2: todos
	-- grande + chico, mas el tercero chico = 6 grandes y 12 chicos, lo que
	-- dice GameConfig.TAMANOS_MONTON.cantidad.
	PAREJAS_MONTON = {
		{ "grande", "chico" },
		{ "grande", "chico" },
		{ "grande", "chico" },
		{ "grande", "chico" },
		{ "grande", "chico" },
		{ "grande", "chico" },
	},
	CAMINO_ANCHO = 10,
	-- Al sur del patio, la calle con la plaza del spawn (pavimento pegado al
	-- borde del patio) y detras el lote de tierra de la recicladora, desde el
	-- borde oeste del patio hasta cerca de la valla este, con la caseta en
	-- x = 0 mirando al norte
	PLAZA_ANCHO = 40,
	PLAZA_FONDO = 38,
	SPAWN_Z = 96,
	LOTE_NORTE = 115,
	LOTE_SUR = 161,
	CASETA_Z = 133,
	CALLE_ANCHO = 12,
	-- Limite del mapa: rectangulo con muro invisible alto y la valla de
	-- madera del vertedero por dentro. Al norte, al este y (desde que no hay
	-- parcelas) al oeste queda una franja de cesped de 24 entre el patio y la
	-- valla (el decorado y las figurinas).
	LIMITE = { oeste = -99, este = 46.5, norte = -99, sur = 177 },
	LIMITE_ALTURA = 60,
	-- 10 studs: un personaje salta ~7,5, asi que la valla no se salta aunque
	-- alguien apague el muro invisible
	VALLA_ALTURA = 10,
	VALLA_MARGEN = 1.6,
	-- Barrera de un cuadrante cerrado: mas alta que un salto (~7,5) y metida
	-- un poco hacia dentro de su cuadrante, para que las dos del borde comun
	-- (Metal | Organico) no coincidan
	BARRERA_ALTURA = 11,
	BARRERA_GROSOR = 0.6,
	BARRERA_DENTRO = 0.6,
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

-- El lote de la recicladora (en x del mundo): desde el borde oeste del patio
-- hasta 3 studs antes de la valla este. Es mas ancho que el patio desde que
-- este se recorto por el este; la caseta sigue en x = 0.
local function limitesLote()
	return LAYOUT.PATIO.oeste, LAYOUT.LIMITE.este - 3
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
		ArteMundo.studsSuelo(baseplate)
	end
	return manual
end

-- ===========================================================================
-- Patio compartido
-- ===========================================================================

-- Los bordes de las columnas y filas de cuadrantes: el rectangulo del patio
-- partido en partes iguales. Los caminos van en los bordes interiores.
local function divisiones(desde, hasta, partes)
	local bordes = {}
	for i = 0, partes do
		table.insert(bordes, desde + (hasta - desde) * i / partes)
	end
	return bordes
end

local function bordesCuadrantes()
	local P = LAYOUT.PATIO
	return divisiones(P.oeste, P.este, LAYOUT.COLUMNAS), divisiones(P.norte, P.sur, LAYOUT.FILAS)
end

-- 18 ranuras: tres por cuadrante del 2x3. La pareja va en una diagonal y un
-- chico en la otra, lo justo para no pisar la falda de ninguno de los dos
-- (la suya puede rozar el camino del borde). Las parejas de tamanos
-- se barajan con semilla fija para que hornear dos veces de el mismo patio.
-- En cada cuadrante el mayor y el menor quedan a D = rMayor + rMenor +
-- SEPARACION entre centros, repartidos para que el conjunto este centrado
-- (el borde lejano de cada uno a la misma distancia del centro): con
-- grande+chico eso ocupa +-21,6 alrededor del centro de un cuadrante de
-- ~49 x 50 (la falda puede rozar un par de studs el camino).
local function posicionesRanuras()
	-- Semilla fija (la de siempre: 6 parcelas * 7 + 3): mismas posiciones al
	-- rehornear
	local rng = Random.new(45)
	local parejas = table.clone(LAYOUT.PAREJAS_MONTON)
	for i = #parejas, 2, -1 do
		local j = rng:NextInteger(1, i)
		parejas[i], parejas[j] = parejas[j], parejas[i]
	end
	local function radio(tamano)
		return GameConfig.TAMANOS_MONTON[tamano].radio
	end
	local bx, bz = bordesCuadrantes()
	assert(#parejas == LAYOUT.COLUMNAS * LAYOUT.FILAS, "PAREJAS_MONTON debe tener una pareja por cuadrante")
	local posiciones, tamanos = {}, {}
	local n = 0
	for fila = 1, LAYOUT.FILAS do
		local z0 = (bz[fila] + bz[fila + 1]) / 2
		for columna = 1, LAYOUT.COLUMNAS do
			local x0 = (bx[columna] + bx[columna + 1]) / 2
			n += 1
			local mayor, menor = parejas[n][1], parejas[n][2]
			local rM, rm = radio(mayor), radio(menor)
			local d = rM + rm + LAYOUT.SEPARACION_MONTONES
			local a = (d + rm - rM) / 2
			-- La diagonal alterna de un cuadrante al siguiente
			local u = if (fila + columna) % 2 == 0 then Vector3.new(1, 0, 1).Unit else Vector3.new(1, 0, -1).Unit
			local centro = Vector3.new(x0, 1, z0)
			local j = LAYOUT.JITTER_MONTON
			local jitter = Vector3.new(rng:NextNumber(-j, j), 0, rng:NextNumber(-j, j))
			table.insert(posiciones, centro - u * a + jitter)
			table.insert(tamanos, mayor)
			table.insert(posiciones, centro + u * (d - a) + jitter)
			table.insert(tamanos, menor)
			-- Tercero: chico en la diagonal perpendicular, lado alterno
			local v = Vector3.new(-u.Z, 0, u.X) * (if columna % 2 == 0 then 1 else -1)
			local rc, s = radio("chico"), LAYOUT.SEPARACION_MONTONES
			local t = math.max(
				math.sqrt(math.max(0, (rM + rc + s) ^ 2 - a ^ 2)),
				math.sqrt(math.max(0, (rm + rc + s) ^ 2 - (d - a) ^ 2))
			)
			table.insert(posiciones, centro + v * t + jitter)
			table.insert(tamanos, "chico")
		end
	end
	return posiciones, tamanos
end

-- Las ranuras salen de tres en tres por cuadrante, en orden de lectura
-- (posicionesRanuras recorre filas y columnas igual que CUADRANTES)
local function construirRanuras(patio)
	local ranuras = carpeta("Ranuras", patio)
	local posiciones, tamanos = posicionesRanuras()
	for i, pos in posiciones do
		local cuadrante = math.ceil(i / 3)
		local def = GameConfig.CUADRANTES[cuadrante]
		local m = marcador("Ranura_" .. i, CFrame.new(pos), ranuras)
		m:SetAttribute("Indice", i)
		m:SetAttribute("Tamano", tamanos[i] or "chico")
		m:SetAttribute("Cuadrante", cuadrante)
		m:SetAttribute("Zona", def.zona)
		etiquetar(m, "RanuraMonton")
	end
	return #posiciones
end

-- Rectangulo (x0, x1, z0, z1) del cuadrante i, en orden de lectura
local function rectanguloCuadrante(i)
	local bx, bz = bordesCuadrantes()
	local fila = math.ceil(i / LAYOUT.COLUMNAS)
	local columna = (i - 1) % LAYOUT.COLUMNAS + 1
	return bx[columna], bx[columna + 1], bz[fila], bz[fila + 1]
end

-- Barreras de los cuadrantes que se abren con rebirths: cuatro paredes por
-- cuadrante, mas altas que un salto. Las paredes son la colision (tag
-- BarreraCuadrante; el servidor las pone en el grupo de colision de su
-- rebirth y cada personaje choca o no segun los suyos) y se ven como un
-- cristal del color del material (se ve lo que espera detras); ArteMundo
-- les pone postes y travesanos de obra. Un cartel en la cara que da al patio
-- abierto dice que rebirth hace falta y que zona hay detras.
local function construirBarreras(patio)
	local barreras = carpeta("Barreras", patio)
	local h, g, dentro = LAYOUT.BARRERA_ALTURA, LAYOUT.BARRERA_GROSOR, LAYOUT.BARRERA_DENTRO
	local n = 0
	for i, def in GameConfig.CUADRANTES do
		if def.rebirth <= 0 then
			continue
		end
		local x0, x1, z0, z1 = rectanguloCuadrante(i)
		x0, x1, z0, z1 = x0 + dentro, x1 - dentro, z0 + dentro, z1 - dentro
		local destaca = (GameConfig.ZONAS[def.zona] or {}).destaca
		local color = if destaca then (Paleta.MATERIAL[destaca] or Paleta.MUEBLE) else Paleta.MUEBLE
		local grupo = modelo("Barrera_" .. i, barreras)
		local lados = {
			Sur = { Vector3.new(x1 - x0, h, g), Vector3.new((x0 + x1) / 2, h / 2, z1) },
			Norte = { Vector3.new(x1 - x0, h, g), Vector3.new((x0 + x1) / 2, h / 2, z0) },
			Oeste = { Vector3.new(g, h, z1 - z0), Vector3.new(x0, h / 2, (z0 + z1) / 2) },
			Este = { Vector3.new(g, h, z1 - z0), Vector3.new(x1, h / 2, (z0 + z1) / 2) },
		}
		for lado, s in lados do
			local pared = parte({
				Name = "Pared" .. lado,
				Size = s[1],
				Position = s[2],
				Color = color,
				Material = Enum.Material.Glass,
				Transparency = 0.6,
				CanTouch = false,
				Parent = grupo,
			})
			pared.CastShadow = false
			pared:SetAttribute("Cuadrante", i)
			pared:SetAttribute("Rebirth", def.rebirth)
			etiquetar(pared, "BarreraCuadrante")
			n += 1
			ArteMundo.postesBarrera(grupo, pared)
		end
		-- (sin string.upper: no sabe de tildes, "ORGáNICO")
		local texto = Textos.formatear(Textos.MUNDO.barrera, { n = def.rebirth, zona = Textos.ZONAS[def.zona] or def.zona })
		local cartel = cartelFlotante(grupo:FindFirstChild("ParedSur"), texto, 0, 260)
		-- Adelantado hacia la camara (la Z de StudsOffset va en su espacio): en
		-- el plano de la pared, el cristal lo tapaba al mirarlo de frente
		cartel.StudsOffset = Vector3.new(0, 0, 3)
	end
	return n
end

-- Caminos de tierra entre los cuadrantes (en sus bordes interiores), de
-- borde a borde del patio, y un ensanche en la entrada desde la plaza
-- (borde sur, en x = 0, donde esta la plaza)
local function construirCaminos(patio)
	local caminos = carpeta("Caminos", patio)
	local P = LAYOUT.PATIO
	local ancho = LAYOUT.CAMINO_ANCHO
	local largoX, largoZ = P.este - P.oeste, P.sur - P.norte
	local cx, cz = (P.oeste + P.este) / 2, (P.norte + P.sur) / 2
	local bx, bz = bordesCuadrantes()
	local semilla = 10
	for i = 2, #bx - 1 do
		semilla += 1
		ArteMundo.caminoTierra(caminos, CFrame.new(bx[i], 1, cz), ancho, largoZ - 4, semilla)
	end
	for i = 2, #bz - 1 do
		semilla += 1
		ArteMundo.caminoTierra(caminos, CFrame.new(cx, 1, bz[i]) * CFrame.Angles(0, math.rad(90), 0), ancho, largoX - 4, semilla)
	end
	ArteMundo.caminoTierra(caminos, CFrame.new(0, 1, P.sur - 6), ancho + 8, 12, 99)
end

-- Seis siluetas estaticas que ademas son los escondites de las figurinas.
-- Todas a mas de 20 studs de cualquier ranura: la basura que brota dentro
-- de una silueta con colision sale disparada hacia el suelo. Con dos
-- montones por cuadrante el patio no deja sitio, asi que van FUERA, en la
-- franja de cesped entre el patio y la valla (norte y este): alli el suelo
-- es el baseplate, a y = 0, un stud por debajo del patio.
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
	silueta({ Name = "Cuerpo", Size = Vector3.new(6, 7, 6), Position = Vector3.new(-60, 3.5, -86), Color = M.PARED, Material = Enum.Material.Plaster }).Parent = lavadora
	local puerta = silueta({ Name = "Puerta", Size = Vector3.new(0.4, 3.6, 3.6), CFrame = CFrame.new(-60, 3, -82.8) * CFrame.Angles(0, math.rad(90), 0), Shape = Enum.PartType.Cylinder, Color = M.CRISTAL, Material = Enum.Material.Glass })
	puerta.Parent = lavadora
	silueta({ Name = "Marco", Size = Vector3.new(0.5, 4.2, 4.2), CFrame = CFrame.new(-60, 3, -82.9) * CFrame.Angles(0, math.rad(90), 0), Shape = Enum.PartType.Cylinder, Color = M.METAL, Material = Enum.Material.Metal }).Parent = lavadora
	silueta({ Name = "Oxido", Size = Vector3.new(2, 1.4, 0.1), Position = Vector3.new(-58.5, 1.2, -82.95), Color = M.OXIDO, Material = Enum.Material.CorrodedMetal }).Parent = lavadora
	escondites.F5 = CFrame.new(-60, 0.8, -82)

	-- Pila de neumaticos (F6 encima)
	local neumaticos = modelo("PilaNeumaticos", decorado)
	for i = 0, 2 do
		local n = silueta({ Name = "Neumatico" .. i, Size = Vector3.new(1.4, 6, 6), CFrame = CFrame.new(34.5, 0.7 + i * 1.4, -86) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = M.GOMA, Material = Enum.Material.Rubber })
		n.Parent = neumaticos
		silueta({ Name = "Llanta" .. i, Size = Vector3.new(1.46, 3, 3), CFrame = CFrame.new(34.5, 0.7 + i * 1.4, -86) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = M.METAL, Material = Enum.Material.Metal }).Parent = neumaticos
	end
	escondites.F6 = CFrame.new(34.5, 4.4, -86)

	-- Tubo tumbado (F2 en la boca)
	local tubo = silueta({ Name = "TuboTumbado", Size = Vector3.new(14, 5, 5), CFrame = CFrame.new(34.5, 2.5, 0) * CFrame.Angles(0, math.rad(90), 0), Shape = Enum.PartType.Cylinder, Color = M.OXIDO, Material = Enum.Material.CorrodedMetal })
	tubo.Name = "TuboTumbado"
	escondites.F2 = CFrame.new(34.5, 0.6, 8)

	-- Rampa a un puente bajo (F4 debajo del puente)
	local puente = modelo("Puente", decorado)
	local madera = Enum.Material.WoodPlanks
	silueta({ Name = "Tablero", Size = Vector3.new(10, 1, 10), Position = Vector3.new(34.5, 5.5, 45), Color = M.MADERA, Material = madera, Variante = V.madera }).Parent = puente
	for nombre, pos in { PilarA = Vector3.new(30, 2.5, 49.5), PilarB = Vector3.new(39, 2.5, 49.5), PilarC = Vector3.new(30, 2.5, 40.5), PilarD = Vector3.new(39, 2.5, 40.5) } do
		silueta({ Name = nombre, Size = Vector3.new(1, 5, 1), Position = pos, Color = M.VIGA, Material = Enum.Material.Wood }).Parent = puente
	end
	local rampa = cuna({ Name = "Rampa", Size = Vector3.new(10, 6, 14), CFrame = CFrame.new(34.5, 3, 57) * CFrame.Angles(0, math.rad(180), 0), Color = M.MADERA, Material = madera, Variante = V.madera, Parent = puente })
	rampa.CanQuery = false
	etiquetar(rampa, "SoloDecorado")
	escondites.F4 = CFrame.new(34.5, 0.6, 45)

	-- Contenedor grande detras del patio, lejos de la entrada (F3 encima)
	local contenedor = silueta({ Name = "ContenedorGrande", Size = Vector3.new(10, 6, 5), Position = Vector3.new(0, 3, -87), Color = M.OXIDO, Material = Enum.Material.CorrodedMetal })
	contenedor.Name = "ContenedorGrande"
	escondites.F3 = CFrame.new(0, 6.6, -87)

	-- Esquina de muro caida, al norte del patio
	local esquina = modelo("EsquinaMuro", decorado)
	silueta({ Name = "TramoA", Size = Vector3.new(12, 3.5, 1.5), Position = Vector3.new(-30, 1.75, -87), Color = M.HORMIGON, Material = Enum.Material.Concrete }).Parent = esquina
	silueta({ Name = "TramoB", Size = Vector3.new(1.5, 3.5, 10), Position = Vector3.new(-24.75, 1.75, -81.25), Color = M.HORMIGON, Material = Enum.Material.Concrete }).Parent = esquina

	-- Props sueltos alrededor del patio: barriles, bolsas y neumaticos
	ArteMundo.barril(decorado, CFrame.new(-80, 0, -40), M.AZUL_MAQUINA)
	ArteMundo.barril(decorado, CFrame.new(-82, 0, -36.5), M.OXIDO)
	ArteMundo.bolsaBasura(decorado, CFrame.new(36.5, 0, 20), 21)
	ArteMundo.bolsaBasura(decorado, CFrame.new(39, 0, 22), 22)
	ArteMundo.pilaNeumaticos(decorado, CFrame.new(-55, 0, 83), 2, 23)
	ArteMundo.pilaNeumaticos(decorado, CFrame.new(32, 0, 84), 4, 24)

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
	local P = LAYOUT.PATIO
	-- 4 studs de grosor (hundido en el baseplate): con 1 stud, la basura que
	-- cae desde lo alto de las montanas atravesaba el suelo y acababa sobre
	-- el baseplate
	ArteMundo.studsSuelo(parte({ Name = "Suelo", Size = Vector3.new(P.este - P.oeste, 4, P.sur - P.norte), Position = Vector3.new((P.oeste + P.este) / 2, -1, (P.norte + P.sur) / 2), Color = M.CESPED, Material = Enum.Material.SmoothPlastic, Variante = V.cesped, Parent = patio }))
	-- Borde rojo sobre el canto del suelo: marca el patio frente al cesped de
	-- alrededor (mismo verde). Solo decorado, no colisiona ni entra en raycasts
	local ancho, largo, grosor = P.este - P.oeste, P.sur - P.norte, 1.5
	local cx, cz = (P.oeste + P.este) / 2, (P.norte + P.sur) / 2
	for _, b in { { ancho, 0, -(largo - grosor) / 2 }, { ancho, 0, (largo - grosor) / 2 }, { grosor, -(ancho - grosor) / 2, 0 }, { grosor, (ancho - grosor) / 2, 0 } } do
		local sx = b[1]
		local sz = if sx == grosor then largo else grosor
		local borde = parte({ Name = "BordePatio", Size = Vector3.new(sx, 0.2, sz), Position = Vector3.new(cx + b[2], 1.1, cz + b[3]), Color = M.BORDE_PATIO, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CanTouch = false, Parent = patio })
		etiquetar(borde, "SoloDecorado")
	end
	local numRanuras = construirRanuras(patio)
	-- Cada cuadrante con su suelo, sin tapar los caminos del medio (van en
	-- los bordes interiores) ni el borde rojo del patio: tierra en el patio
	-- abierto (basura revuelta) y el color del material que destaca en las
	-- zonas ricas del norte
	local colores = carpeta("ColoresCuadrantes", patio)
	local mitadCamino = LAYOUT.CAMINO_ANCHO / 2
	for i, def in GameConfig.CUADRANTES do
		local x0, x1, z0, z1 = rectanguloCuadrante(i)
		x0 += if x0 > P.oeste then mitadCamino else 1.5
		x1 -= if x1 < P.este then mitadCamino else 1.5
		z0 += if z0 > P.norte then mitadCamino else 1.5
		z1 -= if z1 < P.sur then mitadCamino else 1.5
		local destaca = (GameConfig.ZONAS[def.zona] or {}).destaca
		local color = if destaca then (Paleta.MATERIAL[destaca] or M.TIERRA) else M.TIERRA
		ArteMundo.sueloCuadrante(colores, Vector3.new((x0 + x1) / 2, 1.04, (z0 + z1) / 2), x1 - x0, z1 - z0, color)
	end
	construirCaminos(patio)
	local escondites = construirDecorado(patio)
	local numFigurinas = if GameConfig.activa("FIGURINAS") then construirFigurinasFijas(patio, escondites) else 0
	local numBarreras = construirBarreras(patio)
	return numRanuras, numFigurinas, numBarreras
end

-- ===========================================================================
-- Recicladora de Dona Chatarra: caseta, contenedor y el lote
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
	prompt(torso, Textos.PATIO.tienda, "Doña Chatarra", 10)
	ArteMundo.vestirChatarra(npc)
	return npc
end

-- Colision de la recicladora de Blender (la malla no colisiona): cajas y
-- losas invisibles de Config/Recicladora en el marco del pivote de la malla
-- (el suelo bajo el volquete, +Z al frente). Con CanQuery: la bolsa lanzada
-- rebota en ellas y el apuntado las ve (Lanzamiento barre lo consultable).
local function construirColisionRecicladora(caseta, pivote)
	local carpeta = Instance.new("Folder")
	carpeta.Name = "ColisionRecicladora"
	carpeta.Parent = caseta
	local function caja(nombre, cf, tamano)
		parte({ Name = nombre, Size = tamano, CFrame = cf, Color = Paleta.CONTENEDOR, Transparency = 1, Parent = carpeta })
	end
	for _, c in Recicladora.COLISION_CAJAS do
		caja(c.nombre, pivote * CFrame.new(c.centro), c.tamano)
	end
	for _, l in Recicladora.COLISION_LOSAS do
		local largo = (l.hasta - l.desde).Magnitude
		local cf = CFrame.lookAt((l.desde + l.hasta) / 2, l.hasta) * CFrame.new(0, -l.grosor / 2 + 0.3, 0)
		caja(l.nombre, pivote * cf, Vector3.new(l.ancho, l.grosor, largo))
	end
end

-- cf = suelo bajo el centro del contenedor; la pared del frente (con el
-- prompt) queda en +Z local, hacia la plaza. Alto 4,7: el del volquete verde
-- de la recicladora de Blender (decision del usuario: manda el modelo, asi
-- los rodillos de la trituradora se ven por encima del borde).
local function construirContenedor(caseta, cf)
	local cont = modelo("Contenedor", caseta)
	etiquetar(cont, "Contenedor")
	local color = Paleta.CONTENEDOR
	local ancho, alto, fondo, grosor = 8, 4.7, 6, 0.5
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
	-- La recicladora de Blender (volquete verde + trituradora + cinta en L +
	-- salida) si el place tiene la malla: las paredes whitebox siguen
	-- colisionando y llevando el prompt, pero no se ven. Sin malla, el
	-- decorado de partes de siempre.
	if ArteMundo.recicladora(caseta, cf) then
		for _, p in cont:GetChildren() do
			ArteMundo.ocultar(p)
		end
		construirColisionRecicladora(caseta, cf * CFrame.new(0, 1, 0))
	else
		ArteMundo.contenedorVerde(caseta, cont)
		ArteMundo.trituradora(caseta, cf * CFrame.new(0, 1, -6.8))
	end
	return cont, zona
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
	local loteOeste, loteEste = limitesLote()
	ArteMundo.loteTierra(caseta, CFrame.new((loteOeste + loteEste) / 2, 0, (LAYOUT.LOTE_NORTE + LAYOUT.LOTE_SUR) / 2), loteEste - loteOeste, LAYOUT.LOTE_SUR - LAYOUT.LOTE_NORTE, 50)
	-- Solera de hormigon bajo la caseta, el contenedor y la
	-- recicladora (hasta x=38 local: la salida de bloques acaba en x~34)
	ArteMundo.studsSuelo(parte({ Name = "Solera", Size = Vector3.new(70, 1, 30), CFrame = en(3, 0.5, 1), Color = M.HORMIGON, Material = Enum.Material.Concrete, Parent = caseta }))
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
	-- x=22,5: la cinta en L y la caja gris de la recicladora llegan 9,5 studs
	-- a la izquierda del contenedor y la cabana ocupa hasta x=11,3
	local _, zona = construirContenedor(caseta, en(22.5, 0, 6))
	-- Chatarra sobre la solera, junto a la cabana
	ArteMundo.pilaNeumaticos(caseta, en(-29, 1, 4), 3, 31)
	ArteMundo.barril(caseta, en(-30, 1, 11), M.OXIDO)
	ArteMundo.bolsaBasura(caseta, en(-27, 1, 10), 32)
	-- El resto del lote, sobre la tierra: camiones abandonados, neumaticos,
	-- barriles, cajas y un contenedor viejo. En x local el lote va de -43,5
	-- (valla este) a 75 (borde oeste del patio, donde empieza la calle).
	ArteMundo.camion(caseta, en(44, tierra, 6) * CFrame.Angles(0, math.rad(-25), 0))
	ArteMundo.pilaNeumaticos(caseta, en(58, tierra, 8), 4, 33)
	ArteMundo.barril(caseta, en(64, tierra, 2), M.AZUL_MAQUINA)
	ArteMundo.barril(caseta, en(66.6, tierra, 4.4), M.OXIDO)
	ArteMundo.caja(caseta, en(70, tierra, -2), Vector3.new(3, 2.6, 2.8))
	ArteMundo.caja(caseta, en(70.3, tierra + 2.6, -1.7) * CFrame.Angles(0, math.rad(20), 0), Vector3.new(2.4, 2, 2.2))
	ArteMundo.bolsaBasura(caseta, en(69, tierra, 7), 34)
	ArteMundo.bolsaBasura(caseta, en(71.5, tierra, 4.4), 35)
	pieza({ Name = "ContenedorViejo", Size = Vector3.new(10, 6, 5), CFrame = en(62, tierra + 3, -9) * CFrame.Angles(0, math.rad(8), 0), Color = M.OXIDO, Material = Enum.Material.CorrodedMetal, Parent = caseta })
	-- Lado este (x local negativa): entre la solera (-32) y el borde del lote
	-- (-43,5) solo queda una franja de 11; el segundo camion ya no cabe
	ArteMundo.barril(caseta, en(-37, tierra, 12), M.OXIDO)
	ArteMundo.barril(caseta, en(-39.6, tierra, 9.6), M.AZUL_MAQUINA)
	ArteMundo.barril(caseta, en(-37.4, tierra, 7.3), M.AMARILLO)
	ArteMundo.pilaNeumaticos(caseta, en(-38, tierra, -20), 5, 36)
	ArteMundo.caja(caseta, en(-40, tierra, -4), Vector3.new(2.8, 2.4, 2.6))
	ArteMundo.caja(caseta, en(-37.5, tierra, -5.4) * CFrame.Angles(0, math.rad(-30), 0), Vector3.new(2.2, 1.8, 2))
	ArteMundo.bolsaBasura(caseta, en(-38, tierra, -10), 37)
	-- Postes de luz con cables a lo largo del frente del lote (la calle)
	local anteriores = nil
	for _, x in { -42, -14, 14, 42, 70 } do
		local _, puntos = ArteMundo.posteLuz(caseta, en(x, tierra, 17.4))
		if anteriores then
			ArteMundo.cables(anteriores, puntos)
		end
		anteriores = puntos
	end
	return zona
end

-- Plaza: el cruce de caminos entre el patio y la recicladora. Todos aparecen
-- aqui (PuntoAparicion), mirando al patio (diseno v2: sin base).
local function construirPlaza(mundo)
	local plaza = modelo("Plaza", mundo)
	-- Sin pavimento (decision del usuario, 24 sep): la plaza es solo el cruce
	-- de caminos con el poste indicador. "Arriba" es el norte: el patio
	posteSenal(plaza, 17, LAYOUT.PATIO.sur + 4, Textos.MUNDO.patio, 0, 0.9)
	local punto = marcador("PuntoAparicion", CFrame.lookAt(Vector3.new(0, 1, LAYOUT.SPAWN_Z), Vector3.new(0, 1, 0)), plaza)
	etiquetar(punto, "PuntoAparicion")
	return plaza
end

-- ===========================================================================
-- Calles y limites del mapa
-- ===========================================================================

-- La calle de tierra de la plaza, fuera del patio (sobre el baseplate, a
-- y = 0): cruza de la valla oeste al extremo este del lote.
local function construirCalles(mundo)
	local calles = carpeta("Calles", mundo)
	local ancho = LAYOUT.CALLE_ANCHO
	local xOeste = LAYOUT.LIMITE.oeste + LAYOUT.VALLA_MARGEN + 2
	local _, loteEste = limitesLote()
	local xEste = loteEste - 4
	ArteMundo.caminoTierra(calles, CFrame.new((xOeste + xEste) / 2, 0, LAYOUT.SPAWN_Z) * CFrame.Angles(0, math.rad(90), 0), ancho, xEste - xOeste, 70)
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
	local numRanuras, numFigurinas, numBarreras = construirPatio(mundo)
	construirCaseta(mundo)
	construirPlaza(mundo)
	construirCalles(mundo)
	construirLimites(mundo)
	ConstructorMundo.iluminar()
	print(string.format(
		"ConstructorMundo: mundo v%d construido (%d ranuras, %d barreras, %d figurinas fijas, %d instancias)",
		ConstructorMundo.VERSION,
		numRanuras,
		numBarreras,
		numFigurinas,
		#mundo:GetDescendants()
	))
	return mundo
end

-- Rehace solo la tienda sobre el workspace.Mundo existente, sin hornear todo
-- (hornear borra Mundo salvo Manual). Sirve tras importar o reexportar la
-- malla de ServerStorage.Arte.Tienda
function ConstructorMundo.rehacerTienda(): string
	local mundo = workspace:FindFirstChild("Mundo")
	assert(mundo, "no hay workspace.Mundo: hay que hornear primero")
	local caseta = mundo:FindFirstChild("Caseta")
	local cabana = caseta and caseta:FindFirstChild("Cabana")
	if cabana then
		cabana:Destroy()
	end
	local tienda = if caseta then ArteMundo.caseta(caseta, CFrame.new(0, 0, LAYOUT.CASETA_Z) * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 1, 0)) else nil
	return "tienda " .. (if tienda then (if tienda:FindFirstChild("Tienda_Coral", true) then "de malla" else "de partes") else "sin caseta")
end

function ConstructorMundo.previsualizar()
	local posiciones, tamanos = posicionesRanuras()
	local conteo = {}
	for _, t in tamanos do
		conteo[t] = (conteo[t] or 0) + 1
	end
	local P = LAYOUT.PATIO
	print(string.format("Patio x=%.1f..%.1f z=%.1f..%.1f, %d ranuras de monton:", P.oeste, P.este, P.norte, P.sur, #posiciones))
	for t, n in conteo do
		print(string.format("  %s: %d", t, n))
	end
	for i, def in GameConfig.CUADRANTES do
		local x0, x1, z0, z1 = rectanguloCuadrante(i)
		print(string.format("  Cuadrante %d: %s (rebirth %d) x=%.1f..%.1f z=%.1f..%.1f", i, def.zona, def.rebirth, x0, x1, z0, z1))
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
