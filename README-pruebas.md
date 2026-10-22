# Guía de pruebas cerradas — Recíclatas

Para 3–5 probadores en el mismo servidor (máximo 6 por partida). **Esto no mide si el juego funciona,
mide si se siente bien.** Lo técnico ya está cubierto con pruebas automáticas
(`EjecutarPrueba`, ver `CLAUDE.md`); aquí interesa la sensación, y para eso
hace falta gente que no lo haya jugado.

El mayor riesgo del diseño: que el patio compartido sin robo se sienta
"tibio", ni la calma del original ni la emoción de un juego competitivo.
Esta sesión existe para responder a eso, y a si separar por colores tiene
gracia o es un trámite.

## Cómo se juega

| Control | Acción |
|---|---|
| Entrar al patio | La cámara pasa sola a **primera persona** con tus manos y la bolsa. **V** (o el botón Cámara) cambia a tercera persona |
| Acercarse a una colina de basura y mantener **E** | Excavarla: se convierte en una montaña de basura de verdad (20 o 60 piezas). Durante 10 s solo la recoge quien la excavó |
| **Mantener el clic** apuntando a la basura (el punto del centro es la mira) | Recoge lo que pasa por la mira. Cada pieza es del **color de su tipo**: papel celeste, plástico amarillo, metal gris plomo, orgánico verde |
| **Mantener F** (o el botón táctil) con la bolsa llena, soltar | Lanzar la **bolsa entera** a un contenedor; cuanto más lejos, más bonus (+20 % desde 10 m … +150 % desde 60 m) y racha si aciertas seguido |
| **Los 5 contenedores** junto a la recicladora | 4 de color (papel, plástico, metal, orgánico) y el **general azul**. En el de su color, cada pieza paga **x2**; en el de otro color, x0,5; en el general, x1 |
| **E** en un contenedor | Reciclar a mano, sin bonus de lanzamiento (el de separar sí) |
| **Q** / **R** / **P** | Tienda / Rebirth / Pedidos e insignias |
| Gamepad | X recoger, Y lanzar, B cerrar |

Comandos de admin útiles para acelerar (solo el creador, o cualquiera en
Studio): `/dar dinero 5000`, `/maxmejoras`, `/pases on|off`, `/rebirths 1`,
`/tutorial 0`, `/repoblar`, `/reset`.

## Antes de empezar

Jugad **al menos 20 minutos** juntos, en el mismo servidor, y que al menos dos
personas exploren el patio a la vez. Si cada uno va a un montón distinto y no
os cruzáis, no se está probando lo que hay que probar. Que al menos uno sea
nuevo: el tutorial (la píldora de arriba a la izquierda) también se prueba.

## Las cuatro preguntas

Responde con frases, no con números. "Me dio rabia que se llevara el tesoro
del montón que yo había excavado" vale más que un 7/10.

### 1. El montón compartido

- ¿Fuiste a montones que excavaron otros? ¿Te pareció bien o "robar"?
- ¿Alguna vez excavaste uno grande y otros se llevaron lo bueno? ¿Qué sentiste?
- ¿Se siente vivo ver a otros excavando, o da igual que estén?

### 2. Separar por colores

- ¿Entendiste sin que nadie te lo dijera que cada contenedor paga el doble su color?
- ¿Recogiste a propósito de un solo color para llenar la bolsa, o lo mezclaste todo y fuiste al general?
- ¿Te equivocaste de contenedor alguna vez? ¿Se entendió por qué pagó menos?

### 3. El ritmo

- ¿La vuelta a los contenedores es un paseo agradable o un trámite?
- ¿Probaste a lanzar desde lejos? ¿Cuántos tiros fallaste antes de pillarle el truco?
- ¿Los pedidos del día te dieron un objetivo, o ni los miraste?

### 4. El dinero y las mejoras

- ¿La primera mejora llegó pronto o tardó demasiado?
- ¿Se entendió que hay que volver al contenedor para cobrar? ¿Alguien siguió
  recogiendo con la bolsa llena sin darse cuenta?
- ¿La meta del Rebirth 1 parece alcanzable o muy lejana?

## Qué apuntar el organizador

- Cuántos montones se excavan por minuto con 3+ personas (¿se vacía el patio
  antes de que vuelvan las colinas, 45 s después de terminar cada una?).
- Qué contenedor usa cada uno (¿todos al general? entonces el x2 no se entiende o no compensa).
- Momentos de risa o de queja en voz alta: son los datos.
