--!strict
--[[
	Sonidos
	Registro del audio del juego: un asset por clave. Solo datos, como
	Config/Iconos con las imagenes: el codigo (Client/Sonido) pide una clave
	y nunca un rbxassetid suelto, asi cambiar un sonido es cambiar un numero
	aqui. id 0 = esa clave se calla (sin error), la misma convencion que
	Iconos y Productos.

	Los ids son los RECOMENDADOS de docs/Audio-propuesta.md (decision del
	usuario, 22 oct): biblioteca con licencia de Roblox (cuentas Roblox,
	APMOfficial y ProSoundEffects), que cualquier experiencia puede usar. El
	usuario los escucha jugando y cambia aqui los que no le gusten; las
	alternativas de cada clave estan en ese documento. Tambien estan los
	"opcionales" del documento que solo tenian un candidato (falloAviso,
	contarDinero, pestana): si sobran, id 0.

	Volumen = Sound.Volume dentro de su grupo. Es un punto de partida: APM y
	Pro Sound Effects no vienen igualados y se ajusta de oido (sobre todo la
	musica frente a los efectos).

	Campos de cada clave (Def):
	  id           asset de audio (0 = callado)
	  volumen      Sound.Volume
	  grupo        "Efectos" | "Musica": el SoundGroup de SoundService que el
	               ajuste del jugador (perfil.ajustes) pone a 1 o a 0
	  modo         "2D" (interfaz: solo lo oye el jugador) | "3D" (en el
	               mundo, con distancia: cada cliente lo reproduce al ver el
	               evento, porque lo que suena en un cliente no se replica)
	  bucle?       Looped
	  cola?        con bucle: fraccion final del clip que se repite
	               (LoopRegion). La primera pasada suena entera y luego se
	               queda en ese tramo: la carga sube y se sostiene arriba
	  region?      { desde, hasta } en s: solo ese tramo (PlaybackRegion),
	               para recortar lo que dura de mas
	  tono?        { min, max }: PlaybackSpeed al azar en cada toque, para
	               que lo que se repite mucho no canse
	  volumenAlto? / tonoAlto?  a lo que llega un bucle con intensidad 1
	               (la carga llena, la trituradora triturando)
	  distancia?   3D: { RollOffMinDistance, RollOffMaxDistance }, con
	               RollOffMode InverseTapered (a la maxima ya no se oye)
	  voces?       cuantos de esa clave pueden sonar a la vez (2 por defecto;
	               el siguiente reinicia el mas antiguo). Vale para los
	               toques en 2D y en un punto; los pegados a algo que se mueve
	               (Sonido.tocar con padre) son un clon cada uno
	  espera?      s minimos entre dos toques de la clave
	  atenua?      la musica baja a este factor mientras suena

	La musica son claves del grupo Musica; MUSICA dice que listas rotan.

	Un campo mal escrito no rompe nada: al cargar se avisa en la consola y esa
	clave se calla hasta arreglarlo (ver el final).
]]

export type Def = {
	id: number,
	volumen: number,
	grupo: string, -- "Efectos" | "Musica"
	modo: string, -- "2D" | "3D"
	bucle: boolean?,
	cola: number?,
	region: { number }?,
	tono: { number }?,
	volumenAlto: number?,
	tonoAlto: number?,
	distancia: { number }?,
	voces: number?,
	espera: number?,
	atenua: number?,
}

local Sonidos = {}

