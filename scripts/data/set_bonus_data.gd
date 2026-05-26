extends Resource
class_name SetBonusData

## Definición de los bonus de set por elemento. GDD §5.4.
## Datos puros — sin lógica. La lógica de aplicación vive en SetBonusSystem.
##
## 2pc: bonus estadístico pasivo.
## 3pc: habilidad pasiva con nombre y descripción (efecto implementado en código).
##
## Los valores numéricos acá son los que PlayerStatsComponent / componentes leen
## para saber qué multiplicar. Cambiá estos .tres para tunear balance sin tocar .gd.

## Elemento al que aplica este bonus. Debe coincidir con ItemData.Element.
@export_enum("NEUTRO:0", "FUEGO:1", "AGUA:2", "TIERRA:3") var element: int = 0

# ─── 2 piezas ─────────────────────────────────────────────────────────────────

## Nombre del bonus 2pc para mostrar en UI.
@export var bonus_2pc_name: String = ""
## Descripción corta del efecto 2pc para UI.
@export var bonus_2pc_description: String = ""

## Multiplicador de daño total para FUEGO 2pc. 1.10 = +10%. 1.0 = sin efecto.
@export var damage_multiplier_2pc: float = 1.0
## Regeneración pasiva de Furia por segundo para AGUA 2pc. 0 = sin efecto.
@export var furia_regen_per_sec_2pc: float = 0.0
## Multiplicador de HP máximo para TIERRA 2pc. 1.15 = +15%. 1.0 = sin efecto.
@export var hp_multiplier_2pc: float = 1.0

# ─── 3 piezas ─────────────────────────────────────────────────────────────────

## Nombre del bonus 3pc para mostrar en UI.
@export var bonus_3pc_name: String = ""
## Descripción corta del efecto 3pc para UI.
@export var bonus_3pc_description: String = ""

## FUEGO 3pc — radio del AoE al matar un enemy (en píxeles). 0 = desactivado.
@export var fuego_aoe_radius: float = 0.0
## FUEGO 3pc — porcentaje del daño del golpe que hace el AoE. 0.60 = 60%.
@export var fuego_aoe_damage_pct: float = 0.0

## AGUA 3pc — si true, el dash resetea cooldown al pasar por hitbox de enemy.
@export var agua_dash_reset_on_pass: bool = false

## TIERRA 3pc — si true, bloquear con carga recupera +1 carga (hasta max original).
@export var tierra_block_restores_charge: bool = false
