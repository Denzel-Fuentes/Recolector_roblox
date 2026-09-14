--!strict
--[[
	Parcelas (ModuleScript)
	Unica responsabilidad: que parcela es de quien y que se ve en ella.

	Asignacion: al cargar el perfil se toma la parcela libre de menor indice
	(tag Parcela, atributo Dueno vacio). Al salir se libera y se vacia. Las 16
	parcelas estan horneadas en el place; aqui solo se rellenan.

	Render (todo server-side para que los VISITANTES lo vean):
	  Estanteria  una figurina whitebox por cada figurina del perfil, en los
	              marcadores SlotEstanteria (atributo Indice).
	  Exhibidor   la mascota exhibida en cada Pedestal (atributo Indice).
	  Radio       Sound con la cinta puesta (id placeholder = silencio) y el
	              atributo CintaId para que el cliente anime los carretes.
	  Skin        recolorea las partes con atributo Pintable.
	  Cartel      "Base de X" / "Parcela libre".

	Lo generado va en una carpeta Contenido dentro de la parcela y se destruye
	entero en cada render: es mas simple y mas seguro que sincronizar diferencias,
	y una parcela cambia pocas veces por minuto.

	Me gusta: un visitante puede darlo UNA vez por sesion por parcela. Es la
	unica interaccion social sobre la base (no hay robo ni edicion ajena).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))
