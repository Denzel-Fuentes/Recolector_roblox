--!strict
--[[
	HUD
	Distribucion del "UI Kit" de simulador (referencia del usuario), en Fusion.
	Diseno v2: en el patio la pantalla muestra solo lo que se usa al jugar
	(bolsa, dinero, fuerza, fragmentos de mascota y el feed); el resto va a
	4 botones.

	  izquierda      botonera de 4: Tienda (Q), Mascotas, Rebirth y Pedidos.
	                 Cada boton aparece cuando su panel existe (UI/<Nombre>),
	                 asi cada lote que trae un panel trae su boton
	  arriba-dcha    "Contadores": la pildora verde grande del dinero y, debajo,
	                 la mascota mas cerca de completarse con fragmentos
	                 ("Latita 3/5"), o una pista para buscarlos
	  derecha        barra de FUERZA de lanzamiento (mantener F; encima, el bonus
	                 que daria acertar desde donde estas) y, a su lado,
	                 la de BOLSA: cuanto llevas, sin numeros (decision del
	                 usuario: se ve llenarse, y "LLENA" en rojo avisa de que
	                 toca volver al contenedor)
	  abajo-dcha     "MANTEN [F] PARA LANZAR" con la bolsa, y encima la pista
	                 de recoger (se retira sola tras 20 recogidas)

	Tactil: el thumbstick y el boton de salto de Roblox ocupan las esquinas de
	abajo, asi que la botonera sube arriba-izquierda y las pistas se apartan; la de lanzar la sustituye el boton de ContextActionService
	que restiliza ControlPatio. Todo cuelga de Escala.disposicion: cambiar de
	mando o de pantalla recoloca sin reconstruir.

	Solo presentacion: lee EstadoCliente.reactivo y manda intencion por
	RemoteEvent o abre paneles por Menu. Los hijos directos del ScreenGui "HUD"
	son los bloques que mide la prueba ("hud"): no deben solaparse.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local DefinicionesPunteria = require(Config:WaitForChild("DefinicionesPunteria"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Formato = require(Utilidades:WaitForChild("Formato"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Tema = require(script.Parent:WaitForChild("Kit"):WaitForChild("Tema"))
local Escala = require(script.Parent:WaitForChild("Kit"):WaitForChild("Escala"))
local Menu = require(script.Parent:WaitForChild("Menu"))
require(script.Parent:WaitForChild("Notificaciones"))

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local jugador = Players.LocalPlayer
local reactivo = EstadoCliente.reactivo

-- No hay Tools: la mochila de Roblox solo estorba
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- En el movil, siempre en horizontal (peticion del usuario, 29 sep: con
-- Sensor, el valor del place, arrancaba en vertical si el telefono lo
-- estaba). Tambien va en StarterGui (default.project.json); aqui por si el
-- place guardado no lo tiene.
jugador:WaitForChild("PlayerGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

local MARGEN = 16
local RECOGIDAS_PARA_APRENDER = 20

local scope = Fusion.scoped(Fusion, Kit)

local tactil = scope:Computed(function(use)
	return use(Escala.disposicion) == "tactil"
end)
local sinPanel = scope:Computed(function(use)
	return use(Menu.abiertoR) == nil
end)
local enPatio = scope:Value(jugador:GetAttribute("EnPatio") == true)
jugador:GetAttributeChangedSignal("EnPatio"):Connect(function()
	enPatio:set(jugador:GetAttribute("EnPatio") == true)
end)

-- Pulso 0..1 para la alarma de bolsa llena. Solo corre mientras suena
local pulso = scope:Value(0)
local hayAlarma = false
RunService.Heartbeat:Connect(function()
	if hayAlarma then
		pulso:set((math.sin(os.clock() * 7) + 1) / 2)
	end
end)

-- ===========================================================================
-- Datos derivados (solo primitivos)
-- ===========================================================================

local dinero = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	return Formato.dinero(if p then (p.dinero or 0) else 0)
end)
local enBolsa = scope:Computed(function(use)
	return #(use(reactivo.bolsa) :: any).items
end)
local capacidad = scope:Computed(function(use)
	return (use(reactivo.bolsa) :: any).capacidad :: number
end)
local bolsaLlena = scope:Computed(function(use)
	return use(enBolsa) >= use(capacidad)
end)

scope:Observer(bolsaLlena):onBind(function()
	hayAlarma = Fusion.peek(bolsaLlena)
	if not hayAlarma then
		pulso:set(0)
	end
end)

-- Recogidas de la sesion: la pista de recoger se retira tras aprender
local recogidas = scope:Value(0)
do
	local ultimo = 0
	scope:Observer(enBolsa):onChange(function()
		local n = Fusion.peek(enBolsa)
		if n > ultimo then
			recogidas:set(Fusion.peek(recogidas) + n - ultimo)
		end
		ultimo = n
	end)
end

-- ===========================================================================
-- Izquierda: botonera de 4
-- ===========================================================================

-- 88 (era 76: el usuario los queria un poco mas grandes, 29 sep)
local LADO_ICONO = 88

local function botonIcono(nombre: string, texto: string, icono: string, tecla: string?, orden: number, alPulsar: () -> (), extra: any?)
	local encima = scope:Value(false)
	local escala = scope:Spring(
		scope:Computed(function(use)
			return if use(encima) then 1.1 else 1
		end),
		40,
		0.55
	)
	local insignia = nil
	if tecla then
		insignia = scope:Insignia({
			Teclado = tecla,
			Tamano = 22,
			Position = UDim2.new(1, -2, 0, 2),
			AnchorPoint = Vector2.new(1, 0),
			ZIndex = 5,
		})
	end
	return scope:New("TextButton")({
		Name = nombre,
		Text = "",
		Size = UDim2.fromOffset(LADO_ICONO, LADO_ICONO),
		LayoutOrder = orden,
		BackgroundTransparency = 1,
		SelectionImageObject = Tema.SELECCION_INVISIBLE,
		[OnEvent("MouseEnter")] = function()
			encima:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			encima:set(false)
		end,
		[OnEvent("Activated")] = alPulsar,
		[Children] = {
			scope:New("UIScale")({ Scale = escala }),
			scope:Icono({
				Clave = icono,
				Tamano = LADO_ICONO - 18,
				Position = UDim2.new(0.5, 0, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				ZIndex = 2,
			}),
			scope:Texto({
				Texto = texto,
				Size = UDim2.new(1, 8, 0, 18),
				Position = UDim2.new(0.5, 0, 1, 0),
				AnchorPoint = Vector2.new(0.5, 1),
				Tamano = 14,
				Fuente = "titulo",
				Color = Paleta.UI_PAPEL,
				Contorno = Paleta.UI_TINTA,
				Alinear = Enum.TextXAlignment.Center,
				Ajustar = false,
				ZIndex = 3,
			}),
			insignia,
			extra,
		},
	})
end

-- Barrita bajo el icono de Rebirth: lo que falta para el siguiente (dinero
-- y mejoras a partes iguales), verde cuando ya se puede renacer
local function barraRebirth()
	local modulo = script.Parent:FindFirstChild("Rebirth")
	if not modulo then
		return nil
	end
	local Rebirth = require(modulo) :: any
	return scope:Barra({
		Nombre = "Progreso",
		Fraccion = Rebirth.progreso,
		Color = scope:Computed(function(use)
			return if use(Rebirth.puede) then Paleta.UI_EXITO else Paleta.CABECERA_PANEL.Rebirth
		end),
		Size = UDim2.new(1, -8, 0, 10),
		Position = UDim2.new(0.5, 0, 1, -20),
		AnchorPoint = Vector2.new(0.5, 1),
		Radio = 5,
	})
end

-- Panel, texto, icono y atajo de cada boton. Solo sale si su panel existe.
local BOTONES = {
	{ panel = "Tienda", texto = Textos.HUD.tienda, icono = "telefono", tecla = "Q" },
	{ panel = "Mascotas", texto = Textos.HUD.mascotas, icono = "libreta", tecla = "J" },
	{ panel = "Rebirth", texto = Textos.HUD.rebirth, icono = "estrella", tecla = "R" },
	{ panel = "Pedidos", texto = Textos.HUD.pedidos, icono = "nota", tecla = "P" },
}

local hijosBotonera: { any } = {
	scope:New("UIScale")({
		Scale = scope:Computed(function(use)
			return if use(tactil) then 0.8 else 1
		end),
	}),
	scope:Rejilla({ Celda = UDim2.fromOffset(LADO_ICONO, LADO_ICONO), Espacio = 10 }),
}
for orden, b in BOTONES do
	if script.Parent:FindFirstChild(b.panel) then
		local extra = if b.panel == "Rebirth" then barraRebirth() else nil
		table.insert(hijosBotonera, botonIcono(b.panel, b.texto, b.icono, b.tecla, orden, function()
			Menu.alternar(b.panel)
		end, extra))
	end
end

local botonera = scope:New("Frame")({
	Name = "Botonera",
	Size = UDim2.fromOffset(LADO_ICONO * 2 + 10, LADO_ICONO * 2 + 10),
	Position = scope:Computed(function(use)
		return if use(tactil) then UDim2.fromOffset(MARGEN, 16) else UDim2.new(0, MARGEN, 0.46, 0)
	end),
	AnchorPoint = scope:Computed(function(use)
		return if use(tactil) then Vector2.zero else Vector2.new(0, 0.5)
	end),
	Visible = sinPanel,
	BackgroundTransparency = 1,
	[Children] = hijosBotonera,
})

-- ===========================================================================
-- Arriba-dcha: contadores
-- ===========================================================================

local ANCHO_CENTRO = 330
-- De las barras verticales de la derecha; aqui porque Contadores se aparta de ellas
local DIAMETRO_BASE = 48
local SEPARACION_BARRAS = 28

-- La mascota que se esta montando mas cerca de completarse, como texto
-- "set|id|n|total" (un primitivo: el perfil llega como tablas nuevas) o ""
local montajeHud = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	local mejor, fraccion = "", -1
	for _, set in DefinicionesMascotas.SETS do
		local m = p and p.fragmentos and p.fragmentos[set.id]
		if m and m.total > 0 and m.n / m.total > fraccion then
			mejor, fraccion = string.format("%s|%s|%d|%d", set.id, m.id, m.n, m.total), m.n / m.total
		end
	end
	return mejor
end)
local function partesMontaje(texto: string): (DefinicionesMascotas.Set?, DefinicionesMascotas.Mascota?, number, number)
	local p = string.split(texto, "|")
	if #p < 4 then
		return nil, nil, 0, 0
	end
	return DefinicionesMascotas.SET_POR_ID[p[1]], DefinicionesMascotas.obtener(p[2]), tonumber(p[3]) or 0, tonumber(p[4]) or 0
end
local ICONO_SET = { Papel = "setPapel", Plastico = "setPlastico", Metal = "setMetal", Organico = "setOrganico" }

local contadores = scope:New("Frame")({
	Name = "Contadores",
	Size = UDim2.fromOffset(ANCHO_CENTRO, 58 + 8 + 30),
	-- Arriba-dcha (decision del usuario). En tactil la pantalla es baja y las
	-- barras verticales llegan hasta arriba: se aparta a su izquierda y encoge
	Position = scope:Computed(function(use)
		return if use(tactil) then UDim2.new(1, -(MARGEN + 2 * (DIAMETRO_BASE + SEPARACION_BARRAS)), 0, MARGEN) else UDim2.new(1, -MARGEN, 0, MARGEN)
	end),
	AnchorPoint = Vector2.new(1, 0),
	BackgroundTransparency = 1,
	[Children] = {
		scope:New("UIScale")({
			Scale = scope:Computed(function(use)
				return if use(tactil) then 0.75 else 1
			end),
		}),
		scope:Pildora({
			Nombre = "Dinero",
			Icono = "billete",
			Texto = dinero,
			Color = Paleta.UI_DINERO,
			Ancho = 250,
			Alto = 58,
			TamanoTexto = 34,
			Position = UDim2.new(1, 0, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
		}),
		-- Fragmentos de la mascota mas cerca de completarse
		scope:Icono({
			Clave = scope:Computed(function(use)
				local set = partesMontaje(use(montajeHud))
				return if set then (ICONO_SET[set.material] or "estrella") else "estrella"
			end),
			Tamano = 34,
			Position = UDim2.new(1, -250, 0, 66),
			ZIndex = 3,
		}),
		scope:Barra({
			Nombre = "Fragmentos",
			Fraccion = scope:Computed(function(use)
				local _, _, n, total = partesMontaje(use(montajeHud))
				return if total > 0 then math.clamp(n / total, 0, 1) else 0
			end),
			Texto = scope:Computed(function(use)
				local _, def, n, total = partesMontaje(use(montajeHud))
				if not def then
					return Textos.MASCOTAS.sinFragmentosHud
				end
				return Textos.formatear(Textos.MASCOTAS.fragmentosHud, { nombre = def.nombre, n = n, total = total })
			end),
			Color = scope:Computed(function(use)
				local set = partesMontaje(use(montajeHud))
				return if set then (Paleta.MATERIAL[set.material] or Paleta.UI_DINERO) else Paleta.UI_DINERO
			end),
			Size = UDim2.fromOffset(214, 26),
			Position = UDim2.new(1, 0, 0, 68),
			AnchorPoint = Vector2.new(1, 0),
			Radio = 13,
			TamanoTexto = 14,
		}),
	},
})

-- ===========================================================================
-- Derecha: barras verticales de fuerza y bolsa
-- ===========================================================================

local ANCHO_BARRA = 32
local ALTO_BARRA = 210

-- columna 0 = pegada al borde derecho, 1 = la siguiente hacia dentro
local function barraVertical(nombre: string, columna: number, props: { Fraccion: any, Color: any, Texto: any, ColorTexto: any?, Visible: any?, Icono: string })
	local desplazamiento = 22 + columna * (DIAMETRO_BASE + SEPARACION_BARRAS)
	return scope:New("Frame")({
		Name = nombre,
		Size = UDim2.fromOffset(ANCHO_BARRA, ALTO_BARRA),
		-- En tactil suben: debajo va la pista de recoger (sobre el boton de salto)
		Position = scope:Computed(function(use)
			return UDim2.new(1, -desplazamiento, 0.5, if use(tactil) then -20 else 30)
		end),
		AnchorPoint = Vector2.new(1, 0.5),
		Visible = props.Visible,
		BackgroundTransparency = 1,
		[Children] = {
			scope:Barra({
				Fraccion = props.Fraccion,
				Color = props.Color,
				Vertical = true,
				Size = UDim2.fromScale(1, 1),
				Radio = math.floor(ANCHO_BARRA / 2),
			}),
			-- Base: circulo con icono que asoma por debajo
			scope:New("Frame")({
				Name = "Base",
				Size = UDim2.fromOffset(DIAMETRO_BASE, DIAMETRO_BASE),
				Position = UDim2.new(0.5, 0, 1, 4),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Paleta.UI_PAPEL,
				ZIndex = 4,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({ Color = Paleta.UI_TINTA, Thickness = Tema.GROSOR }),
					scope:Icono({ Clave = props.Icono, Tamano = math.floor(DIAMETRO_BASE * 0.66), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5 }),
				},
			}),
			-- La etiqueta cuelga hacia dentro de la pantalla: centrada se saldria
			scope:Texto({
				Texto = props.Texto,
				Size = UDim2.fromOffset(160, 22),
				Position = UDim2.new(1, 0, 0, -6),
				AnchorPoint = Vector2.new(1, 1),
				Tamano = 15,
				Fuente = "titulo",
				Alinear = Enum.TextXAlignment.Right,
				Color = props.ColorTexto or Paleta.UI_PAPEL,
				Contorno = Paleta.UI_TINTA,
				ZIndex = 4,
			}),
		},
	})
end

-- Bonus por distancia si acertara desde aqui (5 veces por segundo: la
-- distancia al contenedor cambia al andar, no cada frame)
local bonusAqui = scope:Value(0)
task.spawn(function()
	local CollectionService = game:GetService("CollectionService")
	while true do
		task.wait(0.2)
		local root = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
		local contenedor = CollectionService:GetTagged("Contenedor")[1]
		local zona = contenedor and contenedor:FindFirstChild("ZonaAcierto")
		if root and root:IsA("BasePart") and zona and zona:IsA("BasePart") then
			local d = Vector3.new(zona.Position.X - root.Position.X, 0, zona.Position.Z - root.Position.Z).Magnitude
			bonusAqui:set(DefinicionesPunteria.bonusDistancia(d))
		end
	end
end)

local barraFuerza = barraVertical("Fuerza", 0, {
	Fraccion = reactivo.carga,
	Color = scope:Computed(function(use)
		return if use(reactivo.carga) >= 0.99 then Paleta.UI_PRIMARIO else Paleta.UI_FUERZA
	end),
	Texto = scope:Computed(function(use)
		local b = use(bonusAqui)
		return if b > 0 then Textos.formatear(Textos.HUD.bonusAqui, { pct = math.floor(b * 100 + 0.5) }) else Textos.HUD.fuerza
	end),
	Visible = enPatio,
	Icono = "flecha",
})

local barraBolsa = barraVertical("Bolsa", 1, {
	Fraccion = scope:Computed(function(use)
		local c = use(capacidad)
		return if c > 0 then use(enBolsa) / c else 0
	end),
	Color = scope:Computed(function(use)
		return if use(bolsaLlena) then Paleta.UI_PELIGRO:Lerp(Paleta.UI_PAPEL, use(pulso) * 0.4) else Paleta.UI_BOLSA
	end),
	Texto = scope:Computed(function(use)
		return if use(bolsaLlena) then Textos.HUD.bolsaLlenaBarra else Textos.HUD.bolsa
	end),
	ColorTexto = scope:Computed(function(use)
		return if use(bolsaLlena) then Paleta.UI_PELIGRO else Paleta.UI_PAPEL
	end),
	Icono = "bolsa",
})

-- ===========================================================================
-- Abajo-dcha: pistas
-- ===========================================================================

-- Pastilla [insignia] TEXTO [icono]; el ancho sigue al contenido
local function pista(nombre: string, alto: number, teclado: string, gamepad: Enum.KeyCode, texto: any, icono: string, posicion: any, visible: any)
	return scope:New("Frame")({
		Name = nombre,
		Size = UDim2.fromOffset(0, alto),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = posicion,
		AnchorPoint = Vector2.new(1, 1),
		Visible = visible,
		BackgroundColor3 = Paleta.UI_PAPEL,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			scope:New("UIStroke")({ Color = Paleta.UI_TINTA, Thickness = Tema.GROSOR }),
			scope:Relleno({ X = 12, Y = 0 }),
			scope:Lista({ Espacio = 8, Horizontal = true, AlinearV = Enum.VerticalAlignment.Center }),
			scope:Insignia({ Teclado = teclado, Gamepad = gamepad, Tamano = alto - 16, Orden = 1 }),
			scope:Texto({ Texto = texto, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Tamano = math.floor(alto * 0.42), Fuente = "titulo", Ajustar = false, Orden = 2 }),
			scope:Icono({ Clave = icono, Tamano = alto - 10, Orden = 3 }),
		},
	})
end

local pistaLanzar = pista(
	"PistaLanzar",
	46,
	"F",
	Enum.KeyCode.ButtonY,
	Textos.HUD.mantenerLanzar,
	"lanzar",
	scope:Computed(function(use)
		return if use(tactil) then UDim2.new(1, -MARGEN, 1, -130) else UDim2.new(1, -MARGEN, 1, -MARGEN)
	end),
	-- Solo con la bolsa llena (solo entonces se lanza, ControlPatio); en
	-- tactil lo dice el boton de ControlPatio
	scope:Computed(function(use)
		return use(enBolsa) > 0 and use(bolsaLlena) and use(sinPanel) and use(Escala.plataforma) ~= "tactil"
	end)
)

local pistaRecoger = pista(
	"PistaRecoger",
	38,
	Textos.HUD.clic,
	Enum.KeyCode.ButtonX,
	scope:Computed(function(use)
		return if use(Escala.plataforma) == "tactil" then Textos.HUD.tocarRecoger else Textos.HUD.mantenerRecoger
	end),
	"mano",
	scope:Computed(function(use)
		return if use(tactil) then UDim2.new(1, -MARGEN, 1, -184) else UDim2.new(1, -MARGEN, 1, -MARGEN - 56)
	end),
	-- Solo en el patio y mientras se aprende
	scope:Computed(function(use)
		return use(enPatio) and use(sinPanel) and use(recogidas) < RECOGIDAS_PARA_APRENDER
	end)
)

scope:Pantalla({
	Nombre = "HUD",
	Orden = 1,
	Hijos = { botonera, contadores, barraFuerza, barraBolsa, pistaLanzar, pistaRecoger },
})
