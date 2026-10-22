--!strict
--[[
	Productos
	Catalogo de monetizacion: Game Passes permanentes y Developer Products.

	Regla de la v2 (26 sep): solo se venden VENTAJAS PERSONALES y COSMETICOS.
	No se vende nada aleatorio (fragmentos, mascotas, suerte), ni
	velocidad o iman (servirian para quitarle piezas a los demas en el patio
	compartido), ni recoger automatico o linea de punteria (harian el trabajo
	por el jugador), ni saltos de rebirth o moneda premium.

	Catalogo de lanzamiento (lote 8, 3 oct):
	  Dinero x2        x2 a todo lo que se recicla (Bolsa)
	  Bolsa XL         +10 huecos encima de la mejora (Mejoras)
	  Estela arcoiris  estela en la bolsa lanzada (cosmetico)
	  Bolsa dorada     diseno de bolsa (cosmetico)
	  Turbo 15 min     producto: x2 al dinero 15 min, se acumula (Turbo)
	Los cosmeticos se describen en Config/DefinicionesCosmeticos. (Los 2
	trajes de avatar de pago se quitaron el 5 oct con los trajes.)

	TODOS los ids de Roblox son 0 (placeholder). Se crean en el Creator
	Dashboard una vez publicado el juego y se rellenan aqui. Con id 0:
	  - el servidor no llama a MarketplaceService;
	  - en Studio, con GameConfig.PASES_DEV_EN_STUDIO, los pases cuentan como
	    comprados para poder probar sus efectos.
]]

export type Pase = {
	id: string,
	nombre: string,
	descripcion: string,
	precioRobux: number,
	gamePassId: number,
	categoria: string, -- "ventaja" | "cosmetico"
	icono: string?, -- clave de Config/Iconos
}

export type Producto = {
	id: string,
	nombre: string,
	descripcion: string,
	precioRobux: number,
	productId: number,
	icono: string?,
	turboMinutos: number?, -- producto de Turbo: minutos de dinero x2
}

local Productos = {}

Productos.PASES = {
	{ id = "DineroX2", nombre = "Dinero x2", descripcion = "Todo lo que reciclas paga el doble, para siempre", precioRobux = 199, gamePassId = 0, categoria = "ventaja", icono = "billete" },
	{ id = "BolsaXL", nombre = "Bolsa XL", descripcion = "10 huecos más en la bolsa, para siempre", precioRobux = 149, gamePassId = 0, categoria = "ventaja", icono = "bolsa" },
	{ id = "EstelaArcoiris", nombre = "Estela arcoíris", descripcion = "Tu bolsa deja un arcoíris al lanzarla", precioRobux = 99, gamePassId = 0, categoria = "cosmetico", icono = "estrella" },
	{ id = "BolsaDorada", nombre = "Bolsa dorada", descripcion = "Una bolsa de oro para lucirla", precioRobux = 99, gamePassId = 0, categoria = "cosmetico", icono = "cofre" },
} :: { Pase }

-- Developer Products (consumibles)
Productos.PRODUCTOS = {
	{ id = "Turbo15", nombre = "Turbo 15 min", descripcion = "Dinero x2 durante 15 minutos (se suma al que te quede)", precioRobux = 49, productId = 0, icono = "rayo", turboMinutos = 15 },
} :: { Producto }

Productos.PASE_POR_ID = {} :: { [string]: Pase }
for _, p in Productos.PASES do
	Productos.PASE_POR_ID[p.id] = p
end

Productos.PRODUCTO_POR_ID = {} :: { [string]: Producto }
for _, p in Productos.PRODUCTOS do
	Productos.PRODUCTO_POR_ID[p.id] = p
end

function Productos.productoPorProductId(productId: number): Producto?
	if productId == 0 then
		return nil
	end
	for _, p in Productos.PRODUCTOS do
		if p.productId == productId then
			return p
		end
	end
	return nil
end

function Productos.pasePorGamePassId(gamePassId: number): Pase?
	if gamePassId == 0 then
		return nil
	end
	for _, p in Productos.PASES do
		if p.gamePassId == gamePassId then
			return p
		end
	end
	return nil
end

return Productos
