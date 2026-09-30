--!strict
--[[
	DefinicionesMascotas
	Las 41 mascotas de basura reciclada del diseno v2: 4 sets (uno por
	material) x (4 Comun + 3 Rara + 3 Epica) mas el Rey Reciclon (Mitica).

	En la v2 una mascota NO es una copia con estado: la tienes o no, y tiene
	un NIVEL (1..5). Se consiguen juntando FRAGMENTOS que salen entre la
	basura de los montones (decision del usuario, 29 sep: las capsulas del
	medidor las daban demasiado rapido). Cada set monta una mascota a la vez:
	el primer fragmento decide cual (rareza con pity y, dentro, una que no
	tengas) y hacen falta FRAGMENTOS_RAREZA para completarla; si ya la tienes
	sube de nivel y, pasado el 5, se convierte en dinero (Services/Fragmentos).
	Su efecto se nota en el patio: la equipada te sigue, da un bonus al
	dinero de su material y, si es Rara o Epica, atrae sola las piezas de su
	material (un iman solo para el).

	Por que 41 (la auditoria las habia recortado a 10): cada set avanza con
	los fragmentos de su material, y la zona del patio que eliges (mas metal
	u organico tras las barreras) decide cuales salen mas. Las definiciones
	son las del juego original (commit fd601a9) sin Resistencia ni Poder,
	que eran valor de coleccion sin uso.

	"forma" elige la silueta dentro del vocabulario del set en
	Utilidades/ModelosMascota.
]]

export type Mascota = {
	id: string,
	nombre: string,
	set: string,
	material: string,
	rareza: string, -- "Comun" | "Rara" | "Epica" | "Mitica"
	forma: number,
	descripcion: string,
}

export type Set = {
	id: string,
	nombre: string,
	material: string,
	rebirth: number, -- rebirths con los que se abre (sus fragmentos empiezan a salir)
	vibra: string,
}

local DefinicionesMascotas = {}

-- En el orden en que se abren (Papel y Plastico desde el inicio, Metal con el
-- Rebirth 1, Organico con el 2, como sus zonas del patio): es el orden de
-- las pestanas del album.
DefinicionesMascotas.SETS = {
	{ id = "Cartonin", nombre = "Cartonín", material = "Papel", rebirth = 0, vibra = "Cajas, periódicos, rollos: mascotas suaves y torpes" },
	{ id = "Plastin", nombre = "Plastín", material = "Plastico", rebirth = 0, vibra = "Botellas, tapas, bolsas: mascotas elásticas y coloridas" },
	{ id = "Chatarrin", nombre = "Chatarrín", material = "Metal", rebirth = 1, vibra = "Latas, tornillos, tuberías: mascotas robóticas y brillantes" },
	{ id = "Mostrenco", nombre = "Mostrenco", material = "Organico", rebirth = 2, vibra = "Cáscaras y restos sin identificar: espeluznantes-tiernas" },
} :: { Set }

DefinicionesMascotas.RAREZAS = { "Comun", "Rara", "Epica", "Mitica" }
DefinicionesMascotas.NOMBRE_RAREZA = { Comun = "Común", Rara = "Rara", Epica = "Épica", Mitica = "Mítica" }

DefinicionesMascotas.NIVEL_MAX = 5

-- Bonus al dinero de su material: de nivel 1 a nivel 5, lineal.
DefinicionesMascotas.BONUS_RAREZA = {
	Comun = { 0.20, 0.40 },
	Rara = { 0.40, 0.80 },
	Epica = { 0.80, 1.60 },
} :: { [string]: { number } }
-- Iman solo para su material (studs). Las Comunes no atraen.
DefinicionesMascotas.IMAN_RAREZA = { Rara = 6, Epica = 10 } :: { [string]: number }
-- El Rey: a todos los materiales, y siempre contigo sin ocupar hueco
DefinicionesMascotas.BONUS_REY = 0.50
-- Una repetida con la mascota ya a nivel 5 se paga (x multiplicador de rebirth)
DefinicionesMascotas.VALOR_REPETIDA = { Comun = 100, Rara = 400, Epica = 1500 } :: { [string]: number }

-- === Fragmentos (Services/Fragmentos) ===
-- Los que hacen falta para completar una mascota de cada rareza: una Epica
-- se ve venir de lejos. La PRIMERA mascota del jugador es siempre Comun y
-- pide solo FRAGMENTOS_PRIMERA, para que llegue hacia el minuto 6-8 (el
-- gancho de los primeros 15 minutos); despues, una cada ~10 min al empezar
-- y mas seguido con la bolsa mejorada. Punto de partida, a calibrar.
DefinicionesMascotas.FRAGMENTOS_RAREZA = { Comun = 5, Rara = 8, Epica = 12 } :: { [string]: number }
DefinicionesMascotas.FRAGMENTOS_PRIMERA = 3
-- Pity POR SET, contado en mascotas empezadas: la 5.a seguida sin Rara o
-- mejor lo es, y la 20.a seguida sin Epica es Epica
DefinicionesMascotas.PITY = { rara = 5, epica = 20 }

