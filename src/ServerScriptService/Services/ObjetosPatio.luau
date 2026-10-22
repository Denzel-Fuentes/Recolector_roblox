--!strict
--[[
	ObjetosPatio (ModuleScript)
	Unica responsabilidad: el registro de lo que hay tirado en el patio y
	quien se lo lleva. Un "objeto" es un item (ver TiposPatio) con su modelo
	en el mundo y un id; reclamar() es la unica forma de sacarlo.

	=== Lo unico realmente nuevo frente a KOTAMON: el reclamo compartido ===
	Activar un monton es un acto compartido: los objetos son de quien los
	reclame primero, sea quien sea. La atomicidad esta en reclamar():
	    if obj.reclamadoPor then return false end
	    obj.reclamadoPor = jugador
	Luau es monohilo y aqui no hay ningun yield entre la comprobacion y la
	asignacion, asi que dos reclamos "simultaneos" (dos eventos de red)
	siempre se resuelven en orden: el primero gana y el segundo ve el objeto
	ya reclamado (o ya retirado).

	Quien reclama por "clic" tiene que estar a Alcance + 2 de la SUPERFICIE del
	objeto (Utilidades/Geometria, la misma medida que usa el cliente para
	resaltar) y no haberse movido hace un momento mas de lo que puede andando
	(Movimiento, P3 22 oct: tras un teletransporte o un speed hack, 2 s sin
	recoger, motivo "movimiento"). Al reclamar, el modelo vuela 0,25 s al torso
	del jugador (feedback) y se destruye. (El Iman, que reclamaba sin
	distancia lo que arrastraba, se fue con las mascotas el 3 oct.)

	Recoger no cuesta nada (diseno v2: sin energia); el unico limite es la
	bolsa.

	Una bolsa caida (tipo "bolsa") solo la reclama su dueno (duenoId) hasta
	item.libreEn (GameConfig.BOLSA_LIBRE_SEGUNDOS desde que se posa); despues,
	cualquiera, y se queda lo que lleva (decision del usuario, 6 oct; la
	auditoria del 26 sep la dejaba solo para el dueno). Al dueno se le avisa
	de quien se la llevo. retirar() la saca sin reclamo cuando se recicla sola.

	Diseno v2, dos reglas mas sobre las piezas de un monton (puedeReclamar):
	  - de un tipo de basura que el jugador no tiene abierto, nunca
	    ("materialBloqueado", GameConfig.MATERIAL_REBIRTH), aunque el monton
	    lo haya excavado otro que si lo tiene (5 oct; ya no hay cuadrantes
	    cerrados);
	  - durante PRIORIDAD_EXCAVADOR s solo las recoge quien excavo el monton
	    ("prioridad"): que un veterano rapido no vacie la montana de un nuevo.

	Los demas modulos se enteran de que un objeto se fue por alRetirar
	(Montones lleva la cuenta y agota, FisicaBasura despierta a los vecinos)
	y de quien recogio que por alRecoger (los pedidos cuentan tesoros): asi
	este modulo no depende de ellos.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosObjetos = require(Utilidades:WaitForChild("ModelosObjetos"))
local Geometria = require(Utilidades:WaitForChild("Geometria"))
local Senal = require(Utilidades:WaitForChild("Senal"))
local Red = require(Utilidades:WaitForChild("Red"))
local Idioma = require(Utilidades:WaitForChild("Idioma"))

local Servicios = ServerScriptService:WaitForChild("Services")
local TiposPatio = require(Servicios:WaitForChild("TiposPatio"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local AvisosMundo = require(Servicios:WaitForChild("AvisosMundo"))
local Movimiento = require(Servicios:WaitForChild("Movimiento"))

local NotificacionEvent = Red.evento("NotificacionEvent")

type Item = TiposPatio.Item
type Objeto = TiposPatio.Objeto
type Monton = TiposPatio.Monton

local ObjetosPatio = {}

-- (objeto) justo despues de salir del registro (reclamado)
ObjetosPatio.alRetirar = Senal.nueva() :: Senal.Senal<Objeto>
-- (jugador, item, posicion) cada vez que alguien se lleva algo a la bolsa
-- (tambien su bolsa caida al recuperarla): los pedidos cuentan los tesoros y
-- BotinHandler manda el "+1" al cliente donde estaba el objeto
ObjetosPatio.alRecoger = Senal.nueva() :: Senal.Senal<Player, Item, Vector3>
-- workspace.Objetos: lo que no cuelga de una montana (bolsas caidas, objetos volando)
ObjetosPatio.carpeta = nil :: Folder?

local DURACION_VUELO = 0.25 -- vuelo del objeto reclamado hasta la bolsa
local TIPOS_CON_AVISO = { figurina = true, cinta = true }

local objetos: { [string]: Objeto } = {}
local contador = 0
local carpeta: Folder
local movimientos: { [Objeto]: number } = {} -- version del vuelo en curso, para cortar uno anterior

-- ===========================================================================
-- Modelos
-- ===========================================================================

-- El modelo real de un item. Sin etiqueta: en la montana no hay nombres.
function ObjetosPatio.modeloPara(item: Item): Model
	if item.tipo == "basura" then
		return ModelosObjetos.basura(item.material or "Papel")
	elseif item.tipo == "billete" then
		return ModelosObjetos.billete()
	elseif item.tipo == "tesoro" then
		return ModelosObjetos.tesoro()
	elseif item.tipo == "figurina" then
		local def = DefinicionesColeccionables.FIGURINA_POR_ID[item.id or ""]
		return if def then ModelosObjetos.figurina(def) else ModelosObjetos.tesoro()
	elseif item.tipo == "cinta" then
		local def = DefinicionesColeccionables.CINTA_POR_ID[item.id or ""]
		return if def then ModelosObjetos.cinta(def) else ModelosObjetos.tesoro()
	elseif item.tipo == "bolsa" then
		return ModelosObjetos.bolsaLlena(1)
	end
	return ModelosObjetos.tesoro()
end

-- ===========================================================================
-- Registro
-- ===========================================================================

-- Da de alta un objeto. El Parent del modelo lo pone quien llama (la montana
-- lo hace brotar en su momento; las bolsas caidas van a ObjetosPatio.carpeta).
function ObjetosPatio.registrar(item: Item, modelo: PVInstance, monton: Monton?): Objeto
	contador += 1
	local id = tostring(contador)
	modelo:SetAttribute("ObjetoId", id)
	modelo:SetAttribute("Tipo", item.tipo)
	-- El cliente no resalta ni intenta recoger los tipos que aun no tiene
	modelo:SetAttribute("MaterialBasura", item.material)
	local obj: Objeto = { id = id, item = item, modelo = modelo, reclamadoPor = nil, suelto = monton == nil, asentado = true, monton = monton }
	objetos[id] = obj
	if monton then
		monton.objetosVivos += 1
	end
	return obj
end

function ObjetosPatio.todos(): { [string]: Objeto }
	return objetos
end

function ObjetosPatio.obtener(id: string): Objeto?
	return objetos[id]
end

-- ===========================================================================
-- Vuelo a la bolsa
-- ===========================================================================

-- Transicion corta del modelo hasta un CFrame y despues alTerminar. Un
-- movimiento nuevo del mismo objeto corta al anterior.
local function mover(obj: Objeto, hasta: CFrame, duracion: number, alTerminar: () -> ())
	local version = (movimientos[obj] or 0) + 1
	movimientos[obj] = version
	local desde = obj.modelo:GetPivot()
	task.spawn(function()
		local t0 = os.clock()
		while true do
			local t = math.min(1, (os.clock() - t0) / duracion)
			local s = t * t * (3 - 2 * t)
			if not obj.modelo.Parent or movimientos[obj] ~= version then
				return
			end
			obj.modelo:PivotTo(desde:Lerp(hasta, s))
			if t >= 1 then
				movimientos[obj] = nil
				alTerminar()
				return
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

-- Feedback del clic: el modelo vuela al torso del jugador y desaparece. Se
-- ancla (lo mueve PivotTo), deja de chocar (no debe empujar al jugador) y de
-- ser consultable (no debe tapar con el rayo la siguiente pieza). Se saca de
-- la montana antes por si esta se destruye (agotado) mientras vuela.
local function volarABolsa(jugador: Player, obj: Objeto)
	local personaje = jugador.Character
	local torso = personaje and (personaje:FindFirstChild("UpperTorso") or personaje:FindFirstChild("Torso"))
	if not torso or not torso:IsA("BasePart") or not obj.modelo.Parent then
		obj.modelo:Destroy()
		return
	end
	for _, p in obj.modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
		end
	end
	obj.modelo.Parent = carpeta
	mover(obj, torso.CFrame * CFrame.new(0, -0.5, -1.5), DURACION_VUELO, function()
		obj.modelo:Destroy()
	end)
end

-- ===========================================================================
-- Reclamo atomico
-- ===========================================================================

-- Donde sale la burbuja de un rechazo: sobre el objeto (AvisosMundo
-- agrupa los repetidos de los clics seguidos)
local function encimaDe(obj: Objeto): Vector3
	local modelo = obj.modelo
	if modelo:IsA("Model") then
		local cf, tamano = modelo:GetBoundingBox()
		return cf.Position + Vector3.new(0, tamano.Y / 2 + 1.2, 0)
	elseif modelo:IsA("BasePart") then
		return modelo.Position + Vector3.new(0, modelo.Size.Y / 2 + 1.2, 0)
	end
	return modelo:GetPivot().Position + Vector3.new(0, 1.5, 0)
end

-- Al alcance de la mano: (ok, motivo si no). Recien llegado de un salto que
-- no dio el servidor (Movimiento), nada lo esta: lo que tiene delante no lo
-- alcanzo andando
local function alAlcance(jugador: Player, obj: Objeto): (boolean, string)
	if Movimiento.sospechoso(jugador) then
		return false, "movimiento"
	end
	local personaje = jugador.Character
	local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false, "lejos"
	end
	return Geometria.distanciaASuperficie(obj.modelo, root.Position) <= Mejoras.valor(jugador, "Alcance") + 2, "lejos"
end

-- Mete el item en la bolsa del jugador. false si no cabe. Recoger NUNCA paga:
-- los billetes tambien van a la bolsa y se cobran en el contenedor (Bolsa).
local function entregar(jugador: Player, item: Item): boolean
	if item.tipo == "bolsa" then
		if not Bolsa.meterVarios(jugador, item.contenido or {}) then
			return false
		end
		Perfiles.estadistica(jugador, "bolsasRecogidas", 1)
		-- Quien la recoge no recibe toast: ya le sale el "+N" en el sitio
		-- (EfectoRecogida). Si era de otro (ya libre), al dueno si se le avisa:
		-- puede estar lejos y no verlo
		if item.duenoId and item.duenoId ~= jugador.UserId then
			local dueno = Players:GetPlayerByUserId(item.duenoId)
			if dueno then
				NotificacionEvent:FireClient(dueno, Idioma.mensaje("PATIO.bolsaTeLaQuitaron", { quien = jugador.DisplayName }), "aviso")
			end
		end
		return true
	end
	if not Bolsa.meter(jugador, item) then
		return false
	end
	if item.tipo == "billete" then
		Perfiles.estadistica(jugador, "billetesEncontrados", 1)
	elseif item.tipo == "tesoro" then
		-- Sin toast: el "¡TESORO!" sale en el mundo (EfectoRecogida, 5 oct)
		Perfiles.estadistica(jugador, "tesorosEncontrados", 1)
	elseif TIPOS_CON_AVISO[item.tipo] then
		NotificacionEvent:FireClient(jugador, item.nombre, "objeto")
	end
	return true
end

-- Si el jugador puede llevarse ese objeto ahora (sin mirar distancia ni
-- bolsa): (ok, motivo). Lo usa reclamar.
-- Segundos que le quedan a una bolsa caida para ser de cualquiera (0 si ya
-- lo es). Sin libreEn se trata como protegida para siempre (por seguridad).
local function segundosParaLibre(item: Item): number
	if not item.libreEn then
		return math.huge
	end
	return math.max(0, item.libreEn - workspace:GetServerTimeNow())
end

function ObjetosPatio.puedeReclamar(jugador: Player, obj: Objeto): (boolean, string)
	if obj.item.tipo == "bolsa" and obj.item.duenoId and obj.item.duenoId ~= jugador.UserId and segundosParaLibre(obj.item) > 0 then
		return false, "ajena"
	end
	-- Un tipo de basura que el jugador aun no abrio no se recoge nunca, aunque
	-- la haya sacado otro jugador que si lo tiene (decision del usuario, 5 oct)
	if obj.item.tipo ~= "bolsa" then
		local perfil = Perfiles.obtener(jugador)
		if not GameConfig.materialAbierto(obj.item.material, if perfil then perfil.rebirths else 0) then
			return false, "materialBloqueado"
		end
	end
	local monton = obj.monton
	if monton then
		local excavador = monton.excavador
		if excavador and excavador ~= jugador and excavador.Parent and os.clock() < monton.activadoEn + GameConfig.PRIORIDAD_EXCAVADOR then
			return false, "prioridad"
		end
	end
	return true, ""
end

-- Aviso de por que no se pudo: una burbuja sobre el objeto (AvisosMundo;
-- antes era un toast arriba de la pantalla)
local function avisarRechazo(jugador: Player, obj: Objeto, motivo: string)
	if motivo == "ajena" then
		local faltan = segundosParaLibre(obj.item)
		AvisosMundo.mostrar(jugador, encimaDe(obj), Idioma.mensaje("PATIO.bolsaAjena", {
			dueno = obj.item.dueno or "?",
			s = if faltan == math.huge then "?" else math.max(1, math.ceil(faltan)),
		}), { icono = "candado" })
	elseif motivo == "materialBloqueado" then
		local material = obj.item.material or ""
		AvisosMundo.mostrar(jugador, encimaDe(obj), Idioma.mensaje("PATIO.materialBloqueado", {
			material = Idioma.mensaje("MATERIALES." .. material),
			n = GameConfig.MATERIAL_REBIRTH[material] or 1,
		}), { icono = "candado" })
	elseif motivo == "prioridad" and obj.monton then
		local monton = obj.monton
		local faltan = math.max(1, math.ceil(monton.activadoEn + GameConfig.PRIORIDAD_EXCAVADOR - os.clock()))
		AvisosMundo.mostrar(jugador, encimaDe(obj), Idioma.mensaje("PATIO.prioridad", { s = faltan, dueno = if monton.excavador then monton.excavador.DisplayName else "?" }))
	end
end

-- origen: "clic" (valida distancia), "mira" (como clic pero sin avisos: la
-- recogida automatica de la mira en el movil, que apunta sin querer a lo
-- que no puede llevarse) o "toque" (pruebas, sin distancia). Devuelve (ok, motivo).
function ObjetosPatio.reclamar(jugador: Player, objetoId: string, origen: string): (boolean, string)
	local obj = objetos[objetoId]
	if not obj then
		return false, "noExiste"
	end
	if obj.reclamadoPor then
		return false, "yaReclamado"
	end
	if origen == "clic" or origen == "mira" then
		local cerca, motivoLejos = alAlcance(jugador, obj)
		if not cerca then
			return false, motivoLejos
		end
	end
	local puede, motivo = ObjetosPatio.puedeReclamar(jugador, obj)
	if not puede then
		if origen == "clic" then
			avisarRechazo(jugador, obj, motivo)
		end
		return false, motivo
	end
	-- Bloqueo: se marca ANTES de cualquier otra cosa. Si luego no cabe en la
	-- bolsa se libera; entre medias no hay ningun yield.
	obj.reclamadoPor = jugador
	if not entregar(jugador, obj.item) then
		-- Sin aviso: el cliente ya lo ve (la barra de bolsa late y tiembla,
		-- y la bolsa de las manos esta atada)
		obj.reclamadoPor = nil
		return false, "bolsaLlena"
	end
	Perfiles.estadistica(jugador, "objetosRecogidos", 1)
	-- Donde estaba, antes de que vuele a la bolsa: ahi sale el "+1"
	local posicion = obj.modelo:GetPivot().Position
	volarABolsa(jugador, obj)
	objetos[obj.id] = nil
	ObjetosPatio.alRetirar:Fire(obj)
	ObjetosPatio.alRecoger:Fire(jugador, obj.item, posicion)
	return true, "reclamado"
end

-- Saca un objeto del registro sin que nadie lo reclame (una bolsa perdida que
-- se recicla sola). Mismo cerrojo que reclamar: si ya lo tiene alguien, false.
function ObjetosPatio.retirar(objetoId: string, porQuien: Player?): boolean
	local obj = objetos[objetoId]
	if not obj or obj.reclamadoPor then
		return false
	end
	obj.reclamadoPor = porQuien
	objetos[obj.id] = nil
	obj.modelo:Destroy()
	ObjetosPatio.alRetirar:Fire(obj)
	return true
end

-- Bolsas caidas de un jugador, libres o no (Lanzamiento: el tope de bolsas
-- en el suelo y reciclarlas al salir)
function ObjetosPatio.bolsasDe(jugador: Player): { Objeto }
	local lista = {}
	for _, obj in objetos do
		if obj.item.tipo == "bolsa" and obj.item.duenoId == jugador.UserId and not obj.reclamadoPor then
			table.insert(lista, obj)
		end
	end
	return lista
end

function ObjetosPatio.iniciar()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Objetos"
	carpeta.Parent = workspace
	ObjetosPatio.carpeta = carpeta
end

return ObjetosPatio
