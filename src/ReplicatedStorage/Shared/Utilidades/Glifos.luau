--!strict
--[[
	Glifos
	Iconos dibujados con Frames (rectangulos redondeados, circulos, rectangulos
	girados y algun caracter) con contorno de tinta. Son el RESPALDO de
	Config/Iconos: cuando una clave no tiene imagen, la UI dibuja esto. Son
	deliberadamente simples (2-4 formas por icono): no compiten con el arte, lo
	sustituyen mientras llega, y por eso viven aparte del sistema de diseno.

	dibujar(nombre, tamano, color?) devuelve un Frame cuadrado transparente de
	`tamano` px con el dibujo en coordenadas relativas (0..1), asi el mismo
	glifo sirve para una pildora de 28 px y para una tarjeta de 120. `color`
	tine la forma principal (para iconos de un solo color, p. ej. en tinta).

	Sin estado y sin dependencias de juego: lo usan el cliente (HUD, paneles) y
	los carteles del mundo.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))

local Glifos = {}

local FUENTE = Font.new("rbxasset://fonts/families/FredokaOne.json")

-- ===========================================================================
-- Ladrillos
-- ===========================================================================

type Lienzo = { raiz: Frame, tamano: number, z: number }

local function grosor(l: Lienzo): number
	return math.max(1.2, l.tamano * 0.055)
end

-- Rectangulo redondeado en coordenadas relativas. `radio` es fraccion del lado
-- corto (0.5 = pastilla / circulo). `rot` en grados. `solo_borde` dibuja el
-- contorno sin relleno (anillos, asas).
local function forma(l: Lienzo, x: number, y: number, w: number, h: number, color: Color3, radio: number?, rot: number?, soloBorde: boolean?): Frame
	l.z += 1
	local f = Instance.new("Frame")
	f.Name = "Forma" .. l.z
	f.Size = UDim2.fromScale(w, h)
	f.Position = UDim2.fromScale(x + w / 2, y + h / 2)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = if soloBorde then 1 else 0
	f.BorderSizePixel = 0
	f.Rotation = rot or 0
	f.ZIndex = l.z
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(radio or 0.18, 0)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = Paleta.UI_TINTA
	s.Thickness = grosor(l)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	f.Parent = l.raiz
	return f
end

-- Un caracter grande con contorno (estrella, corazon, nota, check...)
local function letra(l: Lienzo, texto: string, color: Color3, escala: number?): TextLabel
	l.z += 1
	local t = Instance.new("TextLabel")
	t.Name = "Letra"
	t.Size = UDim2.fromScale(escala or 1, escala or 1)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.BackgroundTransparency = 1
	t.Text = texto
	t.TextColor3 = color
	t.TextScaled = true
	t.FontFace = FUENTE
	t.ZIndex = l.z
	local s = Instance.new("UIStroke")
	s.Color = Paleta.UI_TINTA
	s.Thickness = grosor(l)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = t
	t.Parent = l.raiz
	return t
end

local function claro(color: Color3): Color3
	return Paleta.escalar(color, 1.35)
end

local function oscuro(color: Color3): Color3
	return Paleta.escalar(color, 0.75)
end

-- ===========================================================================
-- Los dibujos
-- ===========================================================================

local PIEL = Paleta.PIEL
local MARRON = Color3.fromRGB(150, 100, 60)
local GRIS = Color3.fromRGB(170, 175, 190)

local DIBUJOS: { [string]: (l: Lienzo, color: Color3?) -> () } = {}

DIBUJOS.billete = function(l, color)
	local c = color or Paleta.UI_DINERO
	forma(l, 0.04, 0.26, 0.92, 0.48, c, 0.12)
	forma(l, 0.36, 0.34, 0.28, 0.32, claro(c), 0.5)
end

DIBUJOS.rayo = function(l, color)
	local c = color or Paleta.UI_ENERGIA
	forma(l, 0.42, 0.04, 0.26, 0.5, c, 0.1, 22)
	forma(l, 0.32, 0.46, 0.26, 0.5, c, 0.1, 22)
end

