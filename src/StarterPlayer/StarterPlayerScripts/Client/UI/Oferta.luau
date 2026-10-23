--!strict
--[[
	Oferta (ModuleScript)
	STUB del paquete C3 (22 oct, economia v4): el panel "Oferta", que K1
	rellena con las ofertas en el momento justo (docs/Economia-v4.md §5.6;
	copy en Textos.OFERTAS): el icono, un titulo, una frase con lo que da y
	dos botones del mismo tamano, tipo de letra y peso ("Comprar · N Robux" y
	"Ahora no"). La oferta la decide el servidor (OfertaEvent) y la respuesta
	vuelve por OfertaRespuestaEvent; quien la reciba la abre con
	Menu.abrir("Oferta", datos).

	Es un panel de Menu a proposito: abierto, suelta el raton en primera
	persona (Camara.client) y deja el patio quieto (ControlPatio), como los
	demas. La X y Esc acaban en Menu.cerrarTodo (y en el `cerrar` del
	registro, si K1 lo pone): valen "Ahora no". No tiene boton en el HUD ni
	atajo.

	De momento, solo la ventana y "Proximamente". Como Recompensas, devuelve
	`indicador` (aqui siempre false: nadie lo pinta).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
-- El copy en el idioma del jugador (misma forma que Config/Textos)
local Idioma = require(Shared:WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Textos = Idioma.textos
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local NOMBRE = "Oferta"

local scope = Fusion.scoped(Fusion, Kit)

local indicador = scope:Value(false)

scope:Ventana({
	Nombre = NOMBRE,
	-- Provisional: el titulo de cada oferta lo pone K1 (OFERTAS.packTitulo...).
	-- Nunca "Oferta" en pantalla (normas de Roblox, ver Textos.OFERTAS)
	Titulo = Textos.TIENDA.pases,
	Ancho = 560,
	Alto = 360,
	Abierta = scope:Computed(function(use)
		return use(Menu.abiertoR) == NOMBRE
	end),
	alCerrar = Menu.cerrarTodo,
	Hijos = {
		scope:Icono({
			Clave = "estrella",
			Tamano = 96,
			Position = UDim2.fromScale(0.5, 0.36),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}),
		scope:Texto({
			Nombre = "Proximamente",
			Texto = Textos.TIENDA.proximamente,
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromScale(0.5, 0.76),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Tamano = 24,
			Fuente = "titulo",
			Color = Paleta.UI_TINTA_SUAVE,
			Alinear = Enum.TextXAlignment.Center,
		}),
	},
})

Menu.registrar(NOMBRE, {
	-- datos: lo que mande el servidor con la oferta (lo define K1)
	abrir = function(_datos: any?) end,
})

return {
	indicador = indicador,
}
