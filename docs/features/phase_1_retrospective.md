# Retrospectiva Fase 1 — Prototipo de Combate

**Período:** ~mayo 2026 (3 sesiones intensivas + iteraciones)
**Cerrada:** 24/05/2026
**Hito GDD §13:** *"Pelear se siente bien."* — Validado por Leo end-to-end.
**Fase siguiente:** 2 — Loop Básico (abierta 25/05/2026).

---

## 1. Objetivo y scope

Construir un **prototipo de combate jugable** con feel suficiente para que Leo (o un tester) diga "esto se siente bien, quiero seguir jugando" tras 5 minutos. Sin arte definitivo — cuadrados sobre fondo plano, joystick virtual, ataque, dash, bloqueo, Momentum como mecánica diferenciadora.

### Scope formal
- Player con movimiento + salto + dash con i-frames.
- Sistema de **Momentum** (core).
- **Furia** con decay.
- **Bloqueo** con cargas (escudo R1-R4).
- Telegrafía + ataque del enemy dummy.
- Feedback visual de impacto + Momentum ≥5x.
- Enemy dummy que ataca de vuelta.

---

## 2. Lo entregado

### Combate moment-to-moment
- ✅ Movimiento + salto + dash con i-frames.
- ✅ Ataque melee (sword/hammer) + ranged (bow/staff).
- ✅ **Bloqueo con cargas** (`ShieldComponent`, signal `hit_blocked`, freeze Momentum al absorber).
- ✅ **Telegrafía enemy** ("!" amarillo bouncing en último 40% del wind-up — iterado 2 veces hasta el feel correcto).
- ✅ **Hit-stop global** + **screen-shake** con decay (`HitStop`, `CameraShake` autoloads).
- ✅ **Game Over modal** + Reintentar (reseta autoloads + `reload_current_scene`).

### Sistemas / arquitectura
- ✅ `MomentumSystem` autoload (curva 1x-10x, +1/golpe, reset al recibir daño).
- ✅ `InventorySystem` (slots ARMA/ARMADURA/ESCUDO, equipar/desequipar).
- ✅ `HitStop`, `CameraShake` autoloads (sensible al tiempo via `Time.get_ticks_msec`).
- ✅ `StageSystem` orquesta runs con stages secuenciales.
- ✅ `GameConfig` con flag `PLATFORM_MODE` (PC vs MOBILE).

### Componentes
- ✅ `HealthComponent`, `HitboxComponent`, `HurtboxComponent`, `ShieldComponent`.
- Composición sobre herencia — reusados por player y enemies.

### UI
- ✅ HUD combat con HP / Furia / Momentum / Shield charges.
- ✅ Touch controls completo (joystick + 6 botones, auto-hide en PC).
- ✅ Inventario + equipo functional.
- ✅ Damage floaters (incluido `spawn_text` helper para "BLOCK!").

### Data
- ✅ Items, weapons, armors, shields, enemies como `.tres` en `resources/`.

### Bugfixes durante playtests
- Swing martillo facing izquierdo (rotación 180° vs espejado).
- Enemy muerto desvanece (antes bloqueaba proyectiles).
- Auto-jump con joystick (cambio de `just_pressed` a `is_pressed`).
- Touch HUD: 3 botones no se cargaban (.tscn con comentarios `#` rompía parser).
- `TouchButton` stuck al cerrar modal CanvasLayer (fix vía `InputEventAction` sintético + poll defensivo).

---

## 3. Lo cortado o postergado

- **Sin arte definitivo.** Sprites generativos (Midjourney/SD) postergados a Fase 3.
- **Sin audio.** No hay SFX/música — pipeline diferido.
- **Sin persistencia.** Items y progreso se pierden al cerrar el juego. `SaveSystem` para Fase 4-5.
- **Sin Coliseo / backend.** Toda la fase fue offline, single-player. Backend en Fase 4.
- **Sin enemies diferenciados por rareza.** Las rarezas (R1-R4) solo escalaban stats — no afectaban behavior. Quedó como pendiente formal de Fase 2 (resuelto el 25/05).

