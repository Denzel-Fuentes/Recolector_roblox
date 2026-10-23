# Recíclatas — el juego tal como se juega hoy

Este documento describe **solo lo que el jugador ve y puede hacer** en la versión actual (23 oct 2026, con K1 ya unido), para quien escriba textos del juego o de la ficha, o guíe a probadores. No habla de cómo está construido por dentro (eso es `CONTEXTO.md`). Si algo no está aquí, no es jugable todavía. Los números salen de `src/ReplicatedStorage/Shared/Config` y de la economía v4 (`docs/Economia-v4.md`); si alguno no coincide, manda Config. El copy exacto está en `Config/Textos.luau` (y en inglés y portugués en `Config/Traducciones`, con su glosario en la cabecera).

> Hasta el 22 oct este documento describía el juego anterior a la v2 (mascotas, energía, bases, gemas, trajes). Todo eso se quitó: ver CONTEXTO §3 "Diseño v2" y "Lanzamiento: v3".

---

## 1. En una frase

Excavas montañas de basura en un patio compartido, llenas tu bolsa y la **lanzas** a uno de cinco contenedores: cuanto más lejos encestas, más ganas, y si separas la basura por colores, paga el doble. Con el dinero mejoras tu bolsa, tu alcance, tu velocidad y tu brazo, y haces **Rebirth** para multiplicar lo que ganas.

### El bucle

1. **Excavar** una colina del patio: se convierte en una montaña de basura de verdad.
2. **Recoger** piezas con la mira hasta llenar la bolsa. Recoger no paga nada.
3. **Lanzar** la bolsa llena a un contenedor (o entregarla a mano, sin bonus de lanzamiento).
4. **Cobrar**: el dinero *solo* sale del contenedor.
5. **Mejorar** en la tienda y, con todo al máximo y el dinero del requisito, **renacer**.
6. Por el camino: **pedidos** del día, **recompensas** por volver y por jugar, **insignias** y **tablones de ranking**.

Vocabulario fijo: patio, montón, bolsa, contenedor, encestar, pedido, mejora, insignia, racha; "Rebirth", "Turbo" y "VIP" no se traducen. Las distancias se enseñan en **m** (son studs).

---

## 2. Al entrar

- Una **pantalla de carga** (los cinco contenedores saltando y consejos) tapa el juego hasta que llega tu progreso; si tarda más de 8 s dice "Cargando tu progreso…".
- Apareces en la **plaza**, mirando al patio (también al morir). Bienvenida: *"¡Bienvenido a Recíclatas! Excava un montón del patio y lanza la bolsa a un contenedor. Si separas por colores, pagan el doble."*
- Si el progreso no se pudo cargar, se avisa: *"No se pudo cargar tu progreso. Esta sesión no se guardará."* Si la partida se abre en otro servidor, este te echa: *"Tu partida se abrió en otro servidor. Vuelve a entrar para seguir jugando."*
- El **tutorial** es una píldora arriba a la izquierda ("Paso 3/8 · …") con una flecha en el mundo. Los 8 pasos: ir al patio · excavar un montón · llenar la bolsa · lanzarla al contenedor azul · comprar una mejora · separar (recoger un solo color y lanzarlo a su contenedor) · cumplir un pedido · la meta del Rebirth 1. Avanza solo con lo que haces.
- Desde la primera mejora (paso 5), si hay algo que cobrar, el panel **Recompensas** se abre solo al entrar; tras 3 días o más sin jugar, antes sale la ventana de regreso (§10).

---

## 3. Controles

| | PC | Móvil y tableta | Mando |
|---|---|---|---|
| Recoger | **mantener el clic** con la mira sobre la basura | apuntar con la mira (arrastrar gira la cámara) y mantener **RECOGER** | mantener **X** |
| Lanzar (con la bolsa llena) | **mantener F** y soltar | mantener **LANZAR** y soltar | mantener **Y** y soltar |
| Excavar, reciclar a mano, tienda | **E** en el aviso del mundo (excavar se mantiene 1,5 s) | tocar el aviso | el botón que enseña el aviso |
| Cerrar un panel | **Esc** | la X | **B** |

