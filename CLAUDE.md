# Recíclatas (CleanRecycle) — guía para trabajar en este repo

Réplica whitebox de KOTAMON para Roblox. El diseño está en `docs/GDD.md`; el
estado del proyecto y las decisiones no obvias en `CONTEXTO.md`. Léelos antes de
tocar balance o estructura.

## Toolchain

- Rojo 7.7.0 (aftman). `rojo serve default.project.json --port 34872` y conectar
  el plugin en Studio. No hay Wally: cero dependencias externas a propósito.
- Sin plugin (p. ej. trabajando por MCP): arrancar
  `powershell -ExecutionPolicy Bypass -File herramientas/servir-fuentes.ps1` y en
  la barra de comandos / `execute_luau` (Edit):
  `loadstring(game:GetService("HttpService"):GetAsync("http://localhost:8123/herramientas/instalar-desde-http.luau", true))()`.
  Crea el mismo árbol que Rojo; idempotente.
- Pruebas dentro de la VM del juego (Play): `game.ServerStorage.EjecutarPrueba:Invoke("estado")`
  (ver `Services/PruebasDefinidas/`) y `ReplicatedStorage.EjecutarPruebaCliente:Invoke("abrir","Album")`.
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
src/ReplicatedStorage/Shared/{Config,Events,Utilidades}
src/ServerStorage/Herramientas/ConstructorMundo.luau   esqueleto whitebox + llamadas al arte
src/ServerStorage/Herramientas/ArteMundo.luau          piezas de arte low-poly (SoloDecorado)
src/ServerScriptService/Services/       Modulo.luau (estado/reglas) + ModuloHandler.server.luau (cableado)
src/StarterPlayer/StarterPlayerScripts/Client/{*.client.luau, *.luau, UI/}
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
                  Geometria, PoseBrazos, Red, Senal, Formato, Entrada, ProgresoLogros,
                  Glifos (iconos dibujados de respaldo)
Services          reglas y estado (Perfiles, Bolsa, Mascotas, Economia…). El patio
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
  el servidor valida distancia, cooldown, energía y dinero.
- `Config/TablasProbabilidad.luau` es la ÚNICA fuente de probabilidades
  (servidor y modal de la tienda la leen). Toda tabla suma 100; hay assert.
- Persistencia: todo acceso a DataStore va en `pcall`, un perfil que no cargó
  nunca se guarda (bandera `cargado`).
- Geometría del runtime se localiza por **tags/atributos** de CollectionService
  (`RanuraMonton`, `Parcela`, `Contenedor`…), nunca por listas de nombres.
- Arte por capas: el whitebox (grises de `Config/Paleta.luau`) sigue siendo
  el esqueleto funcional; el arte son piezas `SoloDecorado` sin colisión de
  `ArteMundo` y materiales sobre las cajas visibles (`Paleta.MUNDO`,
  `Paleta.VARIANTES` por nombre). Nunca cambiar nombre, tag, atributo,
  tamaño ni posición de una parte funcional para "mejorar" su aspecto.
- UI: tema papel y tinta de `Componentes` (pegatinas, insignias, modales que
  se encogen al viewport); iconos siempre por `Componentes.icono` (registro
  `Config/Iconos` + `Utilidades/Glifos`), nunca `rbxassetid` sueltos.

## Verificar

1. Consola de Studio sin errores tras sincronizar (`get_console_output`).
2. Hornear mundo (`hornear-desde-mcp.luau` devuelve los conteos) → capturas
   con `screen_capture` + `camera_position` (vista aérea desde (-36, 430, 70)
   mirando a (-36, 0, 39); la caseta desde la plaza (6, 9, 108) → (0, 7, 158);
   la calle de las parcelas; una esquina de la valla) → 12 `RanuraMonton`,
   6 `Parcela`, 1 `Contenedor`, 1 `MaquinaRefrescos`, 6 `FigurinaFija`,
   4 `Limite`, ~1.600 instancias en `Mundo` (sin árboles). El plano está en la cabecera
   de `ConstructorMundo` (patio en el origen, recicladora al sur, parcelas
   en columna al oeste, valla alrededor de todo).
3. Play: asserts de servidor en `execute_luau` (reclamo atómico, pity, fusión,
   odds suman 100, 41/40/12/7/3 definiciones); `montonPiezas`, `reacomodo`,
   `sinRecogidaAutomatica`, `variedadBasura`, `enPatio` para el patio;
   `billeteEnBolsa`, `sinDineroAlRecoger`, `bonusBolsaLlena` para la regla
   "el dinero sólo sale del contenedor" (si el MCP no puede invocar el
   BindableFunction, por atributo `Prueba`, ver CONTEXTO);
   en el cliente `EjecutarPruebaCliente:Invoke("reticula")` y `("verme", 8)`
   para capturar el propio personaje desde fuera; `("plataforma", "tactil")`
   fuerza la disposición táctil y `("hud")` lista los bloques del HUD y avisa
   de solapes o de que algo se sale del viewport.
4. Multijugador: Studio → Test → Clients and Servers (2 jugadores), ver
   `README-pruebas.md`.

## Bash del harness

Los heredocs de más de ~8 KB con comillas simples se corrompen: para archivos
grandes usar la herramienta Write; Bash para archivos pequeños y comandos.
