# Recíclatas (CleanRecycle) — guía para trabajar en este repo

Réplica whitebox de KOTAMON para Roblox, rediseñada el 26 sep 2026 como
**"Diseño v2: recoger y lanzar"** (sin base ni energía; montones de basura
revuelta, rebirths que abren tipos de basura, pedidos). El 3 oct,
**v3 para lanzar**: cinco contenedores (uno por tipo de basura, del color
de su tipo, y el general azul; x2 lo bien separado), basura del color de
su tipo, **sin mascotas**, tienda con barras de 10 cuadros, pedidos,
insignias, pases, tutorial de 8 pasos y tercera persona (CONTEXTO §3
"Lanzamiento: v3"). El 22–23 oct, el **plan de lanzamiento por agentes**
(CONTEXTO §3 "Lanzamiento por agentes"): guardado con bloqueo de sesión,
anti-trampas, recibos seguros, admin solo en Studio, pantalla de carga,
analítica, audio y la **economía v4** (`docs/Economia-v4.md`, aprobada:
curva, pedidos en %, recompensas y el catálogo K1: Turbo solo jugando, VIP,
Pack de inicio, ofertas y precio real; E1 y K1, unidos sin verificar aún en
Studio). El place está publicado y privado (PlaceId 139915415713937,
universo 10766595888). El diseño original está en `docs/GDD.md`; el estado
del proyecto, lo pendiente y las decisiones no obvias en `CONTEXTO.md`.
Léelos antes de tocar balance o estructura.

## Toolchain

- Rojo 7.7.0 (aftman; no está en el PATH: `~/.aftman/bin/rojo.exe`). No hay
  Wally. Una sola dependencia externa, a propósito: **Fusion 0.3** (UI
  reactiva), copiada tal cual en `src/ReplicatedStorage/Packages/Fusion`
  (licencia MIT en `LICENSE.txt`); no se edita.
