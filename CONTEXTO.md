# Recíclatas (CleanRecycle) — estado del proyecto

Réplica mecánica de KOTAMON para Roblox, low-poly de partes con arte por
capas sobre un esqueleto whitebox (ver §3 "Arte del mundo"). El diseño
completo está en `docs/GDD.md`; este documento es lo que NO se deduce del
código: qué hay, cómo se trabaja y por qué se decidió lo no obvio.

Última pasada: 16 sep 2026 (rendimiento móvil: sin árboles, valla ligera,
sombras y física de la basura recortadas; plano v3 del mapa: parcelas en columna al oeste,
recicladora al sur, valla alrededor de todo; antes, el mismo día, arte del
mundo por MCP: cabaña, máquinas, vallas,
árboles, camión, materiales IA; antes, 15 sep: interfaz v2 papel y tinta,
lotes 9–11). Estado: **todas las mecánicas del GDD implementadas y
verificadas en Play Solo**, HUD/manos/carteles/diálogo con el estilo nuevo,
mundo vestido; pendientes los paneles (lotes 12–13 de la UI), la prueba con
2+ jugadores y publicar.

## 1. Qué hay

| Sistema | Dónde | Estado |
|---|---|---|
| Patio compartido: 12 **colinas** de basura; al activar, la colina se sustituye por una **montaña de basura real con física** (30–200 objetos: latas, llantas, cajas, botellas…, sin etiquetas; caen, se asientan y se anclan; nada flota); **solo se recoge con clic** (o Imán), reclamo atómico, **sin caducidad**, repoblación | `Services/Botin.luau` (fachada) → `GeneradorBotin`, `ObjetosPatio`, `FisicaBasura`, `Montones`, `Iman`, `Lanzamiento` + `BotinHandler` | verificado (`montonPiezas`, `reacomodo`, `sinRecogidaAutomatica`, `variedadBasura`) |
| Puntería: **mantener F carga y lanza la bolsa entera**; si falla queda en el suelo y cualquiera la recoge | `Services/Lanzamiento.luau` | verificado (`lanzarBolsa`, `lanzarBolsaFallo`) |
| Primera persona automática en el patio con retícula (punto), manos+bolsa en 2D (Frames), brazos extendidos (cliente y servidor) sujetando una bolsa abierta soldada entre las manos | `Services/Patio.luau`, `Utilidades/PoseBrazos`, `Client/Camara.client`, `Client/UI/Manos.client`, `Escena.client` | verificado (`enPatio`, capturas) |
| HUD estilo KOTAMON en **papel y tinta**: píldoras con icono ($, cartas, gemas), barras verticales con icono en la base (energía, fuerza, **bolsa** sin números; "¡LLENA!" en rojo), retrato (headshot), dock con insignia de tecla (Q/J/L/B), "[F] MANTÉN PARA LANZAR"; disposición táctil (dock arriba-centro, botón de lanzar sobre el salto) | `Client/UI/HUD.client.luau`, `UI/Componentes.luau` | verificado (capturas PC y táctil forzada) |
| Sistema de diseño: pegatinas con sombra, iconos por registro (`Config/Iconos`, id 0 = glifo dibujado en `Utilidades/Glifos`), insignias de tecla/mando, modales que se encogen al viewport, pestañas de libreta; diálogo de Doña Chatarra con retrato; carteles del mundo y prompts personalizados desde el cliente | `Client/UI/Componentes.luau`, `UI/Dialogo.luau`, `Escena.client`, `Prompts.client` | verificado (capturas) |
| **Arte del mundo**: cabaña de dos plantas, máquina azul, trituradora + contenedor verde, vallas, postes con cables, camión (malla IA), parcelas de madera, Doña Chatarra vestida, césped/tierra/basura con materiales, iluminación cartoon | `ServerStorage/Herramientas/ArteMundo.luau` + `ConstructorMundo` v3 | verificado (capturas, pruebas de servidor intactas) |
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
`ServerStorage/Herramientas/ConstructorMundo`, y este viste el esqueleto con
`ArteMundo`). **Tras construir hay que guardar el place.** `SetupMundo` sólo
lo adopta; si falta, lo construye en runtime como fallback y avisa. Todo se
localiza por tags/atributos, nunca por nombre: `RanuraMonton` (12), `Parcela`
(6), `FigurinaFija`, `Contenedor`, `MaquinaRefrescos`, `Limite`,
`SoloDecorado`; atributos `Mueble`, `Pintable`, `NPC`, `IndiceParcela`.
Con arte, `workspace.Mundo` son ~1.600 instancias (504 el whitebox).

