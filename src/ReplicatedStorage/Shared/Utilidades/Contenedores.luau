--!strict
--[[
	Contenedores
	Unica responsabilidad: encontrar los contenedores de reciclaje del mundo,
	igual en servidor y cliente (Lanzamiento, el prompt de entregar, el bonus
	del HUD, la linea de trayectoria, la flecha del tutorial).

	Desde el 3 oct hay cinco (decision del usuario): uno por tipo de basura
	(Papel, Plastico, Metal, Organico), en fila junto a la recicladora, y el
	GENERAL, el volquete de la recicladora, que acepta de todo. Todos llevan
	el tag Contenedor y un hijo ZonaAcierto; los de tipo, ademas, el atributo
	Material. El general no lo lleva: es el que recibe "el primero siempre
	entra" y el que senala el tutorial.

	Lo que paga cada uno (x2 su tipo, x0,5 otro tipo, x1 el general) lo
	decide Services/Bolsa; aqui solo se localizan.
]]

local CollectionService = game:GetService("CollectionService")

export type Contenedor = {
	modelo: Model,
	zona: BasePart, -- volumen interior: por su boca entra la bolsa
	material: string?, -- nil = el general
}

local Contenedores = {}

-- Todos los del mundo (los que tengan ZonaAcierto)
function Contenedores.listar(): { Contenedor }
	local lista = {}
	for _, inst in CollectionService:GetTagged("Contenedor") do
		local zona = inst:FindFirstChild("ZonaAcierto")
		if inst:IsA("Model") and zona and zona:IsA("BasePart") then
			local material = inst:GetAttribute("Material")
			table.insert(lista, {
				modelo = inst,
				zona = zona,
				material = if typeof(material) == "string" then material else nil,
			})
		end
	end
	return lista
end

-- El de un tipo, o el general con material nil
function Contenedores.de(material: string?): Contenedor?
	for _, c in Contenedores.listar() do
		if c.material == material then
			return c
		end
	end
	return nil
end

function Contenedores.general(): Contenedor?
	return Contenedores.de(nil)
end

-- El mas cercano a un punto (en horizontal) y su distancia
function Contenedores.masCercano(pos: Vector3): (Contenedor?, number)
	local mejor, dMejor = nil, math.huge
	for _, c in Contenedores.listar() do
		local d = Vector3.new(c.zona.Position.X - pos.X, 0, c.zona.Position.Z - pos.Z).Magnitude
		if d < dMejor then
			mejor, dMejor = c, d
		end
	end
	return mejor, dMejor
end

-- El contenedor al que pertenece una instancia (un prompt, una pared)
function Contenedores.duenoDe(inst: Instance): Contenedor?
	local actual: Instance? = inst
	while actual and actual ~= workspace do
		if actual:IsA("Model") and CollectionService:HasTag(actual, "Contenedor") then
			for _, c in Contenedores.listar() do
				if c.modelo == actual then
					return c
				end
			end
			return nil
		end
		actual = actual.Parent
	end
	return nil
end

return Contenedores
