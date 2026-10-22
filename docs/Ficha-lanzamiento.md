# Ficha de lanzamiento — Recíclatas

> **Decisiones del usuario (22 oct 2026), mandan sobre las recomendaciones de abajo:**
> - **Nombre (variante con verbo):** es **Recíclatas: Lanza la Basura** · en **Recíclatas: Throw the Trash** · pt **Recíclatas: Jogue o Lixo**. Sustituye a "Garbage Collector".
> - **Servidores privados:** de pago, **50 Robux al mes**.
> - **Consola:** apagada al abrir (se activará tras una pasada de mando).
> - **Género:** Simulación → Simulador incremental (solo se puede cambiar cada 3 meses).
> - Icono: la propuesta 1 (`thumbnails/icon_512.png`).

> 22 oct 2026. Lo que se escribe en el Creator Dashboard para abrir el juego: nombre, descripción, género, dispositivos, servidores privados, icono y miniaturas, en **español (idioma fuente), inglés y portugués**. Usa la terminología del juego (`Config/Textos`, `Config/Traducciones/en` y `pt`) y solo promete lo que hay o lo que la economía v4 aprobada (`docs/Economia-v4.md`) añade antes de abrir; §2.6 dice de qué depende cada frase. Los recuentos de caracteres están comprobados.
>
> Pensada para las dos fases: primero solo jugadores verificados de 16+, después Roblox Select (9–15). Por eso la ficha no nombra nada de pago, no lleva enlaces ni urgencias y todo el texto es apto para todas las edades.

## Resumen

| Campo | Recomendación |
|---|---|
| Nombre (es, fuente) | **Recíclatas: Simulador de Reciclaje** |
| Nombre (en) | **Recíclatas: Trash Recycling Simulator** |
| Nombre (pt) | **Recíclatas: Simulador de Reciclagem** |
| Descripción | §2: es 942, en 890, pt 930 caracteres (límite 1.000) |
| Género | Simulation → Incremental Simulator |
| Dispositivos | ordenador, teléfono y tableta sí; consola y VR no, de momento |
| Servidores privados | sí, de pago, 50 Robux al mes |
| Idiomas | fuente español; inglés y portugués escritos a mano en Localization |
| Icono | `thumbnails/icon_512.png` (el elegido en I1a), sin texto |
| Miniaturas | 8, sin texto añadido; las que enseñan texto del propio juego, una por idioma (§4) |

**Supuestos** (si alguno falla, ver §2.6):
- Antes de abrir estará la economía v4 (Anexo A, tareas 1–8): calendario de 7 días, regalos por jugar y Turbo que solo corre jugando.
- Max players = 6 (CONTEXTO §5, pendiente de fijar).
- Español con el vocabulario del encargo ("móvil", "mando", que son de España); la variante latinoamericana está en §2.1.

---

## 1. Nombre

### 1.1 Marca: "Recíclatas" sí, "Garbage Collector" no

- **"Recíclatas" es como se llama el juego por dentro**: `GameConfig.NOMBRE_JUEGO` y la bienvenida en los tres idiomas ("¡Bienvenido a Recíclatas!", "Welcome to Recíclatas!", "Bem-vindo ao Recíclatas!"). Si la ficha dice otra cosa, el jugador entra en un juego con otro nombre.
- En español y en portugués se entiende sola (recicla + latas). Por eso el subtítulo puede dedicarse al género. En inglés no dice nada, así que su subtítulo lleva las tres palabras que se buscan.
- **"Garbage Collector" choca por tres lados**:
  1. Ya existe en Roblox *Garbage Collector Simulator* (2022, de otro estudio): basura que se recoge sola, mascotas y zonas, justo lo que este juego no tiene. Se confundirían en la búsqueda.
  2. "Garbage collector" es también un término de programación, lo que llena de ruido las búsquedas fuera de Roblox (YouTube, Google).
  3. No coincide con el nombre que el juego enseña dentro.
- **Cuándo cambiarlo: ahora, antes de abrir.** Roblox pide mantener el nombre estable porque, si se cambia después, quien lo buscaba por el anterior ya no lo encuentra. Hoy nadie lo busca como "Garbage Collector". El nombre interno del proyecto (`RecolectorGarbage`) puede quedarse.
- **La tilde**: "Recíclatas" con tilde en los tres idiomas, como en el juego. No sé si el buscador de Roblox ignora las tildes. Tras publicar, buscar "reciclatas" sin tilde desde otra cuenta. Si no sale, no es grave: las palabras clave del subtítulo hacen ese trabajo.

