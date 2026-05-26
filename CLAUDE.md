# Knights Action — Guía para Claude

> **🔥 ANTES DE NADA:** leé el handoff de la sesión anterior en [`docs/handoffs/LATEST.md`](docs/handoffs/LATEST.md).
>
> Un hook `SessionStart` en `.claude/settings.json` debería volcarlo automáticamente al inicio. Si por alguna razón no aparece en tu contexto (hook deshabilitado, error de shell, etc.), **leelo manualmente** con la tool Read antes de hacer cualquier otra cosa. Es la única forma de no arrancar en cero.

> Este archivo es lo segundo que leés. Contiene la **identidad del proyecto**, **reglas operativas no-negociables**, **pilares no-negociables** y **mapa de navegación**. Antes de tocar código, leelo entero.

---

## 1. Identidad del Proyecto

- **Nombre:** Knights Action (nombre en clave).
- **Director Creativo y único desarrollador:** Leonardo (Leo).
- **Género:** Action-RPG / Plataformas 2D Side-Scroller con meta-juego competitivo asincrónico.
- **Inspiración estética:** *Knights & Dragons*, *Dead Cells*, *Hollow Knight*. Más movimiento que K&D, menos roguelike que Dead Cells.
- **Fantasía del jugador:** *"Soy un guerrero que crece zona a zona, perfecciono mi build y mi técnica, y desafío a ecos de otros guerreros para ganar Gloria."*
- **Plataforma objetivo:** Móvil (iOS/Android). Se desarrolla y testea en PC con Godot.
- **Motor:** **Godot 4.6** (GDScript). Rendering Forward Plus, Jolt Physics para 3D (no usado en MVP), D3D12 en Windows.
- **Pipeline:** AI-first. Claude Code programa, IA generativa produce arte/audio.

**Source of truth de diseño:** [`GDD.md`](GDD.md) (v2.1). Si algo no figura ahí, no es canon. Si encontrás contradicción entre código y GDD, **gana el GDD**, salvo que el playtest haya invalidado la decisión (ver §16 del GDD: "gana el playtest, no el documento").

---

## 2. Reglas de Trabajo (NO NEGOCIABLES)

Las **7 reglas operativas** de Leo. Aplican a Claude principal y a TODO subagente invocado. Detalle completo con ejemplos en [`.claude/docs/reglas-de-trabajo.md`](.claude/docs/reglas-de-trabajo.md).

### Regla 1 — Crear y editar SÍ, eliminar PREGUNTA
Tenés permiso libre para crear y modificar archivos/carpetas. **Pedí confirmación antes de:**
- Borrar archivos o carpetas (cualquier `rm`, `Remove-Item`).
- Eliminar **bloques grandes de código** en un Edit: funciones enteras, clases, secciones lógicas de 5+ líneas que conformaban una feature, exports de Resources.

Modificar líneas sueltas o renombrar variables locales es libre.

### Regla 2 — Si algo puede romper el juego, frená y avisá
Si lo que te piden podría romper el sistema (firma pública de autoload, schema de Resource, fórmulas canónicas, GDD), el diseño (pilares, fantasía), o el flujo de desarrollo (engine, plugins, GDExtension): **no lo hagas de inmediato**. Avisá específicamente qué riesgo detectás y proponé al menos una alternativa antes de esperar decisión.

### Regla 3 — Si tenés dudas, preguntá. No asumas.
Antes de implementar algo ambiguo, preguntá. **Excepción:** si la respuesta está **explícita** en GDD, glossary, formulas o cualquier `.md` del proyecto, procedé sin preguntar (citando la fuente).

Preferí `AskUserQuestion` para preguntas con opciones; inline para abiertas. Preguntá **antes** de empezar, no después de asumir y avanzar.

### Regla 4 — Español por default, inglés cuando ahorra tokens reales
**Comunicación con Leo:** español por default. **Cambio a inglés OK** si:
- Respuesta es ack corto (Done, OK, Failed, "no changes", "all tests pass").
- Terminología técnica densa donde traducir suma tokens (stack traces, paths, API names, error messages).
- La frase en inglés ahorra ≥25% tokens vs español sin perder precisión.

**Siempre español (no flexibilizable):** GDD, docs de referencia (`.claude/docs/*`, `docs/features/*`), comentarios en código GDScript, copy de UI del juego, handoffs en `docs/handoffs/`, mensajes de commit/PR.

