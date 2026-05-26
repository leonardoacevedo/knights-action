# Sistema de Refinamiento — Backend

**Fecha de implementación:** 2026-05-25
**Implementado por:** Claude Code (con dirección de Leo)
**Fase del proyecto:** 2 — Loop Básico
**Sección GDD relevante:** §5.6
**Pilar(es) reforzado(s):** #1 (mi build importa), #2 (cada muerte enseña algo)

---

## Qué hace

Permite mejorar ítems equipables de +1 a +10 niveles de refinamiento, aplicando la fórmula `stat_final = stat_base × (1 + 0.05 × nivel_refinamiento)`. Cada intento consume una Piedra de Resonancia; los niveles +4 a +10 tienen probabilidades de éxito decrecientes con penalizaciones progresivas. Los niveles +8/+9/+10 pueden causar pérdida de nivel al fallar, evitable con un Pergamino de Protección (que igual consume materiales).

## Por qué (pilares)

**Pilar #1 — Mi build importa:** el refinamiento convierte dos ítems idénticos en distintos. Un arma +0 y una +8 son decisiones de inversión diferentes, no solo items más nuevos.

**Pilar #2 — Cada muerte enseña algo:** la probabilidad de éxito se expone antes del intento (vía `get_success_chance`) y el `RefineResult` documenta exactamente qué pasó, qué se consumió y por qué bajó el nivel. El jugador nunca recibe un resultado opaco.

## Cómo se integra

```
UpgradeManager (autoload)
  ├── lee REFINE_TABLE (local const)
  ├── consulta _inv() → InventorySystem (o override en tests)
  ├── muta ItemData.refinement_level (única fuente de mutación)
  └── emite signals:
        refine_started(item, target_level)
        refine_succeeded(result: RefineResult)
        refine_failed(result: RefineResult)
        refine_aborted(reason: String)

ItemData
  └── refined_stat() → float  (ya existía; calcula con la fórmula GDD §5.6)

RefineResult (nuevo Resource)
  └── produccido por UpgradeManager, consumido por la UI futura
```

**La UI futura** conecta sus listeners a `UpgradeManager.refine_succeeded` y `refine_failed`, y lee los campos de `RefineResult` para animar el resultado.

## Fórmula canónica

```
stat_final = stat_base × (1 + 0.05 × nivel_refinamiento)
```

Cap en +10: stat_base × 1.5. Documentada en `.claude/docs/formulas.md`.

## Tabla de probabilidades (GDD §5.6)

| Nivel objetivo | P(éxito) | Penalización si falla | Visual (UI futura) |
| :---: | :---: | :--- | :--- |
| +1 | 1.00 | — | estándar |
| +2 | 1.00 | — | estándar |
| +3 | 1.00 | — | estándar |
| +4 | 0.70 | pérdida de materiales | estándar |
| +5 | 0.70 | pérdida de materiales | brillo sutil |
| +6 | 0.50 | pérdida de materiales | brillo sutil |
| +7 | 0.50 | pérdida de materiales | brillo sutil |
| +8 | 0.30 | −1 nivel (protegible) | partículas intensas |
| +9 | 0.20 | −1 nivel (protegible) | partículas intensas |
| +10 | 0.10 | −1 nivel (protegible) | aura completa |

## Decisiones técnicas no obvias

### RefineResult como Resource (no Dictionary)

Se eligió `class_name RefineResult extends Resource` en lugar de un Dictionary tipado porque:
- Tipado fuerte: la UI futura puede autocomplete los campos sin riesgo de typo en strings.
- Es inspeccionable en el debugger de Godot.
- Permite agregar métodos helpers futuros (ej. `is_protected_fail()`) sin romper la API.

### Oro como dependency injection vacía

El sistema de Oro no existe en Fase 2. En lugar de hardcodear `gold_cost = 0` sin aviso, `REFINE_TABLE` tiene la columna `"gold"` con valor `0` y `attempt_refine` incluye un `TODO` comentado indicando exactamente dónde conectar `GoldSystem` cuando llegue. El campo `gold_consumed` de `RefineResult` también existe y está a `0`.

### Inyección de inventario para tests

`UpgradeManager` expone `_inventory_override: Object`. En producción es `null` y el código usa `InventorySystem` (autoload). En tests (headless, sin autoloads) se asigna un `FakeInventory` duck-type. Esto evita mockear el autoload globalmente y mantiene los tests aislados.