---

## 4. Decisiones técnicas duraderas

### Que se mantienen como canon
1. **Composición sobre herencia.** Todos los entities son `CharacterBody2D` + componentes (`HealthComponent`, etc.). Ninguna jerarquía profunda.
2. **Datos en `.tres`, lógica en `.gd`.** Cero hardcode de stats en código. ItemData/StageData/EnemySpawnEntry son Resources.
3. **Autoloads para sistemas globales.** MomentumSystem, InventorySystem, HitStop, CameraShake, StageManager, GameConfig. Cada uno con responsabilidad única.
4. **Signals antes que polling.** Si dos nodos se comunican, casi siempre la respuesta es una señal.
5. **State machine inline para enemies** (en lugar de framework dedicado). Suficiente para R1-R3; R4 boss probablemente requiere refactor a componente cuando se diseñe.
6. **Stick figure procedural** como placeholder. Soporta tints, scale, FX sin sprite assets — perfecto para iterar gameplay sin tocar arte.

### Decisiones tomadas en playtest (vs documento)
- **Hit-stop NO al recibir daño.** Sentía lag con multi-enemy. Solo al pegar y bloquear.
- **Screen-shake con rate-limit 1/seg al recibir daño** para no marear.
- **Telegrafía SOLO "!" amarillo bouncing** (sin tinte naranja del cuerpo, sin halo — Leo iteró 2 veces).
- **Bloqueo gasta carga al absorber, no al presionar.** Sin cargas, botón es no-op.
- **Tecla bloqueo = Ctrl izquierdo** (no Shift, que es dash).

---

## 5. Bugs y lecciones documentadas

### Godot 4 quirks descubiertos
1. **`.tscn` no soporta comentarios `#`.** El parser silenciosamente saltea el siguiente `[node]`. Síntoma: nodos faltantes sin error. Documentado en CLAUDE.md mental model y handoff Fase 1.
2. **TouchButton stuck con CanvasLayer modal.** El evento release se consumía antes de llegar al botón. Fix: emitir `InputEventAction` sintético en press/release + poll defensivo en `_process` con `process_mode = ALWAYS`.
3. **`Engine.time_scale` afecta todo** — cualquier sistema sensible al tiempo debe usar `Time.get_ticks_msec` para mediciones reales (patrón en `hit_stop.gd`).
4. **Edit tool del harness pierde tabs intermitentemente.** Workaround: PowerShell con `[char]9` para edits que requieren matchear líneas indentadas. (Lección de Fase 2 inicial, no Fase 1, pero relevante para retro técnica.)

### Lecciones de proceso
1. **Cerrar fase con foco supera "una feature más".** Las primeras 2 sesiones de Fase 1 acumularon scope (stages, rarezas, items, armas, ranged, AI fixes) sin cerrar el hito MVP. La sesión 3 (cierre) priorizó los 4 pendientes del playtest y validó "se siente bien" — eso desbloqueó Fase 2.
2. **Playtest > documento.** Varias decisiones (hit-stop, telegrafía, shake) salieron del playtest, no del GDD. La regla "gana el playtest" se aplicó fluida.
3. **Touch HUD desde temprano.** La flag `PLATFORM_MODE` permitió desarrollar y testear en PC sin romper mobile. Recomendado mantener este patrón.

---

## 6. Métricas

| Métrica | Valor |
| :--- | :--- |
| Sesiones intensivas | ~3 |
| Features grandes entregadas | 7 (movement, dash, momentum, bloqueo, telegrafía, hitstop+shake, GameOver) |
| Bugs CRITICAL fixeados durante playtest | 5 (facing, enemy invisible, auto-jump, .tscn comments, TouchButton stuck) |
| Archivos nuevos | ~25 |
| Subagentes invocados activamente | ux-mobile, combat-system, godot-expert (informal — la regla de "default delegar" llegó en Fase 2) |
| Doc de features | poco — Fase 1 priorizó código sobre doc. Patrón mejorado en Fase 2 con `docs/features/*` formal |

---

