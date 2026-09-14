--!strict
--[[
	Album (ModuleScript)
	El album de mascotas: 4 pestanas (una por set) + Rey. A la izquierda la
	rejilla de 10 tarjetas del set (silueta gris si no la tienes); a la derecha
	el detalle de la seleccionada con TODAS sus copias y las acciones:

	  Limpiar     abre la mesa de reparacion con esa copia (si esta sucia)
	  Vender      VenderMascotaEvent(uid)
	  Exhibir     ExhibirEvent(uid, pedestal 1..6) / quitar del pedestal
	  Fusionar    FusionarEvent(id, estado) cuando hay 3 copias limpias iguales
	  Ensamblar   abre la mesa con los 5 fragmentos

	Cada tarjeta lleva un ViewportFrame con el modelo whitebox en el MEJOR
	estado que tengas: el album es donde se ve la coleccion crecer. Las
	tarjetas se cachean y solo se reconstruye el modelo si cambia ese estado,
	porque el perfil llega hasta 4 veces por segundo mientras excavas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosMascota = require(Utilidades:WaitForChild("ModelosMascota"))
local Formato = require(Utilidades:WaitForChild("Formato"))
local Red = require(Utilidades:WaitForChild("Red"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Componentes = require(script.Parent:WaitForChild("Componentes"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local FusionarEvent = Red.evento("FusionarEvent")
local VenderMascotaEvent = Red.evento("VenderMascotaEvent")
local VenderDuplicadosEvent = Red.evento("VenderDuplicadosEvent")
local ExhibirEvent = Red.evento("ExhibirEvent")

type Mascota = DefinicionesMascotas.Mascota

local Album = {}

local ANCHO, ALTO = 980, 620
local modal = Componentes.modal("Album", Textos.ALBUM.titulo, ANCHO, ALTO)
local contenido = modal.contenido

-- === Izquierda: pestanas + rejilla ===
local izquierda = Componentes.marco({ Parent = contenido, Size = UDim2.new(0, 630, 1, 0), Transparencia = 1 })
local nombresPestanas = {}
for _, set in DefinicionesMascotas.SETS do
	table.insert(nombresPestanas, set.nombre)
end
table.insert(nombresPestanas, "Rey")

local rejillaScroll = Componentes.scroll(izquierda, UDim2.new(1, 0, 1, -82), UDim2.fromOffset(0, 44))
local rejilla = Componentes.rejilla(rejillaScroll, UDim2.fromOffset(118, 156), 6)
rejilla.HorizontalAlignment = Enum.HorizontalAlignment.Left

local pie = Componentes.marco({ Parent = izquierda, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 1, -34), Transparencia = 1 })
local textoPie = Componentes.texto({ Parent = pie, Size = UDim2.new(1, -170, 1, 0), Tamano = 14, Color = Paleta.UI_TEXTO_SUAVE })
Componentes.boton({
	Parent = pie,
	Texto = Textos.TIENDA.venderDuplicados,
	Size = UDim2.fromOffset(160, 32),
	Position = UDim2.new(1, -160, 0, 0),
	Tamano = 13,
	alPulsar = function()
		VenderDuplicadosEvent:FireServer()
	end,
})

-- === Derecha: detalle ===
local derecha = Componentes.marco({ Parent = contenido, Size = UDim2.new(1, -642, 1, 0), Position = UDim2.fromOffset(642, 0), Color = Paleta.UI_PANEL, Radio = 12 })
Componentes.padding(derecha, 10)
local detalleVacio = Componentes.texto({ Parent = derecha, Texto = "Elige una mascota", Size = UDim2.fromScale(1, 1), Alinear = Enum.TextXAlignment.Center, Color = Paleta.UI_TEXTO_SUAVE })
local detalle = Componentes.marco({ Parent = derecha, Size = UDim2.fromScale(1, 1), Transparencia = 1, Visible = false })
Componentes.lista(detalle, 6)
local viewportDetalle = Componentes.viewport(detalle, UDim2.new(1, 0, 0, 170), 1)
local nombreDetalle = Componentes.texto({ Parent = detalle, Size = UDim2.new(1, 0, 0, 26), Tamano = 20, Negrita = true, Orden = 2 })
local subDetalle = Componentes.texto({ Parent = detalle, Size = UDim2.new(1, 0, 0, 18), Tamano = 13, Color = Paleta.UI_TEXTO_SUAVE, Orden = 3 })
local statsDetalle = Componentes.texto({ Parent = detalle, Size = UDim2.new(1, 0, 0, 18), Tamano = 14, Orden = 4 })
local pasivaDetalle = Componentes.texto({ Parent = detalle, Size = UDim2.new(1, 0, 0, 34), Tamano = 12, Color = Paleta.UI_ACENTO, Orden = 5, AlinearY = Enum.TextYAlignment.Top })
local descDetalle = Componentes.texto({ Parent = detalle, Size = UDim2.new(1, 0, 0, 34), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE, Orden = 6, AlinearY = Enum.TextYAlignment.Top })
local acciones = Componentes.scroll(detalle, UDim2.new(1, 0, 1, -320))
acciones.LayoutOrder = 7
Componentes.lista(acciones, 4)

-- === Estado ===
local setActual = 1
local seleccion: string? = nil
type Tarjeta = { marco: TextButton, viewport: ViewportFrame, pips: { Frame }, copias: TextLabel, frag: Componentes.Barra, nombre: TextLabel, estadoModelo: string }
local tarjetas: { [string]: Tarjeta } = {}

local function mascotasDelSet(indice: number): { Mascota }
	if indice > #DefinicionesMascotas.SETS then
		local rey = DefinicionesMascotas.obtener(DefinicionesMascotas.ID_REY)
		return if rey then { rey } else {}
	end
	return DefinicionesMascotas.porSet(DefinicionesMascotas.SETS[indice].id)
end

-- Mejor copia (mayor estado; entre iguales, limpia) o nil
local function mejorCopia(id: string): (string?, any)
	local mejorUid, mejor = nil, nil
	for uid, copia in EstadoCliente.copiasDe(id) do
		if not mejor or copia.estado > mejor.estado or (copia.estado == mejor.estado and mejor.sucia and not copia.sucia) then
			mejorUid, mejor = uid, copia
		end
	end
	return mejorUid, mejor
end

local function modeloSilueta(def: Mascota): Model
	local m = ModelosMascota.mascota(def, 3, false)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Color = Paleta.SILUETA
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0
		elseif p:IsA("BillboardGui") then
			p:Destroy()
		end
	end
	return m
end

local function modeloDe(def: Mascota, copia: any?): Model
	if copia then
		return ModelosMascota.mascota(def, copia.estado, copia.sucia)
	end
	return modeloSilueta(def)
end

local function claveModelo(copia: any?): string
	if not copia then
		return "nada"
	end
	return tostring(copia.estado) .. (if copia.sucia then "s" else "l")
end

local mostrarDetalle: (id: string) -> ()

local function crearTarjeta(def: Mascota): Tarjeta
	local marco = Instance.new("TextButton")
	marco.Text = ""
	marco.AutoButtonColor = false
	marco.BackgroundColor3 = Paleta.UI_PANEL
	marco.BorderSizePixel = 0
	marco.Selectable = true
	marco.Name = def.id
	Componentes.esquinas(marco, 10)
	local borde = Componentes.borde(marco, Paleta.RAREZA[def.rareza], 2)
	borde.Transparency = 0.5
	local viewport = Componentes.viewport(marco, UDim2.new(1, -8, 0, 84))
	viewport.Position = UDim2.fromOffset(4, 4)
	local nombre = Componentes.texto({ Parent = marco, Texto = def.nombre, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 90), Tamano = 13, Negrita = true, Alinear = Enum.TextXAlignment.Center })
	local filaPips = Componentes.marco({ Parent = marco, Size = UDim2.new(1, -8, 0, 10), Position = UDim2.fromOffset(4, 110), Transparencia = 1 })
	Componentes.lista(filaPips, 4, true, Enum.HorizontalAlignment.Center)
	local pips = {}
	for i = 1, 5 do
		local pip = Componentes.marco({ Parent = filaPips, Size = UDim2.fromOffset(16, 10), Color = Paleta.UI_FONDO, Radio = 3, Orden = i })
		pips[i] = pip
	end
	local copias = Componentes.texto({ Parent = marco, Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(4, 122), Tamano = 11, Color = Paleta.UI_TEXTO_SUAVE, Alinear = Enum.TextXAlignment.Center })
	local frag = Componentes.barra(marco, UDim2.new(1, -12, 0, 10), Paleta.UI_GEMAS)
	frag.marco.Position = UDim2.fromOffset(6, 140)
	marco.Activated:Connect(function()
		mostrarDetalle(def.id)
	end)
	marco.SelectionGained:Connect(function()
		borde.Transparency = 0
	end)
	marco.SelectionLost:Connect(function()
		borde.Transparency = 0.5
	end)
	marco.Parent = rejillaScroll
	return { marco = marco, viewport = viewport, pips = pips, copias = copias, frag = frag, nombre = nombre, estadoModelo = "" }
end

local function refrescarTarjeta(def: Mascota, t: Tarjeta)
	local _, mejor = mejorCopia(def.id)
	local clave = claveModelo(mejor)
	if clave ~= t.estadoModelo then
		t.estadoModelo = clave
		Componentes.mostrarModelo(t.viewport, modeloDe(def, mejor))
	end
	t.nombre.TextColor3 = if mejor then Paleta.UI_TEXTO else Paleta.UI_TEXTO_SUAVE
	local porEstado = { 0, 0, 0, 0, 0 }
	local total, sucias = 0, 0
	for _, copia in EstadoCliente.copiasDe(def.id) do
		porEstado[copia.estado] = (porEstado[copia.estado] or 0) + 1
		total += 1
		if copia.sucia then
			sucias += 1
		end
	end
	for i, pip in t.pips do
		pip.BackgroundColor3 = if porEstado[i] > 0 then Paleta.RAREZA[def.rareza] else Paleta.UI_FONDO
	end
	if total == 0 then
		t.copias.Text = Textos.ALBUM.sinCopias
	else
		t.copias.Text = Textos.formatear(Textos.ALBUM.copias, { n = total }) .. (if sucias > 0 then string.format(" · %d %s", sucias, Textos.ALBUM.sucia) else "")
	end
	local p = EstadoCliente.perfil
	local fragmentos = if p and p.fragmentos then (p.fragmentos[def.id] or 0) else 0
	if def.rareza == "Mitica" then
		t.frag.marco.Visible = false
	else
		t.frag.fijar(fragmentos / GameConfig.FRAGMENTOS_POR_MASCOTA, Textos.formatear(Textos.ALBUM.fragmentos, { n = fragmentos }))
	end
	t.marco.BackgroundColor3 = if seleccion == def.id then Paleta.UI_PANEL_CLARO else Paleta.UI_PANEL
end

local function refrescarRejilla()
	local lista = mascotasDelSet(setActual)
	local visibles = {}
	for orden, def in lista do
		local t = tarjetas[def.id]
		if not t then
			t = crearTarjeta(def)
			tarjetas[def.id] = t
		end
		t.marco.LayoutOrder = orden
		t.marco.Visible = true
		visibles[def.id] = true
		refrescarTarjeta(def, t)
	end
	for id, t in tarjetas do
		if not visibles[id] then
			t.marco.Visible = false
		end
	end
	local p = EstadoCliente.perfil
	local max = DefinicionesMejoras.valor("Almacen", EstadoCliente.nivelMejora("Almacen"))
	local exhibidas = 0
	if p and p.exhibidas then
		for _ in p.exhibidas do
			exhibidas += 1
		end
	end
	textoPie.Text = Textos.formatear(Textos.ALBUM.almacen, { n = EstadoCliente.cuentaMascotas(), max = max }) .. "   ·   " .. Textos.formatear(Textos.ALBUM.exhibidas, { n = exhibidas })
end

-- === Detalle ===

local function botonAccion(texto: string, orden: number, color: Color3?, alPulsar: () -> ()): TextButton
	return Componentes.boton({ Parent = acciones, Texto = texto, Size = UDim2.new(1, -8, 0, 30), Orden = orden, Tamano = 13, Color = color, alPulsar = alPulsar })
end

local pedestalesAbiertosPara: string? = nil

local function refrescarDetalle()
	local id = seleccion
	if not id then
		detalle.Visible = false
		detalleVacio.Visible = true
		return
	end
	local def = DefinicionesMascotas.obtener(id)
	if not def then
		return
	end
	detalle.Visible = true
	detalleVacio.Visible = false
	local _, mejor = mejorCopia(id)
	Componentes.mostrarModelo(viewportDetalle, modeloDe(def, mejor))
	nombreDetalle.Text = def.nombre
	nombreDetalle.TextColor3 = Paleta.RAREZA[def.rareza]
	local setNombre = "Rey"
	for _, s in DefinicionesMascotas.SETS do
		if s.id == def.set then
			setNombre = s.nombre
		end
	end
	subDetalle.Text = setNombre .. " · " .. DefinicionesMascotas.NOMBRE_RAREZA[def.rareza]
	statsDetalle.Text = string.format("%s %d   %s %d", Textos.ALBUM.resistencia, def.resistencia, Textos.ALBUM.poder, def.poder)
	pasivaDetalle.Text = Textos.ALBUM.pasiva .. ": " .. DefinicionesMascotas.textoPasiva(def)
	descDetalle.Text = def.descripcion

	Componentes.limpiar(acciones)
	local orden = 0
	local function siguiente()
		orden += 1
		return orden
	end

	local p = EstadoCliente.perfil
	-- Fragmentos / ensamblar
	local fragmentos = if p and p.fragmentos then (p.fragmentos[id] or 0) else 0
	if def.rareza ~= "Mitica" then
		if fragmentos >= GameConfig.FRAGMENTOS_POR_MASCOTA then
			botonAccion(if EstadoCliente.tienePase("AutoEnsamblaje") then Textos.ALBUM.autoEnsamblar else Textos.ALBUM.ensamblar, siguiente(), Paleta.UI_ACENTO, function()
				Menu.abrir("Reparacion", { tipo = "ensamblaje", id = id })
			end).TextColor3 = Paleta.UI_FONDO
		else
			Componentes.texto({ Parent = acciones, Texto = Textos.formatear(Textos.ALBUM.fragmentos, { n = fragmentos }), Size = UDim2.new(1, -8, 0, 20), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE, Orden = siguiente() })
		end
	elseif not mejor then
		Componentes.texto({ Parent = acciones, Texto = Textos.ALBUM.reyBloqueado, Size = UDim2.new(1, -8, 0, 40), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE, Orden = siguiente() })
	end

	-- Fusiones posibles: por estado con >= 3 copias limpias no exhibidas
	local limpiasPorEstado: { [number]: number } = {}
	local copias = EstadoCliente.copiasDe(id)
	for uid, copia in copias do
		if not copia.sucia and not EstadoCliente.estaExhibida(uid) then
			limpiasPorEstado[copia.estado] = (limpiasPorEstado[copia.estado] or 0) + 1
		end
	end
	for estado = 1, DefinicionesMascotas.ESTADO_MAX - 1 do
		if (limpiasPorEstado[estado] or 0) >= 3 then
			botonAccion(string.format("%s: %s → %s", Textos.ALBUM.fusionar, DefinicionesMascotas.nombreEstado(estado), DefinicionesMascotas.nombreEstado(estado + 1)), siguiente(), Paleta.UI_GEMAS, function()
				FusionarEvent:FireServer(id, estado)
			end)
		end
	end

	-- Copias, ordenadas de mejor a peor
	local lista = {}
	for uid, copia in copias do
		table.insert(lista, { uid = uid, copia = copia })
	end
	table.sort(lista, function(a, b)
		if a.copia.estado ~= b.copia.estado then
			return a.copia.estado > b.copia.estado
		end
		return tostring(a.uid) < tostring(b.uid)
	end)
	for _, entrada in lista do
		local uid, copia = entrada.uid, entrada.copia
		local fila = Componentes.marco({ Parent = acciones, Size = UDim2.new(1, -8, 0, 64), Color = Paleta.UI_FONDO, Radio = 8, Orden = siguiente() })
		local pedestal = EstadoCliente.estaExhibida(uid)
		local etiqueta = DefinicionesMascotas.nombreEstado(copia.estado)
		if copia.sucia then
			etiqueta ..= " · " .. Textos.ALBUM.sucia
		end
		if pedestal then
			etiqueta ..= " · pedestal " .. tostring(pedestal)
		end
		Componentes.texto({ Parent = fila, Texto = etiqueta, Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(6, 2), Tamano = 12, Negrita = true, Color = Paleta.RAREZA[def.rareza] })
		local botones = Componentes.marco({ Parent = fila, Size = UDim2.new(1, -8, 0, 28), Position = UDim2.fromOffset(6, 28), Transparencia = 1 })
		Componentes.lista(botones, 4, true)
		local base = GameConfig.VALOR_BASE_RAREZA[def.rareza] or 0
		local valor = math.floor(base * (GameConfig.MULT_ESTADO[copia.estado] or 1) * (if copia.sucia then GameConfig.MULT_SUCIA else 1) + 0.5)
		if copia.sucia then
			Componentes.boton({ Parent = botones, Texto = Textos.ALBUM.limpiar, Size = UDim2.fromOffset(74, 26), Tamano = 12, Color = Paleta.UI_ENERGIA, ColorTexto = Paleta.UI_FONDO, Orden = 1, alPulsar = function()
				Menu.abrir("Reparacion", { tipo = "limpieza", uid = uid })
			end })
		elseif pedestal then
			Componentes.boton({ Parent = botones, Texto = Textos.ALBUM.quitarExhibir, Size = UDim2.fromOffset(120, 26), Tamano = 11, Orden = 1, alPulsar = function()
				ExhibirEvent:FireServer(nil, pedestal)
			end })
		else
			Componentes.boton({ Parent = botones, Texto = Textos.ALBUM.exhibir, Size = UDim2.fromOffset(74, 26), Tamano = 12, Color = Paleta.UI_PANEL_CLARO, Orden = 1, alPulsar = function()
				pedestalesAbiertosPara = if pedestalesAbiertosPara == uid then nil else uid
				refrescarDetalle()
			end })
		end
		if def.rareza ~= "Mitica" then
			Componentes.boton({ Parent = botones, Texto = Textos.formatear(Textos.ALBUM.vender, { valor = Formato.miles(valor) }), Size = UDim2.fromOffset(110, 26), Tamano = 12, Color = Paleta.UI_PELIGRO, Orden = 2, alPulsar = function()
				VenderMascotaEvent:FireServer(uid)
			end })
		end
		if pedestalesAbiertosPara == uid then
			local filaPed = Componentes.marco({ Parent = acciones, Size = UDim2.new(1, -8, 0, 30), Transparencia = 1, Orden = siguiente() })
			Componentes.lista(filaPed, 4, true)
			for i = 1, GameConfig.PEDESTALES do
				local ocupado = p and p.exhibidas and p.exhibidas[tostring(i)] ~= nil
				Componentes.boton({ Parent = filaPed, Texto = tostring(i), Size = UDim2.fromOffset(40, 26), Tamano = 12, Color = if ocupado then Paleta.UI_BLOQUEADO else Paleta.UI_ACENTO, ColorTexto = if ocupado then Paleta.UI_TEXTO_SUAVE else Paleta.UI_FONDO, Orden = i, alPulsar = function()
					ExhibirEvent:FireServer(uid, i)
					pedestalesAbiertosPara = nil
				end })
			end
		end
	end
end

mostrarDetalle = function(id: string)
	seleccion = id
	pedestalesAbiertosPara = nil
	refrescarRejilla()
	refrescarDetalle()
end

local pestanas = Componentes.pestanas(izquierda, nombresPestanas, function(indice)
	setActual = indice
	seleccion = nil
	pedestalesAbiertosPara = nil
	refrescarRejilla()
	refrescarDetalle()
end)

local function refrescarTodo()
	if not modal.estaAbierto() then
		return
	end
	refrescarRejilla()
	refrescarDetalle()
end

EstadoCliente.alCambiarPerfil:Connect(refrescarTodo)

table.insert(modal.alCerrar, function()
	Menu.notificarCierre("Album")
end)

Menu.registrar("Album", {
	abrir = function(argumento)
		modal.abrir()
		if typeof(argumento) == "string" then
			local def = DefinicionesMascotas.obtener(argumento)
			if def then
				for i, set in DefinicionesMascotas.SETS do
					if set.id == def.set then
						setActual = i
					end
				end
				if def.rareza == "Mitica" then
					setActual = #DefinicionesMascotas.SETS + 1
				end
				seleccion = argumento
			end
		end
		pestanas.seleccionar(setActual)
		if seleccion then
			refrescarDetalle()
		end
	end,
	cerrar = modal.cerrar,
	estaAbierto = modal.estaAbierto,
	primerSeleccionable = function()
		return Componentes.primerSeleccionable(rejillaScroll) or modal.botonCerrar
	end,
})

return Album
