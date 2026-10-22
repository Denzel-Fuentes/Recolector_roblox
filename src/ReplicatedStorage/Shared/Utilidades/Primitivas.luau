--!strict
--[[
	Primitivas
	Los ladrillos con los que se construye TODO modelo whitebox del juego:
	Part (bloque, bola, cilindro), WedgePart (cuna), modelos con el pivote en
	el suelo, Random con semilla de texto y la etiqueta flotante. Sin texturas.

	Por que es un modulo aparte: ModelosObjetos y ModelosMonton comparten
	exactamente este vocabulario (y el cliente lo usa en la cinta de la
	recicladora). Cualquier cambio de material, sombra o superficie se hace
	aqui una vez.

	Todas las partes salen ANCLADAS y sin colision: quien las necesite con
	fisica (la basura de las montanas) las cambia despues. El origen de cada
	modelo esta en el suelo, bajo el centro, para colocarlo con
	PivotTo(CFrame.new(posSuelo)); ver pivoteEnSuelo y su OJO.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))

local Primitivas = {}

export type Props = {
	Nombre: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Shape: Enum.PartType?,
	Transparency: number?,
	Reflectance: number?,
	Material: Enum.Material?,
	Variante: string?, -- MaterialVariant por nombre (Paleta.VARIANTES); si no existe en el place, se ignora
	Parent: Instance,
}

-- Material base + variante generada (MaterialService) si la hay. Asignar un
-- nombre de variante que no existe no da error: la parte usa el material base.
function Primitivas.materializar(x: BasePart, material: Enum.Material?, variante: string?)
	x.Material = material or Enum.Material.SmoothPlastic
	if variante then
		x.MaterialVariant = variante
	end
end

function Primitivas.parte(p: Props): Part
	local x = Instance.new("Part")
	x.Name = p.Nombre or "Parte"
	x.Anchored = true
	x.CanCollide = false
	x.CanTouch = false
	x.CanQuery = true
	x.CastShadow = true
	Primitivas.materializar(x, p.Material, p.Variante)
	x.TopSurface = Enum.SurfaceType.Smooth
	x.BottomSurface = Enum.SurfaceType.Smooth
	x.Size = p.Size
	x.CFrame = p.CFrame
	x.Color = p.Color or Paleta.MUEBLE
	if p.Shape then
		x.Shape = p.Shape
	end
	if p.Transparency then
		x.Transparency = p.Transparency
	end
	if p.Reflectance then
		x.Reflectance = p.Reflectance
	end
	x.Parent = p.Parent
	return x
end

function Primitivas.cuna(p: Props): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = p.Nombre or "Cuna"
	w.Anchored = true
	w.CanCollide = false
	w.CanTouch = false
	Primitivas.materializar(w, p.Material, p.Variante)
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Size = p.Size
	w.CFrame = p.CFrame
	w.Color = p.Color or Paleta.MUEBLE
	if p.Transparency then
		w.Transparency = p.Transparency
	end
	w.Parent = p.Parent
	return w
end

-- Cilindro con el eje VERTICAL (Roblox lo crea con el eje en X)
function Primitivas.cilindroVertical(nombre: string, diametro: number, alto: number, cf: CFrame, color: Color3, padre: Instance): Part
	return Primitivas.parte({
		Nombre = nombre,
		Size = Vector3.new(alto, diametro, diametro),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Shape = Enum.PartType.Cylinder,
		Parent = padre,
	})
end

-- Cilindro con el eje en Z (tumbado hacia el frente)
function Primitivas.cilindroHorizontal(nombre: string, diametro: number, largo: number, cf: CFrame, color: Color3, padre: Instance): Part
	return Primitivas.parte({
		Nombre = nombre,
		Size = Vector3.new(largo, diametro, diametro),
		CFrame = cf * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Shape = Enum.PartType.Cylinder,
		Parent = padre,
	})
end

function Primitivas.esfera(nombre: string, diametro: number, cf: CFrame, color: Color3, padre: Instance): Part
	return Primitivas.parte({ Nombre = nombre, Size = Vector3.new(diametro, diametro, diametro), CFrame = cf, Color = color, Shape = Enum.PartType.Ball, Parent = padre })
end

function Primitivas.bloque(nombre: string, size: Vector3, cf: CFrame, color: Color3, padre: Instance): Part
	return Primitivas.parte({ Nombre = nombre, Size = size, CFrame = cf, Color = color, Parent = padre })
end

function Primitivas.semilla(texto: string): Random
	local h = 7
	for i = 1, #texto do
		h = (h * 31 + string.byte(texto, i)) % 2147483647
	end
	return Random.new(h)
end

function Primitivas.nuevoModelo(nombre: string): Model
	local m = Instance.new("Model")
	m.Name = nombre
	return m
end

-- Deja el pivote del modelo en el origen local (el suelo bajo el centro).
-- OJO: asignar Model.WorldPivot se IGNORA cuando hay PrimaryPart (medido en
-- Studio); lo que manda es PrimaryPart.PivotOffset, asi que se calcula desde
-- la posicion de la parte principal. Sin esto, PivotTo pone la parte
-- principal en el destino y el resto del modelo queda hundido.
function Primitivas.pivoteEnSuelo(m: Model)
	local principal = m.PrimaryPart
	if principal then
		principal.PivotOffset = principal.CFrame:Inverse()
	else
		m.WorldPivot = CFrame.new(0, 0, 0)
	end
end

function Primitivas.aclarar(color: Color3, f: number): Color3
	return Color3.new(
		math.clamp(color.R + (1 - color.R) * f, 0, 1),
		math.clamp(color.G + (1 - color.G) * f, 0, 1),
		math.clamp(color.B + (1 - color.B) * f, 0, 1)
	)
end

-- Etiqueta flotante encima de un modelo (nombre de un objeto, de un NPC...)
function Primitivas.etiqueta(modelo: Model, texto: string, color: Color3?, altura: number?): BillboardGui?
	local base = modelo.PrimaryPart
	if not base then
		return nil
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Etiqueta"
	bb.Size = UDim2.fromOffset(140, 26)
	bb.StudsOffsetWorldSpace = Vector3.new(0, altura or 2.6, 0)
	bb.MaxDistance = 45
	bb.AlwaysOnTop = false
	bb.AutoLocalize = false -- el idioma lo pone Utilidades/Idioma, no Roblox
	bb.Parent = base
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundColor3 = Paleta.UI_PAPEL
	tl.BackgroundTransparency = 0.35
	tl.TextColor3 = color or Paleta.UI_TINTA
	tl.Text = texto
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamMedium
	tl.Parent = bb
	local esquinas = Instance.new("UICorner")
	esquinas.CornerRadius = UDim.new(0, 6)
	esquinas.Parent = tl
	return bb
end

return Primitivas
