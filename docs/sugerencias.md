# Sugerencias / Backlog de ideas

Archivo vivo. Cualquier idea, mejora, polish o feature futura que NO entre al sprint actual va acá. **No es source of truth de diseño** — son ideas que Leo revisa cuando tenga aire para decidir qué entra al GDD.

**Formato:** cada entrada lleva fecha + origen + clasificación + descripción + por qué importa. Si Leo aprueba, se mueve al GDD o a un feature spec.

**Clasificación:**
- 🎨 polish / feel
- ⚙ sistémico / arquitectura
- 📊 balance
- 🎮 nueva feature
- 🐛 bug menor / cleanup técnico
- 📚 doc / lore

---

## 26/05/2026

### ✅ BUG RESUELTO — `PlayerProgression.get_tree()` chocaba con `Node.get_tree()`
**Fecha:** 26/05/2026 (apertura sesión)
**Causa raíz:** `progression-system` agente nombró `func get_tree() -> SkillTree` en el autoload `PlayerProgression extends Node`. Choca con `Node.get_tree() -> SceneTree` nativo. Godot lo trató como warning-as-error y no carga el script.

**Error reportado por Leo:**
```
Línea 134: The function signature doesn't match the parent. Parent signature is "get_tree() -> SceneTree".
Línea 134: The method "get_tree()" overrides a method from native class "Node". This won't be called by the engine and may not work as expected. (Warning treated as error.)
```

**Fix aplicado:** renombrar `get_tree()` → `get_skill_tree()` en `player_progression.gd` + actualizar 5 callsites en `skill_tree_screen.gd`.

**Lección canon:** **agentes nunca deben nombrar métodos que pisan APIs nativas de la clase padre.** Métodos a evitar en autoloads que extienden `Node`: `get_tree`, `get_parent`, `get_node`, `get_children`, `get_owner`, `is_inside_tree`, etc. Si el dominio del método sugiere algo así, **prefijar con el contexto** (`get_skill_tree`, `get_recipe_tree`, etc.). Aplicar a todos los autoloads + componentes que extienden Node nativo.

---

## 25/05/2026

### ⚙ Cap a 1.0 en fórmula drop_rate → convertir overflow en bonus count
**Origen:** `balance-engineer` (audit Milestone A drops).
**Descripción:** la fórmula GDD §111 `final_chance = base × (1 + 0.1 × momentum)` puede dar valores > 1.0 con Momentum alto + drop_chance base alto (ej. `hierba_antigua` 0.60 × 2.0 = 1.20 → cap a 1.0). El cap "desperdicia" Momentum extra en commons.
**Propuesta:** en lugar de cappear a 1.0, convertir el overflow en chance de +1 count. Ej. `1.20` → 1 garantizado + 20% chance de un segundo. Mantiene la estocasticidad y premia Momentum 10x más allá del cap.
**Por qué importa:** refuerza pilar #3 (skill > farmeo) — Momentum alto siempre tiene valor incremental, no se "saturna".
**Decisión necesaria:** Leo. Implica cambio menor en `DropTable.roll()` y posiblemente en la fórmula del GDD §111.

### 🐛 HURT state en `enemy.gd` sin usar
**Origen:** `enemy-ai` (diferenciación R1/R2/R3).
**Descripción:** el enum `State` tiene `HURT` pero ningún código lo activa ni maneja (preexistente, no causado por enemy-ai). El comentario sugiere que era para i-frames del enemy.
**Propuesta:** elegir entre (a) implementar i-frames del enemy al recibir daño (mini-stun + invulnerabilidad breve), (b) limpiar el enum.
**Por qué importa:** ruido en el código + decisión pendiente sobre feel del combate (si pegarle al enemy "stagger-locks", el combate se siente más pegajoso vs si los enemies tienen i-frames).

