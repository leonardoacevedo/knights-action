extends Node2D
class_name World

## Root del world. Stage-driven: orquesta el spawn de cada etapa de la run.
##
## Flujo:
##   1. _ready carga `stages: Array[StageData]` y se las pasa al StageManager.
##   2. Se suscribe a StageManager.stage_started → cuando dispara, limpia y spawnea.
##   3. Cada enemy se registra en StageManager.register_enemy(enemy).
##   4. StageManager detecta cuando todos murieron y avanza solo. World reacciona.
##
## Si stages está vacío, fallback al spawn legacy del GameConfig.TEST_* counts
## (modo "playground" para iterar 1 stage manualmente sin tocar resources).
##
## NO hay enemies hardcoded en world.tscn — el spawner es la única fuente.
## Si alguien deja uno por error, _clear_existing_enemies lo borra.

# ─── Configuración de la run ─────────────────────────────────────────────────

## Lista ordenada de stages que conforman la run. Si vacía, modo playground.
## Cargar resources/stages/*.tres en este array desde el editor del world.tscn.
@export var stages: Array[StageData] = []

## Si está ON y `stages` está vacío, intenta cargar las stages default del MVP.
## Útil para que el .tscn no quede mal si Leo no asignó nada en el editor.
@export var auto_load_default_stages: bool = true

# ─── Configuración de spawn ──────────────────────────────────────────────────

## Bounds horizontales del spawn random.
@export var spawn_x_min: float = -700.0
@export var spawn_x_max: float = 700.0

## Y de spawn. Default -20 = sobre el suelo.
@export var spawn_y: float = -20.0

## Distancia mínima al player para evitar spawn pegado al spawn point.
@export var min_distance_from_player: float = 250.0

## Escenas por clase.
@export var scene_melee: PackedScene = preload("res://scenes/entities/enemy_melee.tscn")
@export var scene_tank: PackedScene = preload("res://scenes/entities/enemy_tank.tscn")
@export var scene_archer: PackedScene = preload("res://scenes/entities/enemy_archer.tscn")
@export var scene_mage: PackedScene = preload("res://scenes/entities/enemy_mage.tscn")
## Bosses R4 por clase. Si entry.rarity == R4, se usa el boss específico en vez del
## enemy genérico. Modos tradicional (is_boss stage) y prueba (TestArenaConfig) cubren ambos.
@export var scene_boss_guardian: PackedScene = preload("res://scenes/entities/boss_guardian.tscn")
@export var scene_boss_duelista: PackedScene = preload("res://scenes/entities/boss_duelista.tscn")
@export var scene_boss_cazadora: PackedScene = preload("res://scenes/entities/boss_cazadora.tscn")
@export var scene_boss_heraldo: PackedScene = preload("res://scenes/entities/boss_heraldo.tscn")

# ─── Rutas default para auto_load_default_stages ─────────────────────────────
# **Migrado 27/05** a `StageManager.get_stages_for_zone(zone_id)`. La const se
# conserva por compatibilidad para code que lo referencie directo; el path canónico
# para nuevas zonas es `StageManager.ZONE_STAGE_PATHS`.

const DEFAULT_STAGE_PATHS: Array[String] = [
	"res://resources/stages/zona1_etapa_1.tres",
	"res://resources/stages/zona1_etapa_2.tres",
	"res://resources/stages/zona1_etapa_3.tres",
	"res://resources/stages/zona1_etapa_4.tres",
	"res://resources/stages/zona1_etapa_5.tres",
	"res://resources/stages/zona1_etapa_boss.tres",
]

## Skill variant override por zona + enemy_class. Pool §4 — canon decisión Leo 27/05.
## Zona 1 sin override (usa R2_SKILL_RESOURCES canónico en enemy.gd).
## Aplica post-spawn en `_spawn_stage`: si current_zone tiene entry para enemy_class,
## carga el .tres y overrides `enemy._r2_skill_data`. Solo R2/R3 enemies (no R4 bosses).
## Keys: GameConfig.EnemyClass int (MELEE=0, TANK=1, ARCHER=2, MAGE=3).
const ZONA_SKILL_VARIANTS: Dictionary = {
	2: {  # Fragua Cenicienta (FUEGO)
		0: "res://resources/enemy_skills/r2_melee_giratorio.tres",
		2: "res://resources/enemy_skills/r2_archer_disparo_reactivo.tres",
		3: "res://resources/enemy_skills/r2_mage_erupcion_terrestre.tres",
	},
	3: {  # Acueducto Lamento (AGUA)
		0: "res://resources/enemy_skills/r2_melee_tajo_doble.tres",
		1: "res://resources/enemy_skills/r2_tank_gancho_ascendente.tres",
		3: "res://resources/enemy_skills/r2_mage_nova_hielo.tres",
	},
	4: {  # Cumbres Tempestad (VIENTO/LUZ)
		0: "res://resources/enemy_skills/r2_melee_salto_asalto.tres",
		2: "res://resources/enemy_skills/r2_archer_disparo_reactivo.tres",
		3: "res://resources/enemy_skills/r2_mage_rafaga_arcana.tres",
	},
}

