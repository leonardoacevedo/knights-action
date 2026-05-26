extends Resource
class_name StagePlatformConfig

## Configuración de UNA plataforma para un layout de etapa.
##
## Cuando un StageData define `platform_overrides`, el World oculta las
## plataformas default del .tscn y crea nuevas según estos configs.
## Esto permite "etapas con layouts distintos" sin crear .tscn por cada una.

## Centro de la plataforma en coordenadas del World.
@export var position: Vector2 = Vector2.ZERO
## Tamaño (ancho × alto) en píxeles. Default 200×20 = plataforma estándar.
@export var size: Vector2 = Vector2(200.0, 20.0)
## Color principal. Default mismo marrón que las plataformas default.
@export var color: Color = Color(0.30, 0.22, 0.16, 1.0)
