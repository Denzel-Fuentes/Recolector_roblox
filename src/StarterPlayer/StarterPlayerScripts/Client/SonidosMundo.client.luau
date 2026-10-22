--!strict
--[[
	SonidosMundo
	Unica responsabilidad: los sonidos 3D de la bolsa lanzada y de los
	contenedores, los que oye todo el que este cerca. Lo que suena en un
	cliente no se replica, asi que cada cliente los reproduce al ver lo que
	ya le llega del servidor:

	  lanzar       una bolsa en vuelo aparece en workspace.Objetos: la marca
	               Lanzamiento con el atributo LanzadaPor (y Fuerza) y aun no
	               tiene ObjetoId (se registra al posarse; asi una caida que
	               entra con StreamingEnabled no suena como lanzada). El whoosh
	               va en un attachment que la sigue y se queda un poco al
	               acabar, para que no se corte si la bolsa entra y
	               desaparece; mas grave cuanta mas fuerza (1,1 - 0,2 x
	               fuerza, docs/Audio-propuesta §1.6), la de cualquiera.
	  fallo        el primer golpe de esa bolsa: estaba cayendo y deja de
	               caer (rebota hacia arriba, contra el suelo o contra la
	               pared de un contenedor, o se para junto al suelo). Se mira
	               en las posiciones que replica el servidor, que mueve la
	               bolsa con PivotTo (Services/Lanzamiento): nada de fisica en
	               el cliente. Esperar a LibreEn (se pone al posarse) sonaba
	               medio segundo tarde; si aun asi no se vio el golpe, suena
	               entonces.
	  falloAviso   solo para mi, si con ese fallo se pierde una racha de 2 o
	               mas (perfil.racha pasa a 0: solo un fallo la corta). Con
	               cada fallo cansaria; asi dice "la racha vuelve a cero".
	  dentroGolpe  cada deposito (RecicladoraEvent, que va a todos): el golpe
	               en el contenedor donde entro, lanzada o a mano; en el
	               general, el del volquete metalico (dentroGolpeGeneral).

	Nada de esto decide nada: el servidor ya lo hizo; aqui solo suena.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Red = require(Utilidades:WaitForChild("Red"))
local Contenedores = require(Utilidades:WaitForChild("Contenedores"))

local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))
local Sonido = require(script.Parent:WaitForChild("Sonido"))

-- Cayendo a mas de esto (studs/s) y deja de caer = golpe
local CAIDA_MIN = 4
-- Sin moverse tanto rato despues de caer = se paro...
local QUIETA = 0.2
-- ... si esta a esto del suelo o menos (si no, es un tiron de la red)
local CERCA_SUELO = 2.5
-- Lo mas que se sigue una bolsa (su vuelo dura como mucho VIDA_PROYECTIL)
local VIDA_SEGUIMIENTO = GameConfig.VIDA_PROYECTIL + 2
-- Lo que se queda el attachment del whoosh al dejar de seguirla
local COLA_WHOOSH = 2

type Vuelo = {
	modelo: Model,
	ancla: Attachment,
	y: number, -- altura en la ultima posicion distinta
	t: number, -- cuando llego esa posicion
	vy: number, -- velocidad vertical entre las dos ultimas distintas
	nacio: number,
	golpeo: boolean,
}

local vuelos: { Vuelo } = {}

-- ===========================================================================
-- La bolsa en vuelo
-- ===========================================================================

local function posicionDe(modelo: Model): Vector3
	local cuerpo = modelo.PrimaryPart
	return if cuerpo then cuerpo.Position else modelo:GetPivot().Position
end

local paramsSuelo = RaycastParams.new()
paramsSuelo.FilterType = Enum.RaycastFilterType.Exclude