Lo generado por IA vive **en el place**, no en git: las variantes de
material de `MaterialService` (`MontanaBasura` es la única en uso; `CespedCartoon` y
`MaderaVieja` quedaron huérfanas al pasar suelo y parcelas a color liso; hijas directas; el generador las deja en carpetas
`Material: X` con 4 candidatas) y las mallas de `ServerStorage.Arte`
(`Camion`, `Bolsa` —saco facetado atado con banda amarilla, referencia del
usuario—; `Arbol` ya no se usa: se quitaron todos los árboles por
rendimiento). El código las usa por nombre (`Paleta.VARIANTES`,
`ArteMundo.clonarMalla`) y sin ellas construye igual con materiales base y
props de partes. Para regenerarlas: `generate_material` / `generate_mesh`
del MCP y renombrar.

### Trabajar por el MCP de Studio

El hilo de `execute_luau` (Edit) **puede** crear partes, escribir `Source` y
propiedades, y leer `Source`; **no puede** hacer `require` de módulos del
juego, usar HttpService, crear/reparentar scripts ni invocar
BindableFunctions/RemoteEvents (le faltan capacidades: "LoadUnownedAsset",
"Network", "RobloxScript"). De ahí:

- Hornear desde el MCP: `herramientas/hornear-desde-mcp.luau`, un `require`
  que carga cada módulo con `loadstring(modulo.Source)` y `setfenv`.
- Sincronizar código sin el plugin de Rojo: `multi_edit` crea y edita
  scripts y `Source = [==[...]==]` por `execute_luau` reescribe los
  existentes; se comprueba con una huella (largo, suma de bytes y suma
  ponderada por posición) igual en local y en Studio. **Con Rojo conectado no
  usar `multi_edit`**: aplica el mismo cambio dos veces (pasó con `Paleta`).
- Pruebas: por atributos (`Prueba` / `PruebaCliente`, ver arriba).
- `screen_capture` acepta `camera_position` / `look_at_position` en Edit;
  en Play, mover `workspace.CurrentCamera` (Scriptable) desde el cliente.
- Los eventos de `user_keyboard_input` / `user_mouse_input` llegan al juego
  ~6–8 s después de que la herramienta responda; para pulsar algo que
  aparece por un tiempo (el diálogo) hay que esperar a verlo (poll desde
  `execute_luau`) y usar `instance_path` en el clic.

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

### Arte del mundo por capas (16 sep)

Decisión del usuario: "modela todo el juego, dale color como en KOTAMON,
usando solo el MCP de Roblox" → low-poly de partes + IA del MCP para
materiales y dos props. La regla que lo hace barato y seguro: **el whitebox
sigue siendo el esqueleto funcional** (tags, atributos, prompts,
`ZonaAcierto`, colisiones, tamaños intactos) y el arte es una capa
`SoloDecorado` sin colisión ni query alrededor (`ArteMundo`), más pintura de
materiales sobre las cajas que se ven. Ninguna prueba ni servicio distingue
el mundo vestido del desnudo (verificado: `estado`, `excavar`, `reclamarTodo`,
`lanzarBolsa`, `depositar`, `parcela`, `irCasa` en Play sobre el mundo v2).

- Los grises del whitebox (110 suelo, 140 montones, 165 muros, 195 losas,
  215 muebles, 240 caseta) siguen en `Paleta` como respaldo; `Paleta.MUNDO`
  es la paleta de arte y `Paleta.LOSA_PARCELA/MUEBLE/MUROS` pasan a madera
  porque `Parcelas.pintar` repinta con ellos las partes `Pintable` sin skin.
  Objetos y mascotas siguen con color por material y disco de rareza (set y
  rareza son información de juego); sin neón en el mapa.
