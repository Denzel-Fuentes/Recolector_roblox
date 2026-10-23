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

	Economia v4 (22 oct, docs/Economia-v4.md §5; los efectos los pone K1):
	  Pack de inicio   pase de compra unica (99): 30 min de Turbo una sola vez
	                   (turboMinutos; perfil.compras.packInicio) y la Bolsa del
	                   reciclador. Pase y no producto: Roblox impide comprarlo
	                   dos veces. Va el primero: arriba de la pestana Pases
	  VIP              pase (249): corona sobre la cabeza, Estela VIP y un 4.o
	                   pedido diario. No toca el pago por bolsa ni la capacidad
	  Turbo 60 min     producto (149), como el de 15: precio por cantidad, no
	                   se anuncia como descuento
	Escalera de precios: 49 · 99 · 149 · 199 · 249. El Turbo cuenta minutos DE
	JUEGO (solo corre mientras se juega): las descripciones lo dicen.

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
	compraUnica: boolean?, -- la tienda lo marca "Compra unica" (TIENDA.compraUnica)
	turboMinutos: number?, -- minutos de Turbo que da, UNA vez (el Pack de inicio)
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
	-- Icono estrella y no cofre: un cofre parece una caja de premio al azar
	{ id = "PackInicio", nombre = "Pack de inicio", descripcion = "30 min de Turbo (una vez) y la Bolsa del reciclador, que solo está en este pack", precioRobux = 99, gamePassId = 2052712857, categoria = "ventaja", icono = "estrella", compraUnica = true, turboMinutos = 30 },
	{ id = "DineroX2", nombre = "Dinero x2", descripcion = "Todo lo que reciclas paga el doble, para siempre", precioRobux = 199, gamePassId = 2054050833, categoria = "ventaja", icono = "billete" },
	{ id = "BolsaXL", nombre = "Bolsa XL", descripcion = "10 huecos más en la bolsa, para siempre", precioRobux = 149, gamePassId = 2052700812, categoria = "ventaja", icono = "bolsa" },
	{ id = "VIP", nombre = "VIP", descripcion = "Corona VIP sobre tu cabeza, la Estela VIP y un pedido más cada día", precioRobux = 249, gamePassId = 2054056851, categoria = "ventaja", icono = "corona" },
	{ id = "EstelaArcoiris", nombre = "Estela arcoíris", descripcion = "Tu bolsa deja un arcoíris al lanzarla", precioRobux = 99, gamePassId = 2052844870, categoria = "cosmetico", icono = "estrella" },
	{ id = "BolsaDorada", nombre = "Bolsa dorada", descripcion = "Una bolsa de oro para lucirla", precioRobux = 99, gamePassId = 2053906850, categoria = "cosmetico", icono = "cofre" },
} :: { Pase }

-- Developer Products (consumibles). Turbo registra solo todo producto con
-- turboMinutos (Services/Turbo)
Productos.PRODUCTOS = {
	{ id = "Turbo15", nombre = "Turbo 15 min", descripcion = "Dinero x2 durante 15 minutos de juego (se suma al que te quede)", precioRobux = 49, productId = 3721546571, icono = "rayo", turboMinutos = 15 },
	{ id = "Turbo60", nombre = "Turbo 60 min", descripcion = "Dinero x2 durante 60 minutos de juego (se suma al que te quede)", precioRobux = 149, productId = 3721546722, icono = "rayo", turboMinutos = 60 },
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
