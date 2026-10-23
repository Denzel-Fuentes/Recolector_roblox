--!strict
--[[
	EfectoRecogida
	Unica responsabilidad: el "+1" que sale de cada objeto recogido, en el
	mundo, donde estaba (peticion del usuario, 5 oct: un premio inmediato
	por cada pieza). Sin contador encadenado: cada pieza su propio +1.

	  basura   "+1" del color de su tipo (Paleta.TIPO)
	  billete  "+$30": lo que vale al depositarlo, en verde dinero (6 oct)
	  tesoro   "¡TESORO!" violeta (su color) y mas grande
	  bolsa    "+N" (tu bolsa caida, con N objetos)

	Tesoros y billetes ademas estallan en destellos (y el tesoro con un
	anillo de luz y un fogonazo), 6 oct: lo valioso tiene que sentirse
	valioso.

	Llega por RecogidaEvent (BotinHandler, de ObjetosPatio.alRecoger) solo
	al que recogio. El texto es un BillboardGui en una parte invisible
	anclada: sale con un rebote de tamano, sube ~2,5 studs y se funde.
	PruebasCliente lo dispara con ("mas1"); el atributo Vida del script
	alarga cuanto dura (para capturarlo).

	Cada recogida suena (Client/Sonido, 2D: solo quien recoge): "recoger"
	la basura y la bolsa caida recuperada (el pop corto que mas se repite,
	con el tono al azar), "billete" y "tesoro" lo suyo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))
local Formato = require(Shared:WaitForChild("Utilidades"):WaitForChild("Formato"))

local Sonido = require(script.Parent:WaitForChild("Sonido"))

local RecogidaEvent = Red.evento("RecogidaEvent")

-- El sonido de cada tipo; lo demas (basura, bolsa caida) es "recoger"
local SONIDO_TIPO: { [string]: string } = {
	billete = "billete",
	tesoro = "tesoro",
}

local FUENTE = Font.new("rbxasset://fonts/families/FredokaOne.json")
local COLOR_TESORO = Paleta.TESORO -- violeta (7 oct), como el cofre
local SUBIDA = 2.5 -- studs que sube el texto
local VIDA = 0.85 -- s hasta desaparecer
local rng = Random.new()

local carpeta = Instance.new("Folder")
carpeta.Name = "EfectosRecogida"
carpeta.Parent = workspace

local function textoDe(tipo: string, material: string, n: number, valor: number): (string, Color3, number)
	if tipo == "tesoro" then
		return Textos.CELEBRACION.tesoro, COLOR_TESORO, 1.6
	elseif tipo == "billete" then
		return Textos.formatear(Textos.CELEBRACION.billete, { dinero = Formato.miles(valor) }), Paleta.UI_DINERO, 1.3
	end
	local color = Paleta.TIPO[material] or Paleta.UI_PAPEL
	return Textos.formatear(Textos.CELEBRACION.mas, { n = n }), color, if tipo == "bolsa" then 1.3 else 1
end

local function mostrar(posicion: Vector3, tipo: string, material: string, n: number, valor: number)
	local texto, color, grande = textoDe(tipo, material, n, valor)
	local vida = script:GetAttribute("Vida")
	local VIDA = if typeof(vida) == "number" then vida else VIDA
	local ancla = Instance.new("Part")
	ancla.Name = "Mas1"
	ancla.Anchored = true
	ancla.CanCollide = false
	ancla.CanQuery = false
	ancla.CanTouch = false
	ancla.Transparency = 1
	ancla.Size = Vector3.one * 0.2
	ancla.Position = posicion + Vector3.new(rng:NextNumber(-0.6, 0.6), 1, rng:NextNumber(-0.6, 0.6))
	ancla.Parent = carpeta

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(4 * grande, 2 * grande)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 80
	bb.StudsOffsetWorldSpace = Vector3.zero
	bb.Parent = ancla

	local etiqueta = Instance.new("TextLabel")
	etiqueta.BackgroundTransparency = 1
	etiqueta.Size = UDim2.fromScale(1, 1)
	etiqueta.Position = UDim2.fromScale(0.5, 0.5)
	etiqueta.AnchorPoint = Vector2.new(0.5, 0.5)
	etiqueta.FontFace = FUENTE
	etiqueta.TextScaled = true
	etiqueta.Text = texto
	etiqueta.TextColor3 = color
	etiqueta.Rotation = rng:NextNumber(-10, 10)
	etiqueta.Parent = bb
	local contorno = Instance.new("UIStroke")
	contorno.Color = Paleta.UI_TINTA
	contorno.Thickness = 2.5
	contorno.Parent = etiqueta
	local escala = Instance.new("UIScale")
	escala.Scale = 0.2
	escala.Parent = etiqueta

	-- Rebote de entrada, subida y fundido
	TweenService:Create(escala, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(bb, TweenInfo.new(VIDA, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, SUBIDA, 0) }):Play()
	local fundido = TweenInfo.new(VIDA * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, VIDA * 0.55)
	TweenService:Create(etiqueta, fundido, { TextTransparency = 1 }):Play()
	TweenService:Create(contorno, fundido, { Transparency = 1 }):Play()
	task.delay(VIDA + 0.05, function()
		ancla:Destroy()
	end)
