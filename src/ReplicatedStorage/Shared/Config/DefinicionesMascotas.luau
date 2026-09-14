--!strict
--[[
	DefinicionesMascotas
	Las 41 mascotas de basura reciclada: 4 sets x (4 Comun + 3 Rara + 3 Epica)
	mas el Rey Reciclon (Mitica), equivalente directo del Kotalion del original.

	Resistencia y Poder son VALOR DE COLECCION, no hay combate (igual que HP/ATK
	en KOTAMON). La pasiva solo actua mientras la mascota esta EXHIBIDA en el
	pedestal de tu base: asi exhibir tiene un motivo ademas de presumir.

	"forma" elige la silueta base dentro del vocabulario del set en
	Utilidades/ModelosMascota, para que dos mascotas del mismo set no sean
	identicas en whitebox.
]]

export type Pasiva = {
	tipo: string, -- "bonusMaterial" | "bonusTodo"
	material: string?,
	valor: number,
}

export type Mascota = {
	id: string,
	nombre: string,
	set: string,
	material: string,
	rareza: string, -- "Comun" | "Rara" | "Epica" | "Mitica"
	resistencia: number,
	poder: number,
	forma: number,
	descripcion: string,
	pasiva: Pasiva,
}

export type Set = {
	id: string,
	nombre: string,
	material: string,
	vibra: string,
}

local DefinicionesMascotas = {}

DefinicionesMascotas.SETS = {
	{ id = "Chatarrin", nombre = "Chatarrín", material = "Metal", vibra = "Latas, tornillos, tuberías: mascotas robóticas y brillantes" },
	{ id = "Plastin", nombre = "Plastín", material = "Plastico", vibra = "Botellas, tapas, bolsas: mascotas elásticas y coloridas" },
	{ id = "Cartonin", nombre = "Cartonín", material = "Papel", vibra = "Cajas, periódicos, rollos: mascotas suaves y torpes" },
	{ id = "Mostrenco", nombre = "Mostrenco", material = "Organico", vibra = "Cáscaras y restos sin identificar: espeluznantes-tiernas" },
}

DefinicionesMascotas.RAREZAS = { "Comun", "Rara", "Epica", "Mitica" }
DefinicionesMascotas.NOMBRE_RAREZA = { Comun = "Común", Rara = "Rara", Epica = "Épica", Mitica = "Mítica" }

DefinicionesMascotas.ESTADOS = { "Dañada", "Regular", "Buena", "Excelente", "Perfecta" }
DefinicionesMascotas.ESTADO_MAX = 5

-- Porcentaje de bonus por rareza (pasiva "bonusMaterial")
local BONUS_POR_RAREZA = { Comun = 0.02, Rara = 0.04, Epica = 0.06 }

local function mascota(
	id: string,
	nombre: string,
	set: string,
	rareza: string,
	resistencia: number,
	poder: number,
	forma: number,
	descripcion: string
): Mascota
	local material = "Mixto"
	for _, s in DefinicionesMascotas.SETS do
		if s.id == set then
			material = s.material
		end
	end
	local pasiva: Pasiva
	if rareza == "Mitica" then
		pasiva = { tipo = "bonusTodo", valor = 0.10 }
	else
		pasiva = { tipo = "bonusMaterial", material = material, valor = BONUS_POR_RAREZA[rareza] }
	end
	return {
		id = id,
		nombre = nombre,
		set = set,
		material = material,
		rareza = rareza,
		resistencia = resistencia,
		poder = poder,
		forma = forma,
		descripcion = descripcion,
		pasiva = pasiva,
	}
end

