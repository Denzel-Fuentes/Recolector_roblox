--!strict
--[[
	Escala (ModuleScript)
	Unica responsabilidad: el estado de la PANTALLA como Values de Fusion
	(tamano del viewport, escala de la UI, plataforma de entrada) y lo que se
	deriva de el. Toda la UI del Kit lo lee con use(), asi que un cambio de
	tamano o de mando se propaga solo, sin reconstruir nada.

	  escala        UIScale de cada ScreenGui segun la altura de la pantalla
	                (0.72-1.15; minimo 0.8 en tactil para que los botones
	                sigan siendo dedo)
	  plataforma    "teclado" | "tactil" | "gamepad" (Utilidades/Entrada)
	  disposicion   "escritorio" | "tactil": el pulgar del thumbstick y el
	                boton de salto obligan a recolocar el HUD
	  diseno        ancho/alto util en px de DISENO (los de Size/Position)
	  compacto      alto de diseno < 560 (telefono apaisado): una columna

	alCambiar es una Senal para el codigo que no es Fusion (Camara).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Utilidades = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades")
local Entrada = require(Utilidades:WaitForChild("Entrada"))
local Senal = require(Utilidades:WaitForChild("Senal"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

export type Disposicion = "escritorio" | "tactil"

local Escala = {}

Escala.alCambiar = Senal.nueva() :: Senal.Senal<nil>

local function tamanoViewport(): Vector2
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1600, 900)
end

-- Scope del modulo: vive toda la sesion
local scope = Fusion.scoped(Fusion)

Escala.viewport = scope:Value(tamanoViewport())
Escala.plataforma = scope:Value(Entrada.plataforma())

Escala.escala = scope:Computed(function(use)
	local minimo = if use(Escala.plataforma) == "tactil" then 0.8 else 0.72
	return math.clamp(use(Escala.viewport).Y / 900, minimo, 1.15)
end)

Escala.disposicion = scope:Computed(function(use): Disposicion
	return if use(Escala.plataforma) == "tactil" then "tactil" else "escritorio"
end)

Escala.diseno = scope:Computed(function(use)
	return use(Escala.viewport) / use(Escala.escala)
end)

Escala.compacto = scope:Computed(function(use)
	return use(Escala.diseno).Y < 560
end)

-- Lecturas sueltas (codigo que no es Fusion y pruebas)
function Escala.valor(): number
	return Fusion.peek(Escala.escala)
end

function Escala.disenoDisponible(): (number, number)
	local d = Fusion.peek(Escala.diseno)
	return d.X, d.Y
end

function Escala.esCompacto(): boolean
	return Fusion.peek(Escala.compacto)
end

function Escala.disposicionActual(): Disposicion
	return Fusion.peek(Escala.disposicion)
end

local pendiente = false
local function refrescar()
	if pendiente then
		return
	end
	pendiente = true
	task.defer(function()
		pendiente = false
		Escala.viewport:set(tamanoViewport())
		Escala.plataforma:set(Entrada.plataforma())
		Escala.alCambiar:Fire(nil)
	end)
end

-- Fuerza la plataforma (solo Studio, para capturas) y avisa a toda la UI
function Escala.forzarPlataforma(plataforma: Entrada.Plataforma?)
	Entrada.forzar(plataforma)
	refrescar()
end

do
	local function vigilarCamara(cam: Camera?)
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(refrescar)
		end
	end
	vigilarCamara(workspace.CurrentCamera)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		vigilarCamara(workspace.CurrentCamera)
		refrescar()
	end)
	UserInputService.LastInputTypeChanged:Connect(refrescar)
end

return Escala
