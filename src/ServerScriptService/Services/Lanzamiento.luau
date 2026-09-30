--!strict
--[[
	Lanzamiento (ModuleScript)
	Unica responsabilidad: la Punteria. Mantener pulsado carga la fuerza; al
	soltar, la bolsa entera sale volando con TODO lo que llevaba hacia el
	punto apuntado (la fuerza por el Brazo limita el alcance). Si pasa por
	ZonaAcierto entra: se recicla con el bonus de la distancia y de la racha
	(Config/DefinicionesPunteria) y cuenta para records, pedidos e
	insignias. Si falla, la racha vuelve a 0 y la bolsa cae como objeto
	"bolsa" que solo su DUENO puede recoger, y ahi se queda hasta que vuelva
	a por ella: no se recicla sola (decision del usuario, 29 sep; antes lo
	hacia sin bonus a los 20 s). Antes la podia recoger cualquiera ("tension
	social"); la auditoria del 26 sep lo revirtio: castigaba al que se
	arriesga y con publico infantil invitaba al acoso. Como ya no hay
	reciclado de respaldo, una bolsa que queda en alto (el techo de la
	recicladora, la tapa del contenedor) donde no se alcanza se deja en el
	suelo junto al contenedor, del lado del que lanzo. Si el dueno sale, sus
	bolsas caidas se reciclan para el (sin bonus): no pierde lo que llevaba.

	El primer lanzamiento de un perfil SIEMPRE entra (diseno v2): apunta
	solo al contenedor sin limite de brazo, y si aun asi algo lo tumbara,
	cuenta como dentro al caer. El primer tiro tiene que salir bien para
	enganchar. Las cuentas del arco estan en Utilidades/Trayectoria, las
	mismas que dibujan la linea de ayuda en el cliente.

	Records: el personal (mejorDistanciaAcierto) sale en el feed de su
	dueno; el del servidor (en memoria, por sesion), en el de todos.

	La parabola se simula aqui con PivotTo sobre un modelo anclado (con un par
	de botes al caer y rebote contra la pared del contenedor): sin fisica
	y determinista, el servidor decide si entro. Entre paso y paso se barre
	una esfera del tamano de la bolsa contra el mundo solido (lo que tiene
	CanQuery: el esqueleto whitebox, la colision de la recicladora, las
	colinas; el decorado no): contra una pared rebota, sobre una superficie
	cae y bota ahi (peticion del usuario: la bolsa atravesaba la maquina).
	El contenedor y el borde del mapa conservan su trato propio. Las barreras
	de los cuadrantes cerrados (tag BarreraCuadrante) no cuentan: son un
	bloqueo por jugador, no un muro para la bolsa. Nada de esto cuenta para
	el prompt de reciclar de cerca (BotinHandler), que no es punteria.
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
local Trayectoria = require(Utilidades:WaitForChild("Trayectoria"))
local DefinicionesPunteria = require(Config:WaitForChild("DefinicionesPunteria"))

local Servicios = ServerScriptService:WaitForChild("Services")
local TiposPatio = require(Servicios:WaitForChild("TiposPatio"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Mundo = require(Servicios:WaitForChild("Mundo"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Senal = require(Utilidades:WaitForChild("Senal"))

local NotificacionEvent = Red.evento("NotificacionEvent")
local FeedEvent = Red.evento("FeedEvent")

type Item = TiposPatio.Item

local Lanzamiento = {}

-- (jugador, distancia, racha) cada vez que una bolsa entra; la escuchan el
-- Tutorial, los pedidos y las insignias
Lanzamiento.alAcertar = Senal.nueva() :: Senal.Senal<Player, number, number>
-- (jugador) cada bolsa que no entra
Lanzamiento.alFallar = Senal.nueva() :: Senal.Senal<Player>

local COOLDOWN = 0.5
local GRAVEDAD = Trayectoria.GRAVEDAD
local ALTURA_SUELO = 1 -- el patio esta a y = 1 (respaldo si el raycast no ve suelo)
-- Una bolsa fallada que queda por encima de esto esta sobre algo (techo,
-- tapa) y no se alcanza: se baja al suelo junto al contenedor
local ALTURA_ALCANZABLE = ALTURA_SUELO + 3
-- Rebotes (peticion del usuario: que la bolsa bote un poco al caer). Una bolsa
-- llena de latas y carton bota poco y frena rapido: cada bote conserva el
-- 40 % de la velocidad vertical y el 55 % de la horizontal, como mucho 3, y
-- por debajo de 5 studs/s ya no bota, se queda.
local REBOTE_SUELO_Y = 0.4
local REBOTE_SUELO_XZ = 0.55
local REBOTE_PARED = 0.3
local BOTES_MAX = 3
local VELOCIDAD_BOTE_MIN = 5
-- Esfera con la que la bolsa choca con el mundo en vuelo. El pivote de la
-- bolsa esta en su base: el centro de la esfera va RADIO_BOLSA por encima.
local RADIO_BOLSA = 0.7
local CENTRO_BOLSA = Vector3.new(0, RADIO_BOLSA, 0)
-- Normal mas vertical que esto = superficie donde posarse; si no, pared
local NORMAL_SUELO = 0.7

local lanzamientos: { [Player]: number } = {}

-- Record de distancia del servidor en esta sesion
local recordServidor = 0

-- Registra un acierto desde `distancia` (studs al contenedor) y devuelve
-- (bonus total del tiro, racha, bonus de la distancia). Separado del vuelo
-- para poder probarlo sin lanzar.
function Lanzamiento.registrarAcierto(jugador: Player, distancia: number): (number, number, number)
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return 0, 0, 0
	end
	local bonusDistancia = DefinicionesPunteria.bonusDistancia(distancia)
	if not DefinicionesPunteria.cuentaParaRacha(distancia) then
		return bonusDistancia, perfil.racha, bonusDistancia
	end
	perfil.racha += 1
	Perfiles.estadisticaMaxima(jugador, "rachaMaxima", perfil.racha)
	Perfiles.marcarSucio(jugador)
	return bonusDistancia + DefinicionesPunteria.bonusRacha(perfil.racha), perfil.racha, bonusDistancia
end

-- Un fallo corta la racha
function Lanzamiento.registrarFallo(jugador: Player)
	local perfil = Perfiles.obtener(jugador)
	if perfil and perfil.racha > 0 then
		perfil.racha = 0
		Perfiles.marcarSucio(jugador)
	end
end

-- El primer lanzamiento de la vida del perfil siempre entra
function Lanzamiento.esPrimero(jugador: Player): boolean
	return Perfiles.leerEstadistica(jugador, "lanzamientos") == 0
end

-- Para pruebas: el record del servidor
function Lanzamiento.recordServidor(): number
	return recordServidor
end

-- Una bolsa caida de alguien que sale se recicla para el, sin bonus (antes
-- del guardado final: no pierde lo que llevaba)
local function reciclarAlSalir(dueno: Player, obj: TiposPatio.Objeto)
	if ObjetosPatio.retirar(obj.id, dueno) then
		Bolsa.reciclarSinBonus(dueno, obj.item.contenido or {})
	end
end

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
	for _, barrera in CollectionService:GetTagged("BarreraCuadrante") do
		table.insert(excluir, barrera)
	end
	for _, jugador in game:GetService("Players"):GetPlayers() do
		if jugador.Character then
			table.insert(excluir, jugador.Character)
		end
	end
	params.FilterDescendantsInstances = excluir
	-- Poco por encima de la bolsa: con +6 una bolsa bajo la cinta de la
	-- recicladora "aterrizaba" encima de la banda. Ya no hace falta mas margen:
	-- el barrido del vuelo no deja que se hunda en las colinas.
	local desde = Vector3.new(pos.X, math.max(pos.Y, ALTURA_SUELO) + 2, pos.Z)
	local r = workspace:Raycast(desde, Vector3.new(0, -60, 0), params)
	return if r then r.Position.Y else ALTURA_SUELO
end

-- La bolsa fallada queda en el suelo; solo su dueno la recoge. Si choco con
-- la pared del contenedor y aun asi acabo dentro de la caja, se deja fuera,
-- pegada a el. Si quedo en alto, donde no se alcanza, se deja junto al
-- contenedor del lado del jugador (ya no se recicla sola: si no, se perderia).
local function dejarEnElSuelo(jugador: Player, modelo: Model, pos: Vector3, chocoPared: boolean, cajaCF: CFrame, cajaSize: Vector3, items: { Item }, alturaSuelo: number)
	local suelo = Vector3.new(pos.X, alturaSuelo, pos.Z)
	local l = cajaCF:PointToObjectSpace(pos)
	local sobreLaCaja = math.abs(l.X) <= cajaSize.X / 2 and math.abs(l.Z) <= cajaSize.Z / 2
	local function junto(desde: Vector3): Vector3?
		local fuera = Vector3.new(desde.X - cajaCF.Position.X, 0, desde.Z - cajaCF.Position.Z)
		if fuera.Magnitude <= 0.1 then
			return nil
		end
		local base = cajaCF.Position + fuera.Unit * (math.max(cajaSize.X, cajaSize.Z) / 2 + 1.5)
		return Vector3.new(base.X, alturaSueloEn(base, modelo), base.Z)
	end
	if chocoPared and sobreLaCaja then
		suelo = junto(pos) or suelo
	end
	if suelo.Y > ALTURA_ALCANZABLE then
		local root = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
		local bajada = junto(if root and root:IsA("BasePart") then root.Position else pos)
		if bajada then
			modelo:SetAttribute("BajadaDesde", suelo.Y) -- lo lee la prueba bolsaEnAlto
			suelo = bajada
		end
	end
	modelo:PivotTo(CFrame.new(suelo))
	local item: Item = {
		tipo = "bolsa",
		nombre = Textos.formatear(Textos.PATIO.bolsaDe, { dueno = jugador.DisplayName }),
		contenido = items,
		dueno = jugador.DisplayName,
		duenoId = jugador.UserId,
	}
	local obj = ObjetosPatio.registrar(item, modelo, nil)
	Lanzamiento.registrarFallo(jugador)
	Lanzamiento.alFallar:Fire(jugador)
	NotificacionEvent:FireClient(jugador, Textos.PATIO.fallo, "aviso")
end

local function acertar(jugador: Player, modelo: Model, items: { Item }, distancia: number)
	modelo:Destroy()
	if not jugador.Parent then
		-- Salio con la bolsa en el aire: se recicla sin bonus (su perfil sigue
		-- ahi hasta el guardado final de DataService)
		Bolsa.reciclarSinBonus(jugador, items)
		return
	end
	local bonus, racha, bonusDistancia = Lanzamiento.registrarAcierto(jugador, distancia)
	local resumen = Bolsa.depositarItems(jugador, items, bonus)
	local redondeada = math.floor(distancia + 0.5)
	Perfiles.estadistica(jugador, "aciertos", 1)
	local recordAntes = Perfiles.leerEstadistica(jugador, "mejorDistanciaAcierto")
	Perfiles.estadisticaMaxima(jugador, "mejorDistanciaAcierto", redondeada)
	-- "¡Dentro! +$160 desde 25 studs · +40 % · racha 3"
	local texto = Textos.formatear(Textos.PATIO.acierto, { dinero = resumen.dinero, distancia = redondeada })
	if bonusDistancia > 0 then
		texto ..= Textos.formatear(Textos.PATIO.aciertoBonus, { pct = math.floor(bonusDistancia * 100 + 0.5) })
	end
	if racha >= 2 and DefinicionesPunteria.cuentaParaRacha(distancia) then
		texto ..= Textos.formatear(Textos.PATIO.aciertoRacha, { n = racha })
	end
	NotificacionEvent:FireClient(jugador, texto, "exito")
	-- Records (desde la distancia minima con bonus: a quemarropa no cuenta)
	if DefinicionesPunteria.cuentaParaRacha(distancia) then
		if redondeada > recordServidor then
			recordServidor = redondeada
			FeedEvent:FireAllClients(Textos.formatear(Textos.FEED.recordServidor, { jugador = jugador.DisplayName, distancia = redondeada }))
		elseif redondeada > recordAntes and recordAntes > 0 then
			FeedEvent:FireClient(jugador, Textos.formatear(Textos.FEED.recordPersonal, { distancia = redondeada }))
		end
	end
	Lanzamiento.alAcertar:Fire(jugador, redondeada, racha)
end

-- fuerza 0..1: la carga limita el alcance (fuerza 1 = el Brazo del jugador).
-- Devuelve (ok, motivo).
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
	local origen = Trayectoria.origen(root.Position)
	local distContenedor = Vector3.new(zona.Position.X - origen.X, 0, zona.Position.Z - origen.Z).Magnitude
	if distContenedor < GameConfig.DISTANCIA_MIN_LANZAR then
		return false, "demasiadoCerca"
	end
	local delta = punto - origen
	if delta.Magnitude < 0.5 then
		return false, "demasiadoCerca"
	end
	fuerza = math.clamp(fuerza, 0.1, 1)
	local primero = Lanzamiento.esPrimero(jugador)
	local objetivo, alcance
	if primero then
		-- El primero siempre entra: al centro del contenedor, sin limite de brazo
		objetivo = zona.Position
		alcance = (zona.Position - origen).Magnitude
	else
		objetivo, alcance = Trayectoria.objetivo(origen, punto, fuerza, Mejoras.valor(jugador, "Brazo"))
	end

	local llenado = math.clamp(Bolsa.cuenta(jugador) / math.max(Bolsa.capacidad(jugador), 1), 0.3, 1)
	local items = Bolsa.vaciar(jugador)
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
	-- Lo que la bolsa NO barre: ella misma, los objetos del patio, los
	-- personajes, y el contenedor y los limites (tienen su propio rebote)
	local excluirVuelo: { Instance } = {}
	if ObjetosPatio.carpeta then
		table.insert(excluirVuelo, ObjetosPatio.carpeta)
	end
	if contenedor then
		table.insert(excluirVuelo, contenedor)
	end
	for _, limite in limites do
		table.insert(excluirVuelo, limite)
	end
	for _, barrera in CollectionService:GetTagged("BarreraCuadrante") do
		table.insert(excluirVuelo, barrera)
	end
	for _, otro in game:GetService("Players"):GetPlayers() do
		if otro.Character then
			table.insert(excluirVuelo, otro.Character)
		end
	end

	local modelo = ModelosObjetos.bolsaLlena(llenado)
	Primitivas.etiqueta(modelo, Textos.formatear(Textos.PATIO.bolsaDe, { dueno = jugador.DisplayName }), Paleta.UI_GEMAS, 2.2)
	modelo:PivotTo(CFrame.new(origen))
	modelo.Parent = ObjetosPatio.carpeta
	table.insert(excluirVuelo, modelo)
	local paramsVuelo = RaycastParams.new()
	paramsVuelo.FilterType = Enum.RaycastFilterType.Exclude
	paramsVuelo.FilterDescendantsInstances = excluirVuelo

	local vuelo = Trayectoria.vuelo(alcance)
	local v0 = Trayectoria.velocidadInicial(origen, objetivo, vuelo)

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
		-- true cuando el barrido encontro la superficie de debajo: el suelo de
		-- los botes es ESA, no la que ve el rayo vertical (que puede dar con
		-- algo por encima, p. ej. la cinta sobre la plataforma de la esquina)
		local sueloDelBarrido = false
		while modelo.Parent do
			local ahora2 = os.clock()
			local dt = math.min(ahora2 - ultimo, 1 / 20)
			ultimo = ahora2
			local t = ahora2 - t0
			local anterior = pos
			vel += GRAVEDAD * dt
			pos += vel * dt
			local paso = pos - anterior
			if paso.Magnitude > 1e-3 then
				local choque = workspace:Spherecast(anterior + CENTRO_BOLSA, RADIO_BOLSA, paso, paramsVuelo)
				if choque then
					pos = anterior + paso.Unit * choque.Distance
					local n = choque.Normal
					if n.Y > NORMAL_SUELO then
						suelo = pos.Y
						sueloDelBarrido = true
					else
						local reflejada = vel - 2 * vel:Dot(n) * n
						vel = Vector3.new(reflejada.X * REBOTE_PARED, reflejada.Y * 0.5, reflejada.Z * REBOTE_PARED)
						pos += n * 0.05
						giro = giro * 0.5
					end
				end
			end
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
					acertar(jugador, modelo, items, distContenedor)
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
			if pos.Y <= suelo and not sueloDelBarrido then
				-- El suelo guardado es el de otro punto (el del lanzamiento, o un
				-- techo del que la bolsa ya salio): se mira el de aqui, y si esta
				-- mas abajo la bolsa sigue cayendo en vez de saltar a el
				suelo = alturaSueloEn(pos, modelo)
			end
			if pos.Y <= suelo then
				sueloDelBarrido = false
				pos = Vector3.new(pos.X, suelo, pos.Z)
				if botes >= BOTES_MAX or -vel.Y < VELOCIDAD_BOTE_MIN then
					if primero then
						acertar(jugador, modelo, items, distContenedor)
						return
					end
					dejarEnElSuelo(jugador, modelo, pos, chocoPared, cajaCF, cajaSize, items, suelo)
					return
				end
				botes += 1
				vel = Vector3.new(vel.X * REBOTE_SUELO_XZ, -vel.Y * REBOTE_SUELO_Y, vel.Z * REBOTE_SUELO_XZ)
				giro = giro * 0.6
			end
			if t > GameConfig.VIDA_PROYECTIL then
				if primero then
					acertar(jugador, modelo, items, distContenedor)
					return
				end
				dejarEnElSuelo(jugador, modelo, pos, chocoPared, cajaCF, cajaSize, items, suelo)
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
		-- Sus bolsas caidas se reciclan para el antes del guardado final
		for _, obj in ObjetosPatio.bolsasDe(jugador) do
			reciclarAlSalir(jugador, obj)
		end
	end)
end

return Lanzamiento
