--!strict
--[[
	Sonido (ModuleScript)
	Unica responsabilidad: hacer sonar en el cliente las claves de
	Config/Sonidos. Nadie mas crea Sounds ni escribe un rbxassetid: la UI y
	los scripts del mundo piden una clave, como con las imagenes (Kit/Icono).

	  Sonido.tocar(clave, opciones?) -> Sound?
	      Un toque. 2D (interfaz) si no se da sitio; con `posicion`, 3D en ese
	      punto; con `padre` (una parte, un attachment o un modelo), 3D pegado
	      a el, siguiendo a lo que se mueve.
	      opciones: { posicion?, padre?, volumen? (multiplica el del
	      registro), tono? (PlaybackSpeed; si no, el `tono` del registro),
	      espera? (s minimos desde el anterior de la clave; si no, la del
	      registro) }
	  Sonido.bucle(clave, opciones?) -> Bucle?
	      Un sonido propio que controla quien lo pide (la carga, la cinta, la
	      trituradora, contar dinero, cada pista de musica): sonar(desde el
	      principio?), pausar(), parar(), intensidad(0..1) (de volumen/tono a
	      volumenAlto/tonoAlto del registro), fijarVolumen(factor), durar(s)
	      (una pasada dura eso) y destruir().
	  Sonido.atenuarMusica(factor, segundos)   la musica baja un rato (las
	      celebraciones; las claves con `atenua` lo piden solas al sonar)
	  Sonido.atenuacion() -> number             el factor de ahora (Musica)
	  Sonido.activado(grupo) -> boolean         el ajuste del jugador

	=== Por que asi ===
	- Todo suena en el cliente: SoundService.RespectFilteringEnabled esta
	  encendido (default.project.json) y lo que suena aqui no se replica.
	  Los 3D que tienen que oir todos (la bolsa lanzada, los golpes, las
	  recicladoras) los reproduce cada cliente al ver el evento.
	- Un toque no crea un Sound: cada clave tiene una PLANTILLA configurada
	  una vez desde el registro (SoundService.Sonidos.Plantillas) y unas
	  pocas VOCES clonadas de ella que se reutilizan (`voces` del registro;
	  si todas suenan, se reinicia la que empezo antes). "Como mucho 3
	  recoger a la vez" es el tamano de su grupo de voces. Solo `padre` (algo
	  que se mueve y puede desaparecer) clona por toque, y el clon se va al
	  acabar.
	- Grupos: SoundGroup "Efectos" y "Musica" en SoundService, a volumen 1 o
	  0 segun perfil.ajustes (los guarda el servidor: AjustesEvent). Hasta
	  que llega el primer perfil la musica esta a 0: no se sabe si el jugador
	  la quito, y no debe sonar un momento antes de callarse.
	- Precarga: ContentProvider:PreloadAsync con los efectos al arrancar,
	  para que el primer "recoger" no llegue tarde. Las plantillas de musica
	  se crean (y cargan) cuando van a sonar: son minutos de audio por pista.
	- Pruebas por el gancho ("modulo", "Sonido", accion) de PruebasCliente:
	  prueba.listar() dice cuantas claves hay, cuales cargaron (IsLoaded) y
	  su TimeLength; prueba.tocar(clave) suena una para escucharla.
]]

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sonidos = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sonidos"))

local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))

type Def = Sonidos.Def

export type Opciones = {
	posicion: Vector3?,
	padre: Instance?,
	volumen: number?,
	tono: number?,
	espera: number?,
}

export type Bucle = {
	sonido: Sound,
	sonar: (desdeElPrincipio: boolean?) -> (),
	pausar: () -> (),
	parar: () -> (),
	intensidad: (fraccion: number) -> (),
	fijarVolumen: (factor: number) -> (),
	durar: (segundos: number) -> (),
	destruir: () -> (),
}

local Sonido = {}

