extends Node
class_name PlayerStatsComponent

## Aplica stats de equipamiento al player.
## Lee InventorySystem.get_equipped() en cada equipped_changed y empuja
## los resultados a HealthComponent + HitboxComponent + HurtboxComponent.
##
## Fórmula base (formulas.md §Equipamiento):
##   stats_totales = stats_base(nivel) + stats_equipamiento + bonus_skills + bonus_set
## Por ahora: stats_base + equipamiento (skills y set bonus son futuro).
##
## HP al re-equipar: absoluto. Si tenías 80/100 y max sube a 110 → 80/110.
## Si max baja por debajo del HP actual, se clampea al nuevo max.

# ─── Stats base del player ────────────────────────────────────────────────────
# Source of truth: GameConfig autoload (scripts/systems/game_config.gd).
# Es el "archivo .env" del proyecto. Editar allí para tunear balance.
# NO duplicar constantes acá — se leen runtime de GameConfig.PLAYER_BASE_*.

# ─── Referencias a componentes del mismo entity ───────────────────────────────

## Asignar en el _ready del Player (inyección, no get_parent).
var health: HealthComponent
var hitbox: HitboxComponent
var hurtbox: HurtboxComponent

## Override de inventario para tests unitarios (headless no carga autoloads).
## En producción: null → usa InventorySystem autoload.
var _inv: Node = null


func _ready() -> void:
	# Conecta al inventario activo. En tests, _inv puede setearse ANTES de add_child.
	_get_inv().equipped_changed.connect(_on_equipped_changed)
	# Conecta a PlayerProgression para re-calcular stats cuando cambia nivel o skills.
	# Solo si el autoload existe (no en tests headless donde se inyecta _inv directamente).
	var prog := _get_progression()
	if prog != null:
		prog.stats_changed.connect(recalculate)
		prog.level_up.connect(_on_level_up)


## Retorna el inventario activo: override si fue seteado, InventorySystem si no.
func _get_inv() -> Node:
	return _inv if _inv != null else InventorySystem


## Retorna PlayerProgression autoload, o null en contextos de test headless.
## Los autoloads de Godot son nodos en /root/, no singletons de Engine.
func _get_progression() -> Object:
	return get_node_or_null("/root/PlayerProgression")


# ─── API pública ──────────────────────────────────────────────────────────────

## Recalcula todos los stats a partir del equipo actual.
## Aplica fórmula completa GDD §6.4:
##   stats_totales = stats_base(nivel) + equipamiento + bonus_skills + bonus_set
## Llamar manualmente en _ready del player (estado inicial).
## También llamado automáticamente cuando PlayerProgression emite stats_changed.
func recalculate() -> void:
	if health == null or hitbox == null or hurtbox == null:
		push_error("PlayerStatsComponent: referencias no seteadas antes de recalculate()")
		return

	var inv := _get_inv()
	var weapon: ItemData = inv.get_equipped(ItemData.Slot.ARMA)
	var armor: ItemData  = inv.get_equipped(ItemData.Slot.ARMADURA)
	var shield: ItemData = inv.get_equipped(ItemData.Slot.ESCUDO)

	# Log de afijos desconocidos antes de aplicar (una vez por recalculate).
	for item in [weapon, armor, shield]:
		if item != null:
			_warn_unknown_affixes(item)

	_apply_damage(weapon)
	_apply_health_and_defense(armor, shield)
	_apply_defender_element(armor, shield)
	_apply_set_bonus(weapon, armor, shield)
	# Skills que viven en otros componentes (no PlayerStatsComponent directo).
	_apply_furia_skills()
	_apply_dash_skills()
	_apply_movement_skills()
	_apply_evade_skill()
	_apply_elemental_adv_skill()
	_apply_block_charges_skill()


# ─── Privado ──────────────────────────────────────────────────────────────────

func _on_equipped_changed(_slot: ItemData.Slot, _item: ItemData) -> void:
	recalculate()


func _on_level_up(_new_level: int, _points: int) -> void:
	# HP aumenta automáticamente al subir de nivel (GDD §6.1).
	# recalculate() ya incorpora el bonus de nivel en _apply_health_and_defense.
	recalculate()