# ─── Referencias internas ────────────────────────────────────────────────────

@onready var _background: TextureRect = $Background
@onready var _decorations: Node2D = $Decorations
@onready var _bg_sprite: Sprite2D = $ParallaxBackground/LayerBG/BGSprite
@onready var _mid_sprite: Sprite2D = $ParallaxBackground/LayerMid/MidSprite
@onready var _fore_top_sprite: Sprite2D = $ParallaxBackground/LayerForeTop/ForeTopSprite
@onready var _fore_bottom_sprite: Sprite2D = $ParallaxBackground/LayerForeBottom/ForeBottomSprite

## Texturas de background por stage (Opción A simple — swap por stage_index).
## BG = cielo (capa más lejana), MID = ruinas/bosque, FORE = ramas/hierba en primer plano.
## Sub-zonas zona 1: a=stages 1-2 (ruinas abiertas, amanecer), b=stages 3-4 (bosque, mediodía),
## c=stage 5 + boss (bosque profundo, atardecer).
const BG_TEXTURES: Dictionary = {
	"a": preload("res://assets/art/zona1/backgrounds/bg_valle_bga_amanecer_1920x1080.png"),
	"b": preload("res://assets/art/zona1/backgrounds/bg_valle_bgb_mediodia_1920x1080.png"),
	"c": preload("res://assets/art/zona1/backgrounds/bg_valle_bgc_atardecer_1920x1080.png"),
}
## MID nuevos (28/05): Gemini regen — 2752x1536 reales (aspect 16:9 OK), alpha real.
## Filenames mantienen "1280x720" como nombre canónico (tamaño pedido).
const MID_TEXTURES: Dictionary = {
	"a": preload("res://assets/art/zona1/backgrounds/bg_valle_mida_ruinas_1280x720.png"),
	"b": preload("res://assets/art/zona1/backgrounds/bg_valle_midb_bosque_1280x720.png"),
	"c": preload("res://assets/art/zona1/backgrounds/bg_valle_midb_bosque_1280x720.png"),
}
## ForeTop = ramas colgantes arriba. Solo aparecen en sub-zonas con bosque (b y c).
## En sub-zona "a" (ruinas abiertas) ocultamos la capa — visible toggle.
## Nuevos (28/05): 3904x1088 reales (aspect 32:9 tira horizontal), alpha real.
const FORE_TOP_TEXTURES: Dictionary = {
	"a": null,
	"b": preload("res://assets/art/zona1/backgrounds/bg_valle_foreb_ramas_1280x360.png"),
	"c": preload("res://assets/art/zona1/backgrounds/bg_valle_foreb_ramas_1280x360.png"),
}
const FORE_BOTTOM_TEXTURES: Dictionary = {
	"a": preload("res://assets/art/zona1/backgrounds/bg_valle_forea_hierba_1280x360.png"),
	"b": preload("res://assets/art/zona1/backgrounds/bg_valle_forea_hierba_1280x360.png"),
	"c": preload("res://assets/art/zona1/backgrounds/bg_valle_forea_hierba_1280x360.png"),
}

