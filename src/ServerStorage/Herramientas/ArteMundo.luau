--!nonstrict
--[[
	ArteMundo
	Las piezas de ARTE low-poly del mundo (pasada de color, referencia
	KOTAMON): cabana de madera de Dona Chatarra, maquina de refrescos azul,
	trituradora amarilla, contenedor verde, vallas, postes con cables,
	camion abandonado, neumaticos, barriles, caminos de tierra y la propia
	Dona Chatarra. ConstructorMundo las coloca sobre el esqueleto whitebox.

	Regla: el whitebox sigue siendo el esqueleto funcional. Nada de lo que hay
	aqui colisiona, entra en raycasts ni lleva tags de juego: todo es
	`SoloDecorado` (CanCollide/CanQuery/CanTouch = false) y se apoya en las
	cajas invisibles que ya hacen de pared, suelo y prompt. Por eso ninguna
	prueba ni servicio se entera de que el mundo tiene arte.

	Mallas generadas por IA (generate_mesh del MCP): si existe
	ServerStorage.Arte.<Nombre> (Camion; Arbol ya no se usa) se clona en vez de construir
	la version de partes. Viven en el place, no en git; sin ellas, el respaldo
	de partes se ve bien igualmente. Lo mismo con las variantes de material
	(Paleta.VARIANTES): se asignan por nombre y si no existen no pasa nada.

	Convencion de cada pieza: recibe (padre, cf) con cf = pivote en el suelo
	bajo el centro y el frente hacia -Z local (CFrame.lookAt desde el centro
	del mapa da eso). Devuelve el Model.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local M = Paleta.MUNDO
local V = Paleta.VARIANTES

local ArteMundo = {}

local FUENTE_PEGATINA = Font.new("rbxasset://fonts/families/FredokaOne.json")
-- La caseta y sus maquinas miran a +Z LOCAL (hacia la plaza y el patio;
-- ConstructorMundo las construye sobre un pivote girado para que ese +Z sea
-- el norte): la cara que se ve es la "Back" de Roblox (Front es -Z)
local CARA_PATIO = Enum.NormalId.Back

-- ===========================================================================
-- Ladrillos
-- ===========================================================================

local function decorar(inst)
	CollectionService:AddTag(inst, "SoloDecorado")
	return inst
end

-- Parte decorativa: anclada, sin colision ni query. props: Name, Size,
-- CFrame|Position, Color, Material, Variante, Shape, Transparency,
-- Reflectance, Parent, Colision (true para las pocas que si bloquean),
-- Sombra (true en las piezas grandes que proyectan sombra)
local function parte(props)
	local p = Instance.new(props.Shape == "Wedge" and "WedgePart" or "Part")
	p.Anchored = true
	p.CanCollide = props.Colision == true
	p.CanQuery = props.Colision == true
	p.CanTouch = false
	-- Sin sombra propia salvo que la pieza lo pida (Sombra = true): en movil
	-- cada parte que proyecta sombra cuesta, y las pequenas no se notan
	p.CastShadow = props.Sombra == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.Name or "Arte"
	p.Size = props.Size or Vector3.new(1, 1, 1)
	p.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	p.Color = props.Color or M.MADERA
	p.Material = props.Material or Enum.Material.SmoothPlastic
	if props.Variante then
		p.MaterialVariant = props.Variante
	end
	if props.Shape and props.Shape ~= "Wedge" then
		p.Shape = props.Shape
	end
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	if props.Reflectance then
		p.Reflectance = props.Reflectance
	end
	p.Parent = props.Parent
	return decorar(p)
end

local function cilindroVertical(props)
	props.Shape = Enum.PartType.Cylinder
	local d, alto = props.Diametro, props.Alto
	props.Size = Vector3.new(alto, d, d)
	props.CFrame = props.CFrame * CFrame.Angles(0, 0, math.rad(90))
	return parte(props)
end

local function cilindroEjeZ(props)
	props.Shape = Enum.PartType.Cylinder
	local d, largo = props.Diametro, props.Largo
	props.Size = Vector3.new(largo, d, d)
	props.CFrame = props.CFrame * CFrame.Angles(0, math.rad(90), 0)
	return parte(props)
end

local function cilindroEjeX(props)
	props.Shape = Enum.PartType.Cylinder
	local d, largo = props.Diametro, props.Largo
	props.Size = Vector3.new(largo, d, d)
	return parte(props)
end

local function bola(props)
	props.Shape = Enum.PartType.Ball
	local d = props.Diametro
	props.Size = Vector3.new(d, d, d)
	return parte(props)
end

local function modelo(nombre, padre)
	local m = Instance.new("Model")
	m.Name = nombre
	m.Parent = padre
	return decorar(m)
end

-- Repinta una parte del whitebox sin tocar su geometria ni sus tags
function ArteMundo.pintar(p, material, color, variante)
	if not p or not p:IsA("BasePart") then
		return p
	end
	p.Material = material or p.Material
	if color then
		p.Color = color
	end
	if variante then
		p.MaterialVariant = variante
	end
	return p
end

-- Una caja funcional del whitebox que el arte tapa: sigue colisionando y
-- llevando sus prompts, pero no se ve
function ArteMundo.ocultar(p)
	if p and p:IsA("BasePart") then
		p.Transparency = 1
	end
	return p
end

-- Rotulo en estilo pegatina (papel crema, contorno de tinta, FredokaOne),
-- el mismo lenguaje que la UI. En una cara de la parte.
function ArteMundo.letreroPegatina(parteBase, texto, cara, opciones)
	opciones = opciones or {}
	cara = cara or Enum.NormalId.Front
	-- Un letrero por cara: asi una tabla puede leerse por delante y por detras
	local nombre = "Letrero" .. cara.Name
	local viejo = parteBase:FindFirstChild(nombre)
	if viejo then
		viejo:Destroy()
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = nombre
	sg.Face = cara
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.AlwaysOnTop = false
	sg.Parent = parteBase
	local fondo = Instance.new("Frame")
	fondo.Name = "Papel"
	fondo.Size = UDim2.new(1, -16, 1, -16)
	fondo.Position = UDim2.fromScale(0.5, 0.5)
	fondo.AnchorPoint = Vector2.new(0.5, 0.5)
	fondo.BackgroundColor3 = opciones.fondo or Paleta.UI_PAPEL
	fondo.BackgroundTransparency = if opciones.sinPapel then 1 else 0
	fondo.BorderSizePixel = 0
	fondo.Parent = sg
	local esquinas = Instance.new("UICorner")
	esquinas.CornerRadius = UDim.new(0.18, 0)
	esquinas.Parent = fondo
	if not opciones.sinPapel then
		local borde = Instance.new("UIStroke")
		borde.Color = Paleta.UI_TINTA
		borde.Thickness = 4
		borde.Parent = fondo
	end
	local tl = Instance.new("TextLabel")
	tl.Name = "Texto"
	tl.Size = UDim2.new(1, -24, 1, -12)
	tl.Position = UDim2.fromScale(0.5, 0.5)
	tl.AnchorPoint = Vector2.new(0.5, 0.5)
	tl.BackgroundTransparency = 1
	tl.Text = texto
	tl.TextColor3 = opciones.color or Paleta.UI_TINTA
	tl.TextScaled = true
	tl.FontFace = FUENTE_PEGATINA
	tl.Parent = fondo
	if opciones.contorno then
		local contorno = Instance.new("UIStroke")
		contorno.Color = opciones.contorno
		contorno.Thickness = 3
		contorno.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		contorno.Parent = tl
	end
	return sg
end

-- Malla generada por IA guardada en ServerStorage.Arte (o workspace.Arte si
-- el hilo del MCP no pudo moverla). nil si no existe.
local function mallaArte(nombre)
	for _, raiz in { ServerStorage, workspace } do
		local arte = raiz:FindFirstChild("Arte")
		local m = arte and arte:FindFirstChild(nombre)
		if m and (m:IsA("Model") or m:IsA("BasePart")) then
			return m
		end
	end
	return nil
end

-- Clona una malla de arte, la deja decorativa y la coloca con el pivote en
-- el suelo y el largo pedido (escala uniforme por el eje mayor)
local function clonarMalla(nombre, padre, cf, largoObjetivo)
	local original = mallaArte(nombre)
	if not original then
		return nil
	end
	local copia = original:Clone()
	local m = copia
	if copia:IsA("BasePart") then
		m = Instance.new("Model")
		m.Name = nombre
		copia.Parent = m
		m.PrimaryPart = copia
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			decorar(d)
			if d:IsA("MeshPart") then
				-- LOD automatico y colision de caja: no colisiona, pero la malla
				-- de colision precisa igual ocupa memoria
				d.RenderFidelity = Enum.RenderFidelity.Automatic
				d.CollisionFidelity = Enum.CollisionFidelity.Box
			end
		end
	end
	decorar(m)
	m.Parent = padre
	local bcf, tamano = m:GetBoundingBox()
	local mayor = math.max(tamano.X, tamano.Y, tamano.Z)
	if largoObjetivo and mayor > 0 then
		m:ScaleTo(largoObjetivo / mayor)
		bcf, tamano = m:GetBoundingBox()
	end
	-- Pivote en el suelo bajo el centro de la caja
	m.WorldPivot = bcf * CFrame.new(0, -tamano.Y / 2, 0)
	if m.PrimaryPart then
		m.PrimaryPart.PivotOffset = m.PrimaryPart.CFrame:Inverse() * m.WorldPivot
	end
	m:PivotTo(cf)
	return m
end

-- ===========================================================================
-- Vallas, muros y caminos
-- ===========================================================================

-- Valla de madera entre dos puntos (a ras de suelo): postes cada 4 studs,
-- dos travesanos largos (una parte cada uno) y tablas verticales con un
-- poco de inclinacion, como una cerca de vertedero.
function ArteMundo.valla(padre, desde, hasta, alto, semilla)
	local rng = Random.new(semilla or 1)
	local m = modelo("Valla", padre)
	local dir = (hasta - desde)
	local largo = dir.Magnitude
	if largo < 1 then
		return m
	end
	dir = dir.Unit
	local centro = (desde + hasta) / 2
	local cf = CFrame.lookAt(centro, centro + dir) * CFrame.Angles(0, math.rad(90), 0) -- X local = a lo largo
	alto = alto or 5
	-- Travesanos
	for _, f in { 0.42, 0.82 } do
		parte({ Name = "Travesano", Size = Vector3.new(largo, 0.35, 0.25), CFrame = cf * CFrame.new(0, alto * f, -0.2), Color = M.VIGA, Material = Enum.Material.Wood, Parent = m })
	end
	-- Postes cada 6 studs y UNA tabla ancha por vano (el material de tablas
	-- ya dibuja las juntas): la valla rodea todo el mapa y con una tabla por
	-- cada 1,25 studs eran ~1.300 partes, demasiado para movil
	local vano = 6
	local n = math.max(1, math.floor(largo / vano + 0.5))
	local ancho = largo / n
	for i = 0, n do
		local x = -largo / 2 + ancho * i
		parte({ Name = "Poste", Size = Vector3.new(0.55, alto + 0.4, 0.55), CFrame = cf * CFrame.new(x, (alto + 0.4) / 2, -0.35), Color = M.VALLA, Material = Enum.Material.Wood, Parent = m })
	end
	for i = 0, n - 1 do
		local x = -largo / 2 + ancho * (i + 0.5)
		local tono = 0.85 + rng:NextNumber(0, 0.3)
		local h = alto - 0.6 + rng:NextNumber(-0.25, 0.25)
		parte({
			Name = "Tabla",
			Size = Vector3.new(ancho - 0.5, h, 0.2),
			CFrame = cf * CFrame.new(x, h / 2 + 0.3, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-1, 1))),
			Color = Paleta.escalar(M.MADERA, tono),
			Material = Enum.Material.WoodPlanks,
			Variante = V.madera,
			Parent = m,
		})
	end
	return m
