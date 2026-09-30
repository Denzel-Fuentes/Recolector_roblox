# Recíclatas (CleanRecycle) — guía para trabajar en este repo

Réplica whitebox de KOTAMON para Roblox, rediseñada el 26 sep 2026 como
**"Diseño v2: recoger y lanzar"** (sin base ni energía; montones de basura
revuelta con zonas más ricas tras rebirths, mascotas por fragmentos,
rebirths, pedidos). El 29 sep el usuario cambió dos cosas del documento:
los montones ya no van separados por material y las mascotas salen de
fragmentos que se encuentran en los montones, no de cápsulas (CONTEXTO §3).
El diseño está en
`docs/GDD.md`; el estado del proyecto, el plan por lotes de la v2 y las
decisiones no obvias en `CONTEXTO.md`. Léelos antes de tocar balance o
estructura.

## Toolchain

- Rojo 7.7.0 (aftman). `rojo serve default.project.json --port 34872` y conectar
  el plugin en Studio. No hay Wally. Una sola dependencia externa, a propósito:
  **Fusion 0.3** (UI reactiva), copiada tal cual en `src/ReplicatedStorage/Packages/Fusion`
  (licencia MIT en `LICENSE.txt`); no se edita. Rojo no recarga
  `default.project.json` en caliente: tras cambiarlo, reiniciar `rojo serve`.
- Sin plugin (p. ej. trabajando por MCP): arrancar
  `powershell -ExecutionPolicy Bypass -File herramientas/servir-fuentes.ps1` y en
  la barra de comandos / `execute_luau` (Edit):
  `loadstring(game:GetService("HttpService"):GetAsync("http://localhost:8123/herramientas/instalar-desde-http.luau", true))()`.
  Crea el mismo árbol que Rojo; idempotente.
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
- Con el plugin de Rojo conectado, NO usar `multi_edit` del MCP sobre
  scripts (aplica el cambio dos veces); editar los archivos y dejar que Rojo
  sincronice.

## Estructura (espejo del DataModel)

```
src/ReplicatedStorage/Packages/Fusion                   Fusion 0.3 (vendorizado, no tocar)
src/ReplicatedStorage/Shared/{Config,Events,Utilidades}
src/ServerStorage/Herramientas/ConstructorMundo.luau   esqueleto whitebox + llamadas al arte
src/ServerStorage/Herramientas/ArteMundo.luau          piezas de arte low-poly (SoloDecorado)
src/ServerScriptService/Services/       Modulo.luau (estado/reglas) + ModuloHandler.server.luau (cableado)
src/StarterPlayer/StarterPlayerScripts/Client/{*.client.luau, *.luau, UI/}
src/StarterPlayer/StarterPlayerScripts/Client/UI/Kit/    sistema de diseño en Fusion (un constructor por módulo)
assets/ui/                              PNG del arte 2D de la interfaz (claves de Config/Iconos); README con el brief
herramientas/                           NO mapeado en Rojo: scripts de diseño para la barra de comandos / MCP
```

Rojo 7: `.luau` → ModuleScript, `.server.luau` → Script, `.client.luau` →
LocalScript, `X.model.json` → instancia (los RemoteEvents van así), carpeta
con `init.luau` → ModuleScript con hijos (`PruebasDefinidas/`).

Capas (la dependencia va siempre hacia abajo, nunca al revés):