## Plataformas default del .tscn — escondidas cuando un stage tiene overrides.
## Se resuelven en _ready (cualquier hijo en grupo "platform").
var _default_platforms: Array[Node2D] = []
## Plataformas creadas dinámicamente para overrides. Se liberan entre stages.
var _override_platforms: Array[Node2D] = []

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	# Shader white_to_alpha removido el 28/05: PNGs nuevos de Gemini ya vienen
	# con alpha real. El shader sigue disponible en assets/shaders/ por si
	# en zonas futuras se generan PNGs sin alpha y hay que reactivarlo.

	# --- ESCALA Y POSICIÓN DE BACKGROUNDS (refactor 28/05 v2) ---
	# Aspect ratio preservado (scale uniforme X=Y) — antes se rompía.
	# Tamaños PNG reales (post-Gemini v2, watermark removida):
	#   BG = 1920×1080 (mantenido grande para parallax lejano)
	#   MID = 2400×1340 (aspect 16:9 ≈)
	#   FORE_TOP/BOTTOM = 2400×669 (aspect 32:9, tira horizontal)
	# Viewport Godot default = 1152×648.
	var scale_bg: float = 0.6        # 1920×0.6 = 1152 (match viewport ancho)
	var scale_mid: float = 0.50      # 2400×0.50 = 1200 (margen 48px parallax)
	var scale_fore: float = 0.50     # 2400×0.50 = 1200 (margen 48px parallax)

	# Position X = 0: respetar centro del ParallaxLayer (no desplazar).
	# Position Y por capa: aproxima dónde se ancla visualmente cada capa.
	# Tunear si en playtest la composición se ve corrida vertical.
	var offset_y_bg: float = -250.0       # cielo abarca alto viewport
	var offset_y_mid: float = -300.0      # mid distance, centrado vertical
	var offset_y_fore_top: float = -480.0 # tira anclada arriba
	var offset_y_fore_bottom: float = -80.0 # tira anclada piso

	if _bg_sprite != null:
		_bg_sprite.scale = Vector2(scale_bg, scale_bg)
		_bg_sprite.position = Vector2(0, offset_y_bg)
	if _mid_sprite != null:
		_mid_sprite.scale = Vector2(scale_mid, scale_mid)
		_mid_sprite.position = Vector2(0, offset_y_mid)
	if _fore_top_sprite != null:
		_fore_top_sprite.scale = Vector2(scale_fore, scale_fore)
		_fore_top_sprite.position = Vector2(0, offset_y_fore_top)
	if _fore_bottom_sprite != null:
		_fore_bottom_sprite.scale = Vector2(scale_fore, scale_fore)
		_fore_bottom_sprite.position = Vector2(0, offset_y_fore_bottom)

	# Motion mirroring: ajustar a width post-scale por capa para evitar gaps
	# al cruzar el lado del mirror. Cada ParallaxLayer mirror = sprite width × scale.
	var bg_layer: ParallaxLayer = $ParallaxBackground/LayerBG
	var mid_layer: ParallaxLayer = $ParallaxBackground/LayerMid
	var ft_layer: ParallaxLayer = $ParallaxBackground/LayerForeTop
	var fb_layer: ParallaxLayer = $ParallaxBackground/LayerForeBottom
	if bg_layer != null:
		bg_layer.motion_mirroring = Vector2(1920.0 * scale_bg, 0)    # 1152
	if mid_layer != null:
		mid_layer.motion_mirroring = Vector2(2400.0 * scale_mid, 0)  # 1200
	if ft_layer != null:
		ft_layer.motion_mirroring = Vector2(2400.0 * scale_fore, 0)  # 1200
	if fb_layer != null:
		fb_layer.motion_mirroring = Vector2(2400.0 * scale_fore, 0)  # 1200

	# Instanciar la loot card y agregarla al árbol.
	# Se hace aquí (no en world.tscn) para evitar editar UIDs del .tscn a mano.
	# La pantalla se conecta sola a DropSystem.items_dropped en su _ready.
	# TODO: si en el futuro hay múltiples escenas con stages, mover a un autoload UI o SceneManager.
	var loot_card_scene: PackedScene = preload("res://scenes/ui/loot_card_screen.tscn")
	var loot_card: LootCardScreen = loot_card_scene.instantiate() as LootCardScreen
	add_child(loot_card)

	# Borrar cualquier enemy dejado en el .tscn (Godot a veces los regenera al save).
	_clear_existing_enemies()

	# Cachear plataformas default del .tscn (las del grupo "platform").
	for child in get_children():
		if child is StaticBody2D and child.is_in_group("platform"):
			_default_platforms.append(child)

	# Modo prueba: inyectar StageData runtime si TestArenaConfig tiene spawns.
	# Tiene precedencia sobre todo: ignora lo que esté en `stages` y las defaults.
	if TestArenaConfig.is_test_mode and not TestArenaConfig.pending_spawns.is_empty():
		var arena_stage := StageData.new()
		arena_stage.display_name = "Arena de Prueba"
		arena_stage.is_boss = false
		arena_stage.spawns = TestArenaConfig.pending_spawns.duplicate()
		stages = [arena_stage]
		# No llamar exit_test_mode aquí: el flag tiene que persistir durante el run
		# para que los guards de XP/Gold/Drop funcionen. Lo limpia MainMenu al volver.

	# Cargar stages default si no hay y la flag está ON.
	if stages.is_empty() and auto_load_default_stages:
		_load_default_stages()

	if stages.is_empty():
		# Playground mode: usar GameConfig.TEST_*_COUNT (no hay run).
		push_warning("World: sin stages cargados — fallback a modo playground (sin progresión).")
		_spawn_playground()
		return

	# Configurar y arrancar la run via StageManager.
	StageManager.stage_pending.connect(_on_stage_pending)
	StageManager.stage_started.connect(_on_stage_started)
	StageManager.stage_cleared.connect(_on_stage_cleared)
	StageManager.run_completed.connect(_on_run_completed)
	StageManager.configure(stages)
	StageManager.start_run()


