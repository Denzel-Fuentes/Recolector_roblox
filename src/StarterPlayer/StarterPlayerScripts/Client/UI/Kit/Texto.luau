--!strict
--[[
	Texto (constructor del Kit)
	Unica responsabilidad: un TextLabel con las fuentes y reglas del tema.
	Todo lo visible acepta constante o estado de Fusion.

	  scope:Texto {
	    Texto, Tamano?, Color?, Fuente? ("titulo" | "cuerpo" | "negrita"),
	    Contorno? (Color3: contorno de las letras, p. ej. marino bajo blanco),
	    Alinear?, AlinearY?, Ajustar? (TextWrapped, por defecto si),
	    Escalar?, Rico?, Mayusculas?,
	    Size?, Position?, AnchorPoint?, AutomaticSize?, Orden?, ZIndex?,
	    Visible?, Nombre?, Hijos?
	  }

	En compacto (telefono) el tamano nunca baja de Tema.TEXTO_MINIMO_COMPACTO.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))
local Tema = require(script.Parent:WaitForChild("Tema"))
local Escala = require(script.Parent:WaitForChild("Escala"))

local Children = Fusion.Children

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Texto: U<string>?,
	Tamano: U<number>?,
	Color: U<Color3>?,
	Fuente: ("titulo" | "cuerpo" | "negrita")?,
	Contorno: U<Color3?>?,
	Alinear: Enum.TextXAlignment?,
	AlinearY: Enum.TextYAlignment?,
	Ajustar: boolean?,
	Escalar: boolean?,
	Rico: boolean?,
	Mayusculas: boolean?,
	Transparencia: U<number>?,
	Size: U<UDim2>?,
	Position: U<UDim2>?,
	AnchorPoint: U<Vector2>?,
	AutomaticSize: Enum.AutomaticSize?,
	Orden: U<number>?,
	ZIndex: U<number>?,
	Visible: U<boolean>?,
	Nombre: string?,
	Hijos: Fusion.Child?,
}

local FUENTES = {
	titulo = Tema.FUENTE_TITULO,
	cuerpo = Tema.FUENTE_CUERPO,
	negrita = Tema.FUENTE_NEGRITA,
}

return function(scope: any, p: Props): TextLabel
	local tamano = scope:Computed(function(use)
		local base = use(p.Tamano or 16) :: number
		return math.max(base, if use(Escala.compacto) then Tema.TEXTO_MINIMO_COMPACTO else 0)
	end)
	local texto = if p.Mayusculas
		then scope:Computed(function(use)
			return Tema.mayusculas(use(p.Texto or "") :: string)
		end)
		else (p.Texto or "")
	local contorno = nil
	if p.Contorno then
		contorno = scope:New("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = scope:Computed(function(use)
				return (use(p.Contorno) :: Color3?) or Paleta.UI_TINTA
			end),
			Enabled = scope:Computed(function(use)
				return use(p.Contorno) ~= nil
			end),
			Thickness = scope:Computed(function(use)
				return math.max(1.5, (use(tamano) :: number) * 0.1)
			end),
		})
	end
	return scope:New("TextLabel")({
		Name = p.Nombre or "Texto",
		Text = texto,
		Size = p.Size or UDim2.new(1, 0, 0, 24),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		AutomaticSize = p.AutomaticSize,
		BackgroundTransparency = 1,
		TextColor3 = p.Color or Paleta.UI_TINTA,
		TextTransparency = p.Transparencia,
		TextSize = tamano,
		FontFace = FUENTES[p.Fuente or "cuerpo"],
		TextXAlignment = p.Alinear or Enum.TextXAlignment.Left,
		TextYAlignment = p.AlinearY or Enum.TextYAlignment.Center,
		TextWrapped = p.Ajustar ~= false,
		TextScaled = p.Escalar == true,
		RichText = p.Rico == true,
		LayoutOrder = p.Orden,
		ZIndex = p.ZIndex,
		Visible = p.Visible,
		[Children] = { contorno, p.Hijos },
	})
end
