--!strict
--[[
	Probabilidades (ModuleScript)
	El modal "Ver probabilidades" que la politica de Roblox exige antes de
	cualquier compra aleatoria pagada (Sobre Premium con Gemas; Contenedor
	Dorado, que tambien se paga con Gemas).

	Lee las tablas DIRECTAMENTE de Config/TablasProbabilidad, el mismo modulo
	que usa el servidor para sortear: no hay copia de numeros en la UI que pueda
	quedarse desactualizada. Cada tabla se pinta con su suma (100%).

	Va por encima de la Tienda (DisplayOrder mayor) y no pasa por Menu: es un
	detalle de la tienda, no un panel propio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local TablasProbabilidad = require(Config:WaitForChild("TablasProbabilidad"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local Formato = require(Shared:WaitForChild("Utilidades"):WaitForChild("Formato"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Componentes = require(script.Parent:WaitForChild("Componentes"))

local Probabilidades = {}

local modal = Componentes.modal("Probabilidades", "", 520, 520)
modal.pantalla.DisplayOrder = 15
local contenido = modal.contenido
Componentes.lista(contenido, 8)

local NOMBRE_ID = {
	Comun = "Común",
	Rara = "Rara",
	Epica = "Épica",
	["1"] = "Dañada",
	["2"] = "Regular",
	["3"] = "Buena",
	["4"] = "Excelente",
	["5"] = "Perfecta",
}

local function pintarTabla(titulo: string, tabla: TablasProbabilidad.Tabla, orden: number, colorDe: ((id: string) -> Color3)?)
	local bloque = Componentes.marco({ Parent = contenido, Size = UDim2.new(1, 0, 0, 30 + #tabla * 26 + 26), Color = Paleta.UI_PANEL, Radio = 10, Orden = orden })
	Componentes.padding(bloque, 10, 6)
	Componentes.lista(bloque, 2)
	Componentes.texto({ Parent = bloque, Texto = titulo, Size = UDim2.new(1, 0, 0, 22), Tamano = 15, Negrita = true, Orden = 0 })
	for i, entrada in tabla do
		local fila = Componentes.marco({ Parent = bloque, Size = UDim2.new(1, 0, 0, 24), Transparencia = 1, Orden = i })
		local color = if colorDe then colorDe(entrada.id) else Paleta.UI_TEXTO
		Componentes.texto({ Parent = fila, Texto = NOMBRE_ID[entrada.id] or entrada.id, Size = UDim2.new(0.5, 0, 1, 0), Tamano = 14, Color = color })
		local barra = Componentes.barra(fila, UDim2.new(0.3, 0, 0, 14), color)
		barra.marco.Position = UDim2.new(0.5, 0, 0.5, -7)
		barra.fijar(entrada.peso / 100, "")
		Componentes.texto({ Parent = fila, Texto = Formato.porcentaje(entrada.peso / 100, 1), Size = UDim2.new(0.2, 0, 1, 0), Position = UDim2.new(0.8, 0, 0, 0), Tamano = 14, Alinear = Enum.TextXAlignment.Right, Negrita = true })
	end
	Componentes.texto({ Parent = bloque, Texto = "Total: " .. Formato.porcentaje(TablasProbabilidad.suma(tabla) / 100, 0), Size = UDim2.new(1, 0, 0, 20), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE, Alinear = Enum.TextXAlignment.Right, Orden = #tabla + 1 })
end

local function colorRareza(id: string): Color3
	return Paleta.RAREZA[id] or Paleta.UI_TEXTO
end

-- producto = "sobre" | "contenedor" | "monton"
function Probabilidades.abrir(producto: string)
	Componentes.limpiar(contenido)
	local nombre = if producto == "sobre" then Textos.TIENDA.sobrePremium elseif producto == "contenedor" then Textos.TIENDA.contenedorDorado else "los montones"
	modal.titulo.Text = Textos.formatear(Textos.PROBABILIDADES.titulo, { producto = nombre })
	if producto == "sobre" then
		pintarTabla(Textos.PROBABILIDADES.rareza, TablasProbabilidad.SOBRE_PREMIUM.rareza, 1, colorRareza)
		pintarTabla(Textos.PROBABILIDADES.estado, TablasProbabilidad.SOBRE_PREMIUM.estado, 2)
	elseif producto == "contenedor" then
		pintarTabla(Textos.PROBABILIDADES.rareza .. " (cada una de las 3)", TablasProbabilidad.CONTENEDOR_DORADO.rareza, 1, colorRareza)
		pintarTabla(Textos.PROBABILIDADES.estado, TablasProbabilidad.CONTENEDOR_DORADO.estado, 2)
	else
		local p = EstadoCliente.perfil
		local pity = if p then (p.pity or 0) else 0
		local conPase = EstadoCliente.tienePase("PaseSuerte")
		pintarTabla(Textos.PROBABILIDADES.rareza .. " (mascota completa, con tu pity actual)", TablasProbabilidad.tablaRarezaMonton(pity, conPase), 1, colorRareza)
		pintarTabla(Textos.PROBABILIDADES.estado, TablasProbabilidad.ESTADO_MASCOTA_MONTON, 2)
		Componentes.texto({ Parent = contenido, Texto = Textos.formatear(Textos.PROBABILIDADES.pityActual, { pct = string.format("%.0f", TablasProbabilidad.probabilidadRara(pity, conPase) * 100) }), Size = UDim2.new(1, 0, 0, 20), Tamano = 12, Color = Paleta.UI_ACENTO, Orden = 3 })
	end
	Componentes.texto({ Parent = contenido, Texto = Textos.PROBABILIDADES.nota, Size = UDim2.new(1, 0, 0, 36), Tamano = 12, Color = Paleta.UI_TEXTO_SUAVE, Orden = 9 })
	modal.abrir()
end

function Probabilidades.cerrar()
	modal.cerrar()
end

return Probabilidades