# ─── Hook stage_started: spawn de la stage ────────────────────────────────────

## Stage en preparación: cleanup + layout, NO spawn (espera al jugador).
func _on_stage_pending(data: StageData, _index: int) -> void:
	_clear_existing_enemies()
	_clear_projectiles()
	_apply_layout(data)


## Stage iniciada por el jugador (apretó START): ahora sí spawn.
func _on_stage_started(data: StageData, _index: int) -> void:
	_spawn_stage(data)


func _on_stage_cleared(_index: int) -> void:
	# Hook para futuro: SFX de victoria, drops del stage, etc.
	pass


func _on_run_completed() -> void:
	# Zone chaining: zona 1 → 2 → 3 → 4. Cuando el último stage de la zona muere,
	# si hay zona siguiente disponible, avanzamos. Si era la zona 4 (final), volvemos al menú.
	# Modo prueba (TestArenaConfig) no avanza zona — termina en pantalla de menú.
	if TestArenaConfig.is_test_mode:
		await get_tree().create_timer(2.5).timeout
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		return
	var current_zone: int = StageManager.current_zone if StageManager != null else 1
	var next_zone: int = current_zone + 1
	if StageManager.ZONE_STAGE_PATHS.has(next_zone):
		# Espera a que el banner de VICTORIA muestre, luego carga la próxima zona.
		await get_tree().create_timer(3.0).timeout
		StageManager.reset()
		StageManager.set_zone(next_zone)
		get_tree().change_scene_to_file("res://scenes/world.tscn")
	else:
		# Última zona completada → volver al menú principal.
		await get_tree().create_timer(3.5).timeout
		StageManager.reset()
		StageManager.set_zone(1)  # reset al menu para próxima run
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# ─── Spawn de stage data-driven ───────────────────────────────────────────────

func _spawn_stage(data: StageData) -> void:
	if data == null:
		push_warning("World._spawn_stage: data null.")
		return
	var player: Node2D = get_node_or_null("Player")
	var spawn_index: int = 0
	for entry: EnemySpawnEntry in data.spawns:
		if entry == null:
			continue
		var scene: PackedScene = _scene_for_class(entry.enemy_class)
		# Boss override por clase: cualquier entry R4 usa el boss específico de esa clase.
		# Aplica tanto al modo tradicional (stage is_boss) como al modo prueba (TestArenaConfig).
		# Prioridad: `data.boss_scene_override` (per-stage) > routing por clase.
		if entry.rarity == GameConfig.EnemyRarity.R4:
			if data.boss_scene_override != null:
				scene = data.boss_scene_override
			else:
				var boss_override: PackedScene = _boss_scene_for_class(entry.enemy_class)
				if boss_override != null:
					scene = boss_override
		# Mini-boss override (28/05): si stage marcado is_mini_boss + tiene scene override,
		# usar override para cualquier rareza (Capitán Z4E3 = R3 con scene custom).
		elif data.is_mini_boss and data.boss_scene_override != null:
			scene = data.boss_scene_override
		if scene == null:
			push_warning("World: scene null para clase %d." % entry.enemy_class)
			continue
		for i in entry.count:
			var enemy_elem: int = entry.element if "element" in entry else 0
			var enemy: Node = _instantiate_enemy(scene, entry.enemy_class, entry.rarity, enemy_elem, spawn_index, player)
			if enemy == null:
				continue
			# Pool §4 variants: override _r2_skill_data según zona (skip R4 bosses).
			# Bosses tienen patrones propios, no usan _r2_skill_data.
			if entry.rarity != GameConfig.EnemyRarity.R4:
				_apply_zone_skill_variant(enemy, entry.enemy_class)
			# Registrar en StageManager para que cuente al morir.
			StageManager.register_enemy(enemy)
			# Registrar en DropSystem para que dropee materiales al morir.
			# entry.material_drops puede ser null - DropSystem hace fallback a stage.material_drops.
			DropSystem.register_enemy(enemy, entry.material_drops)
			# Registrar en ExperienceSystem para que dé XP al morir. GDD §6.1.
			ExperienceSystem.register_enemy(enemy, entry.rarity)
			# Registrar en GoldSystem para que dé Oro al morir (con mult de Momentum). GDD §5.5.
			GoldSystem.register_enemy(enemy, entry.rarity)
			spawn_index += 1


