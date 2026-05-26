# scripts/data/

**Custom Resource subclasses.** Clases de datos. Solo declaran campos, no lógica de juego.

## Filosofía

- Datos = `Resource` con `@export`.
- Lógica que opera sobre los datos = sistema (en `scripts/systems/`) o entidad.
- Los `.tres` (instancias concretas con valores) van en `resources/`.

## Clases planificadas

| Clase | Usado por | Campos típicos |
| :--- | :--- | :--- |
| `ItemData` | Inventario, UI, todo lo de items | id, slot, rarity, element, base_damage/defense, affixes, refinement_level |
| `WeaponData` | Hereda ItemData | atributos específicos de armas |
| `ArmorData` | Hereda ItemData | resistencias elementales |
| `ShieldData` | Hereda ItemData | block_charges, passive_hp, passive_def |
| `AffixData` | Embedido en ItemData | stat_id, value, weight |
| `MaterialData` | Crafting, drops | id, name, rarity, zone_origin |
| `EnemyData` | Spawning, IA | species_id, rarity, hp, damage, defense, ai_profile, drop_table |
| `BossData` | Hereda EnemyData | phases, patterns, threshold_hp_pct |
| `PatternData` | Bosses | name, windup_seconds, active_seconds, recovery, damage, tell_visual, tell_audio |
| `SkillData` | Skills equipables | id, branch, furia_cost, cooldown, effect |
| `SkillNodeData` | Árbol de skills | id, branch, cost, prerequisites, effects |
| `StatModifier` | Skills, sets | target_stat, additive/multiplicative, value |
| `ZoneData` | Mundo | id, element, level_range, materials, stages, palette |
| `StageData` | Zonas | id, encounters, checkpoints, layout_scene |
| `EncounterData` | Stages | spawn_list, trigger_condition |
| `EcoData` | Coliseo | owner_id, level, glory, ai_profile, build (sub-resource), telemetry |
| `AIProfile` | Coliseo | id, aggression_weight, block_threshold, preferred_distance |

## Convenciones

- Heredan de `Resource` o de otra clase Resource del proyecto.
- Tienen `class_name`.
- Todos los campos relevantes son `@export` con tipo fuerte.
- Sin métodos con lógica de juego. **Solo getters/helpers triviales** (ej. "¿es R3?").
- Archivos `snake_case`: `item_data.gd`, `enemy_data.gd`.

## Plantilla

```gdscript
extends Resource
class_name ItemData

@export var id: StringName
@export var display_name: String
@export var description: String

@export_enum("weapon", "armor", "shield") var slot: String = "weapon"
@export_range(1, 4) var rarity: int = 1
@export_enum("none", "earth", "fire", "water") var element: String = "none"

@export var base_damage: int = 0
@export var base_defense: int = 0

@export var affixes: Array[AffixData] = []
@export_range(0, 10) var refinement_level: int = 0

# Helper trivial — OK
func is_legendary() -> bool:
    return rarity == 4
```

## Anti-patrones

- ❌ Método `apply_damage()` adentro de `ItemData`. **Lógica de combate va en otro lado.**
- ❌ Campos sin `@export` (no serían visibles en Editor).
- ❌ Sin tipo en `@export` (`@export var x = 0` → tipá `@export var x: int = 0`).
- ❌ Resource que carga otros recursos en `_init()` con paths absolutos.

## Crear vs editar `.tres`

Hay 2 formas de crear instancias:

### A. En Godot Editor (preferido para humanos)
1. Botón derecho en `resources/items/weapons/` → "Crear Recurso Nuevo" → buscar `WeaponData`.
2. Editar campos en Inspector.
3. Guardar como `axe_of_valley.tres`.

### B. En código (programático, útil para scripts de seed)
```gdscript
var item := WeaponData.new()
item.id = &"axe_of_valley"
item.display_name = "Hacha del Valle"
item.rarity = 2
ResourceSaver.save(item, "res://resources/items/weapons/axe_of_valley.tres")
```

## Versionado

Si cambiás el schema de un Resource ya usado en `.tres` existentes:
1. Agregá nuevo campo con default razonable (Godot completa con default los `.tres` viejos).
2. Si renombrás o eliminás un campo, podés perder data — **migrar manualmente** o con script.
3. En backend (Eco), incluir `schema_version: int` en el JSON.
