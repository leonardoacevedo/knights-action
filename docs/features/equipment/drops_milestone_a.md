# Drops por etapa — Milestone A (drops de materiales por kill)

**Fecha de implementación:** 2026-05-25
**Implementado por:** Claude Code (orquestación) + 4 subagentes (narrative-lore, equipment-system, ux-mobile, balance-engineer, godot-expert)
**Fase del proyecto:** 2 — Loop Básico
**Sección GDD relevante:** §5.5 (crafteo y fusión), §111 (escala de Momentum sobre drops), §10 (Valle de los Ecos)
**Pilar(es) reforzado(s):** #1 (mi build importa — drops alimentan equipo y futuro refinamiento), #3 (skill > farmeo — Momentum multiplica drops, premia jugar bien)

---

## Qué hace

Cuando un enemy muere durante una stage, el sistema rolea drops de **materiales** y los agrega al inventario del jugador. Aplica la fórmula del GDD §111: `final_chance = clamp(base_chance × (1 + 0.1 × momentum), 0, 1)`. Un toast en el HUD muestra qué cayó (`+N <nombre>`). Cada stage de zona 1 tiene una `DropTable` con 3-4 materiales y probabilidades distintas (etapas tardías incrementan rares y épicos).

Esta es la primera mitad de la feature "drops por etapa". El **Milestone B** (drops de items equipables al completar stage entera) viene en una iteración futura.

## Por qué (pilares)

- **Pilar #1 — Mi build importa.** Los materiales son el fuel del **refinamiento futuro** (Piedra de Resonancia consume al intentar +1 a +10) y del **crafteo**. Sin drops, no hay materia prima para mejorar la build.
- **Pilar #3 — Skill > farmeo.** La fórmula GDD §111 hace que **mantener Momentum alto multiplique los drops hasta ×2**. Un jugador hábil que sostiene Momentum 10x obtiene el doble de loot por unidad de tiempo que uno que se deja golpear y resetea Momentum. El ranking favorece a quien juega mejor, no a quien graba más horas.

## Cómo se integra

```
HealthComponent.died (signal)
        ↓
DropSystem._on_enemy_died(enemy)
        ↓
_resolve_table(enemy):
    → entry.material_drops (tabla propia del enemy, opcional)
    → StageData.material_drops (fallback de la stage)
    → null (sin drops)
        ↓
DropTable.roll_materials_only(MomentumSystem.current_level)
        ↓
[ { type: "material", data: MaterialData, count: N }, ... ]
        ↓
InventorySystem.add_material(material, count)
        ↓
signal material_added(material, count)
        ↓
MaterialToastContainer._on_material_added(...)
        ↓
MaterialToast aparece en HUD superior derecho (stack si <0.6s del anterior)
```

### Wiring del DropSystem

- Autoload `DropSystem` registrado en `project.godot` después de `MomentumSystem`/`InventorySystem`/`StageManager`.
- `World._spawn_stage` llama `DropSystem.register_enemy(enemy, entry.material_drops)` **en paralelo** a `StageManager.register_enemy(enemy)` por cada enemy spawneado.
- `DropSystem` se conecta a `HealthComponent.died` del enemy (vía `Callable.bind`) y a `tree_exited` (limpieza defensiva si el enemy es freed sin morir oficialmente).
- `DropSystem.reset()` se llama desde `game_over_screen.gd` al apretar "Reintentar" para evitar refs colgantes entre runs.

## Decisiones técnicas no obvias

1. **MaterialData clase separada de ItemData.** Los materiales no se equipan, se cuentan (stack). Mezclarlos con equipables habría obligado al refinamiento futuro a filtrar por slot — más acoplamiento y peor refactor. Trade-off: 2 sistemas paralelos (items + materiales) en lugar de 1 unificado.

2. **Drops por kill = solo materiales. Items equipables = Milestone B (stage clear).** Mixto recomendado por Claude principal y aprobado por Leo. Razón: feedback continuo de loot (materiales) + reward visible al cerrar stage (items). Loot card de stage clear queda pendiente.

3. **`DropSystem.register_enemy(enemy, drop_table)` recibe la tabla explícitamente** en lugar de buscar por convención (`enemy.get_node_or_null("DropTable")` o similar). Razón: el "dueño" de la tabla es la `EnemySpawnEntry` que vive en `StageData`, no el `.tscn` del enemy. Esto permite que el mismo prefab de enemy dropee distinto según la stage en que aparece.

4. **Cap a 1.0 en la fórmula §111.** Si `base_chance × (1 + 0.1 × momentum) > 1.0`, se cappea a 1.0 (drop garantizado). Los commons como `hierba_antigua` (base 0.60) llegan al cap a partir de Momentum 7x. Auditado por `balance-engineer`: aceptable porque es el material más mundano y refuerza la sensación de "Momentum alto = lluvia de loot". **Idea futura (NO aplicada):** convertir overflow en bonus count para mantener estocasticidad. Decisión de Leo.