local ModelosMascota = require(Shared:WaitForChild("Utilidades"):WaitForChild("ModelosMascota"))
local Senal = require(Shared:WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Mundo = require(Servicios:WaitForChild("Mundo"))

local Parcelas = {}

Parcelas.alAsignar = Senal.nueva() :: Senal.Senal<Player, Model>

local asignadas: { [Player]: Model } = {}
local meGustaDados: { [Player]: { [Model]: boolean } } = {}
local renderPendiente: { [Player]: boolean } = {}

local function cartelDe(parcela: Model): TextLabel?
	local cartel = parcela:FindFirstChild("Cartel")
	local bb = cartel and cartel:FindFirstChild("CartelDueno")
	local texto = bb and bb:FindFirstChild("Texto")
	return if texto and texto:IsA("TextLabel") then texto else nil
end

local function ponerCartel(parcela: Model, texto: string)
	local tl = cartelDe(parcela)
	if tl then
		tl.Text = texto
	end
end

function Parcelas.de(jugador: Player): Model?
	return asignadas[jugador]
end

function Parcelas.duenoDe(parcela: Model): Player?
	local userId = parcela:GetAttribute("Dueno")
	if typeof(userId) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

function Parcelas.asignar(jugador: Player): Model?
	if asignadas[jugador] then
		return asignadas[jugador]
	end
	for _, parcela in Mundo.parcelas() do
		if parcela:GetAttribute("Dueno") == nil then
			parcela:SetAttribute("Dueno", jugador.UserId)
			parcela:SetAttribute("NombreDueno", jugador.DisplayName)
			asignadas[jugador] = parcela
			ponerCartel(parcela, Textos.formatear(Textos.BASE.visitando, { nombre = jugador.DisplayName }))
			Parcelas.alAsignar:Fire(jugador, parcela)
			return parcela
		end
	end
	warn("Parcelas: no hay parcela libre para " .. jugador.Name)
	return nil
end

local function limpiarContenido(parcela: Model)
	local contenido = parcela:FindFirstChild("Contenido")
	if contenido then
		contenido:Destroy()
	end
	local radio = parcela:FindFirstChild("Radio")
	if radio then
		radio:SetAttribute("CintaId", nil)
		local sonido = radio:FindFirstChild("SonidoCinta", true)
		if sonido then
			sonido:Destroy()
		end
	end
end

local function pintar(parcela: Model, skin: DefinicionesColeccionables.SkinBase?)
	for _, d in parcela:GetDescendants() do
		if d:IsA("BasePart") then
			local tipo = d:GetAttribute("Pintable")
			if tipo == "losa" then
				d.Color = if skin then skin.colorLosa else Paleta.LOSA_PARCELA
			elseif tipo == "mueble" then
				d.Color = if skin then skin.colorMueble else Paleta.MUEBLE
			elseif tipo == "borde" then
				d.Color = if skin then skin.colorBorde else Paleta.MUROS
			end
		end
	end
end

local function marcadores(parcela: Model, mueble: string, nombreMarcador: string): { [number]: BasePart }
	local mapa = {}
	local m = parcela:FindFirstChild(mueble)
	if m then
		for _, hijo in m:GetChildren() do
			if hijo.Name == nombreMarcador and hijo:IsA("BasePart") then
				local indice = hijo:GetAttribute("Indice")
				if typeof(indice) == "number" then
					mapa[indice] = hijo
				end
			end
		end
	end
	return mapa
end

function Parcelas.renderizar(jugador: Player)
	local parcela = asignadas[jugador]
	local perfil = Perfiles.obtener(jugador)
	if not parcela or not perfil then
		return
	end
	limpiarContenido(parcela)
	local contenido = Instance.new("Folder")
	contenido.Name = "Contenido"
	contenido.Parent = parcela

	-- Estanteria: figurinas en orden F1..F12
	local slots = marcadores(parcela, "Estanteria", "SlotEstanteria")
	for i, def in DefinicionesColeccionables.FIGURINAS do
		local slot = slots[i]
		if slot and perfil.figurinas[def.id] then
			local modelo = ModelosMascota.figurina(def)
			modelo:PivotTo(slot.CFrame * CFrame.new(0, -0.9, 0))
			modelo.Parent = contenido
		end
	end

	-- Exhibidor: mascotas en los pedestales
	local pedestales = marcadores(parcela, "Exhibidor", "Pedestal")
	for indice, uid in perfil.exhibidas do
		local ped = pedestales[tonumber(indice) or 0]
		local copia = perfil.mascotas[uid]
		local def = copia and DefinicionesMascotas.obtener(copia.id)
		if ped and copia and def then
			local modelo = ModelosMascota.mascota(def, copia.estado, copia.sucia)
			modelo:PivotTo(ped.CFrame * CFrame.new(0, -0.5, 0))
			modelo:SetAttribute("Uid", uid)
			ModelosMascota.etiqueta(modelo, def.nombre .. " · " .. DefinicionesMascotas.nombreEstado(copia.estado), Paleta.RAREZA[def.rareza], ModelosMascota.alturaMascota(def))
			modelo.Parent = contenido
		end
	end

	-- Radio
	local radio = parcela:FindFirstChild("Radio")
	if radio and perfil.cintaPuesta then
		local cinta = DefinicionesColeccionables.CINTA_POR_ID[perfil.cintaPuesta]
		if cinta then
			radio:SetAttribute("CintaId", cinta.id)
			local cuerpo = radio:FindFirstChild("Cuerpo")
			if cuerpo and cinta.sonidoId ~= 0 then
				local sonido = Instance.new("Sound")
				sonido.Name = "SonidoCinta"
				sonido.SoundId = "rbxassetid://" .. cinta.sonidoId
				sonido.Looped = true
				sonido.RollOffMaxDistance = 60
				sonido.Volume = 0.5
				sonido.Parent = cuerpo
				sonido:Play()
			end
		end
	end

	-- Skin
	pintar(parcela, if perfil.skinBase then DefinicionesColeccionables.SKIN_POR_ID[perfil.skinBase] else nil)
end

-- Varios cambios seguidos (p. ej. depositar 5 figurinas) producen un solo render
function Parcelas.renderizarPronto(jugador: Player)
	if renderPendiente[jugador] then
		return
	end
	renderPendiente[jugador] = true
	task.delay(0.2, function()
		renderPendiente[jugador] = nil
		if jugador.Parent then
			Parcelas.renderizar(jugador)
		end
	end)
end

function Parcelas.liberar(jugador: Player)
	local parcela = asignadas[jugador]
	asignadas[jugador] = nil
	meGustaDados[jugador] = nil
	renderPendiente[jugador] = nil
	if parcela then
		limpiarContenido(parcela)
		pintar(parcela, nil)
		parcela:SetAttribute("Dueno", nil)
		parcela:SetAttribute("NombreDueno", nil)
		ponerCartel(parcela, Textos.BASE.parcelaLibre)
	end
end

function Parcelas.posicionCasa(jugador: Player): Vector3?
	local parcela = asignadas[jugador]
	if not parcela then
		return nil
	end
	local spawn = parcela:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position
	end
	return parcela:GetPivot().Position + Vector3.new(0, 4, 0)
end

function Parcelas.teletransportar(jugador: Player, destino: string): boolean
	local personaje = jugador.Character
	if not personaje then
		return false
	end
	local pos: Vector3?
	local mirarA: Vector3?
	if destino == "casa" then
		pos = Parcelas.posicionCasa(jugador)
		local parcela = asignadas[jugador]
		mirarA = if parcela then parcela:GetPivot().Position else nil
	else
		pos = Mundo.posicionPlaza()
		mirarA = Vector3.new(0, pos.Y, 0)
	end
	if not pos then
		return false
	end
	local cf = if mirarA then CFrame.lookAt(pos, Vector3.new(mirarA.X, pos.Y, mirarA.Z)) else CFrame.new(pos)
	personaje:PivotTo(cf)
	Perfiles.estadistica(jugador, "teletransportes", 1)
	return true
end

-- Devuelve (ok, motivo). El dueno recibe el me gusta en su perfil.
function Parcelas.darMeGusta(visitante: Player, parcela: Model): (boolean, string)
	local dueno = Parcelas.duenoDe(parcela)
	if not dueno then
		return false, "libre"
	end
	if dueno == visitante then
		return false, "propia"
	end
	local dados = meGustaDados[visitante]
	if not dados then
		dados = {}
		meGustaDados[visitante] = dados
	end
	if dados[parcela] then
		return false, "repetido"
	end
	dados[parcela] = true
	local perfilDueno = Perfiles.obtener(dueno)
	if perfilDueno then
		perfilDueno.meGusta += 1
		Perfiles.marcarSucio(dueno)
	end
	Perfiles.estadistica(visitante, "meGustaDados", 1)
	return true, dueno.DisplayName
end

function Parcelas.parcelaDe(inst: Instance): Model?
	return Mundo.parcelaDe(inst)
end

function Parcelas.esParcela(inst: Instance): boolean
	return inst:IsA("Model") and CollectionService:HasTag(inst, "Parcela")
end

return Parcelas