func _instantiate_enemy(scene: PackedScene, enemy_class: int, rarity: int, enemy_element: int, index: int, player: Node2D) -> Node:
	var enemy: Node = scene.instantiate()
	if enemy == null:
		push_warning("World: no se pudo instanciar enemy.")
		return null
	# Setear class, rarity y element ANTES de add_child para que _ready las consuma.
	if "enemy_class" in enemy:
		enemy.enemy_class = enemy_class
	if "rarity" in enemy:
		enemy.rarity = rarity
	# Propagar elemento elemental. GDD §5.3.
	if "element" in enemy:
		enemy.element = enemy_element
	if enemy is Node2D:
		(enemy as Node2D).position = _pick_random_spawn_position(player)
	var rarity_label: String = GameConfig.rarity_name_of(rarity)
	var class_label: String = GameConfig.class_name_of(enemy_class)
	enemy.name = "Stage_%s_%s_%d" % [class_label, rarity_label, index]
	add_child(enemy)
	return enemy


# ─── Modo playground (fallback) ──────────────────────────────────────────────

func _spawn_playground() -> void:
	# Replica del modo TEST_FIXED_COUNTS original — útil para iterar 1 stage manual.
	var player: Node2D = get_node_or_null("Player")
	var index: int = 0
	for i in GameConfig.TEST_MELEE_COUNT:
		_spawn_legacy(scene_melee, "Melee", index, player); index += 1
	for i in GameConfig.TEST_TANK_COUNT:
		_spawn_legacy(scene_tank, "Tank", index, player); index += 1
	for i in GameConfig.TEST_ARCHER_COUNT:
		_spawn_legacy(scene_archer, "Archer", index, player); index += 1
	for i in GameConfig.TEST_MAGE_COUNT:
		_spawn_legacy(scene_mage, "Mage", index, player); index += 1


func _spawn_legacy(scene: PackedScene, class_label: String, index: int, player: Node2D) -> void:
	if scene == null:
		return
	var enemy: Node2D = scene.instantiate() as Node2D
	if enemy == null:
		return
	enemy.position = _pick_random_spawn_position(player)
	enemy.name = "Test_%s_%d" % [class_label, index]
	add_child(enemy)


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _scene_for_class(enemy_class: int) -> PackedScene:
	match enemy_class:
		GameConfig.EnemyClass.MELEE: return scene_melee
		GameConfig.EnemyClass.TANK: return scene_tank
		GameConfig.EnemyClass.ARCHER: return scene_archer
		GameConfig.EnemyClass.MAGE: return scene_mage
	return null


func _boss_scene_for_class(enemy_class: int) -> PackedScene:
	match enemy_class:
		GameConfig.EnemyClass.TANK: return scene_boss_guardian
		GameConfig.EnemyClass.MELEE: return scene_boss_duelista
		GameConfig.EnemyClass.ARCHER: return scene_boss_cazadora
		GameConfig.EnemyClass.MAGE: return scene_boss_heraldo
	return null


