--!strict
--[[
	Celebraciones
	Unica responsabilidad: festejar en pantalla y en el mundo cuando la
	bolsa entra en un contenedor (acierto) o se entrega a mano (entrega).
	Sustituye al toast "¡Dentro del General! +$X desde N m..." (peticion
	del usuario, 5 oct: letras que aparezcan un momento con efecto, no un
	modal).

	  Titulo     "¡DENTRO!" / "¡RECICLADO!" en el color del contenedor
	             (Paleta.TIPO), entra con un rebote de escala y un giro.
	  Dinero     "+$160" contando desde 0; al final vuela encogiendose
	             hasta el contador de dinero del HUD (frame "Contadores").
	  Pildoras   el desglose, una tras otra: distancia, bonus, racha y
	             separacion.
	  Mundo      rafaga de destellos y un anillo de luz del color del
	             contenedor sobre su boca.

	Llega por CelebracionEvent (Lanzamiento y BotinHandler) con una tabla:
	{ tipo, contenedor, dinero, distancia?, bonusPct?, racha?, separadas,
	malSeparadas, posicion? }. Una celebracion nueva corta la anterior.
	PruebasCliente la dispara con ("celebracion") para verla sin lanzar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local Utilidades = Shared:WaitForChild("Utilidades")
local Red = require(Utilidades:WaitForChild("Red"))
local Formato = require(Utilidades:WaitForChild("Formato"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local Escala = require(script.Parent:WaitForChild("Kit"):WaitForChild("Escala"))

local Children = Fusion.Children
local peek = Fusion.peek

local CelebracionEvent = Red.evento("CelebracionEvent")

local jugador = Players.LocalPlayer
local scope = Fusion.scoped(Fusion, Kit)
local pantalla = scope:Pantalla({ Nombre = "Celebraciones", Orden = 25 })

local TEXTURA_DESTELLO = "rbxasset://textures/particles/sparkles_main.dds"
local DURACION = 2.4 -- de principio a fin
local VUELO = 1.7 -- cuando el dinero sale volando al contador
local FUNDIDO = 1.95 -- cuando se funde todo

export type Datos = {
	tipo: string,
	contenedor: string,
	dinero: number,
	distancia: number?,
	bonusPct: number?,
	racha: number?,
	separadas: number?,
	malSeparadas: number?,
	posicion: Vector3?,
}

-- ===========================================================================
-- En el mundo
-- ===========================================================================

local function efectoMundo(posicion: Vector3, color: Color3)
	local ancla = Instance.new("Part")
	ancla.Name = "CelebracionMundo"
	ancla.Anchored = true
	ancla.CanCollide = false
	ancla.CanQuery = false
	ancla.CanTouch = false
	ancla.Transparency = 1
	ancla.Size = Vector3.one
	ancla.CFrame = CFrame.new(posicion + Vector3.new(0, 1.5, 0))
	ancla.Parent = workspace

	local destellos = Instance.new("ParticleEmitter")
	destellos.Texture = TEXTURA_DESTELLO
	destellos.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color)
	destellos.LightEmission = 0.8
	destellos.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) })
	destellos.Transparency = NumberSequence.new(0, 0.6)
	destellos.Speed = NumberRange.new(14, 24)
	destellos.SpreadAngle = Vector2.new(55, 55)
	destellos.EmissionDirection = Enum.NormalId.Top
	destellos.Lifetime = NumberRange.new(0.6, 1.1)
	destellos.Acceleration = Vector3.new(0, -30, 0)
	destellos.Rotation = NumberRange.new(0, 360)
	destellos.RotSpeed = NumberRange.new(-200, 200)
	destellos.Rate = 0
	destellos.Parent = ancla
	destellos:Emit(45)

	-- Anillo de luz que se abre sobre la boca del contenedor
	local anillo = Instance.new("Part")
	anillo.Name = "Anillo"
	anillo.Shape = Enum.PartType.Cylinder
	anillo.Anchored = true
	anillo.CanCollide = false
	anillo.CanQuery = false
	anillo.CanTouch = false
	anillo.CastShadow = false
	anillo.Material = Enum.Material.Neon
	anillo.Color = color
	anillo.Transparency = 0.2
	anillo.Size = Vector3.new(0.2, 1, 1)
	anillo.CFrame = CFrame.new(posicion + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	anillo.Parent = ancla
	TweenService:Create(anillo, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 11, 11),
		Transparency = 1,
	}):Play()

	task.delay(2, function()
		ancla:Destroy()
	end)