end

-- Muro alto de tablas para el limite del mapa: barato (una tabla gigante
-- por lado con material de tablas y una viga encima)
function ArteMundo.muroTablas(padre, cf, largo, alto)
	local m = modelo("MuroTablas", padre)
	parte({ Name = "Tablas", Size = Vector3.new(largo, alto, 1), CFrame = cf * CFrame.new(0, alto / 2, 0), Color = M.VALLA, Material = Enum.Material.WoodPlanks, Variante = V.madera, Sombra = true, Parent = m })
	parte({ Name = "Remate", Size = Vector3.new(largo, 0.6, 1.4), CFrame = cf * CFrame.new(0, alto + 0.3, 0), Color = M.VIGA, Material = Enum.Material.Wood, Parent = m })
	return m
end

-- Camino de tierra: una losa finisima sobre el cesped, sin colision (se
-- camina sobre el suelo real)
function ArteMundo.caminoTierra(padre, cf, ancho, largo, semilla)
	local rng = Random.new(semilla or 1)
	local m = modelo("Camino", padre)
	parte({ Name = "Tierra", Size = Vector3.new(ancho, 0.12, largo), CFrame = cf * CFrame.new(0, 0.06, 0), Color = M.TIERRA, Material = Enum.Material.Ground, Variante = V.tierra, Parent = m })
	-- Manchas mas oscuras (rodadas)
	for _ = 1, math.max(1, math.floor(largo / 30)) do
		local z = rng:NextNumber(-largo / 2 + 5, largo / 2 - 5)
		parte({ Name = "Rodada", Size = Vector3.new(ancho * 0.5, 0.14, rng:NextNumber(6, 12)), CFrame = cf * CFrame.new(rng:NextNumber(-ancho * 0.2, ancho * 0.2), 0.07, z) * CFrame.Angles(0, math.rad(rng:NextNumber(-8, 8)), 0), Color = M.TIERRA_OSCURA, Material = Enum.Material.Ground, Variante = V.tierra, Parent = m })
	end
	return m
