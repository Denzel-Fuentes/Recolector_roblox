--!strict
--[[
	PreciosRobux (ModuleScript)
	Unica responsabilidad: el precio DE VERDAD de cada pase y producto de
	Config/Productos, el que esta puesto en el Creator Dashboard (economia
	v4, K1 22 oct). La tienda y las ofertas pintan este, no el de Config:
	si alguien cambia un precio en el Dashboard, el boton no puede decir otro
	(normas de Roblox: lo que se vende se presenta de forma transparente).

	MarketplaceService:GetProductInfo(id, InfoType) da PriceInRobux e
	IsForSale. Se pregunta UNA vez por cosa (cache de la sesion, en su
	hilo y en pcall: puede tardar o fallar) y la respuesta llega como un
	Value de Fusion, asi la UI se repinta sola:
	  { estado, precio, aLaVenta }
	    "cargando"  aun no ha respondido (precio = el de Config)
	    "listo"     lo dijo Roblox; aLaVenta = IsForSale y con precio
	    "respaldo"  la consulta fallo: el de Config, a la venta, y se
	                reintenta una vez a los REINTENTO s
	    "sinId"     id 0 (sin crear en el Dashboard): no esta a la venta
	La compra la confirma siempre la ventana de Roblox, con su precio.

	Para probarlo sin ids: ("modulo", "PreciosRobux", "listar") y
	("modulo", "PreciosRobux", "fijar", tipo, id, precio, aLaVenta?).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Productos = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Productos"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

export type Info = { estado: string, precio: number, aLaVenta: boolean }

local PreciosRobux = {}

PreciosRobux.REINTENTO = 30
-- Sustituible en pruebas
PreciosRobux.consultar = function(id: number, tipo: Enum.InfoType): any
	return MarketplaceService:GetProductInfo(id, tipo)
end

-- Vive lo que dure la sesion
local scope = Fusion.scoped(Fusion)
local cache: { [string]: any } = {}

-- El id de Roblox, el precio de Config y el InfoType de una cosa del catalogo
local function datosDe(tipo: string, id: string): (number, number, Enum.InfoType)
	if tipo == "pase" then
		local pase = Productos.PASE_POR_ID[id]
		return if pase then pase.gamePassId else 0, if pase then pase.precioRobux else 0, Enum.InfoType.GamePass
	end
	local producto = Productos.PRODUCTO_POR_ID[id]
	return if producto then producto.productId else 0, if producto then producto.precioRobux else 0, Enum.InfoType.Product
end

local function cargar(valor: any, idRoblox: number, respaldo: number, infoTipo: Enum.InfoType)
	task.spawn(function()
		for intento = 1, 2 do
			local ok, info = pcall(PreciosRobux.consultar, idRoblox, infoTipo)
			if ok and typeof(info) == "table" then
				local precio = tonumber(info.PriceInRobux)
				valor:set({
					estado = "listo",
					precio = precio or respaldo,
					aLaVenta = info.IsForSale ~= false and precio ~= nil,
				} :: Info)
				return
			end
			valor:set({ estado = "respaldo", precio = respaldo, aLaVenta = true } :: Info)
			if intento == 1 then
				task.wait(PreciosRobux.REINTENTO)
			end
		end
	end)
end

-- El precio de un pase ("pase") o de un producto ("producto") por su id de
-- Config/Productos, como Value de Fusion (Info). Siempre el mismo Value
function PreciosRobux.de(tipo: string, id: string): any
	local clave = tipo .. ":" .. id
	local valor = cache[clave]
	if valor then
		return valor
	end
	local idRoblox, respaldo, infoTipo = datosDe(tipo, id)
	if idRoblox == 0 then
		valor = scope:Value({ estado = "sinId", precio = respaldo, aLaVenta = false } :: Info)
	else
		valor = scope:Value({ estado = "cargando", precio = respaldo, aLaVenta = true } :: Info)
		cargar(valor, idRoblox, respaldo, infoTipo)
	end
	cache[clave] = valor
	return valor
end

-- Lo que hay ahora (sin Fusion)
function PreciosRobux.info(tipo: string, id: string): Info
	return Fusion.peek(PreciosRobux.de(tipo, id)) :: Info
end

PreciosRobux.prueba = {
	listar = function(): string
		local partes = {}
		for _, pase in Productos.PASES do
			local i = PreciosRobux.info("pase", pase.id)
			table.insert(partes, string.format("%s=%s %d%s", pase.id, i.estado, i.precio, if i.aLaVenta then "" else " (no)"))
		end
		for _, producto in Productos.PRODUCTOS do
			local i = PreciosRobux.info("producto", producto.id)
			table.insert(partes, string.format("%s=%s %d%s", producto.id, i.estado, i.precio, if i.aLaVenta then "" else " (no)"))
		end
		return table.concat(partes, " | ")
	end,
	-- Un precio inventado, para ver la tienda repintarse
	fijar = function(tipo: string, id: string, precio: any, aLaVenta: any): string
		PreciosRobux.de(tipo, id):set({
			estado = "listo",
			precio = tonumber(precio) or 0,
			aLaVenta = aLaVenta ~= false,
		} :: Info)
		return tipo .. " " .. id .. " -> " .. tostring(precio)
	end,
}

return PreciosRobux