**Nombres en código** (funciones, variables, clases, archivos `.gd`): inglés por estándar GDScript. Nombres de contenido del juego (zonas, items, materiales, etc.): español.

**Criterio final:** que Leo entienda al toque y que el reporte de "salió bien / no salió" sea claro. Si en duda → español.

### Regla 5 — Si tenés algo mejor o complementario, avisá y preguntá
Cuando Leo te pide X y vos detectás una mejora, complemento útil, riesgo, o subdivisión natural → **no la implementes por iniciativa propia**. Decíla y ofrecé opciones (solo X / X + mejora / X + complemento / etc.). Leo elige.

Aplica especialmente cuando proponés:
- Skills/items con efectos extra que no se pidieron.
- Refactors no solicitados.
- "Mejoras de calidad" que no estaban en scope.

### Regla 6 — Delegar a subagentes especializados por default
Cualquier tarea que tenga un agente específico en [`.claude/agents/`](.claude/agents/) (combat, equipment, enemy-ai, boss-designer, ux-mobile, narrative-lore, balance-engineer, godot-expert, level-designer, art-prompt-engineer, ecos-coliseum, backend-architect, progression-system, game-designer) **se delega vía `Agent` tool**. Cada subagente tiene su modelo asignado (más capaz o más rápido según el dominio) — Claude principal NO debe absorber tareas que pertenecen a un agente especializado, aunque las pueda hacer.

**Qué SÍ se delega (default):**
- Diseño/implementación de items, skills, enemies, bosses, zonas → agente correspondiente.
- Sistemas core (combate, equipo, progresión, coliseo, backend) → agente correspondiente.
- Validación de balance, naming/lore, UI mobile, arte (prompts), código idiomático Godot.
- Implementaciones multi-archivo o que crucen capas (data + system + UI).

**Qué NO se delega (lo hace Claude principal):**
- Lookups simples (Read/Grep/Glob de un archivo).
- Ediciones triviales (1-3 líneas, rename de variable local, fix de typo).
- Preguntas conversacionales / clarificación con Leo.
- Updates a `CLAUDE.md`, handoffs, `.claude/docs/*` (meta-documentación de proceso).
- Orquestación: decidir qué agente recibe qué subtarea y cómo se compone el resultado.

**Cómo delegar:**
- Si varios agentes aplican en paralelo (ej. `narrative-lore` para nombres + `equipment-system` para código), invocarlos en **un solo mensaje con múltiples bloques `Agent`** (paralelismo real).
- Si hay dependencia (B necesita output de A), secuencial.
- Prompt al agente debe ser **self-contained** (paths, GDD §, decisiones ya tomadas, lo que NO debe hacer). Asumí que el agente arranca en frío.

**Calidad no se sacrifica.** Cada agente tiene el modelo apropiado (Opus para diseño/análisis, Sonnet para implementación volumétrica, Haiku para tareas mecánicas). Si Claude principal "podría hacerlo igual", igual delegá — la separación de roles mantiene contexto limpio y aprovecha el modelo correcto.

Detalle completo en [`.claude/docs/reglas-de-trabajo.md`](.claude/docs/reglas-de-trabajo.md) §6.

### Regla 7 — Default Caveman (estilo de comunicación)
Default del proyecto: **caveman full** en respuestas a Leo. Comentarios en código: **caveman lite**. Detalle completo en [`.claude/docs/estilo-caveman.md`](.claude/docs/estilo-caveman.md).

**Resumen de intensidad por contexto:**
- Chat a Leo + outputs de subagentes → **full** (sin artículos, fragmentos OK).
- Comentarios en `.gd` y mensajes de commit → **lite** (sin filler, gramática completa).
- Plantillas estructuradas (`## Cierre`, `OUTPUT ESPERADO`), code blocks, errores quoteados → **intactos**.
- Docs de referencia (`.claude/docs/*`, `docs/features/*`, handoffs, GDD, CLAUDE.md) → **normal** (precisión > brevedad).
- Copy de UI del juego → sigue `narrative-lore`, NO caveman.

**Combina con regla #4 (español):** elimino filler español (`realmente`, `básicamente`, `simplemente`), pleasantries (`claro`, `de una`) y hedging (`probablemente`). Términos canónicos del juego (Furia, Momentum, Gloria, Eco) nunca abreviados.

**Auto-pausa caveman** para: warnings, ops irreversibles, multi-step ambiguo, aplicación de reglas #2/#5. Vuelve a caveman tras la parte clara.