end

-- ===========================================================================
-- En pantalla
-- ===========================================================================

-- Centro del contador de dinero del HUD en px de diseno (los de Position:
-- el UIScale de la pantalla divide los px reales por Escala.escala)
local function destinoDinero(): UDim2
	local hud = jugador:FindFirstChildOfClass("PlayerGui")
	local contadores = hud and hud:FindFirstChild("Contadores", true)
	local factor = peek(Escala.escala) :: number
	if contadores and contadores:IsA("GuiObject") and factor > 0 then
		local centro = contadores.AbsolutePosition + Vector2.new(contadores.AbsoluteSize.X * 0.6, contadores.AbsoluteSize.Y * 0.3)
		return UDim2.fromOffset(centro.X / factor, centro.Y / factor)
	end
	return UDim2.new(1, -160, 0, 40)
end

-- Las lineas del desglose (texto, color del borde)
local function pildorasDe(d: Datos): { { texto: string, color: Color3 } }
	local lista = {}
	if d.distancia and d.distancia > 0 then
		table.insert(lista, { texto = Textos.formatear(Textos.CELEBRACION.distancia, { distancia = d.distancia }), color = Paleta.UI_TINTA })
	end
	if d.bonusPct and d.bonusPct > 0 then
		table.insert(lista, { texto = Textos.formatear(Textos.CELEBRACION.bonusDistancia, { pct = d.bonusPct }), color = Paleta.UI_DINERO })
	end
	if d.racha and d.racha >= 2 then
		table.insert(lista, { texto = Textos.formatear(Textos.CELEBRACION.racha, { n = d.racha }), color = Paleta.UI_PELIGRO })
	end
	if d.separadas and d.separadas > 0 then
		table.insert(lista, { texto = Textos.formatear(Textos.CELEBRACION.separadas, { n = d.separadas }), color = Paleta.TIPO[d.contenedor] or Paleta.UI_DINERO })
	end
	if d.malSeparadas and d.malSeparadas > 0 then
		table.insert(lista, { texto = Textos.formatear(Textos.CELEBRACION.malSeparadas, { n = d.malSeparadas }), color = Paleta.UI_TINTA_SUAVE })
	end
	return lista
end

local actual: any = nil

