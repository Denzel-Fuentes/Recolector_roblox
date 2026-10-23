--!strict
--[[
	PedidosHandler
	Arranca los pedidos del dia y las insignias (lote 7). No hay remotes: los
	pedidos se cobran solos al cumplirse y las insignias se dan solas; el
	cliente lo lee todo del perfil (perfil.pedidos, perfil.logros,
	perfil.turboRestante).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Servicios = ServerScriptService:WaitForChild("Services")
local Pedidos = require(Servicios:WaitForChild("Pedidos"))
local Insignias = require(Servicios:WaitForChild("Insignias"))

Pedidos.iniciar()
Insignias.iniciar()
