--!strict
--[[
	Recompensas (ModuleScript)
	STUB del paquete C3 (22 oct, economia v4): el panel "Recompensas" que
	abre el boton del regalo del HUD (el sexto hueco de la botonera). Lo
	rellena R1 con el calendario de 7 casillas, los regalos por minutos
	activos y el bono de regreso (docs/Economia-v4.md §4): el copy esta en
	Textos.RECOMPENSAS, el estado en perfil.recompensas (Services/Perfiles,
	cabecera) y la intencion va por RecompensaEvent. De momento, solo la
	ventana con su titulo y "Proximamente".

	Contrato con el HUD: el modulo devuelve `indicador`, un estado de Fusion
	(o un booleano) que enciende el punto rojo de su boton mientras sea true
	(algo por cobrar). Aqui siempre es false; para verlo encendido:
	EjecutarPruebaCliente:Invoke("modulo", "Recompensas", "indicador", true).
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

local NOMBRE = "Recompensas"

local scope = Fusion.scoped(Fusion, Kit)

-- El punto rojo del boton del HUD (ver cabecera)
local indicador = scope:Value(false)

scope:Ventana({
	Nombre = NOMBRE,
	Titulo = Textos.RECOMPENSAS.titulo,
	Ancho = 720,
	Alto = 560,
	Abierta = scope:Computed(function(use)
		return use(Menu.abiertoR) == NOMBRE
	end),
	alCerrar = Menu.cerrarTodo,
	Hijos = {
		scope:Icono({
			Clave = "regalo",
			Tamano = 120,
			Position = UDim2.fromScale(0.5, 0.4),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}),
		scope:Texto({
			Nombre = "Proximamente",
			Texto = Textos.TIENDA.proximamente,
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromScale(0.5, 0.68),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Tamano = 26,
			Fuente = "titulo",
			Color = Paleta.UI_TINTA_SUAVE,
			Alinear = Enum.TextXAlignment.Center,
		}),
	},
})

Menu.registrar(NOMBRE, {
	abrir = function() end,
})

return {
	indicador = indicador,
	prueba = {
		-- ("modulo", "Recompensas", "indicador", true | false): enciende o
		-- apaga el punto rojo del boton del HUD
		indicador = function(valor: any): string
			indicador:set(valor == true or valor == "true")
			return "indicador=" .. tostring(Fusion.peek(indicador))
		end,
	},
}
