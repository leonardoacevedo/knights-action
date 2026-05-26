extends Resource
class_name SkillNode

## Nodo del árbol de habilidades del player. GDD §6.2.
##
## Crear: New Resource → SkillNode. Guardar en
## resources/skills/nodes/<rama>/<id>.tres
##
## Regla de prerequisitos: todos los prereqs deben estar en la MISMA rama.
## No se admiten prereqs cruzados entre ramas — rompe la promesa "build monorama viable".

enum Branch {
	GUERRERO, # daño físico, vida, supervivencia
	MAGO,     # daño elemental, Furia, eficiencia de skills
	AGIL,     # velocidad, dash, esquiva
}

# ─── Identidad ────────────────────────────────────────────────────────────────

## ID único snake_case. Ej: &"guerrero_vitalidad_1"
## Es la clave usada en _unlocked_nodes de PlayerProgression.
@export var id: StringName = &""

## Nombre legible para UI.
@export var display_name: String = ""

## Descripción de 1-3 líneas: qué hace el nodo.
@export_multiline var description: String = ""

@export var branch: Branch = Branch.GUERRERO

# ─── Costo y requisitos ───────────────────────────────────────────────────────

## Costo en puntos de skill. Casi siempre 1.
@export_range(1, 5) var point_cost: int = 1

## IDs de nodos que deben estar desbloqueados antes de poder comprar este.
## Si vacío, es nodo raíz (tier 1) — comprable desde el inicio con 1 punto.
## Todos los prereqs deben ser de la misma rama (ver doc).
@export var prerequisites: Array[StringName] = []

## Tier informativo dentro de la rama (1-5). Usado por UI para posicionar
## el nodo en el árbol visual. No afecta lógica de desbloqueo.
@export_range(1, 5) var tier: int = 1

# ─── Efectos ──────────────────────────────────────────────────────────────────

## Lista de efectos que aplica este nodo al desbloquearse.
## PlayerProgression.get_skill_bonus_* itera sobre estos al calcular stats.
@export var effects: Array[SkillEffect] = []
