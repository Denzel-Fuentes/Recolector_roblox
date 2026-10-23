--!strict
--[[
	Musica
	Unica responsabilidad: la musica de fondo (Config/Sonidos.MUSICA).

	  Patio   las pistas de MUSICA.patio en orden aleatorio, sin repetir la
	          ultima, con FUNDIDO_MUSICA s de fundido cruzado entre una y la
	          siguiente: ninguna pista de APM es un bucle sin costuras, por
	          eso lista y no Looped (docs/Audio-propuesta §5.1). Al empezar
	          una se sortea ya la siguiente y se crea su Sound, para que este
	          cargada cuando toque el fundido (son minutos de audio: crearla
	          al final dejaba un hueco). Si al llegar no cargo, va otra que si.
	  Turbo   mientras CORRE (economia v4, K1: perfil.turboRestante > 0 y
	          sin el atributo TurboPausado del Player; el Turbo solo corre
	          mientras se juega) funde a MUSICA.turbo; suena como mucho
	          REPETICIONES_TURBO veces y vuelve la del patio aunque el Turbo
	          siga (dura 10-15 min: entera cansaria, §5.2). Si se acaba o se
	          pausa (2 min sin hacer nada), vuelve el patio con fundido; al
	          reanudarse vuelve la del Turbo si aun no ha sonado esas veces:
	          se cuentan por Turbo (de 0 a algo), no por cada pausa.
	  Baja    a lo que diga Sonido.atenuacion() (las celebraciones, el
	          rebirth y las insignias la ponen a la mitad mientras suenan),
	          con una transicion corta.
	  Calla   si el jugador la quita (perfil.ajustes.musica, Sonido.activado):
	          se funde y se PARA, no solo baja el grupo, para no seguir
	          bajando audio que nadie oye. Al volver a ponerla empieza otra.

	Un Bucle de Sonido por pista, creado la primera vez que suena y
	reutilizado: cambiar de pista no crea Sounds. El nivel de cada pista
	(0..1) se mueve hacia su objetivo cada Heartbeat; el volumen es el del
	registro x nivel x atenuacion. La pista que suena queda en el atributo
	"Pista" del SoundGroup Musica (lo ensena Sonido.prueba.listar).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Sonidos = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sonidos"))

local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))
local Sonido = require(script.Parent:WaitForChild("Sonido"))

local jugador = Players.LocalPlayer

local FUNDIDO = Sonidos.FUNDIDO_MUSICA
-- s que se espera a que cargue una pista antes de saltar a otra
local ESPERA_CARGA = 15
-- Rapidez con la que se sigue a la atenuacion (por segundo)
local SEGUIR_ATENUACION = 6

local rng = Random.new()

type Pista = {
	clave: string,
	bucle: Sonido.Bucle,
	nivel: number,
	objetivo: number,
	turbo: boolean,
	empezo: number,
}

local bucles: { [string]: Sonido.Bucle } = {}
local terminadas: { [string]: boolean } = {}

local actual: Pista? = nil
local saliendo: { Pista } = {}
local ultimaPatio: string? = nil
-- La siguiente del patio, sorteada (y creada, para que cargue) al empezar una
local proximaPatio: string? = nil
local vecesTurbo = 0 -- veces que ha empezado la del Turbo en este Turbo
local enTurbo = false
local atenuado = 1

-- El Bucle de una pista (se crea la primera vez); nil si esta callada (id 0)
local function bucleDe(clave: string): Sonido.Bucle?
	local b = bucles[clave]
	if b then
		return b
	end
	local nuevo = Sonido.bucle(clave)
	if not nuevo then
		return nil
	end
	nuevo.sonido.Ended:Connect(function()
		terminadas[clave] = true
	end)
	bucles[clave] = nuevo
	return nuevo
end

-- Las pistas de una lista que pueden sonar (sin las de id 0)
local function sonables(lista: { string }): { string }
	local claves: { string } = {}
	for _, clave in lista do
		if Sonidos.id(clave) then
			table.insert(claves, clave)
		end
	end
	return claves
end

-- Le quedan segundos de Turbo (el servidor los publica en el perfil y lo
-- pone a 0 al acabarse), en pausa o no
local function hayTurbo(): boolean
	local p = EstadoCliente.perfil
	return p ~= nil and typeof(p.turboRestante) == "number" and p.turboRestante > 0
end

-- El Turbo corre: le queda y no esta en pausa
local function turboActivo(): boolean
	return hayTurbo() and jugador:GetAttribute("TurboPausado") ~= true
end
-- Si en el ultimo Heartbeat quedaba Turbo: las veces de la pista del Turbo
-- se cuentan por Turbo, no por cada vez que se reanuda tras una pausa
local habiaTurbo = false

local function yaCargo(clave: string): boolean
	local b = bucles[clave]
	return b ~= nil and b.sonido.IsLoaded
end

