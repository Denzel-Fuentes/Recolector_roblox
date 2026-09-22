--!strict
--[[
	Escena
	Detalles de presentacion del mundo que solo importan a ESTE cliente:

	  Figurinas fijas  las que ya tienes se ocultan localmente (transparencia
	                   local): para los demas siguen en su escondite.
	  Radios           las de todas las parcelas con CintaId puesto giran los
	                   carretes y muestran el titulo de la cinta (y "sin audio"
	                   mientras el id sea placeholder).
	  Exhibidas        las mascotas Perfectas de los pedestales giran despacio.
	  Brazos           quien esta en el patio (EnPatio) lleva los brazos al frente
	                   sujetando la bolsa (Utilidades/PoseBrazos en Stepped).
	  Carteles         los carteles flotantes horneados (ConstructorMundo.
	                   cartelFlotante) se restilizan aqui como pegatinas de papel
	                   y tinta, y lo etiquetado que no tenia cartel (la maquina)
	                   recibe uno: "VENDER BASURA", "RESTAURAR ENERGIA", "DONA
	                   CHATARRA" (Textos.MUNDO). El texto de los carteles de
	                   parcela lo sigue poniendo el servidor (Parcelas.ponerCartel):
	                   aqui solo se cambia el aspecto, no se duplica la logica.

	Nada de esto toca el estado del juego; es puro RenderStepped.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local DefinicionesColeccionables = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesColeccionables"))
local DefinicionesMascotas = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMascotas"))
local PoseBrazos = require(Shared:WaitForChild("Utilidades"):WaitForChild("PoseBrazos"))

local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))
local Componentes = require(script.Parent:WaitForChild("UI"):WaitForChild("Componentes"))

-- ===========================================================================
-- Carteles: pegatinas de papel y tinta
-- ===========================================================================

-- Y del punto mas alto de una parte o de su modelo (la loma de una colina, el
-- mono de Dona Chatarra): los carteles y los prompts cuelgan por encima de eso
local function topeDe(parte: BasePart): number
	local tope = parte.Position.Y + parte.Size.Y / 2
	local modelo = parte.Parent
	if modelo and modelo:IsA("Model") then
		local cf, tamano = modelo:GetBoundingBox()
		tope = math.max(tope, cf.Position.Y + tamano.Y / 2)
	end
	return tope
end

-- Restiliza un BillboardGui horneado (o creado aqui) que tenga un TextLabel
-- "Texto": papel, contorno de tinta, FredokaOne. `texto` sustituye el rotulo
-- (los carteles de parcela no lo pasan: su texto es del servidor). El tamano
-- va en studs, no en pixeles: asi el cartel se hace pequeno con la distancia,
-- como un letrero de verdad, y no tapa media pantalla desde lejos. Flota 3,4
-- studs por encima del tope del modelo, por encima del prompt (1,2).
local function estilizarCartel(bb: BillboardGui, texto: string?)
	local tl = bb:WaitForChild("Texto", 10)
	if not tl or not tl:IsA("TextLabel") then
		return
	end
	local parte = bb.Adornee or bb.Parent
	if parte and parte:IsA("BasePart") then
		bb.StudsOffset = Vector3.zero
		bb.StudsOffsetWorldSpace = Vector3.new(0, topeDe(parte) - parte.Position.Y + 3.4, 0)
	end
	bb.Size = UDim2.fromScale(5.4, 1.25)
	bb.MaxDistance = math.max(bb.MaxDistance, 90)
	bb.LightInfluence = 0
	tl.BackgroundColor3 = Paleta.UI_PAPEL
	tl.BackgroundTransparency = 0
	tl.TextColor3 = Paleta.UI_TINTA
	tl.FontFace = Componentes.FUENTE_TITULO
	tl.TextScaled = true
	if texto then
		tl.Text = texto
	end
	local esquinas = tl:FindFirstChildOfClass("UICorner")
	if not esquinas then
		esquinas = Instance.new("UICorner")
		esquinas.Parent = tl
	end
	esquinas.CornerRadius = UDim.new(0.3, 0)
	if not tl:FindFirstChildOfClass("UIStroke") then
		Componentes.borde(tl, Paleta.UI_TINTA, 3)
	end
	local relleno = tl:FindFirstChildOfClass("UIPadding")
	if not relleno then
		relleno = Instance.new("UIPadding")
		relleno.Parent = tl
	end
	relleno.PaddingLeft = UDim.new(0.06, 0)
	relleno.PaddingRight = UDim.new(0.06, 0)
	relleno.PaddingTop = UDim.new(0.12, 0)
	relleno.PaddingBottom = UDim.new(0.12, 0)
