--!strict
--[[
	Botin (ModuleScript)
	La fachada del patio compartido: lo unico que BotinHandler, Admin y las
	pruebas necesitan saber. Por dentro son cinco modulos con una
	responsabilidad cada uno (y sin ciclos entre ellos):

	  GeneradorBotin  que sale de un monton (lotes, relleno)
	  ObjetosPatio    registro de objetos y reclamo atomico
	  FisicaBasura    la basura cae, se amontona y se ancla
	  Montones        colina -> montana de basura -> agotado -> repoblado
	  Lanzamiento     la punteria (lanzar la bolsa al contenedor)

	Tipos compartidos en TiposPatio. Este modulo no tiene logica propia: solo
	arranca todo en orden y reexporta.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Servicios = ServerScriptService:WaitForChild("Services")
local TiposPatio = require(Servicios:WaitForChild("TiposPatio"))
local Colisiones = require(Servicios:WaitForChild("Colisiones"))
local GeneradorBotin = require(Servicios:WaitForChild("GeneradorBotin"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))
local FisicaBasura = require(Servicios:WaitForChild("FisicaBasura"))
local Montones = require(Servicios:WaitForChild("Montones"))
local Lanzamiento = require(Servicios:WaitForChild("Lanzamiento"))

export type Item = TiposPatio.Item
export type Monton = TiposPatio.Monton
export type Objeto = TiposPatio.Objeto

local Botin = {}

Botin.generarContenido = GeneradorBotin.generar
Botin.objetos = ObjetosPatio.todos
Botin.reclamar = ObjetosPatio.reclamar
Botin.montones = Montones.todos
Botin.montonDe = Montones.de
Botin.excavar = Montones.excavar
Botin.montonesActivosDe = Montones.activosDe
Botin.montonPendienteDe = Montones.pendienteDe
Botin.liberarMontones = Montones.liberar
Botin.repoblarAhora = Montones.repoblarAhora
Botin.lanzarBolsa = Lanzamiento.lanzarBolsa

local iniciado = false

function Botin.iniciar()
	if iniciado then
		return
	end
	iniciado = true
	Colisiones.iniciar()
	ObjetosPatio.iniciar()
	FisicaBasura.iniciar()
	Montones.iniciar()
	Lanzamiento.iniciar()
end

return Botin