local function mascota(id: string, nombre: string, set: string, rareza: string, forma: number, descripcion: string): Mascota
	local material = "Mixto"
	for _, s in DefinicionesMascotas.SETS do
		if s.id == set then
			material = s.material
		end
	end
	return {
		id = id,
		nombre = nombre,
		set = set,
		material = material,
		rareza = rareza,
		forma = forma,
		descripcion = descripcion,
	}
end

DefinicionesMascotas.LISTA = {
	-- === Cartonín (Papel/Cartón) ===
	mascota("cajita", "Cajita", "Cartonin", "Comun", 1, "Cualquier gato la envidiaría."),
	mascota("periodin", "Periodín", "Cartonin", "Comun", 2, "Siempre trae noticias de ayer."),
	mascota("rollito", "Rollito", "Cartonin", "Comun", 3, "El tubo del papel higiénico, con orgullo."),
	mascota("papelon", "Papelón", "Cartonin", "Comun", 4, "Una bola de papel arrugado con mucho carácter."),
	mascota("origamo", "Origamo", "Cartonin", "Rara", 1, "Cambia de forma cuando nadie mira."),
	mascota("libretin", "Libretín", "Cartonin", "Rara", 2, "Tiene apuntado todo lo que pasa en el patio."),
	mascota("cartonazo", "Cartonazo", "Cartonin", "Rara", 3, "Caja de electrodoméstico. Enorme y torpe."),
	mascota("papiro", "Papiro", "Cartonin", "Epica", 1, "Más viejo que Doña Chatarra, dicen."),
	mascota("enciclopedio", "Enciclopedio", "Cartonin", "Epica", 2, "Lo sabe todo hasta la letra M."),
	mascota("cartonio", "Cartonio", "Cartonin", "Epica", 3, "Cartón prensado tan denso que casi es metal."),

	-- === Plastín (Plástico) ===
	mascota("botellin", "Botellín", "Plastin", "Comun", 1, "Hace 'plop' cuando lo aprietas."),
	mascota("tapita", "Tapita", "Plastin", "Comun", 2, "Colecciona otras tapitas. Es su hobby."),
	mascota("bolsuki", "Bolsuki", "Plastin", "Comun", 3, "Vuela si hay viento. Vuelve si hay comida."),
	mascota("pajito", "Pajito", "Plastin", "Comun", 4, "Delgado como una pajita porque ES una pajita."),
	mascota("elastiko", "Elastiko", "Plastin", "Rara", 1, "Se estira el doble y vuelve igual."),
	mascota("burbujin", "Burbujín", "Plastin", "Rara", 2, "Plástico de burbujas. Nadie resiste apretarlo."),
	mascota("tupperin", "Tupperín", "Plastin", "Rara", 3, "Guarda cosas dentro. Nunca la tapa correcta."),
	mascota("polimero", "Polímero", "Plastin", "Epica", 1, "Cadena larguísima de moléculas con carita."),
	mascota("neoplast", "Neoplast", "Plastin", "Epica", 2, "Brilla bajo la luz negra de la caseta."),
	mascota("vinilon", "Vinilón", "Plastin", "Epica", 3, "Un disco viejo que todavía suena."),

	-- === Chatarrín (Metal) ===
	mascota("latita", "Latita", "Chatarrin", "Comun", 1, "Una lata de refresco con patitas de clip."),
	mascota("tornillin", "Tornillín", "Chatarrin", "Comun", 2, "Gira sobre sí mismo cuando se emociona."),
	mascota("clavito", "Clavito", "Chatarrin", "Comun", 3, "Pequeño, puntiagudo y muy leal."),
	mascota("tuberco", "Tuberco", "Chatarrin", "Comun", 4, "Un codo de tubería que silba al andar."),
	mascota("engranin", "Engranín", "Chatarrin", "Rara", 1, "Sus dientes encajan con cualquier cosa."),
	mascota("robolata", "Robolata", "Chatarrin", "Rara", 2, "Parpadea con dos tapas de rosca."),
	mascota("chispazo", "Chispazo", "Chatarrin", "Rara", 3, "Huele a tostadora vieja."),
	mascota("ferroton", "Ferrotón", "Chatarrin", "Epica", 1, "Pesa como una nevera y ronronea como una."),
	mascota("cromadon", "Cromadón", "Chatarrin", "Epica", 2, "Se ve reflejado y se saluda a sí mismo."),
	mascota("magnetron", "Magnetrón", "Chatarrin", "Epica", 3, "Atrae cucharas desde tres cuadras."),

	-- === Mostrenco (Orgánico / Misterio) ===
	mascota("cascaron", "Cascarón", "Mostrenco", "Comun", 1, "Cáscara de huevo. Dentro no hay nada... ¿o sí?"),
	mascota("semillin", "Semillín", "Mostrenco", "Comun", 2, "Si lo riegas no pasa nada. Sigue intentándolo."),
	mascota("hojarasca", "Hojarasca", "Mostrenco", "Comun", 3, "Un montoncito de hojas que se mueve solo."),
	mascota("pepita", "Pepita", "Mostrenco", "Comun", 4, "Pepita de aguacate con cara de sueño."),
	mascota("mohosin", "Mohosín", "Mostrenco", "Rara", 1, "Peludito, verde y sorprendentemente cariñoso."),
	mascota("fantasmita", "Fantasmita", "Mostrenco", "Rara", 2, "Nadie sabe de qué está hecho. Él tampoco."),
	mascota("raicilla", "Raicilla", "Mostrenco", "Rara", 3, "Se agarra al suelo si intentas moverlo."),
	mascota("compostor", "Compostor", "Mostrenco", "Epica", 1, "Convierte cualquier cosa en tierra buena."),
	mascota("espectron", "Espectrón", "Mostrenco", "Epica", 2, "La cosa más rara jamás sacada de un montón."),
	mascota("musgron", "Musgrón", "Mostrenco", "Epica", 3, "Musgo de siglos con forma de oso."),

	-- === Mítica ===
	mascota("rey_reciclon", "Rey Reciclón", "Rey", "Mitica", 1, "Un poco de cada material y toda la basura del mundo a sus pies. Llega al tener las 40."),
}