- **Cámara**: primera persona en todo el mapa, con un punto de mira en el centro (un anillo crece cuando hay algo al alcance). **V** o el botón Cámara pasan a **tercera persona** sobre el hombro; se recuerda para la próxima vez.
- **Botonera** (a la izquierda; en táctil, arriba a la izquierda), con su tecla: **Q** (o T) Tienda · **R** Rebirth · **P** Pedidos · **V** Cámara · **M** Sonido · **G** Recompensas (con un punto rojo si hay algo por cobrar). En PC el ratón está bloqueado al centro mientras no hay un panel abierto, así que los paneles se abren con la tecla.
- En el patio ves tus manos con la bolsa abierta; llena, se cierra con un nudo. Los demás te ven con los brazos extendidos y la bolsa.

---

## 4. El mundo

Una valla de madera rodea todo el mapa. De norte a sur:

- **El patio de basura**: un rectángulo de 97,5 × 150 m dividido por caminos en 6 cuadrantes (2 columnas × 3 filas), todos abiertos. Cada cuadrante tiene **2 montones chicos y 1 grande** (18 en total).
- **La plaza**, donde se aparece. En el césped del este, los **3 tablones de ranking** (§12).
- **La recicladora**: la caseta-tienda **SHOP** (dos contenedores apilados, menta y coral) con el tendero tras el mostrador (aviso "Tienda · Reciclador"); el **contenedor general azul**, el volquete de la recicladora grande con su trituradora y su cinta; y, en fila al este, los **4 contenedores de color**, cada uno con su trituradora pequeña. Cada depósito pone en marcha la cinta y la trituradora de su contenedor, y lo ven todos.

---

## 5. El patio y los montones

| Montón | Cuántos | Piezas al excavar |
|---|---|---|
| Chico | 12 | 20 |
| Grande | 6 | 60, con un **tesoro seguro** |

- Junto a una colina, mantén E en **"Excavar"** 1,5 s: la colina se convierte en una montaña de basura que cae con física; las piezas quietas son sólidas y la montaña se puede escalar.
- Cada pieza es **basura** (94 %), un **billete** (5 %, verde con destellos) o un **tesoro** (1 %, violeta brillante, "¡TESORO!").
- La basura es del **color de su tipo**: papel celeste, plástico amarillo, metal gris plomo, orgánico verde. Con 0 rebirths solo salen papel y plástico; el **Rebirth 1** abre el metal y el **2** el orgánico. Nadie recoge una pieza de un tipo que aún no tiene, aunque la saque otro (burbuja "Metal: Rebirth 1").
- **Prioridad del excavador**: durante 10 s solo recoge quien excavó ("Espera 6 s: es de Ana").
- **Un montón a medias por jugador**: para abrir otro hay que recoger el 75 % del tuyo ("Termina tu montón primero"). Con demasiada basura suelta en el patio no se excava ("Patio lleno: espera un poco").
- Las piezas no caducan. Un montón que baja del 25 % vuelve a ser colina a los 45 s.
- Recoger: solo con la mira y dentro de tu **alcance** (6 m de base). La pieza vuela a tu bolsa y sale un **"+1"** ("+1 $" un billete). Pasar por encima no recoge nada.

---

## 6. La bolsa, el lanzamiento y los contenedores