### 1.2 Propuestas (formato "Marca: subtítulo")

| Idioma | Opción | Nombre | Caract. | Por qué |
|---|---|---|---|---|
| es | **A, recomendada** | **Recíclatas: Simulador de Reciclaje** | 34 | Marca, género y tema: dos palabras que se buscan ("simulador", "reciclaje"), ninguna repetida, y un tono positivo para familias y Select. "Basura" va en la primera frase de la descripción: en un título, "simulador de basura" también se lee como "simulador malo". |
| es | B | Recíclatas: Lanza la Basura | 27 | Verbo + objeto, como los títulos que funcionan hoy en Roblox (*Grow a Garden*). Cuenta la mecánica que lo distingue (lanzar), pero pierde "simulador". |
| es | C | Simulador de Basura y Reciclaje | 31 | Solo palabras clave, sin marca. Es lo más buscable, pero es genérico, nadie lo recuerda y no coincide con el juego. Está para comparar; no la recomiendo. |
| en | **A, recomendada** | **Recíclatas: Trash Recycling Simulator** | 37 | En inglés la marca no se entiende, así que el subtítulo junta "trash", "recycling" y "simulator" en una frase natural, sin repetir ninguna. |
| en | B | Recíclatas: Throw the Trash | 27 | Verbo + objeto, corto, con el gancho del lanzamiento. Sin "simulator" ni "recycling". |
| en | C | Garbage Collector: Recycling Simulator | 38 | Conserva el nombre actual del Creator Hub. Tiene los tres choques de §1.1. |
| pt | **A, recomendada** | **Recíclatas: Simulador de Reciclagem** | 35 | Igual que en español. "Lixo" va en la primera frase de la descripción: "simulador de lixo" también se lee como "simulador ruim". |
| pt | B | Recíclatas: Jogue o Lixo | 24 | Verbo + objeto. Recuerda a "jogue o lixo no lixo", el lema brasileño contra tirar basura al suelo. Sin "simulador". |
| pt | C | Simulador de Lixo e Reciclagem | 30 | Solo palabras clave, sin marca (como la C en español). |

Si se prefiere el gancho del verbo, la B se cambia **en los tres idiomas a la vez**: el esquema tiene que ser el mismo en todos.

### 1.3 Reglas del nombre

- Como mucho 50 caracteres: caben todas, y la más larga tiene 38.
- Sin emojis, corchetes ni "[UPDATE]". Roblox tolera uno o dos emojis, pero no ayudan a encontrar el juego, y repetir palabras puede hundirlo en la búsqueda.
- Inglés y portugués se escriben **a mano** en Localization (§5). La traducción manual siempre gana a la automática, y Roblox presenta los títulos traducidos para que el juego se descubra en cada idioma.
- Cambiarlo una sola vez, ahora, y no volver a tocarlo.

---

## 2. Descripción

### 2.1 Cómo está hecha

- **Sigue el orden que recomienda Roblox** ("Game descriptions"):
  1. Gancho: las primeras ~160 letras son lo que se ve en el móvil sin desplegar y en los fragmentos de búsqueda.
  2. Novedades, breves, justo debajo. Así quien vuelve las ve sin bajar y no tapan el gancho.
  3. El bucle de juego.
  4. Una lista de lo que hay.
  5. La información práctica (controles).

  Los ganchos miden 134 (es), 137 (en) y 135 (pt) caracteres.
- **Límite: 1.000 caracteres.** Contando cada salto de línea como 1: es 942, en 890, pt 930. Son 17 saltos, así que aunque contaran como 2, ninguna pasa de 1.000. Quedan ~50 de margen para una línea de novedades más larga.
- **Lo que no lleva**:
  - ni enlaces;
  - ni hashtags: Roblox dice que no cuentan para el ranking y gastan caracteres;
  - ni emojis (los "•" no lo son);
  - ni precios, Robux, pases u ofertas;
  - ni prisas.
- **Controles**: Roblox desaconseja listarlos porque los enseña el tutorial. Van en tres líneas cortas porque hay tres formas de jugar. Si un día falta sitio, es lo primero que se recorta.
- **Glosario del juego**:
  - es: bolsa, contenedor, encestar, pedido, mejora, insignia, racha, patio.
  - en: bag, bin, score, order, upgrade, badge, streak, junkyard.
  - pt: saco, lixeira, acertar, pedido, melhoria, emblema, sequência, lixão.

  "Rebirth" y "Turbo" no se traducen.
