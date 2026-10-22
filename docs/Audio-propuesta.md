# Propuesta de audio — Recíclatas

> 22 oct 2026. Hoy el juego no tiene ni un sonido. Esto es una **lista de candidatos para escuchar y aprobar**: no se ha insertado nada en el place ni se ha tocado código; otro paquete los integrará después. Cada sonido trae 2–3 candidatos con la recomendación marcada, el volumen de partida y si suena en 2D (interfaz, solo lo oye el jugador) o en 3D (en el mundo, con distancia).
>
> **Regla de licencia aplicada.** Solo audio que cualquier experiencia puede usar: el subido por **Roblox** (cuenta 1) y el de su **biblioteca con licencia** (los más de 100.000 efectos y pistas "de socios" que citan los documentos de Roblox). Esa biblioteca no está en la cuenta "Roblox", sino en dos cuentas verificadas: **APMOfficial** (música y jingles; cada ficha acaba en "Courtesy of APM Music") y **ProSoundEffects** (efectos; "Courtesy of Pro Sound Effects"). Las he tratado como "biblioteca con licencia", que es lo que pedía el encargo; si se quiere solo la cuenta "Roblox", ver §7, punto 6. Se descartó todo lo subido por otros creadores. Los 79 audios citados se comprobaron uno a uno el 22 oct: creador, publicado, gratis y visible en la Creator Store.
>
> **No he podido escuchar nada.** La elección sale del título, de la ficha de la biblioteca (instrumentos, carácter, duración) y de las etiquetas automáticas de Roblox. La decisión final es de oído.

## Resumen

Volumen = `Sound.Volume` (por defecto 0,5) dentro de su SoundGroup; es un punto de partida para ajustar en Studio. La columna **Elegido** es para que el usuario apunte el ID que apruebe.

| Clave | Cuándo suena | Recomendado | ID | Modo | Vol. | Elegido |
|---|---|---|---|---|---|---|
| `recoger` | cada pieza recogida | Roblox GUI - Bubble | 17208204604 | 2D | 0,35 | |
| `billete` | recoger un billete | Roblox GUI - Pickup | 17208319162 | 2D | 0,5 | |
| `tesoro` | recoger un tesoro | Magic Glows Soft Clusters Of Chiming Hits 1 | 9116394545 | 2D | 0,6 | |
| `bolsaLlena` | la bolsa se llena | Musical Doorbell (d) | 1840084286 | 2D | 0,5 | |
| `carga` | mantener F para lanzar | Synth Zip Short High Pitch Ascending Bursts | 9126089814 | 2D | 0,3–0,45 | |
| `lanzar` | soltar la bolsa | Slow Whoosh Beefy Airy Pass By 4 | 9119227910 | 3D | 0,6 | |
| `dentroGolpe` | la bolsa cae en el contenedor | Trash Can Impact 12 / Dumpster Booms Hit Side 1 | 9120255466 / 9114204770 | 3D | 0,7 | |
| `dentro` | fanfarria del "¡DENTRO!" | Winner (Bingo) | 1844442553 | 2D | 0,45 | |
| `fallo` | la bolsa cae fuera | Deep Impacts 6 | 9114036494 | 3D | 0,6 | |
| `cobro` | el dinero llega al contador | CoinTransfer_01 | 127645268874265 | 2D | 0,5 | |
| `mejora` | comprar un nivel de mejora | Magic Transformation 15 | 9116422179 | 2D | 0,55 | |
| `rebirth` | hacer un rebirth | Fortune Fun "Star Prize" (+ Magic Burst 1) | 1846251722 (+ 9116384485) | 2D | 0,7 | |
| `insignia` | tarjeta de logro | Correct Answer 3 | 1839997938 | 2D | 0,6 | |
| `clic` | pulsar un botón | Roblox_UI_Bright_Click | 15675059323 | 2D | 0,3 | |
| `panelAbrir` | abrir una ventana | Roblox_UI_Paper_Swipe | 15675037413 | 2D | 0,3 | |
| `panelCerrar` | cerrar una ventana | Roblox GUI - Back | 17208186900 | 2D | 0,3 | |
| `denegado` | acción rechazada | Roblox GUI - Negative | 17208353912 | 2D | 0,4 | |
| `regalo` | calendario, regalos, pedido cumplido | Funfair Fun (sting) | 9038314266 | 2D | 0,6 | |
| `trituradora` | rodillos de las 5 recicladoras (bucle) | Comic Engine Constant 1 | 9112760393 | 3D | 0,15–0,2 | |
| `cinta` | cinta con basura (bucle) | Audio/Roblox_Pinball_Rolling_Metal_Tracks_Loop_01 | 16480554578 | 3D | 0,15–0,2 | |
| `prensa` | sale el bloque prensado | Trash Can Crush 1 | 9120253198 | 3D | 0,4 | |
| `musicaPatio` | fondo del juego (lista de 3) | Happy Place underscore · Tiny Crafts (a) · Daily Affirmation - Alt1, NoMel | 9045567469 · 9040170470 · 9048749096 | 2D | 0,3 | |
| `musicaTurbo` | al activar el Turbo (opcional) | Cheat Code | 1837351012 | 2D | 0,35 | |

