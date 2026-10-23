# assets/ui — arte 2D de la interfaz

Cada PNG de esta carpeta se llama como su clave en
`src/ReplicatedStorage/Shared/Config/Iconos.luau`. Mientras una clave tenga id
`0`, la UI dibuja el icono por código (`Utilidades/Glifos`); en cuanto tiene id,
usa la imagen. Nada más cambia.

Las claves de lo que la v2 quitó (`gema`, `sobre`, `contenedorDorado`,
`pocion`) se borraron el 22 oct y la prueba `sinRestos` falla si vuelven;
`cartas`, `iman` y el marco de carta se fueron antes, con las mascotas
(3 oct).

## Iconos en uso (23 sep): set "Simulator Icon Pack" de la Creator Store

Las claves con id salen de un set gratuito de estilo simulador (el mismo
estilo que el "UI KIT GENERAL" de referencia). Las copias de la Toolbox
traían scripts maliciosos: se usaron solo sus imágenes (ver CONTEXTO).

| Clave | Imagen del set | Id |
|---|---|---|
| billete | Cash/CashIcon | 15402858705 |
| rayo | Stats/Energy | 17368078790 |
| bolsa | Menus/Inventory (mochila) | 15402958715 |
| libreta | Menus/Index (libro) | 127110909372919 |
| telefono | Menus/Shop | 17368217589 |
| trofeo | Stats/Trophies/Wins | 12129301834 |
| casa | Misc/House | 15403180857 |
| montana | Menus/Teleport (portal) | 17368164592 |
| lanzar | Stats/Rocket | 16670799841 |
| mano | Cursors/Click | 17260727409 |
| raton | Cursors/Classic | 13443203578 |
| flecha | Stats/Strength | 15403007921 |
| estrella | Stars/Star | 17368097932 |
| corona | Menus/VIP | 16912465495 |
| check | Misc/Accept | 17368190066 |
| candado | Misc/LockClosed | 17368080973 |
| corazon | Stats/Health | 17368075795 |
| nota, cinta | Misc/Disc | 95668779942949 |
| engranaje | Menus/Settings | 17368089841 |
| bota | Stats/Speed | 17368052918 |
| cofre | Gems/GemChest | 15402896733 |
| cruz | Misc/Deny | 17368208554 |

`studs` (6927295847, el Decal `Workspace.Studs` del place) no es un icono: es
la textura que el Kit repite de fondo en botones, tarjetas y ventanas.

Siguen dibujadas (sin equivalente en el set): `lata`, `figurina`, `camara`,
`sonido`, `regalo`, `calendario`, los `set*`, las `manos*`, `papel`, `logo`.
Los briefs de abajo sirven para encargar esas.

## Estilo común

- PNG con transparencia, fondo vacío, sin texto dentro (el texto lo pone el
  juego, en tres idiomas), esquinas redondeadas.
- Contorno grueso marino (`#1B1D3A`, el `Paleta.UI_TINTA` del Kit; ≈ 10 px a
  256), colores planos e intensos, una luz y una sombra. Referencia: los iconos
  del set de arriba y los del HUD de KOTAMON.
- Colores por función (de `Config/Paleta.luau`): dinero verde `#3ACE3E`,
  Turbo ámbar `#FFA814`, destacado amarillo `#FFC41C`, bolsa azul `#4068C8`,
  fuerza naranja `#FF6E32`, peligro rojo `#F03440`, tesoro violeta `#AA55EB`.
  Los tipos de basura llevan el color de su contenedor: papel celeste
  `#6EC8F0`, plástico amarillo `#F6CA24`, metal plomo `#767F8B`, orgánico
  verde `#4EAC46`, general azul `#2C6ED8`.

## Prioridad 1 — HUD y manos

| Archivo | Tamaño | Qué es |
|---|---|---|
| `manosVacia.png` | 1600×900 (o 2000×1125) | Primera persona: dos manos sujetando la bolsa azul abierta entre ellas, boca a ~40 % de la altura, brazos entrando por las esquinas inferiores y sangrando fuera del lienzo. Con esta sola ya funciona |
| `manosMedia.png` | igual | La misma, bolsa medio llena (se ve abultada) |
| `manosLlena.png` | igual | La misma, bolsa llena y cerrada con su nudo |
| `billete.png` | 256×256 | Billete verde |
| `rayo.png` | 256×256 | Rayo ámbar (el Turbo) |
| `bolsa.png` | 256×256 | Bolsa de basura azul, cerrada |
| `libreta.png` | 256×256 | Libreta con pestañas de colores (Pedidos) |
| `telefono.png` | 256×256 | Teléfono (Tienda) |
| `camara.png` | 256×256 | Cámara (cambiar a primera o tercera persona) |
| `sonido.png` | 256×256 | Altavoz con ondas (el botón Sonido) |
| `regalo.png` | 256×256 | Caja de regalo con lazo (el botón Recompensas y los regalos por jugar) |
| `trofeo.png` | 256×256 | Trofeo dorado (insignias y récords) |
| `lanzar.png` | 256×256 | Bolsa volando en arco |
| `mano.png` | 256×256 | Mano abierta (recoger) |
| `raton.png` | 256×256 | Ratón con el botón izquierdo marcado |
| `lata.png` | 256×256 | Lata de refresco |
| `flecha.png` | 256×256 | Flecha hacia arriba (fuerza de lanzamiento) |

## Prioridad 2 — Paneles

`calendario` (hoja de calendario con una casilla marcada: el calendario de 7
días de Recompensas), `estrella`, `corona`, `check`, `candado`, `corazon`,
`nota`, `figurina`, `cinta`, `engranaje`, `bota`, `cofre`, `cruz` (256×256) y
los tipos de basura `setMetal` (lata o tuerca), `setPlastico` (botella),
`setPapel` (hoja de papel o periódico), `setOrganico` (cáscara o hoja verde).

## Prioridad 3 — Opcionales

| Archivo | Tamaño | Qué es |
|---|---|---|
| `papel.png` | 512×512 repetible | Textura sutil de papel/cartón, casi blanca (se pone al 15 % sobre el fondo) |
| `logo.png` | 1024×512 | Logotipo "Recíclatas" |

## Cómo se suben

1. Dejar los PNG aquí.
2. `powershell -ExecutionPolicy Bypass -File herramientas/servir-fuentes.ps1`
   (sirve `/assets/...` como binario).
3. Desde Claude Code con Studio abierto: `upload_image` del MCP con
   `http://localhost:8123/assets/ui/<clave>.png` → devuelve `rbxassetid://N`;
   se escribe `N` en `Config/Iconos.luau`.
4. Roblox modera las imágenes: pueden tardar unos minutos en verse. Hasta
   entonces el respaldo dibujado sigue activo si el id es 0.

Alternativa: Asset Manager de Studio → Importar en lote, y copiar los ids.

Las imágenes de la ficha y de la tienda de Roblox (icono, insignias, pases,
productos y miniaturas) no van aquí: están en `thumbnails/`.
