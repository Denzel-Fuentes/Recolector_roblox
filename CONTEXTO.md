# Recíclatas (CleanRecycle) — estado del proyecto

Réplica mecánica de KOTAMON para Roblox, en whitebox low-poly sin texturas.
El diseño completo está en `docs/GDD.md`; este documento es lo que NO se deduce
del código: qué hay, cómo se trabaja y por qué se decidió lo no obvio.

Última pasada: 15 sep 2026 (lote 7: refactor a módulos de una responsabilidad;
antes lotes 3–6: colina, basura real, física, clic mantenido). Estado: **todas las mecánicas del GDD implementadas
y verificadas en Play Solo**; pendiente la prueba con 2+ jugadores y publicar.

## 1. Qué hay

| Sistema | Dónde | Estado |
|---|---|---|
| Patio compartido: 12 **colinas** de basura; al activar, la colina se sustituye por una **montaña de basura real con física** (30–280 objetos: latas, llantas, cajas, botellas…, sin etiquetas; caen, se asientan y se anclan; nada flota); **solo se recoge con clic** (o Imán), reclamo atómico, **sin caducidad**, repoblación | `Services/Botin.luau` (fachada) → `GeneradorBotin`, `ObjetosPatio`, `FisicaBasura`, `Montones`, `Iman`, `Lanzamiento` + `BotinHandler` | verificado (`montonPiezas`, `reacomodo`, `sinRecogidaAutomatica`, `variedadBasura`) |
| Puntería: **mantener F carga y lanza la bolsa entera**; si falla queda en el suelo y cualquiera la recoge | `Services/Lanzamiento.luau` | verificado (`lanzarBolsa`, `lanzarBolsaFallo`) |
| Primera persona automática en el patio con retícula (punto), manos+bolsa en 2D (Frames), brazos extendidos (cliente y servidor) sujetando una bolsa abierta soldada entre las manos | `Services/Patio.luau`, `Utilidades/PoseBrazos`, `Client/Camara.client`, `Client/UI/Manos.client`, `Escena.client` | verificado (`enPatio`, capturas) |
| HUD estilo KOTAMON: píldoras ($, cartas, gemas), barras verticales de energía, fuerza y **bolsa** (sin números; "¡LLENA!" en rojo), dock Q/J/L/B, "MANTÉN F PARA LANZAR" | `Client/UI/HUD.client.luau` | verificado (captura) |
| Bolsa: todo lo recogido ocupa hueco (billetes incluidos) y **sólo el contenedor paga**, bonus +25% por bolsa llena | `Services/Bolsa.luau` | verificado (`billeteEnBolsa`, `sinDineroAlRecoger`, `bonusBolsaLlena`) |
| Energía, refrescos (máquina), regen lenta | `Services/Energia.luau` | verificado |
| 41 mascotas, 5 estados, fusión 3→1, venta, exhibición, pasivas, Rey Reciclón | `Config/DefinicionesMascotas`, `Services/Mascotas.luau` | verificado |
| Reparación: limpieza (frotar manchas) y ensamblaje (girar 5 piezas), Auto-Ensamblaje | `Services/Reparacion.luau`, `Client/UI/Reparacion.luau` | verificado por UI simulada |
| 7 mejoras × 10 niveles, coste ×1.6 | `Config/DefinicionesMejoras`, `Services/Mejoras.luau` | verificado (232.430 $ para maxear) |
| Tienda: Sobre Premium, Contenedor Dorado, trajes, skins, gemas, pases; modal de probabilidades | `Services/Tienda.luau`, `Client/UI/Tienda.luau`, `UI/Probabilidades.luau` | verificado |
| 6 parcelas (6 jugadores por servidor): estantería, radio, exhibidor, mesa, teléfono, almacén, me gusta, skins | `Services/Parcelas.luau`, `Client/UI/Base.luau` | verificado |
| 12 figurinas (6 fijas en escondites), 7 cintas, 3 trajes gratis + 2 premium | `Config/DefinicionesColeccionables`, `Services/Coleccionables.luau` | verificado |
| 40 logros en 11 categorías, progreso compartido servidor/cliente | `Config/DefinicionesLogros`, `Utilidades/ProgresoLogros`, `Services/Logros.luau` | verificado |
| Persistencia DataStore (pcall, `cargado`, UpdateAsync, autosave, BindToClose) | `Services/DataService.server.luau` | sin probar: exige publicar |
| Monetización: pases, ProcessReceipt idempotente, modo dev | `Services/Monetizacion.luau` | verificado (recibo duplicado no paga dos veces) |
| HUD, álbum, notificaciones, feed social, gamepad/táctil | `Client/UI/*` | verificado |
| Admin por chat (`/dar`, `/maxmejoras`, `/pases`, `/reset`…) | `Services/AdminHandler.server.luau` | escrito |

