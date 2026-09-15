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
	asignacion, asi que dos reclamos "simultaneos" (dos eventos de red, o el
	bucle del iman de dos jugadores) siempre se resuelven en orden: el primero
	gana y el segundo ve el objeto ya reclamado (o ya retirado).

	Quien reclama por "clic" tiene que estar a Alcance + 2 de la SUPERFICIE del
	objeto (Utilidades/Geometria, la misma medida que usa el cliente para
	resaltar). El Iman reclama con origen "iman" sin distancia: ya lo ha
	arrastrado hasta la bolsa. Al reclamar, el modelo vuela 0,25 s al torso
	del jugador (feedback) y se destruye.

	Los demas modulos se enteran de que un objeto se fue por alRetirar
	(Montones lleva la cuenta y agota, FisicaBasura despierta a los vecinos):
	asi este modulo no depende de ellos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Textos = require(Config:WaitForChild("Textos"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosMascota = require(Utilidades:WaitForChild("ModelosMascota"))
local ModelosObjetos = require(Utilidades:WaitForChild("ModelosObjetos"))
local Geometria = require(Utilidades:WaitForChild("Geometria"))
local Senal = require(Utilidades:WaitForChild("Senal"))
local Red = require(Utilidades:WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local TiposPatio = require(Servicios:WaitForChild("TiposPatio"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))

local NotificacionEvent = Red.evento("NotificacionEvent")

type Item = TiposPatio.Item
type Objeto = TiposPatio.Objeto
type Monton = TiposPatio.Monton

local ObjetosPatio = {}

-- (objeto) justo despues de salir del registro (reclamado)
ObjetosPatio.alRetirar = Senal.nueva() :: Senal.Senal<Objeto>
-- workspace.Objetos: lo que no cuelga de una montana (bolsas caidas, objetos volando)
ObjetosPatio.carpeta = nil :: Folder?

local DURACION_VUELO = 0.25 -- vuelo del objeto reclamado hasta la bolsa
local TIPOS_CON_AVISO = { mascota = true, fragmento = true, figurina = true, cinta = true, traje = true }

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
	elseif item.tipo == "fragmento" then
		local def = DefinicionesMascotas.obtener(item.id or "")
		return if def then ModelosMascota.fragmento(def, 1) else ModelosObjetos.tesoro()
	elseif item.tipo == "mascota" then
		local def = DefinicionesMascotas.obtener(item.id or "")
		return if def then ModelosMascota.mascota(def, item.estado or 2, item.sucia) else ModelosObjetos.tesoro()
	elseif item.tipo == "figurina" then
		local def = DefinicionesColeccionables.FIGURINA_POR_ID[item.id or ""]
		return if def then ModelosObjetos.figurina(def) else ModelosObjetos.tesoro()
	elseif item.tipo == "cinta" then
		local def = DefinicionesColeccionables.CINTA_POR_ID[item.id or ""]
		return if def then ModelosObjetos.cinta(def) else ModelosObjetos.tesoro()
	elseif item.tipo == "bolsa" then
		return ModelosObjetos.bolsaLlena(1)
	end
	local def = DefinicionesColeccionables.TRAJE_POR_ID[item.id or ""]
	return if def then ModelosObjetos.traje(def) else ModelosObjetos.tesoro()
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

local avisoBolsaLlena: { [Player]: number } = {}

local function avisarBolsaLlena(jugador: Player)
	local ahora = os.clock()
	if ahora - (avisoBolsaLlena[jugador] or 0) > 2 then
		avisoBolsaLlena[jugador] = ahora
		NotificacionEvent:FireClient(jugador, Textos.PATIO.bolsaLlena, "aviso")
	end
end

local function alAlcance(jugador: Player, obj: Objeto): boolean
	local personaje = jugador.Character
	local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return Geometria.distanciaASuperficie(obj.modelo, root.Position) <= Mejoras.valor(jugador, "Alcance") + 2
end

-- Mete el item en la bolsa del jugador. false si no cabe. Recoger NUNCA paga:
-- los billetes tambien van a la bolsa y se cobran en el contenedor (Bolsa).
local function entregar(jugador: Player, item: Item): boolean
	if item.tipo == "bolsa" then
		if not Bolsa.meterVarios(jugador, item.contenido or {}) then
			return false
		end
		Perfiles.estadistica(jugador, "bolsasRecogidas", 1)
		NotificacionEvent:FireClient(jugador, Textos.formatear(Textos.PATIO.bolsaRecogida, { n = #(item.contenido or {}), dueno = item.dueno or "?" }), "objeto")
		return true
	end
	if not Bolsa.meter(jugador, item) then
		return false
	end
	if item.tipo == "billete" then
		Perfiles.estadistica(jugador, "billetesEncontrados", 1)
		NotificacionEvent:FireClient(jugador, Textos.formatear(Textos.PATIO.billete, { cantidad = item.valor or 0 }), "objeto")
	elseif TIPOS_CON_AVISO[item.tipo] then
		NotificacionEvent:FireClient(jugador, item.nombre, "objeto")
	end
	return true
end

-- origen: "clic" (valida distancia), "iman" (ya arrastrado hasta la bolsa) o
-- "toque" (pruebas). Devuelve (ok, motivo).
function ObjetosPatio.reclamar(jugador: Player, objetoId: string, origen: string): (boolean, string)
	local obj = objetos[objetoId]
	if not obj then
		return false, "noExiste"
	end
	if obj.reclamadoPor then
		return false, "yaReclamado"
	end
	if origen == "clic" and not alAlcance(jugador, obj) then
		return false, "lejos"
	end
	-- Bloqueo: se marca ANTES de cualquier otra cosa. Si luego no cabe en la
	-- bolsa se libera; entre medias no hay ningun yield.
	obj.reclamadoPor = jugador
	if not entregar(jugador, obj.item) then
		obj.reclamadoPor = nil
		avisarBolsaLlena(jugador)
		return false, "bolsaLlena"
	end
	Perfiles.estadistica(jugador, "objetosRecogidos", 1)
	volarABolsa(jugador, obj)
	objetos[obj.id] = nil
	ObjetosPatio.alRetirar:Fire(obj)
	return true, "reclamado"
end

function ObjetosPatio.iniciar()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Objetos"
	carpeta.Parent = workspace
	ObjetosPatio.carpeta = carpeta
	game:GetService("Players").PlayerRemoving:Connect(function(jugador)
		avisoBolsaLlena[jugador] = nil
	end)
end

return ObjetosPatio
