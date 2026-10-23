--!strict
--[[
	Rebirth (ModuleScript)
	El panel del rebirth (diseno v2): cuantos llevas y tu multiplicador, el
	requisito del siguiente (dinero en mano, con barra, y las 4 mejoras al
	maximo), lo que gana (multiplicador y lo que abre), lo que se reinicia y
	lo que se conserva, y el boton Renacer.

	Solo presentacion: el boton manda RenacerEvent y el servidor decide
	(Services/Rebirths). Todo lo que se pinta se deriva como primitivos del
	perfil (dinero, rebirths, nivel de cada mejora) y de las definiciones de
	Config; las cuentas son las mismas que usa el servidor
	(DefinicionesRebirths).

	Lo que abre el siguiente (economia v4, 22 oct) sale de su `desbloquea`:
	el texto de Textos.REBIRTH.desbloquea y un icono que lo dice sin leer
	(ICONO_DESBLOQUEO): el metal y el organico con su tipo, los regalos de
	bolsa (R3 plateada, R4 hielo) con la bolsa, la Estela de fuego (R5, con
	su insignia) con el lanzamiento, el R10 con el trofeo y los que solo
	suben el multiplicador (R6-R9, desde el 11) con el billete. Una clave sin
	texto cae en la del multiplicador: el panel nunca se queda en blanco.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local DefinicionesMejoras = require(Config:WaitForChild("DefinicionesMejoras"))
local DefinicionesRebirths = require(Config:WaitForChild("DefinicionesRebirths"))
local Utilidades = Shared:WaitForChild("Utilidades")
local Formato = require(Utilidades:WaitForChild("Formato"))
local Red = require(Utilidades:WaitForChild("Red"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Navegacion = require(script.Parent:WaitForChild("Kit"):WaitForChild("Navegacion"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local Children = Fusion.Children

local RenacerEvent = Red.evento("RenacerEvent")

local NOMBRE = "Rebirth"
local reactivo = EstadoCliente.reactivo

-- Icono de lo que abre cada rebirth: clave de Textos.REBIRTH.desbloquea ->
-- clave de Config/Iconos (ver cabecera)
local ICONO_DESBLOQUEO: { [string]: string } = {
	metal = "setMetal",
	organico = "setOrganico",
	bolsaPlateada = "bolsa",
	bolsaHielo = "bolsa",
	estelaFuego = "lanzar",
	multiplicador = "billete",
	leyenda = "trofeo",
}
local DESBLOQUEO_RESPALDO = "multiplicador"

local scope = Fusion.scoped(Fusion, Kit)

-- Primitivos del perfil
local dinero = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	return if p then (p.dinero or 0) else 0
end)
local rebirths = scope:Computed(function(use)
	local p = use(reactivo.perfil)
	return if p then (p.rebirths or 0) else 0
end)
local function nivelDe(id: string)
	return scope:Computed(function(use)
		local p = use(reactivo.perfil)
		return if p and p.mejoras then (p.mejoras[id] or 0) else 0
	end)
end
local niveles = {}
for _, def in DefinicionesMejoras.LISTA do
	niveles[def.id] = nivelDe(def.id)
end

local requisito = scope:Computed(function(use)
	return DefinicionesRebirths.rebirth(use(rebirths) + 1).requisito
end)
-- Lo que abre el siguiente: una clave con texto (ver cabecera)
local desbloquea = scope:Computed(function(use)
	local clave = DefinicionesRebirths.rebirth(use(rebirths) + 1).desbloquea
	return if (Textos.REBIRTH.desbloquea :: any)[clave] then clave else DESBLOQUEO_RESPALDO
end)
local mejorasListas = scope:Computed(function(use)
	for _, def in DefinicionesMejoras.LISTA do
		if use(niveles[def.id]) < DefinicionesMejoras.NIVEL_MAX then
			return false
		end
	end
	return true
end)
local puede = scope:Computed(function(use)
	return use(mejorasListas) and use(dinero) >= use(requisito)
end)

-- ===========================================================================
-- Piezas
-- ===========================================================================

local function filaMejora(orden: number, def: DefinicionesMejoras.Mejora)
	local nivel = niveles[def.id]
	local lista = scope:Computed(function(use)
		return use(nivel) >= DefinicionesMejoras.NIVEL_MAX
	end)
	return scope:New("Frame")({
		Name = "Mejora_" .. def.id,
		Size = UDim2.new(0.5, -6, 0, 30),
		LayoutOrder = orden,
		BackgroundTransparency = 1,
		[Children] = {
			scope:Icono({
				Clave = scope:Computed(function(use)
					return if use(lista) then "check" else "candado"
				end),
				Tamano = 26,
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
			}),
			scope:Texto({
				Texto = scope:Computed(function(use)
					return Textos.formatear(Textos.REBIRTH.mejora, { nombre = Idioma.nombre("Mejoras", def), n = use(nivel) })
				end),
				Size = UDim2.new(1, -34, 1, 0),
				Position = UDim2.fromOffset(34, 0),
				Tamano = 16,
				Fuente = "negrita",
				Color = scope:Computed(function(use)
					return if use(lista) then Paleta.UI_EXITO else Paleta.UI_TINTA
				end),
			}),
		},
	})
end

local filasMejoras = {}
for i, def in DefinicionesMejoras.LISTA do
	table.insert(filasMejoras, filaMejora(i, def))
end

local tarjetaRequisito = scope:Tarjeta({
	Nombre = "Requisito",
	Orden = 2,
	Size = UDim2.new(1, 0, 0, 210),
	Hijos = {
		scope:Texto({
			Texto = scope:Computed(function(use)
				return Textos.formatear(Textos.REBIRTH.siguiente, { n = use(rebirths) + 1 })
			end),
			Size = UDim2.new(1, 0, 0, 26),
			Tamano = 20,
			Fuente = "titulo",
			Color = Paleta.CABECERA_PANEL.Rebirth,
		}),
		scope:Texto({
			Texto = scope:Computed(function(use)
				return Textos.formatear(Textos.REBIRTH.requisitoDinero, { dinero = Formato.dinero(use(requisito)) })
			end),
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 30),
			Tamano = 16,
			Fuente = "negrita",
		}),
		scope:Barra({
			Nombre = "BarraDinero",
			Fraccion = scope:Computed(function(use)
				local r = use(requisito)
				return if r > 0 then math.clamp(use(dinero) / r, 0, 1) else 1
			end),
			Texto = scope:Computed(function(use)
				return Formato.dinero(math.min(use(dinero), use(requisito))) .. " / " .. Formato.dinero(use(requisito))
			end),
			Color = Paleta.UI_DINERO,
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, 56),
			Radio = 14,
			TamanoTexto = 15,
		}),
		scope:Texto({
			Texto = Textos.REBIRTH.requisitoMejoras,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 92),
			Tamano = 15,
			Fuente = "negrita",
		}),
		scope:New("Frame")({
			Name = "Mejoras",
			Size = UDim2.new(1, 0, 0, 66),
			Position = UDim2.fromOffset(0, 114),
			BackgroundTransparency = 1,
			[Children] = {
				scope:Rejilla({ Celda = UDim2.new(0.5, -6, 0, 30), Espacio = 6 }),
				filasMejoras,
			},
		}),
	},
})

local tarjetaPremio = scope:Tarjeta({
	Nombre = "Premio",
	Orden = 3,
	Size = UDim2.new(1, 0, 0, 84),
	Color = Color3.fromRGB(236, 224, 255),
	Hijos = {
		scope:Icono({
			Nombre = "IconoDesbloquea",
			Clave = scope:Computed(function(use)
				return ICONO_DESBLOQUEO[use(desbloquea)] or "estrella"
			end),
			Tamano = 52,
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
		}),
		scope:Texto({
			Texto = scope:Computed(function(use)
				local siguiente = DefinicionesRebirths.rebirth(use(rebirths) + 1)
				return Textos.formatear(Textos.REBIRTH.premio, { mult = Formato.multiplicador(siguiente.multiplicador) })
			end),
			Size = UDim2.new(1, -62, 0, 26),
			Position = UDim2.fromOffset(62, 4),
			Tamano = 19,
			Fuente = "titulo",
			Color = Paleta.CABECERA_PANEL.Rebirth,
		}),
		scope:Texto({
			Nombre = "Desbloquea",
			Texto = scope:Computed(function(use)
				return (Textos.REBIRTH.desbloquea :: any)[use(desbloquea)] or ""
			end),
			Size = UDim2.new(1, -62, 0, 36),
			Position = UDim2.fromOffset(62, 32),
			Tamano = 15,
			Fuente = "negrita",
			AlinearY = Enum.TextYAlignment.Top,
		}),
	},
})

local botonRenacer = scope:Boton({
	Nombre = "Renacer",
	Texto = Textos.REBIRTH.renacer,
	Color = Paleta.CABECERA_PANEL.Rebirth,
	Icono = "estrella",
	Tamano = 22,
	Size = UDim2.fromOffset(240, 56),
	Orden = 5,
	Deshabilitado = scope:Computed(function(use)
		return not use(puede)
	end),
	alPulsar = function()
		RenacerEvent:FireServer()
	end,
})

local contenido = scope:New("Frame")({
	Name = "Columna",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	[Children] = {
		scope:Lista({ Espacio = 10, Alinear = Enum.HorizontalAlignment.Center }),
		scope:Texto({
			Nombre = "Tienes",
			Texto = scope:Computed(function(use)
				return Textos.formatear(Textos.REBIRTH.tienes, { n = use(rebirths), mult = Formato.multiplicador(DefinicionesRebirths.multiplicador(use(rebirths))) })
			end),
			Size = UDim2.new(1, 0, 0, 26),
			Tamano = 18,
			Fuente = "titulo",
			Alinear = Enum.TextXAlignment.Center,
			Orden = 1,
		}),
		tarjetaRequisito,
		tarjetaPremio,
		scope:Texto({
			Nombre = "Reinicio",
			Texto = Textos.REBIRTH.reinicia .. ". " .. Textos.REBIRTH.conserva .. ".",
			Size = UDim2.new(1, 0, 0, 40),
			Tamano = 13,
			Color = Paleta.UI_TINTA_SUAVE,
			Alinear = Enum.TextXAlignment.Center,
			Orden = 4,
		}),
		botonRenacer,
	},
})

scope:Ventana({
	Nombre = NOMBRE,
	Titulo = Textos.REBIRTH.titulo,
	Ancho = 640,
	Alto = 600,
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

-- Para el HUD: progreso hacia el siguiente rebirth (dinero y mejoras a
-- partes iguales) y si ya se puede
return {
	progreso = scope:Computed(function(use)
		local r = use(requisito)
		local fDinero = if r > 0 then math.clamp(use(dinero) / r, 0, 1) else 1
		local suma = 0
		for _, def in DefinicionesMejoras.LISTA do
			suma += use(niveles[def.id]) / DefinicionesMejoras.NIVEL_MAX
		end
		return (fDinero + suma / #DefinicionesMejoras.LISTA) / 2
	end),
	puede = puede,
}