### `_test_force_outcome` en lugar de seed

Se eligió exponer `_test_force_outcome(bool)` en lugar de manipular la seed global de RNG porque:
- Seed global afecta todo el frame, no solo el refine — puede romper otros sistemas si corren en paralelo.
- `_test_force_outcome` es quirúrgico: afecta exactamente el próximo intento y se resetea solo.
- La función tiene el prefijo `_test_` como convención de "solo para testing".

## Cómo conectar la UI futura

```gdscript
# En la escena de UI de refinamiento:
func _ready() -> void:
    UpgradeManager.refine_started.connect(_on_refine_started)
    UpgradeManager.refine_succeeded.connect(_on_refine_succeeded)
    UpgradeManager.refine_failed.connect(_on_refine_failed)
    UpgradeManager.refine_aborted.connect(_on_refine_aborted)

# Mostrar probabilidad ANTES del intento (Pilar #2):
func _update_ui_for_item(item: ItemData) -> void:
    var target := UpgradeManager.get_target_level(item)
    var chance := UpgradeManager.get_success_chance(target)
    var penalty := UpgradeManager.get_penalty_type(target)
    # ... mostrar chance y penalty en pantalla antes de que el jugador confirme.

# Ejecutar refinamiento:
func _on_refine_button_pressed() -> void:
    var use_scroll: bool = scroll_toggle.button_pressed and UpgradeManager.can_use_scroll(item)
    UpgradeManager.attempt_refine(item, use_scroll)
```

## Tests cubiertos

Archivo: `tests/systems/upgrade_manager_test.gd`

| Test | Qué verifica |
| :--- | :--- |
| `_test_can_refine_null` | can_refine(null) → false |
| `_test_can_refine_max_level` | can_refine(+10) → false |
| `_test_get_target_level` | +5 → target 6 |
| `_test_get_success_chance` | nivel 7 → 0.50 |
| `_test_get_penalty_type` | none/materials_only/level_loss por nivel |
| `_test_abort_no_stones` | aborta con "insufficient_materials", nivel intacto |
| `_test_fail_level_loss_no_scroll` | fallo +9 sin pergamino → baja a +8, Piedra consumida |
| `_test_fail_level_loss_with_scroll` | fallo +9 con pergamino → queda en +9, ambos materiales consumidos |
| `_test_success_level_1_to_4` | éxito forzado +3→+4, exactamente 1 Piedra consumida |
| `_test_abort_max_level_attempt` | +10 → abortado "max_level", materiales intactos |
| `_test_abort_scroll_not_applicable` | scroll en nivel +5→+6 → abortado, sin consumo |
| `_test_stat_formula` | refined_stat() coincide con fórmula en +0, +5, +10 |

**Edge cases NO testeados (no aplican en Godot 4 single-threaded):**
- Concurrent refine (dos llamadas simultáneas).
- Multi-thread access al inventario.
- Overflow de nivel (no posible: assert + can_refine lo previene).

## Cómo testear manualmente en Godot

1. En `_ready()` de cualquier nodo temporal, obtener un `ItemData` del inventario.
2. Llamar `UpgradeManager.attempt_refine(item)` y observar las signals en Output.
3. Verificar que `item.refined_stat()` aumentó correctamente.
4. Intentar con Pergamino: `InventorySystem.add_material(pergamino_resource, 1)` → `attempt_refine(item, true)`.

## Pendientes para Fase UI

- [ ] Escena `RefineMenu` (delegar a `ux-mobile`): botón de intento, toggle de Pergamino, barra de probabilidad visible.
- [ ] Animaciones visuales por nivel de refinamiento (GDD §5.6 visual hints: brillo, partículas, aura).
- [ ] Audio de éxito/fallo.
- [ ] Integración con GoldSystem cuando se implemente en Fase 3.
- [ ] Drop table de Pergaminos (vía Coliseo, Fase 4 — `ecos-coliseum`).

## Archivos tocados

- `scripts/data/refine_result.gd` (nuevo)
- `scripts/systems/upgrade_manager.gd` (nuevo, autoload)
- `resources/materials/pergamino_proteccion.tres` (nuevo)
- `project.godot` (UpgradeManager registrado como autoload)
- `tests/systems/upgrade_manager_test.gd` (nuevo)
