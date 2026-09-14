--!strict
--[[
	Logros (ModuleScript)
	Los 40 logros por categoria, con barra de progreso actual/umbral calculada
	con Utilidades/ProgresoLogros sobre el perfil local: el mismo calculo que
	hace el servidor para desbloquear, asi que la barra nunca miente.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local DefinicionesLogros = require(Config:WaitForChild("DefinicionesLogros"))
local ProgresoLogros = require(Shared:WaitForChild("Utilidades"):WaitForChild("ProgresoLogros"))
local Formato = require(Shared:WaitForChild("Utilidades"):WaitForChild("Formato"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Componentes = require(script.Parent:WaitForChild("Componentes"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local Logros = {}

local modal = Componentes.modal("Logros", Textos.LOGROS.titulo, 760, 600)
local contenido = modal.contenido
local total = Componentes.texto({ Parent = modal.panel, Size = UDim2.fromOffset(200, 24), Position = UDim2.new(1, -270, 0, 14), Tamano = 14, Color = Paleta.UI_ACENTO, Alinear = Enum.TextXAlignment.Right })
local cuerpo = Componentes.scroll(contenido)
Componentes.lista(cuerpo, 6)
Componentes.padding(cuerpo, 4)

local function repintar()
	Componentes.limpiar(cuerpo)
	local p = EstadoCliente.perfil
	if not p then
		return
	end
	local desbloqueados = 0
	local orden = 0
	for _, categoria in DefinicionesLogros.CATEGORIAS do
		orden += 1
		Componentes.texto({ Parent = cuerpo, Texto = categoria, Size = UDim2.new(1, -12, 0, 28), Tamano = 16, Negrita = true, Color = Paleta.UI_ACENTO, Orden = orden })
		for _, logro in DefinicionesLogros.porCategoria(categoria) do
			orden += 1
			local tiene = p.logros and p.logros[logro.id] == true
			if tiene then
				desbloqueados += 1
			end
			local actual, umbral = ProgresoLogros.progreso(p, logro)
			local f = Componentes.marco({ Parent = cuerpo, Size = UDim2.new(1, -12, 0, 54), Color = if tiene then Paleta.UI_PANEL_CLARO else Paleta.UI_PANEL, Radio = 8, Orden = orden, Nombre = logro.id })
			Componentes.padding(f, 10, 6)
			local marca = Componentes.marco({ Parent = f, Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(0, 4), Color = if tiene then Paleta.UI_ACENTO else Paleta.UI_FONDO, Radio = 9 })
			marca.Name = "Marca"
			Componentes.texto({ Parent = f, Texto = logro.nombre, Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.fromOffset(28, 0), Tamano = 15, Negrita = true, Color = if tiene then Paleta.UI_TEXTO else Paleta.UI_TEXTO_SUAVE })
			Componentes.texto({ Parent = f, Texto = logro.descripcion, Size = UDim2.new(0.6, 0, 0, 18), Position = UDim2.fromOffset(28, 22), Tamano = 11, Color = Paleta.UI_TEXTO_SUAVE })
			local barra = Componentes.barra(f, UDim2.fromOffset(200, 18), if tiene then Paleta.UI_ACENTO else Paleta.UI_GEMAS)
			barra.marco.Position = UDim2.new(1, -200, 0.5, -9)
			local fraccion = if umbral > 0 then math.min(1, actual / umbral) else 0
			barra.fijar(fraccion, if tiene then Textos.LOGROS.completado else Textos.formatear(Textos.LOGROS.progreso, { actual = Formato.miles(math.min(actual, umbral)), umbral = Formato.miles(umbral) }))
		end
	end
	total.Text = Textos.formatear(Textos.LOGROS.total, { n = desbloqueados })
end

EstadoCliente.alCambiarPerfil:Connect(function()
	if modal.estaAbierto() then
		repintar()
	end
end)

table.insert(modal.alCerrar, function()
	Menu.notificarCierre("Logros")
end)

Menu.registrar("Logros", {
	abrir = function()
		modal.abrir()
		repintar()
	end,
	cerrar = modal.cerrar,
	estaAbierto = modal.estaAbierto,
	primerSeleccionable = function()
		return modal.botonCerrar
	end,
})

return Logros