DefinicionesMascotas.LISTA = {
	-- === Chatarrín (Metal) ===
	mascota("latita", "Latita", "Chatarrin", "Comun", 14, 12, 1, "Una lata de refresco con patitas de clip."),
	mascota("tornillin", "Tornillín", "Chatarrin", "Comun", 18, 20, 2, "Gira sobre sí mismo cuando se emociona."),
	mascota("clavito", "Clavito", "Chatarrin", "Comun", 10, 28, 3, "Pequeño, puntiagudo y muy leal."),
	mascota("tuberco", "Tuberco", "Chatarrin", "Comun", 26, 14, 4, "Un codo de tubería que silba al andar."),
	mascota("engranin", "Engranín", "Chatarrin", "Rara", 40, 36, 1, "Sus dientes encajan con cualquier cosa."),
	mascota("robolata", "Robolata", "Chatarrin", "Rara", 48, 42, 2, "Parpadea con dos tapas de rosca."),
	mascota("chispazo", "Chispazo", "Chatarrin", "Rara", 30, 58, 3, "Huele a tostadora vieja."),
	mascota("ferroton", "Ferrotón", "Chatarrin", "Epica", 95, 62, 1, "Pesa como una nevera y ronronea como una."),
	mascota("cromadon", "Cromadón", "Chatarrin", "Epica", 70, 84, 2, "Se ve reflejado y se saluda a sí mismo."),
	mascota("magnetron", "Magnetrón", "Chatarrin", "Epica", 78, 96, 3, "Atrae cucharas desde tres cuadras."),

	-- === Plastín (Plástico) ===
	mascota("botellin", "Botellín", "Plastin", "Comun", 12, 14, 1, "Hace 'plop' cuando lo aprietas."),
	mascota("tapita", "Tapita", "Plastin", "Comun", 16, 10, 2, "Colecciona otras tapitas. Es su hobby."),
	mascota("bolsuki", "Bolsuki", "Plastin", "Comun", 8, 24, 3, "Vuela si hay viento. Vuelve si hay comida."),
	mascota("pajito", "Pajito", "Plastin", "Comun", 22, 18, 4, "Delgado como una pajita porque ES una pajita."),
	mascota("elastiko", "Elastiko", "Plastin", "Rara", 34, 46, 1, "Se estira el doble y vuelve igual."),
	mascota("burbujin", "Burbujín", "Plastin", "Rara", 52, 30, 2, "Plástico de burbujas. Nadie resiste apretarlo."),
	mascota("tupperin", "Tupperín", "Plastin", "Rara", 44, 44, 3, "Guarda cosas dentro. Nunca la tapa correcta."),
	mascota("polimero", "Polímero", "Plastin", "Epica", 66, 90, 1, "Cadena larguísima de moléculas con carita."),
	mascota("neoplast", "Neoplast", "Plastin", "Epica", 88, 72, 2, "Brilla bajo la luz negra de la caseta."),
	mascota("vinilon", "Vinilón", "Plastin", "Epica", 100, 60, 3, "Un disco viejo que todavía suena."),

	-- === Cartonín (Papel/Cartón) ===
	mascota("cajita", "Cajita", "Cartonin", "Comun", 20, 10, 1, "Cualquier gato la envidiaría."),
	mascota("periodin", "Periodín", "Cartonin", "Comun", 10, 22, 2, "Siempre trae noticias de ayer."),
	mascota("rollito", "Rollito", "Cartonin", "Comun", 16, 16, 3, "El tubo del papel higiénico, con orgullo."),
	mascota("papelon", "Papelón", "Cartonin", "Comun", 28, 12, 4, "Una bola de papel arrugado con mucho carácter."),
	mascota("origamo", "Origamo", "Cartonin", "Rara", 36, 50, 1, "Cambia de forma cuando nadie mira."),
	mascota("libretin", "Libretín", "Cartonin", "Rara", 56, 32, 2, "Tiene apuntado todo lo que pasa en el patio."),
	mascota("cartonazo", "Cartonazo", "Cartonin", "Rara", 46, 40, 3, "Caja de electrodoméstico. Enorme y torpe."),
	mascota("papiro", "Papiro", "Cartonin", "Epica", 74, 80, 1, "Más viejo que Doña Chatarra, dicen."),
	mascota("enciclopedio", "Enciclopedio", "Cartonin", "Epica", 98, 64, 2, "Lo sabe todo hasta la letra M."),
	mascota("cartonio", "Cartonio", "Cartonin", "Epica", 82, 86, 3, "Cartón prensado tan denso que casi es metal."),

	-- === Mostrenco (Orgánico / Misterio) ===
	mascota("cascaron", "Cascarón", "Mostrenco", "Comun", 24, 12, 1, "Cáscara de huevo. Dentro no hay nada... ¿o sí?"),
	mascota("semillin", "Semillín", "Mostrenco", "Comun", 12, 20, 2, "Si lo riegas no pasa nada. Sigue intentándolo."),
	mascota("hojarasca", "Hojarasca", "Mostrenco", "Comun", 14, 18, 3, "Un montoncito de hojas que se mueve solo."),
	mascota("pepita", "Pepita", "Mostrenco", "Comun", 18, 26, 4, "Pepita de aguacate con cara de sueño."),
	mascota("mohosin", "Mohosín", "Mostrenco", "Rara", 42, 38, 1, "Peludito, verde y sorprendentemente cariñoso."),
	mascota("fantasmita", "Fantasmita", "Mostrenco", "Rara", 30, 60, 2, "Nadie sabe de qué está hecho. Él tampoco."),
	mascota("raicilla", "Raicilla", "Mostrenco", "Rara", 54, 34, 3, "Se agarra al suelo si intentas moverlo."),
	mascota("compostor", "Compostor", "Mostrenco", "Epica", 96, 68, 1, "Convierte cualquier cosa en tierra buena."),
	mascota("espectron", "Espectrón", "Mostrenco", "Epica", 62, 100, 2, "La cosa más rara jamás sacada de un montón."),
	mascota("musgron", "Musgrón", "Mostrenco", "Epica", 90, 74, 3, "Musgo de siglos con forma de oso."),

	-- === Mítica ===
	mascota("rey_reciclon", "Rey Reciclón", "Rey", "Mitica", 150, 150, 1, "Un poco de cada material y toda la basura del mundo a sus pies. Solo se obtiene completando los 4 sets."),
}

