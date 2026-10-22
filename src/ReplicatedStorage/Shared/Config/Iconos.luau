--!strict
--[[
	Iconos
	Registro de las imagenes de la interfaz: un id de asset por clave. Solo
	datos. 0 = todavia no hay imagen (misma convencion que Config/Productos).

	La UI nunca pide una imagen directamente: pasa por Kit/Icono, que usa la
	imagen si aqui hay id y, si no, la dibuja con Utilidades/Glifos. Asi la
	interfaz esta terminada aunque el arte llegue despues, y cada imagen se
	activa cambiando un numero, sin tocar logica.

	Iconos del estilo "UI Kit" (23 sep): salen de un set gratuito de la
	Creator Store ("Simulator Icon Pack"). Las copias que hay en la Toolbox
	traian scripts maliciosos escondidos: se insertaron en cuarentena, se
	borraron los scripts y solo se apuntaron aqui los ids de las IMAGENES (el
	origen de cada una, en assets/ui/README.md). Las claves que siguen a 0 no
	tienen equivalente en ese set y se dibujan con Glifos.

	Las claves de lo que la v2 quito (gema, sobre, contenedorDorado, pocion)
	se borraron el 22 oct: la prueba sinRestos falla si vuelven.
]]

local Iconos = {}

Iconos.IMAGENES = {
	-- HUD (prioridad 1)
	billete = 15402858705, -- CashIcon
	rayo = 17368078790, -- Energy
	bolsa = 15402958715, -- Inventory (mochila): lo que cabe
	libreta = 127110909372919, -- Index (libro): el album
	telefono = 17368217589, -- Shop: la tienda
	trofeo = 12129301834, -- Trophies/Wins
	casa = 15403180857, -- House
	montana = 17368164592, -- Teleport (portal): ir al patio
	lanzar = 16670799841, -- Rocket
	mano = 17260727409, -- Cursors/Click
	raton = 13443203578, -- Cursors/Classic
	lata = 0,
	flecha = 15403007921, -- Strength (brazo): fuerza de lanzamiento
	sonido = 0, -- altavoz: el boton Sonido del HUD (glifo dibujado)

	-- Paneles (prioridad 2)
	estrella = 17368097932, -- Star
	corona = 16912465495, -- VIP
	check = 17368190066, -- Accept
	candado = 17368080973, -- LockClosed
	corazon = 17368075795, -- Health
	nota = 95668779942949, -- Disc
	figurina = 0,
	cinta = 95668779942949, -- Disc
	engranaje = 17368089841, -- Settings
	camara = 0, -- vista primera/tercera persona (glifo dibujado)
	bota = 17368052918, -- Speed (zapatilla)
	cofre = 15402896733, -- GemChest
	cruz = 17368208554, -- Deny

	-- Tipos de basura (contenedores, pedidos)
	setMetal = 0,
	setPlastico = 0,
	setPapel = 0,
	setOrganico = 0,

	-- Imagenes grandes (prioridad 1 las manos, 3 el resto)
	manosVacia = 0,
	manosMedia = 0,
	manosLlena = 0,
	papel = 0,
	logo = 0,

	-- Texturas (se repiten en mosaico, no son iconos)
	studs = 6927295847, -- fondo de botones, tarjetas y ventanas del Kit (el Decal Workspace.Studs del place)
}

-- "rbxassetid://N" o nil si aun no hay imagen para esa clave
function Iconos.id(nombre: string): string?
	local n = Iconos.IMAGENES[nombre]
	if typeof(n) == "number" and n > 0 then
		return "rbxassetid://" .. tostring(n)
	end
	return nil
end

function Iconos.existe(nombre: string): boolean
	return Iconos.IMAGENES[nombre] ~= nil
end

return Iconos
