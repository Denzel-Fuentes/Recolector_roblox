--!strict
--[[
	DefinicionesCosmeticos
	Los cosmeticos de la bolsa (lote 8): disenos (el color y el material de
	la bolsa en las manos, lanzada y caida) y estelas (la estela que deja al
	lanzarla). Solo datos y la regla de quien tiene cada uno (servidor y
	tienda la comparten). (Los trajes del avatar se quitaron el 5 oct.)

	Cada uno se consigue de una forma:
	  pase     = id de Config/Productos (Robux)
	  rebirth  = se regala al llegar a ese rebirth (la Bolsa plateada del
	             Rebirth 3, que sustituyo a la segunda mascota el 3 oct)
	Nada aleatorio y nada que de ventaja: solo se ve.
]]

export type Diseno = {
	id: string,
	nombre: string,
	color: Color3,
	material: Enum.Material,
	pase: string?,
	rebirth: number?,
}

export type Estela = {
	id: string,
	nombre: string,
	colores: ColorSequence,
	pase: string?,
	rebirth: number?,
}

local DefinicionesCosmeticos = {}

DefinicionesCosmeticos.BOLSAS = {
	{ id = "Plateada", nombre = "Bolsa plateada", color = Color3.fromRGB(196, 202, 214), material = Enum.Material.Metal, rebirth = 3 },
	{ id = "Dorada", nombre = "Bolsa dorada", color = Color3.fromRGB(242, 190, 46), material = Enum.Material.Metal, pase = "BolsaDorada" },
} :: { Diseno }

DefinicionesCosmeticos.ESTELAS = {
	{
		id = "Arcoiris",
		nombre = "Estela arcoíris",
		colores = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 40)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 210, 90)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 140, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 80, 240)),
		}),
		pase = "EstelaArcoiris",
	},
} :: { Estela }

DefinicionesCosmeticos.BOLSA_POR_ID = {} :: { [string]: Diseno }
for _, d in DefinicionesCosmeticos.BOLSAS do
	DefinicionesCosmeticos.BOLSA_POR_ID[d.id] = d
end
DefinicionesCosmeticos.ESTELA_POR_ID = {} :: { [string]: Estela }
for _, e in DefinicionesCosmeticos.ESTELAS do
	DefinicionesCosmeticos.ESTELA_POR_ID[e.id] = e
end

-- Lo tiene quien cumple su forma de conseguirlo. tienePase lo da quien
-- pregunta (Monetizacion en el servidor, EstadoCliente en el cliente).
function DefinicionesCosmeticos.loTiene(def: { pase: string?, rebirth: number? }, rebirths: number, tienePase: (string) -> boolean): boolean
	if def.pase then
		return tienePase(def.pase)
	end
	if def.rebirth then
		return rebirths >= def.rebirth
	end
	return false
end

-- La definicion de un cosmetico: tipo "bolsa" | "estela"
function DefinicionesCosmeticos.obtener(tipo: string, id: string): any
	if tipo == "bolsa" then
		return DefinicionesCosmeticos.BOLSA_POR_ID[id]
	elseif tipo == "estela" then
		return DefinicionesCosmeticos.ESTELA_POR_ID[id]
	end
	return nil
end

return DefinicionesCosmeticos
