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
local ServerStorage = game:GetService("ServerStorage")

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

function Mundo.parcelas(): { Model }
	local lista = {}
	for _, inst in conTag("Parcela") do
		if inst:IsA("Model") then
			table.insert(lista, inst)
		end
	end
	table.sort(lista, function(a, b)
		return (a:GetAttribute("IndiceParcela") or 0) < (b:GetAttribute("IndiceParcela") or 0)
	end)
	return lista
end

function Mundo.contenedor(): Model?
	for _, inst in conTag("Contenedor") do
		if inst:IsA("Model") then
			return inst
		end
	end
	return nil
end

function Mundo.zonaAcierto(): BasePart?
	local cont = Mundo.contenedor()
	if not cont then
		return nil
	end
	local zona = cont:FindFirstChild("ZonaAcierto")
	return if zona and zona:IsA("BasePart") then zona else nil
end

function Mundo.maquinaRefrescos(): Model?
	for _, inst in conTag("MaquinaRefrescos") do
		if inst:IsA("Model") then
			return inst
		end
	end
	return nil
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

-- Posicion del spawn de la plaza (a donde se vuelve con "Ir al patio")
function Mundo.posicionPlaza(): Vector3
	local r = Mundo.asegurar()
	local plaza = r:FindFirstChild("Plaza")
	local spawn = plaza and plaza:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position + Vector3.new(0, 3, 0)
	end
	return Vector3.new(0, 5, -130)
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

function Mundo.parcelaDe(inst: Instance): Model?
	local actual: Instance? = inst
	while actual and actual ~= workspace do
		if actual:IsA("Model") and CollectionService:HasTag(actual, "Parcela") then
			return actual
		end
		actual = actual.Parent
	end
	return nil
end

return Mundo
