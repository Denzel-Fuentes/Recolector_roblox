--!strict
--[[
	PoseBrazos
	La pose de "brazos al frente sujetando la bolsa abierta" de quien esta en
	el patio, y donde quedan las manos con esa pose (para soldar la bolsa
	entre ellas).

	Se aplica escribiendo Transform de las articulaciones en RunService.Stepped,
	DESPUES de que el Animator haya puesto el suyo: es la forma documentada de
	posar por codigo, y vale igual para Motor6D (rigs viejos) y para
	AnimationConstraint (rigs nuevos, sin C0), que comparten esa propiedad.
	La escribe cada cliente para todos los personajes con EnPatio (Escena) y
	TAMBIEN el servidor (Patio): Transform no se replica, y la vista de
	servidor de Studio (donde el usuario mira a su personaje desde fuera) no
	corre scripts de cliente.

	Codos y munecas van a identidad para que el brazo quede recto: si no, la
	animacion de idle deja el codo doblado y las manos no llegan a la bolsa.
]]

local PoseBrazos = {}

local ELEVACION = math.rad(70)
local CIERRE = math.rad(15) -- las manos se juntan hacia el centro (agarran el borde de la bolsa)

-- R15: la articulacion vive en la parte hija (RightUpperArm.RightShoulder) y su
-- marco esta alineado con el torso: X eleva al frente, Z acerca al centro (es
-- negativa en el brazo derecho, que esta en +X).
-- R6: "Right Shoulder" vive en Torso y su C0 gira 90 grados en Y, asi que el
-- eje que eleva al frente es Z (y en el izquierdo va al reves). Sin probar
-- con un avatar R6: el juego usa R15.
local TRANSFORMS: { [string]: CFrame } = {
	RightShoulder = CFrame.Angles(ELEVACION, 0, -CIERRE),
	LeftShoulder = CFrame.Angles(ELEVACION, 0, CIERRE),
	RightElbow = CFrame.identity,
	LeftElbow = CFrame.identity,
	RightWrist = CFrame.identity,
	LeftWrist = CFrame.identity,
	["Right Shoulder"] = CFrame.Angles(0, 0, ELEVACION),
	["Left Shoulder"] = CFrame.Angles(0, 0, -ELEVACION),
}
local PARTES = { "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "RightHand", "LeftHand", "Torso" }

function PoseBrazos.aplicar(personaje: Model)
	for _, nombre in PARTES do
		local parte = personaje:FindFirstChild(nombre)
		if parte then
			for _, hijo in parte:GetChildren() do
				local transform = TRANSFORMS[hijo.Name]
				if transform and (hijo:IsA("Motor6D") or hijo:IsA("AnimationConstraint")) then
					(hijo :: any).Transform = transform
				end
			end
		end
	end
end

-- Punto medio entre las dos manos con la pose puesta, en coordenadas del
-- torso (UpperTorso en R15, Torso en R6), calculado con las medidas reales
-- del avatar: largo del brazo desde el hombro. Devuelve (torso, offset).
function PoseBrazos.puntoManos(personaje: Model): (BasePart?, CFrame?)
	local upper = personaje:FindFirstChild("UpperTorso")
	if upper and upper:IsA("BasePart") then
		local hombro = upper:FindFirstChild("RightShoulderRigAttachment")
		local brazo = personaje:FindFirstChild("RightUpperArm")
		local antebrazo = personaje:FindFirstChild("RightLowerArm")
		local mano = personaje:FindFirstChild("RightHand")
		local hy, hz = 0.55, 0
		if hombro and hombro:IsA("Attachment") then
			hy, hz = hombro.Position.Y, hombro.Position.Z
		end
		local largo = 2.6
		if brazo and brazo:IsA("BasePart") and antebrazo and antebrazo:IsA("BasePart") and mano and mano:IsA("BasePart") then
			largo = brazo.Size.Y + antebrazo.Size.Y + mano.Size.Y * 0.5
		end
		local alcance = largo * math.cos(CIERRE)
		return upper, CFrame.new(0, hy - alcance * math.cos(ELEVACION), hz - alcance * math.sin(ELEVACION))
	end
	local torso = personaje:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		local largo = 2
		return torso, CFrame.new(0, 0.5 - largo * math.cos(ELEVACION), -largo * math.sin(ELEVACION))
	end
	return nil, nil
end

return PoseBrazos