func _apply_damage(weapon: ItemData) -> void:
	# Daño base del arma con refinamiento, o GameConfig.PLAYER_BASE_DAMAGE si no hay arma.
	# GDD §6.4: stats_base(nivel) + equipamiento + bonus_skills + bonus_set.
	var prog := _get_progression()

	# Stats base (nivel): daño no sube por nivel en MVP (solo HP y Furia).
	# El nivel afecta al unlockeo de skills que sí dan daño.
	var base_damage: int = GameConfig.PLAYER_BASE_DAMAGE
	if weapon != null:
		# Si hay arma, el stat_main del arma reemplaza al base (no se suma).
		base_damage = int(round(weapon.refined_stat()))

	# Bonus de skills (fórmula §6.4).
	var skill_flat: int = 0
	var skill_pct: float = 0.0
	if prog != null:
		skill_flat = int(prog.get_skill_bonus_flat(SkillEffect.Stat.DAMAGE_FLAT))
		skill_pct = prog.get_skill_bonus_pct(SkillEffect.Stat.DAMAGE_PCT)

	hitbox.damage = int(round(float(base_damage + skill_flat) * (1.0 + skill_pct)))


func _apply_health_and_defense(armor: ItemData, shield: ItemData) -> void:
	# GDD §6.4: stats_base(nivel) + equipamiento + bonus_skills + bonus_set.
	var prog := _get_progression()

	# ─── HP ───────────────────────────────────────────────────────────────────
	# Stats base del nivel: HP_base + (nivel - 1) × HEALTH_PER_LEVEL.
	var level_bonus_hp: int = 0
	if prog != null:
		level_bonus_hp = (prog.get_level() - 1) * PlayerProgression.HEALTH_PER_LEVEL

	# Bonus de equipo (afijos hp de armadura, escudo, arma).
	var equip_hp: int = 0
	if armor != null:
		equip_hp += _sum_affix(armor, &"hp")
	if shield != null:
		equip_hp += _sum_affix(shield, &"hp")
	var weapon: ItemData = _get_inv().get_equipped(ItemData.Slot.ARMA)
	if weapon != null:
		equip_hp += _sum_affix(weapon, &"hp")

	# Bonus de skills (flat + pct).
	var skill_hp_flat: int = 0
	var skill_hp_pct: float = 0.0
	if prog != null:
		skill_hp_flat = int(prog.get_skill_bonus_flat(SkillEffect.Stat.HEALTH_MAX))
		skill_hp_pct = prog.get_skill_bonus_pct(SkillEffect.Stat.HEALTH_MAX)

	# Fórmula completa.
	var base_hp: int = GameConfig.PLAYER_BASE_HEALTH + level_bonus_hp
	var new_max: int = int(round(float(base_hp + equip_hp + skill_hp_flat) * (1.0 + skill_hp_pct)))
	_set_max_health(new_max)

	# ─── Defensa ──────────────────────────────────────────────────────────────
	var total_defense: int = GameConfig.PLAYER_BASE_DEFENSE

	if armor != null:
		total_defense += int(round(armor.refined_stat()))
		total_defense += _sum_affix(armor, &"defense")
	if shield != null:
		total_defense += int(round(shield.refined_stat()))
		total_defense += _sum_affix(shield, &"defense")

	# Bonus de skills de defensa.
	if prog != null:
		total_defense += int(prog.get_skill_bonus_flat(SkillEffect.Stat.DEFENSE_FLAT))
		var def_pct: float = prog.get_skill_bonus_pct(SkillEffect.Stat.DEFENSE_PCT)
		if def_pct > 0.0:
			total_defense = int(round(float(total_defense) * (1.0 + def_pct)))

	hurtbox.flat_defense = total_defense