- Montones intactos: **montañas de escombros** (petición del usuario, 16 sep,
  con foto de referencia: ni bolas lisas ni pirámides puntiagudas). Cada
  montón es un pico principal + 2–3 secundarios; cada pico, una bola grande
  hundida que da el bulto, bolas medianas apiñadas en la cima y bolas de
  tamaños varios medio enterradas por la falda, con `Rock` + variante
  `MontanaBasura` y tono por bola (~40–55 partes por montón, sin sombra).
  Perfil para colocar la basura: cono redondeado `h·(1−d/r)^1.6`. Radios
  9/12/17 (antes 7/10/14). Se probaron capas de cilindro (parecían una
  tarta), pirámides de `CornerWedgePart` y una malla IA (`generate_mesh`
  dio cajas apiladas sobre un disco, no escombros; `ModelosMonton` la
  usaría si existiera `ServerStorage.Arte.Monton`). Las partes siguen
  llamándose `Loma_…` porque `Montones` y las pruebas las reconocen por ese
  prefijo. La basura se reparte en el 60 % de la altura y en el 65 % del
  radio: cayendo desde más de ~8 studs se clavaba en el suelo, y apretada se
  asienta antes que suelta por el suelo. `Patio.Suelo` pasa a 4 studs de
  grosor por lo mismo; agotado = parches `Ground`. La basura real coge colores
  vivos de `Paleta.BASURA` y material de Roblox por tipo (latas `Metal`,
  cartón `Cardboard`, neumáticos `Rubber` negros).
- Caminos: `Ground` base sin variante a propósito (las cuatro tandas de IA
  salían agrietadas y naranjas). Suelo, baseplate y parcelas: `SmoothPlastic` liso, sin variante (el usuario no quiso textura de césped ni de madera en las bases: look minimalista).
- La caseta mira a +Z (el patio): la cara visible de sus letreros es la
  `Back` de Roblox (`CARA_PATIO` en ArteMundo); un letrero por cara
  (`LetreroFront`/`LetreroBack`) para que las tablas se lean por los dos
  lados.
- Las cuñas (`WedgePart`): la cara vertical es la trasera (+Z local) y la
  rampa baja hacia -Z; el tejado a dos aguas son dos cuñas, la del frente
  girada 180°.
- Los cables de los postes son `Beam` entre Attachments con `CurveSize`
  negativo (comba).
- Iluminación cartoon en `ConstructorMundo.iluminar()` (idempotente) y
  reflejada en `default.project.json`; `Technology` es de plugin y desde el
  MCP ni se lee, por eso va en pcall.
- Fuera de alcance de esta pasada: las 41 mascotas (siguen siendo primitivas
  por set/rareza, y el álbum depende de ese vocabulario), el avatar, sonidos.

### Plano v3 del mapa (16 sep)

El usuario pidió el plano de su boceto: las 6 bases en columna a la
izquierda, el patio de basura grande a la derecha, la recicladora de Doña
Chatarra debajo del patio, y **la valla que rodeaba el patio pasa a rodear
todo el mapa**. `ConstructorMundo` v3 (`LAYOUT`):

- El patio (200×200) **no se mueve del origen**: `Patio.posicionEnPatio`
  comprueba `|x|, |z| < PATIO_LADO/2`, así que se recoloca todo lo demás a
  su alrededor. Sin muros: es la explanada de césped claro un stud más alta.
- Recicladora al SUR (z 140–186, lote de tierra del ancho del patio) con la
  caseta mirando al norte. Como `ArteMundo` espera el frente en +Z local
  (`CARA_PATIO = Back`), `construirCaseta` construye todo sobre un pivote
  girado 180° (`en(x, y, z)`); las paredes del contenedor pasan a llamarse
  `ParedFrente/Fondo/Izq/Der`. La cara de Doña Chatarra está en +Z local de
  la cabeza, por eso el retrato del diálogo pone la cámara relativa a
  `Cabeza.CFrame` y no en +Z del mundo.
- Plaza del spawn (40×38, pegada al borde sur del patio, z 100–138); se
  aparece mirando a la caseta. `Mundo.posicionPlaza()` sigue siendo la
  fuente para "Ir al patio" y para las pruebas (`Comunes.fueraDelPatio()`
  en vez de un `(0,0,-130)` a mano).
- Parcelas en x = −150, z = {−87, −37, 13, 63, 113, 163}, mirando al este;
  calle de tierra en x = −116 con un ramal a cada entrada.
