extends Resource
class_name EnemySpawnEntry

## Una entrada de spawn dentro de un StageData.
## Representa "N enemies de clase X con rareza Y" para una etapa.
##
## Uso típico (en un StageData.tres):
##   spawns = [
##     EnemySpawnEntry { enemy_class=MELEE, rarity=R1, count=3 },
##     EnemySpawnEntry { enemy_class=TANK,  rarity=R2, count=2 },
##   ]
##
## La rareza escala HP/daño/telegraph según GameConfig.RARITY_*_MULT.

# Usamos int + @export_enum para evitar import circular con GameConfig.
# Los valores coinciden con GameConfig.EnemyClass y GameConfig.EnemyRarity.

@export_enum("Melee:0", "Tank:1", "Archer:2", "Mage:3") var enemy_class: int = 0
@export_enum("R1:0", "R2:1", "R3:2", "R4:3") var rarity: int = 0
@export_range(1, 30) var count: int = 1

## Elemento del enemy. Aplica modifier elemental al daño recibido y dado.
## Default Neutro = sin ventaja/desventaja contra ningún arma elemental. GDD §5.3.
@export_enum("Neutro:0", "Fuego:1", "Agua:2", "Tierra:3") var element: int = 0

## DropTable específica para enemies de esta entry. Si es null, DropSystem usa
## el material_drops de la StageData como fallback. GDD §5.5.
@export var material_drops: DropTable