5. **Inventario de materiales como `Dictionary[StringName, int]`** (no `Array[ItemData]` ni objetos individuales). Razón: los materiales son fungibles (10 piedras_resonancia = 10 enteros, no 10 nodos). Más simple, más performante.

6. **Fix de 3 bugs CRITICAL en round 3:**
   - **Double-connect:** early return en `register_enemy` si `_enemy_tables.has(enemy)`.
   - **Ref colgante:** `tree_exited.connect(...)` para limpieza defensiva si el enemy es freed sin morir.
   - **Game Over reset:** `DropSystem.reset()` público + llamada desde `game_over_screen.gd` junto con los otros resets.

## Cómo testear manualmente

En Godot Editor:

1. Abrí `scenes/world.tscn` y corré.
2. Stage 1 arranca → Apretá START.
3. Matá enemies sin recibir daño (mantené Momentum subiendo). Deberías ver toasts en el HUD superior derecho con `+N Hierba Antigua` (más frecuente), `+1 Piedra de Resonancia` (raro), `+1 Savia Resonante` (raro).
4. Si dejás que un enemy te golpee → Momentum se resetea → los drops bajan a su rate base (≈60% hierba, etc).
5. Esperá a stage 3 o 4 → deberías ver `+1 Esencia del Verdor` ocasionalmente (drop épico, 5-10%).
6. Stage clear → no loot card todavía (Milestone B).
7. Game Over → Reintentar → verificá que no hay errores en la consola (refs limpias).

**Cosas que NO testeás en este milestone:**
- Loot de items equipables (Milestone B).
- Crafteo o refinamiento usando los materiales (features siguientes).
- Inventario visual de materiales (cuenta acumulada, UI de stash — Milestone B).

## Tests unitarios

- `tests/systems/drop_table_test.gd` — 9 casos cubriendo `DropTable.roll()`:
  - Tabla vacía → `[]`.
  - Single entry chance 1.0, momentum 0 → drop garantizado.
  - Single entry chance 0.0 → nunca dropea (incluso momentum 10).
  - Cap a 1.0 con momentum alto.
  - Momentum scaling correcto (`base × (1 + 0.1 × momentum)`).
  - `count_min/max` respetados.
  - `roll_materials_only()` filtra items.
  - Múltiples entries independientes (no exclusivos).

- `tests/systems/drop_system_integration_test.gd` — 6 casos de regresión cubriendo los 3 bugs CRITICAL fixeados y el flujo end-to-end:
  - **Test #1a** (Bug #1 — double-connect): registrar el mismo enemy dos veces → `_enemy_tables` tiene 1 sola entrada → el drop llega exactamente 1 vez al inventario.
  - **Test #1b** (Bug #1 — double-connect): segunda llamada con tabla diferente → la tabla original se preserva, la impostor se ignora.
  - **Test #2** (Bug #2 — ref colgante): `queue_free()` sin emitir `died` → hook `tree_exited` limpia `_enemy_tables` → no hay crash, no hay drops.
  - **Test #3** (Bug #3 — Game Over reset): 2 enemies registrados → `DropSystem.reset()` → `_enemy_tables` queda vacío.
  - **Test #4** (fallback): `register_enemy(enemy, null)` → al morir usa `StageData.material_drops` del stage actual.
  - **Test #5** (end-to-end): enemy registrado con tabla propia → muere → `roll_materials_only()` → `InventorySystem.add_material()` → material disponible en inventario.

**Requisito para correr los tests de integración:** autoloads activos del `project.godot` (GameConfig, MomentumSystem, InventorySystem, StageManager, DropSystem). Se cargan automáticamente al correr con `godot --headless --script res://tests/systems/drop_system_integration_test.gd`.

**Modificación a DropSystem para testabilidad:** se agregaron dos métodos privados `_test_registered_count() -> int` y `_test_is_registered(enemy: Node) -> bool`. Son getters de solo lectura que NO afectan el comportamiento de producción. No usar desde código de juego.

**Lo que NO tiene cobertura:**
- Stacking del toast → validación visual en Godot Editor.
- Flujo Game Over → Reintentar end-to-end completo con UI → validar manualmente.

## Assets necesarios

- **Iconos de los 4 materiales** — pendientes de `art-prompt-engineer`. Por ahora la UI usa `ColorRect` placeholder por rareza (gris/azul/violeta/dorado).
- **SFX al recoger material** — pendiente, no hay pipeline de audio en Fase 2 todavía.

## Archivos tocados

