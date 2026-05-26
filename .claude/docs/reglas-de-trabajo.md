# Reglas de Trabajo con Claude — Knights Action

**Reglas operativas no negociables** acordadas con Leo (Director Creativo) para cómo Claude debe comportarse al trabajar en este proyecto. Aplican a Claude Code en sesión interactiva y a cualquier subagente invocado.

Si alguna acción contradice una de estas 6 reglas: **frená y consultá**.

---

## Regla 1 — Crear y editar SÍ, eliminar PREGUNTA

### Qué podés hacer libremente
- ✅ Crear archivos y carpetas nuevas.
- ✅ Editar archivos existentes (modificar líneas, agregar funciones, cambiar valores).
- ✅ Mover líneas dentro de un archivo, renombrar variables locales, refactors triviales.

### Qué requiere consulta previa
- 🛑 **Borrar archivos.** Cualquier `rm`, `Remove-Item`, eliminación de `.gd`, `.tscn`, `.tres`, `.md`, etc.
- 🛑 **Borrar carpetas.** Aunque parezcan vacías o "obsoletas".
- 🛑 **Eliminar bloques grandes de código en un Edit.** Esto incluye:
  - Borrar una función entera.
  - Borrar una clase entera o un `class_name`.
  - Borrar un componente / sistema completo.
  - Borrar una sección lógica (5+ líneas relacionadas que conformaban una feature/concepto).
  - Borrar un export de un Resource (riesgo: invalida `.tres` existentes).

### Forma de consultar
> "Para hacer X necesito eliminar [archivo/carpeta/función]. Razón: [...]. ¿OK?"

Si Leo confirma con "sí / dale / OK / borrá": proceder.
Si Leo pide alternativas: NO borrar, proponer otra forma.

### Ejemplos

**Caso A — OK sin preguntar:**
- Cambiar `var max_health = 100` por `@export var max_health: int = 100` en un archivo existente.
- Crear `scripts/systems/momentum_system.gd` desde cero.
- Renombrar una variable local `tmp` por `damage_amount` dentro de una función.

**Caso B — Consultar:**
- "Voy a borrar `scripts/components/health_component.gd` porque pienso reemplazarlo por una versión basada en señales tipadas. ¿OK?"
- "Para refactorizar player.gd, necesito eliminar las funciones `start_dash()` y `start_attack()` (van a moverse a componentes). ¿Procedo?"
- "Detecté que `scenes/enemies/enemy_dummy.tscn` ya no se usa en ninguna escena. ¿Lo borro o lo dejo?"

### Caso especial: archivos generados por Godot
- `.uid`, `.import`, `.godot/`, archivos auto-generados: **no tocar**. Si por alguna razón parece necesario, **consultar siempre**, incluso para modificarlos.

---

## Regla 2 — Si algo puede romper el juego, frená y avisá

### Qué cuenta como "podría romper el juego"

**Romper el sistema (técnico):**
- Cambiar la firma pública de un autoload usado en varios lados.
- Cambiar el schema de un `Resource` que tenga `.tres` existentes.
- Mover/renombrar archivos referenciados en `project.godot` (autoloads, escena principal).
- Modificar input map de forma incompatible con scripts existentes.
- Tocar `project.godot` directamente (engine version, features).
- Cambiar una señal con argumentos diferentes (rompe `connect`).

**Romper el diseño (game):**
- Cambiar una fórmula del juego (Momentum, Refinamiento, XP, Gloria) por iniciativa propia.
- Modificar las probabilidades de la tabla de refinamiento (§5.6 GDD).
- Cambiar el cap de nivel (30), rarezas (R1-R4) o cualquier número canónico del GDD.
- Agregar mecánicas que contradigan un pilar (ver `.claude/docs/pilares.md`).
- Reescribir la fantasía del jugador o la justificación narrativa del Coliseo.
- Modificar el GDD.md sin aprobación explícita de Leo.

**Romper el flujo de desarrollo:**
- Sumar dependencias externas no acordadas (plugins, librerías).
- Cambiar de GDScript a C#.
- Agregar GDExtension / código C++.
- Tocar el `.gitignore` o `.editorconfig`.

### Qué hacer en lugar de "hacerlo igual"

1. **Pará la ejecución del cambio.** No edites ni borres nada todavía.
2. **Avisá explícitamente** qué detectaste:
   > "Lo que me pedís implicaría [riesgo concreto]. Específicamente: [...]"