**Cómo escucharlos:** el enlace "escuchar" abre la ficha de la Creator Store, que tiene botón de reproducir. En Studio: Toolbox → Creator Store → Audio y pegar el ID en el buscador.

---

## 1. Efectos del patio

Duración = la que da la Creator Store (redondeada a segundos; "<1 s" es menos de un segundo).

### 1.1 `recoger` — recoger una pieza (pop suave)

Cuándo: cada objeto recogido (`RecogidaEvent` → `EfectoRecogida.client`, el "+1"). Es el sonido que más se repite (decenas por minuto): tiene que ser corto, blando y sin cola.
**Modo:** 2D, solo quien recoge. **Volumen:** 0,35, con tono al azar entre 0,94 y 1,08 para que no canse.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 17208204604 | Roblox GUI - Bubble | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/17208204604) |
| Alternativa | 9119669295 | Suction Pop 2 (SFX): *pop de pistola de juguete o de corcho, categoría "Cartoon"* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9119669295) |
| Alternativa | 9112751536 | Bubble Bloop High Pitched Cute 1 (SFX): *burbuja aguda, "cute"* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9112751536) |

Por qué: la burbuja es del paquete de interfaz del propio Roblox, la misma familia que `clic` y los paneles. El pop de corcho es más cartoon pero más seco; si se elige, bajar el volumen.

### 1.2 `billete` — recoger un billete (5 %, "+1 $")

**Modo:** 2D. **Volumen:** 0,5.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 17208319162 | Roblox GUI - Pickup: *moneda y "ding" de recoger* | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/17208319162) |
| Alternativa | 9126073001 | Synth Sparkle Tone High Pitch Bell Tone Ding (SFX): *campanita de interfaz* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9126073001) |
| Alternativa | 9113848469 | Coin Bounce 3 (SFX): *moneda que rebota, tintineo metálico* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9113848469) |

### 1.3 `tesoro` — recoger un tesoro (1 %, "¡TESORO!")