### 🎮 Distribución de rarezas en stages 1, 3, 4
**Origen:** Claude principal + `enemy-ai`.
**Descripción:** solo `zona1_etapa_2.tres` tiene mix R1/R2/R3 explícito. Stages 1, 3 y 4 siguen con composición original (sin `material_drops` por entry — usan fallback de stage).
**Propuesta:** revisar las 4 stages con `level-designer` para una distribución coherente:
- Etapa 1: 100% R1 (introducción al combate básico).
- Etapa 2: mix R1/R2/R3 (ya hecho).
- Etapa 3: R2 dominante + 1-2 R3.
- Etapa 4: R3 dominante + miniboss R3 reforzado (preludio al boss real).
**Por qué importa:** pacing pedagógico de la zona. Pilar #2 (cada muerte enseña — el jugador debería ver los tells de R2/R3 progresivamente).

### 🎨 Sprites diferenciados por rareza (cuando llegue arte definitivo)
**Origen:** Claude principal (doc enemies).
**Descripción:** ahora la diferenciación visual de R2/R3 es por `modulate` tint + scale sobre StickFigure procedural. Cuando arranque el pipeline de arte, podría haber sprites únicos por (clase × rareza).
**Propuesta:** delegar a `art-prompt-engineer` cuando Leo dé luz verde a Fase 3 (arte de zona). Mantener tints como fallback siempre.
**Por qué importa:** Fase 5 lanzamiento.

### 🎨 SFX por evento de combate / loot
**Origen:** transversal (toast UI, bloqueo enemy, dodge R3, skill R3, pickup material).
**Descripción:** no hay pipeline de audio en Fase 2. Cuando arranque, hay una lista clara de eventos que necesitan SFX:
- Pickup de material (1 SFX por rareza del material).
- Bloqueo del enemy R2 (sonido sordo + chasquido metálico).
- Dodge R3 (whoosh corto).
- Skill R3 telegrafiada (zumbido grave durante el wind-up).
- Refinamiento +N exitoso vs fallido.
- Game Over.
**Por qué importa:** Fase 5. Por ahora documentar para que no se pierdan en el backlog mental.

### ✅ NICE-TO-HAVE InventorySystem — APLICADOS 25/05/2026
**Origen:** `godot-expert` (review Milestone A).
**Resueltos:**
1. ~~`add_material(count <= 0)` no valida~~ → early return implementado.
2. ~~Signal `material_removed(material, count)`~~ → `signal material_removed(id: StringName, count: int)` agregado + emitido en `remove_material`.
3. ~~`reset()` opcionalmente emite signal~~ → parámetro `quiet: bool = true` agregado; pasar `false` emite `materials_changed`.

### 🐛 StageManager.reset() no resetea `_is_pending`
**Origen:** `godot-expert` (durante tests integración DropSystem, 25/05/2026).
**Descripción:** `StageManager.reset()` limpia `_stages`, `_current_index`, `_alive_count`, `_is_transitioning`, `_registered_enemies` — pero NO toca `_is_pending`. Si se llama `reset()` con `_is_pending = true` y luego `configure()` + `start_run()`, el estado de pending queda inconsistente hasta que `_enter_stage_pending(0)` lo pise.
**Riesgo:** bajo. `start_run()` actualmente pisa `_is_pending = true` igual. En producción solo se manifestaría si alguien llama `request_combat_start()` después de un `reset()` sin `start_run()` intermedio.
**Propuesta:** agregar `_is_pending = false` a `StageManager.reset()`. 1 línea.
**Por qué importa:** robustez para futuros refactors del flujo de runs (ej. "abandonar run" que llame reset sin start_run).

### ⚙ Drop tables por enemy específico (no solo por rareza)
**Origen:** Claude principal (extensión natural).
**Descripción:** hoy `EnemySpawnEntry.material_drops` puede apuntar a una tabla por rareza (lo que hicimos). Para variedad futura, podríamos tener "Madera Ancestral" que solo dropea de tanks de zona 1, "Colmillos Duros" que solo dropea de melees agresivos, etc.
**Propuesta:** cuando lleguen los enemies como entidades distintas (no solo "Tank R2"), darles drop tables únicas. Glosario ya menciona "Madera Ancestral, Colmillos Duros, Núcleos de Tierra" como materiales que podrían existir.
**Por qué importa:** pilar #2 (cada muerte enseña — matar X enemy te da Y material identitario). Fase 3.

