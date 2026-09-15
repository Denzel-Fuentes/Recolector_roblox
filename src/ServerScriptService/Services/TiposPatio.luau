--!strict
--[[
	TiposPatio (ModuleScript)
	Los tipos que comparten los modulos del patio (Montones, ObjetosPatio,
	FisicaBasura, Iman, Lanzamiento). Solo tipos: sin requires de servicios,
	para que ningun modulo tenga que importar a otro solo por una anotacion y
	no haya ciclos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ModelosMonton = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("ModelosMonton"))
local Bolsa = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Bolsa"))

export type Item = Bolsa.Item

export type Monton = {
	id: number,
	ranura: BasePart,
	tamano: string,
	estado: string, -- lleno | activo | agotado
	modelo: Model?, -- la colina (lleno), el contenedor de la basura (activo) o las marcas planas (agotado)
	numPiezas: number, -- objetos que dara al activarse
	objetosIniciales: number,
	objetosVivos: number,
	params: ModelosMonton.ParamsColina, -- forma de la colina (donde se reparte la basura)
}

export type Objeto = {
	id: string,
	item: Item,
	modelo: PVInstance, -- el modelo real del item (basura, mascota, bolsa caida...)
	reclamadoPor: Player?,
	suelto: boolean, -- ya no forma parte de la montana (el iman lo arrastra o cayo en el suelo)
	asentado: boolean, -- anclado tras quedarse quieto (FisicaBasura)
	monton: Monton?,
}

return {}
