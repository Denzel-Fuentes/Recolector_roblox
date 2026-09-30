--!strict
--[[
	Productos
	Catalogo de monetizacion: Game Passes permanentes y Developer Products.

	Regla de la v2 (26 sep): solo se venden VENTAJAS PERSONALES y COSMETICOS.
	No se vende nada aleatorio (fragmentos, mascotas, suerte), ni
	velocidad o iman (servirian para quitarle piezas a los demas en el patio
	compartido), ni recoger automatico o linea de punteria (harian el trabajo
	por el jugador), ni saltos de rebirth o moneda premium. El catalogo
	completo de la v2 llega en el lote 8; de momento quedan los trajes.

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
	trajeId: string?,
}

export type Producto = {
	id: string,
	nombre: string,
	descripcion: string,
	precioRobux: number,
	productId: number,
}

local Productos = {}

Productos.PASES = {
	{ id = "TrajeDorado", nombre = "Traje Dorado", descripcion = "Traje de reciclador premium", precioRobux = 199, gamePassId = 0, categoria = "cosmetico", trajeId = "TP1" },
	{ id = "TrajeFantasma", nombre = "Fantasma del Vertedero", descripcion = "Traje de reciclador premium", precioRobux = 79, gamePassId = 0, categoria = "cosmetico", trajeId = "TP2" },
} :: { Pase }

-- Developer Products (consumibles)
Productos.PRODUCTOS = {} :: { Producto }

Productos.PASE_POR_ID = {} :: { [string]: Pase }
for _, p in Productos.PASES do
	Productos.PASE_POR_ID[p.id] = p
end

Productos.PRODUCTO_POR_ID = {} :: { [string]: Producto }
for _, p in Productos.PRODUCTOS do
	Productos.PRODUCTO_POR_ID[p.id] = p
end

function Productos.paseParaTraje(trajeId: string): Pase?
	for _, p in Productos.PASES do
		if p.trajeId == trajeId then
			return p
		end
	end
	return nil
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
