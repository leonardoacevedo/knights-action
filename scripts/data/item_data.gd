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
	NEUTRO, # 0
	# Eje natural — control + daño elemental puro. Triángulo: FUEGO>TIERRA>AGUA>FUEGO + VIENTO neutral cross.
	FUEGO,  # 1 — Synergy: Quemadura (DOT 3s rápido).
	AGUA,   # 2 — Synergy: Congelación (-30% velocidad / 2s).
	TIERRA, # 3 — Synergy: Fractura (próximo golpe recibido +20% dmg, single-use, window 5s).
	VIENTO, # 4 — Synergy: Desequilibrio (interrumpe ataque actual + 1.5s CD penalty).
	# Eje cósmico — alteración de stats, supervivencia, maldiciones. Triángulo: VIENTO>LUZ>SOMBRA>VIENTO.
	LUZ,    # 5 — Synergy: Bendición Divina (vampire heal 5% HP máx al atacante).
	SOMBRA, # 6 — Synergy: Miasma (DOT 5s bypass armor + -50% generación Furia, stack INDEPENDENT).
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

# ─── Hitbox de arma (Pilar #2 — hitboxes honestas) ───────────────────────────
# Definen la forma del polígono de daño que rota con el swing en ATTACK.
# 0 = usar default del visual_type (ver HitboxComponent.weapon_hitbox_defaults).
# Override por .tres permite armas custom (ej. espada R4 con reach extra).
# Bow/Staff = ranged: estos campos se ignoran (no hay hitbox melee).
## Alcance desde la mano (px). Default por tipo: sword=50, hammer=36, none=24.
@export var weapon_reach: float = 0.0
## Ancho del filo/cabeza (px). Default: sword=12, hammer=26.
@export var weapon_width: float = 0.0
## Arco del swing en grados (sweep total). Default: sword=130, hammer=110.
@export var weapon_arc_deg: float = 0.0
## Fracción del reach que daña (0-1). Default: sword=1.0 (todo el filo),
## hammer=0.35 (solo el cabezal), none=1.0 (puño entero).
@export_range(0.0, 1.0) var weapon_damage_zone: float = 0.0

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
