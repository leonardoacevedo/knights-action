# scripts/systems/

**Autoloads / singletons globales.** Estado y servicios compartidos entre toda la escena.

## Qué va acá

- Sistemas que necesitan estado persistente entre escenas.
- Servicios consumidos por muchos consumidores (UI, entidades, otros sistemas).
- Buses de eventos globales (si necesario).

## Qué NO va acá

- Componentes (van en `scripts/components/`).
- Lógica de una entidad específica (va en su script).
- Clases de datos (van en `scripts/data/`).

## Sistemas planificados (no todos existen aún)

| Sistema | Cuándo | Responsabilidad |
| :--- | :--- | :--- |
| `MomentumSystem` | Fase 1 | Estado de momentum del player, escalado, reset on damage. |
| `GameState` | Fase 1 | Pause, fade, transiciones entre escenas. |
| `SaveSystem` | Fase 1 | Persistencia local + cloud backup. |
| `InventorySystem` | Fase 2 | Items poseídos, equipados, materiales. |
| `CraftingManager` | Fase 2 | Recetas, validación, ejecución. |
| `UpgradeManager` | Fase 2 | Refinamiento +1 a +10 con RNG. |
| `FusionManager` | Fase 2 | 3 R(n) → 1 R(n+1). |
| `ProgressionSystem` | Fase 3 | XP, level-ups, puntos de skill. |
| `SkillTree` | Fase 3 | Estado del árbol, nodos comprados. |
| `StatAggregator` | Fase 3 | Calcula stats finales según fórmula. |
| `SetBonusResolver` | Fase 3 | Detecta sets equipados, aplica bonus. |
| `BestiarySystem` | Fase 3 | Kills por especie, bonus permanente. |
| `DailyMissionsSystem` | Fase 3 | 3 dailies rotativas, recompensas. |
| `ColiseumService` | Fase 4 | Fetch ecos, post resultados, ranking. |
| `EcoUploader` | Fase 4 | Analiza telemetría y sube Eco al backend. |
| `TelemetryRecorder` | Fase 4 | Registra últimas 10 batallas. |
| `GlorySystem` | Fase 4 | +/- Gloria, temporadas. |

## Convenciones

- Cada sistema en su archivo: `scripts/systems/<nombre>_system.gd`.
- Registrado en `project.godot` bajo `[autoload]` con el `PascalCase`.
- Emite señales para cambios de estado.
- No expone estado mutable directamente — siempre con getter / setter.
- Tipado fuerte en TODA la API pública.

## Plantilla base

```gdscript
extends Node
# Autoload "XSystem"

signal something_changed(new_value: int)

const SOMETHING_CONSTANT := 100

var _internal_state: int = 0

func _ready() -> void:
    # Inicialización.
    pass

# API pública
func do_something(amount: int) -> void:
    _internal_state += amount
    something_changed.emit(_internal_state)

func get_current() -> int:
    return _internal_state
```

## Registro en `project.godot`

Cuando agregás un autoload, editá la sección `[autoload]`:

```ini
[autoload]

MomentumSystem="*res://scripts/systems/momentum_system.gd"
InventorySystem="*res://scripts/systems/inventory_system.gd"
```

(El `*` significa que se autoload, no que el path tiene wildcard.)

## Anti-patrones

- ❌ Sistema con 50 responsabilidades — partir.
- ❌ Estado público mutable directo (`MomentumSystem.current = 5` desde afuera).
- ❌ Sistema que `process` cada frame sin necesidad.
- ❌ Dos sistemas que dependen circularmente uno del otro.
- ❌ Sistema que sabe sobre UI específica (debe ser agnóstico — UI escucha sus señales).