local VOCES_DEFECTO = 2
-- Sin TimeLength (aun sin cargar): lo que se supone que dura algo que atenua
local DURACION_SUPUESTA = 3
-- Un clon pegado a algo que se mueve se borra a mas tardar a los tantos s
-- (por si nunca llega a sonar y no hay Ended)
local VIDA_CLON = 15
local rng = Random.new()

-- ===========================================================================
-- Grupos y ajustes del jugador
-- ===========================================================================

local function grupoLlamado(nombre: string): SoundGroup
	local existente = SoundService:FindFirstChild(nombre)
	if existente and existente:IsA("SoundGroup") then
		return existente
	end
	local g = Instance.new("SoundGroup")
	g.Name = nombre
	g.Parent = SoundService
	return g
end

local grupos: { [string]: SoundGroup } = {
	Efectos = grupoLlamado("Efectos"),
	Musica = grupoLlamado("Musica"),
}
-- La musica, callada hasta que el perfil diga (ver cabecera). Los dos se
-- fijan aqui: un SoundGroup nuevo nace a 0,5 y los efectos sonarian a la
-- mitad hasta el primer perfil
local activos: { [string]: boolean } = { Efectos = true, Musica = false }
grupos.Efectos.Volume = 1
grupos.Musica.Volume = 0

local function aplicarAjustes(perfil: any)
	if typeof(perfil) ~= "table" then
		return
	end
	local ajustes: any = if typeof(perfil.ajustes) == "table" then perfil.ajustes else {}
	activos.Musica = ajustes.musica ~= false
	activos.Efectos = ajustes.efectos ~= false
	-- El perfil llega hasta 4 veces por segundo: solo se toca si cambia
	for nombre, g in grupos do
		local volumen = if activos[nombre] then 1 else 0
		if g.Volume ~= volumen then
			g.Volume = volumen
		end
	end
end
aplicarAjustes(EstadoCliente.perfil)
EstadoCliente.alCambiarPerfil:Connect(aplicarAjustes)

function Sonido.activado(grupo: string): boolean
	return activos[grupo] == true
end

-- ===========================================================================
-- Atenuacion de la musica
-- ===========================================================================

type Atenuacion = { factor: number, hasta: number }
local atenuaciones: { Atenuacion } = {}

-- Varias a la vez: manda la mas fuerte (el factor mas bajo). Con los efectos
-- quitados no baja: no suena nada a lo que hacer sitio
function Sonido.atenuarMusica(factor: number, segundos: number)
	if not activos.Efectos then
		return
	end
	table.insert(atenuaciones, { factor = math.clamp(factor, 0, 1), hasta = os.clock() + math.max(0, segundos) })
end

function Sonido.atenuacion(): number
	local ahora = os.clock()
	local factor = 1
	for i = #atenuaciones, 1, -1 do
		local a = atenuaciones[i]
		if a.hasta <= ahora then
			table.remove(atenuaciones, i)
		elseif a.factor < factor then
			factor = a.factor
		end
	end
	return factor
end

-- ===========================================================================
-- Plantillas
-- ===========================================================================

local raiz = Instance.new("Folder")
raiz.Name = "Sonidos"
raiz.Parent = SoundService
local carpetaPlantillas = Instance.new("Folder")
carpetaPlantillas.Name = "Plantillas"
carpetaPlantillas.Parent = raiz
-- Voces 2D y bucles sin sitio: en SoundService suenan sin posicion
local carpetaVoces = Instance.new("Folder")
carpetaVoces.Name = "Voces"
carpetaVoces.Parent = raiz

local plantillas: { [string]: Sound } = {}
local avisadas: { [string]: boolean } = {}