## 2. Cómo se trabaja

### Sincronizar código a Studio

Flujo normal: `rojo serve default.project.json --port 34872` y **Connect** en el
plugin de Rojo. Rojo 7 crea `X.luau` → ModuleScript, `X.server.luau` → Script,
`X.client.luau` → LocalScript, `X.model.json` → instancia.

Flujo de emergencia (cuando no se puede pulsar Connect, p. ej. trabajando por
MCP): `herramientas/servir-fuentes.ps1` sirve `src/` por HTTP en
`localhost:8123` y `herramientas/instalar-desde-http.luau`, ejecutado en la
barra de comandos (o `execute_luau`) sobre el DataModel Edit, crea/actualiza el
mismo árbol con las mismas reglas. Es idempotente y sólo escribe `Source` si
cambió; cuando el plugin de Rojo se conecte no verá diferencias.

### El mundo

`workspace.Mundo` es geometría REAL del place, construida por
`herramientas/construir-mundo.luau` (que llama a
`ServerStorage/Herramientas/ConstructorMundo`). **Tras construir hay que guardar
el place.** `SetupMundo` sólo lo adopta; si falta, lo construye en runtime como
fallback y avisa. Todo se localiza por tags/atributos, nunca por nombre:
`RanuraMonton` (12), `Parcela` (6), `FigurinaFija`, `Contenedor`, `MaquinaRefrescos`,
`Limite`, `SoloDecorado`; atributos `Mueble`, `Pintable`, `NPC`, `IndiceParcela`.

### Probar

- `ServerStorage.EjecutarPrueba:Invoke(nombre, ...)` (sólo Studio) ejecuta las
  pruebas de `Services/PruebasDefinidas/` (por área: Patio, Bolsa, Progreso) DENTRO de la VM del servidor.
  Existe porque la barra de comandos / execute_luau corren en la VM del plugin y
  allí `require` devuelve copias vacías de los módulos.
- `ReplicatedStorage.EjecutarPruebaCliente:Invoke("abrir", "Album")` abre
  paneles desde la VM del cliente.
