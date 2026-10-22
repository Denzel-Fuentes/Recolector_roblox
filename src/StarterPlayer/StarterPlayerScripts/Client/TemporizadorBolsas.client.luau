--!strict
--[[
	TemporizadorBolsas
	Unica responsabilidad: el rotulo encima de cada bolsa caida: la cuenta
	atras en letras grandes ("30s", "29s"... y luego "¡LIBRE!") y debajo
	"Bolsa de X". La cuenta es lo que le queda para que la pueda recoger
	cualquiera (GameConfig.BOLSA_LIBRE_SEGUNDOS, decision del usuario,
	6 oct). El servidor pone en el modelo los atributos LibreEn (un
	workspace:GetServerTimeNow(), el mismo reloj aqui que alli) y Dueno, y
	decide quien la recoge; esto solo lo pinta, cada cliente el suyo.

	El rotulo NO cuelga de la bolsa: cuelga de un Attachment local en
	workspace.Terrain que cada frame se pone sobre el tope de la caja
	envolvente del modelo. Colgado del Cuerpo con un desfase fijo, al
	tumbarse o rodar la bolsa el texto se quedaba de lado o dentro de ella
	(peticion del usuario: "arriba de la bolsa independientemente de en que
	posicion este"). La etiqueta "Bolsa de X" del servidor (Primitivas.
	etiqueta, la de la bolsa en vuelo) se oculta localmente: la sustituye la
	segunda linea de esta pila.

	Va en studs (se encoge con la distancia, como un letrero) y con el
	estilo del Kit: FredokaOne blanca con contorno marino. Los ultimos AVISO
	segundos, en rojo y latiendo una vez por segundo; libre, en verde.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos

local Tema = require(script.Parent:WaitForChild("UI"):WaitForChild("Kit"):WaitForChild("Tema"))

local MARGEN = 0.5 -- studs entre el tope de la bolsa y el pie del rotulo
local ALTO_ROTULO = 2.2 -- studs: numero (70 %) + nombre (30 %)
local AVISO = 5 -- ultimos segundos en rojo
local LATIDO = 0.18 -- cuanto crece el numero al cambiar en el aviso

type Rotulo = {
	modelo: Model,
	libreEn: number,
	ancla: Attachment,
	numero: TextLabel,
	escala: UIScale,
	ultimo: string,
}

local activos: { [Model]: Rotulo } = {}

local function texto(props: { Name: string, Size: UDim2, Position: UDim2, Color: Color3, Grosor: number, Parent: Instance }): TextLabel
	local tl = Instance.new("TextLabel")
	tl.Name = props.Name
	tl.Size = props.Size
	tl.Position = props.Position
	tl.BackgroundTransparency = 1
	tl.FontFace = Tema.FUENTE_TITULO
	tl.TextScaled = true
	tl.TextColor3 = props.Color
	tl.Text = ""
	local contorno = Instance.new("UIStroke")
	contorno.Color = Paleta.UI_TINTA
	contorno.Thickness = props.Grosor
	contorno.Parent = tl
	tl.Parent = props.Parent
	return tl
end

local function crear(modelo: Model)
	if activos[modelo] then
		return
	end
	local libreEn = modelo:GetAttribute("LibreEn")
	local cuerpo = modelo.PrimaryPart
	if typeof(libreEn) ~= "number" or not cuerpo then
		return
	end
	local ancla = Instance.new("Attachment")
	ancla.Name = "RotuloBolsa"
	ancla.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Name = "RotuloBolsa"
	bb.Adornee = ancla
	bb.Size = UDim2.fromScale(4.2, ALTO_ROTULO)
	-- El pie del rotulo en el ancla: crece hacia arriba
	bb.StudsOffsetWorldSpace = Vector3.new(0, ALTO_ROTULO / 2, 0)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Parent = ancla
	local numero = texto({ Name = "Numero", Size = UDim2.fromScale(1, 0.7), Position = UDim2.fromScale(0, 0), Color = Paleta.UI_PAPEL, Grosor = Tema.GROSOR, Parent = bb })
	local escala = Instance.new("UIScale")
	escala.Parent = numero
	local dueno = modelo:GetAttribute("Dueno")
	local nombre = texto({ Name = "Dueno", Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.7), Color = Paleta.UI_PAPEL, Grosor = 2, Parent = bb })
	nombre.Text = Textos.formatear(Textos.PATIO.bolsaDe, { dueno = if typeof(dueno) == "string" then dueno else "?" })
	-- La etiqueta del servidor (la de la bolsa en vuelo) sobra: la sustituye la pila
	local etiqueta = cuerpo:FindFirstChild("Etiqueta")
	if etiqueta and etiqueta:IsA("BillboardGui") then
		etiqueta.Enabled = false
	end
	activos[modelo] = { modelo = modelo, libreEn = libreEn, ancla = ancla, numero = numero, escala = escala, ultimo = "" }
end

local function vigilar(modelo: Instance)
	if not modelo:IsA("Model") then
		return
	end
	-- La bolsa entra en la carpeta al lanzarse y recibe LibreEn al posarse
	modelo:GetAttributeChangedSignal("LibreEn"):Connect(function()
		crear(modelo)
	end)
	crear(modelo)
end

local carpeta = workspace:WaitForChild("Objetos")
carpeta.ChildAdded:Connect(vigilar)
for _, hijo in carpeta:GetChildren() do
	vigilar(hijo)
end

RunService.RenderStepped:Connect(function()
	local ahora = workspace:GetServerTimeNow()
	for modelo, r in activos do
		if not modelo:IsDescendantOf(workspace) then
			r.ancla:Destroy()
			activos[modelo] = nil
			continue
		end
		-- Sobre el tope de la caja envolvente, gire como gire la bolsa
		local cf, tamano = modelo:GetBoundingBox()
		r.ancla.WorldPosition = Vector3.new(cf.Position.X, cf.Position.Y + tamano.Y / 2 + MARGEN, cf.Position.Z)
		local faltan = r.libreEn - ahora
		local textoNumero: string, color: Color3, latido: number
		if faltan > 0 then
			local s = math.ceil(faltan)
			textoNumero = Textos.formatear(Textos.PATIO.temporizadorBolsa, { s = s })
			color = if s <= AVISO then Paleta.UI_PELIGRO else Paleta.UI_PAPEL
			-- En el aviso, crece al cambiar de numero y se encoge durante el segundo
			latido = if s <= AVISO then LATIDO * (faltan - (s - 1)) else 0
		else
			textoNumero, color, latido = Textos.PATIO.bolsaLibre, Paleta.UI_DINERO, 0
		end
		if textoNumero ~= r.ultimo then
			r.ultimo = textoNumero
			r.numero.Text = textoNumero
			r.numero.TextColor3 = color
		end
		r.escala.Scale = 1 + latido
	end
end)
