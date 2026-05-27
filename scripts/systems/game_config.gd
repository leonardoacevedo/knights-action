extends Node
## GameConfig — autoload con TODAS las constantes globales de balance.
##
## Es el "archivo .env" del proyecto: un solo lugar para tunear stats base
## sin tocar 20 archivos. Pensado para iteración rápida durante el playtest.
##
## Cómo usar:
##   var hp := GameConfig.PLAYER_BASE_HEALTH
##   var dmg := GameConfig.enemy_damage_for(GameConfig.EnemyClass.TANK)
##
## NO poner acá:
##   - Stats específicos de items individuales (van en los .tres).
##   - Curvas que dependen del nivel del player (van en formulas.md / level_curve.gd).
##   - Constantes de comportamiento (van en sus respectivos scripts).

# ─── PLATAFORMA OBJETIVO ──────────────────────────────────────────────────────
## Plataforma para la que se está testeando. Define qué HUD se muestra:
## - PC: oculta joystick virtual + botones touch (se asume teclado/mouse).
## - MOBILE: muestra ambos (teclado igual sigue funcionando como fallback).
##
## Cambiar a MOBILE antes de exportar a celular o para testear el layout touch
## en PC con mouse-as-touch.
enum Platform { PC, MOBILE }
const PLATFORM_MODE: int = Platform.MOBILE


static func is_mobile() -> bool:
	return PLATFORM_MODE == Platform.MOBILE


static func is_pc() -> bool:
	return PLATFORM_MODE == Platform.PC


# ─── PLAYER ───────────────────────────────────────────────────────────────────

## HP máximo base del player sin armadura.
const PLAYER_BASE_HEALTH: int = 100
## Daño base del player sin arma (puños).
const PLAYER_BASE_DAMAGE: int = 10
## Defensa flat base del player sin escudo/armadura.
const PLAYER_BASE_DEFENSE: int = 0

# ─── ENEMIES (multiplier en %) ───────────────────────────────────────────────

## HP base del enemy (sin multiplicador de clase).
const ENEMY_BASE_HEALTH: int = 100
## Daño base del enemy (sin multiplicador de clase).
const ENEMY_BASE_DAMAGE: int = 10
## Defensa flat base del enemy.
const ENEMY_BASE_DEFENSE: int = 0
## Velocidad base del enemy (px/s). Tank usa fracción de esto.
const ENEMY_BASE_SPEED: float = 400.0

enum EnemyClass {
	MELEE,    ## guerrero a corta distancia, balance estándar
	TANK,     ## lento, mucho HP, golpea menos fuerte
	ARCHER,   ## ataca a distancia con flecha, frágil
	MAGE,     ## ataca a distancia con magia, muy frágil pero pega muy fuerte
}

## Rareza del enemy. Escala stats base por encima del multiplicador de clase.
## R1 común → R4 boss. Aplica a HP/daño/telegraph en enemy.gd al _ready.
enum EnemyRarity {
	R1,  ## Común — stats base sin bonus
	R2,  ## Raro — +50% HP, +30% daño
	R3,  ## Épico — +150% HP, +60% daño
	R4,  ## Legendario / Boss — +350% HP, +120% daño, telegraph más largo
}

## Multiplicadores de HP por rareza (sobre el resultado clase * base).
const RARITY_HP_MULT: Dictionary = {
	EnemyRarity.R1: 1.00,
	EnemyRarity.R2: 1.50,
	EnemyRarity.R3: 2.50,
	EnemyRarity.R4: 4.50,
}

## Multiplicadores de DAÑO por rareza (sobre el resultado clase * base).
const RARITY_DAMAGE_MULT: Dictionary = {
	EnemyRarity.R1: 1.00,
	EnemyRarity.R2: 1.30,
	EnemyRarity.R3: 1.60,
	EnemyRarity.R4: 2.20,
}

## Telegraph extra por rareza (segundos). Suma al base de la clase.
## R4 tiene telegraph MAYOR — es legible, no spam de hits. Refuerza pilar #2.
const RARITY_TELEGRAPH_BONUS: Dictionary = {
	EnemyRarity.R1: 0.0,
	EnemyRarity.R2: 0.0,
	EnemyRarity.R3: 0.05,
	EnemyRarity.R4: 0.30,
}