end

local function crearCartel(parte: BasePart, texto: string, altura: number): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "Cartel"
	bb.Size = UDim2.fromOffset(240, 54)
	bb.StudsOffset = Vector3.new(0, altura, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 110
	local tl = Instance.new("TextLabel")
	tl.Name = "Texto"
	tl.Size = UDim2.fromScale(1, 1)
	tl.Text = texto
	tl.Parent = bb
	bb.Parent = parte
	estilizarCartel(bb, nil)
	return bb
end

-- El modelo etiquetado que contiene a un cartel decide su rotulo
local function rotuloPara(bb: BillboardGui): string?
	local actual: Instance? = bb.Parent
	while actual and actual ~= workspace do
		if CollectionService:HasTag(actual, "Contenedor") then
			return Textos.MUNDO.venderBasura
		elseif actual:GetAttribute("NPC") ~= nil then
			return Textos.MUNDO.chatarra
		end
		actual = actual.Parent
	end
	return nil
end

local cartelesVistos: { [Instance]: boolean } = {}

local function considerarCartel(d: Instance)
	if cartelesVistos[d] then
		return
	end
	if d:IsA("BillboardGui") and (d.Name == "Cartel" or d.Name == "CartelDueno") then
		cartelesVistos[d] = true
		task.defer(function()
			estilizarCartel(d, rotuloPara(d))
		end)
	elseif d:IsA("Model") and CollectionService:HasTag(d, "MaquinaRefrescos") then
		cartelesVistos[d] = true
		task.defer(function()
			local cuerpo = d:WaitForChild("Cuerpo", 10)
			if cuerpo and cuerpo:IsA("BasePart") and not cuerpo:FindFirstChild("Cartel") then
				crearCartel(cuerpo, Textos.MUNDO.restaurarEnergia, cuerpo.Size.Y / 2 + 1.4)
			end
		end)
	end
end

-- === Figurinas fijas ===
local function ocultarFigurinas()
	local carpeta = workspace:FindFirstChild("FigurinasFijas")
	local p = EstadoCliente.perfil
	if not carpeta or not p then
		return
	end
	for _, modelo in carpeta:GetChildren() do
		local id = modelo:GetAttribute("FigurinaId")
		local tiene = typeof(id) == "string" and p.figurinas and p.figurinas[id] == true
		for _, d in modelo:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = if tiene then 1 else 0
			elseif d:IsA("BillboardGui") then
				d.Enabled = not tiene
			end
		end
	end
end

EstadoCliente.alCambiarPerfil:Connect(ocultarFigurinas)
workspace.ChildAdded:Connect(function(hijo)
	if hijo.Name == "FigurinasFijas" then
		hijo.ChildAdded:Connect(function()
			task.defer(ocultarFigurinas)
		end)
		task.defer(ocultarFigurinas)
	end
end)
task.defer(ocultarFigurinas)

-- === Radios ===
type RadioVista = { modelo: Model, carretes: { BasePart }, cartel: BillboardGui?, texto: TextLabel? }
local radios: { RadioVista } = {}

local function prepararRadio(modelo: Model)
	-- Los hijos del modelo pueden llegar despues que el modelo: se esperan.
	local cuerpo = modelo:WaitForChild("Cuerpo", 10)
	local carretes = {}
	for i = 1, 2 do
		local carrete = modelo:WaitForChild("Carrete" .. i, 10)
		if carrete and carrete:IsA("BasePart") then
			table.insert(carretes, carrete)
		end
	end
	local vista: RadioVista = { modelo = modelo, carretes = carretes, cartel = nil, texto = nil }
	if cuerpo and cuerpo:IsA("BasePart") then
		local bb = crearCartel(cuerpo, "", 3.2)
		bb.Name = "CartelRadio"
		bb.Size = UDim2.fromOffset(220, 40)
		bb.MaxDistance = 40
		bb.Enabled = false
		vista.cartel = bb
		vista.texto = bb:FindFirstChild("Texto") :: TextLabel
	end
	table.insert(radios, vista)
end

-- El Mundo se replica por partes: al aparecer workspace.Mundo sus 1.200
-- descendientes aun estan llegando. Se escucha DescendantAdded y se hace una
-- pasada inicial; el conjunto evita preparar dos veces la misma radio.
local preparadas: { [Model]: boolean } = {}
local function considerar(d: Instance)
	if d:IsA("Model") and d:GetAttribute("Mueble") == "Radio" and not preparadas[d] then
		preparadas[d] = true
		task.defer(prepararRadio, d)
	end
	considerarCartel(d)
end

task.defer(function()
	local mundo = workspace:WaitForChild("Mundo", 60)
	if not mundo then
		return
	end
	mundo.DescendantAdded:Connect(considerar)
	for _, d in mundo:GetDescendants() do
		considerar(d)
	end
end)

local giro = 0
RunService.RenderStepped:Connect(function(dt)
	giro += dt * 3
	for _, r in radios do
		local cintaId = r.modelo:GetAttribute("CintaId")
		local activa = typeof(cintaId) == "string"
		if r.cartel then
			r.cartel.Enabled = activa
			if activa and r.texto then
				local def = DefinicionesColeccionables.CINTA_POR_ID[cintaId]
				if def then
					r.texto.Text = "♫ " .. def.nombre .. (if def.sonidoId == 0 then " " .. Textos.BASE.sinAudio else "")
				end
			end
		end
		if activa then
			for i, carrete in r.carretes do
				local base = carrete:GetAttribute("CFrameBase")
				if typeof(base) ~= "CFrame" then
					base = carrete.CFrame
					carrete:SetAttribute("CFrameBase", base)
				end
				carrete.CFrame = base * CFrame.Angles(giro * (if i == 1 then 1 else -1), 0, 0)
			end
		end
	end
end)

-- === Mascotas Perfectas exhibidas giran ===
RunService.RenderStepped:Connect(function(dt)
	local mundo = workspace:FindFirstChild("Mundo")
	if not mundo then
		return
	end
	local parcelas = mundo:FindFirstChild("Parcelas")
	if not parcelas then
		return
	end
	for _, parcela in parcelas:GetChildren() do
		local contenido = parcela:FindFirstChild("Contenido")
		if contenido then
			for _, modelo in contenido:GetChildren() do
				if modelo:IsA("Model") and modelo:GetAttribute("Estado") == DefinicionesMascotas.ESTADO_MAX and modelo:GetAttribute("MascotaId") then
					modelo:PivotTo(modelo:GetPivot() * CFrame.Angles(0, dt * 0.8, 0))
				end
			end
		end
	end
end)

-- === Brazos extendidos de quien esta en el patio ===
-- Se escribe Transform en Stepped, DESPUES de que el Animator haya puesto el
-- suyo (Utilidades/PoseBrazos explica el porque). Se hace para todos los
-- personajes con EnPatio, asi cada cliente ve a los demas sujetando la bolsa.
RunService.Stepped:Connect(function()
	for _, otro in Players:GetPlayers() do
		if otro:GetAttribute("EnPatio") == true then
			local ch = otro.Character
			if ch then
				PoseBrazos.aplicar(ch)
			end
		end
	end
end)