-- La plantilla de una clave (se crea la primera vez) y su definicion. Sin
-- plantilla si la clave no existe (se avisa una vez) o esta callada (id 0).
local function plantilla(clave: string): (Sound?, Def?)
	local def = Sonidos.LISTA[clave]
	if not def then
		if not avisadas[clave] then
			avisadas[clave] = true
			warn("[Sonido] clave sin registrar en Config/Sonidos: " .. tostring(clave))
		end
		return nil, nil
	end
	if def.id == 0 then
		return nil, def
	end
	local existente = plantillas[clave]
	if existente then
		return existente, def
	end
	local s = Instance.new("Sound")
	s.Name = clave
	s.SoundId = "rbxassetid://" .. tostring(def.id)
	s.Volume = def.volumen
	s.SoundGroup = grupos[def.grupo]
	s.Looped = def.bucle == true
	local region = def.region
	if region then
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(region[1], region[2])
	end
	if def.modo == "3D" then
		local distancia = def.distancia
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = if distancia then distancia[1] else 8
		s.RollOffMaxDistance = if distancia then distancia[2] else 60
	end
	s.Parent = carpetaPlantillas
	plantillas[clave] = s
	return s, def
end

-- Donde empieza a sonar (el principio de su region)
local function inicio(def: Def): number
	local region = def.region
	return if region then region[1] else 0
end

-- Lo que dura una pasada (recortada a su region) a ese tono
local function duracion(s: Sound, def: Def, tono: number): number
	local largo = s.TimeLength
	if largo <= 0 then
		return DURACION_SUPUESTA
	end
	local region = def.region
	if region then
		largo = math.max(0, math.min(region[2], largo) - region[1])
	end
	return largo / math.max(tono, 0.01)
end

-- Una parte o attachment donde colgar un sonido 3D (de un modelo, su
-- PrimaryPart o su primera parte)
local function destino(inst: Instance): Instance?
	if inst:IsA("BasePart") or inst:IsA("Attachment") then
		return inst
	elseif inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- ===========================================================================
-- Voces (toques sueltos)
-- ===========================================================================

type Voz = { sonido: Sound, ancla: Attachment?, desde: number }
local voces: { [string]: { Voz } } = {}

local function nuevaVoz(molde: Sound, clave: string, en3D: boolean): Voz
	local s = molde:Clone()
	s.Looped = false -- un toque es un toque, aunque la clave sea un bucle
	if en3D then
		-- Un attachment en el terreno que se mueve a cada toque
		local ancla = Instance.new("Attachment")
		ancla.Name = "Voz_" .. clave
		ancla.Parent = workspace.Terrain
		s.Parent = ancla
		return { sonido = s, ancla = ancla, desde = 0 }
	end
	s.Parent = carpetaVoces
	return { sonido = s, ancla = nil, desde = 0 }
end

-- Una voz libre de la clave; si no hay y caben mas, una nueva; si no, la que
-- empezo antes (se reinicia)
local function tomarVoz(molde: Sound, clave: string, def: Def, en3D: boolean): Voz
	local llave = clave .. (if en3D then "|3D" else "|2D")
	local lista: { Voz } = voces[llave] or {}
	voces[llave] = lista
	local libre: Voz? = nil
	local vieja: Voz? = nil
	for i = #lista, 1, -1 do
		local v = lista[i]
		if v.sonido.Parent == nil then
			-- Algo la destruyo (no deberia): fuera, se hara otra
			table.remove(lista, i)
			if v.ancla then
				v.ancla:Destroy()
			end
		elseif not v.sonido.IsPlaying then
			libre = v
		elseif vieja == nil or v.desde < vieja.desde then
			vieja = v
		end
	end
	if libre then
		return libre
	end
	if vieja == nil or #lista < (def.voces or VOCES_DEFECTO) then
		local v = nuevaVoz(molde, clave, en3D)
		table.insert(lista, v)
		return v
	end
	return vieja
end

local ultimos: { [string]: number } = {}

