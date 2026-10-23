--!strict
--[[
	Recompensas (ModuleScript)
	El panel del boton del regalo del HUD (paquete R1, 22 oct, economia v4;
	docs/Economia-v4.md §4). Sustituye al stub de C3. Dos pestanas:

	  Calendario   las 7 casillas, una por dia jugado: las cobradas de esta
	               semana (verdes, con su marca), la de hoy (amarilla) con el
	               boton Reclamar debajo y las que vienen. La 7 va en grande
	               con lo que trae: la primera vez, la Bolsa de carton (la
	               regala la insignia Constante); desde la 2.a vuelta, Turbo.
	               Debajo, que saltarse un dia no pierde nada.
	  Regalos      los 6 tramos de minutos activos de hoy, cada uno con su
	               barra (minutos de hoy / los del tramo) y lo que da. Se dan
	               solos (Services/Recompensas): aqui solo se ve como vas.

	Y la ventana del bono de regreso ("Regreso"), que pide el servidor al
	entrar (RecompensaEvent "regreso", con el texto ya como Idioma.mensaje).
	Es un panel de Menu, como los demas: abierta suelta el raton en primera
	persona (Camara.client) y Esc o la X la cierran.

	=== Contrato con el HUD ===
	`indicador` (estado de Fusion) enciende el punto rojo del boton mientras
	haya algo que reclamar con un boton: la casilla de hoy
	(DefinicionesRecompensas.hayAlgo; los regalos y el regreso se dan solos).
	El HUD hace require de este modulo al montarse, asi que en el nivel
	superior no cede nada: lo que espera (el primer perfil, el reloj) va en
	task.spawn.

	=== Al entrar ===
	Una vez por sesion, ESPERA_ENTRADA s despues del primer perfil (para que
	se haya ido la pantalla de carga), sin pisar otro panel: la ventana del
	regreso si llego, y al cerrarla el panel si hay algo que reclamar; si no
	hubo regreso, el panel directamente. Lo que tiene que haber para que se
	abra solo lo dice hayAlgo: las recompensas abiertas (paso 5 del tutorial,
	como los pedidos) y la casilla de hoy sin cobrar. Una ventana del regreso
	que llegue con otro panel abierto espera a que se cierre.

	=== Por que asi ===
	- Solo presentacion: deriva primitivos de EstadoCliente.reactivo (el
	  perfil llega varias veces por segundo como tablas nuevas) y monta las
	  tarjetas una vez, sobre las definiciones de Config. Los premios se
	  calculan con las mismas funciones que el servidor: el panel ensena lo
	  que se va a cobrar.
	- El dia es el del servidor (DefinicionesPedidos.dia de
	  GetServerTimeNow), con un reloj de pocos segundos: al cambiar el dia
	  (06:00 UTC) la casilla nueva se enciende sola.
	- Al pulsar Reclamar el boton espera (`pidiendo`) a que el perfil
	  confirme o pasen ESPERA_CONFIRMAR s: dos toques no mandan dos
	  peticiones, y si el servidor la rechazo se puede volver a pedir. El
	  servidor la cobra una vez al dia pida lo que pida el cliente.

	Pruebas por PruebasCliente ("modulo", "Recompensas", accion):
	  indicador(true | false | "auto")  fuerza el punto rojo del HUD (para
	                                    capturas) o lo devuelve al perfil
	  regreso(dias?)                    la ventana del regreso con el premio
	                                    de esos dias (3 por defecto)
	  estado()                          lo que ve el panel
	Y ("abrir", "Recompensas", "regalos") abre la pestana de regalos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local DefinicionesRecompensas = require(Config:WaitForChild("DefinicionesRecompensas"))
local DefinicionesPedidos = require(Config:WaitForChild("DefinicionesPedidos"))
local DefinicionesCosmeticos = require(Config:WaitForChild("DefinicionesCosmeticos"))
local Utilidades = Shared:WaitForChild("Utilidades")
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(Utilidades:WaitForChild("Idioma"))
local Textos = Idioma.textos
local Formato = require(Utilidades:WaitForChild("Formato"))
local Red = require(Utilidades:WaitForChild("Red"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Sonido = require(Cliente:WaitForChild("Sonido"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Escala = require(script.Parent:WaitForChild("Kit"):WaitForChild("Escala"))
local Navegacion = require(script.Parent:WaitForChild("Kit"):WaitForChild("Navegacion"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local Children = Fusion.Children
local peek = Fusion.peek

type Premio = DefinicionesRecompensas.Premio

local RecompensaEvent = Red.evento("RecompensaEvent")

local NOMBRE = "Recompensas"
local NOMBRE_REGRESO = "Regreso"
local CALENDARIO = DefinicionesRecompensas.CALENDARIO
local REGALOS = DefinicionesRecompensas.REGALOS
local SIETE = #CALENDARIO

-- s tras el primer perfil para abrirse solo (ver cabecera)
local ESPERA_ENTRADA = 5
-- s que el boton Reclamar espera a que el perfil confirme
local ESPERA_CONFIRMAR = 3
-- Cada cuanto se mira si cambio el dia del servidor
local RELOJ_DIA = 5

-- La barra de titulo: el rosa del kit (ni el rojo de la Tienda ni el
-- naranja de Pedidos)
local COLOR_CABECERA = Paleta.UI_KIT[5]
-- Lo cobrado: el verde claro de los pedidos hechos (UI/Pedidos); la 7 que
-- no es hoy, el dorado claro de las insignias conseguidas
local COLOR_COBRADA = Color3.fromRGB(215, 245, 215)
local COLOR_SIETE = Color3.fromRGB(255, 236, 170)

-- La Bolsa de carton: la que regala la insignia de la casilla 7
local CARTON: DefinicionesCosmeticos.Diseno? = nil
for _, diseno in DefinicionesCosmeticos.BOLSAS do
	if diseno.insignia == DefinicionesRecompensas.INSIGNIA_SEMANA then
		CARTON = diseno
	end
end

local scope = Fusion.scoped(Fusion, Kit)
local reactivo = EstadoCliente.reactivo
local pestana = scope:Value(1)

-- ===========================================================================
-- Estado: primitivos del perfil y el dia del servidor
-- ===========================================================================

local function diaServidor(): number
	return DefinicionesPedidos.dia(workspace:GetServerTimeNow())
end
local hoy = scope:Value(diaServidor())
task.spawn(function()
	while true do
		task.wait(RELOJ_DIA)
		hoy:set(diaServidor())
	end
end)

local function estadoDe(p: any): any
	return if p ~= nil and typeof(p.recompensas) == "table" then p.recompensas else nil
end

local abiertas = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	return p ~= nil and DefinicionesRecompensas.abiertas(p.tutorial)
end)
local rebirths = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	return if p then (tonumber(p.rebirths) or 0) else 0
end)
-- La casilla por cobrar (1..7) y las vueltas completas
local siguiente = scope:Computed(function(use)
	local e = estadoDe(use(reactivo.perfil))
	return if e and typeof(e.calendario) == "table" then DefinicionesRecompensas.casillaActual(e.calendario) else 1
end)
local vueltas = scope:Computed(function(use)
	local e = estadoDe(use(reactivo.perfil))
	return if e and typeof(e.calendario) == "table" then math.max(0, math.floor(tonumber(e.calendario.vueltas) or 0)) else 0
end)
-- La casilla de hoy sin cobrar
local disponible = scope:Computed(function(use)
	local e = estadoDe(use(reactivo.perfil))
	return e ~= nil and typeof(e.calendario) == "table" and DefinicionesRecompensas.diariaDisponible(e.calendario, use(hoy))
end)
local tieneInsigniaSemana = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	return p ~= nil and typeof(p.logros) == "table" and p.logros[DefinicionesRecompensas.INSIGNIA_SEMANA] == true
end)
-- Minutos activos de hoy y tramos ya dados hoy
local minutosHoy = scope:Computed(function(use)
	local e = estadoDe(use(reactivo.perfil))
	if not (e and typeof(e.regalos) == "table") then
		return 0
	end
	local minutos = DefinicionesRecompensas.regalosDeHoy(e.regalos, use(hoy))
	return minutos
end)
local cobradosHoy = scope:Computed(function(use)
	local e = estadoDe(use(reactivo.perfil))
	if not (e and typeof(e.regalos) == "table") then
		return 0
	end
	local _, cobrados = DefinicionesRecompensas.regalosDeHoy(e.regalos, use(hoy))
	return cobrados
end)

-- Pulsado Reclamar y sin confirmar aun (ver cabecera)
local pidiendo = scope:Value(false)

local hayAlgo = scope:Computed(function(use)
	return use(abiertas) and use(disponible) and not use(pidiendo)
end)

-- El punto rojo del HUD: lo que diga el perfil, o lo forzado en una prueba
local forzado = scope:Value(nil :: boolean?)
local indicador = scope:Computed(function(use)
	local f = use(forzado)
	if f ~= nil then
		return f
	end
	return use(hayAlgo)
end)

-- ===========================================================================
-- Textos de los premios (los mismos que manda el servidor en sus avisos)
-- ===========================================================================

-- "$1.000", "Turbo 10 min" o "$2.000 y Turbo 15 min"
local function textoPremio(premio: Premio): string
	local dinero = if premio.dinero > 0 then Formato.dinero(premio.dinero) else nil
	local turbo = if premio.turbo > 0 then Textos.formatear(Textos.RECOMPENSAS.premioTurbo, { minutos = premio.turbo }) else nil
	if dinero and turbo then
		return Textos.formatear(Textos.RECOMPENSAS.premioY, { a = dinero, b = turbo })
	end
	return dinero or turbo or ""
end

-- Corto, para las tarjetas pequenas: "$1.000" o "10 min" (el rayo del icono
-- ya dice que es Turbo)
local function textoCorto(premio: Premio): string
	if premio.dinero > 0 then
		return Formato.dinero(premio.dinero)
	end
	return Textos.formatear(Textos.RECOMPENSAS.tramo, { n = premio.turbo })
end

local function iconoPremio(premio: Premio): string
	return if premio.dinero > 0 then "billete" else "rayo"
end

-- ===========================================================================
-- Pestana 1: el calendario
-- ===========================================================================

-- "cobrada" (esta semana), "hoy" (por cobrar hoy), "proxima" (la que toca
-- cuando cambie el dia o se abran) o "futura"
local function estadoCasilla(i: number)
	return scope:Computed(function(use)
		local s = use(siguiente)
		if i < s then
			return "cobrada"
		elseif i == s then
			return if use(abiertas) and use(disponible) then "hoy" else "proxima"
		end
		return "futura"
	end)
end

local function tituloDia(i: number, tamano: number, alinear: Enum.TextXAlignment?)
	return scope:Texto({
		Nombre = "Dia",
		Texto = Textos.formatear(Textos.RECOMPENSAS.dia, { n = i }),
		Mayusculas = true,
		Size = UDim2.new(1, -26, 0, tamano + 6),
		Tamano = tamano,
		Fuente = "titulo",
		Alinear = alinear,
	})
end

-- Casillas 1..6: titulo, icono y premio corto; marca si esta cobrada
local function tarjetaCasilla(i: number)
	local estado = estadoCasilla(i)
	local premio = scope:Computed(function(use)
		return DefinicionesRecompensas.premioCasilla(i, use(vueltas), use(rebirths))
	end)
	return scope:Tarjeta({
		Nombre = "Casilla" .. i,
		Orden = i,
		Relleno = 8,
		Color = scope:Computed(function(use)
			local e = use(estado)
			return if e == "cobrada" then COLOR_COBRADA elseif e == "hoy" then Paleta.UI_PRIMARIO else Paleta.UI_PAPEL_OSCURO
		end),
		Hijos = {
			tituloDia(i, 15),
			scope:Icono({
				Nombre = "Cobrada",
				Clave = "check",
				Tamano = 24,
				Position = UDim2.new(1, 2, 0, -2),
				AnchorPoint = Vector2.new(1, 0),
				Visible = scope:Computed(function(use)
					return use(estado) == "cobrada"
				end),
			}),
			scope:Icono({
				Clave = scope:Computed(function(use)
					return iconoPremio(use(premio))
				end),
				Tamano = 34,
				Position = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(0, 1),
			}),
			scope:Texto({
				Nombre = "Premio",
				Texto = scope:Computed(function(use)
					return textoCorto(use(premio))
				end),
				Size = UDim2.new(1, -40, 0, 36),
				Position = UDim2.new(0, 40, 1, 0),
				AnchorPoint = Vector2.new(0, 1),
				Tamano = 17,
				Fuente = "titulo",
				Color = scope:Computed(function(use)
					return if use(estado) == "futura" then Paleta.UI_TINTA_SUAVE else Paleta.UI_TINTA
				end),
			}),
		},
	})
end

-- La casilla 7, en grande: lo que da y, la primera vez, la Bolsa de carton
local function tarjetaSiete()
	local estado = estadoCasilla(SIETE)
	-- La primera vuelta trae la bolsa (si aun no tiene la insignia)
	local conBolsa = scope:Computed(function(use)
		return CARTON ~= nil and use(vueltas) == 0 and not use(tieneInsigniaSemana)
	end)
	local texto = scope:Computed(function(use)
		local premio = textoPremio(DefinicionesRecompensas.premioCasilla(SIETE, use(vueltas), use(rebirths)))
		if use(conBolsa) and CARTON then
			return Textos.formatear(Textos.RECOMPENSAS.premioY, { a = premio, b = Idioma.nombre("Bolsas", CARTON) })
		end
		return premio
	end)
	return scope:Tarjeta({
		Nombre = "Casilla" .. SIETE,
		Relleno = 10,
		Size = UDim2.new(0.36, -6, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Color = scope:Computed(function(use)
			return if use(estado) == "hoy" then Paleta.UI_PRIMARIO else COLOR_SIETE
		end),
		Hijos = {
			scope:Texto({
				Nombre = "Dia",
				Texto = Textos.formatear(Textos.RECOMPENSAS.dia, { n = SIETE }),
				Mayusculas = true,
				Size = UDim2.new(1, 0, 0, 24),
				Tamano = 20,
				Fuente = "titulo",
				Alinear = Enum.TextXAlignment.Center,
			}),
			scope:Icono({
				Clave = "regalo",
				Tamano = 64,
				Position = UDim2.new(0.5, 0, 0, 28),
				AnchorPoint = Vector2.new(0.5, 0),
			}),
			scope:Icono({
				Nombre = "Bolsa",
				Clave = "bolsa",
				Tamano = 30,
				Position = UDim2.new(0.5, 44, 0, 62),
				AnchorPoint = Vector2.new(0.5, 0),
				Visible = conBolsa,
			}),
			scope:Texto({
				Nombre = "Premio",
				Texto = texto,
				Size = UDim2.new(1, 0, 0, 50),
				Position = UDim2.fromScale(0.5, 1),
				AnchorPoint = Vector2.new(0.5, 1),
				Tamano = 17,
				Fuente = "titulo",
				Alinear = Enum.TextXAlignment.Center,
				AlinearY = Enum.TextYAlignment.Bottom,
			}),
		},
	})
end

local function reclamar()
	if peek(pidiendo) or not (peek(abiertas) and peek(disponible)) then
		return
	end
	pidiendo:set(true)
	RecompensaEvent:FireServer("diaria")
	task.delay(ESPERA_CONFIRMAR, function()
		pidiendo:set(false)
	end)
end

local function paginaCalendario()
	local pequenas: { any } = {
		scope:Rejilla({ Celda = UDim2.new(1 / 3, -6, 0.5, -4), Espacio = 8 }),
	}
	for i = 1, SIETE - 1 do
		table.insert(pequenas, tarjetaCasilla(i))
	end
	return {
		scope:Texto({
			Nombre = "Semana",
			Texto = scope:Computed(function(use)
				return Textos.formatear(Textos.RECOMPENSAS.semana, { n = use(vueltas) + 1 })
			end),
			Mayusculas = true,
			Size = UDim2.new(1, 0, 0, 22),
			Tamano = 16,
			Fuente = "titulo",
			Color = Paleta.UI_TINTA_SUAVE,
			Orden = 1,
		}),
		scope:New("Frame")({
			Name = "Calendario",
			LayoutOrder = 2,
			-- En un telefono apaisado mas bajo: el boton tiene que verse sin bajar
			Size = scope:Computed(function(use)
				return UDim2.new(1, 0, 0, if use(Escala.compacto) then 168 else 204)
			end),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("Frame")({
					Name = "Semana",
					Size = UDim2.new(0.64, -6, 1, 0),
					BackgroundTransparency = 1,
					[Children] = pequenas,
				}),
				tarjetaSiete(),
			},
		}),
		scope:Texto({
			Nombre = "Estado",
			Texto = scope:Computed(function(use)
				if not use(abiertas) then
					return Textos.RECOMPENSAS.cerradas
				elseif use(disponible) then
					return Textos.RECOMPENSAS.listo
				end
				return Textos.formatear(Textos.RECOMPENSAS.vuelveManana, { n = use(siguiente) })
			end),
			Size = UDim2.new(1, 0, 0, 28),
			Tamano = 20,
			Fuente = "titulo",
			Alinear = Enum.TextXAlignment.Center,
			Orden = 3,
		}),
		scope:Boton({
			Nombre = "Reclamar",
			Texto = scope:Computed(function(use)
				return if use(disponible) then Textos.RECOMPENSAS.reclamar else Textos.RECOMPENSAS.reclamado
			end),
			Tamano = 24,
			Color = Paleta.UI_EXITO,
			Deshabilitado = scope:Computed(function(use)
				return not (use(abiertas) and use(disponible)) or use(pidiendo)
			end),
			Visible = abiertas,
			alPulsar = reclamar,
			Size = UDim2.fromOffset(280, 58),
			Orden = 4,
		}),
		scope:Texto({
			Nombre = "SinPrisa",
			Texto = Textos.RECOMPENSAS.sinPrisa,
			Size = UDim2.new(1, 0, 0, 36),
			Tamano = 14,
			Color = Paleta.UI_TINTA_SUAVE,
			Alinear = Enum.TextXAlignment.Center,
			Orden = 5,
		}),
	}
end

-- ===========================================================================
-- Pestana 2: los regalos por minutos activos
-- ===========================================================================

local function filaRegalo(i: number)
	local tramo = REGALOS[i]
	-- "dado", "alcanzado" (llego a los minutos con las recompensas cerradas)
	-- o "pendiente"
	local estado = scope:Computed(function(use)
		if use(cobradosHoy) >= i then
			return "dado"
		elseif use(minutosHoy) >= tramo.minutos then
			return "alcanzado"
		end
		return "pendiente"
	end)
	local premio = scope:Computed(function(use)
		return DefinicionesRecompensas.premio(tramo, use(rebirths))
	end)
	-- 44 de alto: las 6 caben en la pagina de PC (432) sin bajar
	return scope:Tarjeta({
		Nombre = "Regalo" .. tramo.minutos,
		Orden = 10 + i,
		Size = UDim2.new(1, 0, 0, 44),
		Relleno = 10,
		RellenoY = 4,
		Color = scope:Computed(function(use)
			return if use(estado) == "dado" then COLOR_COBRADA else Paleta.UI_PAPEL_OSCURO
		end),
		Hijos = {
			scope:Texto({
				Nombre = "Tramo",
				Texto = Textos.formatear(Textos.RECOMPENSAS.tramo, { n = tramo.minutos }),
				Size = UDim2.new(0, 72, 1, 0),
				Tamano = 18,
				Fuente = "titulo",
			}),
			scope:Barra({
				Fraccion = scope:Computed(function(use)
					return math.min(use(minutosHoy) / tramo.minutos, 1)
				end),
				Texto = scope:Computed(function(use)
					if use(estado) == "dado" then
						return Textos.RECOMPENSAS.reclamado
					end
					return string.format("%d/%d", math.min(use(minutosHoy), tramo.minutos), tramo.minutos)
				end),
				Color = scope:Computed(function(use)
					local e = use(estado)
					return if e == "dado" then Paleta.UI_EXITO elseif e == "alcanzado" then Paleta.UI_PRIMARIO else Paleta.UI_CARTAS
				end),
				Size = UDim2.new(1, -250, 0, 24),
				Position = UDim2.new(0, 80, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Radio = 12,
			}),
			scope:Icono({
				Nombre = "Dado",
				Clave = "check",
				Tamano = 26,
				Position = UDim2.new(1, -134, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Visible = scope:Computed(function(use)
					return use(estado) == "dado"
				end),
			}),
			scope:Pildora({
				Nombre = "Premio",
				Icono = if tramo.turbo then "rayo" else "billete",
				Texto = scope:Computed(function(use)
					return textoCorto(use(premio))
				end),
				Color = if tramo.turbo then Paleta.UI_ENERGIA else Paleta.UI_DINERO,
				Ancho = 124,
				Alto = 36,
				TamanoTexto = 17,
				Position = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
			}),
		},
	})
end

local function paginaRegalos()
	local hijos: { any } = {
		scope:Texto({
			Nombre = "MinutosHoy",
			Texto = scope:Computed(function(use)
				return Textos.formatear(Textos.RECOMPENSAS.minutosHoy, { n = use(minutosHoy) })
			end),
			Size = UDim2.new(1, 0, 0, 28),
			Tamano = 20,
			Fuente = "titulo",
			Alinear = Enum.TextXAlignment.Center,
			Orden = 1,
		}),
		scope:Texto({
			Nombre = "Siguiente",
			Texto = scope:Computed(function(use)
				if not use(abiertas) then
					return Textos.RECOMPENSAS.cerradas
				end
				local tramo = DefinicionesRecompensas.siguienteRegalo(use(minutosHoy))
				return if tramo then Textos.formatear(Textos.RECOMPENSAS.siguiente, { n = tramo.minutos }) else Textos.RECOMPENSAS.todos
			end),
			Size = UDim2.new(1, 0, 0, 24),
			Tamano = 16,
			Fuente = "negrita",
			Color = Paleta.UI_TINTA_SUAVE,
			Alinear = Enum.TextXAlignment.Center,
			Orden = 2,
		}),
		-- Arriba y no al pie: es lo que explica como se ganan
		scope:Texto({
			Nombre = "SoloActivo",
			Texto = Textos.RECOMPENSAS.soloActivo,
			Size = UDim2.new(1, 0, 0, 30),
			Tamano = 14,
			Color = Paleta.UI_TINTA_SUAVE,
			Alinear = Enum.TextXAlignment.Center,
			Orden = 3,
		}),
	}
	for i = 1, #REGALOS do
		table.insert(hijos, filaRegalo(i))
	end
	return hijos
end

-- ===========================================================================
-- Ventana del panel
-- ===========================================================================

local PAGINAS = { paginaCalendario, paginaRegalos }
local paginas = {}
for i, pintar in PAGINAS do
	paginas[i] = scope:Scroll({
		Nombre = "Pagina" .. i,
		Espacio = 8,
		Relleno = 4,
		Size = UDim2.new(1, 0, 1, -48),
		Position = UDim2.fromOffset(0, 48),
		Visible = scope:Computed(function(use)
			return use(pestana) == i
		end),
		Hijos = pintar(),
	})
end

scope:Ventana({
	Nombre = NOMBRE,
	Titulo = Textos.RECOMPENSAS.titulo,
	Ancho = 720,
	Alto = 560,
	Color = COLOR_CABECERA,
	Abierta = scope:Computed(function(use)
		return use(Menu.abiertoR) == NOMBRE
	end),
	alCerrar = Menu.cerrarTodo,
	Hijos = {
		scope:Pestanas({
			Nombres = { Textos.RECOMPENSAS.calendario, Textos.RECOMPENSAS.regalos },
			Seleccion = pestana,
		}),
		paginas,
	},
})

Menu.registrar(NOMBRE, {
	abrir = function(argumento)
		pestana:set(if argumento == "regalos" or argumento == 2 then 2 else 1)
	end,
	primerSeleccionable = function()
		return Navegacion.primerSeleccionable(paginas[peek(pestana)])
	end,
})

-- ===========================================================================
-- Ventana del regreso
-- ===========================================================================

local textoRegreso = scope:Value("")

local cuerpoRegreso = scope:New("Frame")({
	Name = "Bienvenida",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	[Children] = {
		scope:Icono({
			Clave = "regalo",
			Tamano = 96,
			Position = UDim2.new(0.5, 0, 0, 4),
			AnchorPoint = Vector2.new(0.5, 0),
		}),
		scope:Texto({
			Nombre = "Premio",
			Texto = textoRegreso,
			Size = UDim2.new(1, -20, 0, 64),
			Position = UDim2.new(0.5, 0, 0, 108),
			AnchorPoint = Vector2.new(0.5, 0),
			Tamano = 22,
			Fuente = "titulo",
			Alinear = Enum.TextXAlignment.Center,
		}),
		scope:Boton({
			Nombre = "Genial",
			Texto = Textos.RECOMPENSAS.genial,
			Tamano = 22,
			Color = Paleta.UI_EXITO,
			alPulsar = Menu.cerrarTodo,
			Size = UDim2.fromOffset(220, 56),
			Position = UDim2.new(0.5, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 1),
		}),
	},
})

scope:Ventana({
	Nombre = NOMBRE_REGRESO,
	Titulo = Textos.RECOMPENSAS.regresoTitulo,
	Ancho = 520,
	Alto = 340,
	Color = COLOR_CABECERA,
	Abierta = scope:Computed(function(use)
		return use(Menu.abiertoR) == NOMBRE_REGRESO
	end),
	alCerrar = Menu.cerrarTodo,
	Hijos = { cuerpoRegreso },
})

Menu.registrar(NOMBRE_REGRESO, {
	abrir = function() end,
	primerSeleccionable = function()
		return Navegacion.primerSeleccionable(cuerpoRegreso)
	end,
})

-- ===========================================================================
-- Al entrar, el regreso y lo que manda el servidor
-- ===========================================================================

local listoParaAbrir = false -- paso ESPERA_ENTRADA tras el primer perfil
local regresoEsperando = false -- llego la ventana del regreso y no se ha visto

-- La ventana del regreso, si llego, ya se puede y no hay otro panel
local function intentarRegreso()
	if regresoEsperando and listoParaAbrir and Menu.abierto() == nil then
		regresoEsperando = false
		Menu.abrir(NOMBRE_REGRESO)
	end
end

-- El panel, si hay algo que reclamar y no hay otro abierto
local function abrirSiHayAlgo()
	if peek(hayAlgo) and Menu.abierto() == nil then
		Menu.abrir(NOMBRE)
	end
end

do
	local anterior: string? = Menu.abierto()
	Menu.alCambiar:Connect(function(nombre: string?)
		local antes = anterior
		anterior = nombre
		if nombre ~= nil then
			return
		end
		-- (despues de que acabe de cerrarse el que se cerro)
		task.defer(function()
			if antes == NOMBRE_REGRESO then
				abrirSiHayAlgo()
			else
				intentarRegreso()
			end
		end)
	end)
end

RecompensaEvent.OnClientEvent:Connect(function(accion: any, datos: any)
	if accion == "regreso" and typeof(datos) == "table" then
		local texto = Idioma.resolver(datos.texto)
		if texto ~= "" then
			textoRegreso:set(texto)
			regresoEsperando = true
			intentarRegreso()
		end
	elseif accion == "premio" then
		Sonido.tocar("regalo")
	end
end)

task.spawn(function()
	EstadoCliente.esperar()
	task.wait(ESPERA_ENTRADA)
	listoParaAbrir = true
	if regresoEsperando then
		intentarRegreso()
	else
		abrirSiHayAlgo()
	end
end)

-- ===========================================================================
-- Pruebas (PruebasCliente: "modulo", "Recompensas", accion)
-- ===========================================================================

local prueba = {}

-- true | false: fuerza el punto rojo del boton del HUD; "auto" (o nada) lo
-- devuelve a lo que diga el perfil
function prueba.indicador(valor: any): string
	if valor == nil or valor == "" or valor == "auto" then
		forzado:set(nil)
	else
		forzado:set(valor == true or valor == "true")
	end
	return "indicador=" .. tostring(peek(indicador))
end

-- La ventana del regreso con el premio que tocaria tras `dias` sin jugar
function prueba.regreso(dias: any): string
	local bono = DefinicionesRecompensas.regreso(tonumber(dias) or 3) or DefinicionesRecompensas.REGRESO[#DefinicionesRecompensas.REGRESO]
	local premio = DefinicionesRecompensas.premio(bono, peek(rebirths))
	textoRegreso:set(Textos.formatear(Textos.RECOMPENSAS.regresoTexto, { premio = textoPremio(premio) }))
	Menu.abrir(NOMBRE_REGRESO)
	return "regreso tras " .. bono.dias .. " dias: " .. peek(textoRegreso)
end

function prueba.estado(): string
	return string.format(
		"abiertas=%s hoy=%d casilla=%d vuelta=%d disponible=%s pidiendo=%s | regalos de hoy: %d min, %d tramos | indicador=%s (forzado %s) | panel=%s pestana=%d",
		tostring(peek(abiertas)), peek(hoy), peek(siguiente), peek(vueltas) + 1, tostring(peek(disponible)), tostring(peek(pidiendo)),
		peek(minutosHoy), peek(cobradosHoy), tostring(peek(indicador)), tostring(peek(forzado)), tostring(Menu.abierto()), peek(pestana)
	)
end

return {
	indicador = indicador,
	prueba = prueba,
}