**Desactivación:** Leo escribe `normal mode` / `stop caveman` (temporal) o `/caveman lite|ultra` (cambia intensidad).

### Flujo de decisión rápido
```
Pedido → ¿Dudas? → preguntar (#3)
       → ¿Riesgo? → avisar + proponer (#2)
       → ¿Mejora extra? → avisar + preguntar (#5)
       → ¿Borrar grande? → consultar (#1)
       → ¿Hay agente especializado? → delegar (#6)
       → Ejecutar en español (#4) modo caveman full (#7)
```

---

## 3. Los 4 Pilares (NO NEGOCIABLES)

Toda decisión de diseño, todo PR, toda feature, se mide contra estos 4 pilares. Si una propuesta **contradice** alguno, se descarta sin discusión. Si **no refuerza ninguno**, se cuestiona seriamente.

1. **Mi build importa, mi skill también.** Ni puro loot, ni puro reflejos. La intersección.
2. **Cada muerte enseña algo.** Nada debe sentirse aleatorio o injusto.
3. **El ranking premia al que mejora, no al que farmea.** El tiempo invertido cuenta menos que la habilidad.
4. **5 minutos bastan, 5 horas también.** Sesiones cortas con profundidad opcional.

Detalle completo y ejemplos en [`.claude/docs/pilares.md`](.claude/docs/pilares.md). Antes de aceptar cualquier feature nueva, corré mentalmente `/pillar-check`.

---

## 4. Estado Actual del Proyecto

- **Fase:** 3 — Sistemas RPG Completos (ver §13 del GDD).
- **Hito a alcanzar:** *"Una zona completa es jugable de principio a fin."*
- **Fase 1 CERRADA** (24/05/2026) — hito "Pelear se siente bien" validado por Leo. Retro en `docs/features/phase_1_retrospective.md`.
- **Fase 2 CERRADA** (25/05/2026) — hito "El loop pelear → lootear → mejorar engancha" validado por Leo end-to-end. Backup completo en `backups/fase_2_cerrada_2026-05-25.tar.gz`. Retro pendiente en `docs/features/phase_2_retrospective.md`.
- **Lo que ya existe (heredado de Fases 1 + 2):**
  - **Combate moment-to-moment:** movimiento, salto, dash con i-frames, ataque melee + ranged, bloqueo con cargas (R2/R3 con `EnemyBlockHandler`), telegrafía enemy, hit-stop + screen-shake, Game Over + Reintentar.
  - **Sistemas core:** `MomentumSystem`, `InventorySystem`, `HitStop`, `CameraShake`, `GameConfig`, `StageSystem`, `DropSystem`, `UpgradeManager`, `CraftingSystem`.
  - **Componentes:** `HealthComponent`, `HitboxComponent`, `HurtboxComponent`, `ShieldComponent`, `EnemyBlockHandler`, `PlayerStatsComponent`.
  - **UI:** HUD combat completo, touch controls, `InventoryScreen` con sección materiales, `RefinementScreen`, `CraftingScreen`, `LootCardScreen`, `MaterialToastContainer`.
  - **Data layer:** Items R1-R3, materiales, drop tables por stage y por rareza, recipes de crafteo, StageData con tints/platforms, BossData del Guardián.
  - **Enemies:** 4 clases × 4 rarezas con comportamientos diferenciados (R2 bloquea cargas reales, R3 dashea + skill, R4 boss con 4 cargas + 5 patrones + gap-close dash).
  - **Boss R4:** "El Guardián de la Maleza" integrado a E4 con escudo regenerable y 2 fases.
  - **Items independientes:** drops/crafts hacen `duplicate(true)` — cada item del inventario es instancia propia.

- **Lo que falta para cerrar Fase 3 ("una zona completa es jugable de principio a fin"):**
  - **Árbol de Skills** (~30 nodos, 3 ramas: Guerrero, Mago, Ágil). Sistema de puntos por level-up + respec.
  - **Sistema Elementos** Tierra/Fuego/Agua con triángulo (×1.5 ventaja / ×0.66 desventaja). Aplica a daño y resistencias.
  - **Set Bonuses** (afinidad de equipo): 2pc mismo elemento = bonus pasivo; 3pc = habilidad pasiva única.
  - **Momentum integrado en UI** finalizada (HUD visual definitivo).
  - **Completar zona 1** — actualmente 3 stages combate + boss (4 total). GDD §7.1 pide 5-8 stages + boss. Sumar 2-4 stages más con pacing coherente.
  - **Arte zona generado por IA** (Midjourney/SD/Nano Banana via `art-prompt-engineer`). Reemplaza StickFigure procedural.
  - **Parallax + sprites** enemies + sprites boss.
  - **Música zona (1 track) + música combate** (audio pipeline nuevo).
  - **Sistema de Oro** (placeholder en refinamiento/crafteo — implementar real).
  - **Pool items R3 completo** (falta armor R3 y escudo R3).