Sonidos.LISTA = {
	-- =======================================================================
	-- Patio
	-- =======================================================================

	-- Cada pieza recogida (EfectoRecogida, el "+1"). Es lo que mas se repite:
	-- corto, blando y con el tono al azar. Como mucho 3 a la vez
	-- Roblox GUI - Bubble (Roblox)
	recoger = { id = 17208204604, volumen = 0.35, grupo = "Efectos", modo = "2D", tono = { 0.94, 1.08 }, voces = 3 },
	-- Un billete ("+$30") - Roblox GUI - Pickup (Roblox)
	billete = { id = 17208319162, volumen = 0.5, grupo = "Efectos", modo = "2D" },
	-- Un tesoro ("¡TESORO!") - Magic Glows Soft Clusters Of Chiming Hits 1 (ProSoundEffects)
	tesoro = { id = 9116394545, volumen = 0.6, grupo = "Efectos", modo = "2D" },
	-- La bolsa se llena, una vez por llenado (ControlPatio) - Musical Doorbell (d) (APM)
	bolsaLlena = { id = 1840084286, volumen = 0.5, grupo = "Efectos", modo = "2D" },
	-- Mantener F para lanzar: una pasada dura la carga (Bucle.durar) y se
	-- queda en su ultimo tramo mientras se mantiene; sube de volumen con ella
	-- Synth Zip Short High Pitch Ascending Bursts (ProSoundEffects)
	carga = { id = 9126089814, volumen = 0.3, volumenAlto = 0.45, grupo = "Efectos", modo = "2D", bucle = true, cola = 0.3 },
	-- La bolsa sale volando (SonidosMundo, en la bolsa: lo oyen los de
	-- alrededor). Con mas fuerza, mas grave (su atributo Fuerza); sin el, al
	-- azar en su tono - Slow Whoosh Beefy Airy Pass By 4 (ProSoundEffects)
	lanzar = { id = 9119227910, volumen = 0.6, grupo = "Efectos", modo = "3D", tono = { 0.9, 1.1 }, distancia = { 8, 60 } },
	-- La bolsa entra en uno de los 4 contenedores de color (cubo de plastico)
	-- Trash Can Impact 12 (ProSoundEffects)
	dentroGolpe = { id = 9120255466, volumen = 0.7, grupo = "Efectos", modo = "3D", distancia = { 10, 80 } },
	-- ... y en el general, el volquete metalico de la recicladora
	-- Dumpster Booms Hit Side 1 (ProSoundEffects)
	dentroGolpeGeneral = { id = 9114204770, volumen = 0.7, grupo = "Efectos", modo = "3D", distancia = { 10, 80 } },
	-- La fanfarria del "¡DENTRO!", para quien lanzo. Pasa cada minuto o menos:
	-- recortada a ~2 s. Bien separada, un tono mas alta (Celebraciones)
	-- Winner, variante "Bingo" (APM)
	dentro = { id = 1844442553, volumen = 0.45, grupo = "Efectos", modo = "2D", region = { 0, 2.2 } },
	-- La bolsa cae fuera (o rebota en la tapa de un contenedor cerrado): en
	-- el primer golpe contra el suelo o la pared - Deep Impacts 6 (ProSoundEffects)
	fallo = { id = 9114036494, volumen = 0.6, grupo = "Efectos", modo = "3D", distancia = { 6, 50 }, voces = 3 },
	-- Opcional del documento: la racha (de 2 o mas) se pierde con un fallo
	-- Loser, variante "Sorry" (APM)
	falloAviso = { id = 1844442622, volumen = 0.3, grupo = "Efectos", modo = "2D", espera = 1 },
	-- El dinero llega volando al contador (Celebraciones) - CoinTransfer_01 (Roblox)
	cobro = { id = 127645268874265, volumen = 0.5, grupo = "Efectos", modo = "2D" },
	-- Opcional del documento: en bucle mientras la cifra cuenta
	-- Audio/Roblox_Pinball_Scoreboard_Tally_Loop_01 (Roblox)
	contarDinero = { id = 16480554151, volumen = 0.2, grupo = "Efectos", modo = "2D", bucle = true },

	-- =======================================================================
	-- Progreso y recompensas
	-- =======================================================================

	-- Un nivel de mejora (y pases de Robux) - Magic Transformation 15 (ProSoundEffects)
	mejora = { id = 9116422179, volumen = 0.55, grupo = "Efectos", modo = "2D" },
	-- Un rebirth: el momento mas grande, con la musica a la mitad
	-- Fortune Fun "Star Prize" (APM)
	rebirth = { id = 1846251722, volumen = 0.7, grupo = "Efectos", modo = "2D", atenua = 0.5 },
	-- ... y su capa de magia, a la vez - Magic Burst 1 (ProSoundEffects)
	rebirthMagia = { id = 9116384485, volumen = 0.5, grupo = "Efectos", modo = "2D" },
	-- La tarjeta de insignia o de record. Varias seguidas (al entrar) suenan
	-- una vez - Correct Answer 3 (APM)
	insignia = { id = 1839997938, volumen = 0.6, grupo = "Efectos", modo = "2D", atenua = 0.5, espera = 1 },
	-- Pedido cumplido y premio del dia (llegan juntos al cumplir el tercero:
	-- suena uno) - Funfair Fun, sting (APM)
	regalo = { id = 9038314266, volumen = 0.6, grupo = "Efectos", modo = "2D", espera = 0.8 },

	-- =======================================================================
	-- Interfaz (los paquetes de interfaz de Roblox: una sola familia)
	-- =======================================================================

	-- Cualquier boton del Kit, los del HUD y los interruptores - Roblox_UI_Bright_Click
	clic = { id = 15675059323, volumen = 0.3, grupo = "Efectos", modo = "2D" },
	-- Se abre una ventana (Menu) - Roblox_UI_Paper_Swipe
	panelAbrir = { id = 15675037413, volumen = 0.3, grupo = "Efectos", modo = "2D" },
	-- Se cierra (vuelve a no haber ninguna) - Roblox GUI - Back
	panelCerrar = { id = 17208186900, volumen = 0.3, grupo = "Efectos", modo = "2D" },
	-- Opcional del documento: otra pestana (Kit/Pestanas) - Roblox GUI - Tab
	pestana = { id = 17208408337, volumen = 0.3, grupo = "Efectos", modo = "2D" },
	-- Algo se rechaza (burbujas de AvisosMundo, sin dinero, bolsa llena):
	-- suave y como mucho uno cada 0,3 s - Roblox GUI - Negative
	denegado = { id = 17208353912, volumen = 0.4, grupo = "Efectos", modo = "2D", espera = 0.3 },

	-- =======================================================================
	-- Las cinco recicladoras (3D a volumen bajo: solo se oye la de cerca)
	-- =======================================================================

	-- Los rodillos giran siempre; triturando, mas deprisa y algo mas fuerte
	-- Comic Engine Constant 1 (ProSoundEffects)
	trituradora = { id = 9112760393, volumen = 0.15, volumenAlto = 0.2, tonoAlto = 1.15, grupo = "Efectos", modo = "3D", bucle = true, distancia = { 6, 40 } },
	-- La cinta, mientras lleva basura
	-- Audio/Roblox_Pinball_Rolling_Metal_Tracks_Loop_01 (Roblox)
	cinta = { id = 16480554578, volumen = 0.18, grupo = "Efectos", modo = "3D", bucle = true, distancia = { 6, 40 } },
	-- Sale el bloque prensado - Trash Can Crush 1 (ProSoundEffects)
	prensa = { id = 9120253198, volumen = 0.4, grupo = "Efectos", modo = "3D", distancia = { 6, 40 } },

	-- =======================================================================
	-- Musica (instrumental; las "underscore"/"NoMel" no llevan la melodia
	-- principal y cansan menos)
	-- =======================================================================

	-- El fondo del patio, en lista (MUSICA.patio)
	musicaPatio1 = { id = 9045567469, volumen = 0.3, grupo = "Musica", modo = "2D" }, -- Happy Place underscore (APM)
	musicaPatio2 = { id = 9040170470, volumen = 0.3, grupo = "Musica", modo = "2D" }, -- Tiny Crafts (a) (APM)
	musicaPatio3 = { id = 9048749096, volumen = 0.3, grupo = "Musica", modo = "2D" }, -- Daily Affirmation - Alt1, NoMel (APM)
	-- Mientras dura el Turbo (MUSICA.turbo) - Cheat Code (APM)
	musicaTurbo = { id = 1837351012, volumen = 0.35, grupo = "Musica", modo = "2D" },
} :: { [string]: Def }

