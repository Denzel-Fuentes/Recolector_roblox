--!strict
--[[
	Kit (ModuleScript con hijos)
	El sistema de diseno de la UI, en Fusion 0.3. Toda pantalla del juego se
	monta con estos constructores, asi el aspecto (estilo "UI Kit" de
	simulador: contorno marino, colores intensos, studs) se decide aqui una
	sola vez. Cada constructor vive en su propio modulo.

	Uso en un panel:
	    local scope = Fusion.scoped(Fusion, Kit)
	    scope:Ventana { Nombre = "Tienda", ..., Hijos = {
	        scope:Boton { Texto = "Comprar", alPulsar = ... },
	    } }

	Este modulo solo reune constructores (funciones (scope, props)), porque
	Fusion.scoped los mezcla como metodos del scope. Las constantes y el
	estado de pantalla estan aparte: Kit/Tema y Kit/Escala; encuadrar modelos
	en Kit/Encuadre.
]]

local Maquetas = require(script:WaitForChild("Maquetas"))

return {
	Pantalla = require(script:WaitForChild("Pantalla")),
	Texto = require(script:WaitForChild("Texto")),
	Icono = require(script:WaitForChild("Icono")),
	Studs = require(script:WaitForChild("Studs")),
	Boton = require(script:WaitForChild("Boton")),
	Tarjeta = require(script:WaitForChild("Tarjeta")),
	Ventana = require(script:WaitForChild("Ventana")),
	Pestanas = require(script:WaitForChild("Pestanas")),
	Pildora = require(script:WaitForChild("Pildora")),
	Insignia = require(script:WaitForChild("Insignia")),
	Barra = require(script:WaitForChild("Barra")),
	Segmentos = require(script:WaitForChild("Segmentos")),
	Interruptor = require(script:WaitForChild("Interruptor")),
	Scroll = require(script:WaitForChild("Scroll")),
	Viewport = require(script:WaitForChild("Viewport")),
	Lista = Maquetas.Lista,
	Rejilla = Maquetas.Rejilla,
	Relleno = Maquetas.Relleno,
}