DIBUJOS.bolsa = function(l, color)
	local c = color or Paleta.UI_BOLSA
	forma(l, 0.14, 0.3, 0.72, 0.64, c, 0.32)
	forma(l, 0.2, 0.14, 0.6, 0.26, claro(c), 0.5)
	forma(l, 0.3, 0.2, 0.4, 0.14, oscuro(c), 0.5)
end

DIBUJOS.libreta = function(l, color)
	local c = color or Paleta.UI_PAPEL
	forma(l, 0.16, 0.1, 0.62, 0.8, c, 0.08)
	forma(l, 0.16, 0.1, 0.12, 0.8, Paleta.UI_CARTAS, 0.08)
	forma(l, 0.74, 0.18, 0.14, 0.16, Paleta.UI_PELIGRO, 0.3)
	forma(l, 0.74, 0.42, 0.14, 0.16, Paleta.UI_PRIMARIO, 0.3)
	forma(l, 0.74, 0.66, 0.14, 0.16, Paleta.UI_DINERO, 0.3)
end

DIBUJOS.telefono = function(l, color)
	local c = color or Paleta.UI_TINTA
	forma(l, 0.3, 0.06, 0.4, 0.88, c, 0.14)
	forma(l, 0.36, 0.16, 0.28, 0.58, Color3.fromRGB(120, 210, 230), 0.06)
	forma(l, 0.45, 0.8, 0.1, 0.08, Paleta.UI_PAPEL, 0.5)
end

DIBUJOS.trofeo = function(l, color)
	local c = color or Paleta.DORADO
	forma(l, 0.24, 0.1, 0.52, 0.44, c, 0.22)
	forma(l, 0.44, 0.52, 0.12, 0.18, oscuro(c), 0.1)
	forma(l, 0.3, 0.7, 0.4, 0.14, oscuro(c), 0.2)
end

DIBUJOS.casa = function(l, color)
	local c = color or Paleta.UI_PAPEL
	forma(l, 0.2, 0.46, 0.6, 0.46, c, 0.06)
	forma(l, 0.27, 0.1, 0.46, 0.46, Paleta.UI_PELIGRO, 0.08, 45)
	forma(l, 0.42, 0.64, 0.16, 0.28, Paleta.UI_TINTA_SUAVE, 0.1)
end

DIBUJOS.montana = function(l, color)
	local c = color or Paleta.MONTON
	forma(l, 0.44, 0.28, 0.4, 0.4, oscuro(c), 0.1, 45)
	forma(l, 0.14, 0.2, 0.5, 0.5, c, 0.1, 45)
	forma(l, 0.04, 0.6, 0.92, 0.3, Paleta.MATERIAL.Organico, 0.14)
end

DIBUJOS.lanzar = function(l, color)
	local c = color or Paleta.UI_BOLSA
	forma(l, 0.08, 0.5, 0.12, 0.12, Paleta.UI_TINTA_SUAVE, 0.5)
	forma(l, 0.24, 0.3, 0.12, 0.12, Paleta.UI_TINTA_SUAVE, 0.5)
	forma(l, 0.44, 0.2, 0.12, 0.12, Paleta.UI_TINTA_SUAVE, 0.5)
	forma(l, 0.5, 0.42, 0.44, 0.48, c, 0.32)
	forma(l, 0.56, 0.32, 0.32, 0.18, claro(c), 0.5)
end

DIBUJOS.mano = function(l, color)
	local c = color or PIEL
	forma(l, 0.26, 0.4, 0.5, 0.52, c, 0.16)
	for i = 0, 3 do
		forma(l, 0.26 + i * 0.125, 0.08, 0.11, 0.4, c, 0.3)
	end
	forma(l, 0.06, 0.42, 0.24, 0.12, c, 0.5, -30)
end

DIBUJOS.raton = function(l, color)
	local c = color or Paleta.UI_PAPEL
	forma(l, 0.3, 0.08, 0.4, 0.84, c, 0.3)
	forma(l, 0.3, 0.08, 0.2, 0.34, Paleta.UI_PRIMARIO, 0.3)
	forma(l, 0.47, 0.14, 0.06, 0.16, Paleta.UI_TINTA, 0.5)