-- Listas de musica (claves de LISTA). El patio rota en orden aleatorio sin
-- repetir la ultima: ninguna pista de APM es un bucle sin costuras (tienen
-- entrada y final), por eso lista con fundido y no Looped.
Sonidos.MUSICA = {
	patio = { "musicaPatio1", "musicaPatio2", "musicaPatio3" },
	turbo = { "musicaTurbo" },
}

-- s del fundido entre dos pistas
Sonidos.FUNDIDO_MUSICA = 2
-- El Turbo dura 10-15 min: su musica suena como mucho estas veces y vuelve
-- la del patio (si suena todo el Turbo, cansa: docs/Audio-propuesta §5.2)
Sonidos.REPETICIONES_TURBO = 2

-- "rbxassetid://N", o nil si la clave no existe o esta callada (id 0)
function Sonidos.id(clave: string): string?
	local def = Sonidos.LISTA[clave]
	if def and def.id > 0 then
		return "rbxassetid://" .. tostring(def.id)
	end
	return nil
end

function Sonidos.existe(clave: string): boolean
	return Sonidos.LISTA[clave] ~= nil
end

-- Un campo mal escrito al cambiar un sonido no debe romper el juego (Sonido
-- lo carga la UI entera a traves del Kit): se avisa en la consola y esa
-- clave se calla (id 0) hasta que se arregle. Devuelve el campo que falla.
local function campoMal(def: Def): string?
	if typeof(def.id) ~= "number" or def.id < 0 or def.id % 1 ~= 0 then
		return "id"
	elseif typeof(def.volumen) ~= "number" or def.volumen < 0 or def.volumen > 10 then
		return "volumen"
	elseif def.grupo ~= "Efectos" and def.grupo ~= "Musica" then
		return "grupo"
	elseif def.modo ~= "2D" and def.modo ~= "3D" then
		return "modo"
	end
	local region = def.region
	if region ~= nil and not (#region == 2 and region[1] >= 0 and region[2] > region[1]) then
		return "region"
	end
	local tono = def.tono
	if tono ~= nil and not (#tono == 2 and tono[1] > 0 and tono[2] >= tono[1]) then
		return "tono"
	end
	local distancia = def.distancia
	if distancia ~= nil and not (#distancia == 2 and distancia[1] > 0 and distancia[2] > distancia[1]) then
		return "distancia"
	end
	local cola = def.cola
	if cola ~= nil and not (def.bucle == true and cola > 0 and cola < 1) then
		return "cola"
	end
	return nil
end

for clave, def in Sonidos.LISTA do
	if typeof(def) ~= "table" then
		warn("[Config/Sonidos] " .. clave .. " no es una tabla: se quita")
		Sonidos.LISTA[clave] = nil
		continue
	end
	local campo = campoMal(def)
	if campo then
		warn(string.format("[Config/Sonidos] %s: el campo %s no vale; la clave se calla hasta arreglarlo", clave, campo))
		def.id = 0
	end
end
for nombre, lista in Sonidos.MUSICA do
	for i = #lista, 1, -1 do
		local def = Sonidos.LISTA[lista[i]]
		if def == nil or def.grupo ~= "Musica" then
			warn(string.format("[Config/Sonidos] MUSICA.%s: %s no es una clave de musica; se quita de la lista", nombre, tostring(lista[i])))
			table.remove(lista, i)
		end
	end
end

return Sonidos