- Capacidad: **10 piezas**, +3 por nivel de la mejora Bolsa (40 al máximo; +10 con el pase Bolsa XL). Todo ocupa un hueco, billetes y tesoros incluidos. En el HUD, la barra **Bolsa** se llena sin números y dice **"¡LLENA!"** en rojo.
- **Lanzar**: solo con la bolsa **llena**. Mantén F para cargar la fuerza (1,2 s llega al alcance de tu **Brazo**: 25 m de base, 70 al máximo) y suelta; la bolsa entera vuela hacia la mira. Hay que estar a más de 6 m del contenedor ("Aléjate un poco para lanzar"). Los 5 primeros lanzamientos llevan una **línea de ayuda**, y el **primero siempre entra**.
- **Si entra**: celebración **"¡DENTRO!"** con el dinero contando, la distancia, el bonus y la racha.

  | Distancia al contenedor | Bonus |
  |---|---|
  | menos de 10 m | — |
  | 10–19 m | +20 % |
  | 20–29 m | +40 % |
  | 30–44 m | +70 % |
  | 45–59 m | +100 % |
  | 60 m o más | +150 % |

  Más la **racha**: +10 % por cada acierto seguido, hasta +50 %. Batir tu récord de distancia (o el del servidor) saca la tarjeta **"¡NUEVO RÉCORD!"**; el del servidor sale también en el feed de los demás.
- **Si falla**: la racha vuelve a 0 y la bolsa queda en el suelo con todo dentro, con "Bolsa de Ana" y una cuenta atrás encima: **30 s solo para su dueño**, después **"¡LIBRE!"** y se la queda quien la recoja (al dueño le llega "Luis se llevó tu bolsa"). Si queda en alto, baja junto al contenedor. Como mucho **3 bolsas caídas** por jugador: con la cuarta, la más vieja se recicla sola, sin bonus y a mitad de precio.
- **Entregar a mano**: E en "Reciclar bolsa" junto a un contenedor. Celebración **"¡RECICLADO!"**; sin bonus de distancia ni de racha (el de separar sí).
- **Los cinco contenedores** ("PAPEL · x2", "GENERAL · TODO"): en el de su color, cada pieza de basura paga **x2**; en el de otro color, **x0,5**; en el **general**, x1. Billetes y tesoros pagan lo suyo en cualquiera. La bolsa entera va al contenedor donde cae. Los de **metal** y **orgánico** están cerrados con un candado ("REBIRTH 1", "REBIRTH 2") hasta tener su rebirth: la bolsa rebota en la tapa.
- **Al salir del juego**, lo que llevas en la bolsa, tus bolsas caídas y las que estén en el aire se cobran para ti, sin bonus.

---

## 7. El dinero

| Pieza | Paga |
|---|---|
| Papel | $5 |
| Plástico | $7 |
| Metal | $15 |
| Orgánico | $25 |
| Billete | 6 piezas de su tipo |
| Tesoro | 40 piezas de su tipo |

Pago de una bolsa = el valor de sus piezas (con el x2 / x0,5 de separar) × (1 + bonus de distancia + racha) × el multiplicador del rebirth, × 2 con el pase **Dinero x2** y × 2 con **Turbo**. La primera bolsa (10 piezas al general, sin bonus) ronda los **$97**.

- **Turbo**: dinero x2 durante unos minutos de **juego**, que se suman si llega otro; el HUD enseña "x2 7:30". Se gana con los pedidos y las recompensas y se compra (§11). Solo corre mientras juegas: tras 2 min sin hacer nada (o fuera del juego) se pone en pausa ("x2 en pausa", en gris) y lo que queda se guarda para la siguiente vez; al entrar empieza en pausa y arranca con lo primero que hagas. En pausa la bolsa sigue pagando x2.
- Los premios en dinero (pedidos, calendario, regalos, regreso) **no** los multiplican ni los pases ni el Turbo.

---

## 8. Mejoras (la Tienda, pestaña Mejoras)

Cuatro mejoras de 10 niveles; en la tienda el nivel es una barra de 10 cuadros, sin números de alcance ni de velocidad.

| Mejora | Qué hace | Nivel 0 → 10 | Nivel 1 | Nivel 10 | Las 10 |
|---|---|---|---|---|---|
| Bolsa | cabe más basura | 10 → 40 piezas | $150 | $2.234 | $8.189 |
| Alcance | recoge desde más lejos | 6 → 16 m | $120 | $1.787 | $6.551 |
| Velocidad | corre más rápido | 16 → 28 | $200 | $2.979 | $10.918 |
| Brazo | lanza más lejos | 25 → 70 m | $180 | $2.681 | $9.827 |

