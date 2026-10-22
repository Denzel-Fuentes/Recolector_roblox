--!strict
--[[
	TiposPatio (ModuleScript)
	Los tipos que comparten los modulos del patio (Montones, ObjetosPatio,
	FisicaBasura, Lanzamiento). Solo tipos: sin requires de servicios,
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
	cuadrante: number, -- 1..6 (GameConfig.CUADRANTES): zona y rebirth que pide
	zona: string, -- la mezcla de materiales de su basura (TablasProbabilidad.MEZCLA)
	estado: string, -- lleno | activo | agotado | reponiendo
	modelo: Model?, -- la colina (lleno), el contenedor de la basura (activo) o las marcas planas (agotado)
	numPiezas: number, -- objetos que dara al activarse
	objetosIniciales: number,
	objetosVivos: number,
	params: ModelosMonton.ParamsColina, -- forma de la colina (donde se reparte la basura)
	activadoPor: Player?, -- quien lo excavo, mientras cuente contra su limite (MONTONES_POR_JUGADOR)
	excavador: Player?, -- quien lo excavo (la prioridad de recogida)
	activadoEn: number, -- os.clock() al excavar
	reposicion: boolean, -- ya hay una reposicion programada
}

export type Objeto = {
	id: string,
	item: Item,
	modelo: PVInstance, -- el modelo real del item (basura, billete, bolsa caida...)
	reclamadoPor: Player?,
	suelto: boolean, -- ya no forma parte de la montana (una bolsa caida en el suelo)
	asentado: boolean, -- anclado tras quedarse quieto (FisicaBasura)
	monton: Monton?,
}

return {}