end

DIBUJOS.lata = function(l, color)
	local c = color or Paleta.UI_CARTAS
	forma(l, 0.3, 0.1, 0.4, 0.8, c, 0.12)
	forma(l, 0.3, 0.06, 0.4, 0.14, claro(c), 0.5)
	forma(l, 0.36, 0.4, 0.28, 0.24, Paleta.UI_PAPEL, 0.1)
end

DIBUJOS.flecha = function(l, color)
	local c = color or Paleta.UI_FUERZA
	forma(l, 0.42, 0.34, 0.16, 0.6, c, 0.2)
	forma(l, 0.3, 0.1, 0.4, 0.4, c, 0.1, 45)
end

DIBUJOS.sobre = function(l, color)
	local c = color or Paleta.UI_GEMAS
	forma(l, 0.08, 0.26, 0.84, 0.58, c, 0.08)
	forma(l, 0.3, 0.06, 0.4, 0.4, claro(c), 0.08, 45)
	forma(l, 0.08, 0.5, 0.84, 0.34, c, 0.08)
end

DIBUJOS.contenedorDorado = function(l, color)
	local c = color or Paleta.DORADO
	forma(l, 0.16, 0.36, 0.68, 0.54, c, 0.1)
	forma(l, 0.08, 0.24, 0.84, 0.18, oscuro(c), 0.3)
	forma(l, 0.4, 0.12, 0.2, 0.14, oscuro(c), 0.3)
end

DIBUJOS.estrella = function(l, color)
	letra(l, "★", color or Paleta.UI_PRIMARIO, 1.1)
end

DIBUJOS.corona = function(l, color)
	local c = color or Paleta.DORADO
	forma(l, 0.14, 0.5, 0.72, 0.36, c, 0.12)
	forma(l, 0.14, 0.18, 0.2, 0.42, c, 0.1, 0)
	forma(l, 0.4, 0.08, 0.2, 0.52, c, 0.1, 0)
	forma(l, 0.66, 0.18, 0.2, 0.42, c, 0.1, 0)
	forma(l, 0.42, 0.56, 0.16, 0.16, Paleta.UI_PELIGRO, 0.5)
end

DIBUJOS.check = function(l, color)
	letra(l, "✓", color or Paleta.UI_EXITO, 1.1)
end

DIBUJOS.cruz = function(l, color)
	letra(l, "X", color or Paleta.UI_PELIGRO, 1.0)
end

DIBUJOS.corazon = function(l, color)
	letra(l, "♥", color or Paleta.UI_PELIGRO, 1.1)
end

DIBUJOS.nota = function(l, color)
	letra(l, "♫", color or Paleta.UI_TINTA, 1.0)
end

DIBUJOS.candado = function(l, color)
	local c = color or Paleta.DORADO
	forma(l, 0.3, 0.12, 0.4, 0.44, Paleta.UI_TINTA_SUAVE, 0.5, 0, true)
	forma(l, 0.22, 0.42, 0.56, 0.48, c, 0.14)
	forma(l, 0.45, 0.56, 0.1, 0.16, Paleta.UI_TINTA, 0.5)
end

DIBUJOS.figurina = function(l, color)
	local c = color or Paleta.FIGURINA
	forma(l, 0.34, 0.06, 0.32, 0.32, c, 0.5)
	forma(l, 0.28, 0.38, 0.44, 0.4, c, 0.14)
	forma(l, 0.18, 0.76, 0.64, 0.16, Paleta.UI_TINTA_SUAVE, 0.3)
end

DIBUJOS.cinta = function(l, color)
	local c = color or Paleta.CINTA
	forma(l, 0.08, 0.24, 0.84, 0.52, c, 0.1)
	forma(l, 0.18, 0.36, 0.26, 0.26, Paleta.UI_PAPEL, 0.5)
	forma(l, 0.56, 0.36, 0.26, 0.26, Paleta.UI_PAPEL, 0.5)
end

