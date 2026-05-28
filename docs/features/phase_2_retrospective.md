# Retrospectiva Fase 2 — Loop Básico

**Período:** ~25 mayo 2026 (sesiones intensivas iterando sobre Fase 1)
**Cerrada:** 25/05/2026
**Hito GDD §13:** *"El loop pelear → lootear → mejorar engancha."* — Validado por Leo end-to-end.
**Backup:** `backups/fase_2_cerrada_2026-05-25.tar.gz` (snapshot completo al cierre).
**Fase siguiente:** 3 — Sistemas RPG Completos (abierta 26/05/2026).

---

## 1. Objetivo y scope

Construir el **loop completo PvE** sobre la base de combate de Fase 1: 3 enemigos diferenciados → drops de materiales/items → crafteo + refinamiento. Validar que el bucle "matar → recolectar → mejorar → matar más fuerte" engancha tras 10-15 min de juego.

### Scope formal
- **3 enemigos R1/R2/R3** con behavior diferenciado (R2 bloquea cargas reales, R3 dashea + skill).
- **Drops Milestone A** (materiales por kill).
- **Drops Milestone B** (items por stage_cleared).
- **Crafteo backend + UI** (5 recetas iniciales).
- **Refinamiento +1..+10** backend + UI con Pergaminos de Protección.
- **Boss R4 "Guardián de la Maleza"** con cargas escudo + 5 patrones + 2 fases.
- **Stats del equipo impactan combate** (`PlayerStatsComponent` + `HurtboxComponent.flat_defense`).
- **UI completa**: Inventory + Refinement + Crafting + LootCard + MaterialToast.

---

## 2. Lo entregado

### Enemies diferenciados por rareza (R1/R2/R3)
- **R1** — comportamiento simple, telegraph + attack, sin bloqueo.
- **R2** — agrega `EnemyBlockHandler` con 1 carga real. Bloquea ataques del player y contraataca.
- **R3** — agrega dash de esquiva lateral (`State.DODGE`) + skill propia por clase (Embestida melee, Triple Tiro archer, etc).

### Drops Milestone A (materiales por kill)
- `DropSystem` autoload escucha `HealthComponent.died` de enemies registrados.
- `EnemySpawnEntry.material_drops` → `DropTable` con `DropEntry[]`.
- Drop por rareza (R1=common, R2=rare, R3=epic).
- Modificado por Momentum (`drop_rate × (1 + 0.1 × M)`).

### Drops Milestone B (items por stage_cleared)
- `StageData.item_drops` → DropTable per-stage.
- Triggered en `StageManager.stage_cleared`.
- LootCardScreen muestra items rolleados al cerrar stage.

### Crafteo
- `CraftingSystem` autoload + `CraftRecipe` Resource.
- 5 recetas iniciales (Zona 1).
- UI con drag inventory → recipe slots.
- Validación stock materials + oro al craftear.

### Refinamiento +1..+10
- `UpgradeManager` autoload con tabla GDD §5.6 (prob decreciente 100→10%).
- Penalización: fallo +4..+7 = pérdida materials; +8..+10 = -1 nivel.
- Pergamino de Protección omite penalización -1 nivel (mantiene gasto materials).
- UI con prob visible, materiales requeridos, slider de target level.

### Boss Guardián de la Maleza
- `boss_guardian.gd` 571 líneas extendiendo Enemy.
- 5 patrones telegrafiados: Embestida, Raíces (3 AoE), Gap-Close Dash, Melee swing, Tormenta de Espinas (F2).
- 2 fases (HP<50% trigger + cargas regeneradas + nuevo patrón).
- Escudo cargas reales reusando `EnemyBlockHandler` (Opción A — no componente boss-only).
- Recarga: al entrar F2 + cada 12s tras shield broken.

### PlayerStats + flat_defense
- `PlayerStatsComponent.recalculate()` aplica stats del equipo.
- Daño recibido del player descuenta `flat_defense` antes de health.
- Equipo realmente impacta combate ahora (no solo cosmético).

### UI completa
- InventoryScreen con sección materiales.
- RefinementScreen + CraftingScreen funcionales.
- LootCardScreen al cerrar stage.
- MaterialToast con cola visual + pool de 4 toasts.