DefinicionesMascotas.POR_ID = {} :: { [string]: Mascota }
for _, m in DefinicionesMascotas.LISTA do
	assert(DefinicionesMascotas.POR_ID[m.id] == nil, "id de mascota duplicado: " .. m.id)
	DefinicionesMascotas.POR_ID[m.id] = m
end

DefinicionesMascotas.ID_REY = "rey_reciclon"

function DefinicionesMascotas.obtener(id: string): Mascota?
	return DefinicionesMascotas.POR_ID[id]
end

function DefinicionesMascotas.porSet(setId: string): { Mascota }
	local lista = {}
	for _, m in DefinicionesMascotas.LISTA do
		if m.set == setId then
			table.insert(lista, m)
		end
	end
	return lista
end

function DefinicionesMascotas.porRareza(rareza: string): { Mascota }
	local lista = {}
	for _, m in DefinicionesMascotas.LISTA do
		if m.rareza == rareza then
			table.insert(lista, m)
		end
	end
	return lista
end

function DefinicionesMascotas.nombreEstado(estado: number): string
	return DefinicionesMascotas.ESTADOS[math.clamp(estado, 1, DefinicionesMascotas.ESTADO_MAX)]
end

function DefinicionesMascotas.textoPasiva(m: Mascota): string
	local pct = string.format("%d%%", math.floor(m.pasiva.valor * 100 + 0.5))
	if m.pasiva.tipo == "bonusTodo" then
		return "+" .. pct .. " $ al reciclar cualquier material"
	end
	local nombres = { Metal = "metal", Plastico = "plástico", Papel = "papel", Organico = "orgánico" }
	return "+" .. pct .. " $ al reciclar " .. (nombres[m.pasiva.material or ""] or "")
end

-- Comprobaciones de integridad: 4 sets x 10 + Rey.
do
	local total = #DefinicionesMascotas.LISTA
	assert(total == 41, "se esperaban 41 mascotas, hay " .. total)
	for _, s in DefinicionesMascotas.SETS do
		local conteo = { Comun = 0, Rara = 0, Epica = 0 }
		for _, m in DefinicionesMascotas.porSet(s.id) do
			conteo[m.rareza] += 1
		end
		assert(conteo.Comun == 4 and conteo.Rara == 3 and conteo.Epica == 3, "set mal formado: " .. s.id)
	end
end

return DefinicionesMascotas
