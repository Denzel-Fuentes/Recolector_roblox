--!nonstrict
--[[
	PruebasCliente
	SOLO EN STUDIO. Expone ReplicatedStorage.EjecutarPruebaCliente
	(BindableFunction) con acciones con nombre que corren DENTRO de la VM del
	cliente (la de execute_luau es la del plugin y no comparte modulos):

	    Invoke("abrir", "Tienda", argumento)  Menu.abrir
	    Invoke("cerrar")                      Menu.cerrarTodo
	    Invoke("estado")                      resumen de EstadoCliente
	    Invoke("panel", "Tienda")             descripcion del panel abierto
	    Invoke("reticula")                    estado de reticula/raton/camara
	    Invoke("verme", 8) / ("camaraNormal")  camara sobre el propio personaje
	    Invoke("plataforma", "tactil")        fuerza la disposicion (tactil/gamepad/teclado; "" = real)
	    Invoke("disposicion")                 escala, disposicion, compacto, viewport
	    Invoke("hud")                         rectangulos del HUD y avisos de solape / fuera de pantalla
	    Invoke("recicladora")                 estado de la animacion de la recicladora (Recicladora.client)
	    Invoke("trayectoria", 0.8)            dibuja la linea de ayuda como si se cargara el tiro (0 la quita)
	    Invoke("celebracion", "Papel")        la celebracion de un acierto (UI/Celebraciones) con datos de ejemplo
	    Invoke("mas1")                        los "+1" de recoger (EfectoRecogida) delante del personaje
	    Invoke("avisoMundo", texto, icono)    una burbuja de AvisosMundo delante del personaje
	    Invoke("toast", tipo?)                toasts con el estilo nuevo (sin tipo: exito, dinero, aviso)
	    Invoke("botones")                     botones tactiles RECOGER / LANZAR y si se ven
	    Invoke("record", 32, true)            la tarjeta grande de record de distancia (true = del servidor)
	    Invoke("idioma")                      idioma activo, separadores y una muestra de cada seccion
	    Invoke("tablones")                    los tablones de ranking montados, sus filas visibles y tu fila
	    Invoke("modulo", nombre, accion, ...) require(<ModuleScript nombre>).prueba[accion](...)
	Fuera de Studio no crea nada.

	El gancho "modulo" (22 oct) es la via para lo nuevo: un ModuleScript del
	cliente (bajo Client, o en ReplicatedFirst si existe, p. ej. la pantalla de
	carga) que exponga `prueba = { accion = function(...) ... end }` se prueba
	sin tocar este script, que ya no se edita mas.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then
	return
end

local UI = script.Parent:WaitForChild("UI")
local Menu = require(UI:WaitForChild("Menu"))
local Escala = require(UI:WaitForChild("Kit"):WaitForChild("Escala"))
local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Formato = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Formato"))

local gancho = Instance.new("BindableFunction")
gancho.Name = "EjecutarPruebaCliente"
gancho.Parent = ReplicatedStorage

local acciones = {}

function acciones.trayectoria(carga)
	local LineaTrayectoria = require(script.Parent:WaitForChild("LineaTrayectoria"))
	local fuerza = tonumber(carga) or 0.8
	if fuerza <= 0 then
		LineaTrayectoria.ocultar()
		return "linea oculta"
	end
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return "sin personaje"
	end
	LineaTrayectoria.dibujar(root.Position + root.CFrame.LookVector * 60, fuerza)
	local carpeta = workspace:FindFirstChild("LineaTrayectoria")
	local visibles, ultimo = 0, nil
	for _, p in (if carpeta then carpeta:GetChildren() else {}) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			visibles += 1
			ultimo = p.Position
		end
	end
	return string.format("activa=%s puntos visibles=%d ultimo=%s", tostring(LineaTrayectoria.activa()), visibles, tostring(ultimo))
end

function acciones.abrir(nombre, argumento)
	Menu.abrir(nombre, argumento)
	task.wait(0.3)
	return "abierto: " .. tostring(Menu.abierto())
end

function acciones.cerrar()
	Menu.cerrarTodo()
	return "cerrado"
end

function acciones.estado()
	local p = EstadoCliente.perfil
	return string.format("perfil=%s cargado=%s modoDev=%s dinero=%s bolsa=%d/%d",
		tostring(p ~= nil), tostring(EstadoCliente.cargado), tostring(EstadoCliente.modoDev), tostring(p and p.dinero),
		#EstadoCliente.bolsa.items, EstadoCliente.bolsa.capacidad)
end

function acciones.panel(nombre)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local sg = pg:FindFirstChild(nombre)
	if not sg then
		return "no existe " .. nombre
	end
	local botones, textos, viewports = 0, 0, 0
	for _, d in sg:GetDescendants() do
		if d:IsA("GuiButton") and d.Visible then
			botones += 1
		elseif d:IsA("TextLabel") and d.Visible then
			textos += 1
		elseif d:IsA("ViewportFrame") then
			viewports += 1
		end
	end
	return string.format("%s enabled=%s botones=%d textos=%d viewports=%d", nombre, tostring(sg.Enabled), botones, textos, viewports)
end

-- Estado de la reticula y del raton (primera persona)
function acciones.reticula()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local sg = pg:FindFirstChild("Reticula")
	return string.format("reticula=%s mouseIcon=%s mouseBehavior=%s cameraMode=%s enPatio=%s panel=%s",
		tostring(sg and sg.Enabled), tostring(UserInputService.MouseIconEnabled), tostring(UserInputService.MouseBehavior),
		tostring(Players.LocalPlayer.CameraMode), tostring(Players.LocalPlayer:GetAttribute("EnPatio")), tostring(Menu.abierto()))
end

-- Mirar al propio personaje desde fuera (capturas de la pose y la bolsa).
-- Sale de primera persona y fuerza el personaje visible mientras dure.
local verme: RBXScriptConnection? = nil
function acciones.verme(distancia)
	local cam = workspace.CurrentCamera
	local ch = Players.LocalPlayer.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if not root then
		return "sin personaje"
	end
	Players.LocalPlayer.CameraMode = Enum.CameraMode.Classic
	task.wait()
	cam.CameraType = Enum.CameraType.Scriptable
	local d = tonumber(distancia) or 8
	local pos = (root.CFrame * CFrame.new(d * 0.45, 1.5, -d)).Position
	cam.CFrame = CFrame.lookAt(pos, root.Position + Vector3.new(0, 0.5, 0))
	if verme then
		verme:Disconnect()
	end
	-- El personaje mira a la camara (de frente se ve la bolsa). Con AutoRotate
	-- el motor lo gira hacia donde mira la camara en cada paso de fisica y
	-- pisa cualquier CFrame que se le ponga: hay que apagarlo.
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = false
	end
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(pos.X, root.Position.Y, pos.Z))
	verme = RunService.RenderStepped:Connect(function()
		for _, p in ch:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 0
			end
		end
	end)
	return "camara scriptable mirando al personaje"
end

function acciones.camaraNormal()
	if verme then
		verme:Disconnect()
		verme = nil
	end
	local ch = Players.LocalPlayer.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	-- La vista vale en todo el mapa (6 oct): primera = LockFirstPerson
	if Players.LocalPlayer:GetAttribute("Vista") ~= "tercera" then
		Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	end
	return "camara custom"
end

-- Disposicion forzada para capturas sin dispositivo
-- ("camara", "tercera" | "primera"): cambia la vista (en todo el mapa) como la V y
-- dice como quedo la camara
function acciones.camara(vista)
	local jugador = Players.LocalPlayer
	jugador:SetAttribute("Vista", if vista == "tercera" then "tercera" else "primera")
	task.wait(0.5)
	local camara = workspace.CurrentCamera
	local personaje = jugador.Character
	local cabeza = personaje and personaje:FindFirstChild("Head")
	local hum = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local distancia = if cabeza and cabeza:IsA("BasePart") then (camara.CFrame.Position - cabeza.Position).Magnitude else -1
	return string.format("vista=%s modo=%s distancia a la cabeza=%.1f offset=%s autoRotate=%s",
		tostring(jugador:GetAttribute("Vista")), tostring(jugador.CameraMode), distancia,
		if hum then tostring(hum.CameraOffset) else "?", if hum then tostring(hum.AutoRotate) else "?")
end

function acciones.plataforma(p)
	if p == nil or p == "" or p == "real" then
		Escala.forzarPlataforma(nil)
	else
		Escala.forzarPlataforma(p)
	end
	task.wait(0.2)
	return acciones.disposicion()
end

function acciones.disposicion()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.zero
	local dw, dh = Escala.disenoDisponible()
	return string.format("viewport=%dx%d escala=%.2f diseno=%dx%d disposicion=%s compacto=%s", vp.X, vp.Y, Escala.valor(), dw, dh, Escala.disposicionActual(), tostring(Escala.esCompacto()))
end

-- Rectangulos (px reales) de los bloques del HUD, con avisos si alguno se sale
-- del viewport o se solapa con otro (los que pueden hacerlo a proposito, como
-- la base de una barra sobre su barra, no se comparan)
function acciones.hud()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local hud = pg:FindFirstChild("HUD")
	if not hud then
		return "sin HUD"
	end
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(0, 0)
	local bloques = {}
	for _, hijo in hud:GetChildren() do
		if hijo:IsA("GuiObject") and hijo.Visible then
			table.insert(bloques, hijo)
		end
	end
	local lineas = {}
	local avisos = 0
	for i, a in bloques do
		local ap, as = a.AbsolutePosition, a.AbsoluteSize
		table.insert(lineas, string.format("%s: %d,%d %dx%d", a.Name, ap.X, ap.Y, as.X, as.Y))
		if ap.X < 0 or ap.Y < 0 or ap.X + as.X > vp.X or ap.Y + as.Y > vp.Y + 1 then
			avisos += 1
			table.insert(lineas, "  ! fuera de pantalla")
		end
		for j = i + 1, #bloques do
			local b = bloques[j]
			local bp, bs = b.AbsolutePosition, b.AbsoluteSize
			local solapa = ap.X < bp.X + bs.X and bp.X < ap.X + as.X and ap.Y < bp.Y + bs.Y and bp.Y < ap.Y + as.Y
			if solapa then
				avisos += 1
				table.insert(lineas, "  ! solapa con " .. b.Name)
			end
		end
	end
	table.insert(lineas, 1, string.format("avisos=%d viewport=%dx%d", avisos, vp.X, vp.Y))
	return table.concat(lineas, "\n")
end

-- Lo que publica Recicladora.client en workspace.RecicladoraEfectos: si
-- encontro el modelo, cuanta basura va por la cinta y cuantos bloques hay en
-- la rampa. Tras la prueba de servidor "recicladora": EnCinta > 0 enseguida,
-- y a los ~6 s un bloque.
function acciones.recicladora()
	local efectos = workspace:FindFirstChild("RecicladoraEfectos")
	if not efectos then
		return "sin RecicladoraEfectos (no corre Recicladora.client)"
	end
	local modelo, total = nil, 0
	for _, m in game:GetService("CollectionService"):GetTagged("RecicladoraArte") do
		total += 1
		if m:GetAttribute("Material") == nil then
			modelo = m
		end
	end
	return string.format("modelo=%s lista=%s enCinta=%s bloques=%s objetos=%d | recicladoras=%d animadas=%s",
		modelo and modelo:GetFullName() or "nil", tostring(efectos:GetAttribute("Lista")), tostring(efectos:GetAttribute("EnCinta")),
		tostring(efectos:GetAttribute("Bloques")), #efectos:GetChildren(), total, tostring(efectos:GetAttribute("Vistas")))
end

-- La celebracion de un acierto con datos de ejemplo, sobre la boca del
-- contenedor de ese tipo (o del general)
function acciones.celebracion(contenedor)
	local cel = UI:FindFirstChild("Celebraciones")
	local evento = cel and cel:FindFirstChild("CelebracionPrueba")
	if not evento then
		return "sin UI/Celebraciones"
	end
	contenedor = contenedor or "Papel"
	local posicion = nil
	for _, c in game:GetService("CollectionService"):GetTagged("Contenedor") do
		local material = c:GetAttribute("Material")
		if (material or "General") == contenedor then
			local zona = c:FindFirstChild("ZonaAcierto")
			posicion = zona and zona.Position
		end
	end
	evento:Fire({ tipo = "acierto", contenedor = contenedor, dinero = 1260, distancia = 24, bonusPct = 40, racha = 3, separadas = 9, malSeparadas = 2, posicion = posicion })
	return "celebracion de " .. contenedor .. " en " .. tostring(posicion)
end

-- Un "+1" de cada clase (basura de cada tipo, billete, tesoro, bolsa) en
-- fila delante del personaje
function acciones.mas1()
	local efecto = script.Parent:FindFirstChild("EfectoRecogida")
	local evento = efecto and efecto:FindFirstChild("RecogidaPrueba")
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not evento or not root then
		return "sin EfectoRecogida o sin personaje"
	end
	local casos = { { "basura", "Papel", 1 }, { "basura", "Plastico", 1 }, { "basura", "Metal", 1 }, { "basura", "Organico", 1 }, { "billete", "Metal", 1, 90 }, { "tesoro", "Metal", 1 }, { "bolsa", "", 12 } }
	for i, c in casos do
		evento:Fire(root.CFrame:PointToWorldSpace(Vector3.new((i - 4) * 2.2, 0, -9)), c[1], c[2], c[3], c[4] or 0)
	end
	return #casos .. " efectos"
end

-- Una burbuja de aviso en el mundo (AvisosMundo.client) delante del personaje
function acciones.avisoMundo(texto, icono)
	local avisos = script.Parent:FindFirstChild("AvisosMundo")
	local evento = avisos and avisos:FindFirstChild("AvisoPrueba")
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not evento or not root then
		return "sin AvisosMundo o sin personaje"
	end
	evento:Fire(root.CFrame:PointToWorldSpace(Vector3.new(0, 2, -8)), texto or "Termina tu montón primero", icono)
	return "burbuja delante del personaje"
end

-- El idioma con el que arranco el cliente (Utilidades/Idioma) y una muestra:
-- para forzar otro, atributo IdiomaStudio = "en" en ReplicatedStorage en Edit,
-- antes de Play (o Test > Player Emulator > Locale)
function acciones.idioma()
	local t = Idioma.textos
	local mensaje = Idioma.mensaje("REBIRTH.faltaDinero", { dinero = Idioma.dinero(12500) })
	return string.format("idioma=%s (LocaleId=%s) | %s | %s | %s | %s | %s | %s | %s",
		Idioma.codigo, Players.LocalPlayer.LocaleId, t.HUD.bolsaLlena, t.TIENDA.titulo, t.PEDIDOS.pestanaInsignias,
		Idioma.resolver(mensaje), Formato.multiplicador(1.5), Idioma.literal("Excavar"), Idioma.mayusculas(t.TIPOS.Organico))
end

-- Los tablones de ranking de la plaza (Tablones.client): por cada pantalla,
-- cuantas filas se ven en cada columna, el aviso y tu fila
function acciones.tablones()
	local partes = {}
	for _, pantalla in game:GetService("CollectionService"):GetTagged("PantallaRanking") do
		local gui = pantalla:FindFirstChild("TablonRanking")
		if not gui then
			table.insert(partes, tostring(pantalla:GetAttribute("Ranking")) .. ": sin SurfaceGui")
			continue
		end
		local columnas = {}
		for _, periodo in { "historico", "semanal" } do
			local col = gui:FindFirstChild("Columna_" .. periodo, true)
			local visibles = 0
			for _, f in (col and col.Filas:GetChildren()) or {} do
				if f:IsA("Frame") and f.Visible then
					visibles += 1
				end
			end
			local aviso = col and col:FindFirstChild("Aviso")
			local tu = col and col.Tu:FindFirstChildWhichIsA("TextLabel")
			table.insert(columnas, string.format("%s %d filas%s, '%s'", periodo, visibles,
				if aviso and aviso.Visible then " (" .. aviso.Text .. ")" else "", if tu then tu.Text else "?"))
		end
		table.insert(partes, tostring(pantalla:GetAttribute("Ranking")) .. ": " .. table.concat(columnas, "; "))
	end
	return if #partes > 0 then table.concat(partes, "\n") else "no hay tablones (tag PantallaRanking)"
end

-- Un toast de cada tipo (UI/Notificaciones) para ver el estilo
function acciones.toast(tipo)
	local Notificaciones = require(UI:WaitForChild("Notificaciones"))
	local tipos = if tipo then { tipo } else { "exito", "dinero", "aviso" }
	for _, t in tipos do
		Notificaciones.mostrar("Toast de prueba (" .. t .. ")", t)
	end
	local gui = Players.LocalPlayer.PlayerGui:FindFirstChild("Notificaciones")
	local pila = gui and gui:FindFirstChild("Toasts", true)
	return #tipos .. " toasts; en pila: " .. (if pila then #pila:GetChildren() else -1)
end

-- La tarjeta grande de record de distancia (UI/Notificaciones)
function acciones.record(distancia, delServidor)
	local Notificaciones = require(UI:WaitForChild("Notificaciones"))
	Notificaciones.record(tostring(distancia or 32), delServidor == true)
	task.wait(0.6)
	local gui = Players.LocalPlayer.PlayerGui:FindFirstChild("Notificaciones")
	local tarjeta = gui and gui:FindFirstChild("Logro", true)
	if not tarjeta then
		return "sin tarjeta"
	end
	local textos = {}
	for _, d in tarjeta:GetDescendants() do
		if d:IsA("TextLabel") then
			table.insert(textos, string.format("%q@%dpx", d.Text, d.TextSize))
		end
	end
	return string.format("tarjeta %dx%d en y=%d: %s", tarjeta.AbsoluteSize.X, tarjeta.AbsoluteSize.Y, tarjeta.AbsolutePosition.Y, table.concat(textos, ", "))
end

-- Los botones tactiles de ControlPatio (RECOGER y LANZAR) y si se ven
function acciones.botones()
	local ContextActionService = game:GetService("ContextActionService")
	local partes = {}
	for _, nombre in { "Recoger", "Lanzar" } do
		local boton = ContextActionService:GetButton(nombre)
		table.insert(partes, string.format("%s: %s", nombre, if boton then (if boton.Visible then "visible" else "oculto") else "sin boton"))
	end
	return table.concat(partes, " | ")
end

-- El primer ModuleScript con ese nombre bajo raiz (nil si no hay)
local function buscarModulo(raiz: Instance?, nombre: string): ModuleScript?
	if not raiz then
		return nil
	end
	for _, d in raiz:GetDescendants() do
		if d:IsA("ModuleScript") and d.Name == nombre then
			return d
		end
	end
	return nil
end

-- Gancho generico: las pruebas de cada modulo viven en el propio modulo
-- (su tabla `prueba`), bajo Client o en ReplicatedFirst
function acciones.modulo(nombre, accion, ...)
	if typeof(nombre) ~= "string" or typeof(accion) ~= "string" then
		return "uso: (\"modulo\", nombre, accion, ...)"
	end
	local modulo = buscarModulo(script.Parent, nombre)
		or buscarModulo(game:GetService("ReplicatedFirst"), nombre)
	if not modulo then
		return "no hay ningun ModuleScript " .. nombre .. " en Client ni en ReplicatedFirst"
	end
	local m = require(modulo)
	local prueba = if typeof(m) == "table" then m.prueba else nil
	local fn = if typeof(prueba) == "table" then prueba[accion] else nil
	if typeof(fn) ~= "function" then
		return nombre .. " no expone prueba." .. accion
	end
	return fn(...)
end

local function ejecutar(nombre, ...)
	local accion = acciones[nombre]
	if not accion then
		return "accion desconocida: " .. tostring(nombre)
	end
	local ok, res = pcall(accion, ...)
	return ok and tostring(res) or ("error: " .. tostring(res))
end

gancho.OnInvoke = ejecutar

-- Segunda via por atributos (ver Pruebas.server): escribir en el cliente
-- ReplicatedStorage:SetAttribute("PruebaCliente", "nombre|arg") deja el
-- resultado en "ResultadoCliente". Los atributos puestos desde el cliente no
-- se replican: son locales a esta VM, que es justo lo que hace falta.
local ultimaOrden = nil
ReplicatedStorage:GetAttributeChangedSignal("PruebaCliente"):Connect(function()
	local orden = ReplicatedStorage:GetAttribute("PruebaCliente")
	if typeof(orden) ~= "string" or orden == "" or orden == ultimaOrden then
		return
	end
	ultimaOrden = orden
	orden = orden:gsub("^%d+:", "") -- numero de orden antipuesto (ver Pruebas.server)
	ReplicatedStorage:SetAttribute("ResultadoCliente", "")
	local partes = string.split(orden, "|")
	local nombre = table.remove(partes, 1)
	local args = {}
	for _, p in partes do
		table.insert(args, tonumber(p) or p)
	end
	local resultado = ejecutar(nombre, table.unpack(args))
	print("[PruebaCliente " .. nombre .. "] " .. resultado)
	ReplicatedStorage:SetAttribute("ResultadoCliente", resultado)
end)