function Sonido.tocar(clave: string, opciones: Opciones?): Sound?
	local molde, def = plantilla(clave)
	if not molde or not def then
		return nil
	end
	local o: Opciones = opciones or {}
	local ahora = os.clock()
	local espera = o.espera or def.espera
	if espera and ahora - (ultimos[clave] or -math.huge) < espera then
		return nil
	end
	ultimos[clave] = ahora
	local rango = def.tono
	local tono = o.tono or (if rango then rng:NextNumber(rango[1], rango[2]) else 1)
	local s: Sound
	if o.padre then
		local sitio = destino(o.padre)
		if not sitio then
			return nil
		end
		-- Pegado a algo que se mueve y puede desaparecer: un clon propio que
		-- se va al acabar (o con lo que lo lleva)
		local clon = molde:Clone()
		clon.Looped = false
		clon.Parent = sitio
		clon.Ended:Once(function()
			clon:Destroy()
		end)
		Debris:AddItem(clon, VIDA_CLON)
		s = clon
	else
		local voz = tomarVoz(molde, clave, def, o.posicion ~= nil)
		local ancla = voz.ancla
		if ancla and o.posicion then
			ancla.WorldPosition = o.posicion
		end
		voz.desde = ahora
		s = voz.sonido
	end
	s.Volume = def.volumen * (o.volumen or 1)
	s.PlaybackSpeed = tono
	s.TimePosition = inicio(def)
	s:Play()
	local atenua = def.atenua
	if atenua then
		Sonido.atenuarMusica(atenua, duracion(s, def, tono))
	end
	return s
end

-- ===========================================================================
-- Bucles (sonidos que controla quien los pide)
-- ===========================================================================

-- Los vivos, para prueba.listar. Claves debiles: un bucle colgado de una
-- parte que desaparece no debe quedarse aqui para siempre
local bucles: { [Sound]: string } = setmetatable({}, { __mode = "k" }) :: any

function Sonido.bucle(clave: string, opciones: Opciones?): Bucle?
	local molde, encontrada = plantilla(clave)
	if not molde or not encontrada then
		return nil
	end
	local def: Def = encontrada
	local o: Opciones = opciones or {}
	local s = molde:Clone()
	local ancla: Attachment? = nil
	if o.padre then
		local sitio = destino(o.padre)
		if not sitio then
			s:Destroy()
			return nil
		end
		s.Parent = sitio
	elseif o.posicion then
		local a = Instance.new("Attachment")
		a.Name = "Bucle_" .. clave
		a.Parent = workspace.Terrain
		a.WorldPosition = o.posicion
		s.Parent = a
		ancla = a
	else
		s.Parent = carpetaVoces
	end
	bucles[s] = clave

	local factor = o.volumen or 1
	local tonoBase = o.tono or 1
	local fraccion = 0
	local function aplicar()
		local alto = def.volumenAlto or def.volumen
		s.Volume = (def.volumen + (alto - def.volumen) * fraccion) * factor
		local tonoAlto = def.tonoAlto
		s.PlaybackSpeed = if tonoAlto then tonoBase * (1 + (tonoAlto - 1) * fraccion) else tonoBase
	end
	aplicar()

	-- La cola que se repite (LoopRegion) se fija cuando se sabe cuanto dura
	local cola = def.cola
	if def.bucle and cola then
		local function fijarCola()
			local largo = s.TimeLength
			if largo <= 0 then
				return
			end
			local region = def.region
			local fin = if region then math.min(region[2], largo) else largo
			s.PlaybackRegionsEnabled = true
			s.LoopRegion = NumberRange.new(fin * (1 - cola), fin)
		end
		s.Loaded:Once(fijarCola)
		if s.IsLoaded then
			fijarCola()
		end
	end

	-- Pausado por pausar() (para seguir donde iba). Sound.IsPaused no sirve:
	-- es true siempre que no suena, tambien parado o sin haber sonado nunca
	local pausado = false
	local b: Bucle = {
		sonido = s,
		sonar = function(desdeElPrincipio: boolean?)
			if desdeElPrincipio or (not pausado and not s.IsPlaying) then
				s.TimePosition = inicio(def)
				s:Play()
			elseif not s.IsPlaying then
				s:Resume()
			end
			pausado = false
		end,
		pausar = function()
			if s.IsPlaying then
				s:Pause()
				pausado = true
			end
		end,
		parar = function()
			s:Stop()
			pausado = false
		end,
		intensidad = function(f: number)
			fraccion = math.clamp(f, 0, 1)
			aplicar()
		end,
		fijarVolumen = function(f: number)
			factor = math.max(0, f)
			aplicar()
		end,
		-- Una pasada entera dura `segundos` (sin cargar aun, se queda a su tono)
		durar = function(segundos: number)
			local largo = s.TimeLength
			if largo <= 0 or segundos <= 0 then
				return
			end
			local region = def.region
			if region then
				largo = math.max(0.05, math.min(region[2], largo) - region[1])
			end
			tonoBase = math.clamp(largo / segundos, 0.5, 2)
			aplicar()
		end,
		destruir = function()
			bucles[s] = nil
			s:Destroy()
			if ancla then
				ancla:Destroy()
			end
		end,
	}
	return b
