--!strict
--[[
	Iconos
	Registro de las imagenes de la interfaz: un id de asset por clave. Solo
	datos. 0 = todavia no hay imagen (misma convencion que Config/Productos).

	La UI nunca pide una imagen directamente: pasa por Componentes.icono, que
	usa la imagen si aqui hay id y, si no, la dibuja con Utilidades/Glifos. Asi
	la interfaz esta terminada aunque el arte llegue despues, y cada imagen se
	activa cambiando un numero, sin tocar logica.

	Las claves son los nombres de archivo de assets/ui/<clave>.png (ver
	assets/ui/README.md para el brief de cada una). Las sube
	herramientas/servir-fuentes.ps1 + upload_image del MCP de Studio.
]]

local Iconos = {}

Iconos.IMAGENES = {
	-- HUD (prioridad 1)
	billete = 0,
	cartas = 0,
	gema = 0,
	rayo = 0,
	bolsa = 0,
	libreta = 0,
	telefono = 0,
	trofeo = 0,
	casa = 0,
	montana = 0,
	lanzar = 0,
	mano = 0,
	raton = 0,
	lata = 0,
	flecha = 0,

	-- Paneles (prioridad 2)
	sobre = 0,
	contenedorDorado = 0,
	estrella = 0,
	corona = 0,
	check = 0,
	candado = 0,
	corazon = 0,
	nota = 0,
	figurina = 0,
	cinta = 0,
	engranaje = 0,
	iman = 0,
	bota = 0,
	cofre = 0,
	cruz = 0,

	-- Sets de mascotas
	setMetal = 0,
	setPlastico = 0,
	setPapel = 0,
	setOrganico = 0,
	setRey = 0,

	-- Imagenes grandes (prioridad 1 las manos, 3 el resto)
	manosVacia = 0,
	manosMedia = 0,
	manosLlena = 0,
	marcoCarta = 0,
	papel = 0,
	logo = 0,
	retratoChatarra = 0,
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