## Tinte de color aplicado encima del color de clase. Diferenciador visual.
## R1 sin tinte. R2 cyan suave. R3 violeta suave. R4 dorado intenso.
const RARITY_TINT: Dictionary = {
	EnemyRarity.R1: Color(1.0, 1.0, 1.0, 1.0),
	EnemyRarity.R2: Color(0.75, 0.95, 1.10, 1.0),
	EnemyRarity.R3: Color(1.10, 0.80, 1.20, 1.0),
	EnemyRarity.R4: Color(1.30, 1.10, 0.50, 1.0),
}

## Escala del sprite por rareza. R4 = bossy (más grande). R1-R3 normales.
const RARITY_SCALE: Dictionary = {
	EnemyRarity.R1: 1.00,
	EnemyRarity.R2: 1.05,
	EnemyRarity.R3: 1.12,
	EnemyRarity.R4: 1.45,
}

## Multiplicadores de HP por clase (% sobre ENEMY_BASE_HEALTH).
const HEALTH_MULT: Dictionary = {
	EnemyClass.MELEE: 1.00,
	EnemyClass.TANK: 2.00,
	EnemyClass.ARCHER: 0.80,
	EnemyClass.MAGE: 0.60,
}

## Multiplicadores de daño por clase (% sobre ENEMY_BASE_DAMAGE).
const DAMAGE_MULT: Dictionary = {
	EnemyClass.MELEE: 1.00,
	EnemyClass.TANK: 0.50,
	EnemyClass.ARCHER: 1.50,
	EnemyClass.MAGE: 1.80,
}

## Multiplicadores de velocidad por clase (% sobre ENEMY_BASE_SPEED).
const SPEED_MULT: Dictionary = {
	EnemyClass.MELEE: 1.00,
	EnemyClass.TANK: 0.65,      ## tank es notablemente más lento
	EnemyClass.ARCHER: 1.20,
	EnemyClass.MAGE: 0.80,
}

## Rango preferido de ataque por clase (px).
## CRITICAL: el hitbox del enemy alcanza ~45px desde su centro. Player hurtbox
## tiene 11px half-width. Reach efectivo total = 56px. PREFERRED_RANGE debe
## ser <=50 para melee/tank, asegurando conexión cuando entra a ATTACK.
## Archer/Mage mantienen distancia y disparan proyectiles.
const PREFERRED_RANGE: Dictionary = {
	EnemyClass.MELEE: 50.0,
	EnemyClass.TANK: 50.0,    ## mismo que melee — hitbox igual
	EnemyClass.ARCHER: 380.0,
	EnemyClass.MAGE: 420.0,
}

## Rango de detección por clase (px). Cuando player entra a esta distancia,
## enemy pasa de IDLE a CHASE. Debe ser >> PREFERRED_RANGE para que ranged
## tengan margen para acercarse antes de atacar.
const DETECT_RANGE: Dictionary = {
	EnemyClass.MELEE: 500.0,
	EnemyClass.TANK: 500.0,
	EnemyClass.ARCHER: 900.0,    ## detecta MUCHO más lejos que su rango de ataque
	EnemyClass.MAGE: 950.0,
}

## Duración de la telegrafía (segundos antes del ATTACK).
## GDD §7.3 sugiere ≥0.7s para R1 — los valores aquí son MENORES (request de Leo
## post-playtest: se sentía demasiado lento). Subir si la dificultad baja mucho.
##
## Tuning 2026-05-25 (Fix 2 playtest): bajar melee/tank — al entrar a rango, el
## player camina y abortaba el TELEGRAPH (cancel a `attack_range × 1.8`) antes
## del swing. Ranged queda igual (dispara a distancia, no se siente el problema).
const TELEGRAPH_SECONDS: Dictionary = {
	EnemyClass.MELEE: 0.25,
	EnemyClass.TANK: 0.4,
	EnemyClass.ARCHER: 0.35,
	EnemyClass.MAGE: 0.35,
}

# ─── WORLD ────────────────────────────────────────────────────────────────────

## Cantidad TOTAL de enemies al iniciar el world. Usado como default por
## `World._ready()` cuando el `@export enemy_count` no fue override.
## Editar acá para cambiar el default sin tocar el .tscn.
const WORLD_ENEMY_COUNT_DEFAULT: int = 5