- **Vocabulario regional**: "móvil", "tableta" y "mando" son de España. En Latinoamérica se dice "celular", "tablet" y "control". Roblox deja poner una variante **es-mx** del nombre y la descripción (es-es no, porque es el idioma fuente). Si se quiere, la variante cambia solo dos líneas:
  - `Celular y tablet: apunta y mantén los botones de recoger y lanzar`
  - `Control: X recoge, mantén Y para lanzar`

  Queda en 945 caracteres. Es opcional: obliga a actualizar dos descripciones en español en cada versión.

### 2.2 Español (942 caracteres)

```
¡Excava montañas de basura, llena tu bolsa y encéstala desde lejos! Un simulador de reciclaje donde separar por colores paga el doble.

NOVEDADES: ¡Ya abrimos el patio!

Recoge basura en el patio y lanza la bolsa llena a un contenedor: cuanto más lejos encestes, más ganas, y las rachas suman. Mejora tu bolsa, alcance, velocidad y brazo, y haz Rebirth para multiplicar lo que ganas.

• 5 contenedores de colores: en el de su color, la basura paga x2
• Billetes y tesoros escondidos en la basura
• Rebirths que abren la basura de metal y la orgánica
• 3 pedidos al día y Turbo: dinero x2 mientras juegas
• Calendario de 7 días (si faltas, te espera) y regalos por jugar
• Insignias y tablones de ranking semanales
• Diseños de bolsa y estelas
• Hasta 6 jugadores en el mismo patio

PC: clic recoge, mantén F para lanzar, V cambia la cámara
Móvil y tableta: apunta y mantén los botones de recoger y lanzar
Mando: X recoge, mantén Y para lanzar
```

### 2.3 English (890 caracteres)

```
Dig up mountains of trash, fill your bag and throw it into a bin from far away! A recycling simulator where sorting by color pays double.

WHAT'S NEW: The junkyard is open!

Pick up trash in the junkyard and throw your full bag into a bin: the farther you score, the bigger the bonus, and streaks add up. Upgrade your bag, reach, speed and arm, and Rebirth to multiply what you earn.

• 5 color bins: trash in its matching bin pays x2
• Cash and treasures hidden in the trash
• Rebirths unlock metal and organic trash
• 3 daily orders and Turbo: x2 money while you play
• 7-day calendar (it waits if you miss a day) and playtime gifts
• Badges and weekly leaderboards
• Bag designs and trails
• Up to 6 players in the same junkyard

PC: click to pick up, hold F to throw, V switches camera
Phone and tablet: aim and hold the pick up and throw buttons
Controller: X picks up, hold Y to throw
```

### 2.4 Português (930 caracteres)

```
Cave montanhas de lixo, junte tudo no saco e acerte a lixeira de longe! Um simulador de reciclagem onde separar por cores paga o dobro.

NOVIDADES: O lixão está aberto!

Pegue lixo no lixão e jogue o saco cheio numa lixeira: quanto mais longe acertar, maior o bônus, e as sequências somam. Melhore seu saco, alcance, velocidade e braço, e faça Rebirth para multiplicar o que ganha.

• 5 lixeiras coloridas: na da sua cor, o lixo paga x2
• Dinheiro e tesouros escondidos no lixo
• Rebirths que desbloqueiam o lixo de metal e o orgânico
• 3 pedidos por dia e Turbo: dinheiro x2 enquanto você joga
• Calendário de 7 dias (se faltar, ele espera) e presentes por jogar
• Emblemas e rankings semanais
• Estilos de saco e rastros
• Até 6 jogadores no mesmo lixão

PC: clique para pegar, segure F para jogar o saco, V muda a câmera
Celular e tablet: mire e segure os botões de pegar e de jogar
Controle: X pega, segure Y para jogar o saco
```

Notas sobre el portugués:
- Es de Brasil, como el juego, y va en la sección *Global* de portugués, así que lo ve también Portugal.
- "Jogar o saco" (y no solo "jogar") evita leer "segure F para jogar" como "mantén F para jugar".
- Se evita "encher o saco": en Brasil, coloquialmente, significa "fastidiar". El juego sí lo usa en `TUTORIAL.paso3` y `PATIO.bolsaNoLlena` de `pt.luau`; conviene revisarlo aparte (por ejemplo, "até o saco ficar cheio").