-- Algo solido justo debajo (sin contar la bolsa ni a los personajes)
local function cercaDelSuelo(modelo: Model, pos: Vector3): boolean
	local excluir: { Instance } = { modelo }
	for _, otro in Players:GetPlayers() do
		if otro.Character then
			table.insert(excluir, otro.Character)
		end
	end
	paramsSuelo.FilterDescendantsInstances = excluir
	return workspace:Raycast(pos + Vector3.new(0, 0.5, 0), Vector3.new(0, -(CERCA_SUELO + 0.5), 0), paramsSuelo) ~= nil
end

local function golpe(v: Vuelo, pos: Vector3)
	if v.golpeo then
		return
	end
	v.golpeo = true
	Sonido.tocar("fallo", { posicion = pos })
end

local function seguir(modelo: Model)
	local pos = posicionDe(modelo)
	local ancla = Instance.new("Attachment")
	ancla.Name = "SonidoBolsa"
	ancla.Parent = workspace.Terrain
	ancla.WorldPosition = pos
	-- Sin fuerza (no deberia), el tono al azar del registro
	local fuerza = modelo:GetAttribute("Fuerza")
	local tono = if typeof(fuerza) == "number" then 1.1 - 0.2 * math.clamp(fuerza, 0, 1) else nil
	Sonido.tocar("lanzar", { padre = ancla, tono = tono })
	local ahora = os.clock()
	local v: Vuelo = { modelo = modelo, ancla = ancla, y = pos.Y, t = ahora, vy = 0, nacio = ahora, golpeo = false }
	table.insert(vuelos, v)
	-- Se poso fuera (Lanzamiento le pone LibreEn): si no se vio el golpe, ahora
	modelo:GetAttributeChangedSignal("LibreEn"):Once(function()
		golpe(v, posicionDe(modelo))
	end)
end

task.spawn(function()
	local carpeta = workspace:WaitForChild("Objetos")
	carpeta.ChildAdded:Connect(function(hijo)
		if hijo:IsA("Model") and hijo:GetAttribute("LanzadaPor") ~= nil and hijo:GetAttribute("ObjetoId") == nil then
			seguir(hijo)
		end
	end)
end)

RunService.Heartbeat:Connect(function()
	local ahora = os.clock()
	for i = #vuelos, 1, -1 do
		local v = vuelos[i]
		if v.modelo.Parent ~= nil and not v.golpeo and ahora - v.nacio < VIDA_SEGUIMIENTO then
			local pos = posicionDe(v.modelo)
			v.ancla.WorldPosition = pos
			-- Entre dos posiciones que llegan del servidor no se mueve: la
			-- velocidad se mide entre posiciones distintas
			local dy = pos.Y - v.y
			if math.abs(dy) > 1e-3 then
				local vy = dy / math.max(ahora - v.t, 1 / 240)
				if v.vy < -CAIDA_MIN and vy > -1 then
					golpe(v, pos)
				end
				v.vy, v.y, v.t = vy, pos.Y, ahora
			elseif v.vy < -CAIDA_MIN and ahora - v.t > QUIETA and cercaDelSuelo(v.modelo, pos) then
				golpe(v, pos)
			end
		else
			table.remove(vuelos, i)
			local ancla = v.ancla
			task.delay(COLA_WHOOSH, function()
				ancla:Destroy()
			end)
		end
	end
end)

-- ===========================================================================
-- La racha perdida (solo yo)
-- ===========================================================================

local rachaAntes = 0
EstadoCliente.alCambiarPerfil:Connect(function(perfil: any)
	local racha = if typeof(perfil) == "table" and typeof(perfil.racha) == "number" then perfil.racha else 0
	if racha == 0 and rachaAntes >= 2 then
		Sonido.tocar("falloAviso")
	end
	rachaAntes = racha
end)

-- ===========================================================================
-- El golpe en el contenedor
-- ===========================================================================

Red.evento("RecicladoraEvent").OnClientEvent:Connect(function(contenedor)
	local material = if typeof(contenedor) == "string" and contenedor ~= "General" then contenedor else nil
	local c = Contenedores.de(material)
	if not c then
		return
	end
	Sonido.tocar(if c.material then "dentroGolpe" else "dentroGolpeGeneral", { posicion = c.zona.Position })
end)