- Límite rectangular (`LAYOUT.LIMITE`, x −196..124, z −124..202): muro
  invisible de 60 studs (tag `Limite`, 4) y la valla de madera de 10 studs
  (no se salta: el salto llega a ~7,5)
  por dentro (sin árboles: se quitaron todos a petición del usuario y por
  rendimiento). El Baseplate mide justo el rectángulo del límite (320×326,
  centrado en −36, 39): fuera de la valla no hay terreno. Igual en el
  constructor, `default.project.json` e `instalar-desde-http`.
- El contenedor grande (escondite F3) pasa al fondo norte del patio para no
  tapar la entrada desde la plaza; F1 queda detrás de la caseta.

### `Mundo.Manual`: lo editado a mano sobrevive al horneado (16 sep)

El usuario editó el place a mano y un horneado posterior lo borró:
`construir()` destruye `workspace.Mundo` entero. Desde entonces
`limpiarPlace` aparta la carpeta `Mundo.Manual` antes de borrar y
`construir()` la vuelve a colgar del Mundo nuevo (si no existe, la crea
vacía). Regla: lo que se toque a mano en Studio va a `Manual`; si se mueve
una pieza funcional, avisar para que el constructor no la duplique. Y antes
de hornear, preguntar siempre.

### Rendimiento en móvil (16 sep)

Medido en Play con 3 montones grandes + 2 medianos activos (el caso malo
realista). Antes: 2.470 partes de mundo (todas con sombra) + 902 objetos de
basura ≈ 5.300 partes en `workspace`, ~3 partes por pieza con colisión y
masa cada una. Después: 1.336 partes de mundo (601 con sombra) + 733
objetos ≈ 3.640 partes, y solo el `Cuerpo` de cada pieza colisiona. Los
FPS de Studio no sirven de métrica (el cliente de Play va capado a ~15 fps
sin foco, con GPU a 0): la medida buena es en dispositivo con el menú de
Stats de Roblox. Qué se hizo y por qué:

- **Sin árboles** (petición del usuario): eran ~200 modelos y el anillo
  exterior no aportaba nada al juego. `ArteMundo.arbol/arbusto` y
  `construirArboleda` se borraron; la malla `Arbol` queda huérfana en el
  place.
- **Valla**: postes cada 6 studs y una tabla ancha por vano (el material de
  tablas dibuja las juntas) en vez de una tabla cada 1,25 studs: de ~1.350
  a ~440 partes para rodear el mapa.
- **Sombras**: `ArteMundo.parte` no proyecta sombra salvo `Sombra = true`
  (cabaña, tejado, trituradora, postes, barriles, neumáticos). La basura
  tampoco (`ModelosObjetos.basura`): cientos de piezas pequeñas cuya sombra
  no se lee.
- **Física de la basura**: se probó dejar solo el `Cuerpo` con colisión y
  masa (los detalles `Massless` y sin `CanCollide`) para ahorrar contactos, y
  se REVIRTIÓ: las piezas redondas sin aros ni tapones que las frenen rodaban
  segundos (`reacomodo` bajaba del 90 % anclado a los 5 s) y en mascotas y
  tesoros el "cuerpo" es solo el torso y se hundían hasta la cabeza
  (`montonPiezas`, bajo −1,5). Colisiona todo, como antes; el ahorro real
  vino de menos piezas por montón y de quitar sombras.
- **Montón grande** de 200–280 a 160–200 piezas (`GameConfig.TAMANOS_MONTON`);
  los lotes de premio no cambian, así que la economía tampoco.
- Mallas clonadas con `RenderFidelity = Automatic` y `CollisionFidelity =
  Box`.
- Pendiente y solo medible en dispositivo: FPS reales, tamaño de las
  texturas IA (ya solo `MontanaBasura`) y si en calidad baja, sin
  Bloom/ColorCorrection, el look sigue gustando.

### Interfaz "papel y tinta" (lotes 9–11, 15 sep)

- Tema claro tipo pegatina (crema + contorno de tinta + sombra dura) con
  FredokaOne/Nunito, en `Componentes` v2. Un hijo no puede pintarse detrás
  de su padre, así que cada pegatina/botón es un envoltorio `{Sombra,
  Cuerpo}`; los botones devuelven el cuerpo (TextButton) y su envoltorio es
  `.Parent`. La escala del hover va en el cuerpo para no mover los layouts.
- Iconos por registro: `Config/Iconos` (id 0 = respaldo dibujado con
  `Utilidades/Glifos`); el arte 2D del usuario va en `assets/ui/<clave>.png`
  (brief en `assets/ui/README.md`) y se sube con `upload_image` del MCP.