### 2.5 La línea de novedades

| es | en | pt |
|---|---|---|
| `NOVEDADES: ¡Ya abrimos el patio!` | `WHAT'S NEW: The junkyard is open!` | `NOVIDADES: O lixão está aberto!` |

En cada versión:
- **Una línea de 60 caracteres como mucho**, cambiada en los tres idiomas el mismo día que se publica. Plantilla:
  - `NOVEDADES (v1.1): <lo nuevo>`
  - `WHAT'S NEW (v1.1): …`
  - `NOVIDADES (v1.1): …`
- Solo lo que ya está en el juego publicado.
- Nada de fechas límite, "¡solo hoy!", precios ni ofertas: Roblox prohíbe las prisas falsas y pide no presionar a los menores (Economía v4 §5.7).
- Si lo que se anuncia tiene que seguir en la ficha, en la versión siguiente pasa a la lista.

### 2.6 Antes de pegarla: de qué depende cada frase

| Frase | Sistema | Hoy | Cómo comprobarlo | Si no está al abrir |
|---|---|---|---|---|
| Lanzar desde lejos da más; las rachas suman | `Lanzamiento`, `DefinicionesPunteria` | hecho | `bonusDistancia`, `racha` | — |
| "la bolsa llena" | solo se lanza llena (P3, 22 oct) | hecho | `lanzarBolsa` | — |
| 4 mejoras; Rebirth multiplica | `Mejoras`, `Rebirths` | hecho | `mejorasV2`, `renacer` | — |
| 5 contenedores, x2 en el suyo | `Contenedores`, `Bolsa.factorContenedor` | hecho | `pagoSeparado`, `lanzarATipo` | — |
| Billetes y tesoros | `GeneradorBotin` | hecho | `variedadBasura`, `tesoroGrande` | — |
| Rebirth abre metal y orgánico | `GameConfig.MATERIAL_REBIRTH` | hecho | `materialPorRebirth`, `contenedorBloqueado` | — |
| 3 pedidos al día | `Pedidos` | hecho | `pedidosDia` | — |
| Turbo "mientras juegas" | Turbo por tiempo jugado (v4 §4.6, tarea 3) | **pendiente** | `turboPausa` | es "Turbo: dinero x2 durante un rato" · en "Turbo: x2 money for a while" · pt "Turbo: dinheiro x2 por um tempo" |
| Calendario que espera; regalos por jugar | `Recompensas` (v4 §4.2–4.5, tarea 4) | **pendiente** | `calendario`, `regalosActivos` | quitar la línea en los tres idiomas |
| Insignias | `Insignias` | hecho (16; 20 con la v4) | `insignias` y Badges creados en el Dashboard | — |
| Tablones semanales | `Rankings` | hecho | `rankings`, `rankingsDatastore` | — |
| Diseños de bolsa y estelas | `Cosmeticos` | hecho (plateada, dorada, arcoíris; +5 con la v4) | `cosmeticoBolsa` | — |
| Hasta 6 jugadores | Max players del place | **pendiente** (CONTEXTO §5) | Studio → Game Settings → Places → Configure Place | cambiar el número |
| Controles táctiles | `ControlPatio` (ContextActionService) | hecho | `("botones")` **en un teléfono real**: en Studio de escritorio no se crean | — |

La descripción no da número de insignias: hoy son 16 y con la v4, 20. Así no hay que acordarse de cambiarla.

---

## 3. Género, dispositivos y servidores privados

### 3.1 Género

- **Simulation → Incremental Simulator.** Roblox define este subgénero como el de juegos en los que se progresa con acciones repetitivas sencillas que suben un contador, desbloqueando capacidades y niveles por el camino. Es exactamente el bucle: recoger, lanzar, cobrar, mejorar y hacer Rebirth.
- **Segunda opción**: Simulation sin subgénero, por si Roblox lo reclasifica.
- **Descartados**:
  - Physics Sim: la física adorna el juego, no es el objetivo.
  - Tycoon: no hay base ni negocio.
  - Idle: todo exige jugar.
- Se elige en el Creator Dashboard (Publish Settings › Game Details). **Solo se puede cambiar una vez cada tres meses**, y Roblox puede corregirlo si lo ve inexacto (avisa por correo).

### 3.2 Dispositivos (Game Settings → Basic Info → Playable Devices)