# ─── DEBUG — Logs de sistemas ────────────────────────────────────────────────
## Si está ON, enemy.gd imprime logs detallados de su state machine
## (CHASE direction, escape ceiling, commit edge, jumps, falloff, intermediate platform).
## Útil para diagnosticar bugs de AI. Apagar para gameplay normal.
const DEBUG_ENEMY_AI: bool = true

# ─── TESTING — Counts fijos por clase ────────────────────────────────────────
## Si está ON, el spawner ignora los weights random y los counts del @export
## de world.gd, y spawnea EXACTAMENTE las cantidades de abajo (uno por clase).
## Útil para probar/balancear cada clase por separado sin RNG.
##
## OFF → spawn weighted random con `enemy_count` total y `spawn_weight_*` del world.gd.
const TEST_FIXED_COUNTS_ENABLED: bool = true

## Cantidad EXACTA por clase cuando TEST_FIXED_COUNTS_ENABLED está ON.
const TEST_MELEE_COUNT: int = 1
const TEST_TANK_COUNT: int = 1
const TEST_ARCHER_COUNT: int = 0
const TEST_MAGE_COUNT: int = 0

# ─── HELPERS ──────────────────────────────────────────────────────────────────

## HP final de un enemy según su clase.
static func enemy_health_for(enemy_class: int) -> int:
	var mult: float = HEALTH_MULT.get(enemy_class, 1.0)
	return int(round(float(ENEMY_BASE_HEALTH) * mult))


## Daño final de un enemy según su clase.
static func enemy_damage_for(enemy_class: int) -> int:
	var mult: float = DAMAGE_MULT.get(enemy_class, 1.0)
	return int(round(float(ENEMY_BASE_DAMAGE) * mult))


## Velocidad final de un enemy según su clase.
static func enemy_speed_for(enemy_class: int) -> float:
	var mult: float = SPEED_MULT.get(enemy_class, 1.0)
	return ENEMY_BASE_SPEED * mult


## Rango preferido de ataque de un enemy según su clase.
static func enemy_range_for(enemy_class: int) -> float:
	return PREFERRED_RANGE.get(enemy_class, 60.0)


## Rango de detección (IDLE → CHASE) según clase.
static func enemy_detect_range_for(enemy_class: int) -> float:
	return DETECT_RANGE.get(enemy_class, 500.0)


## Duración de telegrafía (TELEGRAPH → ATTACK) según clase.
static func enemy_telegraph_for(enemy_class: int) -> float:
	return TELEGRAPH_SECONDS.get(enemy_class, 0.7)


## String legible para debug / logs / UI.
static func class_name_of(enemy_class: int) -> String:
	match enemy_class:
		EnemyClass.MELEE: return "Melee"
		EnemyClass.TANK: return "Tank"
		EnemyClass.ARCHER: return "Archer"
		EnemyClass.MAGE: return "Mage"
	return "Unknown"


# ─── HELPERS DE RAREZA ────────────────────────────────────────────────────────

## HP final aplicando clase + rareza.
static func enemy_health_with_rarity(enemy_class: int, rarity: int) -> int:
	var base: int = enemy_health_for(enemy_class)
	var mult: float = RARITY_HP_MULT.get(rarity, 1.0)
	return int(round(float(base) * mult))


## Daño final aplicando clase + rareza.
static func enemy_damage_with_rarity(enemy_class: int, rarity: int) -> int:
	var base: int = enemy_damage_for(enemy_class)
	var mult: float = RARITY_DAMAGE_MULT.get(rarity, 1.0)
	return int(round(float(base) * mult))


## Telegraph total aplicando clase + bonus de rareza.
static func enemy_telegraph_with_rarity(enemy_class: int, rarity: int) -> float:
	var base: float = enemy_telegraph_for(enemy_class)
	var bonus: float = RARITY_TELEGRAPH_BONUS.get(rarity, 0.0)
	return base + bonus


## Tinte multiplicativo a aplicar encima del color base de clase.
static func rarity_tint_for(rarity: int) -> Color:
	return RARITY_TINT.get(rarity, Color(1, 1, 1, 1))


## Escala del sprite según rareza (1.0 = normal, R4 ~1.45).
static func rarity_scale_for(rarity: int) -> float:
	return RARITY_SCALE.get(rarity, 1.0)


## String legible de rareza para debug / UI.
static func rarity_name_of(rarity: int) -> String:
	match rarity:
		EnemyRarity.R1: return "R1"
		EnemyRarity.R2: return "R2"
		EnemyRarity.R3: return "R3"
		EnemyRarity.R4: return "R4"
	return "?"