---

## 3. Lo cortado o postergado

- **Sin elementos** (triángulo FUEGO/AGUA/TIERRA). Postergado a Fase 3.
- **Sin set bonuses** (afinidad de equipo 2pc/3pc). Postergado a Fase 3.
- **Sin árbol de skills**. Postergado a Fase 3.
- **Sin arte definitivo** — StickFigure procedural sigue siendo placeholder.
- **Sin audio** — pipeline diferido a Fase 5.
- **Coliseo Fase 4 sin tocar.**
- **R4 Legendaria excluida del MVP** (post-launch).

---

## 4. Decisiones técnicas duraderas

### Que se mantienen como canon

1. **EnemyBlockHandler reusable** para R2/R3 y Boss R4. Sin componente boss-only. Justificación: misma flow, un solo bug surface.
2. **DropTable por rareza** + override per-stage. Fallback: `EnemySpawnEntry.material_drops` → `StageData.material_drops`.
3. **`item.duplicate(true)` en drop/craft** — cada instancia es propia. Refinement no afecta otras instancias del mismo item.
4. **Pergamino de Protección consume materials**. Solo protege del downgrade, no del costo. Refuerza Pilar #1 (skill importa — saber cuándo usar Pergamino).
5. **Refinamiento bidireccional con -1 nivel** en +8/+9/+10. No "perdé todo el nivel" — castigo proporcional.
6. **Boss state >=100** para custom states (Guardian usa 100s, futuros bosses 200s+).

### Decisiones en playtest vs documento

- **Furia gain × Momentum** confirmado (`base × (1 + 0.05 × M)`) — refuerza loop "atacá agresivo → más Furia → más skills".
- **Drop rate cap a 1.0** descartado para Fase 3 (sugerencias 25/05) — convertir overflow en bonus count.
- **Boss telegraph times reducidos** post-playtest (0.8s → 0.6s en Embestida) para Game Feel sin sacrificar Pilar #2.

---

## 5. Bugs y lecciones documentadas

### Bugs CRITICAL fixeados

1. **StageData.ambient_tint borrado por agente** — el agente `equipment-system` borró el export al agregar `material_drops`. Resource schema mismatch → crash inicio. Lección: **verificar Grep antes/después al modificar Resource exports**.
2. **DropSystem double-connect** — `register_enemy(enemy)` dos veces conectaba `died` 2× → doble drop. Fix: `if not health.died.is_connected(...)`.
3. **Game Over no reseteaba DropSystem** — Tablas viejas persistían. Fix: `DropSystem.reset()` en `_on_game_over`.
4. **TouchButton stuck con CanvasLayer modal** — heredado Fase 1, refixed con poll defensivo en process_mode=ALWAYS.

### Lecciones técnicas

1. **Modifying Resource schema = mass-test todos los .tres** que lo usan. Agentes deben grepear antes y después.
2. **Tests integration DropSystem pendientes** — los 3 bugs CRITICAL no tienen regression test.
3. **Pool object para MaterialToast** identificado como mejora futura (no urgente).
4. **Boss state machine extendida via int >=100** funciona bien. Pattern reutilizable para futuros bosses.

---

## 6. Métricas de cierre

- **Líneas de código:** ~3500 net (combate + UI + sistemas).
- **Tests:** 28 tests puros (formulas, drops, refinement, crafting, momentum, stats).
- **Resources:** 27 items + 13 materials + 8 drop tables + 5 recipes.
- **Sesión playtesteable end-to-end:** ~12 min (4 stages + boss + 3 refinements).

---

## 7. Apertura Fase 3

Pendientes que abren Fase 3:
- Árbol de skills (3 ramas, ~30 nodos).
- Sistema Elementos (triángulo).
- Set Bonuses (afinidad equipo).
- Completar zona 1 (sumar 2-4 stages).
- Arte IA + audio + parallax + sprites.
- Pool R3 completo (armor R3 + escudo R3).

Ver [`.claude/docs/fases.md`](.claude/docs/fases.md) Fase 3 para detalle.