## Override _r2_skill_data según zona activa. Pool §4 variants canon Leo 27/05.
## Llamado post-spawn solo para R2/R3 (R4 bosses tienen patrones propios).
func _apply_zone_skill_variant(enemy: Node, enemy_class: int) -> void:
	if enemy == null or not enemy.has_method("_r2_telegraph_sec"):
		return  # enemy.gd no o boss especializado sin variant system
	var zone_id: int = StageManager.current_zone if StageManager != null else 1
	var zone_map: Dictionary = ZONA_SKILL_VARIANTS.get(zone_id, {})
	if zone_map.is_empty():
		return  # zona 1 o sin override → canon (R2_SKILL_RESOURCES en enemy.gd)
	var skill_path: String = zone_map.get(enemy_class, "")
	if skill_path.is_empty():
		return  # esta clase no tiene override en esta zona → canon
	var skill_data: EnemySkillData = load(skill_path) as EnemySkillData
	if skill_data == null:
		push_warning("World: no se pudo cargar skill variant '%s' para zona %d" % [skill_path, zone_id])
		return
	enemy._r2_skill_data = skill_data
	# Re-init cooldown con cd_min del nuevo skill (sobreescribe el canon seteado en _ready).
	if enemy.has_method("_r2_cd_min"):
		enemy._skill_r2_cooldown = enemy._r2_cd_min()


func _load_default_stages() -> void:
	# Selección por zona: StageManager.current_zone (default 1) seteado por MainMenu.
	# Si la zona no existe en ZONE_STAGE_PATHS, fallback a la lista local DEFAULT_STAGE_PATHS.
	var zone_id: int = StageManager.current_zone if StageManager != null else 1
	var loaded: Array[StageData] = StageManager.get_stages_for_zone(zone_id) if StageManager != null else []
	if not loaded.is_empty():
		for s in loaded:
			stages.append(s)
		return
	# Fallback compat: zone_id 1 path local.
	for path in DEFAULT_STAGE_PATHS:
		var stage: StageData = load(path) as StageData
		if stage == null:
			push_warning("World: no se pudo cargar stage default en '%s'." % path)
			continue
		stages.append(stage)


func _clear_existing_enemies() -> void:
	for child in get_children():
		if child is Enemy:
			child.queue_free()


func _clear_projectiles() -> void:
	# Los proyectiles viven en current_scene (no como hijos del world directamente
	# en algunos casos). Buscamos por grupo si está, sino por clase.
	for child in get_children():
		if child is Projectile:
			child.queue_free()


## Aplica tint multiplicativo a TODAS las capas parallax (cielo + mid + foretop + forebottom).
## Antes solo tocaba el cielo: visualmente las capas mid/fore tapaban el cambio y se sentía
## estático. Ahora el ambient_tint del StageData impacta toda la composición.
func _apply_ambient_tint(tint: Color) -> void:
	var sprites: Array[Sprite2D] = [_bg_sprite, _mid_sprite, _fore_top_sprite, _fore_bottom_sprite]
	for s: Sprite2D in sprites:
		if s == null:
			continue
		var tween: Tween = create_tween()
		tween.tween_property(s, "modulate", tint, 0.6)


## Devuelve la sub-zona ("a"/"b"/"c") según stage_index. GDD §7.1 Valle de los Ecos:
## stages 1-2 = ruinas amanecer, 3-4 = bosque mediodía, 5+boss = bosque profundo atardecer.
func _zone_key_for_stage(stage_index: int) -> String:
	if stage_index <= 2:
		return "a"
	elif stage_index <= 4:
		return "b"
	return "c"


## Swap de las 4 capas parallax según el stage_index. Antes solo cambiaba el cielo
## (LayerBG); como mid/fore son más visibles y tapaban el cambio, daba sensación de
## fondo estático. Ahora rota también mid (ruinas→bosque) + foretop (oculto en
## ruinas, ramas en bosque) + forebottom (hierba siempre, pero queda preparado
## para variantes futuras).
func _apply_background_for_stage(stage_index: int) -> void:
	var key: String = _zone_key_for_stage(stage_index)
	if _bg_sprite != null:
		var bg_tex: Texture2D = BG_TEXTURES.get(key, null) as Texture2D
		if bg_tex != null:
			_bg_sprite.texture = bg_tex
	if _mid_sprite != null:
		var mid_tex: Texture2D = MID_TEXTURES.get(key, null) as Texture2D
		if mid_tex != null:
			_mid_sprite.texture = mid_tex
	if _fore_top_sprite != null:
		var ft_tex: Texture2D = FORE_TOP_TEXTURES.get(key, null) as Texture2D
		# ForeTop puede ser null intencional (sub-zona "a" sin ramas).
		_fore_top_sprite.texture = ft_tex
		_fore_top_sprite.visible = ft_tex != null
	if _fore_bottom_sprite != null:
		var fb_tex: Texture2D = FORE_BOTTOM_TEXTURES.get(key, null) as Texture2D
		if fb_tex != null:
			_fore_bottom_sprite.texture = fb_tex


