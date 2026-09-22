--!strict
--[[
	Lanzamiento (ModuleScript)
	Unica responsabilidad: la Punteria. Mantener pulsado carga la fuerza; al
	soltar, la bolsa entera sale volando con TODO lo que llevaba hacia el
	punto apuntado (la fuerza limita el alcance). Si pasa por ZonaAcierto
	entra: se recicla con +50% y cuenta para los logros de distancia. Si
	falla, cae como objeto "bolsa" que CUALQUIERA puede recoger (con todo
	dentro): decision del usuario, es la tension social del patio.

	La parabola se simula aqui con PivotTo sobre un modelo anclado (con un par
	de botes al caer y rebote contra la pared del contenedor): sin fisica
	y determinista, el servidor decide si entro. Nada de esto cuenta para el
	prompt de reciclar de cerca (BotinHandler), que no es punteria.
]]

local CollectionService = game:GetService("CollectionService")
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
local ALTURA_SUELO = 1 -- el patio esta a y = 1 (respaldo si el raycast no ve suelo)
-- Rebotes (peticion del usuario: que la bolsa bote un poco al caer). Una bolsa
-- llena de latas y carton bota poco y frena rapido: cada bote conserva el
-- 40 % de la velocidad vertical y el 55 % de la horizontal, como mucho 3, y
-- por debajo de 5 studs/s ya no bota, se queda.
local REBOTE_SUELO_Y = 0.4
local REBOTE_SUELO_XZ = 0.55
local REBOTE_PARED = 0.3
local BOTES_MAX = 3
local VELOCIDAD_BOTE_MIN = 5

local lanzamientos: { [Player]: number } = {}

-- Altura del suelo bajo un punto (rayo hacia abajo que ignora la basura y
-- los personajes): la bolsa puede caer en el patio (y = 1), en la plaza
-- (0,9) o en el lote de la recicladora (0,12).
local function alturaSueloEn(pos: Vector3, ignorar: Instance): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluir: { Instance } = { ignorar }
	if ObjetosPatio.carpeta then
		table.insert(excluir, ObjetosPatio.carpeta)
	end
	for _, jugador in game:GetService("Players"):GetPlayers() do
		if jugador.Character then
			table.insert(excluir, jugador.Character)
		end
	end
	params.FilterDescendantsInstances = excluir
	local desde = Vector3.new(pos.X, math.max(pos.Y, ALTURA_SUELO) + 6, pos.Z)
	local r = workspace:Raycast(desde, Vector3.new(0, -60, 0), params)
	return if r then r.Position.Y else ALTURA_SUELO
end

