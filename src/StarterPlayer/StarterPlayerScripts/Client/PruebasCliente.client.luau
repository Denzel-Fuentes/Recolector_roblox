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
	Fuera de Studio no crea nada.
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
	if Players.LocalPlayer:GetAttribute("EnPatio") == true then
		Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	end
	return "camara custom"
end

-- Disposicion forzada para capturas sin dispositivo
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
	local modelo = nil
	for _, m in game:GetService("CollectionService"):GetTagged("RecicladoraArte") do
		modelo = m
	end
	return string.format("modelo=%s lista=%s enCinta=%s bloques=%s objetos=%d",
		modelo and modelo:GetFullName() or "nil", tostring(efectos:GetAttribute("Lista")), tostring(efectos:GetAttribute("EnCinta")),
		tostring(efectos:GetAttribute("Bloques")), #efectos:GetChildren())
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
