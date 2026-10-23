--!strict
--[[
	Lanzamiento (ModuleScript)
	Unica responsabilidad: la Punteria. Mantener pulsado carga la fuerza; al
	soltar, la bolsa entera sale volando con TODO lo que llevaba hacia el
	punto apuntado (la fuerza por el Brazo limita el alcance). Si entra por
	la boca (ZonaAcierto) de uno de los cinco contenedores (uno por tipo de
	basura y el general, 3 oct) se recicla EN ESE con el bonus de la
	distancia a el y de la racha (Config/DefinicionesPunteria), y Bolsa
	aplica el premio por separar (x2 su tipo, x0,5 otro). El contenedor de
	un tipo que el jugador aun no tiene abierto (Bolsa.contenedorAbierto,
	6 oct) no la acepta: rebota en su tapa como en una pared y es un fallo,
	con una burbuja de candado encima (AvisosMundo). Cuenta para
	records, pedidos e insignias. Si falla, la racha vuelve a 0 y la bolsa cae como objeto
	"bolsa" que solo su DUENO puede recoger durante
	GameConfig.BOLSA_LIBRE_SEGUNDOS (30 s desde que se posa, con la cuenta
	atras encima); despues la recoge cualquiera y se queda lo que lleva
	(decision del usuario, 6 oct). No se recicla sola (29 sep; antes lo
	hacia sin bonus a los 20 s). Al principio la podia recoger cualquiera
	("tension social"); la auditoria del 26 sep lo dejo solo para el dueno
	(castigaba al que se arriesga): los 30 s son el punto medio. Como ya no hay
	reciclado de respaldo, una bolsa que queda en alto (el techo de la
	recicladora, la tapa del contenedor) donde no se alcanza se deja en el
	suelo junto al contenedor, del lado del que lanzo. Cada jugador tiene
	como mucho TOPE_BOLSAS_CAIDAS en el suelo: con una mas, la mas vieja se
	recicla sola para el, sin bonus y a x0,5 (MULT_MAL_SEPARADO), y se le
	avisa (P3, 22 oct: sin tope, un cliente que lanzara sin parar llenaria el
	patio de modelos). El x0,5 es decision del usuario (23 oct): a x1, tirar
	bolsas al suelo a proposito cobraba sin andar hasta el contenedor.

	Al salir (Perfiles.alSalir, que Guardado dispara ANTES del guardado de
	salida; aqui se cobra sin ceder) se cobra para el, sin bonus, lo que
	tenga en el suelo Y lo que tenga en el aire. Hasta el 22 oct se hacia en
	PlayerRemoving, que no tiene orden con el guardado, y lo que estaba en el
	aire se cobraba al caer, quiza despues de guardar (se perdia), o se
	quedaba en el suelo de alguien que ya no estaba. Cada bolsa en el aire es
	un Vuelo; lo resuelve una sola vez quien llegue primero (el bucle de
	vuelo al entrar o al posarse, o la salida), y el otro ya no paga.

	El servidor solo lanza bolsas LLENAS (P3, 22 oct; antes solo lo imponia el
	cliente y uno modificado farmeaba aciertos, rachas, pedidos e insignias con
	una pieza), valida el punto y la fuerza que llegan del remote
	(argumentosValidos: finitos y dentro del mapa) y no deja lanzar a quien
	acaba de moverse mas de lo que puede (Movimiento).

	El primer lanzamiento de un perfil SIEMPRE entra (diseno v2): apunta
	solo al contenedor GENERAL sin limite de brazo, y si aun asi algo lo tumbara,
	cuenta como dentro al caer. El primer tiro tiene que salir bien para
	enganchar, pero no da mas de lo que da el Brazo: paga como mucho la
	distancia del Brazo y no cuenta para records ni para mejorDistanciaAcierto
	(de la que salen las insignias de distancia). Hasta el 22 oct contaba la
	distancia real: un novato que lanzaba desde el patio cobraba +150 % y se
	llevaba "Francotirador" con un record imposible de batir. Las cuentas del
	arco estan en Utilidades/Trayectoria, las mismas que dibujan la linea de
	ayuda en el cliente.

	Records: el personal (mejorDistanciaAcierto) y el del servidor (en
	memoria, por sesion) le salen al que los bate en una tarjeta grande
	(7 oct); el del servidor, ademas, en el feed de los demas.

	La parabola se simula aqui con PivotTo sobre un modelo anclado (con un par
	de botes al caer y rebote contra la pared del contenedor): sin fisica
	y determinista, el servidor decide si entro. Cada paso es el EXACTO de
	una aceleracion constante (pos += vel*dt + g*dt^2/2): hasta el 22 oct
	era Euler (vel += g*dt; pos += vel*dt), que deja la bolsa 0,5*g*t*dt mas
	baja que el arco de Trayectoria; a 60 fps caia 0,4 studs corta y a 30,
	0,8: desde 20 studs la bolsa daba en la pared del contenedor al que se
	apuntaba al centro (la boca de los de tipo mide 4,5 x 3,5), segun los fps
	del servidor, y la linea de ayuda prometia un tiro que no se hacia
	(lanzarATipo pasaba 2 de cada 6). Entre paso y paso se barre
	una esfera del tamano de la bolsa contra el mundo solido (lo que tiene
	CanQuery: el esqueleto whitebox, la colision de la recicladora, las
	colinas; el decorado no): contra una pared rebota, sobre una superficie
	cae y bota ahi (peticion del usuario: la bolsa atravesaba la maquina).
	Los contenedores y el borde del mapa conservan su trato propio. Las barreras
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
local Idioma = require(Utilidades:WaitForChild("Idioma"))
local Trayectoria = require(Utilidades:WaitForChild("Trayectoria"))
local DefinicionesPunteria = require(Config:WaitForChild("DefinicionesPunteria"))

local Servicios = ServerScriptService:WaitForChild("Services")
local TiposPatio = require(Servicios:WaitForChild("TiposPatio"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Mundo = require(Servicios:WaitForChild("Mundo"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Cosmeticos = require(Servicios:WaitForChild("Cosmeticos"))
local AvisosMundo = require(Servicios:WaitForChild("AvisosMundo"))
local Movimiento = require(Servicios:WaitForChild("Movimiento"))
local Senal = require(Utilidades:WaitForChild("Senal"))

-- Un contenedor visto desde la bolsa en vuelo: la caja entera (sus paredes)
-- y la boca (zona). Se calcula una vez por lanzamiento.
type Diana = {
	contenedor: Mundo.Contenedor,
	cajaCF: CFrame,
	cajaSize: Vector3,
	caja: Part, -- sin padre: solo para Geometria.dentroDe
	topCaja: number,
	-- false = de un tipo que el jugador aun no tiene abierto: la bolsa rebota
	-- en su tapa como en una pared (Bolsa.contenedorAbierto, 6 oct)
	abierto: boolean,
}

local NotificacionEvent = Red.evento("NotificacionEvent")
local CelebracionEvent = Red.evento("CelebracionEvent")
local FeedEvent = Red.evento("FeedEvent")

type Item = TiposPatio.Item

-- Una bolsa en el aire: lo que lleva, su modelo y si ya se resolvio (entro,
-- se poso en el suelo o se cobro porque su dueno salio). El bucle de vuelo y
-- la salida se la disputan: la resuelve el primero que llega (resolver) y el
-- otro no hace nada. Sin ningun yield entre mirarlo y marcarlo, como el
-- reclamo de ObjetosPatio.
type Vuelo = {
	items: { Item },
	modelo: Model,
	resuelto: boolean,
}

local Lanzamiento = {}

-- Bolsas caidas que puede tener un jugador a la vez en el suelo (ver cabecera)
Lanzamiento.TOPE_BOLSAS_CAIDAS = 3

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
-- Esfera con la que la bolsa choca con el mundo en vuelo. La posicion del
-- vuelo es el punto mas bajo de la bolsa (ver apoyar): el centro de la
-- esfera va RADIO_BOLSA por encima.
local RADIO_BOLSA = 0.7
local CENTRO_BOLSA = Vector3.new(0, RADIO_BOLSA, 0)
-- Normal mas vertical que esto = superficie donde posarse; si no, pared
local NORMAL_SUELO = 0.7
-- Lo que se acepta del remote (argumentosValidos). El punto apuntado puede
-- quedar fuera de los muros Limite sin trampa: la camara del cliente puede
-- estar lejos del personaje y, apuntando al cielo, manda un punto a 40 studs
-- de ella; el margen lo deja pasar (solo da la direccion: el alcance lo pone
-- el Brazo). Lo que no pasa es un NaN, un infinito o un punto a miles de
-- studs, con los que la parabola y el barrido salian NaN.
local LIMITE_NUMERO = 1e4
local MARGEN_MAPA = 150
local ALTURA_MIN_MAPA = -100
local ALTURA_MAX_MAPA = 500

local lanzamientos: { [Player]: number } = {}
-- Las bolsas en el aire de cada jugador (ver Vuelo)
local vuelos: { [Player]: { [Vuelo]: boolean } } = {}

-- Record de distancia del servidor en esta sesion
local recordServidor = 0

-- Resuelve un vuelo si nadie lo hizo aun: true si le toca a quien llama
-- (que entonces paga o lo deja en el suelo), false si ya estaba resuelto
local function resolver(jugador: Player, vuelo: Vuelo): boolean
	if vuelo.resuelto then
		return false
	end
	vuelo.resuelto = true
	local propios = vuelos[jugador]
	if propios then
		propios[vuelo] = nil
		if next(propios) == nil then
			vuelos[jugador] = nil
		end
	end
	return true
end

-- La caja (en horizontal) que encierran los muros Limite, o nil si el mundo
-- no los tiene. Son geometria horneada: se calcula una vez.
type Caja = { minX: number, maxX: number, minZ: number, maxZ: number }
local cajaMapa: Caja? = nil
local function limitesDelMapa(): Caja?
	if cajaMapa then
		return cajaMapa
	end
	local caja: Caja? = nil
	for _, inst in CollectionService:GetTagged("Limite") do
		if inst:IsA("BasePart") then
			local cf, tamano = inst.CFrame, inst.Size
			-- La caja alineada de la parte (los muros son rectos, pero por si acaso)
			local mitad = Vector3.new(
				math.abs(cf.RightVector.X) * tamano.X + math.abs(cf.UpVector.X) * tamano.Y + math.abs(cf.LookVector.X) * tamano.Z,
				0,
				math.abs(cf.RightVector.Z) * tamano.X + math.abs(cf.UpVector.Z) * tamano.Y + math.abs(cf.LookVector.Z) * tamano.Z
			) / 2
			local p = cf.Position
			if not caja then
				caja = { minX = p.X - mitad.X, maxX = p.X + mitad.X, minZ = p.Z - mitad.Z, maxZ = p.Z + mitad.Z }
			else
				caja.minX = math.min(caja.minX, p.X - mitad.X)
				caja.maxX = math.max(caja.maxX, p.X + mitad.X)
				caja.minZ = math.min(caja.minZ, p.Z - mitad.Z)
				caja.maxZ = math.max(caja.maxZ, p.Z + mitad.Z)
			end
		end
	end
	cajaMapa = caja
	return caja
end

local function finito(x: number): boolean
	return x == x and math.abs(x) < LIMITE_NUMERO
end

-- Si el punto y la fuerza que manda el cliente se pueden usar: un Vector3 y
-- un numero, finitos (x == x descarta NaN; el limite, los infinitos) y el
-- punto dentro del mapa con su margen (ver MARGEN_MAPA). Lo usan
-- BotinHandler (antes de gastar el cooldown) y lanzarBolsa.
function Lanzamiento.argumentosValidos(punto: any, fuerza: any): boolean
	if typeof(punto) ~= "Vector3" or typeof(fuerza) ~= "number" then
		return false
	end
	if not (finito(punto.X) and finito(punto.Y) and finito(punto.Z) and finito(fuerza)) then
		return false
	end
	if punto.Y < ALTURA_MIN_MAPA or punto.Y > ALTURA_MAX_MAPA then
		return false
	end
	local caja = limitesDelMapa()
	if caja then
		return punto.X >= caja.minX - MARGEN_MAPA and punto.X <= caja.maxX + MARGEN_MAPA
			and punto.Z >= caja.minZ - MARGEN_MAPA and punto.Z <= caja.maxZ + MARGEN_MAPA
	end
	return true
end

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

-- Recicla para su dueno, sin bonus, una bolsa caida (al salir, x1; la mas
-- vieja al pasar el tope, x0,5: `factor`). Devuelve lo cobrado, o nil si ya
-- no estaba (la recogio alguien en el mismo instante: mismo cerrojo que el
-- reclamo).
local function reciclarCaida(dueno: Player, obj: TiposPatio.Objeto, factor: number?): number?
	if not ObjetosPatio.retirar(obj.id, dueno) then
		return nil
	end
	return Bolsa.reciclarSinBonus(dueno, obj.item.contenido or {}, factor).dinero
end

-- Con una bolsa caida mas que el tope, las mas viejas (las que se posaron
-- antes: menor libreEn) se reciclan solas para su dueno a x0,5 y se le avisa
-- (el texto dice "sin bonus" y lo cobrado: sigue siendo cierto)
local function aplicarTope(dueno: Player)
	local caidas = ObjetosPatio.bolsasDe(dueno)
	local sobran = #caidas - Lanzamiento.TOPE_BOLSAS_CAIDAS
	if sobran <= 0 then
		return
	end
	table.sort(caidas, function(a, b)
		return (a.item.libreEn or 0) < (b.item.libreEn or 0)
	end)
	for i = 1, sobran do
		local dinero = reciclarCaida(dueno, caidas[i], GameConfig.MULT_MAL_SEPARADO)
		if dinero then
			NotificacionEvent:FireClient(dueno, Idioma.mensaje("PATIO.bolsaViejaReciclada", { dinero = Idioma.dinero(dinero) }), "aviso")
		end
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

-- La bolsa fallada se queda como cayo (peticion del usuario, 6 oct: al
-- pararse volvia a ponerse de pie). No se copia el giro del vuelo tal cual,
-- que podria dejarla boca abajo o medio enterrada: se conserva hacia donde
-- mira y hacia donde se inclinaba. Poco inclinada se queda ladeada; si no,
-- tumbada de costado sobre la barriga, como una bolsa tirada. `haciaFuera`
-- (si choco con un contenedor) la tumba hacia fuera, no contra la pared.
local TUMBADA = math.rad(75)
local CASI_DERECHA = math.rad(35)
local function posturaDeReposo(rot: CFrame, haciaFuera: Vector3?): CFrame
	local arriba = rot.UpVector
	local inclinacion = math.acos(math.clamp(arriba.Y, -1, 1))
	local hacia = haciaFuera or Vector3.new(arriba.X, 0, arriba.Z)
	if hacia.Magnitude < 1e-3 then -- derecha o boca abajo exactas
		hacia = Vector3.new(rot.RightVector.X, 0, rot.RightVector.Z)
	end
	if hacia.Magnitude < 1e-3 then
		hacia = Vector3.xAxis
	end
	local final = if inclinacion < CASI_DERECHA then inclinacion * 0.6 else TUMBADA
	local mira = Vector3.new(rot.LookVector.X, 0, rot.LookVector.Z)
	local guinada = if mira.Magnitude > 1e-3 then math.atan2(-mira.X, -mira.Z) else 0
	return CFrame.fromAxisAngle(Vector3.yAxis:Cross(hacia.Unit), final) * CFrame.Angles(0, guinada, 0)
end

-- Coloca la bolsa girada `rot` alrededor del centro de su Cuerpo y con su
-- punto mas bajo en `punto`. El Cuerpo es casi un elipsoide (malla o bola de
-- partes): su punto mas bajo sale exacto de los semiejes. En vuelo `punto`
-- es el que siguen el barrido y los botes; antes la bolsa giraba sobre su
-- pivote (la base) y, girada, se metia en el suelo al botar y daba un salto
-- al posarse.
local function apoyar(modelo: Model, punto: Vector3, rot: CFrame)
	local cuerpo = modelo.PrimaryPart
	if not cuerpo then
		modelo:PivotTo(CFrame.new(punto) * rot)
		return
	end
	local relativo = modelo:GetPivot():ToObjectSpace(cuerpo.CFrame) -- el Cuerpo respecto al pivote
	local giro = rot * relativo.Rotation
	local vertical = giro:VectorToObjectSpace(Vector3.yAxis)
	local semi = cuerpo.Size / 2
	local alcance = Vector3.new(semi.X * vertical.X, semi.Y * vertical.Y, semi.Z * vertical.Z).Magnitude
	modelo:PivotTo(CFrame.new(punto + Vector3.new(0, alcance, 0)) * giro * relativo:Inverse())
end

-- Segundos que tarda en rodar hasta su postura de reposo al pararse
local ASENTARSE = 0.35

-- La bolsa fallada queda en el suelo; solo su dueno la recoge. Si choco con
-- la pared del contenedor y aun asi acabo dentro de la caja, se deja fuera,
-- pegada a el. Si quedo en alto, donde no se alcanza, se deja junto al
-- contenedor del lado del jugador (ya no se recicla sola: si no, se perderia).
-- `rot` es el giro con el que acabo el vuelo. El vuelo se resuelve al
-- registrarla, despues de que ruede: hasta entonces sigue "en el aire" para
-- la salida de su dueno.
local function dejarEnElSuelo(jugador: Player, vuelo: Vuelo, pos: Vector3, chocoPared: boolean, cajaCF: CFrame, cajaSize: Vector3, alturaSuelo: number, rot: CFrame)
	local modelo = vuelo.modelo
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
	local fuera = Vector3.new(suelo.X - cajaCF.Position.X, 0, suelo.Z - cajaCF.Position.Z)
	local haciaFuera = if chocoPared and fuera.Magnitude > 0.1 then fuera.Unit else nil
	local reposo = posturaDeReposo(rot, haciaFuera)
	-- Si sigue donde paro, rueda hasta su postura (no cambia de golpe); si se
	-- movio (fuera del contenedor, bajada de lo alto), se pone directamente
	if Vector3.new(suelo.X - pos.X, 0, suelo.Z - pos.Z).Magnitude < 0.5 then
		local t0 = os.clock()
		while modelo.Parent do
			local s = math.min(1, (os.clock() - t0) / ASENTARSE)
			apoyar(modelo, suelo, rot:Lerp(reposo, 1 - (1 - s) ^ 2))
			if s >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end
	apoyar(modelo, suelo, reposo)
	-- Mientras rodaba pudo salir su dueno: entonces su salida ya la cobro, y
	-- no se deja en el suelo de alguien que no esta
	if not resolver(jugador, vuelo) then
		modelo:Destroy()
		return
	end
	if not jugador.Parent then
		-- Se fue y su salida aun no llego (si no, estaria resuelto): se cobra
		-- ya, sin bonus, antes de que se guarde
		modelo:Destroy()
		Bolsa.reciclarSinBonus(jugador, vuelo.items)
		return
	end
	-- Solo del dueno hasta libreEn (cuenta desde que se posa); el atributo es
	-- para la cuenta atras del cliente (TemporizadorBolsas)
	local libreEn = workspace:GetServerTimeNow() + GameConfig.BOLSA_LIBRE_SEGUNDOS
	local item: Item = {
		tipo = "bolsa",
		nombre = Textos.formatear(Textos.PATIO.bolsaDe, { dueno = jugador.DisplayName }),
		contenido = vuelo.items,
		dueno = jugador.DisplayName,
		duenoId = jugador.UserId,
		libreEn = libreEn,
	}
	modelo:SetAttribute("LibreEn", libreEn)
	modelo:SetAttribute("Dueno", jugador.DisplayName) -- el rotulo del cliente
	ObjetosPatio.registrar(item, modelo, nil)
	Lanzamiento.registrarFallo(jugador)
	Lanzamiento.alFallar:Fire(jugador)
	aplicarTope(jugador)
	-- Sin toast (6 oct): la cuenta atras encima de la bolsa ya dice que hay
	-- que ir a por ella y cuanto queda (TemporizadorBolsas)
end

-- Distancia horizontal de un punto a la boca de un contenedor
local function distanciaA(contenedor: Mundo.Contenedor, desde: Vector3): number
	local zona = contenedor.zona
	return Vector3.new(zona.Position.X - desde.X, 0, zona.Position.Z - desde.Z).Magnitude
end

-- `primero`: el primer lanzamiento del perfil (entra siempre, sin limite de
-- brazo): paga como mucho la distancia del Brazo y no es record de nadie
local function acertar(jugador: Player, vuelo: Vuelo, distancia: number, material: string?, primero: boolean)
	vuelo.modelo:Destroy()
	if not resolver(jugador, vuelo) then
		return -- su dueno salio con ella en el aire y ya se cobro
	end
	if not jugador.Parent then
		-- Se fue y su salida aun no llego: se cobra ya, sin bonus
		Bolsa.reciclarSinBonus(jugador, vuelo.items)
		return
	end
	if primero then
		distancia = math.min(distancia, Mejoras.valor(jugador, "Brazo"))
	end
	local bonus, racha, bonusDistancia = Lanzamiento.registrarAcierto(jugador, distancia)
	local resumen = Bolsa.depositarItems(jugador, vuelo.items, bonus, material)
	local redondeada = math.floor(distancia + 0.5)
	Perfiles.estadistica(jugador, "aciertos", 1)
	local recordAntes = Perfiles.leerEstadistica(jugador, "mejorDistanciaAcierto")
	if not primero then
		-- De aqui salen tambien las insignias de distancia (Insignias)
		Perfiles.estadisticaMaxima(jugador, "mejorDistanciaAcierto", redondeada)
	end
	-- Sin toast (peticion del usuario, 5 oct): letras grandes y efectos en el
	-- cliente (Celebraciones) con el desglose: dinero, distancia, bonus,
	-- racha y separacion
	local contenedor = Mundo.contenedorDe(material)
	CelebracionEvent:FireClient(jugador, {
		tipo = "acierto",
		contenedor = resumen.contenedor,
		dinero = resumen.dinero,
		distancia = redondeada,
		bonusPct = if bonusDistancia > 0 then math.floor(bonusDistancia * 100 + 0.5) else 0,
		racha = if racha >= 2 and DefinicionesPunteria.cuentaParaRacha(distancia) then racha else 0,
		separadas = resumen.separadas,
		malSeparadas = resumen.malSeparadas,
		posicion = if contenedor then contenedor.zona.Position else nil,
	})
	-- Records (desde la distancia minima con bonus: a quemarropa no cuenta;
	-- el primer tiro tampoco). Al que lo bate, una tarjeta grande
	-- (NotificacionEvent "record", "distancia|servidor|personal"; 7 oct: en
	-- el feed se leia muy pequeno); a los demas, el del servidor en el feed
	-- (la senal social)
	if not primero and DefinicionesPunteria.cuentaParaRacha(distancia) then
		if redondeada > recordServidor then
			recordServidor = redondeada
			NotificacionEvent:FireClient(jugador, tostring(redondeada) .. "|servidor", "record")
			local texto = Idioma.mensaje("FEED.recordServidor", { jugador = jugador.DisplayName, distancia = redondeada })
			for _, otro in game:GetService("Players"):GetPlayers() do
				if otro ~= jugador then
					FeedEvent:FireClient(otro, texto)
				end
			end
		elseif redondeada > recordAntes and recordAntes > 0 then
			NotificacionEvent:FireClient(jugador, tostring(redondeada) .. "|personal", "record")
		end
	end
	Lanzamiento.alAcertar:Fire(jugador, redondeada, racha)
end

-- fuerza 0..1: la carga limita el alcance (fuerza 1 = el Brazo del jugador).
-- Devuelve (ok, motivo); motivos de rechazo: "argumentos", "cooldown",
-- "sinPersonaje", "movimiento", "nadaQueLanzar", "bolsaNoLlena",
-- "demasiadoCerca".
function Lanzamiento.lanzarBolsa(jugador: Player, punto: Vector3, fuerza: number): (boolean, string)
	if not Lanzamiento.argumentosValidos(punto, fuerza) then
		return false, "argumentos"
	end
	local ahora = os.clock()
	if ahora - (lanzamientos[jugador] or 0) < COOLDOWN then
		return false, "cooldown"
	end
	local personaje = jugador.Character
	local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
	local contenedores = Mundo.contenedores()
	local general = Mundo.contenedorDe(nil)
	if not root or not root:IsA("BasePart") or not general then
		return false, "sinPersonaje"
	end
	-- Acaba de moverse mas de lo que puede andando (Movimiento): ese tiro no
	-- se lo gano caminando hasta aqui
	if Movimiento.sospechoso(jugador) then
		return false, "movimiento"
	end
	local zona = general.zona
	if Bolsa.cuenta(jugador) == 0 then
		return false, "nadaQueLanzar"
	end
	-- Solo se lanza la bolsa llena (decision del usuario, 29 sep). El cliente
	-- ni lo intenta antes; el servidor lo impone desde el 22 oct (P3)
	if not Bolsa.estaLlena(jugador) then
		return false, "bolsaNoLlena"
	end
	local origen = Trayectoria.origen(root.Position)
	-- A quemarropa de cualquiera de los cinco no se lanza (se entrega a mano)
	for _, c in contenedores do
		if distanciaA(c, origen) < GameConfig.DISTANCIA_MIN_LANZAR then
			return false, "demasiadoCerca"
		end
	end
	local delta = punto - origen
	if delta.Magnitude < 0.5 then
		return false, "demasiadoCerca"
	end
	fuerza = math.clamp(fuerza, 0.1, 1)
	local primero = Lanzamiento.esPrimero(jugador)
	local objetivo, alcance
	if primero then
		-- El primero siempre entra: al centro del general, sin limite de brazo
		objetivo = zona.Position
		alcance = (zona.Position - origen).Magnitude
	else
		objetivo, alcance = Trayectoria.objetivo(origen, punto, fuerza, Mejoras.valor(jugador, "Brazo"))
	end

	local llenado = math.clamp(Bolsa.cuenta(jugador) / math.max(Bolsa.capacidad(jugador), 1), 0.3, 1)
	local items = Bolsa.vaciar(jugador)
	lanzamientos[jugador] = ahora
	Perfiles.estadistica(jugador, "lanzamientos", 1)

	-- La caja de cada contenedor entero (para detectar el choque con su pared)
	local dianas: { Diana } = {}
	for _, c in contenedores do
		local cajaCF, cajaSize = c.modelo:GetBoundingBox()
		local caja = Instance.new("Part")
		caja.Size = cajaSize
		caja.CFrame = cajaCF
		table.insert(dianas, {
			contenedor = c,
			cajaCF = cajaCF,
			cajaSize = cajaSize,
			caja = caja,
			topCaja = cajaCF.Position.Y + cajaSize.Y / 2,
			abierto = Bolsa.contenedorAbierto(jugador, c.material),
		})
	end
	-- La diana junto a la que se deja una bolsa fallada: la de la pared con
	-- la que choco o, si no choco con ninguna, la mas cercana a donde cae
	local function dianaCercana(pos: Vector3): Diana
		local mejor, dMejor = dianas[1], math.huge
		for _, d in dianas do
			local dist = distanciaA(d.contenedor, pos)
			if dist < dMejor then
				mejor, dMejor = d, dist
			end
		end
		return mejor
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
	-- Lo que la bolsa NO barre: ella misma, los objetos del patio, los
	-- personajes, y los contenedores y los limites (tienen su propio rebote)
	local excluirVuelo: { Instance } = {}
	if ObjetosPatio.carpeta then
		table.insert(excluirVuelo, ObjetosPatio.carpeta)
	end
	for _, d in dianas do
		table.insert(excluirVuelo, d.contenedor.modelo)
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
	ModelosObjetos.vestirBolsa(modelo, Cosmeticos.puesto(jugador, "bolsa"))
	ModelosObjetos.estelaBolsa(modelo, Cosmeticos.puesto(jugador, "estela"))
	local etiqueta = Primitivas.etiqueta(modelo, Textos.formatear(Textos.PATIO.bolsaDe, { dueno = jugador.DisplayName }), Paleta.UI_GEMAS, 2.2)
	-- El texto en espanol es el respaldo: cada cliente la escribe en su idioma (TraducirMundo)
	local rotulo = etiqueta and etiqueta:FindFirstChildOfClass("TextLabel")
	if rotulo then
		rotulo:SetAttribute("Mensaje", Idioma.codificar(Idioma.mensaje("PATIO.bolsaDe", { dueno = jugador.DisplayName })))
	end
	-- Para el sonido de cada cliente (SonidosMundo, A1): es una bolsa en vuelo
	-- (aun sin ObjetoId), de quien y con que fuerza (el whoosh es mas grave
	-- cuanta mas). Como LibreEn y Dueno al posarse: datos para pintar, nada
	-- que decida
	modelo:SetAttribute("LanzadaPor", jugador.UserId)
	modelo:SetAttribute("Fuerza", fuerza)
	modelo:PivotTo(CFrame.new(origen))
	modelo.Parent = ObjetosPatio.carpeta
	table.insert(excluirVuelo, modelo)
	local paramsVuelo = RaycastParams.new()
	paramsVuelo.FilterType = Enum.RaycastFilterType.Exclude
	paramsVuelo.FilterDescendantsInstances = excluirVuelo

	-- Desde aqui (sin haber cedido desde que se vacio la bolsa) lo que lleva
	-- esta en el aire: si su dueno sale antes de que se resuelva, lo cobra la
	-- salida (cobrarAlSalir)
	local vuelo: Vuelo = { items = items, modelo = modelo, resuelto = false }
	local propios = vuelos[jugador]
	if not propios then
		propios = {}
		vuelos[jugador] = propios
	end
	propios[vuelo] = true

	local duracion = Trayectoria.vuelo(alcance)
	local v0 = Trayectoria.velocidadInicial(origen, objetivo, duracion)

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
		local rot = CFrame.identity -- giro actual: con el se deja en el suelo
		-- Angulo acumulado paso a paso: con t * giro, cada vez que un bote
		-- frenaba el giro la bolsa saltaba de golpe a otra orientacion
		local angulo = Vector3.zero
		local botes = 0
		-- La diana con cuya pared choco (despues de un choque ya no entra en
		-- ninguna: rebota hacia fuera y cae al pie)
		local chocoCon: Diana? = nil
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
			-- Paso exacto con aceleracion constante: la bolsa sigue el arco de
			-- Trayectoria sean cuales sean los fps (ver cabecera; con Euler caia
			-- 0,5*g*t*dt mas baja)
			pos += vel * dt + 0.5 * GRAVEDAD * dt * dt
			vel += GRAVEDAD * dt
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
			angulo += giro * dt
			rot = CFrame.Angles(angulo.X, angulo.Y, 0)
			apoyar(modelo, pos, rot)
			-- Acierto o pared: la bolsa avanza ~1,5 studs por tick y la pared mide
			-- 0,5, asi que mirar solo el punto actual era una loteria (a veces
			-- caia justo en la pared antes de "entrar", a veces se la saltaba). Se
			-- decide por el TRAMO: si entro en la caja por debajo del borde, se
			-- mira por donde cruzo el plano del borde superior; si fue por dentro
			-- de la boca, entro; si no, dio contra la pared. Cada contenedor con
			-- su caja y su boca: estan separados, asi que la bolsa solo puede
			-- estar dentro de una caja a la vez.
			for _, d in dianas do
				if chocoCon or not (Geometria.dentroDe(d.caja, pos) and pos.Y < d.topCaja) then
					continue
				end
				local boca = d.contenedor.zona
				local porLaBoca = false
				if anterior.Y >= d.topCaja and pos.Y < anterior.Y then
					local f = (anterior.Y - d.topCaja) / (anterior.Y - pos.Y)
					local cruce = anterior:Lerp(pos, f)
					porLaBoca = Geometria.dentroDe(boca, Vector3.new(cruce.X, boca.Position.Y, cruce.Z))
				elseif Geometria.dentroDe(boca, pos) and Geometria.dentroDe(boca, Vector3.new(anterior.X, boca.Position.Y, anterior.Z)) then
					porLaBoca = true -- ya estaba sobre la boca y sigue bajando
				end
				if porLaBoca and d.abierto then
					acertar(jugador, vuelo, distanciaA(d.contenedor, origen), d.contenedor.material, primero)
					return
				elseif porLaBoca then
					-- Contenedor cerrado (tipo aun bloqueado): rebota en la tapa
					-- como en una pared, cae al pie y es un fallo; el candado sale
					-- sobre el contenedor
					AvisosMundo.mostrar(jugador, Vector3.new(boca.Position.X, d.topCaja + 2.5, boca.Position.Z),
						Idioma.mensaje("PATIO.contenedorBloqueado", { n = GameConfig.MATERIAL_REBIRTH[d.contenedor.material or ""] or 1 }),
						{ icono = "candado" })
				end
				-- Contra la pared: rebota hacia fuera (normal horizontal desde el
				-- centro de la caja) con poca energia y cae al pie del contenedor
				chocoCon = d
				local fuera = Vector3.new(pos.X - d.cajaCF.Position.X, 0, pos.Z - d.cajaCF.Position.Z)
				local normal = if fuera.Magnitude > 0.1 then fuera.Unit else -Vector3.new(vel.X, 0, vel.Z).Unit
				local horizontal = Vector3.new(vel.X, 0, vel.Z)
				local reflejada = horizontal - 2 * horizontal:Dot(normal) * normal
				vel = Vector3.new(reflejada.X * REBOTE_PARED, math.max(vel.Y, 0) * 0.3 + 4, reflejada.Z * REBOTE_PARED)
				pos += normal * 0.8
				giro = giro * 0.5
				break
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
						acertar(jugador, vuelo, distanciaA(general, origen), nil, true)
						return
					end
					local d = chocoCon or dianaCercana(pos)
					dejarEnElSuelo(jugador, vuelo, pos, chocoCon ~= nil, d.cajaCF, d.cajaSize, suelo, rot)
					return
				end
				botes += 1
				vel = Vector3.new(vel.X * REBOTE_SUELO_XZ, -vel.Y * REBOTE_SUELO_Y, vel.Z * REBOTE_SUELO_XZ)
				giro = giro * 0.6
			end
			if t > GameConfig.VIDA_PROYECTIL then
				if primero then
					acertar(jugador, vuelo, distanciaA(general, origen), nil, true)
					return
				end
				local d = chocoCon or dianaCercana(pos)
				dejarEnElSuelo(jugador, vuelo, pos, chocoCon ~= nil, d.cajaCF, d.cajaSize, suelo, rot)
				return
			end
			RunService.Heartbeat:Wait()
		end
		-- El modelo desaparecio en el aire: si fue la salida de su dueno, ya
		-- esta cobrado; si fue otra cosa (no deberia), se cobra sin bonus para
		-- que lo que llevaba no se pierda
		if resolver(jugador, vuelo) then
			Bolsa.reciclarSinBonus(jugador, items)
		end
	end)
	return true, "lanzado"
end

-- Lo que el jugador deja en el patio al salir, cobrado para el sin bonus:
-- lo que tiene en el aire y sus bolsas caidas. Lo llama Perfiles.alSalir
-- (Guardado lo dispara ANTES del guardado de salida, una vez por jugador,
-- tambien en el cierre del servidor) y no cede en ningun momento: el
-- guardado empieza en cuanto acaba. Las pruebas lo llaman directamente.
function Lanzamiento.cobrarAlSalir(jugador: Player)
	lanzamientos[jugador] = nil
	local propios = vuelos[jugador]
	vuelos[jugador] = nil
	if propios then
		for vuelo in propios do
			if not vuelo.resuelto then
				vuelo.resuelto = true
				vuelo.modelo:Destroy()
				Bolsa.reciclarSinBonus(jugador, vuelo.items)
			end
		end
	end
	for _, obj in ObjetosPatio.bolsasDe(jugador) do
		reciclarCaida(jugador, obj)
	end
end

function Lanzamiento.iniciar()
	Perfiles.alSalir:Connect(Lanzamiento.cobrarAlSalir)
	game:GetService("Players").PlayerRemoving:Connect(function(jugador)
		-- Solo limpieza: el dinero ya lo dejo cobrarAlSalir en el perfil
		lanzamientos[jugador] = nil
	end)
end

return Lanzamiento