- Táctil: el thumbstick y el salto de Roblox ocupan las esquinas de abajo →
  dock arriba-centro, retrato junto a las píldoras, botón de lanzar de
  ContextActionService restilizado. `Entrada.forzar()` +
  `EjecutarPruebaCliente:Invoke("plataforma","tactil")` para capturar sin
  dispositivo; `("hud")` avisa de solapes.
- Los modales miden mín(máximo de diseño, 94 % del viewport ÷ escala): caben
  en un teléfono sin diseñar dos veces.
- Prompts: `Style = Custom` puesto **localmente** por el cliente a todos los
  ProximityPrompt (sin re-hornear ni tocar el servidor) y pegatina propia en
  `PromptShown`. Medido en Studio: un BillboardGui con `AlwaysOnTop = true`
  (o en PlayerGui) no se pintaba; va dentro de la parte y sin AlwaysOnTop,
  flotando por encima del tope del modelo.
- Los carteles flotantes horneados se restilizan en el cliente (`Escena`) y
  miden en studs para encoger con la distancia; el texto de los de parcela lo
  sigue poniendo el servidor.
- El saludo de Doña Chatarra abre la tienda al **descartar** el diálogo (como
  Jenny), no por debajo de él; si se cierra solo por tiempo, no abre nada.
- FredokaOne no trae "✕": la X de cerrar es una "X".

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
160–200 según tamaño) con **modelo real** (latas, llantas, barriles, botellas,
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

La parábola se integra paso a paso en el servidor (`PivotTo`, sin física de
Roblox: determinista y el servidor decide el acierto) y desde el 16 sep
**bota** al caer (petición del usuario): hasta 3 botes conservando el 40 %
de la velocidad vertical y el 55 % de la horizontal, y contra la pared del
contenedor sale despedida hacia fuera con el 30 %. La altura del suelo se
mide con un raycast (patio a 1, plaza a 0,9, lote a 0,12), no con una
constante. Medido: cae desde 21 studs, bota a ~4, luego a ~1,5 y se queda;
todo en menos de 3 s, que es lo que espera `lanzarBolsaFallo`. También
rebota hacia dentro contra los muros `Limite` del borde (antes una bolsa
podía perderse fuera de la valla). Acierto o pared se deciden por el TRAMO
entre dos ticks (por dónde cruza el plano del borde superior de la caja),
no por el punto actual: la bolsa avanza ~1,5 studs por tick y la pared
mide 0,5, y mirar solo el punto era una lotería (un acierto de cada cinco
fallaba). La bolsa lanzada es la malla `ServerStorage.Arte.Bolsa` escalada
por el llenado (`ModelosObjetos.bolsaLlena`, con el modelo de partes de
respaldo); `lanzarBolsaFallo` apunta ahora hacia el patio (plano v3).

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
  mediano 80–110 y uno grande 160–200 (premios solo en 14–18 / 22–28 / 34–44
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

- **Guardar el place** tras hornear (el mundo v2, las variantes de
  MaterialService y `ServerStorage.Arte` viven ahí; el `.rbxl` no va en git).
- Interfaz, lotes 12–13: paneles (álbum con cartas estilo KOTAMON en
  `UI/Carta`, tienda con iconos por mejora, revelación con volteo, logros,
  base, reparación, probabilidades; retirar los alias `UI_FONDO/UI_PANEL/...`
  de `Paleta`), pulido tablet/gamepad y docs. Plan en
  `~/.claude/plans/bueno-ahora-que-ya-sharded-dusk.md`.
- Arte 2D del usuario para la UI en `assets/ui/` (manos, iconos, marco de
  carta); hasta entonces, glifos dibujados.
- Arte pendiente del mundo: las 41 mascotas y el avatar del jugador.
- Fijar **Max players = 6** en Game Settings / Creator Dashboard
  (`Players.MaxPlayers` es de solo lectura por script).
- Publicar el place y activar *Studio Access to API Services* para probar el
  DataStore; crear pases, productos y badges y rellenar sus ids.
- Ids de audio de las 7 cintas (`sonidoId = 0`).
- Prueba con 2+ jugadores del patio compartido (riesgo "tibio" del GDD §14).
- Calibrar economía tras las pruebas cerradas.