Las 4 al máximo: **$35.485**. Cada nivel cuesta 1,35 veces el anterior.

---

## 9. Rebirth

Con las **4 mejoras al máximo** y el **dinero del requisito en mano**, el botón **Renacer** reinicia el dinero y las mejoras y sube para siempre tu multiplicador de dinero. Te quedas los tipos de basura abiertos, los récords, las insignias, los cosméticos y los pases.

| Rebirth | En mano | Tu dinero vale | Además |
|---|---|---|---|
| 1 | $15.000 | x1,5 | abre la basura de metal (y su contenedor) |
| 2 | $100.000 | x2 | abre la basura orgánica (y su contenedor) |
| 3 | $250.000 | x3 | regala la Bolsa plateada |
| 4 | $500.000 | x4 | regala la Bolsa de hielo |
| 5 | $800.000 | x5 | regala la Estela de fuego y la insignia Reciclador de élite |
| 6–9 | $1,2M · 1,8M · 2,5M · 3,5M | x6 … x9 | solo sube el multiplicador |
| 10 | $5M | x10 | la insignia Leyenda del reciclaje |
| 11 y más | ×1,4 cada uno | +1 cada uno | solo multiplicador |

Un jugador medio llega al Rebirth 1 hacia la **hora de juego** (calculado, falta medirlo con jugadores). El panel enseña el requisito, una barra y lo que abre el siguiente; bajo el botón Rebirth del HUD hay una barrita de progreso.

---

## 10. Pedidos y recompensas

### Pedidos del día (panel Pedidos, P)

Se abren al comprar la primera mejora. Cada día hay **3 pedidos**, el primero de puntería, elegidos entre:

| Pedido | Dificultad |
|---|---|
| Encesta 10 bolsas | media |
| Consigue una racha de 5 | difícil |
| Encesta 3 desde N m o más (según tu Brazo) | media |
| Recicla 150 piezas | media |
| Recicla 40 piezas en su contenedor de color | fácil |
| Recicla 40 de (un tipo que ya tienes) | media |
| Encuentra 3 tesoros | media |
| Recicla 5 bolsas llenas | fácil |

Se cobran solos al cumplirse ("¡Pedido cumplido! +$1.000"). Pagan el **1,5 % (fácil), 2 % (medio) o 3 % (difícil)** de lo que cuesta tu siguiente rebirth: con 0 rebirths, $760 / $1.000 / $1.500; con 1, $2.000 / $2.700 / $4.100. Los tres del día dan además **10 min de Turbo**. Con el pase **VIP** sale un **Pedido VIP** más (dorado, con corona), que paga como difícil. Los pedidos cambian cada día a las **06:00 UTC** (madrugada en América, mañana en España). El HUD enseña bajo el dinero el pedido más avanzado ("Separa 12/40").

### Recompensas (panel Recompensas, G)

Se abren con la primera mejora. Todo premio en dinero es un porcentaje de lo que cuesta tu siguiente rebirth (con 0 rebirths, 1 % = $500).

- **Calendario** de 7 casillas, una por **día jugado**, con botón **Reclamar**: 2 % · 2 % · Turbo 10 min · 3 % · 3 % · Turbo 15 min · 4 %. Si un día no juegas, **no pierdes nada**: la casilla te espera. La 7.ª da la insignia **Constante**, que regala la Bolsa de cartón (se pone en Estilo); desde la segunda semana, la 7.ª suma Turbo 15 min.
- **Regalos por jugar**, que se dan solos según los minutos que llevas jugando **hoy** (cuentan los minutos en los que recoges, lanzas o excavas, también entre varias sesiones del mismo día): a los 5, 10, 20, 30, 45 y 60 min, 0,5 % · 0,5 % · 1 % · Turbo 5 min · 1 % · 2 %.
- **Bono de regreso**, al volver tras 3 días o más sin jugar: Turbo 15 min + 4 % (tras 14 días, Turbo 30 min + 8 %), con la ventana *"¡Qué bien verte otra vez!"*.