## Setea hurtbox.element según equipo defensivo. GDD §5.3 (triángulo elemental).
## Prioridad: armor > shield > NEUTRO. Si ambas piezas comparten elemento, queda ese.
## Si difieren, armor manda (cobertura mayor del cuerpo).
## El atacante (enemy.hitbox) lee este valor para calcular ×1.5 / ×0.66.
func _apply_defender_element(armor: ItemData, shield: ItemData) -> void:
	var elem: int = ItemData.Element.NEUTRO
	if armor != null and armor.element != ItemData.Element.NEUTRO:
		elem = armor.element
	elif shield != null and shield.element != ItemData.Element.NEUTRO:
		elem = shield.element
	hurtbox.element = elem


func _sum_affix(item: ItemData, stat_id: StringName) -> int:
	# Suma los afijos con el stat_id exacto. Sin warnings acá — ver _warn_unknown_affixes.
	var total: int = 0
	for affix: AffixData in item.affixes:
		if affix != null and affix.stat_id == stat_id:
			total += affix.value
	return total


## IDs de afijos que PlayerStatsComponent conoce.
const KNOWN_AFFIX_IDS: Array[StringName] = [&"hp", &"defense", &"attack_speed"]

func _warn_unknown_affixes(item: ItemData) -> void:
	# Log único por item por recalculate — no por cada llamada a _sum_affix.
	for affix: AffixData in item.affixes:
		if affix == null:
			continue
		if affix.stat_id not in KNOWN_AFFIX_IDS:
			push_warning("PlayerStatsComponent: afijo desconocido '%s' en item '%s' — ignorado" \
				% [affix.stat_id, item.id])


func _set_max_health(new_max: int) -> void:
	# Conserva HP absoluto. Clampea si max baja por debajo del HP actual.
	# Ver docs/features/equipment/items_apply_to_player.md §Decisiones.
	var previous_current: int = health.current_health
	health.max_health = new_max
	health.current_health = min(previous_current, new_max)
	# Notificar HUD / listeners.
	health.health_changed.emit(health.current_health, health.max_health)


## Aplica bonus de set al final de recalculate(). GDD §5.4.
## Se ejecuta DESPUÉS de _apply_damage y _apply_health_and_defense para no
## romper las fórmulas base (bonus se apilan encima del resultado final).
func _apply_set_bonus(weapon: ItemData, armor: ItemData, shield: ItemData) -> void:
	# Resolver SetBonusSystem — en tests headless puede no existir como autoload.
	var sbs: Node = _get_set_bonus_system()

	# Sin autoload disponible: al menos actualizar Furia component con regen=0.
	if sbs == null:
		_update_furia_regen(0.0)
		return

	sbs.refresh(weapon, armor, shield)
	var data: SetBonusData = sbs.get_active_bonus_data()

	# Sin bonus activo → limpiar efectos pasivos y salir.
	if data == null:
		hitbox.damage_set_bonus_multiplier = 1.0
		_update_furia_regen(0.0)
		return

	var pieces: int = sbs.active_pieces

	# ── 2pc: multiplicador de daño (FUEGO) ──────────────────────────────────
	# Solo aplica si el multiplicador existe en el data del elemento activo.
	if data.damage_multiplier_2pc != 1.0 and pieces >= 2:
		hitbox.damage_set_bonus_multiplier = data.damage_multiplier_2pc
	else:
		hitbox.damage_set_bonus_multiplier = 1.0

	# ── 2pc: HP multiplicador (TIERRA) ──────────────────────────────────────
	# Se aplica SOBRE el new_max ya calculado en _apply_health_and_defense.
	# Para no duplicar, hacemos un segundo pase solo si el multiplicador difiere de 1.0.
	if data.hp_multiplier_2pc != 1.0 and pieces >= 2:
		var boosted_max: int = int(round(float(health.max_health) * data.hp_multiplier_2pc))
		_set_max_health(boosted_max)

	# ── 2pc: regen pasiva de Furia (AGUA) ───────────────────────────────────
	var regen: float = data.furia_regen_per_sec_2pc if pieces >= 2 else 0.0
	_update_furia_regen(regen)

	# ── 2pc: LUZ passive HP regen ───────────────────────────────────────────
	var luz_hp_regen: float = data.luz_passive_hp_regen_2pc if pieces >= 2 else 0.0
	_update_luz_passive_regen(luz_hp_regen)

	# ── 2pc: VIENTO bump move_speed_mult ────────────────────────────────────
	# BUG M13 (NO resuelto acá — requiere refactor del orden de recalculate()):
	# el comentario de abajo asume que _apply_set_bonus corre DESPUÉS de
	# _apply_movement_skills, pero en recalculate() el orden REAL es al revés
	# (_apply_set_bonus línea 79, _apply_movement_skills línea 83). Por eso este
	# multiplicador se aplica sobre un move_speed_mult viejo y luego
	# _apply_movement_skills lo pisa con (1 + MOVE_SPEED_PCT), perdiendo el bonus VIENTO.
	# No se puede arreglar moviendo la llamada: _apply_furia_skills DEPENDE de que
	# _apply_set_bonus corra ANTES (stack de regen AGUA 2pc). Fix correcto = separar
	# la aplicación del set bonus o aplicar VIENTO dentro de _apply_movement_skills.
	if data.viento_move_speed_pct_2pc != 0.0 and pieces >= 2:
		var player: Node = get_parent()
		if player != null and player.has_method("set_move_speed_mult"):
			# Multiplicamos encima: skill_mult × (1 + set_bonus_pct).
			var current_mult: float = float(player.get("move_speed_mult")) if player.get("move_speed_mult") != null else 1.0
			player.set_move_speed_mult(current_mult * (1.0 + data.viento_move_speed_pct_2pc))


