extends Resource
class_name ItemData

# Datos base de cualquier item equipable. Slots, rarezas y elementos según GDD §5.
# No contiene lógica de juego — solo datos. La lógica vive en InventorySystem / UpgradeManager.

# ─── Enums ───────────────────────────────────────────────────────────────────

enum Slot {
	ARMA,
	ARMADURA,
	ESCUDO,
}

enum Rarity {
	R1,  # Común
	R2,  # Raro
	R3,  # Épico
	R4,  # Legendario — excluido del MVP, definido para no romper el schema luego
}

enum Element {
	NEUTRO,
	FUEGO,
	AGUA,
	TIERRA,
}

# ─── Identidad ────────────────────────────────────────────────────────────────

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""

# ─── Clasificación ────────────────────────────────────────────────────────────

@export var slot: Slot = Slot.ARMA
@export var rarity: Rarity = Rarity.R1
@export var element: Element = Element.NEUTRO

# ─── Stats principales ────────────────────────────────────────────────────────

# stat_main: daño si slot=ARMA, defensa si slot=ARMADURA o ESCUDO.
@export var stat_main: int = 0

# Nivel de refinamiento. 0 = sin refinar. GDD §5.6.
@export_range(0, 10) var refinement_level: int = 0

# ─── Stats secundarias (afijos) ───────────────────────────────────────────────

# Array de AffixData. Cantidad máxima por rareza: R1=1, R2=2, R3=3. GDD §5.2.
@export var affixes: Array[AffixData] = []

# ─── Visual ───────────────────────────────────────────────────────────────────

@export var icon: Texture2D

## Tipo visual del arma para el StickFigure. Solo aplica si slot=ARMA o ESCUDO.
## 0=None (puños), 1=Sword, 2=Bow, 3=Staff, 4=Hammer, 5=Shield.
## Para slot=ARMADURA siempre None (no se renderiza nada extra).
@export_enum("None:0", "Sword:1", "Bow:2", "Staff:3", "Hammer:4", "Shield:5") var visual_type: int = 0

# ─── Helpers triviales ────────────────────────────────────────────────────────

func is_weapon() -> bool:
	return slot == Slot.ARMA


func is_armor() -> bool:
	return slot == Slot.ARMADURA


func is_shield() -> bool:
	return slot == Slot.ESCUDO


func max_affixes() -> int:
	# Cantidad máxima de afijos según rareza. GDD §5.2.
	match rarity:
		Rarity.R1: return 1
		Rarity.R2: return 2
		Rarity.R3, Rarity.R4: return 3
	return 0


func block_charges() -> int:
	# Cargas de bloqueo según rareza del escudo. GDD §4.3 / §5.2.
	if slot != Slot.ESCUDO:
		return 0
	match rarity:
		Rarity.R1: return 0
		Rarity.R2: return 1
		Rarity.R3: return 2
		Rarity.R4: return 3
	return 0


func refined_stat() -> float:
	# Stat con refinamiento aplicado. Fórmula: stat_base * (1 + 0.05 * nivel). GDD §5.6.
	return float(stat_main) * (1.0 + 0.05 * float(refinement_level))