### Nuevos
- `scripts/data/material_data.gd`
- `scripts/data/drop_entry.gd`
- `scripts/data/drop_table.gd`
- `scripts/systems/drop_system.gd`
- `scripts/ui/material_toast.gd`
- `scripts/ui/material_toast_container.gd`
- `scenes/ui/material_toast.tscn`
- `scenes/ui/material_toast_container.tscn`
- `resources/materials/piedra_resonancia.tres`
- `resources/materials/hierba_antigua.tres`
- `resources/materials/savia_resonante.tres`
- `resources/materials/esencia_verdor.tres`
- `resources/stages/drop_tables/zona1_etapa_1_materials.tres`
- `resources/stages/drop_tables/zona1_etapa_2_materials.tres`
- `resources/stages/drop_tables/zona1_etapa_3_materials.tres`
- `resources/stages/drop_tables/zona1_etapa_4_materials.tres`
- `tests/systems/drop_table_test.gd`
- `docs/features/ui/material_toast.md`

### Modificados
- `scripts/data/enemy_spawn_entry.gd` — campo `material_drops: DropTable` opcional.
- `scripts/data/stage_data.gd` — campo `material_drops: DropTable` (fallback global de stage).
- `scripts/systems/inventory_system.gd` — API de materiales (`add_material`, `get_material_count`, `remove_material`, `get_all_materials`, signals `material_added` / `materials_changed`, `reset()` ampliado).
- `scripts/world/world.gd` — llamada a `DropSystem.register_enemy` en `_spawn_stage`.
- `scripts/ui/game_over_screen.gd` — llamada a `DropSystem.reset()` en Reintentar.
- `scenes/ui/hud_combat.tscn` — `MaterialToastContainer` agregado.
- `resources/stages/zona1_etapa_1.tres` — campo `material_drops`.
- `resources/stages/zona1_etapa_2.tres` — campo `material_drops`.
- `resources/stages/zona1_etapa_3.tres` — campo `material_drops`.
- `resources/stages/zona1_etapa_4.tres` — campo `material_drops`.
- `project.godot` — autoload `DropSystem`.

## Drop tables iniciales (auditadas por balance-engineer)

| Stage | Hierba Antigua | Piedra de Resonancia | Savia Resonante | Esencia del Verdor |
| :--- | :---: | :---: | :---: | :---: |
| E1 | 0.60 | 0.20 | 0.15 | — |
| E2 | 0.55 | 0.20 | 0.20 | — |
| E3 | 0.50 | 0.20 | 0.25 | 0.05 |
| E4 | 0.45 | 0.25 | 0.30 | 0.10 |

Cada entry es independiente (no exclusivo), `count = 1`. Run completa de 40 kills (curva realista de Momentum) → ~30 Hierba, ~13 Piedra, ~14 Savia, ~3 Esencia. Tiempo a 10 Piedras de Resonancia: ~8 kills (sub-1 run).

## Pendientes / mejoras futuras

### Milestone B (próxima iteración)
- **Loot card al completar stage** — modal con cards de items dropeados.
- **DropTable para items equipables** en `StageData`.
- **UI de inventario de materiales** — sección en el inventario actual o tab nuevo.
- **Drop tables por enemy** (ahora todos los enemies de una stage comparten el fallback global) — útil cuando lleguen los 3 enemies R1/R2/R3.

### NICE-TO-HAVE diferidos (reporte de godot-expert)
- Validación de `add_material(count <= 0)` (actualmente sigue derecho, emite signal con count=0).
- Signal `material_removed(material, count)` simétrica a `material_added`.
- `reset()` que opcionalmente emita `materials_changed` cuando algún listener autoload lo necesite.
- Tests unitarios de `DropSystem.register_enemy / died / reset` (requieren autoloads en runtime).

### Polish / playtest
- Si en playtest la Esencia del Verdor (E4 = 0.10) se siente spammy, bajar a 0.08.
- Sprites de materiales (delegar a `art-prompt-engineer`).
- SFX de pickup por rareza (cuando arranque pipeline de audio).
- **Idea futura sobre cap a 1.0:** convertir overflow en bonus count (`base × (1 + 0.1 × mom) > 1.0` → 1 garantizado + (overflow) chance de +1). Decisión de Leo.

### Validaciones manuales pendientes
- `MaterialToastContainer` dentro de `CanvasLayer` con anchors — verificar en Godot Editor que queda donde se espera (`ux-mobile` reportó que en su simulación funciona pero no testeó en device real).
- Testear flujo Game Over → Reintentar end-to-end (los 3 fixes CRITICAL del round 3 no tienen tests automatizados).

---

## Milestone B — Items por stage_cleared (2026-05-25)