DefinicionesMascotas.POR_ID = {} :: { [string]: Mascota }
for _, m in DefinicionesMascotas.LISTA do
	assert(DefinicionesMascotas.POR_ID[m.id] == nil, "id de mascota duplicado: " .. m.id)
	DefinicionesMascotas.POR_ID[m.id] = m
end

DefinicionesMascotas.ID_REY = "rey_reciclon"

DefinicionesMascotas.SET_POR_ID = {} :: { [string]: Set }
DefinicionesMascotas.SET_POR_MATERIAL = {} :: { [string]: Set }
for _, s in DefinicionesMascotas.SETS do
	DefinicionesMascotas.SET_POR_ID[s.id] = s
	DefinicionesMascotas.SET_POR_MATERIAL[s.material] = s
end

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

-- Bonus al dinero de su material a un nivel dado (el Rey: a todo)
function DefinicionesMascotas.bonus(m: Mascota, nivel: number): number
	if m.rareza == "Mitica" then
		return DefinicionesMascotas.BONUS_REY
	end
	local tramo = DefinicionesMascotas.BONUS_RAREZA[m.rareza]
	if not tramo then
		return 0
	end
	local t = (math.clamp(nivel, 1, DefinicionesMascotas.NIVEL_MAX) - 1) / (DefinicionesMascotas.NIVEL_MAX - 1)
	return tramo[1] + (tramo[2] - tramo[1]) * t
end

-- Radio del iman de su material (0 = no atrae)
function DefinicionesMascotas.iman(m: Mascota): number
	return DefinicionesMascotas.IMAN_RAREZA[m.rareza] or 0
end

-- Un set esta abierto (salen y cuentan sus fragmentos) con sus rebirths
function DefinicionesMascotas.setAbierto(setId: string, rebirths: number): boolean
	local set = DefinicionesMascotas.SET_POR_ID[setId]
	return set ~= nil and rebirths >= set.rebirth
end

-- Lo mismo por material (el de una pieza o un fragmento)
function DefinicionesMascotas.materialAbierto(material: string, rebirths: number): boolean
	local set = DefinicionesMascotas.SET_POR_MATERIAL[material]
	return set ~= nil and rebirths >= set.rebirth
end

-- Fragmentos que pide completar una mascota de esa rareza
function DefinicionesMascotas.fragmentos(rareza: string): number
	return DefinicionesMascotas.FRAGMENTOS_RAREZA[rareza] or DefinicionesMascotas.FRAGMENTOS_RAREZA.Comun
end

-- Comprobaciones de integridad: 4 sets x (4/3/3) + Rey
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
	assert(DefinicionesMascotas.POR_ID[DefinicionesMascotas.ID_REY], "falta el Rey Reciclon")
end

return DefinicionesMascotas