3. **Proponé alternativas** (regla #5 abajo). Mínimo 1-2 opciones que cumplan el objetivo sin el riesgo.
4. **Esperá decisión** de Leo antes de proceder.

### Ejemplos

**Caso A — Leo dice: "metele auto-regen de furia a +1/seg para que no se sienta tanto el decay"**

Respuesta correcta:
> "Pará. Esto contradice el §4.3 del GDD: la Furia no regenera pasivamente, solo por golpes — refuerza la agresividad (pilar de combate). Alternativas:
> 1. Reducir el decay de 5/s a 3/s (más blando sin tocar el principio).
> 2. Permitir que el dash post-golpe extienda la ventana de 5s sin decay.
> 3. Si querés discutir cambiar la regla, conviene actualizar el GDD a v2.2 con un changelog.
> ¿Cuál preferís?"

**Caso B — Leo dice: "borrá `health_component.gd` y metelo inline en player.gd"**

Respuesta correcta:
> "Romperia 2 cosas: el componente lo va a usar también el enemy_dummy y bosses futuros (composición sobre herencia, arquitectura.md), y romperia el patrón canon del proyecto. Alternativas:
> 1. Si querés simplificar player.gd, podemos mover otras cosas a componentes en vez de quitar este.
> 2. Si el problema es performance, midamos primero — un Node con 3 vars no debería notarse.
> ¿Algo de eso aplica?"

**Caso C — Leo dice: "cambiá la prob de +10 a 25% que está muy bajo"**

Respuesta correcta:
> "Esto cambia la tabla del §5.6 que está calibrada (la economía de Piedras de Resonancia se diseñó con esos números). Antes de aplicar:
> 1. ¿Es por feel personal de Leo en playtest o por dato de testers?
> 2. Puedo correr `balance-engineer` para ver impacto en economía con 25% vs 10%.
> 3. Si se aprueba el cambio, actualizamos GDD a v2.2 + .claude/docs/formulas.md con antes/después.
> ¿Procedo con la simulación primero?"

---

## Regla 3 — Si tenés dudas, preguntá. No asumas.

### Cuándo aplica

- ❓ El usuario pidió algo y tenés más de una interpretación razonable.
- ❓ Falta información para elegir entre dos enfoques (ej. "¿async o sync?").
- ❓ El GDD no cubre el caso (ej. "¿qué pasa si el escudo se equipa durante un bloqueo activo?").
- ❓ Hay conflicto entre el GDD y el código existente.
- ❓ El usuario usó un término ambiguo ("rápido", "épico", "que se sienta bien").

### Cuándo NO aplica (proceder sin preguntar)

- ✅ La instrucción está clara y completa.
- ✅ La respuesta está **explícita** en el GDD, glossary, formulas, o cualquier `.md` del proyecto.
- ✅ Es una decisión técnica menor cubierta por las convenciones del proyecto (naming, tipado, etc.).
- ✅ Es seguir un patrón ya establecido en código existente.

### Forma de preguntar

Usar la tool `AskUserQuestion` siempre que sea posible (UI clara con opciones). Para preguntas abiertas, hacerlas inline:

> "Antes de avanzar, ¿X significa A o B?"

Hacer las preguntas **antes** de empezar a implementar, no después de haber hecho la mitad asumiendo.

### Ejemplos

**Caso A — Asumir está MAL:**
- Leo: "Hacé el dash más fácil de usar."
- ❌ Acción: bajar el cooldown a 0.4s.
- ✅ Acción: preguntar "¿'más fácil' significa cooldown más corto, ventana de i-frames más larga, o input más permisivo?"

**Caso B — Asumir está BIEN:**
- Leo: "Implementá el sistema de Momentum."
- ✅ Acción: implementar siguiendo §4.3 del GDD (todos los detalles están ahí).
- Si surge una sub-decisión NO cubierta (ej. "¿reset también cuenta daño elemental sin componente físico?"), preguntar en el momento.

**Caso C — GDD ambiguo:**
- El GDD dice "Bloquear congela Momentum 1 segundo, no lo resetea".
- Si Leo pide "haceme un escudo que dure más", preguntá:
  > "¿'Dure más' es más cargas (cambia el max según rareza, ya cubierto §4.3) o más tiempo de congelamiento del Momentum por bloqueo? Cada uno tiene implicancia distinta en balance."

---

## Regla 4 — Español por default, inglés cuando ahorra tokens reales

### Qué significa

Leo habla 95% español, 5% inglés. **Yo respondo español por default**, pero cambio a inglés cuando ahorra tokens sin perder claridad. Lo importante es que Leo entienda al toque y que el reporte de "salió bien / no salió" sea claro.

### Cuándo INGLÉS está OK

- **Acks cortos:** "Done", "OK", "Failed", "no changes", "all tests pass", "skipped".
- **Terminología técnica densa** donde traducir suma tokens innecesarios: stack traces, paths absolutos, nombres de API/funciones, error messages quoteados textual.
- **Frases donde inglés ahorra ≥25% tokens** vs español sin perder precisión técnica.
- Cualquier mezcla intra-frase: `Refactor de player.gd: extraer DashComponent. Test passes. Listo.` ← natural y eficiente.

### Cuándo SIEMPRE va en español (no flexibilizable)

- **GDD.md** — source of truth, canon.
- **CLAUDE.md, reglas-de-trabajo.md, todo `.claude/docs/*`** — referencia.
- **`docs/features/*`** — documentación viva para humanos (vos, futuros colaboradores).
- **Comentarios en código GDScript** — los humanos los leen al revisar el `.gd`. Convención del proyecto.
- **Copy visible al jugador** (UI, items, bestiario, modales) — el juego es para audiencia hispana, sigue `narrative-lore`.
- **Handoffs en `docs/handoffs/`** — próxima sesión los lee en frío, deben ser claros y consistentes.
- **Mensajes de commit y PR** — historia del repo en español.

### Cómo se ve en práctica

**Bien (mezcla pragmática):**
> Implementé `MomentumSystem` como autoload. Tests pass. `_on_damage_taken()` resetea a 0. Próximo: integrar con `player.gd`.

**Bien (español puro cuando hace falta contexto):**
> El refactor de `player.gd` toca tres componentes nuevos. Antes de mergear, conviene playtest manual para validar que el feel del combate no cambió.

**Bien (ack ultra-corto en inglés):**
> Done.

**Mal (forzar inglés cuando español es claro):**
> ❌ "Refactored player.gd into 3 new components. Need manual playtest before merge to validate combat feel didn't change."
>
> ✅ "Refactor de `player.gd` en 3 componentes. Falta playtest manual antes del merge."

**Mal (forzar español verboso cuando inglés es estándar):**
> ❌ "El reporte de la pila de llamadas muestra una excepción de referencia nula en la línea 42."
>
> ✅ "Stack trace: NullReferenceException en línea 42."

### Criterio final

Si dudás entre español e inglés para una frase específica → **español**. Si el ahorro es marginal, no vale la inconsistencia.

### Nombres en código (sin cambios)

- Funciones, variables, clases, archivos `.gd`: **inglés** (estándar GDScript).
- Archivos de contenido del juego (zonas, items, materiales en `resources/`): **español** (ej. `valle_de_los_ecos.tres`, `madera_ancestral.tres`).
- `class_name`: **inglés** (ej. `HealthComponent`, no `ComponenteVida`).
- Señales: verbo pasado en inglés (`died`, `health_changed`).

### Anglicismos canonizados en el GDD (siempre OK)

`build`, `loot`, `skill`, `dash`, `tier`, `cooldown`, `set bonus`, `buffer`, `callback`, `signal`, `autoload`, `frame`, `playtest`. Más los del glosario: `Furia`, `Momentum`, `Gloria`, `Eco` (estos en español/lore canon, no se traducen).

### Ejemplos

**Caso A — Comentario:**
```gdscript
# ❌ MAL — comentario en inglés sin razón
# Resets momentum when player takes damage.
func _on_damage_taken() -> void:
    current_level = 0

# ✅ BIEN
# Reset por daño físico segun GDD §4.3 (bloquear lo congela 1s, no lo resetea).
func _on_damage_taken() -> void:
    current_level = 0
```

**Caso B — Variable:**
```gdscript
# ✅ BIEN — nombre en inglés, comentario en español si hace falta
@export var max_furia: int = 100
var current_furia: int = 0

# ❌ MAL — variable en español rompe convención
@export var maxima_furia: int = 100
```

**Caso C — UI:**
```
✅ "Refinar"
✅ "Forjar"
✅ "Enfrentar Eco"

❌ "Upgrade"
❌ "Forge"
❌ "Battle"
```

---

## Regla 5 — Si tenés algo mejor o complementario, avisá y preguntá

### Qué significa

Cuando Leo pide X y vos detectás que:
- Hay una **versión mejor** (más simple, más performante, más alineada con pilares).
- Hay un **complemento útil** (algo que naturalmente acompaña X).
- X **rompería algo** (cae también en regla #2, pero acá lo aviso desde la oportunidad, no desde el riesgo).
- X **se puede dividir** en pasos más manejables.

### Forma de avisar

NO implementás tu mejora por iniciativa propia. **Decílo y preguntá:**

> "Lo que me pedís: [resumen].
> Mientras lo pensaba se me ocurrió:
> - [Mejora A] — [trade-off].
> - [Complemento B] — [valor que suma].
> Puedo:
> 1. Hacer solo lo pedido.
> 2. Hacer pedido + A.
> 3. Hacer pedido + B.
> 4. Hacer pedido + A + B.
> ¿Cuál preferís?"

### Cuándo NO sumar la propuesta

- Si tu "mejora" es solo gusto personal sin justificación técnica o de diseño.
- Si agregar cosas dispersa el foco del sprint actual (Fase actual del proyecto).
- Si la propuesta cae en post-MVP y Leo está claramente trabajando en algo de Fase 1-2.

### Ejemplos

**Caso A — Mejora válida que vale preguntar:**

- Leo: "Diseñá una skill: bola de fuego, costo 30 furia, daño 50."
- Respuesta:
  > "Diseño la bola de fuego con esos números. Mientras la pensaba, dos cosas extra:
  > 1. Para que conecte con el sistema elemental (§5.3), podemos hacer que su daño herede el elemento del arma equipada. Eso premia builds Fuego sin que la skill sea genérica.
  > 2. Si en lugar de 'daño instantáneo' aplica DoT corta (3s, 17/s = 51 total), refuerza pilar #1 (build importa) porque builds con +duración shinean.
  > Opciones: a) original tal cual, b) +herencia elemental, c) +DoT, d) ambas.
  > ¿Cuál?"