Cuando pidan `/status`, esta sección y el plan de fases en [`.claude/docs/fases.md`](.claude/docs/fases.md) son la fuente.

---

## 5. Stack Técnico y Convenciones

- **Motor:** Godot 4.6 (`config/features=PackedStringArray("4.6", "Forward Plus")`).
- **Lenguaje:** GDScript (NO C#). Si te piden algo que solo se resuelve bien con GDExtension, **avisá antes de meterlo** — el dev es solo, agregar C++ no escala.
- **Arquitectura:** **Composición por componentes** (`HealthComponent`, `HitboxComponent`, etc.) sobre `Node`/`Node2D`. Evitá herencia profunda. Detalle: [`.claude/docs/arquitectura.md`](.claude/docs/arquitectura.md).
- **Datos:** Items, enemigos, skills y zonas se modelan como **Resources `.tres`** (custom `Resource` classes) en `resources/`. Lógica en `scripts/`, datos en `resources/`. Nunca hardcodear stats de items en `.gd`.
- **Autoloads / Singletons:** Sistemas globales (MomentumSystem cuando exista, GameState, SaveSystem, ColiseumService, UpgradeManager) viven en `scripts/systems/` y se registran como autoload en `project.godot`. Detalle: [`scripts/systems/README.md`](scripts/systems/README.md).
- **Naming:**
  - Archivos `.gd` y `.tscn`: `snake_case`.
  - `class_name`: `PascalCase` (ej. `HealthComponent`).
  - Variables/funciones: `snake_case`.
  - Constantes: `SCREAMING_SNAKE_CASE`.
  - Señales: verbo en pasado o evento puntual (`died`, `health_changed`, `momentum_increased`).
- **Comentarios en código:** **Español**, alineado con cómo escribe Leo. Solo cuando el "porqué" no se deduce del código. No documentar el "qué" obvio.
- **Estilo completo:** [`.claude/docs/convenciones-gdscript.md`](.claude/docs/convenciones-gdscript.md).

---

## 6. Mapa del Repo

```
knights-action/
├── CLAUDE.md                 ← Este archivo. Leelo primero.
├── GDD.md                    ← Source of truth de diseño (v2.1).
├── project.godot             ← Config Godot 4.6.
├── icon.svg                  ← Ícono.
├── .claude/
│   ├── settings.json         ← Permisos y config del harness.
│   ├── agents/               ← 14 subagentes especializados.
│   ├── commands/             ← 11 slash commands del proyecto.
│   └── docs/                 ← Reglas-de-trabajo, estilo-caveman, pilares, arquitectura, fórmulas, glosario, etc.
├── docs/
│   ├── features/             ← Una entrada por feature implementada (§12.1 GDD).
│   └── handoffs/             ← Resúmenes entre sesiones. LATEST.md es lo primero que leés.
├── scenes/
│   ├── enemies/              ← .tscn de enemigos.
│   ├── player/               ← player.tscn.
│   └── world.tscn            ← Escena principal de prueba.
├── scripts/
│   ├── player.gd             ← Lógica del jugador.
│   ├── components/           ← Componentes reutilizables (Health, Hitbox, etc.).
│   ├── systems/              ← Autoloads / singletons globales.
│   └── data/                 ← Clases de datos (custom Resource subclasses).
├── resources/                ← .tres de items, enemigos, skills, zonas.
└── tests/                    ← Tests unitarios (fórmulas, combate).
```

Mapa más detallado en [`.claude/docs/estructura-carpetas.md`](.claude/docs/estructura-carpetas.md).

---

## 7. Flujo Operativo de Implementación

### 7.1 Antes de implementar cualquier feature

1. **Leé la sección relevante del GDD** y citala (ej. "según GDD §4.3 Momentum...").
2. **Corré pillar-check mental:** ¿esta feature refuerza al menos uno de los 4 pilares? Si no, paráte y avisá a Leo.
3. **Verificá si toca un sistema existente.** Si va a romper algo, decilo antes.
4. Si la feature es no trivial (>1 archivo nuevo o cambios en `player.gd`/sistemas core), **proponé un plan corto antes de codear**.

### 7.2 Mientras implementás

- **Composición sobre herencia.** Si necesitás un comportamiento nuevo, primero pensá si es un componente reutilizable.
- **Datos en `.tres`, lógica en `.gd`.** Nunca hardcodear balance en código.
- **Señales antes que polling.** Si dos nodos necesitan comunicarse, casi siempre la respuesta es una señal.
- **Una responsabilidad por archivo.** Si un script pasa de ~200 líneas o mezcla preocupaciones, partilo.
- **Cuidá el target móvil.** Cada vez que agregues algo: ¿esto correrá fluido a 60fps en un mid-range Android? Evitá particle counts altos, instancias por frame, etc.

### 7.3 Después de implementar

1. Documentá la feature en `docs/features/<nombre>.md` siguiendo el template ([`docs/features/README.md`](docs/features/README.md)).
2. Si la feature tiene una fórmula o RNG, **escribí un test unitario** en `tests/` (§12.1 GDD).
3. Si cambiaste números/curvas, actualizá [`.claude/docs/formulas.md`](.claude/docs/formulas.md).
4. **No** marques el trabajo como terminado sin haber abierto Godot y probado al menos el flujo feliz (o avisá explícitamente: "no pude probar en Godot, validá vos").

### 7.4 Acciones destructivas

Aplicación práctica de la **Regla 1** de §2:
- Nunca borres `scenes/`, `resources/` ni `scripts/` sin pedir confirmación.
- Antes de renombrar un archivo, chequeá referencias (`.uid`, `[ext_resource path=]`, `preload(...)`, `load(...)`) — un rename incorrecto es equivalente a un delete silencioso.
- `git push`, force push, branch delete: pedí confirmación siempre.
- Eliminar exports de un Resource ya usado en `.tres` existentes: consultar (pérdida de datos).

---

## 8. Cómo trabajar con agentes y comandos

### Subagentes disponibles (en [`.claude/agents/`](.claude/agents/))

Invocá vía `Agent` con el `subagent_type` apropiado. Cada agente tiene un dominio claro:

| Agente | Cuándo invocarlo |
| :--- | :--- |
| `game-designer` | Decisiones de diseño global, scope, pilares, evaluar features nuevas. |
| `godot-expert` | GDScript idiomático, performance, AnimationTree, físicas Godot 4. |
| `combat-system` | Momentum, Furia, dash, bloqueo, hitboxes, frames de inv. |
| `equipment-system` | Items, rarezas, refinamiento, fusión, crafteo, slots. |
| `progression-system` | Nivel, XP, árbol de skills, respec, fórmula de stats final. |
| `enemy-ai` | Comportamiento de mobs PvE (R1-R3): patrullaje, agresión, esquiva. |
| `boss-designer` | Bosses R4: patrones, fases, telegrafía obligatoria. |
| `ecos-coliseum` | Sistema de Ecos, 4 perfiles IA, Gloria, ranking, asincrónico. |
| `balance-engineer` | Validar curvas, simular DPS, TTK, economía de drops. |
| `level-designer` | Diseño de zonas, etapas, encuentros, pacing. |
| `ux-mobile` | UI/UX móvil, HUD, controles touch, ergonomía. |
| `art-prompt-engineer` | Prompts para Midjourney/SD/Nano Banana consistentes. |
| `narrative-lore` | Naming, descripciones de items, lore del bestiario. |
| `backend-architect` | Firebase/Supabase, persistencia de Ecos, anti-cheat. |

**Cuándo NO usar un agente:** preguntas simples, lookups de un archivo, ediciones triviales. Los agentes son para tareas de varios pasos o cuando se necesita la voz especializada del rol.

### Slash commands disponibles (en [`.claude/commands/`](.claude/commands/))

| Comando | Qué hace |
| :--- | :--- |
| `/feature` | Implementa una feature del GDD de punta a punta (plan → código → tests → doc). |
| `/design-item` | Crea un nuevo item (arma/armadura/escudo) con afijos y como `.tres`. |
| `/design-enemy` | Crea un nuevo enemigo R1-R3 con stats, IA y `.tscn`. |
| `/design-boss` | Crea un boss R4 con patrones telegrafiados. |
| `/design-skill` | Crea una skill nueva (costo de Furia, efecto, asignable a slot). |
| `/balance-check` | Audita números: DPS, TTK, economía, curva de XP, drop rates. |
| `/pillar-check` | Valida una propuesta contra los 4 pilares. |
| `/status` | Resume estado actual del proyecto y sugiere próximo paso por fase. |
| `/new-zone` | Plantilla para diseñar una zona PvE completa. |
| `/playtest-log` | Captura feedback de playtest y lo conecta con el GDD. |
| `/genera-resumen` | Genera handoff de la sesión actual en `docs/handoffs/` + actualiza `LATEST.md`. Correlo al cerrar sesión. |

---

## 9. Glosario Rápido

(Detalle completo en [`.claude/docs/glossary.md`](.claude/docs/glossary.md).)

- **Furia** — Recurso para skills. Solo se gana atacando (+10/golpe). Decae si no atacás.
- **Momentum** — Multiplicador de combate (1x–10x). +1 por golpe, reseteo al recibir daño. Escala daño, drops y Furia.
- **Gloria** — Puntos de ranking del Coliseo. Todos arrancan en 1000.
- **Eco** — Copia IA de un personaje real subido al backend. Lo que peleás en el Coliseo.
- **Piedras de Resonancia** — Material que se consume al intentar refinamiento (+1 a +10).
- **Pergamino de Protección** — Consumible que evita la pérdida de nivel al fallar +8/+9/+10.
- **Afinidad de Equipo** — Bonus por equipar piezas del mismo elemento (2pc / 3pc).
- **Eco Profundo** — Modo +20 niveles de una zona ya completada, drops exclusivos.

---

## 10. Fórmulas Críticas

(Tabla completa en [`.claude/docs/formulas.md`](.claude/docs/formulas.md). Estas son las que se referencian todo el tiempo.)

- **Momentum:** `daño_total = daño_base * (1 + 0.05 * momentum)` — En 10x = ×1.5.
- **Drop rate:** `drop_rate = base * (1 + 0.1 * momentum)` — En 10x = ×2.
- **Refinamiento:** `stat_final = stat_base * (1 + 0.05 * nivel_refinamiento)` — Cap +10 = ×1.5.
- **XP por nivel:** `xp_requerida = 100 * nivel^1.5`.
- **Ventaja elemental:** ×1.5; desventaja: ×0.66.
- **Stats finales del personaje:** `stats_base(nivel) + equipo + bonus_skills + bonus_set`.

---

## 11. Anti-patrones a evitar

- ❌ Agregar features porque "estaría bueno". Releé pilares. (§14 Riesgo: scope creep.)
- ❌ Hardcodear stats de items o enemigos en `.gd`. Va en `.tres`.
- ❌ Mockear cosas para tests sin avisar — los tests del proyecto golpean a las clases reales.
- ❌ Inventar nombres de archivos, autoloads o señales que no existen. Verificá con `Grep`/`Read` antes.
- ❌ Romper la separación componente/escena/sistema. Si dudás, preguntá.
- ❌ Cambiar el GDD sin que Leo lo apruebe. Si el playtest invalidó algo, **proponé** el cambio, no lo apliques unilateralmente.
- ❌ Usar C#/GDExtension sin alerta previa.
- ❌ Generar arte/audio "placeholder" complejo cuando un cuadrado de color basta — estamos en Fase 1.

---

## 12. Cuando algo no esté claro

Aplicación práctica de la **Regla 3** de §2:
- **Diseño:** preguntale a Leo antes de inventar.
- **Implementación técnica:** podés decidir, pero documentá la decisión en `docs/features/<nombre>.md` con una sección "Decisiones técnicas y por qué".
- **Conflicto entre GDD y código existente:** flagueá al usuario, no decidas solo.
- **Conflicto entre dos secciones del GDD:** flagueá al usuario y proponé una resolución.

---

## 13. Recordatorio final

Este es un proyecto de **un solo desarrollador** apoyado fuertemente en IA. Eso significa:

- **Velocidad importa, pero el burnout es real.** No prometas más de lo que se puede entregar. Sprints cortos.
- **El GDD es vivo.** Si tras playtest algo no funciona, se cambia y se versiona.
- **La consistencia visual/sistémica es frágil.** Usá el `art-prompt-engineer` para no derivar; usá `balance-engineer` para no romper economía.
- **Cada línea de código debe servir al jugador.** Si no, ¿por qué la escribiste?

> *"Si lo que diseñé acá no se siente bien al jugarlo, gana el playtest, no el documento."* — Leo
