--!strict
--[[
	Encuadre (ModuleScript)
	Unica responsabilidad: poner un modelo dentro de un ViewportFrame y
	encuadrar su camara para que se vea entero. Sin Fusion: lo llaman los
	Computed que eligen QUE modelo se ensena.

	  Encuadre.mostrar(viewport, modelo, giro?) -> modelo (ya dentro)
]]

local Encuadre = {}

function Encuadre.mostrar(v: ViewportFrame, modelo: Model, giro: number?): Model
	for _, hijo in v:GetChildren() do
		if hijo:IsA("Model") then
			hijo:Destroy()
		end
	end
	modelo:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, giro or math.rad(-25), 0))
	modelo.Parent = v
	local cf, size = modelo:GetBoundingBox()
	local radio = math.max(size.X, size.Y, size.Z) * 0.62 + 0.6
	local cam = v.CurrentCamera
	if cam then
		local objetivo = cf.Position
		cam.CFrame = CFrame.lookAt(objetivo + Vector3.new(0, radio * 0.55, -radio * 2.1), objetivo)
		cam.FieldOfView = 40
	end
	return modelo
end

return Encuadre
