--!strict
--[[
	Revelacion (ModuleScript)
	La mascota que se acaba de completar con fragmentos (29 sep, sustituye a
	la ventana de la capsula): el servidor manda el resultado por
	RevelacionEvent (MascotasHandler) y aqui se ensena. Primero el fragmento
	del color de su set, que crece; despues la mascota con su nombre, su
	rareza y lo que ha pasado ("¡Nueva!", "Sube a nivel 3" o, ya al maximo,
	"+$400"). Las probabilidades de la rareza se ven en el album, que es
	donde se decide la siguiente (al llegar su primer fragmento).

	Es un panel de Menu ("Revelacion"): asi el raton queda libre en primera
	persona para pulsar "¡Genial!". Si llegan varias a la vez (una bolsa con
	varios fragmentos puede completar dos), se ensenan en cola.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local Utilidades = Shared:WaitForChild("Utilidades")
local ModelosMascota = require(Utilidades:WaitForChild("ModelosMascota"))
local ModelosObjetos = require(Utilidades:WaitForChild("ModelosObjetos"))
local Formato = require(Utilidades:WaitForChild("Formato"))
local Red = require(Utilidades:WaitForChild("Red"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local Encuadre = require(script.Parent:WaitForChild("Kit"):WaitForChild("Encuadre"))
local Navegacion = require(script.Parent:WaitForChild("Kit"):WaitForChild("Navegacion"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local peek = Fusion.peek

local RevelacionEvent = Red.evento("RevelacionEvent")

local NOMBRE = "Revelacion"
local scope = Fusion.scoped(Fusion, Kit)

type Completa = {
	set: string,
	rareza: string,
	id: string,
	nueva: boolean,
	nivel: number,
	dinero: number,
}

local cola: { Completa } = {}
local actual = scope:Value(nil :: Completa?)
local revelada = scope:Value(false)

-- ===========================================================================
-- Contenido
-- ===========================================================================

local vista = scope:Viewport({ Nombre = "Vista", Size = UDim2.new(1, 0, 0, 230), Color = Paleta.UI_PAPEL, Orden = 1 })
local escalaVista = scope:Spring(
	scope:Computed(function(use)
		return if use(revelada) then 1 else 0.85
	end),
	30,
	0.45
)

local def = scope:Computed(function(use)
	local c = use(actual)
	return if c then DefinicionesMascotas.obtener(c.id) else nil
end)

local function textoResultado(c: Completa): string
	if c.dinero > 0 then
		return Textos.formatear(Textos.REVELACION.convertida, { dinero = Formato.dinero(c.dinero) })
	elseif c.nueva then
		return Textos.REVELACION.nueva
	end
	return Textos.formatear(Textos.REVELACION.subeNivel, { n = c.nivel })
end

local contenido = scope:New("Frame")({
	Name = "Columna",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	[Fusion.Children] = {
		scope:Lista({ Espacio = 6, Alinear = Enum.HorizontalAlignment.Center }),
		scope:New("Frame")({
			Name = "Marco",
			Size = UDim2.new(1, 0, 0, 230),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			[Fusion.Children] = {
				scope:New("UIScale")({ Scale = escalaVista }),
				vista,
			},
		}),
		scope:Texto({
			Nombre = "NombreMascota",
			Texto = scope:Computed(function(use)
				local d = use(def)
				return if use(revelada) and d then d.nombre else "?"
			end),
			Size = UDim2.new(1, 0, 0, 34),
			Tamano = 28,
			Fuente = "titulo",
			Color = scope:Computed(function(use)
				local d = use(def)
				return if use(revelada) and d then (Paleta.RAREZA[d.rareza] or Paleta.UI_TINTA) else Paleta.UI_TINTA
			end),
			Contorno = Paleta.UI_TINTA,
			Alinear = Enum.TextXAlignment.Center,
			Orden = 2,
		}),
		scope:Texto({
			Nombre = "Resultado",
			Texto = scope:Computed(function(use)
				local c = use(actual)
				local d = use(def)
				if not use(revelada) or not c or not d then
					return ""
				end
				return (DefinicionesMascotas.NOMBRE_RAREZA[d.rareza] or d.rareza) .. " · " .. textoResultado(c)
			end),
			Size = UDim2.new(1, 0, 0, 24),
			Tamano = 18,
			Fuente = "titulo",
			Color = Paleta.UI_EXITO,
			Alinear = Enum.TextXAlignment.Center,
			Orden = 3,
		}),
		scope:Boton({
			Nombre = "Genial",
			Texto = Textos.REVELACION.genial,
			Color = Paleta.UI_EXITO,
			Tamano = 20,
			Size = UDim2.fromOffset(220, 52),
			Orden = 4,
			Deshabilitado = scope:Computed(function(use)
				return not use(revelada)
			end),
			alPulsar = function()
				Menu.cerrarTodo()
			end,
		}),
	},
})

scope:Ventana({
	Nombre = NOMBRE,
	Titulo = scope:Computed(function(use)
		local c = use(actual)
		local set = c and DefinicionesMascotas.SET_POR_ID[c.set]
		return if set then Textos.formatear(Textos.REVELACION.deSet, { set = set.nombre }) else Textos.REVELACION.titulo
	end),
	Ancho = 480,
	Alto = 470,
	Orden = 16,
	Abierta = scope:Computed(function(use)
		return use(Menu.abiertoR) == NOMBRE
	end),
	alCerrar = Menu.cerrarTodo,
	Hijos = { contenido },
})

-- ===========================================================================
-- Cola y revelacion
-- ===========================================================================

local function ensenar(c: Completa)
	actual:set(c)
	revelada:set(false)
	local set = DefinicionesMascotas.SET_POR_ID[c.set]
	Encuadre.mostrar(vista, ModelosObjetos.fragmento(if set then set.material else "Plastico"))
	Menu.abrir(NOMBRE)
	task.delay(0.9, function()
		if peek(actual) == c then
			local d = DefinicionesMascotas.obtener(c.id)
			if d then
				Encuadre.mostrar(vista, ModelosMascota.mascota(d, math.max(c.nivel, 1)))
			end
			revelada:set(true)
		end
	end)
end

local function siguiente()
	local c = table.remove(cola, 1)
	if c then
		ensenar(c)
	else
		actual:set(nil)
	end
end

RevelacionEvent.OnClientEvent:Connect(function(completa)
	if typeof(completa) ~= "table" or typeof(completa.id) ~= "string" then
		return
	end
	table.insert(cola, completa)
	if peek(actual) == nil then
		siguiente()
	end
end)

-- Al cerrar la ventana pasa a la siguiente de la cola
Menu.alCambiar:Connect(function()
	if Menu.abierto() ~= NOMBRE and peek(actual) ~= nil then
		task.defer(siguiente)
	end
end)

Menu.registrar(NOMBRE, {
	abrir = function() end,
	primerSeleccionable = function()
		return Navegacion.primerSeleccionable(contenido)
	end,
})

return {}