-- La bolsa fallada queda en el suelo, reclamable por cualquiera. Si choco con
-- la pared del contenedor y aun asi acabo dentro de la caja, se deja fuera,
-- pegada a el.
local function dejarEnElSuelo(jugador: Player, modelo: Model, pos: Vector3, chocoPared: boolean, cajaCF: CFrame, cajaSize: Vector3, items: { Item }, estabaLlena: boolean, alturaSuelo: number)
	local suelo = Vector3.new(pos.X, alturaSuelo, pos.Z)
	local l = cajaCF:PointToObjectSpace(pos)
	local sobreLaCaja = math.abs(l.X) <= cajaSize.X / 2 and math.abs(l.Z) <= cajaSize.Z / 2
	if chocoPared and sobreLaCaja then
		local fuera = Vector3.new(pos.X - cajaCF.Position.X, 0, pos.Z - cajaCF.Position.Z)
		if fuera.Magnitude > 0.1 then
			suelo = Vector3.new(cajaCF.Position.X, alturaSuelo, cajaCF.Position.Z) + fuera.Unit * (math.max(cajaSize.X, cajaSize.Z) / 2 + 1.5)
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
	-- Muros del borde del mapa (tag Limite) y su centro, para rebotar en ellos
	local limites: { BasePart } = {}
	local centroMapa = Vector3.zero
	for _, inst in CollectionService:GetTagged("Limite") do
		if inst:IsA("BasePart") then
			table.insert(limites, inst)
			centroMapa += inst.Position
		end
	end
	if #limites > 0 then
		centroMapa = centroMapa / #limites
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

	-- Parabola integrada paso a paso (no en forma cerrada) para poder rebotar:
	-- al tocar el suelo la bolsa bota un par de veces perdiendo velocidad, y
	-- si da contra la pared del contenedor sale despedida hacia fuera. Sigue
	-- siendo determinista y del servidor: el acierto se decide igual.
	task.spawn(function()
		local t0 = os.clock()
		local ultimo = t0
		local pos = origen
		local vel = v0
		local giro = Vector3.new(4, 3, 0)
		local botes = 0
		local chocoPared = false
		local suelo = alturaSueloEn(pos, modelo)
		while modelo.Parent do
			local ahora2 = os.clock()
			local dt = math.min(ahora2 - ultimo, 1 / 20)
			ultimo = ahora2
			local t = ahora2 - t0
			local anterior = pos
			vel += GRAVEDAD * dt
			pos += vel * dt
			modelo:PivotTo(CFrame.new(pos) * CFrame.Angles(t * giro.X, t * giro.Y, 0))
			-- Acierto o pared: la bolsa avanza ~1,5 studs por tick y la pared mide
			-- 0,5, asi que mirar solo el punto actual era una loteria (a veces
			-- caia justo en la pared antes de "entrar", a veces se la saltaba). Se
			-- decide por el TRAMO: si entro en la caja por debajo del borde, se
			-- mira por donde cruzo el plano del borde superior; si fue por dentro
			-- de la boca, entro; si no, dio contra la pared.
			local topCaja = cajaCF.Position.Y + cajaSize.Y / 2
			if not chocoPared and Geometria.dentroDe(caja, pos) and pos.Y < topCaja then
				local porLaBoca = false
				if anterior.Y >= topCaja and pos.Y < anterior.Y then
					local f = (anterior.Y - topCaja) / (anterior.Y - pos.Y)
					local cruce = anterior:Lerp(pos, f)
					porLaBoca = Geometria.dentroDe(zona, Vector3.new(cruce.X, zona.Position.Y, cruce.Z))
				elseif Geometria.dentroDe(zona, pos) and Geometria.dentroDe(zona, Vector3.new(anterior.X, zona.Position.Y, anterior.Z)) then
					porLaBoca = true -- ya estaba sobre la boca y sigue bajando
				end
				if porLaBoca then
					acertar(jugador, modelo, items, estabaLlena, distContenedor)
					return
				end
				-- Contra la pared: rebota hacia fuera (normal horizontal desde el
				-- centro de la caja) con poca energia y cae al pie del contenedor
				chocoPared = true
				local fuera = Vector3.new(pos.X - cajaCF.Position.X, 0, pos.Z - cajaCF.Position.Z)
				local normal = if fuera.Magnitude > 0.1 then fuera.Unit else -Vector3.new(vel.X, 0, vel.Z).Unit
				local horizontal = Vector3.new(vel.X, 0, vel.Z)
				local reflejada = horizontal - 2 * horizontal:Dot(normal) * normal
				vel = Vector3.new(reflejada.X * REBOTE_PARED, math.max(vel.Y, 0) * 0.3 + 4, reflejada.Z * REBOTE_PARED)
				pos += normal * 0.8
				giro = giro * 0.5
			end
			-- Contra el muro invisible del borde del mapa: rebota hacia dentro, que
			-- una bolsa no se pierda fuera de la valla
			for _, limite in limites do
				if Geometria.dentroDe(limite, pos) then
					local haciaDentro = Vector3.new(centroMapa.X - limite.Position.X, 0, centroMapa.Z - limite.Position.Z)
					local normal = if haciaDentro.Magnitude > 0.1 then haciaDentro.Unit else -Vector3.new(vel.X, 0, vel.Z).Unit
					local horizontal = Vector3.new(vel.X, 0, vel.Z)
					local reflejada = horizontal - 2 * horizontal:Dot(normal) * normal
					vel = Vector3.new(reflejada.X * REBOTE_PARED, vel.Y * 0.5, reflejada.Z * REBOTE_PARED)
					pos += normal * 2.5 -- el muro mide 2 de grosor
					break
				end
			end
			if pos.Y <= suelo then
				suelo = alturaSueloEn(pos, modelo)
				pos = Vector3.new(pos.X, suelo, pos.Z)
				if botes >= BOTES_MAX or -vel.Y < VELOCIDAD_BOTE_MIN then
					dejarEnElSuelo(jugador, modelo, pos, chocoPared, cajaCF, cajaSize, items, estabaLlena, suelo)
					return
				end
				botes += 1
				vel = Vector3.new(vel.X * REBOTE_SUELO_XZ, -vel.Y * REBOTE_SUELO_Y, vel.Z * REBOTE_SUELO_XZ)
				giro = giro * 0.6
			end
			if t > GameConfig.VIDA_PROYECTIL then
				dejarEnElSuelo(jugador, modelo, pos, chocoPared, cajaCF, cajaSize, items, estabaLlena, suelo)
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
