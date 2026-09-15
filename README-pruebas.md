# Guía de pruebas cerradas — Recíclatas

Para 3–5 probadores en el mismo servidor (máximo 6 por partida: 6 bases). **Esto no mide si el juego funciona,
mide si se siente bien.** Lo técnico ya está cubierto con pruebas automáticas;
aquí interesa la sensación, y para eso hace falta gente que no lo haya hecho.

El GDD (§14) señala el mayor riesgo: que el patio compartido sin robo se sienta
"tibio", ni la calma del original ni la emoción de un juego competitivo. Esta
sesión existe para responder a eso antes de comprometer arte.

## Cómo se juega

| Control | Acción |
|---|---|
| Entrar al patio | La cámara pasa sola a **primera persona** y ves tus manos con la bolsa |
| Acercarse a una colina de basura y mantener **E** | Activarla (cuesta energía): la colina se convierte en una montaña de basura de verdad (latas, llantas, cajas, botellas, cáscaras…; 30–280 piezas según el tamaño) que se queda ahí hasta que alguien se la lleve |
| **Mantener el clic** apuntando a la basura (el punto del centro es la mira) | Se recoge todo lo que pase por la mira, ~6 piezas por segundo; cada una vuela a la bolsa y lo que tenía encima cae (física). La montaña asentada es sólida: se sube por ella (salta) para lo de arriba; solo la basura que está cayendo te atraviesa. **Nada se recoge por pasar por encima**; solo la mejora Imán atrae sola |
| **Mantener F** (o botón táctil) apuntando al Contenedor, soltar | Lanzar la **bolsa entera**; cuanto más tiempo, más lejos. Si falla, queda en el suelo y cualquiera puede recogerla |
| **E** en el Contenedor de la caseta | Reciclar la bolsa de cerca (bonus si iba llena). **Es la única forma de ganar $**: todo lo que recoges (basura, billetes, tesoros) ocupa un hueco de la bolsa hasta que lo depositas. La barra junto a la de fuerza es la bolsa: cuando dice "¡LLENA!" toca volver |
| **E** en la máquina | Refresco ($50): recupera energía |
| **Q** / **J** / **L** / **B** | Teléfono (tienda) / Álbum / Logros / Base |
| Botones "Ir a casa" / "Ir al patio" | Teletransporte |
| Gamepad | X recoger, Y lanzar, B cerrar, Select álbum |

Cada uno tiene una **parcela** (base) con estantería, radio, mesa de
reparación, exhibidor, teléfono (tienda) y almacén (álbum). Se puede visitar
la de otro y darle "Me gusta" en el cartel.

Comandos de admin útiles para acelerar (sólo el creador): `/dar dinero 5000`,
`/dar gemas 300`, `/dar todas`, `/maxmejoras`, `/pases on|off`, `/repoblar`.

## Antes de empezar

Jugad **al menos 20 minutos** juntos, en el mismo servidor, y que al menos dos
personas exploren el patio a la vez. Si cada uno va a un montón distinto y no
os cruzáis, no se está probando lo que hay que probar.

## Las cuatro preguntas

Responde con frases, no con números. "Me dio rabia que se llevara la mascota
que yo había hecho saltar" vale más que un 7/10.

### 1. El montón compartido

Cuando alguien activa un montón, los objetos son de quien los toque primero.

- ¿Fuiste a montones que activaron otros? ¿Te pareció bien o "robar"?
- ¿Alguna vez activaste uno grande y otros se llevaron lo bueno? ¿Qué sentiste?
- ¿Avisaste a alguien de que había salido algo bueno, o preferiste callarte?
- ¿Se siente vivo ver a otros excavando, o da igual que estén?

### 2. El ritmo

- ¿Cuándo te quedaste sin energía por primera vez? ¿Compraste refresco o esperaste?
- ¿La vuelta a la caseta a reciclar es un paseo agradable o un trámite?
- ¿Probaste a lanzar desde lejos? ¿Se entiende que hay que apuntar al hueco?

### 3. La colección

- ¿Qué mascota te hizo más ilusión encontrar y por qué?
- Tras limpiar o ensamblar una vez, ¿lo harías 20 veces más? (Kotamon se llevó
  quejas por esto; aquí hay pase de Auto-Ensamblaje).
- ¿Miraste la colección de otra persona? ¿Te dieron ganas de completar la tuya?

### 4. El dinero

- ¿La primera mejora llegó pronto o tardó demasiado?
- ¿Se entendió que hay que volver al contenedor para cobrar? ¿Alguien siguió
  recogiendo con la bolsa llena sin darse cuenta?
- ¿Entendiste para qué sirven las Gemas sin que nadie te lo explicara?
- Abre "Ver probabilidades" del Sobre Premium: ¿te fías de lo que dice?

## Qué apuntar el organizador

- Cuántos montones se activan por minuto con 3+ personas (¿se vacía el patio
  antes de que reponga Doña Chatarra? Hoy repone con ≤ 8 montones, 20 s después).
- Si alguien se queda sin energía Y sin dinero para refrescos (bloqueo).
- Momentos de risa o de queja en voz alta: son los datos.