# ─── PROGRESIÓN — XP POR KILL (GDD §6.1) ────────────────────────────────────

## XP otorgada por matar un enemy según su rareza. GDD §6.1.
## Sin multiplicador de Momentum: el nivel es progresión del personaje, no farmeo.
## Si Leo quiere multiplicarlo en el futuro, agregar XP_MOMENTUM_MULT constante.
const XP_PER_RARITY: Dictionary = {
	EnemyRarity.R1: 10,
	EnemyRarity.R2: 25,
	EnemyRarity.R3: 60,
	EnemyRarity.R4: 300,
}

## XP que otorga un enemy al morir según su rareza. Retorna 0 para rareza desconocida.
static func xp_for_kill(rarity: int) -> int:
	return XP_PER_RARITY.get(rarity, 0)


# ─── SISTEMA DE ORO — Oro por kill (GDD §5.5) ────────────────────────────────

## Oro base que otorga un enemy al morir según su rareza.
## El multiplicador de Momentum se aplica en GoldSystem._on_enemy_died (no aquí).
## Proporcional a XP/2: R1=5, R2=12 (≈25/2), R3=30 (≈60/2), R4=150 (≈300/2).
## Ajustado ligeramente hacia arriba para que el total post-Zona1 alcance los costos
## de refinamiento +10 (≈8270g total acumulado). Ver docs/features/gold_system.md.
const GOLD_PER_RARITY: Dictionary = {
	EnemyRarity.R1: 5,
	EnemyRarity.R2: 15,
	EnemyRarity.R3: 40,
	EnemyRarity.R4: 200,
}

## Oro que otorga un enemy al morir según su rareza. GoldSystem aplica mult de Momentum encima.
## Retorna 0 para rareza desconocida.
static func gold_for_kill(rarity: int) -> int:
	return GOLD_PER_RARITY.get(rarity, 0)


# ─── SISTEMA ELEMENTAL (GDD §5.3 + extensión 27/05) ──────────────────────────

## Modificador de ventaja elemental. GDD §5.3.
const ELEMENT_ADVANTAGE_MULT: float = 1.5
## Modificador de desventaja elemental.
const ELEMENT_DISADVANTAGE_MULT: float = 0.66

## Dos triángulos independientes:
##  - Primario:   FUEGO > TIERRA > AGUA > FUEGO    (canon GDD)
##  - Secundario: VIENTO > LUZ > SOMBRA > VIENTO   (canon definitivo 27/05)
## Cross-triángulo: 1.0 (neutral). Mismo elemento: 1.0.
## Status synergy on-hit (30% chance, ver HitboxComponent._try_apply_element_status):
## Diseño 27/05 — dos ejes:
##  Eje natural (control + daño): FUEGO=Quemadura · AGUA=Congelación · TIERRA=Fractura · VIENTO=Desequilibrio.
##  Eje cósmico (stats + supervivencia + maldiciones): LUZ=Bendición (vampire) · SOMBRA=Miasma (DOT bypass).
const ELEMENT_ADVANTAGE: Dictionary = {
	# Triángulo primario
	1: 3,  # FUEGO vence TIERRA
	3: 2,  # TIERRA vence AGUA
	2: 1,  # AGUA vence FUEGO
	# Triángulo secundario
	4: 5,  # VIENTO esparce LUZ
	5: 6,  # LUZ ilumina/disipa SOMBRA
	6: 4,  # SOMBRA ahoga VIENTO
}


## Retorna el modificador elemental entre atacante y defensor.
## Usa ItemData.Element (int) como base. GDD §5.3.
## - Ventaja: 1.5
## - Desventaja: 0.66
## - Neutral / NEUTRO involucrado: 1.0
## - Cross-triángulo (FUEGO vs VIENTO, etc.): 1.0
static func element_modifier(attacker: int, defender: int) -> float:
	if attacker == ItemData.Element.NEUTRO or defender == ItemData.Element.NEUTRO:
		return 1.0
	if attacker == defender:
		return 1.0
	if ELEMENT_ADVANTAGE.get(attacker, -1) == defender:
		return ELEMENT_ADVANTAGE_MULT
	if ELEMENT_ADVANTAGE.get(defender, -1) == attacker:
		return ELEMENT_DISADVANTAGE_MULT
	return 1.0
