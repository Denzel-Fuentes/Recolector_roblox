--!strict
--[[
	Ajustes (ModuleScript)
	El panelito del boton Sonido del HUD (paquete A1, 22 oct): dos
	interruptores del Kit, Musica y Efectos (perfil.ajustes). Es el panel
	"Ajustes" de Menu (el modulo de sonido ya se llama Sonido) y su titulo
	es el del boton.

	El ajuste lo valida y lo guarda el servidor (AjustesEvent ->
	Services/Ajustes) y vuelve en el perfil: es lo que pintan los
	interruptores y lo que aplica Client/Sonido (los SoundGroups a 0 o 1).
	Para que el interruptor no espere la ida y vuelta, ensena ya lo pedido
	(`pendiente`) hasta que el perfil lo confirma o pasan ESPERA_CONFIRMAR s
	desde el envio: si el servidor lo rechazo, vuelve a lo que diga el
	perfil. Los cambios seguidos se juntan en un solo envio, como mucho uno
	cada ESPACIO_ENVIOS: el doble del cooldown del servidor
	(GameConfig.COOLDOWN_AJUSTES), que ignora los que llegan antes; el margen
	cubre que un paquete llegue mas tarde que el siguiente. Asi dos toques
	rapidos no pierden el segundo.

	Solo presentacion: deriva primitivos del perfil (un booleano por ajuste)
	y manda intencion.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(Shared:WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Navegacion = require(script.Parent:WaitForChild("Kit"):WaitForChild("Navegacion"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local Children = Fusion.Children
local peek = Fusion.peek

local AjustesEvent = Red.evento("AjustesEvent")

local NOMBRE = "Ajustes"
-- s que se ensena lo pedido sin que el perfil lo confirme
local ESPERA_CONFIRMAR = 2
-- Entre dos envios (ver cabecera)
local ESPACIO_ENVIOS = GameConfig.COOLDOWN_AJUSTES * 2
local CLAVES = { "musica", "efectos" }

local scope = Fusion.scoped(Fusion, Kit)
local reactivo = EstadoCliente.reactivo

-- Lo que dice el perfil (encendido salvo que diga false), lo pedido y lo
-- que se ensena, por ajuste
local servidor: { [string]: any } = {}
local pendiente: { [string]: any } = {}
local mostrado: { [string]: any } = {}
for _, clave in CLAVES do
	servidor[clave] = scope:Computed(function(use)
		local p = use(reactivo.perfil)
		local ajustes = if p then p.ajustes else nil
		return not (typeof(ajustes) == "table" and ajustes[clave] == false)
	end)
	pendiente[clave] = scope:Value(nil :: boolean?)
	mostrado[clave] = scope:Computed(function(use)
		local pedido = use(pendiente[clave])
		if pedido ~= nil then
			return pedido
		end
		return use(servidor[clave])
	end)
	-- El perfil ya dice lo pedido: fuera el pendiente
	scope:Observer(servidor[clave]):onChange(function()
		if peek(pendiente[clave]) == peek(servidor[clave]) then
			pendiente[clave]:set(nil)
		end
	end)
end

-- ===========================================================================
-- Envio
-- ===========================================================================

local ultimoEnvio = -math.huge
local envioEnCola = false

local function enviar()
	if envioEnCola then
		return
	end
	envioEnCola = true
	local espera = math.max(0, ultimoEnvio + ESPACIO_ENVIOS - os.clock())
	task.delay(espera, function()
		envioEnCola = false
		ultimoEnvio = os.clock()
		local marca = ultimoEnvio
		AjustesEvent:FireServer({ musica = peek(mostrado.musica) == true, efectos = peek(mostrado.efectos) == true })
		-- Sin confirmacion (rechazado), se vuelve a lo que diga el perfil;
		-- no si mientras tanto se pidio otra cosa (otro envio, hecho o en cola)
		task.delay(ESPERA_CONFIRMAR, function()
			if ultimoEnvio == marca and not envioEnCola then
				for _, clave in CLAVES do
					pendiente[clave]:set(nil)
				end
			end
		end)
	end)
end

local function cambiar(clave: string, valor: boolean)
	pendiente[clave]:set(valor)
	enviar()
end

-- ===========================================================================
-- Panel
-- ===========================================================================

local function fila(orden: number, clave: string, icono: string, titulo: string)
	return scope:Tarjeta({
		Nombre = "Ajuste_" .. clave,
		Orden = orden,
		Size = UDim2.new(1, 0, 0, 84),
		Hijos = {
			scope:Icono({ Clave = icono, Tamano = 52, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) }),
			scope:Texto({
				Texto = titulo,
				Size = UDim2.new(1, -170, 0, 28),
				Position = UDim2.fromOffset(64, 6),
				Tamano = 20,
				Fuente = "titulo",
			}),
			scope:Texto({
				Nombre = "Estado",
				Texto = scope:Computed(function(use)
					return if use(mostrado[clave]) then Textos.SONIDO.activado else Textos.SONIDO.desactivado
				end),
				Color = scope:Computed(function(use)
					return if use(mostrado[clave]) then Paleta.UI_TINTA else Paleta.UI_TINTA_SUAVE
				end),
				Size = UDim2.new(1, -170, 0, 22),
				Position = UDim2.fromOffset(64, 36),
				Tamano = 15,
				Fuente = "negrita",
			}),
			scope:Interruptor({
				Nombre = "Interruptor_" .. clave,
				Activado = mostrado[clave],
				alCambiar = function(valor: boolean)
					cambiar(clave, valor)
				end,
				Position = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
			}),
		},
	})
end

local contenido = scope:New("Frame")({
	Name = "Columna",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	[Children] = {
		scope:Lista({ Espacio = 10, Alinear = Enum.HorizontalAlignment.Center }),
		fila(1, "musica", "nota", Textos.SONIDO.musica),
		fila(2, "efectos", "sonido", Textos.SONIDO.efectos),
	},
})

scope:Ventana({
	Nombre = NOMBRE,
	Titulo = Textos.SONIDO.boton,
	Ancho = 460,
	Alto = 270,
	Abierta = scope:Computed(function(use)
		return use(Menu.abiertoR) == NOMBRE
	end),
	alCerrar = Menu.cerrarTodo,
	Hijos = { contenido },
})

Menu.registrar(NOMBRE, {
	abrir = function() end,
	primerSeleccionable = function()
		return Navegacion.primerSeleccionable(contenido)
	end,
})

return {}
