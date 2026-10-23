--!nonstrict
--[[
	Pruebas del catalogo de la economia v4 (K1, 22 oct; docs/Economia-v4.md
	§4.6 y §5): el Turbo que solo corre mientras se juega (turboPausa), su
	tope de compra (turboTope), los dos productos de Turbo (turboProductos),
	el Pack de inicio una sola vez (packInicioUnaVez), lo que da el VIP
	(vipVentajas), los cosmeticos nuevos (cosmeticosNuevos) y cada regla de
	las ofertas (ofertaReglas).

	Los relojes se sustituyen (Actividad.ahora, que es tambien el de Turbo;
	Ofertas.ahora y Ofertas.reloj): nada espera de verdad. Las compras se
	simulan con Monetizacion.otorgarProductoPorId y recibos de prueba, los
	pases poniendo pasesCache, y los ids de Roblox que hacen falta se ponen
	un momento. Todo lo tocado se devuelve al acabar, tambien si la prueba
	falla. Al acabar, la actividad del jugador queda olvidada (como si
	acabara de entrar): su Turbo, si tiene, en pausa hasta que haga algo.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local Productos = require(Config:WaitForChild("Productos"))
local DefinicionesCosmeticos = require(Config:WaitForChild("DefinicionesCosmeticos"))
local DefinicionesOfertas = require(Config:WaitForChild("DefinicionesOfertas"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Actividad = require(Servicios:WaitForChild("Actividad"))
local Turbo = require(Servicios:WaitForChild("Turbo"))
local Cosmeticos = require(Servicios:WaitForChild("Cosmeticos"))
local Ofertas = require(Servicios:WaitForChild("Ofertas"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador = Comunes.jugador

local Pruebas = {}

local DIA = 86400

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

local function igual(a: number?, b: number): boolean
	return a ~= nil and math.abs(a - b) <= 0.001
end

local function copiaJson(valor)
	return HttpService:JSONDecode(HttpService:JSONEncode(valor))
end

local function guid(): string
	return HttpService:GenerateGUID(false)
end

-- Lo que tocan las compras simuladas, para dejarlo como estaba
local function foto(p)
	return {
		turboRestante = p.turboRestante,
		recibos = table.clone(p.recibos),
		ultimaRobux = p.compras.ultimaRobux,
		packInicio = p.compras.packInicio,
		pasesCache = table.clone(p.pasesCache),
		modoDev = Monetizacion.modoDev(),
	}
end
local function devolver(j, p, f)
	p.turboRestante = f.turboRestante
	p.recibos = f.recibos
	p.compras.ultimaRobux = f.ultimaRobux
	p.compras.packInicio = f.packInicio
	p.pasesCache = f.pasesCache
	Monetizacion.fijarModoDev(f.modoDev)
	Monetizacion.alCambiarPases:Fire(j)
	Turbo.sincronizar(j)
	Perfiles.marcarSucio(j)
end

-- ===========================================================================
-- Turbo
-- ===========================================================================

-- Solo corre jugando: con una accion corre; a los 120 s sin hacer nada se
-- pausa (TurboPausado) y deja de bajar, aunque sigue valiendo x2; otra
-- accion lo reanuda; al salir se para y al volver espera a la primera
-- accion; al acabarse corriendo avisa alAcabar con ganado = true si era de
-- Turbo.anadir. Con el reloj de Actividad sustituido: cuentas exactas
function Pruebas.turboPausa()
	local j = jugador()
	local p = Perfiles.obtener(j)
	if not p then
		return "sin perfil => FALLO"
	end
	local turboAntes = p.turboRestante
	local relojAntes = Actividad.ahora
	local t = 10000
	local r = {}
	local acabados = {}
	local conexion = Turbo.alAcabar:Connect(function(quien, ganado)
		if quien == j then
			table.insert(acabados, ganado)
		end
	end)
	local exito, err = pcall(function()
		Actividad.ahora = function()
			return t
		end
		Actividad.olvidar(j)
		p.turboRestante = 600
		Turbo.sincronizar(j)
		-- Sin ninguna accion (como al entrar): en pausa
		r.inicioPausado = j:GetAttribute("TurboPausado") == true
		t += 30
		Turbo.actualizar(j)
		r.quieto = Turbo.restante(j) -- 600
		-- Hace algo: corre
		Actividad.registrar(j)
		Turbo.actualizar(j)
		r.corre = Turbo.corre(j) and j:GetAttribute("TurboPausado") == false
		t += 60
		Turbo.actualizar(j)
		r.tras60 = Turbo.restante(j) -- 540
		-- 200 s quieto: corre hasta los 120 y se pausa
		t += 200
		Turbo.actualizar(j)
		r.tras200 = Turbo.restante(j) -- 480
		r.pausado = Turbo.pausado(j) and j:GetAttribute("TurboPausado") == true
		r.multiplicador = Turbo.multiplicador(j) -- 2: en pausa vale x2
		t += 500
		Turbo.actualizar(j)
		r.enPausa = Turbo.restante(j) -- 480
		-- Otra accion: corre otra vez desde ahi
		Actividad.registrar(j)
		Turbo.actualizar(j)
		r.reanudado = j:GetAttribute("TurboPausado") == false
		t += 30
		Turbo.actualizar(j)
		r.tras30 = Turbo.restante(j) -- 450
		-- Sale: lo que queda se guarda y ya no baja
		Turbo.salir(j)
		t += 1000
		Turbo.actualizar(j)
		r.fuera = Turbo.restante(j) -- 450
		-- Vuelve: en pausa hasta la primera accion
		Turbo.entrar(j)
		t += 100
		Turbo.actualizar(j)
		r.vuelta = Turbo.restante(j) -- 450
		r.vueltaPausado = j:GetAttribute("TurboPausado") == true
		-- Uno ganado de 20 s que se acaba corriendo: alAcabar(j, true)
		p.turboRestante = 0
		Turbo.anadir(j, 20)
		Actividad.registrar(j)
		Turbo.actualizar(j)
		t += 25
		Turbo.actualizar(j)
		r.acabado = Turbo.restante(j) == 0 and j:GetAttribute("TurboPausado") == false
	end)
	conexion:Disconnect()
	Actividad.ahora = relojAntes
	Actividad.olvidar(j)
	p.turboRestante = turboAntes
	Turbo.entrar(j)
	Perfiles.marcarSucio(j)
	-- El fin de Turbo ganado de la prueba no debe disparar una oferta de verdad
	local sesion = Ofertas.sesion(j)
	if sesion then
		sesion.turboGanadoAcabado = false
	end
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local bien = r.inicioPausado and igual(r.quieto, 600) and r.corre and igual(r.tras60, 540) and igual(r.tras200, 480)
		and r.pausado and r.multiplicador == 2 and igual(r.enPausa, 480) and r.reanudado and igual(r.tras30, 450)
		and igual(r.fuera, 450) and igual(r.vuelta, 450) and r.vueltaPausado and r.acabado
		and #acabados == 1 and acabados[1] == true and Turbo.PAUSA == 120
	local avisos = {}
	for _, ganado in acabados do
		table.insert(avisos, if ganado then "ganado" else "comprado")
	end
	return string.format("al entrar en pausa=%s | 30 s quieto: %s | accion: corre=%s, +60 s: %s | 200 s quieto: %s (para a los 120), en pausa=%s, x%s | +500 s en pausa: %s | otra accion: corre=%s, +30 s: %s | fuera +1000 s: %s | al volver +100 s: %s, en pausa=%s | uno ganado de 20 s, +25 s: acabado=%s, alAcabar [%s] => %s",
		tostring(r.inicioPausado), tostring(r.quieto), tostring(r.corre), tostring(r.tras60), tostring(r.tras200),
		tostring(r.pausado), tostring(r.multiplicador), tostring(r.enPausa), tostring(r.reanudado), tostring(r.tras30),
		tostring(r.fuera), tostring(r.vuelta), tostring(r.vueltaPausado), tostring(r.acabado), table.concat(avisos, ","), ok(bien))
end

-- Con 3 h guardadas no se puede comprar mas (Turbo.puedeComprar: la Tienda
-- y las ofertas desactivan sus botones), pero un recibo que llegue igual se
-- otorga entero: ProcessReceipt nunca rechaza una compra pagada
function Pruebas.turboTope()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = foto(p)
	local r = {}
	local exito, err = pcall(function()
		p.turboRestante = GameConfig.TURBO_TOPE_COMPRA - 1
		r.debajo = Turbo.puedeComprar(j)
		p.turboRestante = GameConfig.TURBO_TOPE_COMPRA
		r.alTope = Turbo.puedeComprar(j)
		r.otorgado = Monetizacion.otorgarProductoPorId(j, "Turbo15", "PruebaTope-" .. guid())
		r.tras = Turbo.restante(j)
	end)
	devolver(j, p, antes)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local tope = GameConfig.TURBO_TOPE_COMPRA
	local bien = tope == 3 * 3600 and r.debajo and not r.alTope and r.otorgado and igual(r.tras, tope + 900)
	return string.format("tope %d s | con %d s se puede=%s | con %d s se puede=%s | recibo con el tope lleno: otorgado=%s, queda %d s (tope + 900) => %s",
		tope, tope - 1, tostring(r.debajo), tope, tostring(r.alTope), tostring(r.otorgado), r.tras or -1, ok(bien))
end

-- Turbo 15 (49) y Turbo 60 (149): cada recibo suma sus minutos, el mismo
-- recibo dos veces solo una, y cada compra deja compras.ultimaRobux
function Pruebas.turboProductos()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = foto(p)
	local r = {}
	local exito, err = pcall(function()
		p.turboRestante = 0
		p.compras.ultimaRobux = 0
		local recibo15 = "PruebaT15-" .. guid()
		r.uno = Monetizacion.otorgarProductoPorId(j, "Turbo15", recibo15)
		r.t15 = Turbo.restante(j)
		r.otraVez = Monetizacion.otorgarProductoPorId(j, "Turbo15", recibo15)
		r.t15b = Turbo.restante(j)
		r.sesenta = Monetizacion.otorgarProductoPorId(j, "Turbo60", "PruebaT60-" .. guid())
		r.t60 = Turbo.restante(j)
		r.ultimaRobux = math.abs((p.compras.ultimaRobux or 0) - os.time()) <= 2
	end)
	devolver(j, p, antes)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local t15, t60 = Productos.PRODUCTO_POR_ID.Turbo15, Productos.PRODUCTO_POR_ID.Turbo60
	local config = t15.turboMinutos == 15 and t15.precioRobux == 49 and t60.turboMinutos == 60 and t60.precioRobux == 149
	local bien = config and r.uno and igual(r.t15, 900) and r.otraVez and igual(r.t15b, 900) and r.sesenta and igual(r.t60, 4500) and r.ultimaRobux
	return string.format("Config 15 min/49 y 60 min/149=%s | Turbo15: %s -> %d s | mismo recibo: %d s | Turbo60: %s -> %d s | ultimaRobux al dia=%s => %s",
		tostring(config), tostring(r.uno), r.t15 or -1, r.t15b or -1, tostring(r.sesenta), r.t60 or -1, tostring(r.ultimaRobux), ok(bien))
end

-- ===========================================================================
-- Pases nuevos
-- ===========================================================================

-- El Pack de inicio da sus 30 min de Turbo UNA vez (compras.packInicio): no
-- sin el pase, no con el modo dev (no envenena el perfil), no con un perfil
-- provisional; si con el pase y el perfil guardable, y nunca otra vez: ni al
-- volver a mirar, ni al recargar el perfil (alCambiarPases y entrar), ni en
-- lo que se guarda
function Pruebas.packInicioUnaVez()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = foto(p)
	local cargadoAntes = Perfiles.estaCargado
	local r = {}
	local exito, err = pcall(function()
		Monetizacion.fijarModoDev(false)
		p.turboRestante = 0
		p.compras.packInicio = false
		p.pasesCache.PackInicio = nil
		r.sinPase = Turbo.revisarPack(j)
		Monetizacion.fijarModoDev(true)
		r.modoDev = Turbo.revisarPack(j) or Turbo.restante(j) > 0
		Monetizacion.fijarModoDev(false)
		p.pasesCache.PackInicio = true
		Perfiles.estaCargado = function()
			return false
		end
		r.provisional = Turbo.revisarPack(j) or p.compras.packInicio
		Perfiles.estaCargado = function()
			return true
		end
		r.primera = Turbo.revisarPack(j)
		r.tras = Turbo.restante(j)
		r.marca = p.compras.packInicio
		r.segunda = Turbo.revisarPack(j)
		Monetizacion.alCambiarPases:Fire(j)
		Turbo.entrar(j)
		r.recarga = Turbo.restante(j)
		local guardado = Perfiles.completar(copiaJson(p))
		r.guardado = guardado.compras.packInicio == true and igual(guardado.turboRestante, 1800)
	end)
	Perfiles.estaCargado = cargadoAntes
	devolver(j, p, antes)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local pase = Productos.PASE_POR_ID.PackInicio
	local config = pase.compraUnica == true and pase.turboMinutos == 30 and pase.precioRobux == 99
	local bien = config and not r.sinPase and not r.modoDev and not r.provisional and r.primera and igual(r.tras, 1800)
		and r.marca and not r.segunda and igual(r.recarga, 1800) and r.guardado
	return string.format("Config 99, compra unica, 30 min=%s | sin pase: %s | modo dev: %s | perfil provisional: %s | con el pase: %s, Turbo %d s, marca=%s | otra vez: %s | recargado: %d s | en lo guardado=%s => %s",
		tostring(config), tostring(r.sinPase), tostring(r.modoDev), tostring(r.provisional), tostring(r.primera), r.tras or -1,
		tostring(r.marca), tostring(r.segunda), r.recarga or -1, tostring(r.guardado), ok(bien))
end

-- El VIP: el atributo VIP del Player (la corona y la etiqueta del chat los
-- pinta cada cliente) y la Estela VIP; sin el pase, ni una ni otra (la
-- estela puesta se quita). El 4.o pedido del VIP es de otro paquete
function Pruebas.vipVentajas()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = foto(p)
	local estelaAntes = p.estela
	local r = {}
	local exito, err = pcall(function()
		Monetizacion.fijarModoDev(false)
		p.pasesCache.VIP = nil
		Monetizacion.alCambiarPases:Fire(j)
		r.sinAtributo = j:GetAttribute("VIP") == false
		r.sinEstela = not Cosmeticos.tiene(j, "estela", "VIP") and not Cosmeticos.equipar(j, "estela", "VIP")
		-- La compra confirmada lo marca (registrarCompraPase -> marcarPase)
		Monetizacion.marcarPase(j, "VIP")
		r.conAtributo = j:GetAttribute("VIP") == true
		r.conEstela = Cosmeticos.tiene(j, "estela", "VIP") and Cosmeticos.equipar(j, "estela", "VIP")
		local puesta = Cosmeticos.puesto(j, "estela")
		r.puesta = puesta ~= nil and puesta.id == "VIP"
		-- Sin el pase otra vez (un reembolso): fuera la corona y la estela
		p.pasesCache.VIP = nil
		Monetizacion.alCambiarPases:Fire(j)
		r.quitado = j:GetAttribute("VIP") == false and Cosmeticos.puesto(j, "estela") == nil
		-- El modo dev de Studio tambien la da
		Monetizacion.fijarModoDev(true)
		r.modoDev = j:GetAttribute("VIP") == true
		Monetizacion.fijarModoDev(false)
	end)
	p.estela = estelaAntes
	devolver(j, p, antes)
	Cosmeticos.alCambiar:Fire(j)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local pase = Productos.PASE_POR_ID.VIP
	local estela = DefinicionesCosmeticos.ESTELA_POR_ID.VIP
	local config = pase.precioRobux == 249 and pase.icono == "corona" and estela ~= nil and estela.pase == "VIP"
	local bien = config and r.sinAtributo and r.sinEstela and r.conAtributo and r.conEstela and r.puesta and r.quitado and r.modoDev
	return string.format("Config 249, corona, Estela VIP del pase=%s | sin pase: VIP=false %s, sin estela %s | con el pase: VIP=true %s, estela %s, puesta %s | reembolso: %s | modo dev: %s => %s",
		tostring(config), tostring(r.sinAtributo), tostring(r.sinEstela), tostring(r.conAtributo), tostring(r.conEstela),
		tostring(r.puesta), tostring(r.quitado), tostring(r.modoDev), ok(bien))
end

-- Los cosmeticos de la economia v4: la Bolsa de carton con la insignia
-- Constante (semanaCompleta, forma insignia: perfil.logros), la del
-- reciclador con el Pack de inicio, la de hielo con el Rebirth 4 y la
-- Estela de fuego con el 5. Lo que se deja de tener se quita al mirarlo
function Pruebas.cosmeticosNuevos()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = foto(p)
	local guardados = {
		logro = p.logros.semanaCompleta,
		rebirths = p.rebirths,
		bolsa = p.disenoBolsa,
		estela = p.estela,
	}
	local r = {}
	local exito, err = pcall(function()
		Monetizacion.fijarModoDev(false)
		-- Carton
		p.logros.semanaCompleta = nil
		r.cartonSin = not Cosmeticos.tiene(j, "bolsa", "Carton") and not Cosmeticos.equipar(j, "bolsa", "Carton")
		p.logros.semanaCompleta = true
		r.cartonCon = Cosmeticos.tiene(j, "bolsa", "Carton") and Cosmeticos.equipar(j, "bolsa", "Carton")
		p.logros.semanaCompleta = nil
		r.cartonQuitado = Cosmeticos.puesto(j, "bolsa") == nil
		-- Reciclador
		p.pasesCache.PackInicio = nil
		r.recicladorSin = not Cosmeticos.tiene(j, "bolsa", "Reciclador")
		p.pasesCache.PackInicio = true
		r.recicladorCon = Cosmeticos.tiene(j, "bolsa", "Reciclador") and Cosmeticos.equipar(j, "bolsa", "Reciclador")
		p.pasesCache.PackInicio = nil
		-- Hielo (Rebirth 4) y Fuego (Rebirth 5)
		p.rebirths = 3
		r.r3 = not Cosmeticos.tiene(j, "bolsa", "Hielo") and not Cosmeticos.tiene(j, "estela", "Fuego")
		p.rebirths = 4
		r.r4 = Cosmeticos.tiene(j, "bolsa", "Hielo") and not Cosmeticos.tiene(j, "estela", "Fuego")
		p.rebirths = 5
		r.r5 = Cosmeticos.tiene(j, "bolsa", "Hielo") and Cosmeticos.tiene(j, "estela", "Fuego")
		-- Una llamada sin tieneInsignia nunca da uno de insignia
		r.sinFuncion = not DefinicionesCosmeticos.loTiene(DefinicionesCosmeticos.BOLSA_POR_ID.Carton, 99, function()
			return true
		end)
	end)
	p.logros.semanaCompleta = guardados.logro
	p.rebirths = guardados.rebirths
	p.disenoBolsa = guardados.bolsa
	p.estela = guardados.estela
	devolver(j, p, antes)
	Cosmeticos.alCambiar:Fire(j)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local B = DefinicionesCosmeticos.BOLSA_POR_ID
	local config = B.Carton.insignia == "semanaCompleta" and B.Reciclador.pase == "PackInicio" and B.Hielo.rebirth == 4
		and DefinicionesCosmeticos.ESTELA_POR_ID.Fuego.rebirth == 5
	local bien = config and r.cartonSin and r.cartonCon and r.cartonQuitado and r.recicladorSin and r.recicladorCon and r.r3 and r.r4 and r.r5 and r.sinFuncion
	return string.format("Config=%s | Carton: sin insignia %s, con ella %s, al perderla se quita %s | Reciclador: sin pack %s, con el %s | rebirth 3/4/5: %s %s %s | sin tieneInsignia nunca=%s => %s",
		tostring(config), tostring(r.cartonSin), tostring(r.cartonCon), tostring(r.cartonQuitado), tostring(r.recicladorSin),
		tostring(r.recicladorCon), tostring(r.r3), tostring(r.r4), tostring(r.r5), tostring(r.sinFuncion), ok(bien))
end

-- ===========================================================================
-- Ofertas
-- ===========================================================================

local AHORA = 2000000000

-- Un contexto en el que el Pack de inicio se puede ensenar tras un deposito
local function contexto(cambios: ((any) -> ())?): any
	local ctx = {
		momento = "deposito",
		rebirthHecho = nil,
		ahora = AHORA,
		tutorial = 8,
		sesion = 2,
		segundosSesion = 600,
		mostradasSesion = 0,
		mostradasSesionPorId = {},
		historial = {},
		porId = {},
		ultimaRobux = 0,
		rebirths = 0,
		turboRestante = 0,
		intentosBolsaLlena = 0,
		nivelBolsa = 0,
		turboGanadoAcabado = false,
		pases = {},
		ids = {},
	}
	ctx.tienePase = function(id)
		return ctx.pases[id] == true
	end
	ctx.idRoblox = function(_tipo, id)
		return ctx.ids[id] or 1
	end
	if cambios then
		cambios(ctx)
	end
	return ctx
end

-- Cada regla de §5.6 con DefinicionesOfertas.debeOfrecer (pura) y, despues,
-- el viaje entero por Services/Ofertas con los relojes sustituidos: no en
-- los 3 primeros minutos, una a la vez, solo cuenta si se ensena (lo
-- caducado y lo descartado no), un "Ahora no" la aparta 7 dias, 1 por
-- sesion, la segunda del Pack en la 4.a sesion, 24 h tras una compra, los
-- intentos con la bolsa llena (solo llena de verdad) y el Turbo tras acabarse
-- uno ganado (solo el primer deposito, solo las opciones con id). Y basura
-- por el remote
function Pruebas.ofertaReglas()
	local partes, malos = {}, {}

	-- === 1. Las reglas, una a una (pura) ===
	local casos = {
		{ "Pack: sesion 2, min 10", "PackInicio", nil, "ok" },
		{ "1.a sesion", "PackInicio", function(c) c.sesion = 1 end, "sesion" },
		{ "6 pasos del tutorial", "PackInicio", function(c) c.tutorial = 6 end, "tutorial" },
		{ "7 pasos", "PackInicio", function(c) c.tutorial = 7 end, "ok" },
		{ "minuto 2:59", "PackInicio", function(c) c.segundosSesion = 179 end, "minutos" },
		{ "minuto 3", "PackInicio", function(c) c.segundosSesion = 180 end, "ok" },
		{ "ya lo tiene", "PackInicio", function(c) c.pases.PackInicio = true end, "loTiene" },
		{ "id 0", "PackInicio", function(c) c.ids.PackInicio = 0 end, "sinIds" },
		{ "1 por sesion", "PackInicio", function(c) c.mostradasSesion = 1 end, "porSesion" },
		{ "3 esta semana", "PackInicio", function(c) c.historial = { AHORA - DIA, AHORA - 2 * DIA, AHORA - 6 * DIA } end, "porSemana" },
		{ "3, una de hace 8 dias", "PackInicio", function(c) c.historial = { AHORA - DIA, AHORA - 2 * DIA, AHORA - 8 * DIA } end, "ok" },
		{ "compra hace 23 h", "PackInicio", function(c) c.ultimaRobux = AHORA - 23 * 3600 end, "trasCompra" },
		{ "compra hace 25 h", "PackInicio", function(c) c.ultimaRobux = AHORA - 25 * 3600 end, "ok" },
		{ "Ahora no hace 6 dias", "PackInicio", function(c) c.sesion = 4; c.porId.PackInicio = { vistas = 1, ultima = AHORA - 6 * DIA, rechazos = 1 } end, "ahoraNo" },
		{ "Ahora no hace 8 dias", "PackInicio", function(c) c.sesion = 4; c.porId.PackInicio = { vistas = 1, ultima = AHORA - 8 * DIA, rechazos = 1 } end, "ok" },
		{ "3 Ahora no", "BolsaXL", function(c) c.intentosBolsaLlena = 5; c.nivelBolsa = 3; c.porId.BolsaXL = { vistas = 3, ultima = AHORA - 30 * DIA, rechazos = 3 } end, "rechazada" },
		{ "Pack 2.a vez en la sesion 3", "PackInicio", function(c) c.sesion = 3; c.porId.PackInicio = { vistas = 1, ultima = AHORA - 9 * DIA, rechazos = 0 } end, "sesion" },
		{ "Pack 2.a vez en la sesion 4", "PackInicio", function(c) c.sesion = 4; c.porId.PackInicio = { vistas = 1, ultima = AHORA - 9 * DIA, rechazos = 0 } end, "ok" },
		{ "Pack 3.a vez", "PackInicio", function(c) c.sesion = 9; c.porId.PackInicio = { vistas = 2, ultima = AHORA - 9 * DIA, rechazos = 0 } end, "total" },
		{ "Pack con 2 rebirths", "PackInicio", function(c) c.rebirths = 2 end, "rebirths" },
		{ "Pack con 1 rebirth", "PackInicio", function(c) c.rebirths = 1 end, "ok" },
		{ "Dinero x2 tras el R1", "DineroX2", function(c) c.momento = "rebirth"; c.rebirthHecho = 1; c.rebirths = 1 end, "ok" },
		{ "Dinero x2 tras el R3", "DineroX2", function(c) c.momento = "rebirth"; c.rebirthHecho = 3; c.rebirths = 3 end, "ok" },
		{ "Dinero x2 tras el R2", "DineroX2", function(c) c.momento = "rebirth"; c.rebirthHecho = 2; c.rebirths = 2 end, "momento" },
		{ "Dinero x2 en un deposito", "DineroX2", nil, "momento" },
		{ "Dinero x2 ya comprado", "DineroX2", function(c) c.momento = "rebirth"; c.rebirthHecho = 3; c.pases.DineroX2 = true end, "loTiene" },
		{ "Dinero x2 3.a vez", "DineroX2", function(c) c.momento = "rebirth"; c.rebirthHecho = 3; c.porId.DineroX2 = { vistas = 2, ultima = AHORA - 30 * DIA, rechazos = 0 } end, "total" },
		{ "VIP tras el R2", "VIP", function(c) c.momento = "rebirth"; c.rebirthHecho = 2; c.rebirths = 2 end, "ok" },
		{ "VIP 2.a vez", "VIP", function(c) c.momento = "rebirth"; c.rebirthHecho = 2; c.porId.VIP = { vistas = 1, ultima = AHORA - 30 * DIA, rechazos = 0 } end, "total" },
		{ "Bolsa XL: 4 intentos", "BolsaXL", function(c) c.intentosBolsaLlena = 4; c.nivelBolsa = 3 end, "bolsaLlena" },
		{ "Bolsa XL: Bolsa nivel 2", "BolsaXL", function(c) c.intentosBolsaLlena = 5; c.nivelBolsa = 2 end, "nivelBolsa" },
		{ "Bolsa XL: 5 intentos, nivel 3", "BolsaXL", function(c) c.intentosBolsaLlena = 5; c.nivelBolsa = 3 end, "ok" },
		{ "Bolsa XL: otra a los 3 dias", "BolsaXL", function(c) c.intentosBolsaLlena = 5; c.nivelBolsa = 3; c.porId.BolsaXL = { vistas = 1, ultima = AHORA - 3 * DIA, rechazos = 0 } end, "cadaDias" },
		{ "Bolsa XL: 4.a vez", "BolsaXL", function(c) c.intentosBolsaLlena = 5; c.nivelBolsa = 3; c.porId.BolsaXL = { vistas = 3, ultima = AHORA - 9 * DIA, rechazos = 0 } end, "total" },
		{ "Turbo sin uno ganado acabado", "Turbo", function(c) c.sesion = 3 end, "momento" },
		{ "Turbo en la sesion 2", "Turbo", function(c) c.turboGanadoAcabado = true end, "sesion" },
		{ "Turbo en la sesion 3", "Turbo", function(c) c.turboGanadoAcabado = true; c.sesion = 3 end, "ok" },
		{ "Turbo con Turbo guardado", "Turbo", function(c) c.turboGanadoAcabado = true; c.sesion = 3; c.turboRestante = 5 end, "conTurbo" },
		{ "Turbo sin ids", "Turbo", function(c) c.turboGanadoAcabado = true; c.sesion = 3; c.ids.Turbo15 = 0; c.ids.Turbo60 = 0 end, "sinIds" },
		{ "Turbo 2 por semana (otra a 1 dia)", "Turbo", function(c) c.turboGanadoAcabado = true; c.sesion = 3; c.porId.Turbo = { vistas = 1, ultima = AHORA - DIA, rechazos = 0 } end, "semanaOferta" },
		{ "Turbo 2 por semana (otra a 4 dias)", "Turbo", function(c) c.turboGanadoAcabado = true; c.sesion = 3; c.porId.Turbo = { vistas = 1, ultima = AHORA - 4 * DIA, rechazos = 0 } end, "ok" },
	}
	local bienCasos = 0
	for _, caso in casos do
		local nombre, id, cambios, esperado = caso[1], caso[2], caso[3], caso[4]
		local puede, motivo = DefinicionesOfertas.debeOfrecer(DefinicionesOfertas.POR_ID[id], contexto(cambios))
		if (esperado == "ok") == puede and motivo == esperado then
			bienCasos += 1
		else
			table.insert(malos, string.format("%s: %s (esperado %s)", nombre, motivo, esperado))
		end
	end
	table.insert(partes, string.format("reglas %d/%d", bienCasos, #casos))
	-- Prioridad: con el Pack y la Bolsa XL a la vez, el Pack; solo las
	-- opciones con id (Turbo 60 sin id: un boton)
	local primera = DefinicionesOfertas.elegir(contexto(function(c)
		c.intentosBolsaLlena = 5
		c.nivelBolsa = 3
	end))
	local opcionesTurbo = DefinicionesOfertas.opciones(DefinicionesOfertas.POR_ID.Turbo, contexto(function(c)
		c.ids.Turbo60 = 0
	end))
	local prioridadOk = primera ~= nil and primera.id == "PackInicio" and #opcionesTurbo == 1 and opcionesTurbo[1].id == "Turbo15"
	if not prioridadOk then
		table.insert(malos, "prioridad u opciones")
	end
	table.insert(partes, string.format("Pack antes que Bolsa XL=%s, Turbo sin el id del 60: %d boton(es)", tostring(primera and primera.id == "PackInicio"), #opcionesTurbo))

	-- === 2. El viaje por Services/Ofertas ===
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = foto(p)
	local guardados = {
		ofertas = copiaJson(p.ofertas),
		tutorial = p.tutorial,
		sesiones = p.estadisticas.sesiones,
		rebirths = p.rebirths,
		bolsa = p.mejoras.Bolsa,
		contenido = table.clone(Bolsa.contenido(j)),
		ahora = Ofertas.ahora,
		reloj = Ofertas.reloj,
		enviar = Ofertas.enviarCliente,
		idPack = Productos.PASE_POR_ID.PackInicio.gamePassId,
		idBolsaXL = Productos.PASE_POR_ID.BolsaXL.gamePassId,
		idTurbo15 = Productos.PRODUCTO_POR_ID.Turbo15.productId,
	}
	local enviados = {}
	local reloj, ahora = 1000, AHORA
	local r = {}
	local exito, err = pcall(function()
		Ofertas.reloj = function()
			return reloj
		end
		Ofertas.ahora = function()
			return ahora
		end
		Ofertas.enviarCliente = function(_quien, datos)
			table.insert(enviados, datos)
		end
		Productos.PASE_POR_ID.PackInicio.gamePassId = 990000011
		Productos.PASE_POR_ID.BolsaXL.gamePassId = 990000012
		Monetizacion.fijarModoDev(false)
		p.ofertas = { porId = {}, historial = {} }
		p.compras.ultimaRobux = 0
		p.tutorial = 8
		p.estadisticas.sesiones = 2
		p.rebirths = 0
		p.turboRestante = 0
		p.pasesCache = {}
		p.mejoras.Bolsa = 0
		Ofertas.reiniciarSesion(j)

		-- Minuto 1: aun no
		reloj = 1060
		local _, motivo = Ofertas.momento(j, "deposito")
		r.minuto1 = motivo
		-- Minuto 4: el Pack, por OfertaEvent con su token
		reloj = 1240
		r.pack = Ofertas.momento(j, "deposito")
		local d1 = enviados[1]
		r.datos = d1 ~= nil and d1.id == "PackInicio" and d1.titulo.k == "OFERTAS.packTitulo" and #d1.opciones == 1 and d1.espera == 60
		-- Una a la vez
		local _, motivo2 = Ofertas.momento(j, "deposito")
		r.pendiente = motivo2
		-- No se ensena en sus 60 s: caduca y no cuenta
		reloj += 70
		r.caducada = not Ofertas.responder(j, "mostrada", d1.token) and p.ofertas.porId.PackInicio == nil
		-- Otra vez: ensenada, cuenta una vez
		r.otra = Ofertas.momento(j, "deposito")
		local d2 = enviados[2]
		r.mostrada = Ofertas.responder(j, "mostrada", d2.token)
		r.dosVeces = Ofertas.responder(j, "mostrada", d2.token)
		local reg = p.ofertas.porId.PackInicio
		r.cuenta = reg ~= nil and reg.vistas == 1 and reg.ultima == ahora and #p.ofertas.historial == 1
		-- Basura y token falso
		r.basura = not Ofertas.responder(j, 42, "x") and not Ofertas.responder(j, "ahoraNo", d2.token + 7) and not Ofertas.responder(j, "comprar", d2.token, "VIP")
		-- Ahora no: un rechazo
		r.ahoraNo = Ofertas.responder(j, "ahoraNo", d2.token) and reg.rechazos == 1
		-- 1 por sesion
		local _, motivo3 = Ofertas.momento(j, "deposito")
		r.porSesion = motivo3
		-- Sesion 3, al dia siguiente: el Ahora no de ayer la aparta
		ahora += DIA
		p.estadisticas.sesiones = 3
		reloj += 500
		Ofertas.reiniciarSesion(j)
		reloj += 240
		local _, motivo4 = Ofertas.momento(j, "deposito")
		r.trasAhoraNo = motivo4
		-- Sesion 4, 8 dias despues: la 2.a vez del Pack. Comprar y la compra
		-- completada la cierran
		ahora += 8 * DIA
		p.estadisticas.sesiones = 4
		Ofertas.reiniciarSesion(j)
		reloj += 240
		r.segunda = Ofertas.momento(j, "deposito")
		local d3 = enviados[#enviados]
		Ofertas.responder(j, "mostrada", d3.token)
		r.comprar = Ofertas.responder(j, "comprar", d3.token, "PackInicio")
		Ofertas.compra(j, "PackInicio")
		local sesion = Ofertas.sesion(j)
		r.cerrada = sesion ~= nil and sesion.actual == nil and p.ofertas.porId.PackInicio.vistas == 2
		-- Sesion 5: intentos con la bolsa llena (solo llena de verdad, uno
		-- por segundo como mucho) para la Bolsa XL, que no sale en las 24 h
		-- tras una compra
		ahora += 2 * DIA
		p.estadisticas.sesiones = 5
		p.mejoras.Bolsa = 3
		Ofertas.reiniciarSesion(j)
		Bolsa.vaciar(j)
		r.vacia = not Ofertas.responder(j, "bolsaLlena", 0)
		Comunes.llenarBolsa(j)
		local contados = 0
		for _ = 1, 5 do
			reloj += 1.1
			if Ofertas.responder(j, "bolsaLlena", 0) then
				contados += 1
			end
		end
		r.rapido = not Ofertas.responder(j, "bolsaLlena", 0)
		r.intentos = contados
		reloj += 240
		p.compras.ultimaRobux = ahora - 3600
		local _, motivo5 = Ofertas.momento(j, "deposito")
		r.trasCompra = motivo5
		p.compras.ultimaRobux = ahora - 25 * 3600
		r.bolsaXL = Ofertas.momento(j, "deposito")
		-- Descartada (sin momento tranquilo): no cuenta y libera
		local d4 = enviados[#enviados]
		r.descartada = Ofertas.responder(j, "descartada", d4.token) and p.ofertas.porId.BolsaXL == nil
		-- Sesion 6: un Turbo ganado se acaba -> en el primer deposito, el
		-- Turbo (solo con el id del 15: un boton); en el siguiente ya no
		Productos.PRODUCTO_POR_ID.Turbo15.productId = 990000013
		ahora += DIA
		p.estadisticas.sesiones = 6
		p.mejoras.Bolsa = 0
		Ofertas.reiniciarSesion(j)
		reloj += 240
		Ofertas.turboAcabado(j, true)
		r.turbo = Ofertas.momento(j, "deposito")
		local d5 = enviados[#enviados]
		r.turboUnBoton = d5 ~= nil and d5.id == "Turbo" and #d5.opciones == 1 and d5.opciones[1].id == "Turbo15"
		Ofertas.responder(j, "descartada", d5.token)
		local turboOtra, motivo6 = Ofertas.momento(j, "deposito")
		r.turboSoloPrimero = turboOtra == nil and motivo6 ~= "ok"
		-- Uno comprado que se acaba no la dispara
		Ofertas.turboAcabado(j, false)
		local turboComprado = Ofertas.momento(j, "deposito")
		r.turboComprado = turboComprado == nil
	end)
	-- Todo como estaba
	Ofertas.ahora = guardados.ahora
	Ofertas.reloj = guardados.reloj
	Ofertas.enviarCliente = guardados.enviar
	Productos.PASE_POR_ID.PackInicio.gamePassId = guardados.idPack
	Productos.PASE_POR_ID.BolsaXL.gamePassId = guardados.idBolsaXL
	Productos.PRODUCTO_POR_ID.Turbo15.productId = guardados.idTurbo15
	p.ofertas = guardados.ofertas
	p.tutorial = guardados.tutorial
	p.estadisticas.sesiones = guardados.sesiones
	p.rebirths = guardados.rebirths
	p.mejoras.Bolsa = guardados.bolsa
	Bolsa.vaciar(j)
	Bolsa.meterVarios(j, guardados.contenido)
	devolver(j, p, antes)
	Ofertas.reiniciarSesion(j)
	if not exito then
		return "error: " .. tostring(err) .. " => FALLO"
	end
	local viajeOk = r.minuto1 == "minutos" and r.pack == "PackInicio" and r.datos and r.pendiente == "pendiente" and r.caducada
		and r.otra == "PackInicio" and r.mostrada and not r.dosVeces and r.cuenta and r.basura and r.ahoraNo and r.porSesion == "porSesion"
		and r.trasAhoraNo == "ahoraNo" and r.segunda == "PackInicio" and r.comprar and r.cerrada
		and r.vacia and r.intentos == 5 and r.rapido and r.trasCompra == "trasCompra" and r.bolsaXL == "BolsaXL" and r.descartada
		and r.turbo == "Turbo" and r.turboUnBoton and r.turboSoloPrimero and r.turboComprado
	if not viajeOk then
		local claves = {}
		for k, v in r do
			table.insert(claves, k .. "=" .. tostring(v))
		end
		table.sort(claves)
		table.insert(malos, "viaje: " .. table.concat(claves, " "))
	end
	table.insert(partes, string.format("viaje: minuto 1 %s, minuto 4 %s, pendiente %s, caducada sin contar=%s, ensenada cuenta 1=%s, Ahora no=%s, 2.a de la sesion %s, al dia siguiente %s, 2.a vez en la 4.a sesion %s y comprada=%s, bolsa llena %d/5 (vacia no=%s), tras una compra %s, Bolsa XL %s, descartada no cuenta=%s, Turbo %s (1 boton=%s, solo el primer deposito=%s, el comprado no=%s)",
		tostring(r.minuto1), tostring(r.pack), tostring(r.pendiente), tostring(r.caducada), tostring(r.cuenta), tostring(r.ahoraNo),
		tostring(r.porSesion), tostring(r.trasAhoraNo), tostring(r.segunda), tostring(r.cerrada), r.intentos or 0, tostring(r.vacia),
		tostring(r.trasCompra), tostring(r.bolsaXL), tostring(r.descartada), tostring(r.turbo), tostring(r.turboUnBoton),
		tostring(r.turboSoloPrimero), tostring(r.turboComprado)))
	local bien = #malos == 0
	return table.concat(partes, " | ") .. (if bien then "" else " | MAL: " .. table.concat(malos, "; ")) .. " => " .. ok(bien)
end

return Pruebas