| Dispositivo | ¿Activar? | Por qué |
|---|---|---|
| Ordenador | **Sí** | Es la plataforma de referencia: clic recoge, F lanza, Q/R/P abren los paneles y V cambia la cámara. Todo está probado en Studio. |
| Teléfono | **Sí** | Botones táctiles de recoger y lanzar, la mira en el centro y el HUD táctil (`("hud")` sin solapes con la disposición táctil forzada). El mundo se aligeró para móvil (16 sep). La economía v4 ya cuenta con que el móvil va más lento (R1 en ~82 min, frente a 58). **Condición**: una partida en un teléfono real antes de abrir, porque los botones no se ven en Studio de escritorio. |
| Tableta | **Sí** | Lo mismo que el teléfono, con más pantalla. Probar en una. |
| Consola | **No, de momento** | Hay acciones de mando: X recoge y excava, Y lanza, B cierra, y cada panel selecciona su primer botón. Pero no hay atajo de mando para abrir Tienda, Pedidos o Rebirth ni para cambiar la cámara (solo Q/R/P/V y los botones del HUD). Las guías de consola de Roblox piden una interfaz que se maneje con la cruceta por defecto, legible en una tele, y la ventana de chat apagada en consola. Una mala primera partida en consola baja el compromiso medio justo en la fase 16+, que necesita 250 partidas de jugadores muy comprometidos. |
| VR | **No** | La primera persona con manos dibujadas en 2D, la mira y los botones no están pensados para VR ni se han probado. |

El mando conectado a un PC funciona aunque la consola esté apagada: por eso la descripción lista sus controles.

Pasada de mando para activar la consola más adelante:

| # | Agente | Tarea | Terminado cuando |
|---|---|---|---|
| 1 | `roblox-dev` | Atajos de mando: la cruceta abre Tienda, Pedidos y Rebirth, y un botón cambia la cámara | cada panel se abre y la vista cambia sin teclado ni cursor virtual |
| 2 | `roblox-dev` | Ventana de chat apagada en consola (TextChatService) | en consola no aparece la ventana de chat |
| 3 | `roblox-dev` | HUD y paneles legibles en una tele (`ViewportDisplaySize` Large, zona segura) | captura a 1920×1080 sin nada importante fuera de la zona segura |
| 4 | usuario | Probar en una Xbox o una PlayStation y activar Console | el tutorial de 8 pasos completo solo con mando |

### 3.3 Servidores privados

**Sí, de pago: 50 Robux al mes.** Se activan en Audience → Access Settings → *Allow private servers* + *Requires Robux*, y solo con la experiencia ya pública.

- **De pago y no gratis.** Los suscriptores de Roblox Plus tienen los servidores privados de pago sin coste, y el juego cobra hasta 100 Robux al mes por cada uno según el tiempo que pasen en ellos; uno gratis no genera eso. Además, en las primeras semanas habrá pocos jugadores, y el patio compartido es más divertido con gente: un precio pequeño evita vaciar los servidores públicos.
- **Por qué 50.** Es el escalón más bajo del catálogo (Turbo 15 cuesta 49) y lo pueden pagar un grupo de amigos o unos hermanos.
- **Acertar el precio a la primera.** Cambiarlo después cancela todas las suscripciones activas.
- **Menores de 13.** Puede que no entren, según sus controles parentales, así que la descripción no los anuncia.
- **Sin riesgos de reglas.**
  - Los comandos de admin no se abren al dueño de un servidor privado: `Admin.esAdmin` solo acepta al creador y Studio.
  - Jugar solo o con amigos da algo más de patio por cabeza. No rompe la economía, porque los premios dependen de la propia progresión.
  - Los tablones son globales.

Alternativas: gratis (más social, sin ingresos de Plus) o apagados hasta salir de la fase 16+.

### 3.4 Madurez (para llegar a Select)

- Completar el **cuestionario entero**, no solo la primera pregunta. Sin él, la etiqueta es *Content May Vary* y el juego solo llega a 16+. Para Select hace falta completo.
- Contestar con lo que hay:
  - sin violencia, sangre, miedo, lenguaje fuerte ni romance;
  - compras con Robux, pero ninguna al azar;
  - el chat de texto estándar de Roblox.

  Lo esperable es la etiqueta más baja (*Minimal*). Los requisitos de Select (cuenta verificada, verificación en dos pasos, tarifa reembolsable o suscripción) están en Economía v4 §5.7.

---

## 4. Icono y miniaturas

### 4.1 Reglas

