--!strict
--[[
	CrecerMontones (cliente)
	Unica responsabilidad: cuando un monton se repone, la colina nueva sale
	del suelo en vertical en vez de aparecer de golpe (ilusion de que crece).

	El servidor (Montones.llenar) crea el modelo ya con su tamano final y su
	sitio; aqui solo se baja la colina entera bajo el suelo y se sube a su
	posicion con PivotTo cada frame. Es puro decorado local: el servidor no
	vuelve a mover las partes ancladas, asi que lo que hace el cliente se
	queda, y el monton se puede excavar igual desde el primer momento.

	Solo se anima lo que llega despues de entrar: los montones que ya estaban
	al unirse el jugador no salen todos a la vez.
]]

local RunService = game:GetService("RunService")

local DURACION = 2.2 -- segundos que tarda en salir toda la colina
local ESPERA_REPLICACION = 0.15 -- que lleguen las partes antes de bajarla

local carpeta = workspace:WaitForChild("Montones")

local function crecer(modelo: Model)
	task.wait(ESPERA_REPLICACION)
	if not modelo.Parent or modelo:GetAttribute("Estado") ~= "lleno" then
		return
	end
	local final = modelo:GetPivot()
	local _, tam = modelo:GetBoundingBox()
	local hondo = tam.Y + 0.5
	modelo:PivotTo(final * CFrame.new(0, -hondo, 0))
	local t0 = os.clock()
	while modelo.Parent do
		local t = math.min(1, (os.clock() - t0) / DURACION)
		-- Sale deprisa y frena al final (ease-out cubico)
		local s = 1 - (1 - t) ^ 3
		modelo:PivotTo(final * CFrame.new(0, -hondo * (1 - s), 0))
		if t >= 1 then
			return
		end
		RunService.RenderStepped:Wait()
	end
end

-- Lo que replica en los primeros segundos es el patio que ya habia
local inicio = os.clock()
local GRACIA_INICIAL = 4

carpeta.ChildAdded:Connect(function(hijo)
	if hijo:IsA("Model") and os.clock() - inicio > GRACIA_INICIAL then
		task.spawn(crecer, hijo)
	end
end)