end

-- Lote de tierra pisada (la explanada de la recicladora): losa de Ground con
-- manchas mas oscuras repartidas al azar, sin colision
function ArteMundo.loteTierra(padre, cf, ancho, largo, semilla)
	local rng = Random.new(semilla or 1)
	local m = modelo("Lote", padre)
	parte({ Name = "Tierra", Size = Vector3.new(ancho, 0.12, largo), CFrame = cf * CFrame.new(0, 0.06, 0), Color = M.TIERRA, Material = Enum.Material.Ground, Variante = V.tierra, Parent = m })
	for _ = 1, math.max(2, math.floor(ancho * largo / 900)) do
		local sx, sz = rng:NextNumber(6, 16), rng:NextNumber(4, 10)
		local x = rng:NextNumber(-ancho / 2 + sx, ancho / 2 - sx)
		local z = rng:NextNumber(-largo / 2 + sz, largo / 2 - sz)
		parte({ Name = "Mancha", Size = Vector3.new(sx, 0.14, sz), CFrame = cf * CFrame.new(x, 0.07, z) * CFrame.Angles(0, math.rad(rng:NextNumber(-15, 15)), 0), Color = M.TIERRA_OSCURA, Material = Enum.Material.Ground, Variante = V.tierra, Parent = m })
	end
	return m
end

-- ===========================================================================
-- Props
-- ===========================================================================

-- Poste de luz de madera con travesano y aisladores. Devuelve el modelo y
-- los tres Attachments del travesano para colgar cables.
function ArteMundo.posteLuz(padre, cf)
	local m = modelo("PosteLuz", padre)
	local alto = 15
	local poste = parte({ Name = "Poste", Size = Vector3.new(0.8, alto, 0.8), CFrame = cf * CFrame.new(0, alto / 2, 0), Color = M.VIGA, Material = Enum.Material.Wood, Sombra = true, Parent = m })
	local travesano = parte({ Name = "Travesano", Size = Vector3.new(4.5, 0.4, 0.4), CFrame = cf * CFrame.new(0, alto - 1.2, 0), Color = M.VIGA, Material = Enum.Material.Wood, Parent = m })
	local puntos = {}
	for i, x in { -1.8, 0, 1.8 } do
		cilindroVertical({ Name = "Aislador", Diametro = 0.35, Alto = 0.5, CFrame = cf * CFrame.new(x, alto - 0.75, 0), Color = Paleta.UI_PAPEL, Parent = m })
		local a = Instance.new("Attachment")
		a.Name = "Cable" .. i
		a.CFrame = CFrame.new(x, 0.45, 0)
		a.Parent = travesano
		puntos[i] = a
	end
	m.PrimaryPart = poste
	return m, puntos
end

