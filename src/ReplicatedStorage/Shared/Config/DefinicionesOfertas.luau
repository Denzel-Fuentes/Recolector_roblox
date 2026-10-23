--!strict
--[[
	DefinicionesOfertas
	Las ofertas en el momento justo (economia v4, K1 22 oct;
	docs/Economia-v4.md §5.6): las reglas generales, los cinco disparadores en
	orden de prioridad y la funcion pura que decide si una oferta se puede
	ensenar ahora (debeOfrecer). Solo datos y cuentas, sin requires: el
	estado (la sesion, lo pendiente) lo lleva Services/Ofertas, que arma el
	contexto con el perfil y los pases y manda la oferta al cliente
	(UI/Oferta). Al ser pura, la prueba ofertaReglas recorre cada regla con
	contextos inventados.

	=== Normas de Roblox con menores (§5.7) ===
	Precios fijos, sin cuentas atras, sin "solo hoy", sin precios tachados y
	sin la palabra oferta en pantalla (los titulos de Textos.OFERTAS); dos
	botones iguales "Comprar" y "Ahora no" (tres con el Turbo); como mucho
	una por sesion y tres por semana. Nada de vender dinero, saltos de
	rebirth ni automatizacion (regla v2): solo se ofrece lo que ya esta en la
	tienda.

	=== Reglas generales (GLOBAL), todas a la vez ===
	  1 con pasosTutorial pasos hechos (el primer pedido) y desde la sesion
	    sesionMinima (la de la oferta si pide mas); nunca en los
	    minutosEnSesion primeros minutos de una sesion
	  2 nunca si ya lo tiene (pases) ni el Turbo con Turbo guardado; nunca lo
	    que tiene id 0 (sin crear en el Creator Dashboard): se ofrecen solo
	    las opciones con id y sin comprar, y sin ninguna no hay oferta
	  3 porSesion por sesion y porSemana en 7 dias moviles (historial)
	  4 ninguna en las horasTrasCompra siguientes a una compra con Robux
	  5 en un momento tranquilo: el disparador lo da el servidor (tras un
	    deposito, al renacer) y el cliente espera hasta esperaMomento s a no
	    tener panel abierto, ni celebracion, ni lanzamiento cargando; si no
	    llega, se descarta y no cuenta (Services/Ofertas, UI/Oferta)
	  8 tras un "Ahora no", diasTrasAhoraNo dias sin esa oferta; con
	    rechazosMax, no vuelve sola (sigue en la tienda)
	(6 y 7, los botones iguales y sin presion, son de la ventana: UI/Oferta.)

	=== Cada disparador (LISTA, en orden de prioridad) ===
	  momento   "inicioSesion" el primer momento tranquilo de la sesion en que
	            ya se pueden ensenar (tras un deposito o al cobrar el
	            calendario, momento "calendario", si se cablea); "deposito";
	            "rebirth" (con rebirths = los que la disparan); y
	            "finTurboGanado" (el primer deposito despues de acabarse un
	            Turbo ganado, no comprado: lo avisa Services/Turbo)
	  sesiones  la k-esima vez sale como pronto en la sesion sesiones[k] (el
	            Pack: la 2.a y otra vez la 4.a)
	  total     veces como mucho; rebirthsMax: nunca con mas rebirths
	  intentosBolsaLlena / nivelBolsa  los de la sesion y la mejora Bolsa
	  cadaDias  dias minimos entre dos; porSesion / porSemana  topes propios
	  titulo, texto, icono  claves de Textos.OFERTAS y de Config/Iconos;
	            valores = "multiplicador": {mult} y {mult2} (el de ahora y el
	            doble, el de Dinero x2)

	=== porSemana de una oferta sin su historial ===
	Por oferta, el perfil guarda solo { vistas, ultima, rechazos }
	(Services/Perfiles, perfil.ofertas.porId): "n por semana" se garantiza
	separandolas 7/n dias. Es mas estricto que contar en una ventana, nunca
	mas permisivo. El tope global si cuenta: historial lleva la hora de cada
	una ensenada (recortar lo deja en los ultimos 7 dias).
]]

export type Opcion = { tipo: string, id: string } -- tipo "pase" | "producto"

export type Definicion = {
	id: string, -- la clave en perfil.ofertas.porId
	pases: { string }?, -- ids de Config/Productos.PASES
	productos: { string }?, -- ids de Config/Productos.PRODUCTOS
	momento: string,
	sesiones: { number }?,
	total: number?,
	rebirthsMax: number?,
	rebirths: { number }?,
	intentosBolsaLlena: number?,
	nivelBolsa: number?,
	cadaDias: number?,
	sesionMinima: number?,
	porSesion: number?,
	porSemana: number?,
	titulo: string, -- clave de Textos ("OFERTAS.packTitulo")
	texto: string,
	icono: string,
	valores: string?,
}