### 📚 Glosario: actualizar entrada Piedra de Resonancia
**Origen:** `narrative-lore` (Milestone A).
**Descripción:** la entrada propuesta por narrative-lore para el glosario fue:
> **Piedra de Resonancia** — Material universal de refinamiento. Se consume en cada intento de mejora (+1 a +10). Su propiedad resonante permite que el filo, el temple o el peso de un item se reajuste a un estado superior sin refundirlo.
**Propuesta:** agregar al `.claude/docs/glossary.md` cuando Leo apruebe el copy.
**Por qué importa:** consistencia narrativa entre código y lore.

### ⚙ Object pool para los 4 slots de material toast
**Origen:** `ux-mobile` (Milestone A).
**Descripción:** el `MaterialToastContainer` instancia y libera nodos `MaterialToast` por cada material recogido. Con muchos drops simultáneos (Momentum 10x + stage cleared) puede haber instanciación/liberación frecuente.
**Propuesta:** pool de 4 toasts permanentes que se reusan + flag de visibilidad. Mejora perf mobile.
**Por qué importa:** target mobile (mid-range Android a 60fps). No urgente — solo si en playtest se nota stutter al recoger muchos materiales.

### 🎮 Adelantar boss R4 "El Guardián de la Maleza" a Fase 2
**Origen:** handoff Fase 1 + `.claude/docs/fases.md`.
**Descripción:** flagueado como opcional. Originalmente Fase 3 (primera zona completa), pero si Leo quiere cerrar zona 1 completa en Fase 2 (drops + 3 enemigos + boss → loop completo), se puede adelantar.
**Propuesta:** después de cerrar Refinamiento + Crafteo, delegar a `boss-designer` para diseñar y prototipear el Guardián. Sin sprites finales — tints/scale sobre StickFigure como los R3.
**Por qué importa:** cerrar Fase 2 con un climax memorable es más satisfactorio que cerrarla con un "loop completo pero sin destino".

### ⚙ Tests integración DropSystem (register/died/reset/integration)
**Origen:** `godot-expert` (review).
**Descripción:** los 3 bugs CRITICAL fixeados en round 3 (double-connect, ref colgante, Game Over reset) NO tienen tests automatizados. Requieren autoloads en runtime → tests de SceneTree.
**Propuesta:** task delegada a `godot-expert` (T11 creada). Cubrir:
- `register_enemy` dos veces con mismo enemy → no double-fire.
- `enemy.queue_free()` antes de `died` → erase en tree_exited.
- `reset()` limpia `_enemy_tables`.
- Fallback a `StageData.material_drops` cuando enemy no tiene tabla propia.
**Por qué importa:** regression protection. Si alguien refactorea DropSystem, los tests atrapan.

---

## Reglas de uso

- **Cualquier idea va acá**, incluso si parece tonta. Filtrar después es más barato que olvidar.
- **No prometer fechas** — solo descripción + por qué importa.
- **Si una idea pasa a ejecución**, mover a `docs/features/<feature>.md` con su spec y eliminar de acá (con commit que linkee).
- **Si una idea se descarta**, mover a sección "Archivado" abajo con razón.

---

## ✅ BUG RESUELTO — `stage_data.gd` perdió `@export var ambient_tint`

**Fecha:** 25/05/2026 ~tarde
**Causa raíz REAL:** durante T2 (equipment-system round 1) cuando se agregó `@export var material_drops: DropTable` a `stage_data.gd`, el agente **borró por error la export `@export var ambient_tint: Color`**. Esto rompió el schema del Resource: los `.tres` existentes (E2, E3, E4) seguían escribiendo `ambient_tint = Color(...)` pero el script ya no lo definía → al cargar `data.ambient_tint` en `world.gd._apply_layout` → `Invalid access to property 'ambient_tint' on a base object of type 'Resource (StageData)'` → crash al iniciar el primer stage.

**Error reportado por Leo:**
```
E 0:00:01:227   World._apply_layout: Invalid access to property or key 'ambient_tint' on a base object of type 'Resource (StageData)'.
  world.gd:238 @ World._apply_layout()
  world.gd:102 @ _on_stage_pending()
  stage_manager.gd:160 @ _enter_stage_pending()
  stage_manager.gd:80 @ start_run()
  world.gd:93 @ _ready()
```