- **Formatos**: icono de 512×512, ya hecho. Miniaturas en 16:9 a 1920×1080, hasta 10 entre imágenes y vídeos.
- **Sin texto añadido** (decisión del usuario; Roblox además prohíbe el texto promocional en las miniaturas). El texto que sale del propio juego (la celebración, los carteles, los paneles) sí puede aparecer, y entonces la miniatura se captura **en cada idioma**:
  1. En Edit, poner `IdiomaStudio = "en"` (o `"pt"`) en `ReplicatedStorage`, antes de Play, y quitarlo después.
  2. Subir esas versiones en Localization → idioma → Information.
  3. Subir la serie completa de 8 en cada idioma, en el mismo orden; las que no llevan texto se repiten.
- **Encuadre**:
  - Nada importante en la franja de abajo: el contador de jugadores la tapa.
  - Interfaz oculta salvo en las miniaturas que tratan de ella.
  - Nada que no esté en el juego. Nada de pago en primer plano: ni la pestaña Pases ni la Bolsa dorada o la Estela arcoíris. Lo que se enseña es lo que se gana jugando.
- **Texto alternativo**: cada miniatura lleva uno (accesibilidad, pestaña Experience Detail Page). Son los "captions" de §4.3. Si ese campo no se puede traducir, va en español.
- **Prueba A/B**: la de Home pide de 2 a 5 miniaturas activas. Empezar con la 1, la 2 y la 3, que son el bucle.

### 4.2 Icono

`thumbnails/icon_512.png`: la bolsa azul atada con el cincho amarillo sobre un fondo naranja de rayos, rodeada de basura de los cuatro colores (caja, botella, lata, manzana). No lleva texto y se reconoce en pequeño. Texto alternativo:
- es: "Bolsa de basura azul atada, rodeada de basura de colores: una caja, una botella, una lata y una manzana."
- en: "A tied blue trash bag surrounded by colorful trash: a box, a bottle, a can and an apple."
- pt: "Saco de lixo azul amarrado, cercado de lixo colorido: uma caixa, uma garrafa, uma lata e uma maçã."

### 4.3 Las 8 miniaturas, en orden

Capturas con `screen_capture` (MCP) o desde Studio a 1920×1080. Las posiciones de cámara son las de "Verificar" en `CLAUDE.md`.

**1. El lanzamiento (portada)**
- **Qué se ve**: tercera persona (`("camara", "tercera")`), a unos 45–60 m de los contenedores. La bolsa llena va en el aire con su línea de trayectoria (sale en los cinco primeros lanzamientos), y delante está la montaña de basura de colores.
- **Idiomas**: una para los tres, con la interfaz oculta.
- **Texto alternativo**:
  - es: "Un jugador lanza su bolsa de basura desde el patio hacia los contenedores de colores."
  - en: "A player throws a bag of trash from the junkyard toward the colored bins."
  - pt: "Um jogador joga o saco de lixo do lixão em direção às lixeiras coloridas."

**2. "¡DENTRO!"**
- **Qué se ve**: la celebración sobre un contenedor de color: las letras grandes de su color, el dinero contando, las píldoras de distancia y racha, y los destellos con el anillo. Se dispara con `("celebracion", "Papel")` o con un acierto real.
- **Idiomas**: una por idioma ("¡DENTRO!", "SCORED!", "ACERTOU!").
- **Texto alternativo**:
  - es: "La bolsa entra en el contenedor de papel: aparece ¡DENTRO! y el dinero ganado."
  - en: "The bag lands in the paper bin: SCORED! appears with the money earned."
  - pt: "O saco cai na lixeira de papel: aparece ACERTOU! com o dinheiro ganho."

**3. Los cinco contenedores**
- **Qué se ve**: desde la plaza (8, 12, 100) mirando a (8, 3, 128): los cuatro de color, cada uno con su trituradora, y el general azul de la recicladora.
- **Idiomas**: una por idioma, por los carteles ("PAPEL · x2"). Antes hay que re-hornear el mundo para que las placas se traduzcan (CONTEXTO §5.6).
- **Texto alternativo**:
  - es: "Los cinco contenedores: papel celeste, plástico amarillo, metal gris, orgánico verde y el general azul."
  - en: "The five bins: light blue paper, yellow plastic, gray metal, green organic and the blue general bin."
  - pt: "As cinco lixeiras: papel azul-claro, plástico amarelo, metal cinza, orgânico verde e a geral azul."