- `powershell -ExecutionPolicy Bypass -File herramientas/rojo-serve-bucle.ps1`
  (un `rojo serve default.project.json --port 34872` que se relanza solo) y
  **Connect** en el plugin. Rojo 7.7 se cae con los temporales con los que
  guarda la herramienta Edit (rojo-rbx/rojo#1338) y el plugin **no se
  reconecta solo**: tras una caída lo editado no llega a Studio hasta que
  alguien pulse Connect. Rojo no recarga `default.project.json` en caliente:
  tras cambiarlo, reiniciar `rojo serve` y volver a conectar.
- Sincronizar sin el plugin (agentes, MCP): arrancar
  `powershell -ExecutionPolicy Bypass -File herramientas/servir-fuentes.ps1` y en
  la barra de comandos / `execute_luau` (Edit):
  `loadstring(game:GetService("HttpService"):GetAsync("http://localhost:8123/herramientas/instalar-desde-http.luau", true))()`.
  Crea el mismo árbol que Rojo (también `ReplicatedFirst`, donde borra lo que
  sobre), normaliza CRLF→LF como Rojo y solo escribe lo que cambió: un
  segundo pase da 0 cambios.
- Studio se abre por shell, nunca con `open_application` (abre una
  instancia nueva en la página de inicio):
  `& (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\RobloxStudioBeta.exe" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName -task EditPlace -placeId 139915415713937 -universeId 10766595888`.
  Antes, `list_roblox_studios`: si el place ya está abierto, no abrir otro.
  Computer use solo para lo que no tiene otra vía: Connect en el plugin de
  Rojo y Start en Test → Clients and Servers.
- Pruebas dentro de la VM del juego (Play): `game.ServerStorage.EjecutarPrueba:Invoke("estado")`
  (ver `Services/PruebasDefinidas/`) y `ReplicatedStorage.EjecutarPruebaCliente:Invoke("abrir","Tienda")`.
  La barra de comandos corre en la VM del plugin: `require` allí da copias vacías.
- El mundo NO se genera en runtime: se hornea en el place con
  `herramientas/construir-mundo.luau` (barra de comandos) o, desde el hilo
  del MCP (que no puede hacer `require`), con
  `herramientas/hornear-desde-mcp.luau` por `execute_luau` sobre el
  DataModel Edit; después se **guarda el place**. Hornear BORRA
  `workspace.Mundo` salvo la carpeta `Mundo.Manual` (ediciones a mano del
  usuario): preguntar antes de hornear. `SetupMundo` solo adopta
  `workspace.Mundo`; si no existe, lo construye como fallback y avisa.
- El place (`*.rbxl`) está en `.gitignore`: la fuente del mundo es la
  herramienta. Excepción: lo generado por IA (variantes de `MaterialService`
  y mallas de `ServerStorage.Arte`) solo vive en el place; el código lo usa
  por nombre y funciona sin ello. Ver CONTEXTO §2 "Trabajar por el MCP".
  También van en `.gitignore` `.claude/worktrees/` (las copias aisladas de
  los agentes) y `.claude/settings.local.json`.
- El código se edita en los archivos de `src/` y llega a Studio por Rojo o
  por el instalador HTTP. Nunca con `multi_edit` del MCP (con el plugin
  conectado aplica el cambio dos veces) ni escribiendo `Source` por
  `execute_luau`, que queda para leer, invocar pruebas y hornear con permiso.

## Estructura (espejo del DataModel)

```
src/ReplicatedFirst/                    pantalla de carga (Carga.luau + PantallaCarga.client.luau): corre antes que todo, sin Fusion
src/ReplicatedStorage/Packages/Fusion   Fusion 0.3 (vendorizado, no tocar)
src/ReplicatedStorage/Shared/{Config,Events,Utilidades}
src/ServerStorage/Herramientas/ConstructorMundo.luau   esqueleto whitebox + llamadas al arte
src/ServerStorage/Herramientas/ArteMundo.luau          piezas de arte low-poly (SoloDecorado)
src/ServerScriptService/Services/       Modulo.luau (estado/reglas) + ModuloHandler.server.luau (cableado)
src/StarterPlayer/StarterPlayerScripts/Client/{*.client.luau, *.luau, UI/}
src/StarterPlayer/StarterPlayerScripts/Client/UI/Kit/    sistema de diseño en Fusion (un constructor por módulo)
assets/ui/                              PNG del arte 2D de la interfaz (claves de Config/Iconos); README con el brief
docs/                                   GDD (diseño original), Economia-v4 (aprobada), Ficha-lanzamiento, Audio-propuesta, Juego (el juego de hoy)
thumbnails/                             icono, insignias (badge_*), pases y productos (pass_*, product_*) a 512×512; blender/ con su .blend
herramientas/                           NO mapeado en Rojo: scripts de diseño para la barra de comandos / MCP
```

Rojo 7: `.luau` → ModuleScript, `.server.luau` → Script, `.client.luau` →
LocalScript, `X.model.json` → instancia (los RemoteEvents van así), carpeta
con `init.luau` → ModuleScript con hijos (`PruebasDefinidas/`).

Capas (la dependencia va siempre hacia abajo, nunca al revés):

```
Config            datos puros: números, textos (Textos + Traducciones en/pt), tablas de probabilidad,
                  definiciones (mejoras, rebirths, pedidos, recompensas, cosméticos, insignias, ofertas…),
                  Productos (ids de Roblox), Paleta (grises whitebox + Paleta.MUNDO + VARIANTES),
                  Iconos (ids del arte 2D), Sonidos (ids del audio)
Utilidades        sin estado de juego, servidor y cliente por igual:
                  Primitivas → ModelosObjetos / ModelosMonton, Contenedores
                  (los 5 contenedores, servidor y cliente), Geometria,
                  PoseBrazos, Red, Senal, Formato, Entrada,
                  Glifos (iconos dibujados de respaldo), Idioma (traduce el copy)
Services          reglas y estado (Perfiles, Bolsa, Mejoras, Economia, Turbo,
                  Cosmeticos, Pedidos, Insignias, Recompensas, Ajustes…).
                  Guardado es lo único que habla con el DataStore de perfiles
                  (cola y bloqueo de sesión); Movimiento vigila los saltos
                  imposibles; Monetizacion, pases y recibos; Ofertas, cuándo
                  se enseña cada oferta (no vende: la compra la confirma
                  Roblox); Analitica traduce
                  Senales a AnalyticsService; Actividad sabe cuándo hizo algo
                  cada jugador (sin dependencias: la requiere Turbo); Admin,
                  solo en Studio. El patio es una fachada
                  (Botin) sobre cinco módulos de una responsabilidad:
                  GeneradorBotin (qué sale) · ObjetosPatio (registro y reclamo) ·
                  FisicaBasura (cae y se ancla) · Montones (ciclo de vida) ·
                  Lanzamiento; tipos comunes en TiposPatio, grupos de
                  colisión en Colisiones
*Handler.server   cableado: prompts, remotes, cooldowns → llaman a los módulos
Client            solo intención + presentación; toma Config y Utilidades, nunca Services.
                  El audio pasa por Client/Sonido (Musica y SonidosMundo lo usan)
ReplicatedFirst   la pantalla de carga: ningún require de ReplicatedStorage antes de game:IsLoaded()
```

Reglas al añadir código: un módulo = una responsabilidad nombrada en su
cabecera; nada de lógica de juego en los Handlers ni en la UI; si dos módulos
se necesitan mutuamente, el de abajo publica una `Senal` y el de arriba se
suscribe (así ObjetosPatio no conoce a Montones); los tipos compartidos van a
un módulo de solo tipos.

## Convenciones de código

- `--!strict` (o `--!nonstrict` en constructores de geometría), tabs.
- Identificadores, archivos y comentarios en **español**. UI en español, todo el
  copy en `Config/Textos.luau`.
- Idiomas (7 oct, CONTEXTO §3 "Idiomas"): el juego sale en español, inglés
  y portugués. Toda clave nueva de `Textos` (o nombre nuevo de mejora, pase,
  producto, insignia o cosmético) va también en `Config/Traducciones/en` y
  `pt` con los mismos `{marcadores}`; la prueba `idioma` lo comprueba. El
  cliente lee `Idioma.textos`, nunca `Config/Textos`, y los nombres de Config
  con `Idioma.nombre/descripcion`. **El servidor no envía texto montado**:
  envía `Idioma.mensaje("SECCION.clave", valores)` (dinero con
  `Idioma.dinero`, nombres con `Idioma.mensajeNombre`) y, en instancias, el
  mensaje en un atributo (`Idioma.codificar`). Mayúsculas con
  `Idioma.mayusculas`, no `string.upper`. Única excepción: `Player:Kick`
  solo admite texto plano y el servidor lo resuelve él,
  `Idioma.resolver(Idioma.mensaje(...), Idioma.normalizar(jugador.LocaleId))`
  (Guardado). En portugués, la bolsa llena es "lotado/lotar", nunca
  "cheio/encher" (glosarios en la cabecera de cada traducción).
- Cabecera de cada archivo: qué hace ("Única responsabilidad") y el **porqué**
  de lo no obvio. Documenta decisiones, no sintaxis.
- El servidor es la autoridad: el cliente sólo envía intención por RemoteEvent y
  el servidor valida tipos y números finitos (`Lanzamiento.argumentosValidos`),
  distancia, cooldown, dinero y lo que tiene abierto. Un teletransporte del
  servidor avisa antes a `Movimiento.permitirSalto(jugador, destino)`; si no,
  lo toma por un salto del cliente (2 s sin recoger, entregar ni lanzar).
- `Config/TablasProbabilidad.luau` es la ÚNICA fuente de probabilidades. Toda
  tabla suma 100; hay assert. No se vende nada aleatorio.
- Persistencia: solo `Services/Guardado` toca el DataStore de perfiles (todo en
  `pcall`; un perfil que no cargó, o de una versión más nueva que el código,
  nunca se guarda). Un campo nuevo va en `Perfiles.porDefecto` (`completar`
  lo rellena; dentro de `mejoras`, `ajustes`, `recompensas`, `ofertas` y
  `compras`, clave a clave); si algo cambia de forma o de sentido,
  `GameConfig.VERSION_PERFIL` + `Perfiles.MIGRACIONES[v]`. Lo que haya que
  dejar en el perfil al salir se conecta a `Perfiles.alSalir` (llega antes
  del guardado de salida) y no cede; nunca en `PlayerRemoving`, que no tiene
  orden con el guardado (sirve para olvidar estado en memoria). Un recibo de
  Robux solo devuelve `PurchaseGranted` tras `Guardado.guardarAhora`.
- Dinero gratis (pedidos, calendario, regalos, regreso): `Economia.ganar`,
  nunca multiplicado por pases ni Turbo, como porcentaje de
  `DefinicionesRebirths.costeSiguiente` redondeado con `redondear`; los días,
  siempre `DefinicionesPedidos.dia` (cambia a las 06:00 UTC). Una fuente de
  dinero nueva tiene que pasar por `Analitica` o saldrá al salir como
  `Reciclaje_SinBonus`. "Está jugando" (minutos activos, la pausa del Turbo)
  lo dice `Services/Actividad`, no `tiempoJugado`.
- Solo en Studio: los comandos de admin y el modo dev de pases (`esStudio()`,
  sustituible en pruebas; en el juego publicado no hay comandos ni admins, ni
  el creador), los ganchos de prueba y los stores `_Studio` (perfiles
  `ReciclatasPerfiles_v4_Studio`, rankings `Ranking_v2_Studio_*`).
- Geometría del runtime se localiza por **tags/atributos** de CollectionService
  (`RanuraMonton`, `Contenedor` + atributo `Material` en los 4 de tipo,
  `PuntoAparicion`, `BarreraCuadrante`…), nunca por listas de nombres. Cuadrantes y su zona: `GameConfig.CUADRANTES`
  + `Utilidades/Cuadrantes` (servidor y cliente).
- Arte por capas: el whitebox (grises de `Config/Paleta.luau`) sigue siendo
  el esqueleto funcional; el arte son piezas `SoloDecorado` sin colisión de
  `ArteMundo` y materiales sobre las cajas visibles (`Paleta.MUNDO`,
  `Paleta.VARIANTES` por nombre). Nunca cambiar nombre, tag, atributo,
  tamaño ni posición de una parte funcional para "mejorar" su aspecto.
- Lo que la v2 QUITA se borró del código (energía, gemas, Sobre, Contenedor
  Dorado, Pase de la Suerte, Montón extra, reparación, fusión, venta, base,
  logros con dinero; el 3 oct las mascotas, sus fragmentos y el imán; el
  5 oct los trajes del avatar, gratis y de pago; el 22 oct 7 textos sin uso,
  los iconos y glifos gema, sobre, contenedorDorado y pocion): no se
  reintroduce sin decisión del usuario (`sinRestos` lo vigila). Tampoco se
  vende dinero, ni saltos de rebirth, ni automatización. Lo que solo POSPONE
  (figuritas, cintas) sigue tras
  `GameConfig.activa("FIGURINAS" | "CINTAS")`; no añadir
  dependencias nuevas de ello (ver CONTEXTO §3 "Diseño v2").
- UI: en **Fusion 0.3** con el Kit (`Client/UI/Kit`, estilo "UI Kit" de
  simulador: contorno marino, colores intensos, barras de título de color,
  studs). Cada panel: `local scope = Fusion.scoped(Fusion, Kit)` y
  `scope:Ventana{...}` abierta por `Computed(use(Menu.abiertoR) == nombre)`.
  El estado sale de `EstadoCliente.reactivo`; el perfil llega varias veces
  por segundo como tablas nuevas, así que se derivan **primitivos** con
  `Computed` y las listas se recorren sobre definiciones de Config, no sobre
  el perfil. Iconos siempre por `scope:Icono` (registro
  `Config/Iconos` + `Utilidades/Glifos`), nunca `rbxassetid` sueltos. Cada
  botón de panel del HUD lleva su tecla (en PC, sin panel abierto, el ratón
  está bloqueado al centro y la botonera no se puede pulsar): Q (o T), R, P,
  V, M y G; la E es de los prompts y la F de lanzar.
- Audio siempre por clave: `Client/Sonido.tocar/bucle` con `Config/Sonidos`
  (id 0 = callada), nunca un `Sound` ni un `rbxassetid` sueltos. Lo que suena
  en un cliente no se replica: los 3D que oyen todos los reproduce cada
  cliente al ver el evento.
- Pruebas: cada paquete en su `PruebasDefinidas/<Área>.luau` (`init` falla si
  dos repiten nombre), y dejan el perfil como estaba. Las que mueven al
  jugador usan `Comunes.teletransportar` (avisa a Movimiento); las que lanzan,
  `Comunes.llenarBolsa` (el servidor solo lanza bolsas llenas) y
  `Comunes.limpiarBolsasCaidas` (tope de 3 en el suelo). En el cliente, un
  ModuleScript con `prueba = { accion = fn }` (bajo `Client` o en
  `ReplicatedFirst`) se prueba con `("modulo", nombre, accion, ...)`:
  `PruebasCliente` ya no se edita.

## Verificar

1. Consola de Studio sin errores tras sincronizar (`get_console_output`).
2. Hornear mundo (`hornear-desde-mcp.luau` devuelve los conteos) → capturas
   con `screen_capture` + `camera_position` (vista aérea desde (-26, 330, 60)
   mirando a (-26, 0, 30); la caseta desde la plaza (-29, 9, 83) → (-35, 7, 133);
   el norte del patio (ya sin barrera) desde (-20, 12, 5) → (-30, 5, -45); una esquina de la
   valla; los contenedores de color con su trituradora desde la plaza (8, 12, 100) →
   (8, 3, 128)) →
   mundo v6: 18 `RanuraMonton` (12 chicos + 6 grandes, con `Cuadrante` y
   `Zona`), 0 `BarreraCuadrante`, 1 `PuntoAparicion`, 5 `Contenedor` (4
   con `Material`: los de tipo; el general sin él), 4 `Limite`,
   0 `Parcela`, 0 `MaquinaRefrescos`, 0 `FigurinaFija` (con `FIGURINAS`
   apagada), 5 `RecicladoraArte` (la del general y una por contenedor de
   color, con atributo `Material`), 3 `PantallaRanking` (los tablones de
   ranking, con atributo `Ranking`), 1.054 instancias en `Mundo` (re-horneado
   del 22 oct). Placas de los contenedores: "ORGÁNICO" en español y
   "ORGANIC" con `IdiomaStudio = "en"`.
   El plano está en la cabecera de `ConstructorMundo` (patio 97,5×150 con
   2x3 cuadrantes, los seis zona "patio" abiertos y sin barreras desde el
   5 oct: los rebirths desbloquean TIPOS de basura, `GameConfig.MATERIAL_REBIRTH`;
   recicladora al sur, con la caseta en x = `LAYOUT.CASETA_X` (−35) y las 4
   unidades de color al este de la cabaña; valla a 24 studs del patio).
3. Play: pruebas de servidor con `EjecutarPrueba:Invoke(nombre, ...)`, por
   área (`PruebasDefinidas/<Área>`; una prueba nueva que mueva al jugador
   usa `Comunes.teletransportar` y una que lance, `Comunes.llenarBolsa`):
   - Idioma: `idioma` (en/pt cubren todo `Textos` y `DEF`, mismos marcadores,
     mensajes anidados y con dinero).
   - Datos (P1; almacén en memoria y claves de prueba, no tocan el registro
     real): `guardadoEnCola`, `cierreEspera`, `cargaDuranteCierre`,
     `bloqueoSesion` (con `"real"` repite sus casos en el store de Studio,
     ~10 s), `reentrarMismoServidor`, `seVaEsperandoRobo`,
     `almacenInestable`, `migracionPerfil`, `cargaEnFondo`, `storeStudio`,
     `salidaAntesDeGuardar`, `salidaReintenta`. Avisos esperados en la
     consola: los fallos simulados de `almacenInestable` y `salidaReintenta`
     y la expulsión falsa de `bloqueoSesion`.
   - Monetizacion (P2): `reciboIdempotente`, `reciboSinPerfil`,
     `reciboGuardaAntes`, `reciboConcurrente`, `compraPase` (solo cuenta si
     Roblox lo confirma), `modoDevSoloStudio`, `adminOculto`,
     `insigniasLote` (con `"real"` pregunta a Roblox).
   - Antitrampas (P3): `lanzarSoloLlena`, `lanzarArgumentosMalos`,
     `primeroSinRecord`, `topeBolsasCaidas` (la más vieja a x0,5),
     `vueloAlSalir`, `teletransporte`, `camaraCooldown`, `poseSinBucle`;
     depuración: `vigilarSospechas` (`"empezar"`, jugar, `"ver"`: falsos
     positivos de Movimiento) y `dejarBolsaCaida` (parar el Play y mirar el
     cobro al volver).
   - Analitica (N1, sobre `Analitica.registro`; en Studio no se envía:
     `ENVIAR_EN_STUDIO` apagado, y `analiticaEmbudo` lo enciende y escribe
     las líneas "event fired"): `analiticaEmbudo`, `analiticaEconomia`,
     `analiticaProgresion`, `analiticaEventoMalo`, `analiticaSinServicio`,
     `analiticaLanzamiento`, `analiticaSospecha`.
   - Ajustes y Actividad: `ajustesValidos`, `actividad`.
   - Economia (E1): `ritmoR1` (el modelo del documento: R1 en 45–60 min),
     `costeSiguiente`, `rebirthsAbren`, `pedidoVip`, `premioAlCobrar`.
   - Recompensas (R1, reloj y día inyectados): `diariaCalendario`,
     `diariaUnaVezAlDia`, `diariaSaltarDia`, `diariaCasilla7`,
     `regresoTrasDias`, `regalosMinutosActivos`,
     `recompensaBloqueadaTutorial`, `recompensaRemoteMalo`.
   - Progreso: `estado`, `perfilV5` (antes `perfilV3`), `mejorasV2` ($35.485
     las 4 al máximo), `brazoLimita`, `aparicion`, `tutorial` (8 pasos),
     `sinRestos` (nada de lo quitado: mascotas, trajes y el copy, los iconos
     y los glifos del 22–23 oct).
   - Rankings: `rankings` (semana desde el lunes, valores semanales de suma
     y de máximo, stores `_Studio`, un tablón por ranking) y
     `rankingsDatastore` (ida y vuelta real por los OrderedDataStores de
     Studio; sin acceso a la API dice SIN API).
   - Patio: `excavar`, `reclamoAtomico`, `montonPiezas`, `reacomodo`,
     `sinRecogidaAutomatica`, `variedadBasura`, `coloresBasura` (cada pieza
     del color de su tipo), `enPatio`, `bolsaManosLlena` (abierta en manos;
     llena, cerrada con nudo), `limiteJugador`, `topePatio`.
   - Rebirths: `rebirthTabla` (R1–R10 de la v4), `renacerRequisitos`, `renacer`.
   - Bolsa (contenedores y "el dinero sólo sale del contenedor"):
     `pagoSeparado` (x2 / x0,5 / x1), `lanzarATipo` (la bolsa entra en el
     contenedor al que se apunta, los cinco), `contenedorBloqueado`
     (metal/orgánico cerrados sin su rebirth: rebota y a mano se rechaza),
     `billeteEnBolsa`, `sinDineroAlRecoger`, `salirRecicla`, `bolsaProtegida`,
     `bolsaLibre` (a los 30 s la recoge cualquiera), `lanzarBolsa`,
     `lanzarBolsaFallo`, `lanzarContraRecicladora`, `bolsaEnAlto` (exige que
     de verdad cayera en alto; se baja junto al contenedor), `recicladora`
     (y luego `EjecutarPruebaCliente:Invoke("recicladora")` para la cinta; si
     el MCP no puede invocar el BindableFunction, por atributo `Prueba`, ver
     CONTEXTO).
   - Pedidos: `pedidosDia` (3 y el VIP con el pase, % del siguiente rebirth,
     día a las 06:00 UTC), `pedidoSeparadas`, `premioTurbo`, `insignias` (20).
   - Pases: `paseDineroX2`, `paseBolsaXL`, `turboAcumula`, `cosmeticoBolsa`
     (usan el modo dev de pases y lo dejan como estaba).
   - Catalogo (K1): `turboPausa` (solo corre jugando; pausa a los 120 s),
     `turboTope` (3 h; un recibo con el tope lleno se otorga igual),
     `turboProductos`, `packInicioUnaVez` (su toast "+30 min" es lo esperado),
     `vipVentajas`, `cosmeticosNuevos`, `ofertaReglas` (41 reglas y el viaje
     de una oferta). En Studio las ofertas no salen solas: para verlas de
     verdad, `ServerStorage:SetAttribute("OfertasEnStudio", true)` (vale en
     Play), y quitarlo después.
   - Punteria: `bonusDistancia`, `racha`, `primeroEntra`, `pagoFormula`.
   - Cuadrantes: `cuadrantes`, `materialPorRebirth`, `variedadPiezas`,
     `tesoroGrande`, `valoresMaterial`, `prioridadExcavador`, `reposicion`,
     `reclamoMaterialBloqueado` (con 0 rebirths no se recoge el metal que
     saca otro con R2), `sinBarreras`.
   Sin veredicto (depuración): `dar`, `comprarMejora`, `maxMejoras`,
   `fijarMejora`, `pases`, `darColeccionable`, `montones`, `reclamarTodo`,
   `repoblar`, `verMonton`, `depositar`, `bolsaAlSalir`, `fijarLanzamientos`.
   `montonPiezas` y `reacomodo` dependen de la física y fallan de vez en
   cuando (una pieza que sale disparada o que tarda en anclarse): repetir
   antes de dar nada por roto.
   En el cliente `EjecutarPruebaCliente:Invoke("reticula")` y `("verme", 8)`
   para capturar el propio personaje desde fuera; `("plataforma", "tactil")`
   fuerza la disposición táctil, `("celebracion", "Papel")` y `("mas1")` disparan
   los efectos de cobro y de recoger (el "+1" va con `AlwaysOnTop` y la
   captura del MCP no lo pinta; ponerlo a false para verlo), y `("hud")` lista los bloques del HUD y avisa
   de solapes o de que algo se sale del viewport; `("camara", "tercera")`
   cambia la vista (vale en todo el mapa desde el 6 oct, como la V); `("abrir", "Tienda", "pases")`,
   `("abrir", "Pedidos", "insignias")`, `("abrir", "Ajustes")` y
   `("abrir", "Recompensas", "regalos")` abren un panel o una pestaña.
   `("trayectoria", 0.8)` dibuja la línea de ayuda, que solo sale en los 5
   primeros lanzamientos del perfil: antes,
   `EjecutarPrueba:Invoke("fijarLanzamientos", 0)` (devuelve los que había,
   para volver a ponerlos).
   `("avisoMundo", texto, icono)` pinta una burbuja de aviso, `("toast")`
   toasts del estilo nuevo y `("botones")` dice si se ven RECOGER/LANZAR
   (solo existen con pantalla táctil), `("record", 32, true)` la tarjeta
   de récord. `("idioma")` dice el idioma activo y una muestra; para jugar
   en otro, atributo `IdiomaStudio = "en"` (o `"pt"`) en `ReplicatedStorage`
   en Edit antes de Play, y quitarlo después. `("tablones")` resume los
   tablones de ranking (filas visibles y tu fila).
   Por el gancho `("modulo", nombre, accion, ...)`:
   `("modulo", "Sonido", "listar")` (cuántas claves, cuáles cargaron y lo que
   duran) y `("modulo", "Sonido", "tocar", clave)`;
   `("modulo", "Carga", "estado")`, `("modulo", "Carga", "mostrar", 10, "progreso" | "indicador")`
   y `("modulo", "Carga", "ocultar")`;
   `("modulo", "Recompensas", "indicador", true | false | "auto")` (el punto
   rojo del botón), `("modulo", "Recompensas", "regreso", 3)` (la ventana del
   bono de regreso) y `("modulo", "Recompensas", "estado")`;
   `("modulo", "Oferta", "mostrar", "PackInicio")` (o `DineroX2`, `VIP`,
   `BolsaXL`, `Turbo`: la ventana con datos de ejemplo, sin servidor) y
   `("modulo", "Oferta", "estado")` (título, botones y sus tamaños);
   `("modulo", "PreciosRobux", "listar")` (el precio de cada pase y producto
   y de dónde sale). Para ver la
   pantalla de carga de verdad: `ServerStorage:SetAttribute("SimularCargaLenta", 15)`
   en Edit antes de Play (Guardado retrasa la carga; solo Studio), y quitarlo
   después.
   `PASES_DEV_EN_STUDIO` está apagado: `/pases on` para ver los pases (con
   el VIP, la corona en tercera persona y `[VIP]` en el chat; el modo dev no
   da el Turbo del Pack de inicio).
   En Studio el perfil y los rankings van a los stores `_Studio`; sin "Enable
   Studio Access to API Services" se juega sin guardar (con su `warn`).
4. Multijugador: Studio → Test → Clients and Servers (2 jugadores), ver
   `README-pruebas.md` (también lo que hay que mirar de Movimiento y del
   bloqueo de sesión).

## Bash del harness

Los heredocs de más de ~8 KB con comillas simples se corrompen: para archivos
grandes usar la herramienta Write; Bash para archivos pequeños y comandos.