```
Config            datos puros: números, textos, tablas de probabilidad, definiciones,
                  Paleta (grises whitebox + Paleta.MUNDO + VARIANTES), Iconos (ids del arte 2D)
Utilidades        sin estado de juego, servidor y cliente por igual:
                  Primitivas → ModelosMascota / ModelosObjetos / ModelosMonton,
                  Geometria, PoseBrazos, Red, Senal, Formato, Entrada,
                  Glifos (iconos dibujados de respaldo)
Services          reglas y estado (Perfiles, Bolsa, Mejoras, Economia…). El patio
                  es una fachada (Botin) sobre seis módulos de una responsabilidad:
                  GeneradorBotin (qué sale) · ObjetosPatio (registro y reclamo) ·
                  FisicaBasura (cae y se ancla) · Montones (ciclo de vida) ·
                  Iman · Lanzamiento; tipos comunes en TiposPatio, grupos de
                  colisión en Colisiones
*Handler.server   cableado: prompts, remotes, cooldowns → llaman a los módulos
Client            solo intención + presentación; toma Config y Utilidades, nunca Services
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
- Cabecera de cada archivo: qué hace ("Única responsabilidad") y el **porqué**
  de lo no obvio. Documenta decisiones, no sintaxis.
- El servidor es la autoridad: el cliente sólo envía intención por RemoteEvent y
  el servidor valida distancia, cooldown, dinero y lo que tiene abierto.
- `Config/TablasProbabilidad.luau` es la ÚNICA fuente de probabilidades
  (servidor, y el álbum de mascotas para enseñarlas). Toda tabla suma 100; hay assert.
- Persistencia: todo acceso a DataStore va en `pcall`, un perfil que no cargó
  nunca se guarda (bandera `cargado`).
- Geometría del runtime se localiza por **tags/atributos** de CollectionService
  (`RanuraMonton`, `Contenedor`, `PuntoAparicion`, `BarreraCuadrante`…), nunca
  por listas de nombres. Cuadrantes y sus materiales: `GameConfig.CUADRANTES`
  + `Utilidades/Cuadrantes` (servidor y cliente).
- Arte por capas: el whitebox (grises de `Config/Paleta.luau`) sigue siendo
  el esqueleto funcional; el arte son piezas `SoloDecorado` sin colisión de
  `ArteMundo` y materiales sobre las cajas visibles (`Paleta.MUNDO`,
  `Paleta.VARIANTES` por nombre). Nunca cambiar nombre, tag, atributo,
  tamaño ni posición de una parte funcional para "mejorar" su aspecto.
- Lo que la v2 QUITA se borró del código (energía, gemas, Sobre, Contenedor
  Dorado, Pase de la Suerte, Montón extra, reparación, fusión, venta, base,
  logros con dinero): no se reintroduce sin decisión del usuario. Lo que solo
  POSPONE (figuritas, cintas, trajes del botín) sigue tras
  `GameConfig.activa("FIGURINAS" | "CINTAS" | "TRAJES_BOTIN")`; no añadir
  dependencias nuevas de ello (ver CONTEXTO §3 "Diseño v2").
- UI: en **Fusion 0.3** con el Kit (`Client/UI/Kit`, estilo "UI Kit" de
  simulador: contorno marino, colores intensos, barras de título de color,
  studs). Cada panel: `local scope = Fusion.scoped(Fusion, Kit)` y
  `scope:Ventana{...}` abierta por `Computed(use(Menu.abiertoR) == nombre)`.
  El estado sale de `EstadoCliente.reactivo`; el perfil llega varias veces
  por segundo como tablas nuevas, así que se derivan **primitivos** con
  `Computed` y las listas se recorren sobre definiciones de Config, no sobre
  el perfil. Iconos siempre por `scope:Icono` (registro
  `Config/Iconos` + `Utilidades/Glifos`), nunca `rbxassetid` sueltos.

## Verificar

1. Consola de Studio sin errores tras sincronizar (`get_console_output`).
2. Hornear mundo (`hornear-desde-mcp.luau` devuelve los conteos) → capturas
   con `screen_capture` + `camera_position` (vista aérea desde (-26, 330, 60)
   mirando a (-26, 0, 30); la caseta desde la plaza (6, 9, 83) → (0, 7, 133);
   la barrera del norte desde (-20, 12, 5) → (-30, 5, -45); una esquina de la
   valla) → mundo v5: 18 `RanuraMonton` (12 chicos + 6 grandes, con
   `Cuadrante` y `Zona`), 8 `BarreraCuadrante`, 1 `PuntoAparicion`,
   1 `Contenedor`, 4 `Limite`, 0 `Parcela`, 0 `MaquinaRefrescos`,
   0 `FigurinaFija` (con `FIGURINAS` apagada), ~1.000 instancias en `Mundo`.
   El plano está en la cabecera de `ConstructorMundo` (patio 97,5×150 con
   2x3 cuadrantes; los cuatro del sur, zona "patio" de basura revuelta; los
   dos del norte, zonas ricas en metal y orgánico tras barreras de Rebirth 1
   y 2; recicladora al sur, valla a 24 studs del patio).
3. Play: pruebas de servidor con `EjecutarPrueba:Invoke(nombre)`:
   - perfil y progreso: `estado`, `perfilV3`, `mejorasV2`, `brazoLimita`,
     `aparicion`, `tutorial`, `sinRestos` (nada de lo que la v2 quitó);
   - patio: `excavar`, `reclamoAtomico`, `montonPiezas`, `reacomodo`,
     `sinRecogidaAutomatica`, `variedadBasura`, `enPatio`, `limiteJugador`,
     `topePatio`;
   - rebirths: `rebirthTabla`, `renacerRequisitos`, `renacer`;
   - mascotas y fragmentos: `rarezaOdds`, `siempreNueva`, `primeraMascota`,
     `montaje`, `fragmentoCerrado`, `fragmentoAlDepositar`,
     `fragmentosMonton`, `mezclaZonas`, `repetidaNivel`, `huecos`,
     `bonusMascota`, `imanMaterial`, `reyReciclon`, `simularSet` (y
     `darFragmentos` set n para ver la revelación en el cliente);
   - puntería: `bonusDistancia`, `racha`, `primeroEntra`, `pagoFormula`
     (y en el cliente `("trayectoria", 0.8)` dibuja la línea de ayuda);
   - patio por zonas: `cuadrantes`, `variedadPiezas`, `tesoroGrande`,
     `valoresMaterial`, `prioridadExcavador`, `reposicion`, `bloqueoRebirth`,
     `barreraColision`, `caminarBarrera` (el personaje anda de verdad hacia
     el Metal con 0 y con 1 rebirths);
   - bolsa ("el dinero sólo sale del contenedor"): `billeteEnBolsa`,
     `sinDineroAlRecoger`, `salirRecicla`, `bolsaProtegida`, `lanzarBolsa`,
     `lanzarBolsaFallo`, `lanzarContraRecicladora`, `bolsaEnAlto` (la bolsa
     fallada no se recicla sola; en alto se baja junto al contenedor),
     `recicladora` (y luego
     `EjecutarPruebaCliente:Invoke("recicladora")` para la cinta; si el MCP no
     puede invocar el BindableFunction, por atributo `Prueba`, ver CONTEXTO).
   `montonPiezas` y `reacomodo` dependen de la física y fallan de vez en
   cuando (una pieza que sale disparada o que tarda en anclarse): repetir
   antes de dar nada por roto.
   En el cliente `EjecutarPruebaCliente:Invoke("reticula")` y `("verme", 8)`
   para capturar el propio personaje desde fuera; `("plataforma", "tactil")`
   fuerza la disposición táctil y `("hud")` lista los bloques del HUD y avisa
   de solapes o de que algo se sale del viewport.
4. Multijugador: Studio → Test → Clients and Servers (2 jugadores), ver
   `README-pruebas.md`.

## Bash del harness

Los heredocs de más de ~8 KB con comillas simples se corrompen: para archivos
grandes usar la herramienta Write; Bash para archivos pequeños y comandos.