## Actualiza la regeneración pasiva de Furia en FuriaComponent si existe.
## Si FuriaComponent no tiene el método (test aislado), falla silencioso.
func _update_furia_regen(regen_per_sec: float) -> void:
	var furia_node: Node = _find_sibling_component("FuriaComponent")
	if furia_node == null:
		return
	if furia_node.has_method("set_passive_regen"):
		furia_node.set_passive_regen(regen_per_sec)


## LUZ 2pc — regen pasivo HP cada segundo. Player.gd lee este valor + tickea.
func _update_luz_passive_regen(regen_per_sec: float) -> void:
	var player: Node = get_parent()
	if player != null and player.has_method("set_luz_passive_regen"):
		player.set_luz_passive_regen(regen_per_sec)


## Busca un componente hermano (mismo padre) por global class_name del script.
## get_class() retorna el tipo Godot nativo ("Node"), no el class_name GDScript.
## Por eso comparamos script.get_global_name().
func _find_sibling_component(class_name_str: String) -> Node:
	if get_parent() == null:
		return null
	for sibling: Node in get_parent().get_children():
		if sibling == self:
			continue
		var script: Script = sibling.get_script() as Script
		if script != null and script.get_global_name() == class_name_str:
			return sibling
	return null


## Retorna SetBonusSystem autoload, o null en contextos headless.
func _get_set_bonus_system() -> Node:
	return get_node_or_null("/root/SetBonusSystem")


# ─── Skills cableados a otros componentes ────────────────────────────────────
#
# Cada método lee el bonus de skills del stat correspondiente y lo empuja al
# componente que lo consume. Patrón: _find_sibling_component + has_method para
# evitar crash en contextos headless donde el componente puede no existir.

