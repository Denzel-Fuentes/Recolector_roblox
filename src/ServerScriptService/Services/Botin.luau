--!strict
--[[
	Botin (ModuleScript)
	Unica responsabilidad: el patio compartido. Montones, lo que sale de ellos,
	quien se lleva cada objeto, el iman, la repoblacion y los lanzamientos.

	=== Lo unico realmente nuevo frente a KOTAMON: el reclamo compartido ===
	Activar un monton es un acto compartido: los objetos que saltan son de quien
	los toque primero, sea quien sea. La atomicidad esta en reclamar():
	    if obj.reclamadoPor then return false end
	    obj.reclamadoPor = jugador
	Luau es monohilo y aqui no hay ningun yield entre la comprobacion y la
	asignacion, asi que dos reclamos "simultaneos" (dos eventos de red, o el
	bucle del iman de dos jugadores) siempre se resuelven en orden: el primero
	gana y el segundo ve el objeto ya reclamado.

	=== RNG con pity (correccion deliberada de la queja #1 del original) ===
	Cada mascota completa que salta tira "Rara o mejor" con probabilidad
	TablasProbabilidad.probabilidadRara(pity). Si el monton no saca ninguna
	Rara+, pity += 1; si saca alguna, pity = 0. Es por jugador (quien activa) y
	persiste en el perfil. Los fragmentos usan una tabla plana pero se sesgan
	hacia mascotas que ya tienes a medias, para que el ensamblaje converja.

	=== Toque e iman ===
	No se usa .Touched. Un bucle cada INTERVALO_IMAN mide distancias: a menos de
	DISTANCIA_RECLAMO_IMAN se reclama (eso es "tocar"); dentro del radio de la
	mejora Iman el objeto se arrastra hacia el jugador. El clic (Alcance) llega
	por RemoteEvent y se valida aqui con la misma distancia.

	=== Punteria ===
	Lanzar saca un objeto de la bolsa y simula una parabola hacia el punto que
	el jugador apunto. Si pasa por ZonaAcierto (el interior del Contenedor)
	entra: vale +50% y cuenta para los logros de distancia. Si no, cae al suelo
	como objeto libre: cualquiera lo puede recoger.

	Todo lo que hay en el patio vive en workspace.Montones y workspace.Objetos
	(carpetas creadas al arrancar). Se posiciona con PivotTo sobre modelos
	anclados: sin fisica, sin welds, determinista.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local TablasProbabilidad = require(Config:WaitForChild("TablasProbabilidad"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosMascota = require(Utilidades:WaitForChild("ModelosMascota"))
local Senal = require(Utilidades:WaitForChild("Senal"))
local Red = require(Utilidades:WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Energia = require(Servicios:WaitForChild("Energia"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Mascotas = require(Servicios:WaitForChild("Mascotas"))
local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Mundo = require(Servicios:WaitForChild("Mundo"))

local FeedEvent = Red.evento("FeedEvent")
local NotificacionEvent = Red.evento("NotificacionEvent")

export type Item = Bolsa.Item

export type Monton = {
	id: number,
	ranura: BasePart,
	tamano: string,
	estado: string, -- lleno | activo | agotado
	modelo: Model?,
	anillo: BasePart?,
	objetosVivos: number,
}

export type Objeto = {
	id: string,
	item: Item,
	modelo: Model,
	reclamadoPor: Player?,
	creado: number,
	asentado: boolean,
	monton: Monton?,
}

local Botin = {}

Botin.alReclamar = Senal.nueva() :: Senal.Senal<Player, Objeto>
Botin.alActivar = Senal.nueva() :: Senal.Senal<Player, Monton, { Item }>
Botin.alAcertar = Senal.nueva() :: Senal.Senal<Player, number>

local montones: { Monton } = {}
local objetos: { [string]: Objeto } = {}
local contador = 0
local repoblacionPendiente = false
local carpetaMontones: Folder
local carpetaObjetos: Folder
local rng = Random.new()

local NOMBRE_BASURA = { Metal = "Chatarra", Plastico = "Plástico", Papel = "Papel", Organico = "Orgánico" }

-- ===========================================================================
-- Contenido de un monton
-- ===========================================================================

local function mascotaAleatoria(rareza: string, excluir: { [string]: boolean }?): DefinicionesMascotas.Mascota?
	local candidatas = {}
	for _, def in DefinicionesMascotas.porRareza(rareza) do
		if def.id ~= DefinicionesMascotas.ID_REY and not (excluir and excluir[def.id]) then
			table.insert(candidatas, def)
		end
	end
	if #candidatas == 0 then
		return nil
	end
	return candidatas[rng:NextInteger(1, #candidatas)]
end

local function itemTesoro(): Item
	return { tipo = "tesoro", nombre = "Tesoro", valor = rng:NextInteger(GameConfig.VALOR_TESORO.min, GameConfig.VALOR_TESORO.max) }
end

local function itemFragmento(jugador: Player): Item
	local enCurso = Mascotas.fragmentosEnCurso(jugador)
	local def: DefinicionesMascotas.Mascota? = nil
	if #enCurso > 0 and rng:NextNumber() < TablasProbabilidad.SESGO_FRAGMENTO_EN_CURSO then
		def = DefinicionesMascotas.obtener(enCurso[rng:NextInteger(1, #enCurso)])
	end
	if not def then
		-- Excluir las que ya tienen los 5 fragmentos esperando ensamblaje
		local perfil = Perfiles.obtener(jugador)
		local excluir = {}
		if perfil then
			for id, n in perfil.fragmentos do
				if n >= GameConfig.FRAGMENTOS_POR_MASCOTA then
					excluir[id] = true
				end
			end
		end
		def = mascotaAleatoria(TablasProbabilidad.elegir(TablasProbabilidad.RAREZA_FRAGMENTO, rng), excluir)
	end
	if not def then
		return itemTesoro()
	end
	return { tipo = "fragmento", nombre = "Fragmento de " .. def.nombre, id = def.id }
end

local function itemMascota(jugador: Player, contexto: { huboRara: boolean }): Item
	local perfil = Perfiles.obtener(jugador)
	local pity = if perfil then perfil.pity else 0
	local probRara = TablasProbabilidad.probabilidadRara(pity, Monetizacion.tienePase(jugador, "PaseSuerte"))
	local rareza = "Comun"
	if rng:NextNumber() < probRara then
		contexto.huboRara = true
		rareza = if rng:NextNumber() < GameConfig.PROB_EPICA_ENTRE_RARAS then "Epica" else "Rara"
	end
	local def = mascotaAleatoria(rareza)
	if not def then
		return itemTesoro()
	end
	local estado = tonumber(TablasProbabilidad.elegir(TablasProbabilidad.ESTADO_MASCOTA_MONTON, rng)) or 2
	return {
		tipo = "mascota",
		nombre = def.nombre,
		id = def.id,
		estado = estado,
		sucia = rng:NextNumber() < TablasProbabilidad.PROB_SUCIA_MONTON,
	}
end

local function itemColeccionable(jugador: Player): Item
	local orden = { TablasProbabilidad.elegir(TablasProbabilidad.COLECCIONABLE, rng), "figurina", "cinta", "traje" }
	for _, tipo in orden do
		local faltantes = Coleccionables.faltantes(jugador, tipo)
		if #faltantes > 0 then
			local id = faltantes[rng:NextInteger(1, #faltantes)]
			local nombre = id
			if tipo == "figurina" then
				nombre = DefinicionesColeccionables.FIGURINA_POR_ID[id].nombre
			elseif tipo == "cinta" then
				nombre = DefinicionesColeccionables.CINTA_POR_ID[id].nombre
			elseif tipo == "traje" then
				nombre = DefinicionesColeccionables.TRAJE_POR_ID[id].nombre
			end
			return { tipo = tipo, nombre = nombre, id = id }
		end
	end
	return itemTesoro()
end

local function generarItem(jugador: Player, contexto: { huboRara: boolean }): Item
	local tipo = TablasProbabilidad.elegir(TablasProbabilidad.TIPO_OBJETO, rng)
	if tipo == "basura" then
		local material = TablasProbabilidad.elegir(TablasProbabilidad.MATERIAL_BASURA, rng)
		return { tipo = "basura", nombre = NOMBRE_BASURA[material] or material, material = material, valor = GameConfig.VALOR_BASURA[material] }
	elseif tipo == "billete" then
		return { tipo = "billete", nombre = "Billete", valor = rng:NextInteger(GameConfig.VALOR_BILLETE.min, GameConfig.VALOR_BILLETE.max) }
	elseif tipo == "fragmento" then
		return itemFragmento(jugador)
	elseif tipo == "mascota" then
		return itemMascota(jugador, contexto)
	elseif tipo == "tesoro" then
		return itemTesoro()
	else
		return itemColeccionable(jugador)
	end
end

function Botin.generarContenido(jugador: Player, tamano: string): ({ Item }, boolean)
	local def = GameConfig.TAMANOS_MONTON[tamano] or GameConfig.TAMANOS_MONTON.chico
	local n = rng:NextInteger(def.min, def.max)
	local contexto = { huboRara = false }
	local lista = {}
	for _ = 1, n do
		table.insert(lista, generarItem(jugador, contexto))
	end
	return lista, contexto.huboRara
end

-- ===========================================================================
-- Modelos
-- ===========================================================================

local function modeloPara(item: Item): Model
	local m: Model
	local colorEtiqueta = Paleta.UI_TEXTO
	if item.tipo == "basura" then
		m = ModelosMascota.basura(item.material or "Papel")
	elseif item.tipo == "billete" then
		m = ModelosMascota.billete()
		colorEtiqueta = Paleta.UI_DINERO
	elseif item.tipo == "tesoro" then
		m = ModelosMascota.tesoro()
		colorEtiqueta = Paleta.TESORO
	elseif item.tipo == "fragmento" then
		local def = DefinicionesMascotas.obtener(item.id or "")
		m = if def then ModelosMascota.fragmento(def, 1) else ModelosMascota.tesoro()
	elseif item.tipo == "mascota" then
		local def = DefinicionesMascotas.obtener(item.id or "")
		m = if def then ModelosMascota.mascota(def, item.estado or 2, item.sucia) else ModelosMascota.tesoro()
		colorEtiqueta = if def then Paleta.RAREZA[def.rareza] else colorEtiqueta
	elseif item.tipo == "figurina" then
		local def = DefinicionesColeccionables.FIGURINA_POR_ID[item.id or ""]
		m = if def then ModelosMascota.figurina(def) else ModelosMascota.tesoro()
	elseif item.tipo == "cinta" then
		local def = DefinicionesColeccionables.CINTA_POR_ID[item.id or ""]
		m = if def then ModelosMascota.cinta(def) else ModelosMascota.tesoro()
	else
		local def = DefinicionesColeccionables.TRAJE_POR_ID[item.id or ""]
		m = if def then ModelosMascota.traje(def) else ModelosMascota.tesoro()
	end
	local texto = item.nombre
	if item.tipo == "billete" then
		texto = "$" .. tostring(item.valor)
	end
	ModelosMascota.etiqueta(m, texto, colorEtiqueta, if item.tipo == "mascota" then 3.4 else 2)
	return m
end

Botin.modeloPara = modeloPara

-- ===========================================================================
-- Objetos
-- ===========================================================================

local function registrar(item: Item, modelo: Model, monton: Monton?): Objeto
	contador += 1
	local id = tostring(contador)
	modelo:SetAttribute("ObjetoId", id)
	modelo:SetAttribute("Tipo", item.tipo)
	modelo.Parent = carpetaObjetos
	local obj: Objeto = { id = id, item = item, modelo = modelo, reclamadoPor = nil, creado = os.clock(), asentado = false, monton = monton }
	objetos[id] = obj
	if monton then
		monton.objetosVivos += 1
	end
	return obj
end

local function agotar(monton: Monton)
	monton.estado = "agotado"
	if monton.anillo then
		monton.anillo:Destroy()
		monton.anillo = nil
	end
end

local function quitarObjeto(obj: Objeto)
	objetos[obj.id] = nil
	if obj.modelo.Parent then
		obj.modelo:Destroy()
	end
	local monton = obj.monton
	if monton then
		monton.objetosVivos = math.max(0, monton.objetosVivos - 1)
		if monton.objetosVivos == 0 and monton.estado == "activo" then
			agotar(monton)
		end
	end
end

-- Salto desde el monton hasta su sitio en el suelo (0.6 s)
local function animarSalida(obj: Objeto, desde: Vector3, hasta: Vector3)
	task.spawn(function()
		local duracion = 0.6
		local t0 = os.clock()
		while true do
			local t = math.min(1, (os.clock() - t0) / duracion)
			if not obj.modelo.Parent then
				return
			end
			local pos = desde:Lerp(hasta, t) + Vector3.new(0, math.sin(t * math.pi) * 3.5, 0)
			obj.modelo:PivotTo(CFrame.new(pos) * CFrame.Angles(0, t * math.pi * 2, 0))
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		obj.modelo:PivotTo(CFrame.new(hasta))
		obj.asentado = true
	end)
end

function Botin.objetos(): { [string]: Objeto }
	return objetos
end

-- ===========================================================================
-- Montones
-- ===========================================================================

local function crearModeloMonton(monton: Monton)
	if monton.modelo then
		monton.modelo:Destroy()
	end
	local modelo = ModelosMascota.monton(monton.tamano, monton.estado == "agotado", monton.id)
	modelo.Name = "Monton_" .. monton.id
	modelo:SetAttribute("MontonId", monton.id)
	modelo:SetAttribute("Tamano", monton.tamano)
	modelo:SetAttribute("Estado", monton.estado)
	modelo:PivotTo(CFrame.new(monton.ranura.Position))
	modelo.Parent = carpetaMontones
	monton.modelo = modelo
	if monton.estado == "lleno" and modelo.PrimaryPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PromptExcavar"
		prompt.ActionText = Textos.PATIO.excavar
		prompt.ObjectText = "Montón " .. monton.tamano
		prompt.HoldDuration = GameConfig.DURACION_EXCAVAR
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = modelo.PrimaryPart
	end
end

function Botin.montonDe(inst: Instance): Monton?
	local actual: Instance? = inst
	while actual and actual ~= workspace do
		local id = actual:GetAttribute("MontonId")
		if id then
			return montones[id]
		end
		actual = actual.Parent
	end
	return nil
end

function Botin.montones(): { Monton }
	return montones
end

local function distanciaA(jugador: Player, posicion: Vector3): number?
	local personaje = jugador.Character
	local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	return (root.Position - posicion).Magnitude
end

function Botin.excavar(jugador: Player, monton: Monton): (boolean, string)
	if monton.estado ~= "lleno" then
		return false, "agotado"
	end
	local d = distanciaA(jugador, monton.ranura.Position)
	if not d or d > 16 then
		return false, "lejos"
	end
	if not Energia.gastar(jugador, GameConfig.COSTE_EXCAVAR) then
		return false, "sinEnergia"
	end
	monton.estado = "activo"
	local contenido, huboRara = Botin.generarContenido(jugador, monton.tamano)

	local perfil = Perfiles.obtener(jugador)
	if perfil then
		perfil.pity = if huboRara then 0 else perfil.pity + 1
		Perfiles.marcarSucio(jugador)
	end
	Perfiles.estadistica(jugador, "montonesActivados", 1)

	-- El anillo neon y el monton aplanado
	local centro = monton.ranura.Position
	local radio = ModelosMascota.radioMonton(monton.tamano)
	local promptViejo = monton.modelo and monton.modelo:FindFirstChild("PromptExcavar", true)
	if promptViejo then
		promptViejo:Destroy()
	end
	if monton.modelo then
		monton.modelo:SetAttribute("Estado", "activo")
		local anillo = ModelosMascota.anilloActivado(radio)
		anillo.CFrame = CFrame.new(centro + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
		anillo.Parent = carpetaMontones
		monton.anillo = anillo
	end
	task.delay(0.9, function()
		if monton.estado == "activo" then
			local vivo = monton.modelo
			monton.modelo = nil
			if vivo then
				vivo:Destroy()
			end
			local aplanado = ModelosMascota.monton(monton.tamano, true, monton.id)
			aplanado.Name = "Monton_" .. monton.id
			aplanado:SetAttribute("MontonId", monton.id)
			aplanado:PivotTo(CFrame.new(centro))
			aplanado.Parent = carpetaMontones
			monton.modelo = aplanado
		end
	end)

	-- Los objetos saltan alrededor
	for i, item in contenido do
		local ang = (i / #contenido) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local dist = rng:NextNumber(radio * 1.7 + 1, radio * 1.7 + GameConfig.RADIO_DISPERSION_OBJETOS)
		local hasta = centro + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
		local modelo = modeloPara(item)
		modelo:PivotTo(CFrame.new(centro + Vector3.new(0, 1.5, 0)))
		local obj = registrar(item, modelo, monton)
		animarSalida(obj, centro + Vector3.new(0, 1.5, 0), hasta)
	end
	if #contenido == 0 then
		agotar(monton)
	end

	-- Senal social
	if monton.tamano == "grande" then
		FeedEvent:FireAllClients(Textos.formatear(Textos.FEED.montonGrande, { jugador = jugador.DisplayName }))
	end
	for _, item in contenido do
		if item.tipo == "mascota" and item.id then
			local def = DefinicionesMascotas.obtener(item.id)
			if def and def.rareza ~= "Comun" then
				FeedEvent:FireAllClients(Textos.formatear(Textos.FEED.raraEncontrada, {
					jugador = jugador.DisplayName,
					mascota = def.nombre,
					rareza = DefinicionesMascotas.NOMBRE_RAREZA[def.rareza],
				}))
			end
		end
	end
	Botin.alActivar:Fire(jugador, monton, contenido)
	return true, "activado"
end

-- ===========================================================================
-- Reclamo atomico
-- ===========================================================================

local avisoBolsaLlena: { [Player]: number } = {}

function Botin.reclamar(jugador: Player, objetoId: string, origen: string): (boolean, string)
	local obj = objetos[objetoId]
	if not obj then
		return false, "noExiste"
	end
	if obj.reclamadoPor then
		return false, "yaReclamado"
	end
	if not obj.asentado and origen == "clic" then
		return false, "enElAire"
	end
	if origen == "clic" then
		local d = distanciaA(jugador, obj.modelo:GetPivot().Position)
		if not d or d > Mejoras.valor(jugador, "Alcance") + 2 then
			return false, "lejos"
		end
	end
	-- Bloqueo: se marca ANTES de cualquier otra cosa. Si luego no cabe en la
	-- bolsa se libera; entre medias no hay ningun yield.
	obj.reclamadoPor = jugador
	local item = obj.item
	if item.tipo == "billete" then
		local valor = item.valor or 0
		Economia.ganar(jugador, valor)
		Perfiles.estadistica(jugador, "billetesEncontrados", 1)
		NotificacionEvent:FireClient(jugador, Textos.formatear(Textos.PATIO.billete, { cantidad = valor }), "dinero")
	else
		if not Bolsa.meter(jugador, item) then
			obj.reclamadoPor = nil
			local ahora = os.clock()
			if ahora - (avisoBolsaLlena[jugador] or 0) > 2 then
				avisoBolsaLlena[jugador] = ahora
				NotificacionEvent:FireClient(jugador, Textos.PATIO.bolsaLlena, "aviso")
			end
			return false, "bolsaLlena"
		end
		if item.tipo == "mascota" or item.tipo == "fragmento" or item.tipo == "figurina" or item.tipo == "cinta" or item.tipo == "traje" then
			NotificacionEvent:FireClient(jugador, item.nombre, "objeto")
		end
	end
	Perfiles.estadistica(jugador, "objetosRecogidos", 1)
	quitarObjeto(obj)
	Botin.alReclamar:Fire(jugador, obj)
	return true, "reclamado"
end

-- ===========================================================================
-- Bucles: toque + iman, despawn, repoblacion
-- ===========================================================================

local function bucleIman()
	local paso = 14 * GameConfig.INTERVALO_IMAN
	for _, jugador in Players:GetPlayers() do
		local personaje = jugador.Character
		local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and Perfiles.obtener(jugador) then
			local posJ = root.Position
			local radioIman = Mejoras.valor(jugador, "Iman")
			local bolsaLlena = Bolsa.estaLlena(jugador)
			for id, obj in objetos do
				if not obj.reclamadoPor and obj.asentado then
					local pivot = obj.modelo:GetPivot()
					local delta = posJ - pivot.Position
					local d = delta.Magnitude
					local esBillete = obj.item.tipo == "billete"
					if d <= GameConfig.DISTANCIA_RECLAMO_IMAN + 0.5 then
						Botin.reclamar(jugador, id, "toque")
					elseif radioIman > 0 and d <= radioIman and (esBillete or not bolsaLlena) then
						local avance = math.min(paso, d - 1.5)
						if avance > 0 then
							local nuevo = pivot.Position + delta.Unit * avance
							obj.modelo:PivotTo(CFrame.new(Vector3.new(nuevo.X, math.max(1, nuevo.Y), nuevo.Z)))
						end
					end
				end
			end
		end
	end
end

local function bucleDespawn()
	local ahora = os.clock()
	for _, obj in objetos do
		if not obj.reclamadoPor and ahora - obj.creado > GameConfig.VIDA_OBJETO then
			quitarObjeto(obj)
		end
	end
end

local function repoblar()
	for _, monton in montones do
		if monton.estado == "agotado" then
			monton.estado = "lleno"
			monton.objetosVivos = 0
			crearModeloMonton(monton)
		end
	end
	FeedEvent:FireAllClients(Textos.FEED.repoblacion)
end

local function bucleRepoblacion()
	if repoblacionPendiente then
		return
	end
	local disponibles = 0
	for _, monton in montones do
		if monton.estado ~= "agotado" then
			disponibles += 1
		end
	end
	if disponibles <= GameConfig.UMBRAL_REPOBLACION then
		repoblacionPendiente = true
		task.delay(GameConfig.RETRASO_REPOBLACION, function()
			repoblar()
			repoblacionPendiente = false
		end)
	end
end

-- ===========================================================================
-- Punteria: lanzar al Contenedor
-- ===========================================================================

local function dentroDe(parte: BasePart, pos: Vector3): boolean
	local local_ = parte.CFrame:PointToObjectSpace(pos)
	local mitad = parte.Size / 2
	return math.abs(local_.X) <= mitad.X and math.abs(local_.Y) <= mitad.Y and math.abs(local_.Z) <= mitad.Z
end

local lanzamientos: { [Player]: number } = {}

function Botin.lanzar(jugador: Player, punto: Vector3): (boolean, string)
	local ahora = os.clock()
	if ahora - (lanzamientos[jugador] or 0) < 0.5 then
		return false, "cooldown"
	end
	local personaje = jugador.Character
	local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
	local zona = Mundo.zonaAcierto()
	if not root or not root:IsA("BasePart") or not zona then
		return false, "sinPersonaje"
	end
	local origen = root.Position + Vector3.new(0, 1.5, 0)
	local horizontal = Vector3.new(zona.Position.X - origen.X, 0, zona.Position.Z - origen.Z)
	local distContenedor = horizontal.Magnitude
	if distContenedor < GameConfig.DISTANCIA_MIN_LANZAR then
		return false, "demasiadoCerca"
	end
	if (punto - origen).Magnitude > GameConfig.DISTANCIA_MAX_LANZAR then
		return false, "demasiadoLejos"
	end
	if not Bolsa.tieneLanzable(jugador) then
		return false, "nadaQueLanzar"
	end
	local item = Bolsa.sacarLanzable(jugador)
	if not item then
		return false, "nadaQueLanzar"
	end
	lanzamientos[jugador] = ahora
	Perfiles.estadistica(jugador, "lanzamientos", 1)

	local contenedor = Mundo.contenedor()
	local cajaCF, cajaSize = CFrame.new(zona.Position), zona.Size
	if contenedor then
		cajaCF, cajaSize = contenedor:GetBoundingBox()
	end
	local caja = Instance.new("Part")
	caja.Size = cajaSize
	caja.CFrame = cajaCF

	local modelo = modeloPara(item)
	modelo:PivotTo(CFrame.new(origen))
	modelo.Parent = carpetaObjetos

	local vuelo = math.clamp((punto - origen).Magnitude / 22, 0.7, 1.5)
	local g = Vector3.new(0, -55, 0)
	local v0 = (punto - origen - 0.5 * g * vuelo * vuelo) / vuelo
	local valorBase = if item.tipo == "basura" then Bolsa.valorBasura(jugador, item) else (item.valor or 0)

	task.spawn(function()
		local t0 = os.clock()
		local pos = origen
		while true do
			local t = os.clock() - t0
			pos = origen + v0 * t + 0.5 * g * t * t
			if not modelo.Parent then
				return
			end
			modelo:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 4, t * 3, 0))
			if dentroDe(zona, pos) then
				-- Acierto
				modelo:Destroy()
				local valor = math.floor(valorBase * (1 + GameConfig.BONUS_ACIERTO) + 0.5)
				Economia.ganar(jugador, valor)
				Perfiles.estadistica(jugador, "objetosReciclados", 1)
				Perfiles.estadistica(jugador, "aciertos", 1)
				Perfiles.estadisticaMaxima(jugador, "mejorDistanciaAcierto", math.floor(distContenedor + 0.5))
				NotificacionEvent:FireClient(jugador, Textos.formatear(Textos.PATIO.acierto, { bonus = valor, distancia = math.floor(distContenedor + 0.5) }), "exito")
				Botin.alAcertar:Fire(jugador, distContenedor)
				return
			end
			local chocoPared = dentroDe(caja, pos) and not dentroDe(zona, pos) and pos.Y < zona.Position.Y + zona.Size.Y / 2
			if pos.Y <= 1 or t > GameConfig.VIDA_PROYECTIL or chocoPared then
				-- Fallo: cae como objeto libre
				local suelo = Vector3.new(pos.X, 1, pos.Z)
				if chocoPared then
					local fuera = Vector3.new(pos.X - cajaCF.Position.X, 0, pos.Z - cajaCF.Position.Z)
					if fuera.Magnitude > 0.1 then
						suelo = Vector3.new(cajaCF.Position.X, 1, cajaCF.Position.Z) + fuera.Unit * (math.max(cajaSize.X, cajaSize.Z) / 2 + 1.5)
					end
				end
				modelo:PivotTo(CFrame.new(suelo))
				local obj = registrar(item, modelo, nil)
				obj.asentado = true
				NotificacionEvent:FireClient(jugador, Textos.PATIO.fallo, "aviso")
				return
			end
			RunService.Heartbeat:Wait()
		end
	end)
	return true, "lanzado"
end

-- ===========================================================================
-- Arranque
-- ===========================================================================

local iniciado = false

function Botin.iniciar()
	if iniciado then
		return
	end
	iniciado = true
	carpetaMontones = Instance.new("Folder")
	carpetaMontones.Name = "Montones"
	carpetaMontones.Parent = workspace
	carpetaObjetos = Instance.new("Folder")
	carpetaObjetos.Name = "Objetos"
	carpetaObjetos.Parent = workspace

	for i, ranura in Mundo.ranuras() do
		local monton: Monton = {
			id = i,
			ranura = ranura,
			tamano = ranura:GetAttribute("Tamano") or "chico",
			estado = "lleno",
			modelo = nil,
			anillo = nil,
			objetosVivos = 0,
		}
		montones[i] = monton
		crearModeloMonton(monton)
	end

	local acumIman, acumDespawn, acumRepo = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acumIman += dt
		acumDespawn += dt
		acumRepo += dt
		if acumIman >= GameConfig.INTERVALO_IMAN then
			acumIman = 0
			bucleIman()
		end
		if acumDespawn >= 1 then
			acumDespawn = 0
			bucleDespawn()
		end
		if acumRepo >= 5 then
			acumRepo = 0
			bucleRepoblacion()
		end
	end)

	Players.PlayerRemoving:Connect(function(jugador)
		avisoBolsaLlena[jugador] = nil
		lanzamientos[jugador] = nil
	end)
end

-- Para pruebas: fuerza la repoblacion ya
function Botin.repoblarAhora()
	repoblar()
end

return Botin