Es raro (y seguro en el montón grande): puede ser más vistoso que el billete.
**Modo:** 2D. **Volumen:** 0,6.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 9116394545 | Magic Glows Soft Clusters Of Chiming Hits 1 (SFX): *racimo de campanitas que brillan* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9116394545) |
| Alternativa | 9048764475 | Magical Meetup - Hit2: *golpe orquestal corto, pizzicato y campanas (álbum Happy Place)* | APMOfficial | ≈2 s | [escuchar](https://create.roblox.com/store/asset/9048764475) |
| Alternativa | 1847713809 | Instant Fun 19: *jingle de dibujos animados (álbum CARTOONWORX)* | APMOfficial | ≈4 s | [escuchar](https://create.roblox.com/store/asset/1847713809) |

### 1.4 `bolsaLlena` — la bolsa se llena (aviso)

Cuándo: al llenarse (el HUD pone "¡LLENA!" en rojo). Una vez por llenado; si se intenta recoger con la bolsa llena (la barra tiembla), suena `denegado`, no esto.
**Modo:** 2D. **Volumen:** 0,5.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 1840084286 | Musical Doorbell (d): *un solo "din-don" de timbre* | APMOfficial | ≈3 s | [escuchar](https://create.roblox.com/store/asset/1840084286) |
| Alternativa | 15675085146 | Roblox_UI_Indicator: *aviso melódico de interfaz* | Roblox | ≈3 s | [escuchar](https://create.roblox.com/store/asset/15675085146) |
| Alternativa | 9113854411 | Comic Boinks 2 (SFX): *"boing" de muelle, cómico* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9113854411) |

### 1.5 `carga` — mantener F para lanzar (tensión que sube)

Cuándo: mientras se mantiene F o el botón LANZAR (`EstadoCliente.alCambiarCarga`, de 0 a 1 en 1,2 s: `GameConfig.FUERZA_LANZAMIENTO.segundosCarga`). Se corta al soltar.
**Modo:** 2D, solo quien lanza. **Volumen:** de 0,3 a 0,45 con la carga.
**Cómo:** reproducir al pulsar con `PlaybackSpeed = TimeLength / 1,2` para que llegue arriba justo a carga llena; si se mantiene más, dejar que acabe (o un `LoopRegion` en el último tramo). Otra opción: bucle con `PlaybackSpeed` de 0,9 a 1,3 según la carga.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 9126089814 | Synth Zip Short High Pitch Ascending Bursts (SFX): *zip corto que sube* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9126089814) |
| Alternativa | 16480578169 | Audio/Roblox_Pinball_8Bit_Riser_01: *subida de 8 bits (paquete Pinball)* | Roblox | ≈2 s | [escuchar](https://create.roblox.com/store/asset/16480578169) |
| Alternativa | 9117953934 | Pulsing Synth Constant Ascending Flutter 5 (SFX): *aleteo de sintetizador que sube* | ProSoundEffects | ≈2 s | [escuchar](https://create.roblox.com/store/asset/9117953934) |

Por qué: el recomendado ya dura casi lo que la carga (1,4 s según su ficha), así que casi no hay que acelerarlo.

### 1.6 `lanzar` — soltar la bolsa (whoosh)

**Modo:** 3D en la bolsa lanzada, para que lo oigan los demás (`RollOffMaxDistance` ≈60). **Volumen:** 0,6; con más fuerza, un poco más grave (`PlaybackSpeed ≈ 1,1 − 0,2·fuerza`).

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 9119227910 | Slow Whoosh Beefy Airy Pass By 4 (SFX): *whoosh con cuerpo, rápido* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9119227910) |
| Alternativa | 9119900967 | Synth Whoosh Cartoonish 2 (SFX): *whoosh de sintetizador, de dibujos* | ProSoundEffects | ≈2 s | [escuchar](https://create.roblox.com/store/asset/9119900967) |
| Alternativa | 15675024286 | Roblox_UI_Whoosh_01 | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/15675024286) |

Por qué: la bolsa pesa; un whoosh con cuerpo se distingue de los de interfaz, que se quedan para los paneles.

### 1.7 `dentroGolpe` + `dentro` — acierto "¡DENTRO!"

Son dos capas que suenan juntas: el golpe, en el contenedor, y la fanfarria, para quien lanzó (`CelebracionEvent` → `Celebraciones.client`). Como pasa cada minuto o menos, la fanfarria tiene que ser corta: si alguna dura más de 2 s, recortarla con `PlaybackRegion`.

**`dentroGolpe`.** **Modo:** 3D en el contenedor (tag `Contenedor`), lo oyen todos (`RollOffMaxDistance` ≈80). **Volumen:** 0,7.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado (los 4 de color)** | 9120255466 | Trash Can Impact 12 (SFX): *cubo de plástico, golpe hondo y hueco* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9120255466) |
| **Recomendado (el general)** | 9114204770 | Dumpster Booms Hit Side 1 (SFX): *contenedor metálico, golpe grande que resuena* | ProSoundEffects | ≈3 s | [escuchar](https://create.roblox.com/store/asset/9114204770) |
| Alternativa | 9113860267 | Comic Metal 6 (SFX): *golpes de metal de dibujos, categoría "Cartoon"* | ProSoundEffects | ≈2 s | [escuchar](https://create.roblox.com/store/asset/9113860267) |

Por qué: los cuatro de tipo son cubos y el general es el volquete metálico de la recicladora. Un golpe distinto ayuda a saber dónde ha entrado.

**`dentro` (fanfarria).** **Modo:** 2D, solo quien lanzó. **Volumen:** 0,45.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 1844442553 | Winner *(variante "Bingo")*: *remate de ganador de concurso de tele (álbum Tv Show Trax)* | APMOfficial | ≈2 s | [escuchar](https://create.roblox.com/store/asset/1844442553) |
| Alternativa | 1840084163 | Gameshow Buzzer (a): *"sting" positivo de concurso* | APMOfficial | ≈2 s | [escuchar](https://create.roblox.com/store/asset/1840084163) |
| Alternativa | 12222253 | victory.wav: *el jingle clásico de Roblox* | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/12222253) |

Idea opcional: cuando va bien separado (x2), la misma fanfarria a `PlaybackSpeed` 1,06 (un tono más alegre) en vez de otro sonido.

### 1.8 `fallo` — la bolsa cae fuera (golpe sordo)

Cuándo: la bolsa toca el suelo sin entrar (se queda para su dueño). También cuando rebota en la tapa de un contenedor cerrado (`ContenedoresBloqueados`).
**Modo:** 3D donde cae (`RollOffMaxDistance` ≈50). **Volumen:** 0,6.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 9114036494 | Deep Impacts 6 (SFX): *golpe grave y corto, categoría "Cartoon"* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9114036494) |
| Alternativa | 9113480915 | Body Fall Thud 2 (SFX): *golpe sordo con arrastre* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9113480915) |
| Alternativa | 9113246413 | Bag Dull Sprinkling Impact 5 (SFX): *bolsa que cae en suelo duro, sorda* | ProSoundEffects | ≈3 s | [escuchar](https://create.roblox.com/store/asset/9113246413) |

Según su ficha, la tercera incluye también el recogerla: usar solo el primer segundo y medio (`PlaybackRegion`).
**Opcional, `falloAviso`** (2D, solo quien lanzó, volumen 0,3): Loser *(variante "Sorry")*, APMOfficial, ≈1 s, ID 1844442622, [escuchar](https://create.roblox.com/store/asset/1844442622). Es el remate de "lo siento" de un concurso, para que se entienda que la racha vuelve a cero.

### 1.9 `cobro` — cobrar (monedas)

Cuándo: en la celebración, cuando el dinero llega volando al contador; unas décimas después del golpe y la fanfarria, para no pisarlos.
**Modo:** 2D, quien cobra. **Volumen:** 0,5.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 127645268874265 | CoinTransfer_01: *monedas que pasan de un sitio a otro* | Roblox | ≈2 s | [escuchar](https://create.roblox.com/store/asset/127645268874265) |
| Alternativa | 17208380755 | Roblox GUI - Purchase: *"cling" de compra* | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/17208380755) |
| Alternativa | 9113849583 | Coin Throws 2 (SFX): *varias monedas cayendo* | ProSoundEffects | ≈2 s | [escuchar](https://create.roblox.com/store/asset/9113849583) |

**Opcional, `contarDinero`** (2D, en bucle mientras la cifra cuenta, volumen 0,2): Audio/Roblox_Pinball_Scoreboard_Tally_Loop_01, Roblox, ≈5 s, ID 16480554151, [escuchar](https://create.roblox.com/store/asset/16480554151).

---

## 2. Progreso y recompensas

### 2.1 `mejora` — comprar un nivel de mejora (power-up)

Cuándo: cada nivel comprado en la tienda (40 en total por ciclo, así que se oye a menudo: mejor corto). Sirve también para pases y cosméticos.
**Modo:** 2D. **Volumen:** 0,55.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 9116422179 | Magic Transformation 15 (SFX): *"boinks" brillantes y saltarines, categoría "Cartoon"* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9116422179) |
| Alternativa | 9125524869 | Electro Bubbles Synthy Spins Ascending Tones (SFX): *burbujas de sintetizador que suben* | ProSoundEffects | ≈2 s | [escuchar](https://create.roblox.com/store/asset/9125524869) |
| Alternativa | 9048764474 | Magical Meetup - Hit1: *golpe orquestal corto, pizzicato y campanas* | APMOfficial | ≈2 s | [escuchar](https://create.roblox.com/store/asset/9048764474) |

### 2.2 `rebirth` — hacer un rebirth (gran fanfarria, mágico)

Es el momento más grande (el primero llega hacia la hora de juego): puede durar 5–10 s y bajar la música a la mitad mientras suena.
**Modo:** 2D. **Volumen:** 0,7; capa de magia a 0,5 a la vez.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 1846251722 | Fortune Fun "Star Prize": *"gran premio" de concurso (álbum Showbiz Plus 2 - Gameshows)* | APMOfficial | ≈6 s | [escuchar](https://create.roblox.com/store/asset/1846251722) |
| Alternativa (más mágica) | 1839901317 | Heavenly sting: *revelación con voces celestiales* | APMOfficial | ≈6 s | [escuchar](https://create.roblox.com/store/asset/1839901317) |
| Alternativa (más grande) | 1845466651 | Celebration Fanfare: *fanfarria de metales* | APMOfficial | ≈11 s | [escuchar](https://create.roblox.com/store/asset/1845466651) |
| Capa de magia (`rebirthMagia`) | 9116384485 | Magic Burst 1 (SFX): *estallido mágico con cola tonal* | ProSoundEffects | ≈3 s | [escuchar](https://create.roblox.com/store/asset/9116384485) |

### 2.3 `insignia` — insignia o logro conseguido

Cuándo: la tarjeta de logro (`NotificacionEvent` tipo "logro"; vale también para la de récord).
**Modo:** 2D. **Volumen:** 0,6.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 1839997938 | Correct Answer 3: *acierto de concurso con sintes que suben y brillan* | APMOfficial | ≈5 s | [escuchar](https://create.roblox.com/store/asset/1839997938) |
| Alternativa | 1844442571 | Winner *(variante "Full Score")*: *remate de ganador de concurso* | APMOfficial | ≈3 s | [escuchar](https://create.roblox.com/store/asset/1844442571) |
| Alternativa (discreta) | 15675043410 | Roblox_UI_Tonal_Stinger | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/15675043410) |

Por qué no "Winner" como recomendado: la fanfarria de `dentro` es del mismo álbum, y una insignia que llega justo después de un acierto sonaría igual.

### 2.4 `regalo` — recompensa diaria, regalo, pedido cumplido

Cuándo: hoy, al cumplirse un pedido y con el premio de Turbo. Con la economía v4: la casilla del calendario, los regalos por minutos activos y el de regreso.
**Modo:** 2D. **Volumen:** 0,6.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 9038314266 | Funfair Fun (sting): *remate de ukelele y acordeón* | APMOfficial | ≈4 s | [escuchar](https://create.roblox.com/store/asset/9038314266) |
| Alternativa | 9040476898 | Early Bird - Hit1: *golpe alegre de melódica y láminas* | APMOfficial | ≈3 s | [escuchar](https://create.roblox.com/store/asset/9040476898) |
| Alternativa | 9125635442 | Magical Exit Sparkling Pass Bys Clinking Chi (SFX): *campanitas brillantes que pasan* | ProSoundEffects | ≈3 s | [escuchar](https://create.roblox.com/store/asset/9125635442) |

Por qué: el ukelele enlaza con la música del patio recomendada (§5.1).

---

## 3. Interfaz

Todo 2D y de los paquetes de interfaz del propio Roblox (`RBLX UI … (SFX)` de 2022, `Roblox_UI_*` de 2023 y `Roblox GUI - *` de 2024), para que suene como una sola familia.

### 3.1 `clic` — pulsar un botón

Cuándo: cualquier botón del Kit (`Boton`). **Volumen:** 0,3.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 15675059323 | Roblox_UI_Bright_Click | Roblox | <1 s | [escuchar](https://create.roblox.com/store/asset/15675059323) |
| Alternativa | 17208396156 | Roblox GUI - Select | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/17208396156) |
| Alternativa | 15675032796 | Roblox_UI_Small_Click | Roblox | <1 s | [escuchar](https://create.roblox.com/store/asset/15675032796) |

### 3.2 `panelAbrir` / `panelCerrar` — abrir y cerrar ventanas (swoosh suave)

Cuándo: al cambiar `Menu.abiertoR` (abrir: pasa a un panel; cerrar: vuelve a nada). **Volumen:** 0,3.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado (abrir)** | 15675037413 | Roblox_UI_Paper_Swipe | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/15675037413) |
| Alternativa (abrir) | 15675028888 | Roblox_UI_Whoosh_02 | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/15675028888) |
| Alternativa (abrir) | 17208405682 | Roblox GUI - Swipe | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/17208405682) |
| **Recomendado (cerrar)** | 17208186900 | Roblox GUI - Back | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/17208186900) |
| Alternativa (cerrar) | 10066914500 | RBLX UI Back (SFX) | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/10066914500) |
| Alternativa (cerrar) | 15675081158 | Roblox_UI_Cute_Goodbye | Roblox | <1 s | [escuchar](https://create.roblox.com/store/asset/15675081158) |

Opcional, `pestana` (cambiar de pestaña en Tienda o Pedidos): Roblox GUI - Tab, Roblox, ≈1 s, ID 17208408337, [escuchar](https://create.roblox.com/store/asset/17208408337).

### 3.3 `denegado` — acción denegada o error (suave)

Cuándo: el servidor rechaza algo (no llega el dinero, contenedor cerrado a mano, pieza de un tipo que no tienes, recoger con la bolsa llena). Como mucho uno cada 0,3 s.
**Volumen:** 0,4.

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 17208353912 | Roblox GUI - Negative | Roblox | <1 s | [escuchar](https://create.roblox.com/store/asset/17208353912) |
| Alternativa | 15675062723 | Roblox_UI_Whistle_Low | Roblox | <1 s | [escuchar](https://create.roblox.com/store/asset/15675062723) |
| Alternativa | 17208214688 | Roblox GUI - Call Decline | Roblox | ≈1 s | [escuchar](https://create.roblox.com/store/asset/17208214688) |

Por qué: son negativos de interfaz, no zumbadores; los "Wrong Answer" y "Gameshow Buzzer (b)" de APM se descartaron por estridentes.

---

## 4. La recicladora (bucles 3D, volumen bajo)

Hay cinco (la general y una detrás de cada contenedor de color). Según `Recicladora.client`, los rodillos de la trituradora giran **siempre** (más deprisa al caer basura), la cinta solo se mueve con basura encima y, al caer el último objeto, la prensa saca un bloque. Por eso son tres sonidos. Todos en 3D en su recicladora, `RollOffMode = InverseTapered`, `RollOffMinDistance` ≈6 y `RollOffMaxDistance` ≈40: así solo se oye la que está cerca.

**`trituradora`** (bucle siempre; **volumen** 0,15–0,2; `PlaybackSpeed` de 1,0 a 1,15 mientras tritura):

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 9112760393 | Comic Engine Constant 1 (SFX): *motor de dibujos en bucle: rítmico, chasquidos, chirridos* | ProSoundEffects | ≈27 s | [escuchar](https://create.roblox.com/store/asset/9112760393) |
| Alternativa | 9112760403 | Comic Engine Constant 2 (SFX): *lo mismo, toma más larga* | ProSoundEffects | ≈53 s | [escuchar](https://create.roblox.com/store/asset/9112760403) |
| Alternativa | 365965609 | Blender: *batidora; su ficha cita Freesound como origen* | Roblox | ≈4 s | [escuchar](https://create.roblox.com/store/asset/365965609) |

**`cinta`** (bucle mientras haya basura en la cinta; **volumen** 0,15–0,2):

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 16480554578 | Audio/Roblox_Pinball_Rolling_Metal_Tracks_Loop_01: *bolas rodando por raíles, hecho para bucle* | Roblox | ≈3 s | [escuchar](https://create.roblox.com/store/asset/16480554578) |
| Alternativa | 9113910422 | Conveyor Belt 2 (SFX): *cinta industrial con motor y traqueteo* | ProSoundEffects | ≈10 s | [escuchar](https://create.roblox.com/store/asset/9113910422) |
| Alternativa | 9113910297 | Conveyor Belt 5 (SFX): *ídem* | ProSoundEffects | ≈14 s | [escuchar](https://create.roblox.com/store/asset/9113910297) |

Las dos "Conveyor Belt" empiezan y acaban con el motor arrancando y parando: en bucle, usar `LoopRegion` en el tramo central.

**`prensa`** (una vez, al salir el bloque; **volumen** 0,4):

| | ID | Nombre | Creador | Duración | |
|---|---|---|---|---|---|
| **Recomendado** | 9120253198 | Trash Can Crush 1 (SFX): *cubo de metal aplastado, golpes y traqueteo* | ProSoundEffects | ≈3 s | [escuchar](https://create.roblox.com/store/asset/9120253198) |
| Alternativa | 9118478749 | Robot Transform Metal Bangs Clunks 6 (SFX): *golpes metálicos cortos* | ProSoundEffects | ≈1 s | [escuchar](https://create.roblox.com/store/asset/9118478749) |
| Alternativa | 9117231779 | Paper Shredder 2 (SFX): *trituradora de papel que arranca y para* | ProSoundEffects | ≈6 s | [escuchar](https://create.roblox.com/store/asset/9117231779) |

---

## 5. Música

Toda es instrumental. Las versiones "underscore", "NoMel" y "No Lead" no llevan la melodía principal: cansan menos en sesiones largas.

### 5.1 `musicaPatio` — fondo alegre y relajado

**Modo:** 2D, SoundGroup `Musica`. **Volumen:** 0,3.
**Cómo:** una lista con las tres recomendadas (≈6 min antes de repetir), en orden aleatorio sin repetir la última y con fundido de 2 s entre pistas. Ninguna pista de APM es un bucle sin costuras (tienen entrada y final), por eso mejor lista que `Looped`. La única hecha para bucle es la de Roblox (alternativa).

| | ID | Nombre | Creador (álbum) | Duración | |
|---|---|---|---|---|---|
| **Recomendada** | 9045567469 | Happy Place underscore: *acústica y juguetona con ukelele, sin melodía principal* | APMOfficial (Bells and Whistles) | 2:08 | [escuchar](https://create.roblox.com/store/asset/9045567469) |
| **Recomendada** | 9040170470 | Tiny Crafts (a): *pieza ligera "de tareas": pizzicato, maracas, guitarra, marimba, celesta* | APMOfficial (Positive & Playful) | 1:51 | [escuchar](https://create.roblox.com/store/asset/9040170470) |
| **Recomendada** | 9048749096 | Daily Affirmation - Alt1, NoMel: *indie folk alegre con ukelele y guitarras, sin melodía* | APMOfficial (Happy Place) | 1:56 | [escuchar](https://create.roblox.com/store/asset/9048749096) |
| Alternativa | 1843404009 | Happy Song: *folk con mandolina y ukelele, con melodía* | APMOfficial (UPBEAT INDIE FOLK) | 2:48 | [escuchar](https://create.roblox.com/store/asset/1843404009) |
| Alternativa | 9046514590 | Weekend Activites Underscore B: *pizzicato y piano, ligera* | APMOfficial (Beds: Light & Playful) | 1:34 | [escuchar](https://create.roblox.com/store/asset/9046514590) |
| Alternativa | 15675069601 | Roblox_UI_Loop_Calm_Music: *marimba y glockenspiel, tranquila, hecha para bucle* | Roblox | 1:35 | [escuchar](https://create.roblox.com/store/asset/15675069601) |
| Alternativa | 9039992037 | The Right Stuff *(mezcla sin melodía principal)*: *ukelele* | APMOfficial (Ukulele Whistling) | 2:00 | [escuchar](https://create.roblox.com/store/asset/9039992037) |

### 5.2 `musicaTurbo` — más enérgica, opcional

**Modo:** 2D, SoundGroup `Musica`. **Volumen:** 0,35.
**Cómo:** fundido desde el patio al activar el Turbo. Como el Turbo dura 10–15 min, mejor que suene una o dos veces y vuelva a la lista del patio; si suena todo el Turbo, cansa.

| | ID | Nombre | Creador (álbum) | Duración | |
|---|---|---|---|---|---|
| **Recomendada** | 1837351012 | Cheat Code: *sintes juguetones y animados, sabor a videojuego retro* | APMOfficial (RETRO GAMING) | 1:56 | [escuchar](https://create.roblox.com/store/asset/1837351012) |
| Alternativa | 9048733403 | Push Wave: *electrónica brillante y enérgica* | APMOfficial (Happy Place) | 2:04 | [escuchar](https://create.roblox.com/store/asset/9048733403) |
| Alternativa | 1843599021 | Fun Arcade: *electrónica bailable de arcade (sin ficha descriptiva)* | APMOfficial (KIDS GAMES) | 2:49 | [escuchar](https://create.roblox.com/store/asset/1843599021) |

Por qué Cheat Code: va bien con los efectos de "juego" (la subida de 8 bits de `carga` si se elige) y no compite con el ukelele del patio.

---

## 6. Notas para quien lo integre

- **Grupos.** En `SoundService`, un SoundGroup `Musica` y otro `Efectos` (con `Interfaz` y `Mundo` dentro si se quiere mezclar aparte). El perfil v4 ya trae `ajustes.musica` y `ajustes.efectos`: cada uno pone a 0 el volumen de su grupo.
- **Todo suena en el cliente.** El servidor ya avisa de cada momento (`RecogidaEvent`, `CelebracionEvent`, `RecicladoraEvent`, `NotificacionEvent`…). El instalador pone `SoundService.RespectFilteringEnabled = true`: lo que suena en un cliente no se replica. Por eso los 3D que deben oír todos (`lanzar`, `dentroGolpe`, `fallo`, recicladora) los reproduce cada cliente al recibir el evento.
- **Un registro, no ids sueltos.** Como con los iconos (`Config/Iconos` + `scope:Icono`), un `Config/Sonidos.luau` con clave → id, volumen, grupo, modo y variación de tono, y que el código use la clave.
- **Precarga.** `ContentProvider:PreloadAsync` con los efectos cortos al arrancar el cliente, para que el primer `recoger` no llegue tarde.
- **Recortes y bucles.** `PlaybackRegionsEnabled = true` + `PlaybackRegion` para cortar (fanfarrias largas, Bag Dull Sprinkling Impact) y `Looped` + `LoopRegion` para los bucles con arranque y parada (Conveyor Belt).
- **Que no se amontonen.** Como mucho 3 `recoger` a la vez; `denegado` con 0,3 s de espera; música a la mitad durante `rebirth` e `insignia`.
- **Duraciones.** Son las de la Creator Store, redondeadas. Algunas fichas de APM dicen más (p. ej. Winner "Bingo": ≈2 s en Roblox, 6 s en su ficha): comprobar `Sound.TimeLength` en Studio y recortar lo que sobre.
- **Sonoridad.** APM y Pro Sound Effects no vienen igualados: los volúmenes de esta tabla son de partida y hay que ajustarlos de oído, sobre todo la música frente a los efectos.

---

## 7. Lo que no encontré y dudas

1. **Bolsa de basura cartoon.** En la biblioteca con licencia solo hay foley realista de bolsas. Por eso `fallo` usa un golpe de dibujos.
2. **Silbato de émbolo que solo sube.** Los "Slide Whistle 1–7" de Pro Sound Effects se describen como frases de dibujos (pueden subir y bajar). Si se quiere el clásico ascendente para `carga`, escuchar Slide Whistle 3 ([9119197920](https://create.roblox.com/store/asset/9119197920)) y 7 ([9119198473](https://create.roblox.com/store/asset/9119198473)).
3. **El "¡ka-ching!" de caja registradora.** Los "Cash Register" con licencia son el cajón y el mecanismo, sin campanilla; por eso `cobro` va con monedas.
4. **Una subida pensada para bucle.** No hay; `carga` usa una subida de 1–2 s ajustada a 1,2 s.
5. **Bucles de música sin costuras.** Las pistas de APM tienen principio y final. La única hecha para bucle es la de Roblox (Roblox_UI_Loop_Calm_Music).
6. **Solo cuenta "Roblox".** Si se descartan APMOfficial y ProSoundEffects, se quedan sin candidato `tesoro`, `dentroGolpe`, `fallo`, `mejora`, `rebirth`, `regalo` y `musicaTurbo`. Para el resto hay opción de Roblox en las tablas.
7. **Descartados por la regla.** La mayoría de lo que sale al buscar "pop", "coin" o "cash register" es de otros creadores, y parte está sacado de otros juegos ("Slime Rancher - UI Notification Pop-Up", "Poppy Playtime alarm"). Tampoco he usado la música de DistroKid (cuenta `DistrokidOfficial`): la distribuye un socio, pero queda fuera de la regla pedida.
8. **La recompensa diaria aún no existe.** Llega con la economía v4 (calendario, regalos por minutos activos, regreso); `regalo` ya sirve hoy para los pedidos y el premio de Turbo.

---

## 8. Cómo se buscó (para repetirlo)

- MCP de Studio, `search_asset` (Creator Store, audio): solo lectura. No filtra por creador, así que sirvió para comprobar que los elegidos salen con su creador correcto.
- API pública de la Creator Store, solo lectura y sin sesión:
  - buscar por creador y duración: `https://apis.roblox.com/toolbox-service/v1/marketplace/3?keyword=<palabras>&creatorTargetId=<id>&creatorType=1&maxDuration=<s>` (Roblox = 1, APMOfficial = 7462718749, ProSoundEffects = 7462895450);
  - comprobar un candidato: `https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=<id1>,<id2>` (creador, duración, ficha, etiquetas, publicado y gratis).
- No se insertó nada en el place, no se ejecutó código en Studio, no se guardó ni se publicó.