-- Camara de fotos: cambiar entre primera y tercera persona en el patio
DIBUJOS.camara = function(l, color)
	local c = color or Paleta.UI_CARTAS
	forma(l, 0.3, 0.16, 0.26, 0.16, c, 0.2)
	forma(l, 0.08, 0.28, 0.84, 0.56, c, 0.2)
	forma(l, 0.32, 0.36, 0.36, 0.36, Paleta.UI_PAPEL, 0.5)
	forma(l, 0.42, 0.46, 0.16, 0.16, Paleta.UI_TINTA, 0.5)
end

DIBUJOS.engranaje = function(l, color)
	local c = color or GRIS
	for i = 0, 3 do
		forma(l, 0.38, 0.04, 0.24, 0.92, c, 0.12, i * 45)
	end
	forma(l, 0.2, 0.2, 0.6, 0.6, c, 0.5)
	forma(l, 0.38, 0.38, 0.24, 0.24, Paleta.UI_PAPEL, 0.5)
end

DIBUJOS.bota = function(l, color)
	local c = color or MARRON
	forma(l, 0.26, 0.08, 0.36, 0.6, c, 0.1)
	forma(l, 0.26, 0.58, 0.6, 0.3, oscuro(c), 0.3)
end

DIBUJOS.cofre = function(l, color)
	local c = color or MARRON
	forma(l, 0.12, 0.42, 0.76, 0.48, c, 0.08)
	forma(l, 0.12, 0.24, 0.76, 0.24, oscuro(c), 0.3)
	forma(l, 0.42, 0.42, 0.16, 0.18, Paleta.DORADO, 0.3)
end

DIBUJOS.setMetal = function(l, color)
	local c = color or Paleta.MATERIAL.Metal
	forma(l, 0.12, 0.12, 0.76, 0.76, c, 0.5)
	forma(l, 0.12, 0.12, 0.76, 0.76, c, 0.2, 45)
	forma(l, 0.36, 0.36, 0.28, 0.28, Paleta.UI_PAPEL, 0.5)
end

DIBUJOS.setPlastico = function(l, color)
	local c = color or Paleta.MATERIAL.Plastico
	forma(l, 0.32, 0.3, 0.36, 0.64, c, 0.24)
	forma(l, 0.4, 0.06, 0.2, 0.3, c, 0.2)
	forma(l, 0.4, 0.5, 0.2, 0.24, Paleta.UI_PAPEL, 0.1)
end

DIBUJOS.setPapel = function(l, color)
	local c = color or Paleta.MATERIAL.Papel
	forma(l, 0.2, 0.08, 0.6, 0.84, c, 0.06)
	forma(l, 0.58, 0.08, 0.22, 0.22, oscuro(c), 0.06, 45)
	forma(l, 0.32, 0.4, 0.36, 0.06, Paleta.UI_TINTA_SUAVE, 0.5)
	forma(l, 0.32, 0.56, 0.36, 0.06, Paleta.UI_TINTA_SUAVE, 0.5)
end

DIBUJOS.setOrganico = function(l, color)
	local c = color or Paleta.MATERIAL.Organico
	forma(l, 0.14, 0.14, 0.62, 0.62, c, 0.45, 45)
	forma(l, 0.46, 0.46, 0.1, 0.44, oscuro(c), 0.5, -35)
end


-- ===========================================================================
-- API
-- ===========================================================================

function Glifos.existe(nombre: string): boolean
	return DIBUJOS[nombre] ~= nil
end

function Glifos.dibujar(nombre: string, tamano: number, color: Color3?): Frame
	local raiz = Instance.new("Frame")
	raiz.Name = "Glifo_" .. nombre
	raiz.Size = UDim2.fromOffset(tamano, tamano)
	raiz.BackgroundTransparency = 1
	raiz.BorderSizePixel = 0
	local l: Lienzo = { raiz = raiz, tamano = tamano, z = 0 }
	local dibujo = DIBUJOS[nombre]
	if dibujo then
		dibujo(l, color)
	else
		forma(l, 0.1, 0.1, 0.8, 0.8, Paleta.UI_PAPEL_SOMBRA, 0.5)
		letra(l, "?", Paleta.UI_TINTA, 0.7)
	end
	return raiz
end

return Glifos
