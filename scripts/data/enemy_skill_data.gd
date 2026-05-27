extends Resource
class_name EnemySkillData

## Datos del skill R2 de un enemy. Reemplaza la antigua const `R2_SKILL_TABLE` en
## `enemy.gd` por Resources serializables (.tres). Permite balance sin recompile +
## diff legible en git + override por scene variant (Archer R3 podría usar otra .tres).
##
## Catálogo canon en `resources/enemy_skills/r2_{melee,tank,archer,mage}.tres`.
## La lógica de ejecución (proyectiles, dash, taunt) sigue en `enemy.gd` —
## el Resource solo expone parámetros configurables.
##
## Flujo migración:
##  1. `enemy.gd._ready()` preload del .tres según `enemy_class`.
##  2. Métodos `_enter_r2_skill_attack` / `_tick_r2_skill_attack` / `_finish_r2_skill`
##     leen `_r2_skill_data.telegraph_sec`, `cd_min`, etc.
##  3. R2_SKILL_TABLE const queda como fallback defensivo (no se borra todavía).

## ID legible. Convención: `r2_{clase}` o `r3_{clase}_{nombre}`.
@export var id: StringName = &""

## Clase del enemy al que aplica (0=MELEE, 1=TANK, 2=ARCHER, 3=MAGE).
## Coincide con `GameConfig.EnemyClass`. Solo informativo — el match se hace por
## carga directa del .tres correcto en `enemy._ready`.
@export_enum("Melee:0", "Tank:1", "Archer:2", "Mage:3") var enemy_class: int = 0

## Duración del telegraph (R2_SKILL_TELEGRAPH state). GDD §7.3 R2 ≥0.5s.
@export var telegraph_sec: float = 0.6

## Cooldown random range entre activaciones. Se elige `randf_range(min, max)`
## tras cada `_finish_r2_skill`.
@export var cd_min: float = 5.0
@export var cd_max: float = 7.0

## Duración del state R2_SKILL_ATTACK. Melee dash sale por posición, no por timer.
@export var attack_duration: float = 0.25

## Multiplicador de daño del hitbox/proyectil durante el skill.
@export var damage_mult: float = 1.5

## Identificador del tipo de telegrafía visual. Solo informativo por ahora —
## el dispatch real lo hace `_spawn_r2_telegraph_vfx()` por enemy_class.
## Valores típicos: &"windup", &"channel", &"dash_trail", &"taunt_aura", &"rifle".
@export var telegraph_type: StringName = &"windup"

## Params específicos por clase. Schema esperado:
##  MELEE:  { dash_distance: float, dash_speed: float, knockback: float }
##  TANK:   { taunt_radius: float, taunt_duration: float, taunt_redirect_pct: float }
##  ARCHER: { projectile_count: int, spread_deg: float }
##  MAGE:   { fireball_scale: float }
##
## Acceso seguro: `params.get("dash_distance", 120.0)` con default canon.
@export var params: Dictionary = {}

## Metadata UI / documentación opcional.
@export var display_name: String = ""
@export_multiline var description: String = ""
