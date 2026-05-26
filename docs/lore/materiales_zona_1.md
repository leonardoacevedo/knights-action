# Materiales — Valle de los Ecos (Zona 1)

Descripciones extendidas + flavor toasts para los 4 materiales canónicos de Zona 1. Las descripciones cortas (1-2 líneas) viven en los `.tres` (campo `description`) y aparecen en el inspector / tooltip. Las extendidas de acá son para Bestiario, inventario expandido, y futuras UI de lore.

---

## Piedra de Resonancia (universal)

**`id`:** `piedra_resonancia`
**Rareza:** R1 — Común
**Origen:** Universal (todas las zonas).
**Uso:** Consumible de refinamiento (+1 a +10).

### Descripción corta (en `.tres`)
> Un fragmento mineral que vibra a frecuencias imperceptibles. Al contacto con metal forjado, se asienta en su estructura y la empuja más allá de sus límites naturales.

### Descripción extendida
La Piedra de Resonancia no es exactamente piedra. Los herreros que las trabajaron por primera vez notaron que **el material respondía al sonido** — golpear una contra otra producía una resonancia que parecía continuar más allá del impacto, como si la piedra "recordara" la vibración.

Esa propiedad es la que la hace útil para refinamiento. Al colocar una Piedra de Resonancia sobre un arma o armadura ya forjada y aplicar la técnica adecuada, **el metal absorbe parte de esa resonancia residual** y se reajusta a un estado superior — más afilado, más resistente, más equilibrado — sin necesidad de refundirlo desde cero.

El proceso no siempre tiene éxito. Cuanto más alto el nivel objetivo, más difícil que la Piedra "acepte" liberar su resonancia en el item. Las Piedras fallidas se desintegran. Las exitosas también — solo una vez, una sola transferencia, irrecuperable.

### Flavor al recoger por primera vez
> "Vibra levemente entre los dedos. Algo en ella recuerda la forma de todo metal."

---

## Hierba Antigua

**`id`:** `hierba_antigua`
**Rareza:** R1 — Común
**Origen:** Valle de los Ecos (todas las stages).
**Uso:** Material base de crafteo. Insumo principal de armaduras ligeras y armas básicas.

### Descripción corta (en `.tres`)
> Crece entre grietas de piedra labrada que ya nadie recuerda haber tallado. Su tallo resiste más que la roca bajo sus raíces.

### Descripción extendida
La Hierba Antigua no es la primera planta que creció sobre las ruinas del imperio caído, pero es la única que se quedó. Las demás murieron. Esta aprendió a vivir en la grieta.

Su tallo es **más fibroso que la madera tierna**, casi metálico al tacto. Los herreros del Valle la usan trenzada como núcleo de cinchas y empuñaduras: no se rompe con el sudor, no cede al filo de una espada limpia, soporta el roce constante del cuerpo en combate. Cuando se la calienta, libera un aroma vegetal denso que algunos guerreros asocian con "el olor de las ruinas". No es desagradable. Es persistente.

Como material, es el más mundano de la zona. Pero también el más confiable. Pocas recetas no la requieren.

### Flavor al recoger por primera vez
> "El tallo no se quiebra cuando lo arrancás. Cede con un crujido limpio, como si te entregara su parte."

---

## Savia Resonante

**`id`:** `savia_resonante`
**Rareza:** R2 — Raro
**Origen:** Valle de los Ecos (drop de enemies R2+).
**Uso:** Material intermedio de crafteo. Refuerza el efecto de la Piedra de Resonancia cuando ambos están presentes en una receta.

### Descripción corta (en `.tres`)
> La sangre lenta de los árboles que sobrevivieron al derrumbe. Condensa siglos en cada gota.

### Descripción extendida
Cuando el imperio cayó, no todos los árboles murieron. Los más viejos — los que ya estaban antes de las primeras fortalezas — soportaron el derrumbe sin caer. Lo que cambió en ellos fue interno: la savia, que antes circulaba como en cualquier árbol joven, se volvió **densa, lenta, casi cristalina**.

Extraerla requiere paciencia y una técnica heredada — un corte preciso en la corteza vieja, una espera de horas, una sola gota que se forma con dificultad. Los recolectores experimentados llevan meses entre extracción y extracción del mismo árbol, para no agotarlo.

La Savia Resonante **comparte una propiedad sutil con la Piedra de Resonancia**: ambas vibran al mismo registro inaudible. En recetas que combinan ambos materiales, el resultado supera la suma de sus partes — algo en la coordinación química amplifica el efecto del refinamiento implícito.

### Flavor al recoger por primera vez
> "Una sola gota. Pesa más de lo que debería."

---

## Esencia del Verdor

**`id`:** `esencia_verdor`
**Rareza:** R3 — Épico
**Origen:** Valle de los Ecos (drop raro de enemies R3 y del Guardián).
**Uso:** Material de alta gama. Requerido para crafteo de items R3 y para mejoras de set específicas del Valle.

### Descripción corta (en `.tres`)
> Lo que queda cuando el Valle concentra su voluntad en un solo punto. Los guerreros que la portan dicen escuchar algo, pero no pueden explicar qué.

### Descripción extendida
No se sabe cómo se produce. Aparece, ocasionalmente, sobre el cuerpo de los enemies más resistentes del Valle — élites, hechiceros, el Guardián mismo — al momento de su caída. Una gota verde-dorada, densa, **vibra durante unos segundos** después del último golpe y luego se solidifica en una forma orgánica imposible de catalogar.

Los herreros que han trabajado Esencia del Verdor reportan dos cosas:

1. **El material "guía" la forja.** No se moldea — se acompaña. Un herrero que intenta forzarlo lo destruye. Uno que lo deja hablar termina con piezas que tienen propiedades que él no diseñó.
2. **Los guerreros que portan items con Esencia del Verdor escuchan algo.** No siempre, no fuerte, no descifrable. Un murmullo, una sensación de "no estar solo" en momentos de quietud. Algunos lo encuentran reconfortante. Otros lo descartan y renuncian al item.

Si tiene una conexión con los Ecos del Coliseo, nadie la ha demostrado todavía. Pero hay coincidencias notables.

### Flavor al recoger por primera vez
> "Tibia. Pulsa con un ritmo que no es el tuyo."

---

## Decisión narrativa pendiente

El nombre **"Esencia del Verdor"** se usa indistintamente con **"Esencia Verdor"** en algunos `.tres` y referencias. Para consistencia, recomendar a Leo elegir uno:

- **"Esencia del Verdor"** (con artículo) — más natural en español, mejor cadencia.
- **"Esencia Verdor"** (sin artículo) — más corto, encaja mejor en UI con poco espacio.

Mi preferencia: **"Esencia del Verdor"** para texto largo (bestiario, descripciones, lore) y aceptar **"Esencia Verdor"** como abreviación válida en toasts y tooltips de inventario donde el espacio cuenta.

Si Leo decide unificar, el cambio es trivial: editar `display_name` en `resources/materials/esencia_verdor.tres`.
