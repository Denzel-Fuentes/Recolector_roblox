--!strict
--[[
	Lanzamiento (ModuleScript)
	Unica responsabilidad: la Punteria. Mantener pulsado carga la fuerza; al
	soltar, la bolsa entera sale volando con TODO lo que llevaba hacia el
	punto apuntado (la fuerza limita el alcance). Si pasa por ZonaAcierto
	entra: se recicla con +50% y cuenta para los logros de distancia. Si
	falla, cae como objeto "bolsa" que CUALQUIERA puede recoger (con todo
	dentro): decision del usuario, es la tension social del patio.

	La parabola se simula aqui con PivotTo sobre un modelo anclado: sin fisica
	y determinista, el servidor decide si entro. Nada de esto cuenta para el
	prompt de reciclar de cerca (BotinHandler), que no es punteria.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosObjetos = require(Utilidades:WaitForChild("ModelosObjetos"))
local Primitivas = require(Utilidades:WaitForChild("Primitivas"))
local Geometria = require(Utilidades:WaitForChild("Geometria"))
local Red = require(Utilidades:WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local TiposPatio = require(Servicios:WaitForChild("TiposPatio"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Mundo = require(Servicios:WaitForChild("Mundo"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))

local NotificacionEvent = Red.evento("NotificacionEvent")

type Item = TiposPatio.Item

local Lanzamiento = {}

local COOLDOWN = 0.5
local GRAVEDAD = Vector3.new(0, -55, 0)
local ALTURA_SUELO = 1 -- el patio esta a y = 1

local lanzamientos: { [Player]: number } = {}

-- La bolsa fallada queda en el suelo, reclamable por cualquiera. Si choco con
-- la pared del contenedor se deja fuera, pegada a el, no dentro de la caja.
local function dejarEnElSuelo(jugador: Player, modelo: Model, pos: Vector3, chocoPared: boolean, cajaCF: CFrame, cajaSize: Vector3, items: { Item }, estabaLlena: boolean)
	local suelo = Vector3.new(pos.X, ALTURA_SUELO, pos.Z)
	if chocoPared then
		local fuera = Vector3.new(pos.X - cajaCF.Position.X, 0, pos.Z - cajaCF.Position.Z)
		if fuera.Magnitude > 0.1 then
			suelo = Vector3.new(cajaCF.Position.X, ALTURA_SUELO, cajaCF.Position.Z) + fuera.Unit * (math.max(cajaSize.X, cajaSize.Z) / 2 + 1.5)
		end
	end
	modelo:PivotTo(CFrame.new(suelo))
	local item: Item = {
		tipo = "bolsa",
		nombre = Textos.formatear(Textos.PATIO.bolsaDe, { dueno = jugador.DisplayName }),
		contenido = items,
		estabaLlena = estabaLlena,
		dueno = jugador.DisplayName,
	}
	ObjetosPatio.registrar(item, modelo, nil)
	NotificacionEvent:FireClient(jugador, Textos.PATIO.fallo, "aviso")
end

local function acertar(jugador: Player, modelo: Model, items: { Item }, estabaLlena: boolean, distancia: number)
	modelo:Destroy()
	local resumen = Bolsa.depositarItems(jugador, items, estabaLlena, 1 + GameConfig.BONUS_ACIERTO)
	local redondeada = math.floor(distancia + 0.5)
	Perfiles.estadistica(jugador, "aciertos", 1)
	Perfiles.estadisticaMaxima(jugador, "mejorDistanciaAcierto", redondeada)
	NotificacionEvent:FireClient(jugador, Textos.formatear(Textos.PATIO.acierto, { bonus = resumen.dinero, distancia = redondeada }), "exito")
end

-- fuerza 0..1: la carga limita el alcance (fuerza 1 = alcanceMax). Devuelve
-- (ok, motivo).
function Lanzamiento.lanzarBolsa(jugador: Player, punto: Vector3, fuerza: number): (boolean, string)
	local ahora = os.clock()
	if ahora - (lanzamientos[jugador] or 0) < COOLDOWN then
		return false, "cooldown"
	end
	local personaje = jugador.Character
	local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
	local zona = Mundo.zonaAcierto()
	if not root or not root:IsA("BasePart") or not zona then
		return false, "sinPersonaje"
	end
	if Bolsa.cuenta(jugador) == 0 then
		return false, "nadaQueLanzar"
	end
	local origen = root.Position + Vector3.new(0, 1.5, 0)
	local distContenedor = Vector3.new(zona.Position.X - origen.X, 0, zona.Position.Z - origen.Z).Magnitude
	if distContenedor < GameConfig.DISTANCIA_MIN_LANZAR then
		return false, "demasiadoCerca"
	end
	local delta = punto - origen
	if delta.Magnitude < 0.5 then
		return false, "demasiadoCerca"
	end
	fuerza = math.clamp(fuerza, 0.1, 1)
	local alcance = math.min(delta.Magnitude, fuerza * GameConfig.FUERZA_LANZAMIENTO.alcanceMax, GameConfig.DISTANCIA_MAX_LANZAR)
	local objetivo = origen + delta.Unit * alcance

	local items, estabaLlena = Bolsa.vaciar(jugador)
	lanzamientos[jugador] = ahora
	Perfiles.estadistica(jugador, "lanzamientos", 1)

	-- La caja del contenedor entero (para detectar el choque con la pared)
	local contenedor = Mundo.contenedor()
	local cajaCF, cajaSize = CFrame.new(zona.Position), zona.Size
	if contenedor then
		cajaCF, cajaSize = contenedor:GetBoundingBox()
	end
	local caja = Instance.new("Part")
	caja.Size = cajaSize
	caja.CFrame = cajaCF

	local modelo = ModelosObjetos.bolsaLlena(if estabaLlena then 1 else 0.6)
	Primitivas.etiqueta(modelo, Textos.formatear(Textos.PATIO.bolsaDe, { dueno = jugador.DisplayName }), Paleta.UI_GEMAS, 2.2)
	modelo:PivotTo(CFrame.new(origen))
	modelo.Parent = ObjetosPatio.carpeta

	local vuelo = math.clamp(alcance / 22, 0.7, 1.5)
	local v0 = (objetivo - origen - 0.5 * GRAVEDAD * vuelo * vuelo) / vuelo

	task.spawn(function()
		local t0 = os.clock()
		while modelo.Parent do
			local t = os.clock() - t0
			local pos = origen + v0 * t + 0.5 * GRAVEDAD * t * t
			modelo:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 4, t * 3, 0))
			if Geometria.dentroDe(zona, pos) then
				acertar(jugador, modelo, items, estabaLlena, distContenedor)
				return
			end
			local chocoPared = Geometria.dentroDe(caja, pos) and pos.Y < zona.Position.Y + zona.Size.Y / 2
			if pos.Y <= ALTURA_SUELO or t > GameConfig.VIDA_PROYECTIL or chocoPared then
				dejarEnElSuelo(jugador, modelo, pos, chocoPared, cajaCF, cajaSize, items, estabaLlena)
				return
			end
			RunService.Heartbeat:Wait()
		end
	end)
	return true, "lanzado"
end

function Lanzamiento.iniciar()
	game:GetService("Players").PlayerRemoving:Connect(function(jugador)
		lanzamientos[jugador] = nil
	end)
end

return Lanzamiento