## 7. Riesgos identificados para Fase 2

1. **Scope creep del loop loot/refine/craft.** Tentación de meter UI épica de inventario, animaciones complejas. Mitigación: mantener placeholders, refinar feel en cada milestone.
2. **Balance roto por loot.** Drops escalan con Momentum (×2 en 10x). Si las drop tables se calibran mal, el farm óptimo destruye el ranking futuro. Mitigación: `balance-engineer` audita cada feature de loot/economía.
3. **Performance mobile con multi-enemy + drops + toasts.** Cada material drop instancia un nodo de toast. Cada enemy R3 tiene partículas. Mitigación: object pool para toasts (sugerencia archivada en `docs/sugerencias.md`).
4. **Refinamiento puede convertirse en RNG frustration.** GDD §5.6 da prob 10% para +10 — fail rate del 90% sin Pergamino. Mitigación: comunicar prob ANTES del intento (UI), permitir Pergamino visible siempre, mecánica de "casi" (bar de progreso visible aunque sea estocástica).
5. **El feel del combate puede degradarse al sumar enemies R2/R3.** Bloqueo del enemy puede sentirse "wall" si chance alta. Dodge R3 puede sentirse spammeable. Mitigación: smoke checks en playtest de cada round.

---

## 8. Patrón de trabajo establecido

### Lo que funcionó
- **Pillar-check antes de aceptar features.** Cada propuesta se mide contra los 4 pilares. Cortar es más barato que arrepentirse.
- **AskUserQuestion para decisiones de scope.** Leo decide rápido con opciones claras. Evita asumir y rehacer.
- **`/genera-resumen` al cerrar sesión.** Handoff en `docs/handoffs/LATEST.md` es la única forma de no arrancar en cero la siguiente sesión.
- **Playtest valida cada hito.** Sin playtest, no se cierra fase.

### Lo que se mejoró en Fase 2 inicial
- **Regla 6 (delegar a subagentes por default)** — agregada al abrir Fase 2 (25/05/2026). Cada agente tiene su modelo asignado; Claude principal orquesta.
- **`docs/features/*` formal por cada feature** — template seguido en `drops_milestone_a.md`, `rareza_diferenciacion.md`.
- **TaskCreate / TaskUpdate** para trackear progreso de features multi-step.

### Lo que sigue siendo riesgo
- **Sin git inicializado.** Cambios viven en working tree, sin snapshots. Si algo se rompe, no hay rollback. Recomendación: inicializar git en cuanto Leo apruebe (pendiente desde fin de Fase 1).
- **Tests cubren fórmulas pero no integración.** DropSystem.register_enemy y similar requieren tests de SceneTree — pendiente.

---

## 9. Recomendación para Fase 2

**Path sugerido:**
1. Cerrar Milestone B de drops (items por stage clear + loot card).
2. Refinamiento backend (sin UI) → habilita "mejorar" del loop.
3. Crafteo backend → completa la matriz materiales→item.
4. UI unificada de inventario/refinamiento/crafteo (requiere playtest iterativo).
5. Boss R4 "Guardián de la Maleza" (opcional adelantado de Fase 3) — climax de zona 1.
6. Playtest 30 min para validar hito "el loop engancha".

**Anti-recomendación:**
- NO empezar Fase 3 (skills tree, elementos, sets) hasta cerrar el loop core de Fase 2. Cada capa nueva sin validar feel anterior multiplica el debt de iteración.

---

## 10. Cierre

Fase 1 cerró su hito GDD §13. Lo más valioso que dejó:
- **Una base de combate que se siente.** El feedback de hit-stop + shake + telegrafía + bloqueo es legible y responsivo.
- **Patrón de arquitectura limpio** (componentes + autoloads + .tres) que escala a Fase 2/3 sin reescritura.
- **Confianza en el playtest como source of truth** sobre el GDD escrito.

> *"Si lo que diseñé acá no se siente bien al jugarlo, gana el playtest, no el documento."* — Leo
>
> Fase 1: pasó el test. Fase 2: a construir el resto del juego sobre cimientos sólidos.