local function celebrar(d: Datos)
	if actual then
		Fusion.doCleanup(actual)
		actual = nil
	end
	local s = scope:innerScope()
	actual = s
	local color = Paleta.TIPO[d.contenedor] or Paleta.TIPO.General

	-- Estado animado: los Springs con poco amortiguamiento dan el rebote
	local escalaTitulo = s:Value(0)
	local giroTitulo = s:Value(-12)
	local escalaDinero = s:Value(0)
	local posDinero = s:Value(UDim2.fromScale(0.5, 0.36))
	local dineroMostrado = s:Value(0)
	local transparencia = s:Value(0)
	local opacidad = s:Tween(transparencia, TweenInfo.new(0.4))

	local function texto(props: {
		Texto: any,
		Tamano: number,
		Color: Color3,
		Size: UDim2,
		Position: any?,
		AnchorPoint: Vector2?,
		Grosor: number?,
	}): TextLabel
		return s:Texto({
			Texto = props.Texto,
			Tamano = props.Tamano,
			Color = props.Color,
			Fuente = "titulo",
			Alinear = Enum.TextXAlignment.Center,
			Ajustar = false,
			Size = props.Size,
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			Transparencia = opacidad,
			Hijos = {
				s:New("UIStroke")({
					Color = Paleta.UI_TINTA,
					Thickness = props.Grosor or 4,
					Transparency = opacidad,
				}),
			},
		})
	end

	local titulo = texto({
		Texto = if d.tipo == "entrega" then Textos.CELEBRACION.entrega else Textos.CELEBRACION.acierto,
		Tamano = 92,
		Color = color,
		Size = UDim2.fromOffset(720, 110),
		Position = UDim2.fromScale(0.5, 0.25),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Grosor = 5,
	})
	s:Hydrate(titulo)({
		Rotation = s:Spring(giroTitulo, 22, 0.45),
		[Children] = s:New("UIScale")({ Scale = s:Spring(escalaTitulo, 28, 0.42) }),
	})

	local dinero = texto({
		Texto = s:Computed(function(use)
			return Textos.formatear(Textos.CELEBRACION.dinero, { dinero = Formato.miles(math.floor(use(dineroMostrado) :: number)) })
		end),
		Tamano = 66,
		Color = Paleta.UI_DINERO,
		Size = UDim2.fromOffset(460, 80),
		Position = s:Spring(posDinero, 16, 0.85),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	s:Hydrate(dinero)({
		[Children] = s:New("UIScale")({ Scale = s:Spring(escalaDinero, 26, 0.5) }),
	})

	-- Pildoras del desglose, apiladas bajo el dinero
	local lineas = pildorasDe(d)
	local escalasPildora = {}
	local pildoras = {}
	for i, linea in lineas do
		local escala = s:Value(0)
		escalasPildora[i] = escala
		table.insert(pildoras, s:New("Frame")({
			Name = "Pildora" .. i,
			LayoutOrder = i,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			BackgroundColor3 = Paleta.UI_PAPEL,
			BackgroundTransparency = opacidad,
			[Children] = {
				s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				s:New("UIStroke")({ Color = linea.color, Thickness = 3, Transparency = opacidad, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				s:New("UIPadding")({ PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
				s:New("UIScale")({ Scale = s:Spring(escala, 30, 0.5) }),
				s:Texto({
					Texto = linea.texto,
					Tamano = 20,
					Fuente = "titulo",
					Color = Paleta.UI_TINTA,
					Ajustar = false,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromScale(0, 1),
					Transparencia = opacidad,
				}),
			},
		}))
	end
	local pila = s:New("Frame")({
		Name = "Desglose",
		Size = UDim2.fromOffset(600, 200),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		[Children] = {
			s:New("UIListLayout")({
				Padding = UDim.new(0, 8),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			pildoras,
		},
	})

	-- (s:New lo deja en el scope: doCleanup lo destruye)
	s:New("Frame")({
		Name = "Celebracion",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = pantalla,
		[Children] = { titulo, dinero, pila },
	})

	if d.posicion then
		efectoMundo(d.posicion, color)
	end

	-- Linea de tiempo
	escalaTitulo:set(1)
	giroTitulo:set(0)
	task.delay(0.15, function()
		if actual ~= s then
			return
		end
		escalaDinero:set(1)
		local t0 = os.clock()
		while actual == s do
			local t = math.min(1, (os.clock() - t0) / 0.6)
			dineroMostrado:set(d.dinero * (1 - (1 - t) ^ 3))
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
	for i, escala in escalasPildora do
		task.delay(0.45 + (i - 1) * 0.12, function()
			if actual == s then
				escala:set(1)
			end
		end)
	end
	task.delay(VUELO, function()
		if actual == s then
			posDinero:set(destinoDinero())
			escalaDinero:set(0.35)
			escalaTitulo:set(0.6)
		end
	end)
	task.delay(FUNDIDO, function()
		if actual == s then
			transparencia:set(1)
		end
	end)
	task.delay(DURACION, function()
		if actual == s then
			Fusion.doCleanup(s)
			actual = nil
		end
	end)
end

CelebracionEvent.OnClientEvent:Connect(function(datos)
	if typeof(datos) ~= "table" or typeof(datos.dinero) ~= "number" then
		return
	end
	celebrar(datos :: Datos)
end)

-- Para PruebasCliente: ("celebracion") sin lanzar
local prueba = Instance.new("BindableEvent")
prueba.Name = "CelebracionPrueba"
prueba.Event:Connect(function(datos)
	celebrar(datos)
end)
prueba.Parent = script
