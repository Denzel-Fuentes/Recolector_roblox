--!strict
--[[
	ContenedoresBloqueados
	Unica responsabilidad: que se VEA que un contenedor de tipo esta cerrado
	para ti. El de un tipo que aun no tienes abierto (GameConfig.
	MATERIAL_REBIRTH: metal con el Rebirth 1, organico con el 2) no acepta la
	bolsa (peticion del usuario, 6 oct; lo decide el servidor,
	Bolsa.contenedorAbierto: lanzada rebota en la tapa, a mano se rechaza).
	Aqui solo:
	  - un recuadro rojo translucido que envuelve el contenedor, con un
	    candado grande y "REBIRTH N" en su cara del frente (7 oct);
	  - un candado con "REBIRTH N" flotando sobre el contenedor (entre la
	    caja y su cartel "METAL · x2");
	  - su prompt de entregar a mano, apagado (localmente).
	Al cambiar el perfil (un rebirth) se recalcula: el candado se va solo.
	Cada jugador ve los suyos.

	El mundo llega al cliente por partes y en cualquier orden: el contenedor
	puede estar vacio (caja sin tamano, sin prompt) cuando se mira por primera
	vez. Por eso (8 oct: los candados se quedaban en el origen y el prompt
	encendido hasta el siguiente cambio de perfil) cada contenedor se vuelve a
	mirar cuando le llega una pieza, y todos cada REPASO segundos.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Paleta = require(Config:WaitForChild("Paleta"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local Iconos = require(Config:WaitForChild("Iconos"))
local Glifos = require(Shared:WaitForChild("Utilidades"):WaitForChild("Glifos"))

local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))
local Tema = require(script.Parent:WaitForChild("UI"):WaitForChild("Kit"):WaitForChild("Tema"))

local ALTURA = 1.6 -- studs sobre el tope de la caja (su cartel va a 3,4)
local REPASO = 3 -- segundos entre repasos de todos los contenedores

-- Contenedor -> el candado que se le puso (si esta cerrado)
local candados: { [Instance]: Attachment } = {}

local function rebirths(): number
	local p = EstadoCliente.perfil
	return if p then p.rebirths or 0 else 0
end

-- El candado grande con "REBIRTH N" (SurfaceGui de la cara frontal)
local function carteleraCandado(padre: Instance, n: number)
	local id = Iconos.id("candado")
	local icono: GuiObject
	if id then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = id
		img.ScaleType = Enum.ScaleType.Fit
		icono = img
	else
		icono = Glifos.dibujar("candado", 120)
	end
	icono.AnchorPoint = Vector2.new(0.5, 0)
	icono.Position = UDim2.fromScale(0.5, 0.1)
	icono.Size = UDim2.fromScale(0.5, 0.55)
	icono.Parent = padre
	local texto = Instance.new("TextLabel")
	texto.BackgroundTransparency = 1
	texto.AnchorPoint = Vector2.new(0.5, 0)
	texto.Position = UDim2.fromScale(0.5, 0.66)
	texto.Size = UDim2.fromScale(0.9, 0.24)
	texto.FontFace = Tema.FUENTE_TITULO
	texto.TextScaled = true
	texto.TextColor3 = Paleta.UI_PAPEL
	texto.Text = Textos.formatear(Textos.MUNDO.contenedorCandado, { n = n })
	local contorno = Instance.new("UIStroke")
	contorno.Color = Paleta.UI_TINTA
	contorno.Thickness = 3
	contorno.Parent = texto
	texto.Parent = padre
end

-- Recuadro translucido rojo que envuelve el contenedor cerrado (peticion
-- del usuario, 7 oct: "un cuadrado transparente de algun color... ademas
-- del candado"), con el candado grande en la cara que mira a la plaza (la
-- de la pared del frente). Solo de este cliente, sin colision ni consulta:
-- la bolsa la decide el servidor. Cuelga del ancla del candado y se va con
-- ella.
local function crearRecuadro(ancla: Attachment, n: number)
	local caja = Instance.new("Part")
	caja.Name = "RecuadroBloqueado"
	caja.Anchored = true
	caja.CanCollide = false
	caja.CanQuery = false
	caja.CanTouch = false
	caja.CastShadow = false
	caja.Material = Enum.Material.SmoothPlastic
	caja.Color = Paleta.UI_PELIGRO
	caja.Transparency = 0.6
	caja.Parent = ancla
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Candado"
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Adornee = caja
	sg.Parent = caja
	carteleraCandado(sg, n)
end

-- Coloca el candado y el recuadro sobre el contenedor. Se repite en cada
-- actualizacion: el mundo llega al cliente por partes y, recien creado, la
-- caja del contenedor puede estar aun vacia (salian en el origen, 7 oct)
local function colocar(cont: Model, ancla: Attachment)
	local cf, tamano = cont:GetBoundingBox()
	if tamano.Magnitude < 1 then
		return
	end
	ancla.WorldPosition = cf.Position + Vector3.new(0, tamano.Y / 2 + ALTURA, 0)
	local caja = ancla:FindFirstChild("RecuadroBloqueado")
	if not caja or not caja:IsA("BasePart") then
		return
	end
	caja.Size = tamano + Vector3.new(0.4, 0.4, 0.4)
	caja.CFrame = cf
	-- La cara del frente: hacia donde esta la pared del frente desde el centro
	local frente = cont:FindFirstChild("ParedFrente")
	local sg = caja:FindFirstChild("Candado")
	if frente and frente:IsA("BasePart") and sg and sg:IsA("SurfaceGui") then
		local l = cf:PointToObjectSpace(frente.Position)
		if math.abs(l.X) > math.abs(l.Z) then
			sg.Face = if l.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left
		else
			sg.Face = if l.Z > 0 then Enum.NormalId.Back else Enum.NormalId.Front
		end
	end
end

local function crearCandado(n: number): Attachment
	local ancla = Instance.new("Attachment")
	ancla.Name = "CandadoContenedor"
	ancla.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Adornee = ancla
	bb.Size = UDim2.fromScale(4, 1.2)
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	bb.Parent = ancla
	local pastilla = Instance.new("Frame")
	pastilla.Size = UDim2.fromScale(1, 1)
	pastilla.BackgroundColor3 = Paleta.UI_TINTA
	pastilla.Parent = bb
	local esquinas = Instance.new("UICorner")
	esquinas.CornerRadius = UDim.new(0.5, 0)
	esquinas.Parent = pastilla
	local contorno = Instance.new("UIStroke")
	contorno.Color = Paleta.UI_PAPEL
	contorno.Thickness = 2
	contorno.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	contorno.Parent = pastilla
	-- Candado a la izquierda (imagen de Iconos o su glifo), texto a la derecha
	local id = Iconos.id("candado")
	local icono: GuiObject
	if id then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = id
		img.ScaleType = Enum.ScaleType.Fit
		icono = img
	else
		icono = Glifos.dibujar("candado", 32)
	end
	icono.AnchorPoint = Vector2.new(0, 0.5)
	icono.Position = UDim2.fromScale(0.05, 0.5)
	icono.Size = UDim2.fromScale(0.22, 0.8)
	icono.Parent = pastilla
	local texto = Instance.new("TextLabel")
	texto.BackgroundTransparency = 1
	texto.AnchorPoint = Vector2.new(0, 0.5)
	texto.Position = UDim2.fromScale(0.28, 0.5)
	texto.Size = UDim2.fromScale(0.68, 0.7)
	texto.FontFace = Tema.FUENTE_TITULO
	texto.TextScaled = true
	texto.TextColor3 = Paleta.UI_PAPEL
	texto.Text = Textos.formatear(Textos.MUNDO.contenedorCandado, { n = n })
	texto.Parent = pastilla
	crearRecuadro(ancla, n)
	return ancla
end

local function actualizar(cont: Instance)
	if not cont:IsA("Model") then
		return
	end
	local material = cont:GetAttribute("Material")
	if typeof(material) ~= "string" then
		return -- el general acepta siempre
	end
	local cerrado = not GameConfig.materialAbierto(material, rebirths())
	for _, d in cont:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.Enabled = not cerrado
		end
	end
	local viejo = candados[cont]
	if cerrado then
		local ancla = viejo or crearCandado(GameConfig.MATERIAL_REBIRTH[material] or 1)
		candados[cont] = ancla
		colocar(cont, ancla)
	elseif viejo then
		viejo:Destroy()
		candados[cont] = nil
	end
end

local function todos()
	for _, cont in CollectionService:GetTagged("Contenedor") do
		actualizar(cont)
	end
end

-- Cuando a un contenedor le llegan piezas (la caja, el prompt) se vuelve a
-- mirar, agrupando las que llegan seguidas
local pendientes: { [Instance]: boolean } = {}
local vigilados: { [Instance]: RBXScriptConnection } = {}

local function programar(cont: Instance)
	if pendientes[cont] then
		return
	end
	pendientes[cont] = true
	task.delay(0.3, function()
		pendientes[cont] = nil
		if cont.Parent then
			actualizar(cont)
		end
	end)
end

local function vigilar(cont: Instance)
	if vigilados[cont] then
		return
	end
	vigilados[cont] = cont.DescendantAdded:Connect(function()
		programar(cont)
	end)
	programar(cont)
end

CollectionService:GetInstanceAddedSignal("Contenedor"):Connect(vigilar)
CollectionService:GetInstanceRemovedSignal("Contenedor"):Connect(function(cont)
	local conexion = vigilados[cont]
	if conexion then
		conexion:Disconnect()
		vigilados[cont] = nil
	end
	local ancla = candados[cont]
	if ancla then
		ancla:Destroy()
		candados[cont] = nil
	end
end)
for _, cont in CollectionService:GetTagged("Contenedor") do
	vigilar(cont)
end
EstadoCliente.alCambiarPerfil:Connect(todos)
-- Red de seguridad: lo que llegue sin avisar (o un perfil que no cambia)
task.spawn(function()
	while true do
		task.wait(REPASO)
		todos()
	end
end)