export type Registro = { vistas: number, ultima: number, rechazos: number }

-- Todo lo que hace falta saber para decidir (lo arma Services/Ofertas)
export type Contexto = {
	momento: string, -- "deposito" | "rebirth" | "calendario"
	rebirthHecho: number?, -- con momento "rebirth": el que se acaba de hacer
	ahora: number, -- os.time()
	tutorial: number, -- pasos del tutorial completados
	sesion: number, -- numero de esta sesion (estadistica sesiones)
	segundosSesion: number,
	mostradasSesion: number, -- ensenadas en esta sesion, todas
	mostradasSesionPorId: { [string]: number },
	historial: { number }, -- os.time() de cada una ensenada
	porId: { [string]: Registro },
	ultimaRobux: number, -- os.time() de la ultima compra con Robux (0 = nunca)
	rebirths: number,
	turboRestante: number,
	intentosBolsaLlena: number, -- en esta sesion
	nivelBolsa: number,
	turboGanadoAcabado: boolean,
	tienePase: (string) -> boolean,
	idRoblox: (tipo: string, id: string) -> number, -- 0 = sin crear
}

local DefinicionesOfertas = {}

DefinicionesOfertas.DIA = 86400
DefinicionesOfertas.SEMANA = 7 * 86400

DefinicionesOfertas.GLOBAL = {
	pasosTutorial = 7, -- con 7 pasos completados (el primer pedido)
	sesionMinima = 2, -- nunca en la primera sesion
	minutosEnSesion = 3,
	porSesion = 1,
	porSemana = 3,
	horasTrasCompra = 24,
	esperaMomento = 60, -- s para encontrar un momento tranquilo; si no, se descarta
	diasTrasAhoraNo = 7,
	rechazosMax = 3, -- con 3 "Ahora no", no vuelve sola
}

DefinicionesOfertas.LISTA = {
	{
		id = "PackInicio",
		pases = { "PackInicio" },
		momento = "inicioSesion",
		sesiones = { 2, 4 },
		total = 2,
		rebirthsMax = 1,
		titulo = "OFERTAS.packTitulo",
		texto = "OFERTAS.packTexto",
		icono = "estrella",
	},
	{
		id = "DineroX2",
		pases = { "DineroX2" },
		momento = "rebirth",
		rebirths = { 1, 3 },
		total = 2,
		titulo = "OFERTAS.dineroTitulo",
		texto = "OFERTAS.dineroTexto",
		icono = "billete",
		valores = "multiplicador",
	},
	{
		id = "VIP",
		pases = { "VIP" },
		momento = "rebirth",
		rebirths = { 2 },
		total = 1,
		titulo = "OFERTAS.vipTitulo",
		texto = "OFERTAS.vipTexto",
		icono = "corona",
	},
	{
		id = "BolsaXL",
		pases = { "BolsaXL" },
		momento = "deposito",
		intentosBolsaLlena = 5,
		nivelBolsa = 3,
		cadaDias = 7,
		total = 3,
		titulo = "OFERTAS.bolsaXLTitulo",
		texto = "OFERTAS.bolsaXLTexto",
		icono = "bolsa",
	},
	{
		id = "Turbo",
		productos = { "Turbo15", "Turbo60" },
		momento = "finTurboGanado",
		sesionMinima = 3,
		porSesion = 1,
		porSemana = 2,
		titulo = "OFERTAS.turboTitulo",
		texto = "OFERTAS.turboTexto",
		icono = "rayo",
	},
} :: { Definicion }

DefinicionesOfertas.POR_ID = {} :: { [string]: Definicion }
for _, def in DefinicionesOfertas.LISTA do
	DefinicionesOfertas.POR_ID[def.id] = def
end

local SIN_REGISTRO: Registro = { vistas = 0, ultima = 0, rechazos = 0 }

-- Lo de historial que cae en los 7 dias antes de `ahora` (copia nueva)
function DefinicionesOfertas.recortar(historial: { number }, ahora: number): { number }
	local recientes = {}
	for _, t in historial do
		if typeof(t) == "number" and ahora - t < DefinicionesOfertas.SEMANA then
			table.insert(recientes, t)
		end
	end
	return recientes
end

-- Lo que se puede comprar de una oferta ahora: con id de Roblox y, si es un
-- pase, sin tenerlo ya
function DefinicionesOfertas.opciones(def: Definicion, ctx: Contexto): { Opcion }
	local lista: { Opcion } = {}
	for _, id in def.pases or {} do
		if ctx.idRoblox("pase", id) ~= 0 and not ctx.tienePase(id) then
			table.insert(lista, { tipo = "pase", id = id })
		end
	end
	for _, id in def.productos or {} do
		if ctx.idRoblox("producto", id) ~= 0 then
			table.insert(lista, { tipo = "producto", id = id })
		end
	end
	return lista