## FURIA_MAX (plano), FURIA_GAIN_PCT, FURIA_REGEN_FLAT → FuriaComponent.
## La regen suma set bonus AGUA 2pc + skill regen pasiva (ej. mago_resonancia_arcana).
func _apply_furia_skills() -> void:
	var prog := _get_progression()
	var furia_node: Node = _find_sibling_component("FuriaComponent")
	if furia_node == null:
		return

	# FURIA_MAX: base (nivel × FURIA_PER_LEVEL) + skill flat.
	var level_bonus_furia: int = 0
	if prog != null:
		level_bonus_furia = (prog.get_level() - 1) * PlayerProgression.FURIA_PER_LEVEL

	var skill_furia_flat: int = 0
	if prog != null:
		skill_furia_flat = int(prog.get_skill_bonus_flat(SkillEffect.Stat.FURIA_MAX))

	# set_max_furia_override: base (@export max_furia) + nivel + skills.
	# No pisamos el @export base — lo sumamos encima.
	var base_max: int = furia_node.max_furia  # valor del @export (100 default)
	furia_node.set_max_furia_override(base_max + level_bonus_furia + skill_furia_flat)

	# FURIA_GAIN_PCT.
	var gain_pct: float = 0.0
	if prog != null:
		gain_pct = prog.get_skill_bonus_pct(SkillEffect.Stat.FURIA_GAIN_PCT)
	furia_node.set_gain_multiplier(1.0 + gain_pct)

	# FURIA_REGEN_FLAT: skills (mago_resonancia_arcana = +1/s).
	# La regen del set bonus AGUA 2pc ya fue seteada por _apply_set_bonus (corre antes).
	# Acá sumamos el skill encima para no perder el valor del set bonus.
	if prog != null:
		var skill_regen: float = prog.get_skill_bonus_flat(SkillEffect.Stat.FURIA_REGEN_FLAT)
		if skill_regen > 0.0 and furia_node.has_method("get_passive_regen"):
			var current_regen: float = furia_node.get_passive_regen()
			furia_node.set_passive_regen(current_regen + skill_regen)


## DASH_COOLDOWN_PCT, IFRAMES_PCT → DashComponent.
func _apply_dash_skills() -> void:
	var prog := _get_progression()
	if prog == null:
		return
	var dash_node: Node = _find_sibling_component("DashComponent")
	if dash_node == null:
		return

	var cd_pct: float = prog.get_skill_bonus_pct(SkillEffect.Stat.DASH_COOLDOWN_PCT)
	# cd_pct es negativo (-0.20 = -20%). 1.0 + (-0.20) = 0.80 → 20% más rápido.
	dash_node.dash_cooldown_mult = max(0.1, 1.0 + cd_pct)

	var iframes_pct: float = prog.get_skill_bonus_pct(SkillEffect.Stat.IFRAMES_PCT)
	dash_node.iframes_mult = max(0.1, 1.0 + iframes_pct)


## MOVE_SPEED_PCT → player.gd. Buscamos al padre (Player) y modificamos velocity cap.
## Godot no tiene un "max speed" separado — Player.SPEED es constante.
## Solución: exponemos var move_speed_mult en Player y PlayerStatsComponent la setea.
func _apply_movement_skills() -> void:
	var prog := _get_progression()
	if prog == null:
		return
	var speed_pct: float = prog.get_skill_bonus_pct(SkillEffect.Stat.MOVE_SPEED_PCT)
	var player: Node = get_parent()
	if player != null and player.has_method("set_move_speed_mult"):
		player.set_move_speed_mult(1.0 + speed_pct)


## EVADE_PCT → HurtboxComponent.evade_chance.
func _apply_evade_skill() -> void:
	var prog := _get_progression()
	var evade_pct: float = 0.0
	if prog != null:
		evade_pct = prog.get_skill_bonus_pct(SkillEffect.Stat.EVADE_PCT)
	hurtbox.evade_chance = clampf(evade_pct, 0.0, 0.75)  # cap 75% — no trivializar combate


## ELEMENTAL_ADV_MULT → HitboxComponent.elemental_adv_skill_bonus.
func _apply_elemental_adv_skill() -> void:
	var prog := _get_progression()
	var adv_bonus: float = 0.0
	if prog != null:
		adv_bonus = prog.get_skill_bonus_pct(SkillEffect.Stat.ELEMENTAL_ADV_MULT)
	hitbox.elemental_adv_skill_bonus = adv_bonus


## BLOCK_CHARGES → ShieldComponent.skill_charges_bonus.
func _apply_block_charges_skill() -> void:
	var prog := _get_progression()
	var charges_bonus: int = 0
	if prog != null:
		charges_bonus = int(prog.get_skill_bonus_flat(SkillEffect.Stat.BLOCK_CHARGES))
	var shield_comp: Node = _find_sibling_component("ShieldComponent")
	if shield_comp != null and shield_comp.has_method("set_skill_charges_bonus"):
		shield_comp.set_skill_charges_bonus(charges_bonus)
