# tests/

Tests unitarios y simulaciones de balance. Mencionado en §12.1 GDD: *"Claude Code escribe tests unitarios cuando sea aplicable (combate, fórmulas)."*

## Qué testear

- ✅ **Fórmulas** matemáticas (Momentum, Refinamiento, XP, daño elemental).
- ✅ **RNG** con N alto para validar que las probabilidades convergen.
- ✅ **State machines** de enemigos / bosses (transiciones esperadas).
- ✅ **Sistemas críticos:** `UpgradeManager`, `StatAggregator`, `GlorySystem`.
- ✅ **Lógica de combate** determinística (cálculo de daño, efectos elementales).

## Qué NO testear

- ❌ UI (probarla a mano en mobile).
- ❌ Animaciones (visual, fuera de scope unitario).
- ❌ Performance (eso son benchmarks, separados).
- ❌ Lógica trivial (un getter de 1 línea no merece test).

## Organización

```
tests/
├── README.md
├── sims/                              # Simulaciones de balance (no son tests, son reportes).
│   ├── refinement_sim.gd
│   ├── xp_curve_sim.gd
│   ├── dps_ttk_sim.gd
│   └── drop_economy_sim.gd
├── components/
│   ├── health_component_test.gd
│   └── ...
├── systems/
│   ├── momentum_system_test.gd
│   ├── upgrade_manager_test.gd
│   ├── progression_system_test.gd
│   └── glory_system_test.gd
├── enemies/
│   └── states_test.gd
└── bosses/
    └── guardian_maleza_test.gd
```

## Framework

**MVP:** scripts simples con `assert()`. Ejecutables con `godot --headless --script res://tests/<archivo>.gd`.

**Futuro (decidir con Leo):** [GUT](https://github.com/bitwes/Gut) si los tests crecen. Es plugin estándar GDScript.

## Plantilla — test simple

```gdscript
# tests/systems/upgrade_manager_test.gd
extends SceneTree

func _init() -> void:
    print("== upgrade_manager_test ==")
    _test_success_table_complete()
    _test_levels_1_to_3_always_succeed()
    _test_downgrade_only_on_8_9_10()
    print("✅ All passed.")
    quit()

func _test_success_table_complete() -> void:
    for lvl in range(1, 11):
        assert(UpgradeManager.SUCCESS_TABLE.has(lvl),
            "Missing prob for level %d" % lvl)
    print("  - success table complete")

func _test_levels_1_to_3_always_succeed() -> void:
    assert(UpgradeManager.SUCCESS_TABLE[1] == 1.0)
    assert(UpgradeManager.SUCCESS_TABLE[2] == 1.0)
    assert(UpgradeManager.SUCCESS_TABLE[3] == 1.0)
    print("  - levels 1-3 always succeed")

func _test_downgrade_only_on_8_9_10() -> void:
    assert(8 in UpgradeManager.DOWNGRADE_ON_FAIL)
    assert(9 in UpgradeManager.DOWNGRADE_ON_FAIL)
    assert(10 in UpgradeManager.DOWNGRADE_ON_FAIL)
    assert(not (7 in UpgradeManager.DOWNGRADE_ON_FAIL))
    print("  - downgrade only on 8/9/10")
```

## Plantilla — simulación de balance

```gdscript
# tests/sims/refinement_sim.gd
extends SceneTree

const N_ATTEMPTS_PER_LEVEL := 10000

func _init() -> void:
    print("== Refinement Simulation ==")
    for target in range(1, 11):
        var successes := 0
        var prob: float = UpgradeManager.SUCCESS_TABLE[target]
        for i in range(N_ATTEMPTS_PER_LEVEL):
            if randf() <= prob:
                successes += 1
        var observed_rate: float = float(successes) / float(N_ATTEMPTS_PER_LEVEL)
        var deviation: float = abs(observed_rate - prob)
        print("Target +%d: expected %.2f, observed %.4f, deviation %.4f"
            % [target, prob, observed_rate, deviation])
        assert(deviation < 0.02, "Deviation too high for +%d" % target)
    print("✅ Simulation matches expected probabilities.")
    quit()
```

## Ejecución

```bash
godot --headless --script res://tests/systems/upgrade_manager_test.gd
godot --headless --script res://tests/sims/refinement_sim.gd
```

**Plan futuro:** script `run_all_tests.sh` o equivalente PowerShell que itera sobre `tests/` y reporta pass/fail. Crear cuando haya ≥10 tests.

## Reglas

1. **Test pasa o falla con código de salida claro.** `assert()` falla detiene la ejecución.
2. **Mensajes descriptivos.** Cuando assert falle, debe ser obvio qué se rompió.
3. **No tests dependientes entre sí.** Cada test es independiente.
4. **Tests rápidos.** Si un test tarda >5s, hay algo mal.
5. **Simulaciones (en `sims/`) NO son tests** — son reportes que generan output legible.

## Anti-patrones

- ❌ Mockear cosas para tests sin avisar — los tests deben golpear las clases reales del proyecto.
- ❌ Tests que solo testean lo que el código dice (sin verificar el comportamiento esperado).
- ❌ Test con N=10 para validar probabilidad (necesita ≥1000).
- ❌ Tests que requieren Godot Editor (deben correr headless).