end

local function momentoValido(def: Definicion, ctx: Contexto): boolean
	if def.momento == "rebirth" then
		return ctx.momento == "rebirth" and def.rebirths ~= nil and table.find(def.rebirths, ctx.rebirthHecho or -1) ~= nil
	elseif def.momento == "inicioSesion" then
		return ctx.momento == "deposito" or ctx.momento == "calendario"
	elseif def.momento == "deposito" then
		return ctx.momento == "deposito"
	elseif def.momento == "finTurboGanado" then
		return ctx.momento == "deposito" and ctx.turboGanadoAcabado
	end
	return false
end

-- Si `def` se puede ensenar con este contexto: (true, "ok") o (false, la
-- primera regla que lo impide). Los motivos (las pruebas los miran):
--   momento, loTiene, conTurbo, sinIds, tutorial, sesion, minutos,
--   trasCompra, porSesion, porSemana, rechazada, ahoraNo, total,
--   semanaOferta, cadaDias, rebirths, bolsaLlena, nivelBolsa
function DefinicionesOfertas.debeOfrecer(def: Definicion, ctx: Contexto): (boolean, string)
	local G = DefinicionesOfertas.GLOBAL
	local DIA = DefinicionesOfertas.DIA
	if not momentoValido(def, ctx) then
		return false, "momento"
	end
	-- 2: lo que ya tiene, el Turbo con Turbo, lo que no tiene id
	for _, id in def.pases or {} do
		if ctx.tienePase(id) then
			return false, "loTiene"
		end
	end
	if def.productos and ctx.turboRestante > 0 then
		return false, "conTurbo"
	end
	if #DefinicionesOfertas.opciones(def, ctx) == 0 then
		return false, "sinIds"
	end
	-- 1: tutorial, sesion y minutos
	if ctx.tutorial < G.pasosTutorial then
		return false, "tutorial"
	end
	if ctx.sesion < math.max(G.sesionMinima, def.sesionMinima or 0) then
		return false, "sesion"
	end
	if ctx.segundosSesion < G.minutosEnSesion * 60 then
		return false, "minutos"
	end
	-- 4: nada en las 24 h siguientes a una compra
	if ctx.ultimaRobux > 0 and ctx.ahora - ctx.ultimaRobux < G.horasTrasCompra * 3600 then
		return false, "trasCompra"
	end
	-- 3: topes por sesion y por semana
	if ctx.mostradasSesion >= G.porSesion then
		return false, "porSesion"
	end
	if def.porSesion and (ctx.mostradasSesionPorId[def.id] or 0) >= def.porSesion then
		return false, "porSesion"
	end
	if #DefinicionesOfertas.recortar(ctx.historial, ctx.ahora) >= G.porSemana then
		return false, "porSemana"
	end
	-- 8: los "Ahora no"
	local registro = ctx.porId[def.id] or SIN_REGISTRO
	if registro.rechazos >= G.rechazosMax then
		return false, "rechazada"
	end
	if registro.rechazos > 0 and ctx.ahora - registro.ultima < G.diasTrasAhoraNo * DIA then
		return false, "ahoraNo"
	end
	-- Las de la oferta
	if def.total and registro.vistas >= def.total then
		return false, "total"
	end
	if def.porSemana and registro.vistas > 0 and ctx.ahora - registro.ultima < DefinicionesOfertas.SEMANA / def.porSemana then
		return false, "semanaOferta"
	end
	if def.cadaDias and registro.vistas > 0 and ctx.ahora - registro.ultima < def.cadaDias * DIA then
		return false, "cadaDias"
	end
	if def.sesiones then
		local como = def.sesiones[registro.vistas + 1]
		if como and ctx.sesion < como then
			return false, "sesion"
		end
	end
	if def.rebirthsMax and ctx.rebirths > def.rebirthsMax then
		return false, "rebirths"
	end
	if def.intentosBolsaLlena and ctx.intentosBolsaLlena < def.intentosBolsaLlena then
		return false, "bolsaLlena"
	end
	if def.nivelBolsa and ctx.nivelBolsa < def.nivelBolsa then
		return false, "nivelBolsa"
	end
	return true, "ok"
end

-- La primera de LISTA (la de mas prioridad) que se puede ensenar, o nil y
-- por que no salio la primera cuyo momento si era este ("momento" si no
-- toca ninguna)
function DefinicionesOfertas.elegir(ctx: Contexto): (Definicion?, string)
	local motivo = "momento"
	for _, def in DefinicionesOfertas.LISTA do
		local puede, porque = DefinicionesOfertas.debeOfrecer(def, ctx)
		if puede then
			return def, "ok"
		elseif motivo == "momento" then
			motivo = porque
		end
	end
	return nil, motivo
end

return DefinicionesOfertas
