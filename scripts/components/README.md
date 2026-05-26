# scripts/components/

**Componentes reutilizables.** Encapsulan UN comportamiento que múltiples entidades pueden usar.

## Filosofía

Composición sobre herencia. En vez de tener `class Player extends Entity extends Damageable extends Movable`, tenemos `Player` con `HealthComponent`, `HitboxComponent`, `DashComponent`, etc.

Beneficios:
- Reutilización entre player, enemigos y bosses.
- Cada archivo hace UNA cosa.
- Más fácil testear cada componente aislado.
- Más fácil cambiar el comportamiento de una entidad sin tocar las otras.

## Componentes existentes

- ✅ [`health_component.gd`](health_component.gd) — HP con señales `died` y `health_changed`.

## Componentes planificados

| Componente | Cuándo | Responsabilidad |
| :--- | :--- | :--- |
| `HitboxComponent` | Fase 1 | Área que aplica daño, configurable por team. |
| `HurtboxComponent` | Fase 1 | Área que recibe daño, filtra por team. |
| `FuriaComponent` | Fase 1 | Recurso Furia con decay automático. |
| `DashComponent` | Fase 1 | Dash con i-frames y cooldown. |
| `BlockComponent` | Fase 1 | Cargas de bloqueo, integración con escudo equipado. |
| `MomentumDisplayComponent` | Fase 1 | (opcional) traduce señal de momentum a feedback visual local. |
| `StaggerComponent` | Fase 2 | Stagger temporal para enemigos R2+. |
| `EquipmentComponent` | Fase 2 | Slot equipment del jugador (arma, armadura, escudo). |
| `BestiaryRecorderComponent` | Fase 3 | (en enemigos) notifica BestiarySystem al morir. |
| `DropTableComponent` | Fase 2 | (en enemigos) determina qué dropea al morir. |

## Convenciones

1. Heredan de `Node` o `Node2D` (o `Area2D` si necesitan colisión).
2. Tienen `class_name` PascalCase: `HealthComponent`, no `health_component`.
3. **No leen el nodo padre** directamente (`get_parent()` mal).
4. Exponen API por funciones públicas + señales tipadas.
5. Parámetros configurables como `@export` para que el Inspector los muestre.

## Plantilla

```gdscript
extends Node
class_name FuriaComponent

signal furia_changed(current: int, maximum: int)

@export var max_furia: int = 100
@export var decay_per_second: int = 5
@export var decay_starts_after_seconds: float = 5.0

var current_furia: int = 0
var _seconds_since_last_attack: float = 0.0

func _ready() -> void:
    set_process(true)

func _process(delta: float) -> void:
    _seconds_since_last_attack += delta
    if _seconds_since_last_attack >= decay_starts_after_seconds:
        _decay(delta)

func add(amount: int) -> void:
    if amount <= 0:
        return
    _seconds_since_last_attack = 0.0
    current_furia = min(max_furia, current_furia + amount)
    furia_changed.emit(current_furia, max_furia)

func try_spend(amount: int) -> bool:
    if current_furia < amount:
        return false
    current_furia -= amount
    furia_changed.emit(current_furia, max_furia)
    return true

func _decay(delta: float) -> void:
    var lost: int = int(delta * decay_per_second)
    if lost <= 0:
        return
    current_furia = max(0, current_furia - lost)
    furia_changed.emit(current_furia, max_furia)
```

## Cómo se usa desde el padre

```gdscript
# En player.gd
@onready var furia: FuriaComponent = $FuriaComponent
@onready var dash: DashComponent = $DashComponent

func _ready() -> void:
    furia.furia_changed.connect(_on_furia_changed)

func use_skill(skill: SkillData) -> void:
    if furia.try_spend(skill.furia_cost):
        # ejecutar skill...
        pass
```

## Inyección en lugar de buscar

**No** hagas:
```gdscript
# ❌ MAL — frágil.
var health: HealthComponent = get_parent().get_node("HealthComponent")
```

**Sí** hacé:
```gdscript
# ✅ BIEN — el padre te lo inyecta.
var health: HealthComponent

func setup(health_ref: HealthComponent) -> void:
    health = health_ref
```

## Tests

Cada componente nuevo debe venir con su test en `tests/components/<nombre>_test.gd`. Mínimo:
- API pública funciona como esperado.
- Señales se emiten en los momentos correctos.
- Valores extremos (0, max, negativo) se manejan bien.

## Anti-patrones

- ❌ Componente que sabe sobre escenas específicas (ej. `HealthComponent` que asume que su padre es un `Player`).
- ❌ Componente con múltiples responsabilidades ("HealthAndStaminaComponent").
- ❌ Componente con dependencias circulares (`A` necesita `B` necesita `A`).
- ❌ Componente sin tipos en su API pública.