**Implementado por:** equipment-system (subagente)
**Sección GDD relevante:** §5.5 (crafteo y fusión), §111 (escala de Momentum sobre drops)
**Pilar(es) reforzado(s):** #1 (mi build importa — items reales caen y alimentan la build), #4 (5 minutos bastan — completar una stage siempre recompensa)

### Qué hace

Cuando el jugador completa una stage entera (señal `StageManager.stage_cleared`), el sistema rolea la `DropTable` de items equipables de esa stage (`StageData.item_drops`) y agrega cada item dropeado directamente al `InventorySystem`. La señal `DropSystem.items_dropped(items: Array[ItemData])` se emite siempre al completar stage (vacía si no dropea nada). La loot card de UI es responsabilidad de `ux-mobile` (tarea T21, pendiente).

La etapa 1 (tutorial) no tiene `item_drops` asignado — `null` es válido, no rompe nada.

### Items que dropean por stage

| Stage | Item | Drop Chance (base) | Rareza |
| :--- | :--- | :---: | :--- |
| E1 | — | — | Tutorial, sin drops |
| E2 | Espada de Madera | 30% | R1 |
| E2 | Escudo de Tablones | 25% | R1 |
| E3 | Cota de Cuero | 40% | R1 |
| E3 | Arco Corto | 20% | R1 |
| E3 | Escudo de Hierro | 15% | R2 |
| E4 | Espada de Hierro | 50% | R2 |
| E4 | Coraza de Placas | 40% | R2 |
| E4 | Vara de Cristal | 20% | R2 |
| E4 | Martillo Guardián | 15% | R2 |

Las chances se escalan por Momentum igual que los materiales: `final_chance = clamp(base × (1 + 0.1 × momentum), 0, 1)`. Momentum 10x puede garantizar items con base ≥ 0.50.

Cada entry es independiente (no exclusiva) — un stage clear de E4 con buen Momentum puede dropear múltiples items a la vez.

### Cómo se integra

```
StageManager.stage_cleared(index: int)
        ↓
DropSystem._on_stage_cleared(index)
        ↓
StageManager.current_stage() → StageData
        ↓
StageData.item_drops (DropTable o null)
        ↓
DropTable.roll_items_only(MomentumSystem.current_level)
        ↓
[ { type: "item", data: ItemData, count: 1 }, ... ]
        ↓
InventorySystem.add_item(item) (por cada resultado)
        ↓
DropSystem.items_dropped.emit(items_list)  ← siempre, aunque vacía
        ↓
UI futura (T21, ux-mobile) escucha items_dropped → loot card modal
```

### Cómo la UI futura escucha

```gdscript
# En la loot card (T21, ux-mobile):
DropSystem.items_dropped.connect(_on_items_dropped)

func _on_items_dropped(items: Array[ItemData]) -> void:
    if items.is_empty():
        return  # Sin loot de items esta stage.
    # Mostrar modal con cards de cada item.
    _show_loot_card(items)
```

La señal se emite incluso con lista vacía para que la UI pueda decidir si muestra el modal o simplemente continúa. No hace falta conectar a `stage_cleared` desde la UI — `items_dropped` es suficiente.

### Archivos tocados

#### Modificados
- `scripts/data/drop_table.gd` — método `roll_items_only(momentum_level: int) -> Array` agregado al final.
- `scripts/data/stage_data.gd` — export `item_drops: DropTable` insertado entre `material_drops` y la sección estética. Los 10 exports anteriores permanecen intactos.
- `scripts/systems/drop_system.gd` — signal `items_dropped` + lógica de `_on_stage_cleared` expandida (reemplaza el TODO de Milestone B).
- `resources/stages/zona1_etapa_2.tres` — campo `item_drops` + ext_resource de la tabla. `load_steps` 15→16.
- `resources/stages/zona1_etapa_3.tres` — campo `item_drops` + ext_resource. `load_steps` 16→17.
- `resources/stages/zona1_etapa_4.tres` — campo `item_drops` + ext_resource. `load_steps` 5→6.
- `tests/systems/drop_table_test.gd` — 3 tests nuevos para `roll_items_only` (casos 10/11/12).

#### Nuevos
- `resources/stages/drop_tables/zona1_etapa_2_items.tres` — espada_madera + escudo_tablones.
- `resources/stages/drop_tables/zona1_etapa_3_items.tres` — cota_cuero + arco_corto + escudo_hierro.
- `resources/stages/drop_tables/zona1_etapa_4_items.tres` — espada_hierro + coraza_placas + vara_cristal + martillo_guardian.

### Pendientes / próxima iteración

- **T21 (ux-mobile):** loot card modal al completar stage — escucha `DropSystem.items_dropped`.
- Ícono / arte placeholder para items en la loot card.
- Validación manual en Godot Editor: completar E2, E3, E4 y confirmar que el inventario recibe los items correctos con y sin Momentum alto.
