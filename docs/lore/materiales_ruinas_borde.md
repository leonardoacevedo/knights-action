# Materiales — Ruinas de Borde (Zona 1 provisional)

> PROPUESTA Fase 4+ (expansión 7 zonas). GDD vigente v2.2. Numeración de zona provisional.

Descripciones extendidas + flavor toasts para los 3 materiales canónicos del borde. Las cortas (1-2 líneas) viven en los `.tres`. Las extendidas son para Bestiario, inventario expandido y futuras UI de lore.

> *Nota de diseño:* los materiales del borde son **NEUTRO, sin afinidad elemental** — escombro genérico del imperio. Forjan el equipo base que el forastero usa hasta encontrar el primer material elemental al bajar. Es la única zona cuyos materiales no cargan elemento.

---

## Cascote de Borde

**`id`:** `cascote_borde`
**Rareza:** R1 — Común
**Origen:** Ruinas de Borde (todas las stages).
**Uso:** Material base de crafteo. Insumo principal de equipo NEUTRO de tier bajo.

### Descripción corta (en `.tres`)
> Trozo de muro de frontera. No tiene nada especial. Por eso es lo primero que encontrás y lo último que extrañás.

### Descripción extendida
El Cascote de Borde es exactamente lo que parece: **pedazos de las construcciones más mundanas del imperio**, las de la franja exterior. Muro de barraca, esquina de aduana, base de poste de peaje. No pasó por ningún horno sagrado ni absorbió ninguna veta profunda. Es piedra y argamasa viejas, nada más.

Esa banalidad es su utilidad. Los herreros del exterior lo usan para forjar el equipo de los primeros pasos — piezas NEUTRO sin afinidad, robustas a fuerza de ser simples. No counterea ningún elemento porque no tiene ninguno. Sirve hasta que el forastero baja y encuentra algo con carga elemental, y entonces el Cascote queda atrás sin que nadie lo lamente.

Abunda. Está en cada grieta del borde. Es el material más ordinario del juego — y el más honesto sobre lo que es.

### Flavor al recoger por primera vez
> "Un cascote como cualquier otro. Lo guardás igual. Algo hay que forjar para empezar."

---

## Sillar Hueco

**`id`:** `sillar_hueco`
**Rareza:** R2 — Raro
**Origen:** Ruinas de Borde (drop de enemies R2+).
**Uso:** Material intermedio de crafteo. Aligera las piezas NEUTRO sin sacrificar resistencia.

### Descripción corta (en `.tres`)
> Sillar tallado con una cavidad interior que nadie explica. Pesa menos de lo que su tamaño promete.

### Descripción extendida
Los Sillares Huecos son bloques de piedra labrada del borde con una **cavidad interna deliberada** — no una grieta, no una erosión: un hueco tallado a propósito. Los herreros del exterior discuten para qué servían. La teoría más sobria es que el imperio aligeraba los sillares de las construcciones de paso para moverlos rápido con caravanas, llenando el hueco con paja o lastre según hiciera falta.

Lo curioso es que **los huecos están vacíos**. Nunca se encontró el lastre. El forastero levanta un sillar esperando peso de roca y recibe peso de cáscara. Es la primera anomalía que ve en el juego — pequeña, mundana, sin elemento. Apenas un bloque que pesa de menos.

Como material, sirve para forjar piezas NEUTRO **ligeras**: armaduras de los primeros niveles que no penalizan la movilidad. El metal y la piedra del exterior, vaciados igual que el sillar, dan equipo cómodo para aprender a moverse. Después del borde, el forastero querrá afinidad. Por ahora quiere soltura, y el Sillar Hueco se la da.

### Flavor al recoger por primera vez
> "Lo levantás y casi te vas para atrás del impulso. Esperabas roca. Te dieron cáscara. ¿Qué iba adentro?"

---

## Cuño de Aduana

**`id`:** `cuno_aduana`
**Rareza:** R3 — Súper raro
**Origen:** Ruinas de Borde (drop raro de enemies R3 y del Sargento de Frontera).
**Uso:** Material de gama alta de la zona. Requerido para el mejor equipo NEUTRO y para el primer amuleto del juego.

### Descripción corta (en `.tres`)
> El sello de hierro que autorizaba el paso al imperio. Quien lo lleva, en teoría, tiene permiso de entrar.

### Descripción extendida
El Cuño de Aduana no se extrae de la piedra. **Se hereda de un fragmento.** Aparece, ocasionalmente, sobre los enemies más viejos del borde — los oficiales, el Sargento mismo — al momento de su caída. Es un bloque de hierro macizo con un grabado en relieve: el emblema del imperio caído, el que se estampaba en los permisos de paso. Pesado, frío, todavía legible.

Es el material más cargado de significado del borde — no de elemento (no tiene ninguno), sino de **autoridad**. El Cuño era la diferencia entre entrar y quedarse afuera. Quien lo portaba decidía. Ahora el forastero lo lleva en el bolsillo, y los herreros del exterior lo trabajan para las piezas NEUTRO de gama alta de la zona: equipo que, sin afinidad, es sólido por la calidad del hierro imperial.

Hay una lectura que circula entre los recolectores: el Cuño **autoriza el paso**. Quien lo lleva, en el lenguaje muerto del imperio, tiene permiso de entrar. El forastero baja al Acueducto con un Cuño de Aduana encima — y nadie sabe si la grieta se abrió porque limpió la zona, o porque, por primera vez, **llevaba el sello correcto.** Leo no ha decidido si esto es superstición de recolectores o algo más. Por ahora, ninguna de las dos lecturas hace que el Cuño se sienta neutral del todo.

### Flavor al recoger por primera vez
> "Hierro frío con un emblema que no reconocés. Pesa como una decisión. Algo te dice que ahora podés pasar."

---

## Decisiones narrativas pendientes

- **Cuño de Aduana — ¿abre el descenso?** El flavor sugiere que portar el Cuño podría ser lo que autoriza el paso al Acueducto (gate narrativo), en paralelo al gate mecánico de "completar Z1 desbloquea shards elementales" (§4.1 de la propuesta). Mi recomendación: **dejarlo ambiguo** — el forastero limpia la zona Y aparece el Cuño Y se abre la grieta, sin aclarar cuál fue la causa. Refuerza el tono "el imperio dejó cosas y nadie sabe del todo cómo funcionan". Si Leo quiere certeza, atarlo explícitamente al gate de shards.
- **Sillar Hueco — el lastre faltante.** El hueco vacío es un hook chico. Si Leo quiere usarlo, el lastre podría reaparecer abajo (¿algo que el imperio sacó de los sillares del borde para enterrarlo más profundo?). Si no, queda como anomalía decorativa del tutorial. Decisión menor.
- Estos 3 materiales son **NEUTRO** y deben quedar fuera de cualquier tabla de afinidad elemental. Al implementar, confirmar que el equipo forjado con ellos sale con `element = NEUTRO (0)` y no entra al cálculo de matchup ni de set bonus elemental.