-- Cables que cuelgan entre dos postes (Beams con comba)
function ArteMundo.cables(puntosA, puntosB)
	for i = 1, math.min(#puntosA, #puntosB) do
		local b = Instance.new("Beam")
		b.Name = "Cable"
		b.Attachment0 = puntosA[i]
		b.Attachment1 = puntosB[i]
		b.Width0 = 0.12
		b.Width1 = 0.12
		b.Color = ColorSequence.new(M.NEGRO)
		b.Transparency = NumberSequence.new(0)
		b.LightEmission = 0
		b.LightInfluence = 0.5
		b.FaceCamera = true
		b.Segments = 14
		b.CurveSize0 = -3
		b.CurveSize1 = -3
		b.Parent = puntosA[i].Parent
	end
end

function ArteMundo.pilaNeumaticos(padre, cf, n, semilla)
	local rng = Random.new(semilla or 1)
	local m = modelo("PilaNeumaticos", padre)
	for i = 0, (n or 3) - 1 do
		local c = cilindroVertical({ Name = "Neumatico", Diametro = 3.2, Alto = 1.1, CFrame = cf * CFrame.new(rng:NextNumber(-0.3, 0.3), 0.55 + i * 1.1, rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = M.GOMA, Material = Enum.Material.Rubber, Sombra = true, Parent = m })
		cilindroVertical({ Name = "Llanta", Diametro = 1.6, Alto = 1.14, CFrame = c.CFrame * CFrame.Angles(0, 0, math.rad(-90)), Color = M.METAL, Material = Enum.Material.Metal, Parent = m })
	end
	return m
end

function ArteMundo.barril(padre, cf, color)
	local m = modelo("Barril", padre)
	cilindroVertical({ Name = "Cuerpo", Diametro = 2.4, Alto = 3.4, CFrame = cf * CFrame.new(0, 1.7, 0), Color = color or M.AZUL_MAQUINA, Material = Enum.Material.Metal, Sombra = true, Parent = m })
	for _, y in { 0.7, 1.7, 2.7 } do
		cilindroVertical({ Name = "Aro", Diametro = 2.55, Alto = 0.2, CFrame = cf * CFrame.new(0, y, 0), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, Parent = m })
	end
	return m
end

function ArteMundo.bolsaBasura(padre, cf, semilla)
	local rng = Random.new(semilla or 1)
	local m = modelo("BolsaBasura", padre)
	local d = rng:NextNumber(1.8, 2.6)
	bola({ Name = "Saco", Diametro = d, CFrame = cf * CFrame.new(0, d / 2, 0), Color = Paleta.BOLSA, Parent = m })
	cilindroVertical({ Name = "Nudo", Diametro = d * 0.3, Alto = d * 0.3, CFrame = cf * CFrame.new(0, d + d * 0.08, 0), Color = Paleta.escalar(Paleta.BOLSA, 1.3), Parent = m })
	return m
end

function ArteMundo.caja(padre, cf, tamano)
	local m = modelo("Caja", padre)
	local s = tamano or Vector3.new(2.4, 2, 2.2)
	parte({ Name = "Carton", Size = s, CFrame = cf * CFrame.new(0, s.Y / 2, 0), Color = Paleta.BASURA.Papel[1], Material = Enum.Material.Cardboard, Parent = m })
	parte({ Name = "Cinta", Size = Vector3.new(s.X + 0.02, 0.35, s.Z + 0.02), CFrame = cf * CFrame.new(0, s.Y - 0.2, 0), Color = Paleta.escalar(Paleta.BASURA.Papel[1], 0.8), Material = Enum.Material.Cardboard, Parent = m })
	return m
end

-- Camion abandonado: malla IA si existe, si no uno de partes (cabina,
-- capo, caja y ruedas; le falta una rueda y tiene manchas de oxido)
function ArteMundo.camion(padre, cf)
	local malla = clonarMalla("Camion", padre, cf, 14)
	if malla then
		return malla
	end
	local m = modelo("Camion", padre)
	local azul = M.AZUL_MAQUINA
	local ry = 1.3
	-- chasis y cabina (frente -Z)
	parte({ Name = "Chasis", Size = Vector3.new(6, 0.8, 13), CFrame = cf * CFrame.new(0, ry + 0.2, 0), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, Parent = m })
	parte({ Name = "Capo", Size = Vector3.new(6, 2.2, 4.5), CFrame = cf * CFrame.new(0, ry + 1.7, -4.2), Color = azul, Material = Enum.Material.Metal, Parent = m })
	parte({ Name = "Cabina", Size = Vector3.new(6, 3.4, 3.6), CFrame = cf * CFrame.new(0, ry + 2.3, -0.4), Color = azul, Material = Enum.Material.Metal, Parent = m })
	parte({ Name = "Parabrisas", Size = Vector3.new(5.2, 2.0, 0.2), CFrame = cf * CFrame.new(0, ry + 2.7, -2.2) * CFrame.Angles(math.rad(-18), 0, 0), Color = M.CRISTAL, Material = Enum.Material.Glass, Transparency = 0.25, Parent = m })
	parte({ Name = "Techo", Size = Vector3.new(6.2, 0.4, 3.8), CFrame = cf * CFrame.new(0, ry + 4.1, -0.4), Color = Paleta.escalar(azul, 0.85), Material = Enum.Material.Metal, Parent = m })
	-- caja trasera
	parte({ Name = "CajaSuelo", Size = Vector3.new(6, 0.4, 6.6), CFrame = cf * CFrame.new(0, ry + 0.8, 3.1), Color = M.OXIDO, Material = Enum.Material.CorrodedMetal, Parent = m })
	for _, x in { -2.85, 2.85 } do
		parte({ Name = "CajaLado", Size = Vector3.new(0.3, 1.8, 6.6), CFrame = cf * CFrame.new(x, ry + 1.7, 3.1), Color = azul, Material = Enum.Material.Metal, Parent = m })
	end
	parte({ Name = "CajaFondo", Size = Vector3.new(6, 1.8, 0.3), CFrame = cf * CFrame.new(0, ry + 1.7, 6.25), Color = Paleta.escalar(azul, 0.8), Material = Enum.Material.Metal, Parent = m })
	-- ruedas (falta la trasera derecha: apoyado en el eje)
	for _, r in { { -3.2, -3.4 }, { 3.2, -3.4 }, { -3.2, 3.8 } } do
		cilindroEjeX({ Name = "Rueda", Diametro = 2.6, Largo = 1, CFrame = cf * CFrame.new(r[1], ry, r[2]), Color = M.GOMA, Material = Enum.Material.Rubber, Sombra = true, Parent = m })
		cilindroEjeX({ Name = "Tapacubos", Diametro = 1.3, Largo = 1.06, CFrame = cf * CFrame.new(r[1], ry, r[2]), Color = M.METAL, Material = Enum.Material.Metal, Parent = m })
	end
	-- oxido y faros
	parte({ Name = "Oxido", Size = Vector3.new(1.6, 1.2, 0.1), CFrame = cf * CFrame.new(2.2, ry + 2.0, -6.46), Color = M.OXIDO, Material = Enum.Material.CorrodedMetal, Parent = m })
	parte({ Name = "Oxido2", Size = Vector3.new(0.1, 1.4, 2.2), CFrame = cf * CFrame.new(-3.05, ry + 1.6, 1.5), Color = M.OXIDO, Material = Enum.Material.CorrodedMetal, Parent = m })
	for _, x in { -2.2, 2.2 } do
		cilindroEjeZ({ Name = "Faro", Diametro = 0.9, Largo = 0.2, CFrame = cf * CFrame.new(x, ry + 1.8, -6.5), Color = Paleta.UI_PAPEL, Parent = m })
	end
	return m
end

-- ===========================================================================
-- La caseta de Dona Chatarra: cabana de madera de dos plantas
-- ===========================================================================

-- cf = centro de la cabina (z de la caseta), frente hacia +Z (el patio). La
-- cabina whitebox (Fondo, Lados, Techo, Mostrador, Rotulo) sigue debajo
-- haciendo de colision; aqui se viste por fuera y se sube una segunda
-- planta con balcon, tejado de lona azul, ventanas, antena y el rotulo grande.
function ArteMundo.caseta(padre, cf)
	local m = modelo("Cabana", padre)
	local rng = Random.new(7)
	local madera = Enum.Material.WoodPlanks
	local W, D = 15.2, 9.2 -- planta baja por fuera (la cabina mide 14 x 8.6)
	local H1 = 8.6 -- planta baja, del suelo (cf) al techo de la cabina (9.6 en el mundo)
	local H2 = 7.2 -- segunda planta
	local y2 = 8.6 -- suelo de la segunda planta, relativo al cf (que ya esta a ras de suelo)

	local function tabla(nombre, size, cfLocal, tono)
		return parte({ Name = nombre, Size = size, CFrame = cf * cfLocal, Color = Paleta.escalar(M.MADERA, tono or 1), Material = madera, Variante = V.madera, Sombra = true, Parent = m })
	end
	local function viga(nombre, size, cfLocal)
		return parte({ Name = nombre, Size = size, CFrame = cf * cfLocal, Color = M.VIGA, Material = Enum.Material.Wood, Sombra = true, Parent = m })
	end

	-- Planta baja: tablas horizontales en el fondo y los lados (el frente es
	-- la cabina abierta con el mostrador)
	local filas = 8
	for i = 0, filas - 1 do
		local y = (i + 0.5) * (H1 / filas)
		local tono = 0.9 + rng:NextNumber(0, 0.2)
		tabla("TablaFondo", Vector3.new(W, H1 / filas - 0.08, 0.5), CFrame.new(0, y, -D / 2), tono)
		tabla("TablaLadoO", Vector3.new(0.5, H1 / filas - 0.08, D), CFrame.new(-W / 2, y, 0), tono)
		tabla("TablaLadoE", Vector3.new(0.5, H1 / filas - 0.08, D), CFrame.new(W / 2, y, 0), tono)
	end
	-- Vigas de esquina y del frente
	for _, x in { -W / 2, W / 2 } do
		for _, z in { -D / 2, D / 2 } do
			viga("Esquina", Vector3.new(0.9, H1 + 0.6, 0.9), CFrame.new(x, (H1 + 0.6) / 2, z))
		end
	end
	-- Cornisa entre plantas
	viga("Cornisa", Vector3.new(W + 1.4, 0.6, D + 1.4), CFrame.new(0, y2 - 0.3, 0))

	-- Segunda planta: caja de tablas con ventanas
	local paredes = {
		{ Vector3.new(W, H2, 0.5), CFrame.new(0, y2 + H2 / 2, -D / 2) }, -- fondo
		{ Vector3.new(W, H2, 0.5), CFrame.new(0, y2 + H2 / 2, D / 2) }, -- frente
		{ Vector3.new(0.5, H2, D), CFrame.new(-W / 2, y2 + H2 / 2, 0) },
		{ Vector3.new(0.5, H2, D), CFrame.new(W / 2, y2 + H2 / 2, 0) },
	}
	for i, p in paredes do
		parte({ Name = "Pared" .. i, Size = p[1], CFrame = cf * p[2], Color = M.PARED, Material = Enum.Material.Plaster, Sombra = true, Parent = m })
	end
	-- Tablas horizontales decorativas sobre la pared crema (mitad inferior)
	for i = 0, 2 do
		local y = y2 + 0.6 + i * 1.1
		tabla("TablaAlta", Vector3.new(W + 0.2, 0.7, 0.3), CFrame.new(0, y, D / 2 + 0.2), 0.95)
		tabla("TablaAltaF", Vector3.new(W + 0.2, 0.7, 0.3), CFrame.new(0, y, -D / 2 - 0.2), 0.95)
	end
	for _, x in { -W / 2, W / 2 } do
		for _, z in { -D / 2, D / 2 } do
			viga("EsquinaAlta", Vector3.new(0.9, H2 + 0.4, 0.9), CFrame.new(x, y2 + H2 / 2, z))
		end
	end
	-- Ventanas: dos al frente, una a cada lado
	local function ventana(cfLocal, girada)
		local marco = Vector3.new(if girada then 0.5 else 3.0, 3.0, if girada then 3.0 else 0.5)
		viga("MarcoVentana", marco, cfLocal)
		local cristal = Vector3.new(if girada then 0.6 else 2.4, 2.4, if girada then 2.4 else 0.6)
		parte({ Name = "Cristal", Size = cristal, CFrame = cf * cfLocal, Color = M.CRISTAL, Material = Enum.Material.Glass, Transparency = 0.15, Parent = m })
		-- cruceta
		parte({ Name = "Cruceta", Size = Vector3.new(if girada then 0.7 else 2.4, 0.2, if girada then 2.4 else 0.7), CFrame = cf * cfLocal, Color = M.VIGA, Material = Enum.Material.Wood, Parent = m })
		parte({ Name = "Cruceta2", Size = Vector3.new(if girada then 0.7 else 0.2, 2.4, if girada then 0.2 else 0.7), CFrame = cf * cfLocal, Color = M.VIGA, Material = Enum.Material.Wood, Parent = m })
	end
	ventana(CFrame.new(-4.2, y2 + 4.2, D / 2), false)
	ventana(CFrame.new(4.2, y2 + 4.2, D / 2), false)
	ventana(CFrame.new(-W / 2, y2 + 4.2, 0), true)
	ventana(CFrame.new(W / 2, y2 + 4.2, 0), true)
	-- Puerta azul al fondo de la segunda planta (al balcon trasero no hay: es decorado)
	parte({ Name = "Puerta", Size = Vector3.new(2.6, 4.6, 0.3), CFrame = cf * CFrame.new(0, y2 + 2.3, D / 2 + 0.1), Color = M.LONA, Material = Enum.Material.SmoothPlastic, Parent = m })
	parte({ Name = "Pomo", Size = Vector3.new(0.3, 0.3, 0.3), CFrame = cf * CFrame.new(0.9, y2 + 2.3, D / 2 + 0.3), Color = M.AMARILLO, Material = Enum.Material.Metal, Parent = m })

	-- Balcon al frente sobre el mostrador, con barandilla
	local balconZ = D / 2 + 2.2
	tabla("Balcon", Vector3.new(W + 1.6, 0.5, 4.4), CFrame.new(0, y2 - 0.2, balconZ), 1.05)
	for i = 0, 8 do
		local x = -(W + 1.6) / 2 + 0.3 + i * ((W + 1.0) / 8)
		viga("Balaustre", Vector3.new(0.35, 2.6, 0.35), CFrame.new(x, y2 + 1.3, balconZ + 2.0))
	end
	viga("Pasamanos", Vector3.new(W + 1.6, 0.35, 0.45), CFrame.new(0, y2 + 2.6, balconZ + 2.0))
	for _, x in { -(W + 1.6) / 2 + 0.3, (W + 1.6) / 2 - 0.3 } do
		viga("BalaustreLado", Vector3.new(0.35, 2.6, 4.4), CFrame.new(x, y2 + 1.3, balconZ))
	end
	-- Toldo de lona azul bajo el balcon (sobre el mostrador)
	parte({ Name = "Toldo", Size = Vector3.new(W + 2, 0.25, 5.2), CFrame = cf * CFrame.new(0, y2 - 0.65, D / 2 + 2.4) * CFrame.Angles(math.rad(8), 0, 0), Color = M.LONA, Material = Enum.Material.Fabric, Sombra = true, Parent = m })
	for i = 0, 6 do
		local x = -(W + 2) / 2 + 1 + i * ((W + 2 - 2) / 6)
		parte({ Name = "Fleco", Size = Vector3.new(1.4, 0.9, 0.2), CFrame = cf * CFrame.new(x, y2 - 1.3, D / 2 + 4.9), Color = if i % 2 == 0 then M.LONA else Paleta.UI_PAPEL, Material = Enum.Material.Fabric, Parent = m })
	end

	-- Tejado a dos aguas de lona azul (cunas): el alto queda en la cumbrera
	local techoY = y2 + H2
	local caida = 3.8
	local fondoTejado = (D + 3) / 2
	local largoTejado = W + 3
	parte({ Name = "TejadoFrente", Shape = "Wedge", Size = Vector3.new(largoTejado, caida, fondoTejado), CFrame = cf * CFrame.new(0, techoY + caida / 2, fondoTejado / 2) * CFrame.Angles(0, math.rad(180), 0), Color = M.LONA, Material = Enum.Material.Fabric, Sombra = true, Parent = m })
	parte({ Name = "TejadoFondo", Shape = "Wedge", Size = Vector3.new(largoTejado, caida, fondoTejado), CFrame = cf * CFrame.new(0, techoY + caida / 2, -fondoTejado / 2), Color = Paleta.escalar(M.LONA, 0.85), Material = Enum.Material.Fabric, Sombra = true, Parent = m })
	viga("Cumbrera", Vector3.new(largoTejado + 0.4, 0.5, 0.7), CFrame.new(0, techoY + caida + 0.1, 0))
	-- Frontones (triangulos de madera en los laterales): dos cunas giradas
	for _, lado in { -1, 1 } do
		parte({ Name = "Fronton", Shape = "Wedge", Size = Vector3.new(0.4, caida - 0.2, fondoTejado - 0.2), CFrame = cf * CFrame.new(lado * (W / 2 - 0.1), techoY + (caida - 0.2) / 2, (fondoTejado - 0.2) / 2) * CFrame.Angles(0, math.rad(180), 0), Color = M.MADERA, Material = madera, Variante = V.madera, Parent = m })
		parte({ Name = "Fronton2", Shape = "Wedge", Size = Vector3.new(0.4, caida - 0.2, fondoTejado - 0.2), CFrame = cf * CFrame.new(lado * (W / 2 - 0.1), techoY + (caida - 0.2) / 2, -(fondoTejado - 0.2) / 2), Color = M.MADERA, Material = madera, Variante = V.madera, Parent = m })
	end

	-- Rotulo grande sobre el tejado, en pegatina, con dos postes
	local rotuloY = techoY + caida + 3.2
	for _, x in { -5, 5 } do
		viga("PosteRotulo", Vector3.new(0.5, 6, 0.5), CFrame.new(x, techoY + 2.4, 0.5))
	end
	local rotulo = tabla("RotuloGrande", Vector3.new(18, 4.2, 0.6), CFrame.new(0, rotuloY, 0.5), 1)
	rotulo.Color = M.MADERA_CLARA
	ArteMundo.letreroPegatina(rotulo, "DOÑA CHATARRA", Enum.NormalId.Front, { contorno = nil })
	ArteMundo.letreroPegatina(rotulo, "DOÑA CHATARRA", Enum.NormalId.Back, {})

	-- Antena de television en el tejado
	local antenaBase = CFrame.new(5.5, techoY + caida + 0.2, -2)
	parte({ Name = "Antena", Size = Vector3.new(0.15, 5, 0.15), CFrame = cf * antenaBase * CFrame.new(0, 2.5, 0), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, Parent = m })
	for i, w in { 3.2, 2.4, 1.6 } do
		parte({ Name = "AntenaBrazo", Size = Vector3.new(w, 0.12, 0.12), CFrame = cf * antenaBase * CFrame.new(0, 2.6 + i * 0.7, 0), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, Parent = m })
	end

	-- Cajas de carton apiladas junto a la cabina y un par de bolsas
	ArteMundo.caja(m, cf * CFrame.new(W / 2 + 2.4, 1, 1.5), Vector3.new(2.6, 2.2, 2.4))
	ArteMundo.caja(m, cf * CFrame.new(W / 2 + 2.2, 3.2, 1.7) * CFrame.Angles(0, math.rad(15), 0), Vector3.new(2.0, 1.6, 1.9))
	ArteMundo.caja(m, cf * CFrame.new(-W / 2 - 2.5, 1, -1.0) * CFrame.Angles(0, math.rad(-20), 0), Vector3.new(2.2, 1.9, 2.0))
	ArteMundo.bolsaBasura(m, cf * CFrame.new(-W / 2 - 2.6, 1, 2.2), 3)
	return m
end

-- ===========================================================================
-- Maquina de refrescos (viste las partes del whitebox: Cuerpo, Ventana, Ranura)
-- ===========================================================================

function ArteMundo.maquinaRefrescos(padre, maq)
	local cuerpo = maq:FindFirstChild("Cuerpo")
	local ventana = maq:FindFirstChild("Ventana")
	local ranura = maq:FindFirstChild("Ranura")
	if not cuerpo then
		return nil
	end
	local m = modelo("ArteMaquina", padre)
	ArteMundo.pintar(cuerpo, Enum.Material.SmoothPlastic, M.AZUL_MAQUINA)
	ArteMundo.pintar(ventana, Enum.Material.Glass, M.CRISTAL)
	if ventana then
		ventana.Transparency = 0.45
	end
	ArteMundo.pintar(ranura, Enum.Material.Metal, M.METAL_OSCURO)
	local cf = cuerpo.CFrame -- frente = +Z (la ventana esta en z + 1.55)
	local s = cuerpo.Size
	-- Zocalo y remate
	parte({ Name = "Zocalo", Size = Vector3.new(s.X + 0.4, 0.8, s.Z + 0.4), CFrame = cf * CFrame.new(0, -s.Y / 2 + 0.4, 0), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, Parent = m })
	parte({ Name = "Remate", Size = Vector3.new(s.X + 0.3, 0.5, s.Z + 0.3), CFrame = cf * CFrame.new(0, s.Y / 2 + 0.25, 0), Color = Paleta.escalar(M.AZUL_MAQUINA, 0.8), Parent = m })
	-- Franja luminosa arriba con el letrero
	local franja = parte({ Name = "Franja", Size = Vector3.new(s.X - 0.4, 1.1, 0.25), CFrame = cf * CFrame.new(0, s.Y / 2 - 0.9, s.Z / 2 + 0.12), Color = Paleta.UI_PAPEL, Material = Enum.Material.Neon, Parent = m })
	ArteMundo.letreroPegatina(franja, "REFRESCOS", CARA_PATIO, { sinPapel = true, color = M.AZUL_MAQUINA })
	-- Latas tras el cristal: 3 baldas x 4 latas
	if ventana then
		local vcf, vs = ventana.CFrame, ventana.Size
		for fila = 0, 2 do
			local y = vs.Y / 2 - 0.7 - fila * 1.25
			parte({ Name = "Balda", Size = Vector3.new(vs.X - 0.2, 0.08, 0.9), CFrame = vcf * CFrame.new(0, y - 0.55, -0.3), Color = M.METAL, Material = Enum.Material.Metal, Parent = m })
			for col = 0, 3 do
				local x = -vs.X / 2 + 0.55 + col * ((vs.X - 1.1) / 3)
				local colores = Paleta.BASURA.Metal
				cilindroVertical({ Name = "Lata", Diametro = 0.5, Alto = 0.95, CFrame = vcf * CFrame.new(x, y, -0.3), Color = colores[(fila + col) % #colores + 1], Material = Enum.Material.Metal, Parent = m })
			end
		end
	end
	-- Panel de botones a la derecha de la ventana y la ranura de monedas
	local panelX = s.X / 2 - 0.55
	parte({ Name = "Panel", Size = Vector3.new(0.7, 3.2, 0.2), CFrame = cf * CFrame.new(panelX, 0.6, s.Z / 2 + 0.1), Color = Paleta.escalar(M.AZUL_MAQUINA, 0.7), Parent = m })
	for i = 0, 3 do
		parte({ Name = "Boton", Size = Vector3.new(0.4, 0.3, 0.1), CFrame = cf * CFrame.new(panelX, 1.7 - i * 0.6, s.Z / 2 + 0.24), Color = Paleta.BASURA.Metal[i % 4 + 1], Material = Enum.Material.Neon, Parent = m })
	end
	parte({ Name = "Monedero", Size = Vector3.new(0.5, 0.5, 0.15), CFrame = cf * CFrame.new(panelX, -1.1, s.Z / 2 + 0.24), Color = M.METAL, Material = Enum.Material.Metal, Parent = m })
	-- Pegatina lateral "OPEN HERE"-style: flecha en la ranura
	if ranura then
		ArteMundo.letreroPegatina(ranura, "↑ AQUÍ", CARA_PATIO, {})
	end
	return m
end

-- ===========================================================================
-- Contenedor verde y trituradora amarilla
-- ===========================================================================

-- Pinta las paredes del contenedor whitebox como contenedor de obra verde y
-- le anade borde, ruedas y una franja
function ArteMundo.contenedorVerde(padre, cont)
	local m = modelo("ArteContenedor", padre)
	local frente = cont.PrimaryPart or cont:FindFirstChild("ParedFrente")
	if not frente then
		return m
	end
	-- Paredes y piso (todo menos la zona de acierto invisible)
	for _, p in cont:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "ZonaAcierto" then
			ArteMundo.pintar(p, Enum.Material.Metal, M.VERDE_CONTENEDOR)
		end
	end
	local cf = cont:GetBoundingBox()
	local _, tam = cont:GetBoundingBox()
	local top = cf.Position.Y + tam.Y / 2
	-- Borde superior mas oscuro
	local bordeColor = Paleta.escalar(M.VERDE_CONTENEDOR, 0.75)
	parte({ Name = "BordeN", Size = Vector3.new(tam.X + 0.4, 0.5, 0.9), CFrame = CFrame.new(cf.Position.X, top + 0.1, cf.Position.Z - tam.Z / 2), Color = bordeColor, Material = Enum.Material.Metal, Parent = m })
	parte({ Name = "BordeS", Size = Vector3.new(tam.X + 0.4, 0.5, 0.9), CFrame = CFrame.new(cf.Position.X, top + 0.1, cf.Position.Z + tam.Z / 2), Color = bordeColor, Material = Enum.Material.Metal, Parent = m })
	parte({ Name = "BordeO", Size = Vector3.new(0.9, 0.5, tam.Z + 0.4), CFrame = CFrame.new(cf.Position.X - tam.X / 2, top + 0.1, cf.Position.Z), Color = bordeColor, Material = Enum.Material.Metal, Parent = m })
	parte({ Name = "BordeE", Size = Vector3.new(0.9, 0.5, tam.Z + 0.4), CFrame = CFrame.new(cf.Position.X + tam.X / 2, top + 0.1, cf.Position.Z), Color = bordeColor, Material = Enum.Material.Metal, Parent = m })
	-- Nervios verticales en las caras largas
	for _, z in { cf.Position.Z - tam.Z / 2 - 0.3, cf.Position.Z + tam.Z / 2 + 0.3 } do
		for i = -1, 1 do
			parte({ Name = "Nervio", Size = Vector3.new(0.5, tam.Y - 1.2, 0.3), CFrame = CFrame.new(cf.Position.X + i * (tam.X / 3.2), cf.Position.Y, z), Color = bordeColor, Material = Enum.Material.Metal, Parent = m })
		end
	end
	-- Ruedas
	for _, dx in { -tam.X / 2 + 1.2, tam.X / 2 - 1.2 } do
		for _, dz in { -tam.Z / 2 + 0.9, tam.Z / 2 - 0.9 } do
			cilindroEjeX({ Name = "Rueda", Diametro = 1.1, Largo = 0.5, CFrame = CFrame.new(cf.Position.X + dx, 0.55, cf.Position.Z + dz), Color = M.GOMA, Material = Enum.Material.Rubber, Sombra = true, Parent = m })
		end
	end
	-- Placa pequena con la pegatina de reciclaje (no toda la pared)
	local placa = parte({ Name = "Placa", Size = Vector3.new(4.2, 1.5, 0.2), CFrame = frente.CFrame * CFrame.new(0, 0.6, frente.Size.Z / 2 + 0.12), Color = Paleta.UI_PAPEL, Material = Enum.Material.SmoothPlastic, Parent = m })
	ArteMundo.letreroPegatina(placa, "♻ RECICLAJE", CARA_PATIO, { color = M.VERDE_CONTENEDOR })
	return m
end

-- Trituradora amarilla decorativa detras del contenedor: cuerpo con franjas,
-- boca con rodillos, cinta transportadora y boton verde. cf = suelo bajo el
-- centro, frente hacia +Z.
function ArteMundo.trituradora(padre, cf)
	local m = modelo("Trituradora", padre)
	local amarillo = M.AMARILLO
	local W, H, D = 10, 6.5, 5
	parte({ Name = "Cuerpo", Size = Vector3.new(W, H, D), CFrame = cf * CFrame.new(0, H / 2 + 0.6, 0), Color = amarillo, Material = Enum.Material.Metal, Sombra = true, Parent = m })
	parte({ Name = "Base", Size = Vector3.new(W + 0.6, 0.6, D + 0.6), CFrame = cf * CFrame.new(0, 0.3, 0), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, Parent = m })
	-- Boca oscura con dos rodillos dentados
	parte({ Name = "Boca", Size = Vector3.new(W - 2.4, 2.6, 0.6), CFrame = cf * CFrame.new(0, H - 1.2, D / 2 + 0.05), Color = M.NEGRO, Material = Enum.Material.Metal, Parent = m })
	for _, x in { -1.9, 1.9 } do
		cilindroEjeX({ Name = "Rodillo", Diametro = 2.0, Largo = 3.4, CFrame = cf * CFrame.new(x, H - 1.2, D / 2 + 0.5), Color = M.METAL_OSCURO, Material = Enum.Material.DiamondPlate, Parent = m })
		for i = 0, 5 do
			local a = i * math.pi / 3
			parte({ Name = "Diente", Size = Vector3.new(3.2, 0.35, 0.35), CFrame = cf * CFrame.new(x, H - 1.2, D / 2 + 0.5) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 1.05, 0), Color = M.METAL, Material = Enum.Material.Metal, Parent = m })
		end
	end
	-- Franjas amarillas y negras arriba
	for i = 0, 9 do
		parte({ Name = "Franja", Size = Vector3.new(W / 10, 0.8, 0.2), CFrame = cf * CFrame.new(-W / 2 + W / 20 + i * W / 10, H + 0.2, D / 2 + 0.1), Color = if i % 2 == 0 then M.NEGRO else amarillo, Material = Enum.Material.SmoothPlastic, Parent = m })
	end
	-- Tolva arriba
	parte({ Name = "Tolva", Size = Vector3.new(W - 3, 1.6, D - 1.5), CFrame = cf * CFrame.new(0, H + 1.4, -0.5), Color = Paleta.escalar(amarillo, 0.85), Material = Enum.Material.Metal, Sombra = true, Parent = m })
	-- Cinta transportadora
	local largoCinta = 12
	-- Sube por el lado ESTE (lejos de la cabana): el extremo alto (oeste) descarga en la tolva
	local cintaCF = cf * CFrame.new(W / 2 + largoCinta / 2 - 1.5, 3.3, -0.5) * CFrame.Angles(0, 0, math.rad(-26))
	parte({ Name = "Cinta", Size = Vector3.new(largoCinta, 0.5, 3.2), CFrame = cintaCF, Color = M.NEGRO, Material = Enum.Material.Rubber, Sombra = true, Parent = m })
	parte({ Name = "CintaBorde", Size = Vector3.new(largoCinta, 0.9, 0.3), CFrame = cintaCF * CFrame.new(0, 0.3, 1.7), Color = M.METAL, Material = Enum.Material.Metal, Parent = m })
	parte({ Name = "CintaBorde2", Size = Vector3.new(largoCinta, 0.9, 0.3), CFrame = cintaCF * CFrame.new(0, 0.3, -1.7), Color = M.METAL, Material = Enum.Material.Metal, Parent = m })
	for i = 0, 5 do
		parte({ Name = "Listón", Size = Vector3.new(0.25, 0.1, 3.0), CFrame = cintaCF * CFrame.new(-largoCinta / 2 + 1 + i * 2, 0.3, 0), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, Parent = m })
	end
	for _, dx in { -largoCinta / 2 + 1, 0 } do
		parte({ Name = "Pata", Size = Vector3.new(0.5, 3, 0.5), CFrame = cf * CFrame.new(W / 2 + largoCinta / 2 - 1.5 - dx, 1.5, -0.5), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, Parent = m })
	end
	-- Panel con boton verde y luz roja, y pegatina de peligro
	parte({ Name = "Panel", Size = Vector3.new(1.6, 1.4, 0.3), CFrame = cf * CFrame.new(W / 2 - 1.4, 2.6, D / 2 + 0.1), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, Parent = m })
	cilindroEjeZ({ Name = "BotonVerde", Diametro = 0.6, Largo = 0.3, CFrame = cf * CFrame.new(W / 2 - 1.7, 2.8, D / 2 + 0.35), Color = M.VERDE_CONTENEDOR, Material = Enum.Material.Neon, Parent = m })
	cilindroEjeZ({ Name = "LuzRoja", Diametro = 0.4, Largo = 0.3, CFrame = cf * CFrame.new(W / 2 - 1.0, 2.8, D / 2 + 0.35), Color = Paleta.UI_PELIGRO, Material = Enum.Material.Neon, Parent = m })
	local senal = parte({ Name = "Senal", Size = Vector3.new(2.2, 2.2, 0.2), CFrame = cf * CFrame.new(-W / 2 + 1.8, 2.6, D / 2 + 0.15), Color = amarillo, Parent = m })
	ArteMundo.letreroPegatina(senal, "⚠", CARA_PATIO, { fondo = amarillo, color = M.NEGRO })
	-- Tubo de escape
	cilindroVertical({ Name = "Chimenea", Diametro = 0.8, Alto = 3, CFrame = cf * CFrame.new(W / 2 - 1.2, H + 1.6, -1.6), Color = M.METAL_OSCURO, Material = Enum.Material.Metal, Parent = m })
	return m
end

-- ===========================================================================
-- Dona Chatarra
-- ===========================================================================

-- Viste al NPC whitebox (Torso, Cabeza, Mono, BrazoIzq/Der, Piernas siguen
-- con sus nombres y tamanos: prompt y retrato del dialogo dependen de ellos)
function ArteMundo.vestirChatarra(npc)
	local torso = npc:FindFirstChild("Torso")
	local cabeza = npc:FindFirstChild("Cabeza")
	local mono = npc:FindFirstChild("Mono")
	local piernas = npc:FindFirstChild("Piernas")
	if not torso or not cabeza then
		return
	end
	local m = modelo("Ropa", npc)
	ArteMundo.pintar(torso, Enum.Material.Fabric, M.CAMISA)
	ArteMundo.pintar(cabeza, Enum.Material.SmoothPlastic, M.PIEL_NPC)
	ArteMundo.pintar(mono, Enum.Material.SmoothPlastic, M.PELO_NPC)
	ArteMundo.pintar(piernas, Enum.Material.Fabric, Paleta.escalar(M.LONA, 0.7))
	for _, nombre in { "BrazoIzq", "BrazoDer" } do
		ArteMundo.pintar(npc:FindFirstChild(nombre), Enum.Material.Fabric, M.CAMISA)
	end
	local cf = torso.CFrame
	local ts = torso.Size
	-- Delantal azul con peto y bolsillo
	parte({ Name = "Delantal", Size = Vector3.new(ts.X * 0.8, ts.Y * 0.95, 0.25), CFrame = cf * CFrame.new(0, -0.1, ts.Z / 2 + 0.1), Color = M.DELANTAL, Material = Enum.Material.Fabric, Parent = m })
	parte({ Name = "Bolsillo", Size = Vector3.new(ts.X * 0.4, 0.6, 0.12), CFrame = cf * CFrame.new(0, -0.5, ts.Z / 2 + 0.3), Color = Paleta.escalar(M.DELANTAL, 0.8), Material = Enum.Material.Fabric, Parent = m })
	for _, x in { -0.5, 0.5 } do
		parte({ Name = "Tirante", Size = Vector3.new(0.3, 0.9, 0.15), CFrame = cf * CFrame.new(x, ts.Y / 2 - 0.3, ts.Z / 2 + 0.08), Color = M.DELANTAL, Material = Enum.Material.Fabric, Parent = m })
	end
	-- Guantes amarillos y botas
	for _, nombre in { "BrazoIzq", "BrazoDer" } do
		local brazo = npc:FindFirstChild(nombre)
		if brazo then
			parte({ Name = "Guante", Size = Vector3.new(brazo.Size.X + 0.15, 0.7, brazo.Size.Z + 0.15), CFrame = brazo.CFrame * CFrame.new(0, -brazo.Size.Y / 2 + 0.3, 0), Color = M.AMARILLO, Material = Enum.Material.Rubber, Parent = m })
		end
	end
	if piernas then
		for _, x in { -0.5, 0.5 } do
			parte({ Name = "Bota", Size = Vector3.new(0.8, 0.7, 1.2), CFrame = piernas.CFrame * CFrame.new(x, -piernas.Size.Y / 2 + 0.35, 0.1), Color = M.VIGA, Material = Enum.Material.Leather, Parent = m })
		end
	end
	-- Cara: gafas redondas, ojos y sonrisa; pelo recogido con diadema
	local ccf = cabeza.CFrame
	local r = cabeza.Size.X / 2
	for _, x in { -0.32, 0.32 } do
		cilindroEjeZ({ Name = "Lente", Diametro = 0.5, Largo = 0.1, CFrame = ccf * CFrame.new(x, 0.1, r - 0.02), Color = M.CRISTAL, Material = Enum.Material.Glass, Transparency = 0.3, Parent = m })
		cilindroEjeZ({ Name = "Montura", Diametro = 0.58, Largo = 0.06, CFrame = ccf * CFrame.new(x, 0.1, r - 0.06), Color = M.NEGRO, Parent = m })
		bola({ Name = "Ojo", Diametro = 0.16, CFrame = ccf * CFrame.new(x, 0.1, r - 0.1), Color = M.NEGRO, Parent = m })
	end
	parte({ Name = "Puente", Size = Vector3.new(0.14, 0.08, 0.08), CFrame = ccf * CFrame.new(0, 0.1, r - 0.02), Color = M.NEGRO, Parent = m })
	parte({ Name = "Sonrisa", Size = Vector3.new(0.5, 0.08, 0.06), CFrame = ccf * CFrame.new(0, -0.32, r - 0.02), Color = Paleta.escalar(M.PIEL_NPC, 0.6), Parent = m })
	parte({ Name = "Diadema", Size = Vector3.new(r * 2.1, 0.25, 0.25), CFrame = ccf * CFrame.new(0, r * 0.75, 0), Color = M.CAMISA, Material = Enum.Material.Fabric, Parent = m })
	bola({ Name = "Pelo", Diametro = r * 1.9, CFrame = ccf * CFrame.new(0, r * 0.35, -r * 0.35), Color = M.PELO_NPC, Parent = m })
	return m
end

return ArteMundo