---

## 11. La Tienda ("Caseta de reciclaje", Q)

Se abre con Q (o T), con el botón Tienda o en el aviso del tendero. Tres pestañas:

- **Mejoras** (§8).
- **Pases** (Robux), creados en Roblox el 23 oct: cada tarjeta lleva su botón de compra con el precio que dice Roblox (el de la tabla si no responde). Arriba van el Pack de inicio ("Compra única"; al comprarlo baja al final) y el VIP; debajo de los pases, "El Turbo solo corre mientras juegas". Con 3 h de Turbo guardadas, los Turbo no se pueden comprar y la fila dice por qué.

  | Pase o producto | Robux | Da |
  |---|---|---|
  | Pack de inicio (compra única) | 99 | 30 min de Turbo una vez y la Bolsa del reciclador |
  | Dinero x2 | 199 | todo lo que reciclas paga el doble, para siempre |
  | Bolsa XL | 149 | 10 huecos más en la bolsa, para siempre |
  | VIP | 249 | la Estela VIP, un pedido más cada día, una corona sobre la cabeza (la ven todos; la tuya no en primera persona) y [VIP] delante de tu nombre en el chat |
  | Estela arcoíris | 99 | tu bolsa deja un arcoíris al lanzarla |
  | Bolsa dorada | 99 | una bolsa de oro |
  | Turbo 15 min / 60 min | 49 / 149 | dinero x2 ese tiempo, sumado al que te quede |

- **Estilo**: diseños de la bolsa (en las manos, lanzada y caída) y estelas al lanzarla. Bolsas plateada (Rebirth 3), de hielo (Rebirth 4), de cartón (insignia Constante), del reciclador (Pack de inicio) y dorada (pase); estelas arcoíris (pase), de fuego (Rebirth 5) y VIP (pase VIP). Solo se ven: no dan ventaja.

Nada de lo que se vende es aleatorio ni hace el trabajo por ti, y no se vende dinero ni rebirths. Cada cosa de Estilo dice de dónde sale; las del Pack y del VIP no se venden sueltas.

**Ofertas**: de vez en cuando, en un momento tranquilo (sin panel abierto, sin celebración ni lanzamiento a medias), sale una ventana con algo de la tienda y dos botones iguales, "Comprar" y "Ahora no" (tres con el Turbo: 15 min, 60 min y "Ahora no"). Nunca en la primera sesión, ni antes del primer pedido del tutorial, ni en los 3 primeros minutos de una sesión, ni en las 24 h siguientes a una compra; como mucho una por sesión y tres por semana. Tras un "Ahora no" esa no vuelve en 7 días, y con 3 deja de salir sola. Sin cuentas atrás, sin "solo hoy" ni precios tachados. Cuáles: el Pack de inicio (en la 2.ª y la 4.ª sesión, con 1 rebirth como mucho), Dinero x2 al hacer los Rebirths 1 y 3, el VIP al hacer el 2, Bolsa XL tras 5 intentos de recoger con la bolsa llena en una sesión (con la mejora Bolsa en el nivel 3 o más) y el Turbo tras acabarse uno ganado (desde la 3.ª sesión).

---

## 12. Insignias, récords y rankings

- **20 insignias** (panel Pedidos, pestaña Insignias, "N/20 conseguidas"), con una tarjeta grande al conseguirlas ("¡Insignia conseguida!"); las que ya están creadas en Roblox se dan también como Badge.

  | Insignia | Cómo | Insignia | Cómo |
  |---|---|---|---|
  | Primer reciclaje | recicla tu primera bolsa | ¡Dentro! | encesta tu primera bolsa |
  | Brazo fuerte | encesta desde 30 m | Francotirador | encesta desde 60 m |
  | En racha | encesta 5 seguidas | Imparable | encesta 10 seguidas |
  | Reciclador | recicla 1.000 piezas | Gran reciclador | recicla 10.000 piezas |
  | Separa bien | 500 piezas en su contenedor de color | Buscatesoros | encuentra un tesoro |
  | Ahorrador | gana $10.000 en total | Millonario | gana $1.000.000 en total |
  | A tope | una mejora al máximo | Equipo completo | las 4 mejoras al máximo |
  | Renacido | tu primer Rebirth | Veterano | llega al Rebirth 3 |
  | Reciclador de élite | llega al Rebirth 5 | Leyenda del reciclaje | llega al Rebirth 10 |
  | Constante | cobra las 7 casillas del calendario | Cumplidor | cumple 30 pedidos |

