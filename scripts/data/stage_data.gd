extends Resource
class_name StageData

## Configuración data-driven de una etapa (stage).
##
## Una etapa = un encuentro PvE con un set fijo de enemies. Cuando todos mueren,
## el StageManager avanza a la siguiente. La última etapa es típicamente un boss.
##
## Cómo crear: en el editor de Godot, New Resource → StageData. Editar los campos
## y guardar como `resources/stages/<zona>_etapa_<N>.tres`.

# ─── Identidad ────────────────────────────────────────────────────────────────

## Índice 1-based. Solo informativo (el orden real lo decide el array en StageManager).
@export var stage_index: int = 1

## Nombre legible para banner UI. Ej: "Avanzada de Vanguardia", "Guarida del Tanque".
@export var display_name: String = "Etapa"

## Lore corto opcional. Mostrado debajo del título en banner (puede quedar vacío).
@export_multiline var subtitle: String = ""

# ─── Spawns ───────────────────────────────────────────────────────────────────

## Array de EnemySpawnEntry. Cada entry = N enemies de clase X con rareza Y.
## Para una stage normal: 3-10 entries.
## Para una stage boss: typically 1 entry con count=1 y is_boss=true.
@export var spawns: Array[EnemySpawnEntry] = []

## Si está ON, este stage es un boss fight. UI/feedback distinto.
## El boss se spawnea desde `spawns` (que debería contener una sola entry R4).
@export var is_boss: bool = false

# ─── Drops ────────────────────────────────────────────────────────────────────

## DropTable de materiales usada como fallback cuando un EnemySpawnEntry no tiene
## material_drops propio. Todos los enemies de la etapa comparten esta tabla.
## Si también es null, el kill no dropea nada. GDD §5.5.
@export var material_drops: DropTable

## DropTable de items equipables que se rolea al completar la stage (Milestone B).
## A diferencia de material_drops (drops por kill), esta tabla es por-stage:
## solo dispara una vez en stage_cleared. Null = no hay items garantizados.
## GDD §5.5.
@export var item_drops: DropTable

# ─── Estética ─────────────────────────────────────────────────────────────────

## Tinte multiplicador aplicado al background del world. Default blanco (sin tinte).
## Cambiar para "ambientar" la etapa (ej. rojo más intenso para etapas finales).
@export var ambient_tint: Color = Color(1.0, 1.0, 1.0, 1.0)

## Si NO está vacío, oculta las plataformas default del world.tscn y crea
## una nueva por cada entry. Permite layouts distintos por etapa.
## Si vacío, mantiene las plataformas default (salvo hide_default_platforms=true).
@export var platform_overrides: Array[StagePlatformConfig] = []

## Si está ON y `platform_overrides` está vacío, oculta TODAS las plataformas
## default igual. Útil para arenas planas (ej. boss fight).
@export var hide_default_platforms: bool = false

## Visibilidad de decoraciones del paisaje (árboles, luna).
## Permite "limpiar" la escena para etapas más áridas (ej. boss).
@export var show_decorations: bool = true

# ─── Helpers ──────────────────────────────────────────────────────────────────

## Total de enemies que spawneará esta etapa. Suma counts de todos los entries.
func total_enemy_count() -> int:
	var total: int = 0
	for entry in spawns:
		if entry != null:
			total += entry.count
	return total