**4. Varios jugadores**
- **Qué se ve**: de 4 a 6 avatares reales (cuentas propias o amigos, con su permiso; en el place publicado o con Team Test) en el patio. Uno excava una montaña grande donde brilla un tesoro, otro recoge y otro carga un lanzamiento.
- **Idiomas**: una para los tres, con la interfaz oculta.
- **Texto alternativo**:
  - es: "Varios jugadores excavan, recogen y lanzan basura en el mismo patio; entre la basura brilla un tesoro."
  - en: "Several players dig, pick up and throw trash in the same junkyard; a treasure glows in the pile."
  - pt: "Vários jogadores cavam, pegam e jogam lixo no mesmo lixão; um tesouro brilha no meio do lixo."

**5. La tienda: mejoras**
- **Qué se ve**: el panel de la tienda en la pestaña Mejoras (las cuatro barras de 10 cuadros), con la caseta y el reciclador detrás. Nunca la pestaña Pases.
- **Idiomas**: una por idioma.
- **Texto alternativo**:
  - es: "La tienda de la caseta: mejoras de bolsa, alcance, velocidad y brazo."
  - en: "The shed shop: bag, reach, speed and arm upgrades."
  - pt: "A loja da cabana: melhorias de saco, alcance, velocidade e braço."

**6. Estilo**
- **Qué se ve**: tres jugadores con diseños de bolsa distintos de los que se ganan jugando: la plateada del Rebirth 3 y, con la v4, la de hielo, la de cartón y una bolsa en vuelo con la estela de fuego.
- **Idiomas**: una para los tres, sin interfaz.
- **Texto alternativo** (si la estela de fuego aún no existe, quitar la segunda parte):
  - es: "Tres jugadores con bolsas de diseños distintos; una vuela dejando una estela de fuego."
  - en: "Three players with different bag designs; one bag flies with a fire trail."
  - pt: "Três jogadores com sacos de estilos diferentes; um voa com um rastro de fogo."

**7. Rebirth**
- **Qué se ve**: el panel de Rebirth con la barra llena ("Desbloquea la basura de metal", "Tu dinero pasa a x1,5") y, al fondo, el contenedor de metal con su candado "REBIRTH 1".
- **Ojo**: desde el 5 oct no hay zonas ni barreras. Lo que abre un rebirth son tipos de basura y sus contenedores, así que la imagen no debe enseñar zonas.
- **Idiomas**: una por idioma.
- **Texto alternativo**:
  - es: "El panel de Rebirth: con las 4 mejoras al máximo, multiplicas lo que ganas y abres la basura de metal."
  - en: "The Rebirth panel: with all 4 upgrades maxed, you multiply what you earn and unlock metal trash."
  - pt: "O painel de Rebirth: com as 4 melhorias no máximo, você multiplica o que ganha e libera o lixo de metal."

**8. Tablones de ranking**
- **Qué se ve**: los tres tablones de la plaza (x 41, z 74/89/104), desde el punto de aparición mirando al este.
- **Ojo**: enseñan nombres y caras reales. Capturarlos con datos de cuentas propias o con permiso, y nunca con la cuenta del creador si ha usado `/dar dinero` en el juego publicado: `Economia.ganar` lo suma a "Dinero ganado".
- **Idiomas**: una por idioma.
- **Texto alternativo**:
  - es: "Los tablones de ranking de la plaza: dinero ganado, racha máxima y bolsas encestadas, histórico y de la semana."
  - en: "The plaza leaderboards: money earned, best streak and bags scored, all time and this week."
  - pt: "Os rankings da praça: dinheiro ganho, maior sequência e sacos acertados, geral e da semana."

Por qué este orden:
- 1 a 3 son el bucle: qué haces, la sensación de acertar y el giro de separar.
- 4 es el juego compartido.
- 5 a 7, la progresión.
- 8, la competición.

### 4.4 Vídeo (opcional, después de abrir)

- **Qué**: 20–30 s solo de juego: excavar, recoger, la bolsa que se cierra, lanzar desde lejos, "¡DENTRO!" y los cinco contenedores.
- **Reglas de Roblox para vídeos**: sin voz, sin música con letra y sin texto promocional.
- **Límites**: 3 subidas al mes, y no se ve en Xbox, PlayStation ni VR. Si se aprueba, sale el primero en la página del juego.

---

## 5. Dónde va cada cosa