## Aplica todo lo visual de la stage: BG textura + tint + plataformas + decoraciones.
func _apply_layout(data: StageData) -> void:
	_apply_background_for_stage(data.stage_index)
	_apply_ambient_tint(data.ambient_tint)
	_apply_platforms(data.platform_overrides, data.hide_default_platforms)
	_apply_decorations(data.show_decorations)


## Maneja las plataformas según override + flag hide_default.
## - overrides no vacío → oculta defaults y crea nuevas.
## - overrides vacío + hide_default=true → arena limpia (todas ocultas).
## - overrides vacío + hide_default=false → muestra defaults del .tscn.
##
## CRITICAL: además de visible+collision, agrega/remueve del grupo "platform".
## Razón: el enemy.gd busca plataformas intermedias por `get_nodes_in_group("platform")`
## que NO filtra por visible. Si dejamos las defaults en el grupo, los enemies
## las consideran candidatas incluso ocultas (bug visto en E2 — saltaban hacia
## Platform1 default en vez de las overrides).
func _apply_platforms(overrides: Array[StagePlatformConfig], hide_default: bool) -> void:
	# Limpiar plataformas dinámicas previas.
	for p in _override_platforms:
		if is_instance_valid(p):
			p.queue_free()
	_override_platforms.clear()

	var defaults_visible: bool = overrides.is_empty() and not hide_default
	for p in _default_platforms:
		if not is_instance_valid(p):
			continue
		p.visible = defaults_visible
		_set_platform_collision(p, defaults_visible)
		# Remover del grupo si oculta para que la AI no la considere candidata.
		if defaults_visible:
			if not p.is_in_group("platform"):
				p.add_to_group("platform")
		else:
			if p.is_in_group("platform"):
				p.remove_from_group("platform")

	for cfg in overrides:
		if cfg == null:
			continue
		var plat: StaticBody2D = _build_platform(cfg)
		add_child(plat)
		_override_platforms.append(plat)


## Construye una plataforma StaticBody2D + CollisionShape2D + visual desde un config.
func _build_platform(cfg: StagePlatformConfig) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = cfg.position
	body.collision_mask = 0
	body.add_to_group("platform")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = cfg.size
	shape.shape = rect
	body.add_child(shape)

	# Visual: 3 rects (top grass, mid body, bottom shadow) para parecerse a las default.
	var half_w: float = cfg.size.x * 0.5
	var half_h: float = cfg.size.y * 0.5

	var body_visual := ColorRect.new()
	body_visual.color = cfg.color
	body_visual.offset_left = -half_w
	body_visual.offset_top = -half_h
	body_visual.offset_right = half_w
	body_visual.offset_bottom = half_h
	body.add_child(body_visual)

	var grass_top := ColorRect.new()
	grass_top.color = Color(0.25, 0.55, 0.18, 1)
	grass_top.offset_left = -half_w
	grass_top.offset_top = -half_h - 1.0
	grass_top.offset_right = half_w
	grass_top.offset_bottom = -half_h + 4.0
	body.add_child(grass_top)

	var shadow := ColorRect.new()
	shadow.color = Color(0.18, 0.13, 0.09, 0.7)
	shadow.offset_left = -half_w
	shadow.offset_top = half_h - 4.0
	shadow.offset_right = half_w
	shadow.offset_bottom = half_h
	body.add_child(shadow)

	return body


func _set_platform_collision(p: Node2D, enabled: bool) -> void:
	# Habilita/deshabilita la CollisionShape2D dentro de la plataforma.
	for child in p.get_children():
		if child is CollisionShape2D:
			child.disabled = not enabled


func _apply_decorations(show: bool) -> void:
	if _decorations != null:
		_decorations.visible = show


func _pick_random_spawn_position(player: Node2D) -> Vector2:
	# Intenta hasta 30 veces encontrar una posición lejana al player.
	var player_pos: Vector2 = player.position if player != null else Vector2.ZERO
	for attempt in 30:
		var x: float = randf_range(spawn_x_min, spawn_x_max)
		var pos: Vector2 = Vector2(x, spawn_y)
		if pos.distance_to(player_pos) >= min_distance_from_player:
			return pos
	return Vector2(randf_range(spawn_x_min, spawn_x_max), spawn_y)
