--!strict
--[[
	Escena
	Detalles de presentacion del mundo que solo importan a ESTE cliente:

	  Figurinas fijas  las que ya tienes se ocultan localmente (transparencia
	                   local): para los demas siguen en su escondite (solo con
	                   la funcion FIGURINAS, pospuesta en la v2).
	  Brazos           quien esta en el patio (EnPatio) lleva los brazos al frente
	                   sujetando la bolsa (Utilidades/PoseBrazos en Stepped).
	  Carteles         los carteles flotantes horneados (ConstructorMundo.
	                   cartelFlotante) se restilizan aqui con el estilo del Kit
	                   (blanco, contorno marino) y su rotulo: "VENDER BASURA",
	                   "DONA CHATARRA" (Textos.MUNDO).

	Nada de esto toca el estado del juego; es puro RenderStepped.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local PoseBrazos = require(Shared:WaitForChild("Utilidades"):WaitForChild("PoseBrazos"))

local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))
local Tema = require(script.Parent:WaitForChild("UI"):WaitForChild("Kit"):WaitForChild("Tema"))

-- ===========================================================================
-- Carteles: estilo del Kit (blanco, contorno marino, FredokaOne)
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
-- (sin el, se queda el horneado). El tamano
-- va en studs, no en pixeles: asi el cartel se hace pequeno con la distancia,
-- como un letrero de verdad, y no tapa media pantalla desde lejos. Flota 3,4
-- studs por encima del tope del modelo, por encima del prompt (1,2).
local function estilizarCartel(bb: BillboardGui, texto: string?, colorBorde: Color3?)
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
	tl.FontFace = Tema.FUENTE_TITULO
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
	local contorno = tl:FindFirstChildOfClass("UIStroke")
	if not contorno then
		contorno = Instance.new("UIStroke")
		contorno.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		contorno.Parent = tl
	end
	-- Los carteles de los contenedores llevan el borde del color de su tipo
	contorno.Color = colorBorde or Paleta.UI_TINTA
	contorno.Thickness = if colorBorde then Tema.GROSOR * 2 else Tema.GROSOR
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

-- El modelo etiquetado que contiene a un cartel decide su rotulo (y, en los
-- contenedores, el color del borde: el de su tipo)
local function rotuloPara(bb: BillboardGui): (string?, Color3?)
	local actual: Instance? = bb.Parent
	while actual and actual ~= workspace do
		if CollectionService:HasTag(actual, "Contenedor") then
			local material = actual:GetAttribute("Material")
			if typeof(material) == "string" then
				return Textos.formatear(Textos.MUNDO.contenedorTipo, { tipo = Idioma.mayusculas(Textos.TIPOS[material] or material) }), Paleta.TIPO[material]
			end
			return Textos.MUNDO.contenedorGeneral, Paleta.TIPO.General
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

-- El Mundo se replica por partes: al aparecer workspace.Mundo sus 1.200
-- descendientes aun estan llegando. Se escucha DescendantAdded y se hace una
-- pasada inicial.
local function considerar(d: Instance)
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