end

-- ===========================================================================
-- Arranque: plantillas de los efectos y su precarga
-- ===========================================================================

do
	local efectos: { Instance } = {}
	for clave, def in Sonidos.LISTA do
		if def.grupo == "Efectos" then
			local s = plantilla(clave)
			if s then
				table.insert(efectos, s)
			end
		end
	end
	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(efectos)
		end)
		if not ok then
			warn("[Sonido] la precarga de los efectos fallo: " .. tostring(err))
		end
	end)
end

-- ===========================================================================
-- Pruebas (PruebasCliente: ("modulo", "Sonido", accion, ...))
-- ===========================================================================

Sonido.prueba = {
	-- Cuantas claves, cuales cargaron y lo que dura cada una
	listar = function(): string
		local claves: { string } = {}
		for clave in Sonidos.LISTA do
			table.insert(claves, clave)
		end
		table.sort(claves)
		local cargados = 0
		local detalle: { string } = {}
		local sinCargar: { string } = {}
		local sinCrear: { string } = {}
		local callados: { string } = {}
		for _, clave in claves do
			local def = Sonidos.LISTA[clave]
			local s = plantillas[clave]
			if def.id == 0 then
				table.insert(callados, clave)
			elseif not s then
				table.insert(sinCrear, clave)
			elseif s.IsLoaded then
				cargados += 1
				table.insert(detalle, string.format("%s %.2fs", clave, s.TimeLength))
			else
				table.insert(sinCargar, clave)
			end
		end
		local nVoces = 0
		for _, lista in voces do
			nVoces += #lista
		end
		local nBucles = 0
		for _ in bucles do
			nBucles += 1
		end
		return string.format(
			"sonidos=%d cargados=%d | sin cargar [%s] | musica que aun no sono [%s] | callados (id 0) [%s] | grupos Efectos=%g Musica=%g, atenuacion=%.2f, pista=%s | voces=%d bucles=%d\n%s",
			#claves,
			cargados,
			table.concat(sinCargar, ", "),
			table.concat(sinCrear, ", "),
			table.concat(callados, ", "),
			grupos.Efectos.Volume,
			grupos.Musica.Volume,
			Sonido.atenuacion(),
			tostring(grupos.Musica:GetAttribute("Pista")),
			nVoces,
			nBucles,
			table.concat(detalle, " | ")
		)
	end,
	-- Suena una clave (2D si es 3D: no hay sitio) para escucharla
	tocar = function(clave: any): string
		local nombre = tostring(clave)
		local s = Sonido.tocar(nombre, { espera = 0 })
		if not s then
			return nombre .. ": no suena (sin registrar o id 0)"
		end
		local grupo = s.SoundGroup
		return string.format("%s: suena (cargado=%s, %.2f s, grupo %s a %g)", nombre, tostring(s.IsLoaded), s.TimeLength,
			if grupo then grupo.Name else "?", if grupo then grupo.Volume else -1)
	end,
}

return Sonido
