--!strict
--[[
	Reparacion (ModuleScript, cliente)
	La mesa de reparacion: los dos minijuegos de KOTAMON.

	  Limpieza     el modelo de la mascota en un ViewportFrame con manchas
	               encima. Se frota arrastrando el puntero (raton, dedo, o
	               cursor virtual con el stick + A en gamepad): cada mancha
	               desaparece tras 0.3 s de contacto. Sin manchas -> terminado.
	  Ensamblaje   5 piezas giradas al azar (90/180/270). Tocar una la gira 90.
	               Todas a 0 -> terminado. Con el pase Auto-Ensamblaje el
	               servidor responde "auto" y no hay minijuego.

	Protocolo con el servidor (Reparacion.luau valida un tiempo minimo):
	  iniciar -> "iniciado" (o "auto") -> el jugador juega -> terminar
	El cliente espera a cumplir ese tiempo minimo antes de mandar terminar,
	para que un jugador rapido nunca reciba "demasiadoRapido".

	Se abre con Menu.abrir("Reparacion", { tipo = "limpieza", uid = ... }) o
	{ tipo = "ensamblaje", id = ... }, o sin argumento para elegir.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosMascota = require(Utilidades:WaitForChild("ModelosMascota"))
local Red = require(Utilidades:WaitForChild("Red"))
local Entrada = require(Utilidades:WaitForChild("Entrada"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Componentes = require(script.Parent:WaitForChild("Componentes"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local LimpiezaEvent = Red.evento("LimpiezaEvent")
local EnsamblajeEvent = Red.evento("EnsamblajeEvent")

local Reparacion = {}

local ANCHO, ALTO = 760, 560
local modal = Componentes.modal("Reparacion", Textos.REPARACION.titulo, ANCHO, ALTO)
local contenido = modal.contenido

local instruccion = Componentes.texto({ Parent = contenido, Size = UDim2.new(1, 0, 0, 24), Tamano = 15, Color = Paleta.UI_TEXTO_SUAVE, Alinear = Enum.TextXAlignment.Center })
local area = Componentes.marco({ Parent = contenido, Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 30), Transparencia = 1, Nombre = "Area" })

-- Estado de la sesion en curso
type Sesion = { tipo: string, clave: string, inicio: number, activa: boolean, conexiones: { RBXScriptConnection } }
local sesion: Sesion? = nil

local function cerrarSesion()
	if sesion then
		for _, c in sesion.conexiones do
			c:Disconnect()
		end
		if sesion.activa then
			if sesion.tipo == "limpieza" then
				LimpiezaEvent:FireServer("cancelar", sesion.clave)
			else
				EnsamblajeEvent:FireServer("cancelar", sesion.clave)
			end
		end
		sesion = nil
	end
	Componentes.limpiar(area)
end

local function terminadoVisual(texto: string)
	Componentes.limpiar(area)
	Componentes.texto({ Parent = area, Texto = texto, Size = UDim2.fromScale(1, 1), Tamano = 26, Negrita = true, Alinear = Enum.TextXAlignment.Center, Color = Paleta.UI_ACENTO })
	task.delay(1.2, function()
		if modal.estaAbierto() then
			Menu.cerrarTodo()
		end
	end)
end

-- ===========================================================================
-- Selector: que reparar
-- ===========================================================================

local function mostrarSelector()
	Componentes.limpiar(area)
	instruccion.Text = Textos.REPARACION.elegir
	local scroll = Componentes.scroll(area)
	Componentes.lista(scroll, 6)
	local orden = 0
	local p = EstadoCliente.perfil
	if p then
		for uid, copia in p.mascotas do
			if copia.sucia then
				local def = DefinicionesMascotas.obtener(copia.id)
				if def then
					orden += 1
					Componentes.boton({ Parent = scroll, Texto = string.format("%s: %s (%s)", Textos.REPARACION.limpieza, def.nombre, DefinicionesMascotas.nombreEstado(copia.estado)), Size = UDim2.new(1, -8, 0, 36), Orden = orden, Color = Paleta.UI_PANEL, alPulsar = function()
						Reparacion.abrirLimpieza(uid)
					end })
				end
			end
		end
		for id, n in p.fragmentos do
			if n >= GameConfig.FRAGMENTOS_POR_MASCOTA then
				local def = DefinicionesMascotas.obtener(id)
				if def then
					orden += 1
					Componentes.boton({ Parent = scroll, Texto = string.format("%s: %s (5/5)", Textos.REPARACION.ensamblaje, def.nombre), Size = UDim2.new(1, -8, 0, 36), Orden = orden, Color = Paleta.UI_PANEL, alPulsar = function()
						Reparacion.abrirEnsamblaje(id)
					end })
				end
			end
		end
	end
	if orden == 0 then
		Componentes.texto({ Parent = scroll, Texto = Textos.REPARACION.nadaQueReparar, Size = UDim2.new(1, 0, 0, 40), Alinear = Enum.TextXAlignment.Center, Color = Paleta.UI_TEXTO_SUAVE })
	end
end

-- ===========================================================================
-- Limpieza
-- ===========================================================================

local function posicionPuntero(cursorVirtual: Frame?): Vector2
	if cursorVirtual and Entrada.esGamepad() then
		local ap = cursorVirtual.AbsolutePosition
		local as = cursorVirtual.AbsoluteSize
		return ap + as / 2
	end
	local m = UserInputService:GetMouseLocation()
	return Vector2.new(m.X, m.Y - GuiService:GetGuiInset().Y)
end

local function dentro(gui: GuiObject, punto: Vector2): boolean
	local ap, as = gui.AbsolutePosition, gui.AbsoluteSize
	return punto.X >= ap.X and punto.X <= ap.X + as.X and punto.Y >= ap.Y and punto.Y <= ap.Y + as.Y
end

local function montarLimpieza(uid: string, copia: any, def: DefinicionesMascotas.Mascota)
	Componentes.limpiar(area)
	instruccion.Text = Textos.REPARACION.instruccionLimpieza
	local zona = Componentes.marco({ Parent = area, Size = UDim2.fromOffset(560, 380), Position = UDim2.new(0.5, 0, 0, 0), Anchor = Vector2.new(0.5, 0), Color = Paleta.UI_PANEL, Radio = 12 })
	local viewport = Componentes.viewport(zona, UDim2.fromScale(1, 1))
	Componentes.mostrarModelo(viewport, ModelosMascota.mascota(def, copia.estado, false))
	local capa = Componentes.marco({ Parent = zona, Size = UDim2.fromScale(1, 1), Transparencia = 1, Nombre = "Manchas" })
	capa.ZIndex = 5
	local progreso = Componentes.texto({ Parent = area, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 390), Tamano = 15, Negrita = true, Alinear = Enum.TextXAlignment.Center })

	-- Manchas en posiciones deterministas por uid
	local rng = Random.new(tonumber(uid) or 1)
	local n = rng:NextInteger(GameConfig.MANCHAS_LIMPIEZA.min, GameConfig.MANCHAS_LIMPIEZA.max)
	local manchas: { [Frame]: number } = {}
	local vivas = n
	for i = 1, n do
		local d = rng:NextInteger(40, 58)
		local mancha = Componentes.marco({ Parent = capa, Size = UDim2.fromOffset(d, d), Position = UDim2.fromScale(rng:NextNumber(0.15, 0.85), rng:NextNumber(0.12, 0.88)), Anchor = Vector2.new(0.5, 0.5), Color = Paleta.gris(50), Radio = d, Nombre = "Mancha" .. i })
		mancha.ZIndex = 6
		mancha.BackgroundTransparency = 0.15
		manchas[mancha] = 0
	end
	progreso.Text = string.format("Manchas %d/%d", 0, n)

	-- Cursor virtual para gamepad
	local cursor = Componentes.marco({ Parent = capa, Size = UDim2.fromOffset(26, 26), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), Color = Paleta.UI_ACENTO, Radio = 13 })
	cursor.ZIndex = 8
	cursor.Visible = Entrada.esGamepad()

	local frotando = false
	local s = sesion :: Sesion
	table.insert(s.conexiones, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			frotando = true
		end
	end))
	table.insert(s.conexiones, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			frotando = false
		end
	end))
	local terminado = false
	table.insert(s.conexiones, RunService.RenderStepped:Connect(function(dt)
		if terminado then
			return
		end
		-- Stick izquierdo mueve el cursor virtual
		local stick = Vector2.zero
		for _, estadoInput in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if estadoInput.KeyCode == Enum.KeyCode.Thumbstick1 then
				stick = Vector2.new(estadoInput.Position.X, -estadoInput.Position.Y)
			end
		end
		if stick.Magnitude > 0.2 then
			cursor.Visible = true
			local pos = cursor.Position
			local nx = math.clamp(pos.X.Scale + stick.X * dt * 0.9, 0.02, 0.98)
			local ny = math.clamp(pos.Y.Scale + stick.Y * dt * 0.9, 0.02, 0.98)
			cursor.Position = UDim2.fromScale(nx, ny)
		end
		if not frotando then
			return
		end
		local punto = posicionPuntero(cursor)
		for mancha, acumulado in manchas do
			if dentro(mancha, punto) then
				local nuevo = acumulado + dt
				manchas[mancha] = nuevo
				mancha.BackgroundTransparency = 0.15 + (nuevo / 0.3) * 0.6
				if nuevo >= 0.3 then
					manchas[mancha] = nil
					vivas -= 1
					local t = TweenService:Create(mancha, TweenInfo.new(0.2), { BackgroundTransparency = 1, Size = UDim2.fromOffset(4, 4) })
					t:Play()
					t.Completed:Connect(function()
						mancha:Destroy()
					end)
					progreso.Text = string.format("Manchas %d/%d", n - vivas, n)
				end
			end
		end
		if vivas <= 0 then
			terminado = true
			progreso.Text = "Puliendo…"
			local restante = GameConfig.MIN_SEGUNDOS_LIMPIEZA - (os.clock() - s.inicio) + 0.15
			task.delay(math.max(0, restante), function()
				if sesion == s then
					LimpiezaEvent:FireServer("terminar", uid)
				end
			end)
		end
	end))
end

function Reparacion.abrirLimpieza(uid: string)
	local p = EstadoCliente.perfil
	local copia = p and p.mascotas[uid]
	local def = copia and DefinicionesMascotas.obtener(copia.id)
	if not copia or not def then
		mostrarSelector()
		return
	end
	cerrarSesion()
	sesion = { tipo = "limpieza", clave = uid, inicio = os.clock(), activa = false, conexiones = {} }
	instruccion.Text = "…"
	LimpiezaEvent:FireServer("iniciar", uid)
end

LimpiezaEvent.OnClientEvent:Connect(function(resultado, uid, ok)
	if not sesion or sesion.tipo ~= "limpieza" or sesion.clave ~= uid then
		return
	end
	if resultado == "iniciado" then
		sesion.activa = true
		sesion.inicio = os.clock()
		local p = EstadoCliente.perfil
		local copia = p and p.mascotas[uid]
		local def = copia and DefinicionesMascotas.obtener(copia.id)
		if copia and def then
			montarLimpieza(uid, copia, def)
		end
	elseif resultado == "terminado" then
		sesion.activa = false
		cerrarSesion()
		terminadoVisual(Textos.REPARACION.completado)
	elseif not ok then
		sesion.activa = false
		cerrarSesion()
		mostrarSelector()
	end
end)

-- ===========================================================================
-- Ensamblaje
-- ===========================================================================

local function montarEnsamblaje(id: string, def: DefinicionesMascotas.Mascota)
	Componentes.limpiar(area)
	instruccion.Text = Textos.REPARACION.instruccionEnsamblaje
	local cabecera = Componentes.marco({ Parent = area, Size = UDim2.new(1, 0, 0, 150), Transparencia = 1 })
	local viewport = Componentes.viewport(cabecera, UDim2.fromOffset(200, 140))
	viewport.Position = UDim2.new(0.5, 0, 0, 0)
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	Componentes.mostrarModelo(viewport, ModelosMascota.mascota(def, 2, false))
	local tablero = Componentes.marco({ Parent = area, Size = UDim2.new(1, 0, 0, 240), Position = UDim2.fromOffset(0, 165), Transparencia = 1, Nombre = "Tablero" })
	Componentes.lista(tablero, 16, true, Enum.HorizontalAlignment.Center)
	local progreso = Componentes.texto({ Parent = area, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 420), Tamano = 15, Negrita = true, Alinear = Enum.TextXAlignment.Center })

	local rng = Random.new(#id * 131 + string.byte(id, 1))
	local color = Paleta.MATERIAL[def.material] or Paleta.MUEBLE
	local piezas: { TextButton } = {}
	local encajadas = 0
	local s = sesion :: Sesion
	local terminado = false
	local function contar()
		encajadas = 0
		for _, pieza in piezas do
			if pieza.Rotation % 360 == 0 then
				encajadas += 1
			end
		end
		progreso.Text = string.format("Piezas encajadas %d/%d", encajadas, #piezas)
		if encajadas == #piezas and not terminado then
			terminado = true
			progreso.Text = "Pegando…"
			local restante = GameConfig.MIN_SEGUNDOS_ENSAMBLAJE - (os.clock() - s.inicio) + 0.15
			task.delay(math.max(0, restante), function()
				if sesion == s then
					EnsamblajeEvent:FireServer("terminar", id)
				end
			end)
		end
	end
	for i = 1, GameConfig.FRAGMENTOS_POR_MASCOTA do
		local pieza = Instance.new("TextButton")
		pieza.Name = "Pieza" .. i
		pieza.Text = ""
		pieza.AutoButtonColor = false
		pieza.Size = UDim2.fromOffset(110, 110)
		pieza.BackgroundColor3 = color
		pieza.BorderSizePixel = 0
		pieza.Selectable = true
		pieza.LayoutOrder = i
		pieza.Rotation = rng:NextInteger(1, 3) * 90
		Componentes.esquinas(pieza, 14)
		Componentes.borde(pieza, Paleta.FRAGMENTO_BORDE, 2)
		-- Muesca arriba: hace visible la orientacion
		local muesca = Componentes.marco({ Parent = pieza, Size = UDim2.fromOffset(34, 16), Position = UDim2.new(0.5, 0, 0, 4), Anchor = Vector2.new(0.5, 0), Color = Paleta.gris(40), Radio = 4 })
		muesca.ZIndex = 2
		local numero = Componentes.texto({ Parent = pieza, Texto = tostring(i), Size = UDim2.fromScale(1, 1), Alinear = Enum.TextXAlignment.Center, Tamano = 22, Negrita = true, Color = Paleta.gris(40) })
		numero.ZIndex = 2
		pieza.Activated:Connect(function()
			if terminado then
				return
			end
			TweenService:Create(pieza, TweenInfo.new(0.12), { Rotation = pieza.Rotation + 90 }):Play()
			task.delay(0.13, function()
				pieza.Rotation = pieza.Rotation % 360
				contar()
			end)
		end)
		pieza.Parent = tablero
		piezas[i] = pieza
	end
	contar()
	task.defer(function()
		if Entrada.esGamepad() then
			GuiService.SelectedObject = piezas[1]
		end
	end)
end

function Reparacion.abrirEnsamblaje(id: string)
	local def = DefinicionesMascotas.obtener(id)
	if not def then
		mostrarSelector()
		return
	end
	cerrarSesion()
	sesion = { tipo = "ensamblaje", clave = id, inicio = os.clock(), activa = false, conexiones = {} }
	instruccion.Text = "…"
	EnsamblajeEvent:FireServer("iniciar", id)
end

EnsamblajeEvent.OnClientEvent:Connect(function(resultado, id, ok)
	if not sesion or sesion.tipo ~= "ensamblaje" or sesion.clave ~= id then
		return
	end
	if resultado == "iniciado" then
		sesion.activa = true
		sesion.inicio = os.clock()
		local def = DefinicionesMascotas.obtener(id)
		if def then
			montarEnsamblaje(id, def)
		end
	elseif resultado == "auto" then
		sesion.activa = false
		cerrarSesion()
		terminadoVisual(Textos.REPARACION.autoEnsamblado)
	elseif resultado == "terminado" then
		sesion.activa = false
		cerrarSesion()
		terminadoVisual(Textos.REPARACION.completado)
	elseif not ok then
		sesion.activa = false
		cerrarSesion()
		mostrarSelector()
	end
end)

-- ===========================================================================
-- Registro en el menu
-- ===========================================================================

table.insert(modal.alCerrar, function()
	cerrarSesion()
	Menu.notificarCierre("Reparacion")
end)

Menu.registrar("Reparacion", {
	abrir = function(argumento)
		modal.abrir()
		if typeof(argumento) == "table" and argumento.tipo == "limpieza" and typeof(argumento.uid) == "string" then
			Reparacion.abrirLimpieza(argumento.uid)
		elseif typeof(argumento) == "table" and argumento.tipo == "ensamblaje" and typeof(argumento.id) == "string" then
			Reparacion.abrirEnsamblaje(argumento.id)
		else
			mostrarSelector()
		end
	end,
	cerrar = modal.cerrar,
	estaAbierto = modal.estaAbierto,
	primerSeleccionable = function()
		return Componentes.primerSeleccionable(area) or modal.botonCerrar
	end,
})

return Reparacion
