--!strict
--[[
	Mundo (ModuleScript)
	Unica responsabilidad: localizar la geometria horneada del place para el
	resto de servicios. NO construye nada en el flujo normal.

	La geometria se busca por TAGS de CollectionService y atributos (ver
	ServerStorage/Herramientas/ConstructorMundo), nunca por nombres: asi se
	pueden mover, anadir o borrar piezas en Studio sin tocar codigo.

	Fallback: si al arrancar no existe workspace.Mundo (place recien hecho con
	rojo build, o alguien lo borro), se construye con ConstructorMundo y se avisa.
	Lo construido asi desaparece al parar el juego; para que persista hay que
	hornear con herramientas/construir-mundo.luau y guardar el place.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Contenedores = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Contenedores"))

export type Contenedor = Contenedores.Contenedor

local Mundo = {}

local raiz: Model? = nil

function Mundo.asegurar(): Model
	if raiz then
		return raiz
	end
	local existente = workspace:FindFirstChild("Mundo")
	if existente and existente:IsA("Model") then
		raiz = existente
		print(string.format("Mundo: adoptado workspace.Mundo v%s (%d instancias)", tostring(existente:GetAttribute("Version")), #existente:GetDescendants()))
		return existente
	end
	warn("Mundo: no existe workspace.Mundo. Se construye en runtime como fallback; hornea con herramientas/construir-mundo.luau y guarda el place.")
	local ConstructorMundo = require(ServerStorage:WaitForChild("Herramientas"):WaitForChild("ConstructorMundo")) :: any
	local construido = ConstructorMundo.construir()
	raiz = construido
	return construido
end

function Mundo.raiz(): Model
	return Mundo.asegurar()
end

local function conTag(tag: string): { Instance }
	Mundo.asegurar()
	return CollectionService:GetTagged(tag)
end

function Mundo.ranuras(): { BasePart }
	local lista = {}
	for _, inst in conTag("RanuraMonton") do
		if inst:IsA("BasePart") then
			table.insert(lista, inst)
		end
	end
	table.sort(lista, function(a, b)
		return (a:GetAttribute("Indice") or 0) < (b:GetAttribute("Indice") or 0)
	end)
	return lista
end

function Mundo.figurinasFijas(): { BasePart }
	local lista = {}
	for _, inst in conTag("FigurinaFija") do
		if inst:IsA("BasePart") then
			table.insert(lista, inst)
		end
	end
	return lista
end

-- Los cinco contenedores (uno por tipo + el general; Utilidades/Contenedores)
function Mundo.contenedores(): { Contenedor }
	Mundo.asegurar()
	return Contenedores.listar()
end

-- El de un tipo de basura, o el general con material nil
function Mundo.contenedorDe(material: string?): Contenedor?
	Mundo.asegurar()
	return Contenedores.de(material)
end

-- El GENERAL (el volquete de la recicladora): el del primer lanzamiento
function Mundo.contenedor(): Model?
	local c = Mundo.contenedorDe(nil)
	return if c then c.modelo else nil
end

function Mundo.zonaAcierto(): BasePart?
	local c = Mundo.contenedorDe(nil)
	return if c then c.zona else nil
end

function Mundo.npc(nombre: string): Model?
	local r = Mundo.asegurar()
	for _, d in r:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("NPC") == nombre then
			return d
		end
	end
	return nil
end

-- Donde aparece todo el mundo: en la plaza, junto al borde sur del patio y
-- mirandolo (diseno v2: sin base, se aparece junto al patio). Un marcador
-- horneado con el tag PuntoAparicion manda; sin el, la plaza de siempre.
local PLAZA = Vector3.new(0, 5, 96)

function Mundo.cframeAparicion(): CFrame
	for _, inst in conTag("PuntoAparicion") do
		if inst:IsA("BasePart") then
			return inst.CFrame + Vector3.new(0, 4, 0)
		end
	end
	return CFrame.lookAt(PLAZA, Vector3.new(0, PLAZA.Y, 0))
end

-- Sube a la parte con prompt hasta el Model que lleva el atributo/tag de interes
function Mundo.modeloDe(inst: Instance): Model?
	local actual: Instance? = inst
	while actual and actual ~= workspace do
		if actual:IsA("Model") then
			return actual
		end
		actual = actual.Parent
	end
	return nil
end

return Mundo