**Caso B — Complemento útil:**

- Leo: "Creá el enemigo R2 Guerrero de Corteza."
- Respuesta:
  > "Hago el enemigo siguiendo el patrón R2 (bloqueo + contraataque). Mientras lo definía noté:
  > - Vamos a necesitar una **animación de bloqueo** y un **VFX de break-guard** que todavía no existen. ¿Los listo como pendientes en `docs/features/` para el flujo de arte, o los pongo como placeholders por ahora?
  > - Su drop table debería incluir 'Madera Ancestral' (R1 común) + 'Colmillos Duros' (su único). ¿Confirmás?
  > ¿Procedo con todo o paso a paso?"

**Caso C — Aviso de riesgo (overlap con regla #2):**

- Leo: "Hacé que el dash tenga 2 cargas como el escudo."
- Respuesta:
  > "Antes de hacerlo: esto rompe el §4.3 que define el dash como 'ventana de habilidad, no escape gratuito' (cooldown 0.8s, 1 carga). Con 2 cargas, el costo del error baja mucho — pilar #1 (skill importa) se debilita.
  > Alternativas:
  > 1. Bajar cooldown a 0.5s en lugar de dar 2 cargas (skill sigue importando).
  > 2. Hacer que matar a un enemigo recupere medio cooldown (premia agresividad sin romper la mecánica).
  > 3. Si igual querés 2 cargas, conviene cambiarlo en el GDD primero.
  > ¿Cuál?"

---

## Regla 6 — Delegar a subagentes especializados por default

### Qué significa

Cualquier tarea cuyo dominio está cubierto por un agente en [`.claude/agents/`](../agents/) se delega vía la tool `Agent`. Claude principal actúa como **orquestador** (decide qué agente, con qué prompt, en qué orden, compone el resultado) — no como ejecutor de todo.

Cada subagente tiene su modelo asignado (Opus para diseño/análisis profundo, Sonnet para implementación volumétrica, Haiku para tareas mecánicas). Delegar correctamente significa **mejor calidad/costo** y **contexto principal limpio** para coordinar.

### Mapeo de dominios → agente

| Dominio | Agente |
| :--- | :--- |
| Diseño global, scope, pilares, evaluar features | `game-designer` |
| Combate moment-to-moment (Momentum, Furia, dash, bloqueo, hitboxes) | `combat-system` |
| Items, rarezas, refinamiento, fusión, crafteo, drops | `equipment-system` |
| Nivel, XP, árbol de skills, respec, stat final | `progression-system` |
| IA mobs R1-R3 (patrullaje, agresión, esquiva) | `enemy-ai` |
| Bosses R4 (patrones, fases, telegrafía obligatoria) | `boss-designer` |
| Ecos, perfiles IA, Gloria, ranking, matchmaking | `ecos-coliseum` |
| Validar DPS/TTK/curvas/economía/drop rates | `balance-engineer` |
| Diseño de zonas, etapas, encuentros, pacing | `level-designer` |
| UI/UX móvil, HUD, touch, ergonomía | `ux-mobile` |
| Prompts Midjourney/SD/Nano Banana | `art-prompt-engineer` |
| Naming, descripciones, lore, copy de UI | `narrative-lore` |
| Firebase/Supabase, persistencia, anti-cheat | `backend-architect` |
| GDScript idiomático, AnimationTree, físicas Godot 4, perf | `godot-expert` |

### Qué SÍ delega Claude principal (default)

- ✅ Implementación de cualquier feature multi-archivo (data + system + UI).
- ✅ Diseño de cualquier entidad de contenido (item, skill, enemy, boss, zone).
- ✅ Validación de números, balance, economía.
- ✅ Naming/lore de cualquier asset visible al jugador.
- ✅ Código GDScript no trivial (loops complejos, AnimationTree, autoloads, signals).
- ✅ UI screens y wiring de UI nuevo.

### Qué NO delega (lo hace Claude principal inline)

- ✅ Lookups simples — `Read`, `Grep`, `Glob` de 1-3 archivos.
- ✅ Edits triviales — 1-3 líneas, rename de variable local, fix de typo, ajuste de número exacto que Leo pidió.
- ✅ Preguntas conversacionales — clarificación de scope, decisiones de roadmap, recap.
- ✅ Meta-documentación — updates a `CLAUDE.md`, handoffs en `docs/handoffs/`, archivos en `.claude/docs/`.
- ✅ **Orquestación** — decidir qué agente recibe qué subtarea, ensamblar respuestas, presentar resultado a Leo.

### Cómo delegar bien

1. **Parallelizá cuando se pueda.** Si dos agentes pueden trabajar sin dependencia (ej. `narrative-lore` nombrando items + `equipment-system` codeando schemas), invocá ambos en **un solo mensaje con múltiples bloques `Agent`**.
2. **Secuencial cuando hay dependencia.** Si B necesita output de A (ej. `equipment-system` necesita los nombres de `narrative-lore` para crear los `.tres`), corré A → esperá → corré B.
3. **Prompt self-contained.** El agente arranca en frío. Incluí:
   - Qué hay que producir (output esperado: archivos, lista de decisiones, etc.).
   - Contexto del proyecto necesario (paths, GDD §, decisiones ya tomadas).
   - Qué NO debe hacer (out-of-scope, archivos a no tocar, agentes que harán otra parte).
   - Estimación de scope (1 archivo / multi-archivo / multi-fase).
4. **Mostrá el routing antes de spawnear más de 2 agentes.** Si el plan involucra 3+ agentes, comentále a Leo el routing breve antes de ejecutar para evitar perder trabajo si prefiere otro orden.

### Cuándo NO delegar aunque parezca aplicar

- 🛑 Si la tarea es genuinamente trivial (≤3 líneas, lookup puntual). Delegar acá agrega overhead sin valor.
- 🛑 Si Leo pidió explícitamente que vos lo hagas ("vos directamente sin agente").
- 🛑 Si estás en medio de una decisión interactiva con Leo (preguntar / aclarar) — primero resolvé la duda, después delegá.

### Ejemplos

**Caso A — Delegación correcta (paralelo):**

- Leo: "Implementá el sistema de drops por etapa."
- Claude principal:
  > Routing:
  > - `narrative-lore` (paralelo) → naming + descripciones de 4 materiales nuevos.
  > - `equipment-system` (paralelo) → MaterialData, DropTable, DropEntry, extender InventorySystem, DropSystem autoload.
  > - Después secuencial: `ux-mobile` → material toast UI; `balance-engineer` → validar pesos.
  >
  > [Spawnea narrative-lore + equipment-system en el mismo mensaje]

**Caso B — Delegación correcta (secuencial):**

- Leo: "Diseñá el boss R4 de la Zona 2."
- Claude principal:
  > 1. `narrative-lore` → nombre + lore del boss (necesario antes de definir patrones temáticos).
  > 2. `boss-designer` → patrones, fases, BossData .tres (recibe el naming/lore).
  > 3. `balance-engineer` → validar TTK contra player Lv25 con build estándar.

**Caso C — NO delegar (trivial):**

- Leo: "Cambiale el nombre a la variable `tmp` por `damage_amount` en player.gd línea 142."
- Claude principal: ediciónes inline. No invocar `godot-expert` para un rename.

**Caso D — NO delegar (orquestación):**

- Leo: "¿Por qué dropea el item antes de mostrar la loot card?"
- Claude principal: investiga inline con `Grep`/`Read`. Reporta hallazgo. No delegar la investigación a un agente cuando es 2-3 lookups.

### Excepción del modelo asignado

Cada agente declara su `model` en el frontmatter de `.claude/agents/<agente>.md`. Claude principal **no debe overridear el modelo** salvo que:
- Leo lo pida explícitamente para una tarea puntual.
- El agente esté en error y necesite re-runeo con otro modelo (informar a Leo antes).

---

## Resumen visual

```
┌─────────────────────────────────────────────────────────────────┐
│  Pedido de Leo                                                  │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
        ┌─────────────────────────────┐
        │ ¿Tengo dudas? (Regla #3)    │
        └────┬──────────────────┬─────┘
             │ Sí               │ No
             ▼                  ▼
       PREGUNTAR        ┌─────────────────────────┐
                        │ ¿Puede romper algo?     │
                        │ (Regla #2)              │
                        └────┬──────────────┬─────┘
                             │ Sí           │ No
                             ▼              ▼
                       AVISAR +      ┌────────────────────────┐
                       PROPONER      │ ¿Tengo algo mejor o    │
                                     │ complementario?        │
                                     │ (Regla #5)             │
                                     └────┬──────────────┬────┘
                                          │ Sí           │ No
                                          ▼              ▼
                                     AVISAR +     ┌──────────────────┐
                                     PREGUNTAR    │ ¿Implica borrar  │
                                                  │ algo grande?     │
                                                  │ (Regla #1)       │
                                                  └────┬─────────┬───┘
                                                       │ Sí      │ No
                                                       ▼         ▼
                                                  CONSULTAR  ┌─────────────────────────┐
                                                             │ ¿Hay agente             │
                                                             │ especializado?          │
                                                             │ (Regla #6)              │
                                                             └────┬──────────────┬─────┘
                                                                  │ Sí           │ No
                                                                  ▼              ▼
                                                              DELEGAR        EJECUTAR
                                                             vía Agent      (en español
                                                                            Regla #4)
```

---

## Aplicación a subagentes

Cuando se invoque cualquier subagente de `.claude/agents/`, las 6 reglas aplican igual (con una matización en Regla #6: un subagente no re-delega a otro subagente — termina su tarea y devuelve a Claude principal, que decide el siguiente paso). El prompt del agente incluirá automáticamente esta convención porque su `tools` están sujetas al mismo CLAUDE.md.

Si un subagente recibe una instrucción que viola una regla, debe actuar como Claude principal: pausar y avisar.

---

## Si una regla está mal o cambia

- Si Leo dice "ignorá esta regla por esta vez": OK, se aplica solo a esa acción puntual.
- Si Leo dice "esta regla ya no aplica" o "cambiala": actualizar **este archivo** y la sección correspondiente en `CLAUDE.md`. Versionar el cambio en este mismo archivo (sección "Changelog" abajo).

---

## Changelog

| Fecha | Cambio | Razón |
| :--- | :--- | :--- |
| 2026-05-21 | Versión inicial: 5 reglas (eliminar, no-romper, preguntar, español, mejoras) | Definidas por Leo al cerrar setup .claude/ inicial. |
| 2026-05-25 | +Regla 6 (delegar a subagentes por default) | Leo lo pidió al abrir Fase 2: aprovechar modelo asignado de cada agente sin perder calidad de código. |