- Si el hilo del MCP no puede invocar BindableFunctions ("additional values for
  the Capabilities property", visto en Studio tras reabrir el place), la misma
  prueba se lanza por atributos (ese hilo tampoco puede crear ni mover scripts
  ni usar HttpService: para sincronizar codigo en ese caso solo queda el plugin
  de Rojo; `multi_edit` del MCP sirve para parches pequenos): `ServerStorage:SetAttribute("Prueba",
  "3:montonPiezas")` (número de orden + nombre|args) y el texto queda en el
  atributo `Resultado`; en el cliente `ReplicatedStorage` con `PruebaCliente` /
  `ResultadoCliente`. El número evita ejecuciones dobles con señales diferidas.
- Multijugador: Studio → Test → *Clients and Servers* (2 jugadores). Ver
  `README-pruebas.md`.

## 3. Decisiones no obvias (y por qué)

### Arquitectura del patio (lote 7: limpieza)

`Botin.luau` llegó a 1.060 líneas con siete responsabilidades. Se partió en
módulos de una responsabilidad, sin ciclos, y `Botin` quedó como **fachada**
(lo único que `BotinHandler`, `Admin` y las pruebas importan):

| Módulo | Responsabilidad | Depende de |
|---|---|---|
| `TiposPatio` | solo tipos (`Item`, `Monton`, `Objeto`) | `ModelosMonton`, `Bolsa` (tipo Item) |
| `GeneradorBotin` | qué sale de un montón (pity, lotes, relleno); devuelve items | Perfiles, Mascotas, Coleccionables, Monetizacion |
| `ObjetosPatio` | registro de objetos, `modeloPara`, reclamo atómico, vuelo a la bolsa; publica `alRetirar` | Bolsa, Economia, Perfiles, Mejoras |
| `FisicaBasura` | soldar/soltar/anclar, cascada, bucle de asentar | Colisiones, ObjetosPatio (lee), `alRetirar` |
| `Montones` | colina → montaña → agotado → repoblado; `excavar` | GeneradorBotin, ObjetosPatio, FisicaBasura, Energia, Mundo, `alRetirar` |
| `Iman` | la única recogida sin clic | ObjetosPatio, FisicaBasura, Montones |
| `Lanzamiento` | la puntería | ObjetosPatio, Bolsa, Mundo |

La regla que evita ciclos: **quien retira un objeto no sabe quién lo cuenta**.
`ObjetosPatio.reclamar` dispara `alRetirar`; `Montones` descuenta y agota,
`FisicaBasura` despierta a los vecinos. Antes `quitarObjeto` llamaba a los dos
a mano y cualquier módulo nuevo tenía que tocar `Botin`.

Lo mismo en `Utilidades`: `ModelosMascota` (830 líneas) se partió en
`Primitivas` (los ladrillos y la etiqueta), `ModelosMascota` (mascotas y
fragmentos), `ModelosObjetos` (basura, tesoros, coleccionables, bolsas) y
`ModelosMonton` (la colina y sus puntos). `Geometria.distanciaASuperficie`
es una sola función para servidor y cliente: antes cada uno tenía su copia y
un desajuste habría hecho que el cliente resaltara lo que el servidor rechaza.

Las pruebas (`PruebasDefinidas/`, carpeta con `init.luau`) están por área:
`Patio`, `Bolsa`, `Progreso`, con `Comunes` para los ayudantes; `init` las
junta en una tabla y falla si dos áreas repiten un nombre.

Se quitaron las señales sin suscriptores (`alReclamar`, `alActivar`,
`alAcertar`, `alReciclarLanzando`), `alturaMonton`, el parámetro `escala`
de `parametrosColina` (la colina ya no encoge) y el estado de física que
vivía dentro de cada `Objeto` (ahora es una tabla privada de `FisicaBasura`).

### El reclamo compartido es atómico sin locks

`ObjetosPatio.reclamar` comprueba `obj.reclamadoPor` y lo asigna en la misma llamada,
sin ningún yield entre medias. Luau es monohilo: dos reclamos "simultáneos"
(dos eventos de red, o el bucle del imán de dos jugadores) siempre se resuelven
en orden. El perdedor ve `noExiste` (el objeto ya se retiró del registro), no
`yaReclamado`: sólo hay ventana para `yaReclamado` si la bolsa del ganador
estaba llena y se liberó el bloqueo. Prueba: `reclamoAtomico`.

### Nada se recoge por pasar encima: clic, o el Imán

Decisión del usuario (lote 4): sin la mejora Imán **nada** entra en la bolsa
por cercanía; cada objeto se recoge con clic, y **manteniendo el clic** (dedo
en táctil, X en gamepad) se recoge en cadena lo que pase por la mira, una
pieza cada `INTERVALO_RECOGIDA` (0,16 s ≥ `COOLDOWN_REMOTE`, lo que el servidor
acepta por jugador; el mismo id no se reenvía hasta que el servidor lo retira
y el objeto que vuela a la bolsa deja de ser consultable por el rayo, así el
siguiente entra al instante) (`ReclamarObjetoEvent` →
`ObjetosPatio.reclamar(..., "clic")`), validado en el servidor por distancia del
personaje a la **superficie** del objeto ≤ Alcance + 2 (medir al centro engaña
con modelos grandes; el cliente mide igual para el resaltado). El bucle cada
0,2 s solo sirve al Imán: dentro de su radio suelta el objeto de la colina y
lo arrastra con `PivotTo`, y cuando un objeto **arrastrado** llega a
`DISTANCIA_RECLAMO_IMAN` lo mete en la bolsa. No se usa `.Touched`. Al
reclamar, el modelo vuela 0,25 s al torso del jugador (feedback del clic) y se
destruye al llegar. La bolsa caída también se recoge con clic.

### El pity es por jugador y persiste

Cada monton sin Rara+ suma 1; una Rara+ lo resetea. La probabilidad se calcula
en `TablasProbabilidad.probabilidadRara` (8% + 2%·pity, tope 60%; el Pase de la
Suerte sube el paso a 3%). Medido con 300 montones grandes: pity 0 → 6%, pity
10 → 37%, pity 26 → 57% (teóricos 8/28/60). Los fragmentos usan tabla plana con
sesgo del 50% hacia mascotas a medias para que el ensamblaje converja.

### `TablasProbabilidad` es la única fuente de odds

Servidor (`Tienda`, `GeneradorBotin`) y cliente (`Probabilidades`) leen el mismo módulo
de ReplicatedStorage; `verificar()` hace assert al cargar de que cada tabla
suma 100. Es el requisito de política de Roblox sobre ítems aleatorios pagados.

### Persistencia propia, sin ProfileStore

Cero dependencias (no hay Wally). Reglas: todo en `pcall` con reintentos; un
perfil que no cargó nunca se guarda (`Perfiles.estaCargado`); `UpdateAsync`;
autosave 120 s; `PlayerRemoving` espera 0,2 s para guardar DESPUÉS de que
Bolsa/Parcelas toquen el perfil. Sin bloqueo de sesión: migrar a ProfileStore
si algún día hay servidores concurrentes escribiendo el mismo perfil.

### El dinero sólo sale del contenedor (lote 8)

Decisión del usuario: **recoger nunca paga**. Todo lo que se levanta del patio
(basura, billetes, tesoros, mascotas…) ocupa un hueco de la bolsa y sólo se
convierte en $ al depositarlo (prompt del Contenedor o bolsa lanzada), las dos
vías por `Bolsa.depositarItems` con `Bolsa.valorDeposito(item)` como única
tabla de precios. Consecuencias:

- Los billetes ya no dan "+$" al tocarlos: son un objeto más (`billeteEnBolsa`).
  El Imán tampoco los excluye del corte por bolsa llena.
- El **Pase Auto-Reciclaje** del GDD (basura → $ al recogerla, sin ocupar
  hueco) se retiró de `Config/Productos`: era exactamente lo que la regla
  prohíbe, y en Studio (`PASES_DEV_EN_STUDIO`) hacía que la basura
  "desapareciera en dinero" sin llenar la bolsa, que fue lo que el usuario vio.
- El HUD no muestra `n/cap`: la bolsa es una **barra vertical junto a la de
  fuerza** que se llena, y en rojo pulsando dice "¡LLENA!" (`Textos.HUD`).
  La bolsa 2D de las manos también crece con el llenado.
- Siguen dando $ sin pasar por el contenedor: vender mascotas/duplicados a
  Doña Chatarra (en la caseta) y la recompensa de cada logro. No son botín.

### La bolsa no persiste, y lo que vale dinero se pierde al salir

Al desconectar, las mascotas, fragmentos y coleccionables van al perfil si
caben (`Bolsa.vaciarAlSalir`); basura, billetes y tesoros se pierden. Antes se
reciclaban sin bonus, pero con la regla de arriba eso sería un atajo (salir y
volver en vez de caminar al contenedor). Perder una Épica por una caída de
conexión sería cruel; perder una bolsa de latas, no.

### Las pasivas sólo actúan exhibidas

Las 6 mascotas del exhibidor dan +2/4/6% al reciclar su material (Rey: +10% a
todo). Exhibir tiene así un motivo además de presumir.

### Modo dev de pases

En Studio, `GameConfig.PASES_DEV_EN_STUDIO` hace que todos los Game Passes
cuenten como comprados sin tocar el perfil (viaja en `extras` del snapshot, no
en `pasesCache`, para no envenenar perfiles). `/pases off` lo apaga para probar
sin ellos. Los ids reales (0 = placeholder) se rellenan en `Config/Productos` y
`Config/DefinicionesLogros` (badges) al publicar.

### Whitebox: grises por función + color por material

Escenario: 110 suelo del patio, 140 montones/decorado, 165 caminos/muros, 195
losas/contenedor, 215 muebles/NPC, 240 caseta. Objetos y mascotas llevan color
plano por material y disco de rareza: set y rareza son información de juego.
Sin neón en el mapa: el anillo amarillo del montón activado se quitó a petición
del usuario; la señal es la propia montaña, que pasa de gris a colores de
material. Todo en `Config/Paleta.luau`.

### Replicación del mundo en el cliente

`workspace.Mundo` aparece en el cliente antes que sus 1.191 descendientes.
Cualquier script de cliente que busque muebles debe escuchar `DescendantAdded`
(ver `Escena.client.luau`); una pasada única al arrancar se queda corta.

### ⚠️ `Model.WorldPivot` se ignora si hay `PrimaryPart`

Medido en Studio: asignar `WorldPivot` a un modelo con `PrimaryPart` no hace
nada; el pivote sigue siendo la parte principal. Durante el lote 1 todos los
modelos "en el suelo" (montones, objetos, mascotas) se colocaban con `PivotTo`
y quedaban HUNDIDOS la altura de su parte principal: por eso los montones se
veían como bloques pequeños (solo asomaba la cima). Lo correcto es
`PrimaryPart.PivotOffset = PrimaryPart.CFrame:Inverse()`
(`Primitivas.pivoteEnSuelo`). Cualquier modelo nuevo debe pasar por ahí.

### La colina se convierte en una montaña de basura, y no caduca

Un montón sin activar es una **colina lisa** (`ModelosMonton.monton` →
`parametrosColina` + bolas hundidas `Loma_i`: una principal y 2–3 lomas
secundarias hacia el borde, semilla fija por montón). Radio = el de
`TAMANOS_MONTON`, altura ∝ `numPiezas`. El usuario quiere ponerle después una
textura de basura; con primitivas eso será un MeshPart, hoy es gris
`Paleta.MONTON`.

Al activarlo, la colina **se sustituye entera por una montaña de basura con
su mismo bulto** (decisión del usuario, lote 5: "mucha basura, equivalente al
tamaño del montón, no un poquito"): `numPiezas` objetos (30–40 / 80–110 /
200–280 según tamaño) con **modelo real** (latas, llantas, barriles, botellas,
bidones, cajas de cartón, periódicos, plátanos, huesos… y los premios:
mascotas, fragmentos, tesoros, billetes, coleccionables; sin etiquetas)
repartidos por TODO el volumen del casquete (`puntosEnColina`: muestreo
"mejor candidato" sesgado hacia la capa exterior para que no se vea el
interior), revueltos (giro libre, inclinación ±40°), brotando de abajo arriba
en 1 s. Una grande son ~270 objetos / ~800 partes.

**Premios por lotes**: `TAMANOS_MONTON[t].lotes` (14–18 / 22–28 / 34–44, los
antiguos numPiezas) son las tiradas de `TIPO_OBJETO`; el resto hasta
`min/max` es basura de relleno. Así la cantidad de basura no multiplica
mascotas ni fragmentos. La basura sí vale dinero: un montón da ahora 3–6×
más $ que antes (ver §4, calibración pendiente).

**La basura tiene física** (lote 6, "¿por qué se queda flotando? colócale
física"): cada objeto es un modelo soldado a su parte principal, sin anclar,
**mientras cae** en el grupo de colisión `Basura` (`Services/Colisiones`:
choca con el suelo y con otra basura, no con los personajes: una lluvia de
270 piezas no debe empujarlos ni encajonarlos). Las lomas de la colina se
destruyen al activar (chocarían con la basura). Lo que lleva ~1 s quieto se
**ancla y pasa a Default** (`FisicaBasura`, cada 0,5 s; tope 8 s por si algo
rueda): la basura asentada **sí choca con los personajes** y la montaña se
sube como escombros (decisión del usuario: "no quiero traspasar la basura");
nunca se ancla una pieza con un personaje metido en su caja
(`personajeEncima`), que quedaría encajonado. El objeto que vuela a la bolsa
va sin colisión. Así el servidor tampoco simula cientos de cuerpos, y
al recoger una pieza se **despiertan** las vecinas de encima (radio 5), que
caen y se vuelven a asentar; una pieza suelta que se mueve > 1 stud despierta
a su vez a las suyas (cascada). `SetNetworkOwner(nil)`: lo simula el servidor,
nadie empuja basura desde su cliente. Con física la montaña asienta más baja
y ancha que la colina (grande: ~5,5 de 10 studs): se compensa con fricción 2 y
lluvia de abajo arriba en 1,5 s. Con 0 objetos → `agotado` (marcas planas
`Resto`).

Historia: lote 2, las piezas rodaban al suelo ("aparecía muy poca basura");
lote 3, cono de bloques que se convertían en sitio ("son bloques, no basura de
verdad", y se recogían al pasar); lote 4, basura real clavada sobre la colina
que encogía ("me gusta cómo colocaste los montones, pero que se reemplace del
todo por basura"); lote 5, montaña de basura anclada sobre suelo invisible
("se queda flotando"); lote 6, física.

`ModelosObjetos.basura(material, rng?)`: 4 formas por material, cuerpo en el
color del material y detalles con `Paleta.escalar`; atributo `Forma`;
`ScaleTo(1.35)` para que abulten.

El Imán (único que recoge solo) filtra primero montañas enteras por distancia
al centro antes de mirar objetos: con cientos por montaña, iterar todo por
jugador cada 0,2 s sería tonto.

Los objetos no desaparecen nunca (decisión del usuario, como en KOTAMON). Para
que la repoblación no espere al último papel, un montón activo deja de contar
como "disponible" cuando le queda menos del 25 % de sus objetos.

### La bolsa se lanza entera, y si falla es de todos

Mantener F carga la fuerza (1,2 s = 70 studs); al soltar, la bolsa sale con
TODO lo que llevaba hacia donde apuntas. Si entra en el Contenedor se recicla
con +50 % (y +25 % más si iba llena) y cuenta para Puntería. Si falla cae como
objeto `bolsa` que **cualquiera** puede recoger (decisión del usuario: es la
tensión social ligera del patio). Reciclar por el prompt de cerca sigue
existiendo, pero no cuenta para Puntería.

### Primera persona en el patio y el bug de los modales

Entrar al patio (servidor: atributo `EnPatio`) pone `LockFirstPerson`. Con un
panel abierto el script de cámara de Roblox re-bloquea el ratón CADA frame, y
cambiar a `Classic` tampoco lo libera mientras el zoom está a distancia de
primera persona. La solución que funciona: `BindToRenderStep` con prioridad
`Camera + 1` que deja `MouseBehavior = Default` mientras hay panel
(`Camara.client`). Además `Menu` solo fija `GuiService.SelectedObject` con
gamepad: en PC forzaba la navegación por teclado.

Los rigs nuevos usan `AnimationConstraint` (sin `C0`) y el Animator pisa
cualquier cambio único: la pose de brazos (`Utilidades/PoseBrazos`: hombros
70° al frente y 15° hacia el centro, codos y muñecas a identidad para que el
brazo quede recto) se escribe en `Transform` cada `RunService.Stepped`. La
escribe cada cliente para todos los personajes con `EnPatio` (`Escena.client`)
**y también el servidor** (`Patio`): `Transform` no se replica y la vista de
servidor de Studio (donde el usuario miraba a su personaje) mostraba los brazos
caídos y la bolsa a un lado. La bolsa abierta (`ModelosObjetos.bolsaAbierta`,
bola con boca clara e interior oscuro, crece con el llenado) se suelda al torso
entre las manos **medidas de verdad** 0,2 s después de entrar (el largo real
del brazo no se deduce bien de los tamaños de las partes: los rig attachments
no están en los extremos).

Retícula: en primera persona Roblox sigue pintando la flecha del ratón en el
centro. En el patio sin panel abierto se oculta (`MouseIconEnabled = false`) y
`Camara.client` dibuja un punto en el centro del viewport (ScreenGui con
`IgnoreGuiInset`, que es de donde sale el rayo). Para capturar al propio
personaje desde fuera en Studio: `EjecutarPruebaCliente:Invoke("verme", 8)`
(apaga `Humanoid.AutoRotate`: en primera persona el motor gira el personaje
hacia donde mira la cámara en cada paso de física y pisa cualquier CFrame).

### Modelos por código

`Utilidades/ModelosMascota` construye las 41 mascotas (forma por set y `forma`,
tamaño por rareza, estado visible: torcida/apagada/reflectante/neón, manchas si
está sucia; 1.673 partes para las 41×5 variantes) y sus fragmentos;
`ModelosObjetos` la basura (16 formas: 4 por material), billetes, tesoros,
figurinas, cintas, trajes y bolsas; `ModelosMonton` la colina; todos sobre
`Primitivas`. Sirven al mundo y a los ViewportFrames del álbum: un solo
vocabulario visual.

## 4. Números de calibración (punto de partida)

- Maxear las 7 mejoras: 232.430 $. Un montón chico deja 30–40 objetos, uno
  mediano 80–110 y uno grande 200–280 (premios solo en 14–18 / 22–28 / 34–44
  tiradas; el resto basura de relleno a 5–12 $: un grande son ~1.500–2.500 $
  solo en basura, 3–6× lo de antes); billetes 20–80 $, tesoros 150–600 $.
  Objetivo KOTAMON: ~5 h gratis → **recalibrar** VALOR_BASURA o los costes de
  mejoras tras probar. La bolsa base (8) hace 4–35 viajes por montón: subir
  `BOLSA_BASE` (GameConfig) es la palanca si se hace pesado.
- Energía 100 (+15/nivel), excavar cuesta 10, refresco 50 $ restaura 30 (+8/nivel),
  regen 1 punto / 2 s.
- Bolsa 8 (+3/nivel), almacén 30 (+10/nivel), imán 1,5 studs/nivel, alcance 6 (+1/nivel).
- Sobre Premium 149 gemas; Contenedor Dorado 25.000 $ o 150 gemas, 3 mascotas.
- Repoblación: con ≤ 4 montones disponibles (lleno, o activo con ≥ 25 % de
  sus objetos), 20 s después se rellenan los agotados. Nada caduca.
- Lanzamiento: 1,2 s de carga = alcance máximo 70 studs; +50 % al entrar.

## 5. Pendiente

- Fijar **Max players = 6** en Game Settings / Creator Dashboard
  (`Players.MaxPlayers` es de solo lectura por script).
- Publicar el place y activar *Studio Access to API Services* para probar el
  DataStore; crear pases, productos y badges y rellenar sus ids.
- Ids de audio de las 7 cintas (`sonidoId = 0`).
- Prueba con 2+ jugadores del patio compartido (riesgo "tibio" del GDD §14).
- Calibrar economía tras las pruebas cerradas.