end

-- Lo valioso estalla al recogerlo (peticion del usuario, 6 oct): una rafaga
-- de destellos y, el tesoro, ademas un anillo de luz que se abre y un
-- fogonazo. Piezas locales sin colision que se van solas.
local DESTELLO = "rbxasset://textures/particles/sparkles_main.dds"

local function rafaga(posicion: Vector3, tipo: string)
	local tesoro = tipo == "tesoro"
	local color = if tesoro then COLOR_TESORO else Paleta.UI_DINERO
	local ancla = Instance.new("Part")
	ancla.Name = "Rafaga"
	ancla.Anchored = true
	ancla.CanCollide = false
	ancla.CanQuery = false
	ancla.CanTouch = false
	ancla.Transparency = 1
	ancla.Size = Vector3.one * 0.2
	ancla.Position = posicion + Vector3.new(0, 0.6, 0)
	ancla.Parent = carpeta
	local e = Instance.new("ParticleEmitter")
	e.Texture = DESTELLO
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(if tesoro then 8 else 5, if tesoro then 14 else 8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Acceleration = Vector3.new(0, -6, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, if tesoro then 1 else 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = ancla
	e:Emit(if tesoro then 34 else 12)
	if tesoro then
		-- Fogonazo de luz
		local luz = Instance.new("PointLight")
		luz.Color = COLOR_TESORO
		luz.Range = 14
		luz.Brightness = 5
		luz.Shadows = false
		luz.Parent = ancla
		TweenService:Create(luz, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
		-- Anillo de neon que se abre y se funde
		local anillo = Instance.new("Part")
		anillo.Name = "Anillo"
		anillo.Shape = Enum.PartType.Cylinder
		anillo.Material = Enum.Material.Neon
		anillo.Color = COLOR_TESORO
		anillo.Anchored = true
		anillo.CanCollide = false
		anillo.CanQuery = false
		anillo.CanTouch = false
		anillo.CastShadow = false
		anillo.Transparency = 0.2
		anillo.Size = Vector3.new(0.08, 0.6, 0.6)
		anillo.CFrame = CFrame.new(posicion + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		anillo.Parent = carpeta
		local abrir = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(anillo, abrir, { Size = Vector3.new(0.08, 7, 7), Transparency = 1 }):Play()
		task.delay(0.5, function()
			anillo:Destroy()
		end)
	end
	task.delay(1, function()
		ancla:Destroy()
	end)
end

RecogidaEvent.OnClientEvent:Connect(function(posicion, tipo, material, n, valor)
	if typeof(posicion) ~= "Vector3" then
		return
	end
	local t = if typeof(tipo) == "string" then tipo else "basura"
	mostrar(posicion, t, if typeof(material) == "string" then material else "", if typeof(n) == "number" then n else 1, if typeof(valor) == "number" then valor else 0)
	if t == "tesoro" or t == "billete" then
		rafaga(posicion, t)
	end
	Sonido.tocar(SONIDO_TIPO[t] or "recoger")
end)

-- Para PruebasCliente: ("mas1")
local prueba = Instance.new("BindableEvent")
prueba.Name = "RecogidaPrueba"
prueba.Event:Connect(function(posicion, tipo, material, n, valor)
	mostrar(posicion, tipo, material, n, valor or 0)
	if tipo == "tesoro" or tipo == "billete" then
		rafaga(posicion, tipo)
	end
	Sonido.tocar(SONIDO_TIPO[tipo] or "recoger")
end)
prueba.Parent = script