1. **Idioma fuente.** Creator Dashboard → la experiencia → Audience → Localization → Languages. Comprobar que el idioma fuente es **Español** (por defecto es el de la cuenta) y añadir **English** y **Portuguese**. **No** activar Automatic Text Capture (CONTEXTO §3 "Idiomas").
2. **Español.** Nombre y descripción en español en los ajustes de la experiencia, junto con el género (§3.1), el icono y las 8 miniaturas (orden y texto alternativo en Experience Detail Page).
3. **Inglés y portugués.** Translate → English → pestaña **Information**: Name, Description y las miniaturas con texto → Save. Lo mismo con Portuguese.
4. **Productos.** Translate → idioma → pestaña **Products**: los pases, el producto y las insignias, con los textos de `Config/Traducciones/{en,pt}.luau` (sección `DEF`) y los nuevos de Economía v4 §6.1 cuando existan.
5. **Dispositivos y jugadores.** Studio → Game Settings → Basic Info → Playable Devices (§3.2), y Places → Configure Place → Max players = 6.
6. **Servidores privados.** Audience → Access Settings → Allow private servers + Requires Robux = 50, con la experiencia ya pública.
7. **Enlaces sociales**: ninguno por ahora.
8. **Comprobar** con una cuenta en inglés y otra en portugués (Settings → Language) que salen el nombre y la descripción escritos a mano.

Los demás idiomas (francés, alemán…): Roblox traduce solo el nombre y la descripción a quien tenga activada la traducción automática, y dentro el juego les sale en español (la caída de `Utilidades/Idioma`). Si se prefiere que caigan al inglés, es un cambio de código aparte; no afecta a esta ficha.

---

## 6. Preguntas para el usuario

1. **Nombre.** ¿Cambiamos ya "Garbage Collector" por *Recíclatas: Simulador de Reciclaje* / *Trash Recycling Simulator* / *Simulador de Reciclagem*? ¿O prefieres la variante del verbo (*Lanza la Basura* / *Throw the Trash* / *Jogue o Lixo*)?
2. **Servidores privados.** ¿De pago a 50 Robux al mes (mi propuesta), gratis, o apagados hasta salir de la fase 16+?
3. **Consola.** ¿La dejamos apagada al abrir (mi propuesta), o encargamos antes la pasada de mando de §3.2 a `roblox-dev`?

---

## Fuentes

- Roblox Creator Hub, [Experience genres](https://create.roblox.com/docs/production/publishing/experience-genres): taxonomía, definición de Incremental Simulator, un cambio cada tres meses.
- Roblox Creator Hub, [Game descriptions](https://create.roblox.com/docs/production/publishing/descriptions): gancho de 160 caracteres, límite de 1.000, sin hashtags, no listar controles, apto para todas las edades.
- Roblox Creator Hub, [Publish experiences and places](https://create.roblox.com/docs/production/publishing/publish-experiences-and-places): nombre estable, sin repetir palabras, uno o dos emojis como mucho.
- Roblox Creator Hub, [Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails): 16:9 a 1920×1080, hasta 10, texto alternativo, franja de abajo, prueba A/B con 2–5, reglas de los vídeos.
- Roblox Creator Hub, [Add translations](https://create.roblox.com/docs/production/localization/add-translations): pestañas Information y Products, imágenes por idioma, variantes regionales (es-mx; es-es no si el español es la fuente).
- Roblox Creator Hub, [Localization](https://create.roblox.com/docs/production/localization): la traducción manual siempre gana a la automática.
- Roblox DevForum, [Localized Game Titles and Descriptions](https://devforum.roblox.com/t/localized-game-titles-and-descriptions/206555): los títulos traducidos son para que el juego se descubra en cada idioma.
- Roblox Creator Hub, [Private servers](https://create.roblox.com/docs/production/monetization/private-servers): gratis o de pago, Roblox Plus (hasta 100 Robux por suscriptor al mes), cambiar el precio cancela las suscripciones, menores de 13.
- Roblox Creator Hub, [Console guidelines](https://create.roblox.com/docs/production/publishing/console-guidelines): navegación con la cruceta, interfaz para tele, chat apagado en consola, información de madurez.
- Roblox Creator Hub, [Experience settings](https://create.roblox.com/docs/en-us/studio/experience-settings.md): Playable Devices, Max players.
- Roblox Creator Hub, [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select): fase 16+, 250 partidas en 60 días, cuestionario completo.
- Pro Game Guides, [Garbage Collector Simulator codes](https://progameguides.com/roblox/roblox-garbage-collector-simulator-codes/): existe un juego de Roblox con ese nombre.
