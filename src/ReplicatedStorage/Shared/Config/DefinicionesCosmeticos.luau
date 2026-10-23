--!strict
--[[
	DefinicionesCosmeticos
	Los cosmeticos de la bolsa (lote 8): disenos (el color y el material de
	la bolsa en las manos, lanzada y caida) y estelas (la estela que deja al
	lanzarla). Solo datos y la regla de quien tiene cada uno (servidor y
	tienda la comparten). (Los trajes del avatar se quitaron el 5 oct.)

	Cada uno se consigue de una forma:
	  pase     = id de Config/Productos (Robux). Los de VIP y del Pack de
	             inicio no se venden sueltos: van dentro de ese pase
	  rebirth  = se regala al llegar a ese rebirth (la Bolsa plateada del
	             Rebirth 3, que sustituyo a la segunda mascota el 3 oct; la de
	             hielo del 4 y la estela de fuego del 5, economia v4)
	  insignia = se regala con esa insignia de DefinicionesInsignias (mira
	             perfil.logros): la Bolsa de carton de "Constante", la 7.a
	             casilla del calendario (economia v4, 22 oct)
	Nada aleatorio y nada que de ventaja: solo se ve. Los de la economia v4
	son color y material de la bolsa de siempre, o una ColorSequence: ni arte
	nuevo ni mallas.
]]

export type Diseno = {
	id: string,
	nombre: string,
	color: Color3,
	material: Enum.Material,
	pase: string?,
	rebirth: number?,
	insignia: string?,
}

export type Estela = {
	id: string,
	nombre: string,
	colores: ColorSequence,
	pase: string?,
	rebirth: number?,
	insignia: string?,
}

local DefinicionesCosmeticos = {}

DefinicionesCosmeticos.BOLSAS = {
	{ id = "Plateada", nombre = "Bolsa plateada", color = Color3.fromRGB(196, 202, 214), material = Enum.Material.Metal, rebirth = 3 },
	{ id = "Dorada", nombre = "Bolsa dorada", color = Color3.fromRGB(242, 190, 46), material = Enum.Material.Metal, pase = "BolsaDorada" },
	-- Economia v4 (22 oct): la de la insignia Constante, la del Rebirth 4 y la
	-- del Pack de inicio (solo en el pack)
	{ id = "Carton", nombre = "Bolsa de cartón", color = Color3.fromRGB(176, 134, 88), material = Enum.Material.Cardboard, insignia = "semanaCompleta" },
	{ id = "Hielo", nombre = "Bolsa de hielo", color = Color3.fromRGB(165, 220, 255), material = Enum.Material.Ice, rebirth = 4 },
	{ id = "Reciclador", nombre = "Bolsa del reciclador", color = Color3.fromRGB(64, 170, 92), material = Enum.Material.Fabric, pase = "PackInicio" },
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
	-- Economia v4 (22 oct): la del Rebirth 5 y la dorada del pase VIP
	{
		id = "Fuego",
		nombre = "Estela de fuego",
		colores = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 30)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 60)),
		}),
		rebirth = 5,
	},
	{
		id = "VIP",
		nombre = "Estela VIP",
		colores = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 180, 40)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 236, 160)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 180, 40)),
		}),
		pase = "VIP",
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

-- Lo tiene quien cumple su forma de conseguirlo. tienePase y tieneInsignia
-- los da quien pregunta (en el servidor, Monetizacion y perfil.logros; en el
-- cliente, EstadoCliente y el perfil publicado). Sin tieneInsignia, uno que
-- se gana con una insignia no se tiene: asi una llamada antigua nunca pone
-- algo que no toca.
function DefinicionesCosmeticos.loTiene(
	def: { pase: string?, rebirth: number?, insignia: string? },
	rebirths: number,
	tienePase: (string) -> boolean,
	tieneInsignia: ((string) -> boolean)?
): boolean
	if def.pase then
		return tienePase(def.pase)
	end
	if def.rebirth then
		return rebirths >= def.rebirth
	end
	if def.insignia then
		return tieneInsignia ~= nil and tieneInsignia(def.insignia)
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
