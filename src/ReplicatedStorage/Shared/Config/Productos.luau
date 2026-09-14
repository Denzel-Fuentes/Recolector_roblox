--!strict
--[[
	Productos
	Catalogo de monetizacion (GDD seccion 10): Game Passes permanentes,
	Developer Products (Gemas) y lo que se compra con Gemas dentro del juego.

	TODOS los ids de Roblox son 0 (placeholder). Se crean en el Creator
	Dashboard una vez publicado el juego y se rellenan aqui. Con id 0:
	  - el servidor no llama a MarketplaceService;
	  - en Studio, con GameConfig.PASES_DEV_EN_STUDIO, los pases cuentan como
	    comprados para poder probar sus efectos.

	Ningun pase bloquea contenido: aceleran o embellecen. La coleccion entera se
	completa gratis, como en KOTAMON.
]]

local GameConfig = require(script.Parent.GameConfig)

export type Pase = {
	id: string,
	nombre: string,
	descripcion: string,
	precioRobux: number,
	gamePassId: number,
	categoria: string, -- "boost" | "conveniencia" | "cosmetico"
	trajeId: string?,
	skinId: string?,
}

export type Producto = {
	id: string,
	nombre: string,
	descripcion: string,
	precioRobux: number,
	productId: number,
	gemas: number,
}

local Productos = {}

Productos.PASES = {
	-- A) Boosts
	{ id = "PaseSuerte", nombre = "Pase de la Suerte", descripcion = "El pity de mascotas raras sube un tramo extra por montón (3% en vez de 2%)", precioRobux = 249, gamePassId = 0, categoria = "boost" },
	{ id = "PaseVelocidad", nombre = "Pase de Velocidad", descripcion = "+25% velocidad de movimiento permanente", precioRobux = 149, gamePassId = 0, categoria = "boost" },
	{ id = "PaseIman", nombre = "Pase de Imán", descripcion = "+50% radio de imán", precioRobux = 149, gamePassId = 0, categoria = "boost" },
	{ id = "AutoEnsamblaje", nombre = "Auto-Ensamblaje", descripcion = "Los fragmentos se ensamblan solos al tener los 5", precioRobux = 199, gamePassId = 0, categoria = "conveniencia" },
	-- B) Auto-farm y cosmeticos
	{ id = "AutoReciclaje", nombre = "Pase Auto-Reciclaje", descripcion = "La basura común se convierte en $ al recogerla, sin ocupar la bolsa", precioRobux = 299, gamePassId = 0, categoria = "conveniencia" },
	{ id = "TrajeDorado", nombre = "Traje Dorado", descripcion = "Traje de reciclador premium", precioRobux = 199, gamePassId = 0, categoria = "cosmetico", trajeId = "TP1" },
	{ id = "TrajeFantasma", nombre = "Fantasma del Vertedero", descripcion = "Traje de reciclador premium", precioRobux = 79, gamePassId = 0, categoria = "cosmetico", trajeId = "TP2" },
	{ id = "SkinNeon", nombre = "Base Neón", descripcion = "Tema decorativo para tu parcela", precioRobux = 249, gamePassId = 0, categoria = "cosmetico", skinId = "S1" },
	{ id = "SkinJardin", nombre = "Base Jardín", descripcion = "Tema decorativo para tu parcela", precioRobux = 99, gamePassId = 0, categoria = "cosmetico", skinId = "S2" },
}

-- C) Packs de Gemas (Developer Products, consumibles)
Productos.PRODUCTOS = {
	{ id = "GemasChico", nombre = "Puñado de Gemas", descripcion = "100 Gemas", precioRobux = 99, productId = 0, gemas = 100 },
	{ id = "GemasMediano", nombre = "Bolsa de Gemas", descripcion = "300 Gemas", precioRobux = 249, productId = 0, gemas = 300 },
	{ id = "GemasGrande", nombre = "Cubo de Gemas", descripcion = "700 Gemas", precioRobux = 499, productId = 0, gemas = 700 },
}

-- Lo que se compra con Gemas dentro del juego
Productos.SOBRE_PREMIUM = {
	id = "SobrePremium",
	nombre = "Sobre de Mascotas Premium",
	descripcion = "1 mascota limpia con probabilidad mejorada de Rara/Épica",
	precioGemas = GameConfig.PRECIO_SOBRE_GEMAS,
}

Productos.CONTENEDOR_DORADO = {
	id = "ContenedorDorado",
	nombre = "Contenedor Dorado",
	descripcion = "3 mascotas Raras o Épicas en buen estado. Requiere las 7 mejoras al máximo.",
	precioDinero = GameConfig.PRECIO_CONTENEDOR_DORADO,
	precioGemas = GameConfig.PRECIO_CONTENEDOR_DORADO_GEMAS,
}

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

function Productos.paseParaSkin(skinId: string): Pase?
	for _, p in Productos.PASES do
		if p.skinId == skinId then
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