- **Récords**: tu mejor distancia de acierto y la mejor del servidor (§6). El primer lanzamiento, que entra siempre, no cuenta para récords.
- **Tablones de ranking** en la plaza: **Dinero ganado**, **Racha máxima** y **Bolsas encestadas**, cada uno con el **histórico** y **esta semana** (empieza el lunes a las 00:00 UTC): el top 10 con la cara del avatar y, al pie, tu fila.

---

## 13. Pantalla y avisos

- **Arriba a la derecha**: la píldora verde del **dinero**, el **Turbo** si queda (en gris, "x2 en pausa", cuando no corre) y el pedido más avanzado.
- **A la derecha**: la barra de **Fuerza** (con el bonus que daría acertar desde donde estás) y la de **Bolsa**.
- **Abajo**: "MANTÉN [F] PARA LANZAR" con la bolsa llena y la pista de recoger (se va sola tras 20 recogidas).
- **Burbujas en el mundo**, a media pantalla, para lo que se rechaza ("Es de Ana: libre en 12 s", "Se abre con el Rebirth 2", "Llena la bolsa para poder lanzarla", "No llevas nada que reciclar"…).
- **Avisos** arriba en el centro para lo tuyo (pedidos, rebirth, compras, regalos) y un **feed** del servidor ("Ana activó un montón grande", "¡Llegó más basura al patio!", "¡Luis hizo el Rebirth 2!", "¡Récord del servidor!…").
- **Celebraciones** al cobrar ("¡DENTRO!", "¡RECICLADO!") y tarjetas grandes de récord y de insignia.

---

## 14. Sonido e idiomas

- Efectos al recoger, cargar y lanzar, al encestar o fallar, al cobrar, en las mejoras, los rebirths y las insignias, en la interfaz y en las trituradoras; música alegre en el patio (otra más animada al empezar un Turbo), que baja en las celebraciones. El botón **Sonido (M)** enciende o apaga **Música** y **Efectos** por separado, y se recuerda.
- El juego sale en **español, inglés o portugués** según el idioma de tu cuenta de Roblox; cualquier otro idioma lo ve en español.

---

## 15. Varios jugadores

- Hasta **6 por servidor**.
- **Compartido**: el patio, sus montones y lo que sale de ellos (quien recoge primero se lo lleva, salvo los 10 s del que excava), las bolsas falladas pasados sus 30 s, el feed, los tablones y las recicladoras en marcha.
- **De cada uno**: la bolsa, el dinero, las mejoras, los rebirths, los pedidos, las recompensas, los récords personales, las insignias y los cosméticos. Las celebraciones solo las ve quien cobra.
- El servidor vigila que nadie se mueva más deprisa de lo que permite su Velocidad: a quien se pasa no le deja recoger ni lanzar durante 2 s (nunca le echa).

---

## 16. Lo que todavía no hay

- 10 de los 20 Badges de Roblox (la insignia se gana igual en el juego; el Badge llega cuando se cree, a quien ya la tenía también).
- **Pospuestas**: figuritas escondidas y cintas de música en los montones.
- **Después del lanzamiento**: amigos, grupo e invitaciones, códigos, contenido nuevo pasado el Rebirth 3, premios semanales de ranking.
- **Quitadas** (no vuelven sin una decisión nueva): mascotas, energía y refrescos, bases, gemas, sobres y Contenedor Dorado, trajes, venta, reparación y fusión.
