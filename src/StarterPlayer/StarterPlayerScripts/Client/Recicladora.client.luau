--!strict
--[[
	Recicladora (cliente)
	Unica responsabilidad: animar las recicladoras de Blender (modelos con tag
	RecicladoraArte que coloca ArteMundo.recicladora). Puro decorado local:

	  Trituradora  los dos rodillos dentados giran siempre, y mas deprisa
	               mientras cae basura en la tolva.
	  Cinta en L   parada hasta que alguien deposita una bolsa: el servidor
	               avisa a todos (RecicladoraEvent con el contenedor y el
	               material de cada objeto) y de la caja gris salen objetos de
	               basura que suben por el tramo 1, doblan en la esquina, suben
	               por el tramo 2 y caen en la tolva. Mientras haya basura
	               encima los listones avanzan, los rodillos de la cinta giran
	               y la luz de la salida pasa de roja a verde.
	  Salida       cuando cae el ultimo objeto de un deposito la trituradora
	               prensa un momento y sale un bloque por la rampa (clon de
	               BloqueMolde), que se queda al final y se desvanece.

	Desde el 5 oct hay CINCO: la del general (sin atributo Material) y una
	por contenedor de tipo (atributo Material), escaladas (GetScale). Cada
	una tiene su propia cola y su propio estado; el deposito anima la del
	contenedor donde entro. La ruta, los ejes y los tiempos estan en
	Config/Recicladora en el marco del pivote a escala 1: aqui se multiplican
	por la escala del modelo. Nada colisiona ni toca el estado del juego.
	Varios depositos seguidos se ponen en cola: la cinta suelta un objeto
	cada INTERVALO_BASURA.

	Pruebas: workspace.RecicladoraEfectos lleva los atributos Lista, EnCinta y
	Bloques de la del GENERAL, Vistas con cuantas hay listas y Cola con los
	objetos que esperan en todas (lo lee PruebasCliente "recicladora").
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Datos = require(Shared:WaitForChild("Config"):WaitForChild("Recicladora"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosObjetos = require(Utilidades:WaitForChild("ModelosObjetos"))
local Red = require(Utilidades:WaitForChild("Red"))

local RecicladoraEvent = Red.evento("RecicladoraEvent")

local MATERIALES = { "Metal", "Plastico", "Papel", "Organico" }
local GENERAL = "General"
local rng = Random.new()

type Giratoria = { parte: BasePart, base: CFrame, eje: Vector3, sentido: number }
type Listones = { parte: BasePart, base: CFrame, dir: Vector3 }
type Pendiente = { material: string, alCaer: () -> () }
type Vista = {
	modelo: Model,
	clave: string, -- "General" o el material del contenedor
	escala: number,
	trituradora: { Giratoria },
	cinta: { Giratoria },
	rampa: { Giratoria },
	listones: { Listones },
	luzVerde: BasePart?,
	luzRoja: BasePart?,
	molde: Model?,
	rutaBasura: { Vector3 },
	rutaBloque: { Vector3 },
	cola: { Pendiente },
	triturandoHasta: number,
	lucesEnMarcha: boolean?,
	bloques: { Model },
	enCinta: number,
	enRampa: number,
	anguloTrituradora: number,
	anguloCinta: number,
	anguloRampa: number,
	desplazamiento: number,
}
type Viaje = {
	vista: Vista,
	modelo: Model,
	ruta: { Vector3 },
	tramo: number,
	recorrido: number,
	velocidad: number,
	alto: number,
	orientacion: CFrame,
	giro: CFrame,
	esBasura: boolean,
	alLlegar: () -> (),
}

local vistas: { [string]: Vista } = {}
local preparando: { [Instance]: boolean } = {}
local viajes: { Viaje } = {}

local efectos = Instance.new("Folder")
efectos.Name = "RecicladoraEfectos"
efectos:SetAttribute("Lista", false)
efectos:SetAttribute("EnCinta", 0)
efectos:SetAttribute("Bloques", 0)
efectos:SetAttribute("Vistas", 0)
efectos.Parent = workspace

local function contarVistas()
	local n = 0
	for _ in vistas do
		n += 1
	end
	efectos:SetAttribute("Vistas", n)
end

-- ===========================================================================
-- Preparar el modelo
-- ===========================================================================

local function girar(g: Giratoria, angulo: number)
	g.parte.CFrame = CFrame.new(g.base.Position) * CFrame.fromAxisAngle(g.eje, angulo * g.sentido) * g.base.Rotation
end

local function encenderLuces(v: Vista, enMarcha: boolean)
	if v.lucesEnMarcha == enMarcha then
		return
	end
	v.lucesEnMarcha = enMarcha
	if v.luzVerde then
		v.luzVerde.Material = if enMarcha then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
	if v.luzRoja then
		v.luzRoja.Material = if enMarcha then Enum.Material.SmoothPlastic else Enum.Material.Neon
	end
end

local function preparar(modelo: Model)
	-- El Mundo se replica por partes: se esperan los hijos con plazo
	local trit = modelo:WaitForChild("Trituradora", 15)
	local moviles = trit and trit:WaitForChild("Moviles", 15)
	if not moviles then
		warn("[Recicladora] " .. modelo:GetFullName() .. " no tiene Trituradora.Moviles: sin animacion")
		return
	end
	local material = modelo:GetAttribute("Material")
	local pivote = modelo:GetPivot()
	local escala = modelo:GetScale()
	local v: Vista = {
		modelo = modelo,
		clave = if typeof(material) == "string" and material ~= "" then material else GENERAL,
		escala = escala,
		trituradora = {},
		cinta = {},
		rampa = {},
		listones = {},
		luzVerde = nil,
		luzRoja = nil,
		molde = nil,
		rutaBasura = {},
		rutaBloque = {},
		cola = {},
		triturandoHasta = 0,
		lucesEnMarcha = nil,
		bloques = {},
		enCinta = 0,
		enRampa = 0,
		anguloTrituradora = 0,
		anguloCinta = 0,
		anguloRampa = 0,
		desplazamiento = 0,
	}
	for _, p in Datos.RUTA_BASURA do
		table.insert(v.rutaBasura, pivote:PointToWorldSpace(p * escala))
	end
	for _, p in Datos.RUTA_BLOQUE do
		table.insert(v.rutaBloque, pivote:PointToWorldSpace(p * escala))
	end
	for nombre, eje in Datos.EJE_GIRO do
		local p = moviles:WaitForChild(nombre, 5)
		if p and p:IsA("BasePart") then
			local g: Giratoria = {
				parte = p,
				base = p.CFrame,
				eje = pivote:VectorToWorldSpace(if eje == "X" then Vector3.xAxis else Vector3.zAxis),
				sentido = Datos.SIEMPRE_GIRAN[nombre] or 1,
			}
			if Datos.SIEMPRE_GIRAN[nombre] then
				table.insert(v.trituradora, g)
			elseif nombre:match("^RodilloRampa") then
				table.insert(v.rampa, g)
			else
				table.insert(v.cinta, g)
			end
		end
	end
	for _, tramo in Datos.TRAMOS do
		local p = moviles:WaitForChild(tramo.listones, 5)
		if p and p:IsA("BasePart") then
			local dir = (v.rutaBasura[tramo.hasta] - v.rutaBasura[tramo.desde]).Unit
			table.insert(v.listones, { parte = p, base = p.CFrame, dir = dir })
		end
	end
	local verde = moviles:WaitForChild("LuzSalida_Verde", 5)
	local roja = moviles:WaitForChild("LuzSalida_Roja", 5)
	v.luzVerde = if verde and verde:IsA("BasePart") then verde else nil
	v.luzRoja = if roja and roja:IsA("BasePart") then roja else nil
	-- La luz verde del panel de la trituradora esta siempre encendida
	local panel = moviles:WaitForChild("LuzPanel_Verde", 5)
	if panel and panel:IsA("BasePart") then
		panel.Material = Enum.Material.Neon
	end
	local molde = modelo:WaitForChild("BloqueMolde", 5)
	v.molde = if molde and molde:IsA("Model") then molde else nil
	encenderLuces(v, false)
	vistas[v.clave] = v
	contarVistas()
	if v.clave == GENERAL then
		efectos:SetAttribute("Lista", true)
	end
end

local function considerar(inst: Instance)
	if inst:IsA("Model") and not preparando[inst] then
		preparando[inst] = true
		task.spawn(preparar, inst)
	end
end
CollectionService:GetInstanceAddedSignal("RecicladoraArte"):Connect(considerar)
for _, inst in CollectionService:GetTagged("RecicladoraArte") do
	considerar(inst)
end

-- ===========================================================================
-- Viajes: basura por la cinta y bloques por la rampa
-- ===========================================================================

local function soloDecorado(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
end

-- Direccion para orientar el objeto: la del tramo, salvo en los tramos casi
-- verticales (sale de la caja, cae en la tolva), donde se conserva la anterior
local function colocar(viaje: Viaje)
	local a, b = viaje.ruta[viaje.tramo], viaje.ruta[viaje.tramo + 1]
	local largo = (b - a).Magnitude
	local pos = if largo > 0 then a:Lerp(b, viaje.recorrido / largo) else b
	local dir = (b - a).Unit
	if largo > 0 and math.abs(dir.Y) < 0.9 then
		viaje.orientacion = CFrame.lookAt(Vector3.zero, dir)
	end
	-- Los modelos llevan el pivote en el suelo: el punto de la ruta es su centro
	local cf = CFrame.new(pos) * viaje.orientacion * viaje.giro
	viaje.modelo:PivotTo(cf * CFrame.new(0, -viaje.alto / 2, 0))
end

local function empezarViaje(v: Vista, modelo: Model, ruta: { Vector3 }, velocidad: number, esBasura: boolean, alLlegar: () -> ())
	local _, tamano = modelo:GetBoundingBox()
	local viaje: Viaje = {
		vista = v,
		modelo = modelo,
		ruta = ruta,
		tramo = 1,
		recorrido = 0,
		velocidad = velocidad * v.escala,
		alto = tamano.Y,
		orientacion = CFrame.lookAt(Vector3.zero, (ruta[#ruta] - ruta[1]) * Vector3.new(1, 0, 1)),
		giro = if esBasura then CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) else CFrame.identity,
		esBasura = esBasura,
		alLlegar = alLlegar,
	}
	colocar(viaje)
	table.insert(viajes, viaje)
end

-- Devuelve true si el viaje termino
local function avanzar(viaje: Viaje, dt: number): boolean
	local ruta = viaje.ruta
	local ultimo = viaje.tramo == #ruta - 1
	-- La caida en la tolva va mas deprisa que la banda
	local resto = dt * viaje.velocidad * (if viaje.esBasura and ultimo then 2 else 1)
	while resto > 0 do
		local largo = (ruta[viaje.tramo + 1] - ruta[viaje.tramo]).Magnitude
		local falta = largo - viaje.recorrido
		if resto < falta then
			viaje.recorrido += resto
			resto = 0
		else
			resto -= falta
			if viaje.tramo + 1 >= #ruta then
				viaje.recorrido = largo
				colocar(viaje)
				return true
			end
			viaje.tramo += 1
			viaje.recorrido = 0
		end
	end
	colocar(viaje)
	return false
end

local function crearBasura(v: Vista, material: string): Model
	local mat = if table.find(MATERIALES, material) then material else MATERIALES[rng:NextInteger(1, #MATERIALES)]
	local m = ModelosObjetos.basura(mat, rng)
	local _, tamano = m:GetBoundingBox()
	local mayor = math.max(tamano.X, tamano.Y, tamano.Z)
	if mayor > 0 then
		m:ScaleTo(m:GetScale() * Datos.LARGO_OBJETO * v.escala / mayor)
	end
	soloDecorado(m)
	m.Parent = efectos
	return m
end

local function actualizarBloques(v: Vista)
	if v.clave == GENERAL then
		efectos:SetAttribute("Bloques", #v.bloques)
	end
end

local function desvanecer(v: Vista, m: Model)
	local idx = table.find(v.bloques, m)
	if idx then
		table.remove(v.bloques, idx)
		actualizarBloques(v)
	end
	local info = TweenInfo.new(0.6)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(0.7, function()
		m:Destroy()
	end)
end

-- Sale un bloque prensado por la rampa
local function sacarBloque(v: Vista)
	if not v.molde then
		return
	end
	local b = v.molde:Clone()
	for _, d in b:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 0
		end
	end
	soloDecorado(b)
	-- Pivote en la base del bloque, como los modelos de basura: colocar()
	-- pone el centro sobre la ruta
	local centro, tamano = b:GetBoundingBox()
	b.WorldPivot = CFrame.new(centro.Position) * v.modelo:GetPivot().Rotation * CFrame.new(0, -tamano.Y / 2, 0)
	b.Name = "Bloque"
	b.Parent = efectos
	table.insert(v.bloques, b)
	actualizarBloques(v)
	if #v.bloques > Datos.MAX_BLOQUES then
		desvanecer(v, v.bloques[1])
	end
	empezarViaje(v, b, v.rutaBloque, Datos.VELOCIDAD_BLOQUE, false, function()
		task.delay(Datos.VIDA_BLOQUE, function()
			if b.Parent then
				desvanecer(v, b)
			end
		end)
	end)
end

-- Un deposito en `contenedor` ("General" o un material): sus objetos a la
-- cola de esa recicladora; cuando cae el ultimo, sale el bloque
RecicladoraEvent.OnClientEvent:Connect(function(contenedor, materiales)
	if typeof(materiales) ~= "table" then
		return
	end
	local v = vistas[if typeof(contenedor) == "string" then contenedor else GENERAL] or vistas[GENERAL]
	if not v then
		return
	end
	local lista: { string } = {}
	for _, m in materiales do
		if #lista >= Datos.MAX_BASURA_POR_DEPOSITO then
			break
		end
		table.insert(lista, if typeof(m) == "string" then m else "")
	end
	while #lista < Datos.MIN_BASURA_POR_DEPOSITO do
		table.insert(lista, "")
	end
	local pendientes = #lista
	for _, material in lista do
		table.insert(v.cola, {
			material = material,
			alCaer = function()
				pendientes -= 1
				v.triturandoHasta = os.clock() + Datos.ESPERA_TRITURAR
				if pendientes == 0 then
					task.delay(Datos.ESPERA_TRITURAR, sacarBloque, v)
				end
			end,
		})
	end
end)

-- Cada recicladora suelta un objeto de su cola cada INTERVALO_BASURA
local ultimaSalida: { [Vista]: number } = {}
task.spawn(function()
	while true do
		local ahora = os.clock()
		local enCola = 0
		for _, v in vistas do
			enCola += #v.cola
			if #v.cola > 0 and ahora - (ultimaSalida[v] or 0) >= Datos.INTERVALO_BASURA then
				ultimaSalida[v] = ahora
				local siguiente = table.remove(v.cola, 1) :: Pendiente
				local m = crearBasura(v, siguiente.material)
				empezarViaje(v, m, v.rutaBasura, Datos.VELOCIDAD_CINTA, true, function()
					m:Destroy()
					siguiente.alCaer()
				end)
			end
		end
		efectos:SetAttribute("Cola", enCola)
		task.wait(0.05)
	end
end)

-- ===========================================================================
-- Cada frame
-- ===========================================================================

RunService.RenderStepped:Connect(function(dt)
	for _, v in vistas do
		v.enCinta, v.enRampa = 0, 0
	end
	for i = #viajes, 1, -1 do
		local viaje = viajes[i]
		if not viaje.modelo.Parent then
			table.remove(viajes, i)
		else
			if viaje.esBasura then
				viaje.vista.enCinta += 1
			else
				viaje.vista.enRampa += 1
			end
			if avanzar(viaje, dt) then
				table.remove(viajes, i)
				viaje.alLlegar()
			end
		end
	end
	local general = vistas[GENERAL]
	efectos:SetAttribute("EnCinta", if general then general.enCinta else 0)

	local ahora = os.clock()
	for _, v in vistas do
		local giro = if ahora < v.triturandoHasta then Datos.GIRO_TRITURANDO else Datos.GIRO_TRITURADORA
		v.anguloTrituradora += dt * giro
		for _, g in v.trituradora do
			girar(g, v.anguloTrituradora)
		end
		if v.enCinta > 0 then
			v.anguloCinta += dt * Datos.GIRO_RODILLOS_CINTA
			v.desplazamiento = (v.desplazamiento + dt * Datos.VELOCIDAD_CINTA * v.escala) % (Datos.PASO_LISTONES * v.escala)
			for _, g in v.cinta do
				girar(g, v.anguloCinta)
			end
			for _, l in v.listones do
				l.parte.CFrame = l.base + l.dir * v.desplazamiento
			end
		end
		if v.enRampa > 0 then
			v.anguloRampa += dt * Datos.GIRO_RODILLOS_CINTA * (Datos.VELOCIDAD_BLOQUE / Datos.VELOCIDAD_CINTA)
			for _, g in v.rampa do
				girar(g, v.anguloRampa)
			end
		end
		encenderLuces(v, v.enCinta > 0)
	end
end)