**Fix aplicado:** restaurada `@export var ambient_tint: Color = Color(1.0, 1.0, 1.0, 1.0)` en `scripts/data/stage_data.gd` dentro de la sección `# ─── Estética ───`.

**Lección que ya existía en `CLAUDE.md §7.4`** ("Eliminar exports de un Resource ya usado en .tres existentes: consultar (pérdida de datos)") **— el agente la violó silenciosamente.** Default futuro: cuando un agente modifique un schema de Resource, verificar con Grep antes/después que **TODAS** las exports anteriores siguen presentes.

---

## Boss R4 en `_wip/` — estado pendiente de validar

**Fecha:** 25/05/2026 ~13:22
**Origen:** Sesión cortada por límite mientras `boss-designer` implementaba el Guardián de la Maleza (T15).
**Sospecha inicial (DESCARTADA):** que los archivos del boss rompían el juego. **El verdadero bug era `ambient_tint`** (ver entrada anterior).
**Acción tomada (precautoria):**
- Movidos `scripts/entities/boss_guardian.gd` (571 líneas) y `scripts/components/enemy_shield_component.gd` (73 líneas) a `_wip/` (incluyendo sus `.uid`).
- Verificado: 0 referencias externas a `BossGuardian` o `EnemyShieldComponent` en `.tscn` / `.gd` / `.tres` activos del proyecto.
- E4 (`zona1_etapa_4.tres`) sigue usando el Tank R4 placeholder (sin modificar).

**Estado:** los archivos pueden estar OK. La sospecha contra ellos no se confirmó. Si Leo quiere recuperarlos, **moverlos de vuelta**:
```
_wip/boss_guardian.gd → scripts/entities/boss_guardian.gd
_wip/boss_guardian.gd.uid → scripts/entities/boss_guardian.gd.uid
_wip/enemy_shield_component.gd → scripts/components/enemy_shield_component.gd
_wip/enemy_shield_component.gd.uid → scripts/components/enemy_shield_component.gd.uid
```
Después abrir Godot y verificar que el editor no reporta errores. Si pasa, validar manualmente el boss instanciándolo (requiere modificar world.gd para spawnear BossGuardian cuando R4 + is_boss, o crear escena boss_guardian.tscn).

**Por qué la sospecha cae sobre esos archivos:**
- Generados por un agente cuya sesión murió antes de poder verificar / iterar.
- 571 líneas de código nuevo con state machine extendida + override de métodos del padre + componente nuevo (EnemyShieldComponent).
- Análisis estático no detectó parse errors obvios, pero hay decisiones técnicas frágiles (state machine extendida via int constants > enum values, cleanup parcial en `_change_to_boss_state` replicando padre, posible bug en `CameraShake.shake(magnitude, duration)` con orden de parámetros).
- El override `_on_damaged` del boss usa `health.heal(amount)` después de que `health.take_damage` descontó — patrón "restaurar HP" en lugar de interceptar antes. Funciona pero es frágil si el padre cambia.

**Estado del lore narrativo (T15 + T16):**
- ✅ `docs/lore/bestiario_zona_1.md` — 7 especies + boss, COMPLETO.
- ✅ `docs/lore/valle_de_los_ecos.md` — contexto narrativo, COMPLETO (creado por Claude principal).
- ✅ `docs/lore/materiales_zona_1.md` — descripciones extendidas + flavor toasts, COMPLETO (creado por Claude principal).

**Próximos pasos cuando Leo vuelva:**
1. Abrir Godot y verificar que el juego carga (con los archivos del boss ya movidos).
2. Si carga: confirma diagnóstico, los archivos del boss eran la causa.
3. Si NO carga: hay otra causa que no detectamos — pedir log de Godot.
4. Decidir si re-implementar el boss desde cero con un agent (más cuidadoso, en pedacitos) o adoptar lo que hay en `_wip/` con review humano.

**Lecciones del incidente:**
- Lanzar boss-designer (tarea grande, 571 líneas) sin verificar inmediatamente que carga en Godot fue arriesgado.
- Cuando una sesión muere a mitad de un Agent grande, el output del agent puede haber terminado el código pero NO haber validado nada.
- Default futuro: tras delegar tarea grande de código, validar al menos parse-time antes de seguir a la próxima task.

---

## Archivado

(vacío por ahora)