-- Una del patio al azar que no sea `evitar` (salvo que solo haya una)
local function sortearPatio(evitar: string?): string?
	local patio = sonables(Sonidos.MUSICA.patio)
	if #patio == 0 then
		return nil
	end
	local clave = patio[rng:NextInteger(1, #patio)]
	while #patio > 1 and clave == evitar do
		clave = patio[rng:NextInteger(1, #patio)]
	end
	return clave
end

-- La siguiente pista (y si es la del Turbo), o nil si no hay ninguna
local function elegir(): (string?, boolean)
	if turboActivo() and vecesTurbo < Sonidos.REPETICIONES_TURBO then
		local turbo = sonables(Sonidos.MUSICA.turbo)
		if #turbo > 0 then
			return turbo[rng:NextInteger(1, #turbo)], true
		end
	end
	local clave = proximaPatio
	if clave == nil or clave == ultimaPatio then
		clave = sortearPatio(ultimaPatio)
	elseif not yaCargo(clave) then
		-- La prevista no cargo en toda una pista (o no carga): mejor otra ya
		-- cargada; si no hay, otra cualquiera antes que esperar a la que falla
		local otras: { string } = {}
		for _, otra in sonables(Sonidos.MUSICA.patio) do
			if otra ~= ultimaPatio and otra ~= clave then
				if yaCargo(otra) then
					return otra, false
				end
				table.insert(otras, otra)
			end
		end
		if #otras > 0 then
			clave = otras[rng:NextInteger(1, #otras)]
		end
	end
	return clave, false
end

local function marcarPista()
	local grupo = SoundService:FindFirstChild("Musica")
	local esta = actual
	if grupo then
		grupo:SetAttribute("Pista", if esta then esta.clave else nil)
	end
end

-- Funde la actual hacia fuera y empieza `clave` desde el principio
local function empezar(clave: string, esTurbo: boolean)
	local b = bucleDe(clave)
	if not b then
		return
	end
	local previa = actual
	if previa then
		previa.objetivo = 0
		table.insert(saliendo, previa)
	end
	-- Si esa misma se estaba yendo, se recupera (no puede sonar dos veces)
	for i = #saliendo, 1, -1 do
		if saliendo[i].clave == clave then
			table.remove(saliendo, i)
		end
	end
	terminadas[clave] = nil
	b.fijarVolumen(0)
	b.sonar(true)
	actual = { clave = clave, bucle = b, nivel = 0, objetivo = 1, turbo = esTurbo, empezo = os.clock() }
	if esTurbo then
		vecesTurbo += 1
	else
		ultimaPatio = clave
		-- La siguiente, ya: su Sound empieza a cargar mientras suena esta
		proximaPatio = sortearPatio(clave)
		if proximaPatio then
			bucleDe(proximaPatio)
		end
	end
	marcarPista()
end

local function callarActual()
	local esta = actual
	if esta then
		esta.objetivo = 0
		table.insert(saliendo, esta)
		actual = nil
		marcarPista()
	end
end

-- Cuando toca cambiar de pista: se acaba (fundido cruzado antes del final),
-- acabo, o no carga
local function siguienteSiToca(p: Pista)
	local s = p.bucle.sonido
	local cargada = s.IsLoaded and s.TimeLength > 0
	local acabando = cargada and s.TimeLength - s.TimePosition <= FUNDIDO
	-- (por si no llego Ended; la musica nunca se pausa, asi que no sonar es
	-- haber acabado. Sound.IsPaused no distingue: es true siempre que no suena)
	local acabada = terminadas[p.clave] == true or (cargada and not s.IsPlaying and os.clock() - p.empezo > 1)
	local atascada = not s.IsLoaded and os.clock() - p.empezo > ESPERA_CARGA
	if not (acabando or acabada or atascada) then
		return
	end
	local clave, esTurbo = elegir()
	if not clave then
		return
	end
	-- La misma otra vez (una lista de una): sin fundido, cuando acabe
	if clave ~= p.clave or acabada or atascada then
		empezar(clave, esTurbo)
	end
end

local function acercar(p: Pista, paso: number)
	if p.nivel < p.objetivo then
		p.nivel = math.min(p.objetivo, p.nivel + paso)
	else
		p.nivel = math.max(p.objetivo, p.nivel - paso)
	end
	p.bucle.fijarVolumen(p.nivel * atenuado)
end

RunService.Heartbeat:Connect(function(dt)
	local suena = Sonido.activado("Musica")

	-- Un Turbo nuevo: su pista vuelve a poder sonar REPETICIONES_TURBO veces.
	-- Una pausa y su vuelta no la reinician
	local hay = hayTurbo()
	if hay and not habiaTurbo then
		vecesTurbo = 0
	end
	habiaTurbo = hay
	-- El Turbo empieza, se pausa, sigue o acaba: se cambia de lista ya, con fundido
	local turbo = turboActivo()
	if turbo ~= enTurbo then
		enTurbo = turbo
		if suena then
			local clave, esTurbo = elegir()
			local esta = actual
			if clave and (esta == nil or esta.turbo ~= esTurbo) then
				empezar(clave, esTurbo)
			end
		end
	end

	if suena then
		local esta = actual
		if esta == nil then
			local clave, esTurbo = elegir()
			if clave then
				empezar(clave, esTurbo)
			end
		else
			siguienteSiToca(esta)
		end
	else
		callarActual()
	end

	atenuado += (Sonido.atenuacion() - atenuado) * math.min(1, dt * SEGUIR_ATENUACION)
	local paso = dt / FUNDIDO
	local esta = actual
	if esta then
		acercar(esta, paso)
	end
	for i = #saliendo, 1, -1 do
		local p = saliendo[i]
		acercar(p, paso)
		if p.nivel <= 0 then
			p.bucle.parar()
			table.remove(saliendo, i)
		end
	end
end)
