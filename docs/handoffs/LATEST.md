> **Origen:** [2026-05-27-1625-completo.md](2026-05-27-1625-completo.md) · Generado: 27 May 2026, 16:25 · Handoff CONSOLIDADO sesión completa

# Handoff Completo — 27 May 2026, 16:25 (Cierre Fase 3 lógica al ~95%)

**Sesión consolidada (07:40 → 16:25):** Marathon de lógica pura. Sistema generic StatusEffect, EnemySkillData Resource, PlayerSkillSystem (Furia → habilidad), 6 elementos canon Leo definitivos (FUEGO/AGUA/TIERRA/VIENTO/LUZ/SOMBRA con doble eje natural+cósmico), Zonas 2/3/4 lógica completa (4 bosses nuevos), 16 enemy skills (R2 canon + 10 variants pool §4), 6 player skills activas, 15 items dedicados elementos, 6 set bonuses runtime efectivos, mini-boss type, multi-zona routing, Projectile vampire heal + reflexión.
**Fase del proyecto:** 3 — Sistemas RPG Completos. Lógica ~95% cerrada. Único pendiente: visual estético TODAS las zonas.
**GDD versión vigente:** v2.1 (código va por delante; GDD §5.3 sigue con 3 elementos canon, sync diferido post-playtest por decisión Leo).
**Generado por:** sesión Claude consolidada, 58 tasks acumuladas.

---

## 1. Resumen ejecutivo

Lo más importante del día:

1. **6 elementos canon definitivos** (Leo decisión 27/05): NEUTRO, FUEGO, AGUA, TIERRA, VIENTO, LUZ, SOMBRA. Dos triángulos: primario FUEGO>TIERRA>AGUA>FUEGO + secundario VIENTO>LUZ>SOMBRA>VIENTO. Cross-triángulo neutral. **Diseño dual eje:** natural (control + daño puro) vs cósmico (alteración stats + supervivencia + maldiciones).
2. **StatusEffect system genérico** + 12 statuses canónicos (burn, freeze, fractura, desequilibrio, bendicion, miasma, slow, stun, post_dash_damage, post_dash_invis, espiritu_marcial, muralla_estatica).
3. **PlayerSkillSystem** Furia → habilidad. 6 player skills + autoload + save loadout + input map skill_1/2/3.
4. **16 enemy skills .tres** (4 R2 canon por clase + 10 variants pool §4 implementadas con dispatch por id + asignadas por zona).
5. **3 bosses nuevos**: Ignis (Zona 2 FUEGO Melee 5 patrones), Lyss (Zona 3 AGUA Mage 6 patrones inc Muralla refleja), Vael (Zona 4 LUZ Mage 5 patrones inc Lanza Luz Line2D). Total 7 bosses canon en el juego.
6. **Zonas 2/3/4 lógica completa** (materials + drop tables + stages + bosses + recetas) — sin visual.
7. **15 items dedicados** (FUEGO/AGUA/TIERRA originales + 3 nuevos FUEGO BOW/STAFF + 4 nuevos AGUA + 9 nuevos VIENTO/LUZ/SOMBRA). 6 set bonuses runtime efectivos.
8. **Infra reusable**: Projectile.source_entity + reflect API, HitboxComponent.ignore_shield, ShieldComponent.consume_charge_force + add_temporary_charges, StageData.is_mini_boss + boss_scene_override, StageManager multi-zona.

---

## 2. Qué se hizo en detalle

### 2.1 StatusEffect System genérico (Sprint 1)

**Files creados:**
- `scripts/data/status_effect_data.gd` (Resource: id, duration, magnitude, tick_interval, stack_mode, magnitude_policy, display_name, color)
- `scripts/components/status_effect_component.gd` (Node: apply/has/get_magnitude/get_remaining/remove/clear + signals effect_applied/expired/ticked + tick lifecycle)
- `tests/systems/status_effect_component_test.gd` (18 tests puros)

**Stack modes:** REFRESH (default), EXTEND, INDEPENDENT, IGNORE.
**Magnitude policies:** KEEP_MAX (default), KEEP_MIN, KEEP_LATEST, SUM.

Wireado runtime en Player.gd + Enemy.gd como child node instanciado en `_ready()`.

### 2.2 Migración ad-hoc → status effects (Sprint 1)

Eliminados de player.gd: `_external_speed_*`, `_espiritu_marcial_*`, `_post_dash_damage_*`, `_post_dash_invis_*`, `_tick_*` helpers.

API pública preservada: `apply_slow(mult, duration)` (boss Cazadora intacto).
Side effects en handlers: `_on_status_applied/expired/ticked` (alpha invis, force_elem_advantage cleanup, DOT ticks).

### 2.3 6 elementos canon + eje cósmico (decisión Leo)

**Iteraciones:** primero 3→6 con RAYO, luego rename RAYO→LUZ (canon definitivo Leo).

`ItemData.Element` enum extendido:
```
NEUTRO=0, FUEGO=1, AGUA=2, TIERRA=3, VIENTO=4, LUZ=5, SOMBRA=6
```

`GameConfig.ELEMENT_ADVANTAGE`:
- Primario: FUEGO>TIERRA>AGUA>FUEGO
- Secundario: VIENTO>LUZ>SOMBRA>VIENTO
- Cross-triángulo: ×1.0 neutral

**Status synergy (30% chance on-hit) — diseño dual eje:**

Eje natural (control + daño elemental puro):
- FUEGO → Quemadura (DOT 3s, 3 dmg/tick)
- AGUA → Congelación (-30% vel 2s)
- TIERRA → Fractura (próximo hit +20%, single-use consume, ventana 5s)
- VIENTO → Desequilibrio (interrumpe ataque actual + 1.5s CD penalty)

Eje cósmico (santidad/maldad/stats):
- LUZ → Bendición Divina (vampire heal: atacante 5% HP máx, no aplica status defender)
- SOMBRA → Miasma (DOT 5s + bypass armor + -50% Furia gen, stack INDEPENDENT)

Tests: `tests/systems/element_system_test.gd` extendido (16 tests) + `element_status_synergy_test.gd` (10 tests).

### 2.4 EnemySkillData Resource — data-driven skills

`scripts/data/enemy_skill_data.gd` Resource:
- telegraph_sec, cd_min, cd_max, attack_duration
- damage_mult, telegraph_type, params (Dictionary)

4 .tres canon R2 (uno por clase) + 10 variants pool §4 (Set B/C).

`enemy.gd` dispatch:
- `_enter_r2_skill_attack / _tick_r2_skill_attack` rama por `_r2_skill_data.id` (variant system).
- Default fallback al match por enemy_class (canon).
- Helpers: `_r2_telegraph_sec / _r2_cd_min / _r2_cd_max / _r2_attack_duration / _r2_param(key, default)`.

`R2_SKILL_TABLE` const queda como fallback defensivo.

### 2.5 Skills pool §4 — 10 implementadas

**Batch 1 (Set B/C melee):**
- `r2_melee_giratorio`: hitbox activo durante todo el spin (1.5s) + avance lento + multi-hit tick.
- `r2_melee_tajo_doble`: 2 hits secuenciales con gap 0.1s.
- `r2_melee_patada`: hitbox corto + knockback fuerte.

**Batch 2 (AoE telegraph):**
- `r2_melee_salto_asalto`: AoeTelegraph + jump arc + landing damage 75px + knockback.
- `r2_mage_nova_hielo`: AoeTelegraph bajo player + AoE damage 70px + aplica FREEZE.
- `r2_mage_erupcion_terrestre`: AoeTelegraph + AoE 50px + aplica FRACTURA single-use.

**Batch 3 (ranged + utility):**
- `r2_archer_disparo_reactivo`: proyectil veloz (×2 speed, ÷2 dmg).
- `r2_mage_rafaga_arcana`: 3 proyectiles secuenciales con delay 0.12s.
- `r2_tank_gancho_ascendente`: hitbox + `ShieldComponent.consume_charge_force(2)` rompe escudo.
- `r2_melee_arma_imbuida`: buff propio 5s. `HitboxComponent.ignore_shield = true` cross-state.

### 2.6 Skill variants assignment por zona (decisión Leo)

`world.gd` const `ZONA_SKILL_VARIANTS`:
- Z2 (FUEGO): MELEE→Giratorio, ARCHER→Disparo Reactivo, MAGE→Erupción Terrestre
- Z3 (AGUA): MELEE→Tajo Doble, TANK→Gancho Ascendente, MAGE→Nova Hielo
- Z4 (VIENTO/LUZ): MELEE→Salto Asalto, ARCHER→Disparo Reactivo, MAGE→Ráfaga Arcana

`world._apply_zone_skill_variant(enemy, class)` override post-spawn de `_r2_skill_data`. Skip R4 bosses (tienen patrones propios).

### 2.7 R3 skills nuevas (refactor enemy.gd dispatch por clase)

- Archer R3 → **Lluvia de Flechas**: 3 AoeTelegraph staggered (spread 70px) + damage radial tras 0.55s.
- Mage R3 → **Lluvia de Meteoros**: 3 AoeTelegraph staggered (spread 80px) + AoE damage + aplica BURN.
- Tank R3 → **Muralla Estática**: status `muralla_estatica` 1.2s → invuln direccional frontal (check en `HurtboxComponent._is_blocked_by_directional_invuln`). Aura azul GPUParticles.
- Melee R3 → Sed de Sangre (preservado).

### 2.8 PlayerSkillSystem (Furia → habilidad)

`scripts/data/player_skill_data.gd` Resource — 9 effect types: HEAL, BUFF_DAMAGE, AOE_DAMAGE, AOE_BURN, DASH_FORWARD, SPAWN_PROJECTILE, GAIN_SHIELD, INVIS, APPLY_SLOW_AOE.

`scripts/systems/player_skill_system.gd` autoload:
- 3 slots equipados + cooldowns
- Signals: `skill_used / cooldown_started / slot_equipped / skill_failed(reason)`
- Ejecutor por effect_type
- `_serialize_state / _restore_state` para persistencia SaveSystem

6 skills .tres iniciales: `embestida, bola_fuego, onda_sismica, curacion, escudo_magico, sombra`.

Input map en `project.godot`: `skill_1/2/3 → teclas 1/2/3`.
Loadout default: slot 0=Embestida, 1=Bola Fuego, 2=Onda Sísmica.

`tests/systems/player_skill_system_test.gd` (13 tests).

### 2.9 Zona 2 — Fragua Cenicienta (FUEGO) completa

**Materials:** `fragmento_ascuas` R1, `mineral_hierro_rojo` R2, `nucleo_igneo` R3.
**Stages:** 6 etapas + boss stage (`zona2_etapa_1..6.tres` + `zona2_etapa_boss.tres`).
**Drop tables:** materials, boss_materials, boss_items.
**Recetas:** `craft_peto_brasas`, `craft_aegis_igneo`.
**Items nuevos FUEGO:** `arco_brasas` (BOW), `vara_brasas` (STAFF).

**Boss Ignis** (`boss_ignis.gd` 357 líneas + `.tscn`):
1. Hammer Overhead (telegraph 0.7s + dmg ×1.5)
2. Salto Sísmico (jump + landing AoE + PersistentHazard lava 4s)
3. Lluvia Meteoros (reusa pipeline R3 Mage)
4. Sed de Sangre F2 (+25% vel 6s)
5. Corte Giratorio F2 (hitbox móvil 1.5s)

HP 1.1× MAGE R4 base. Velocidad 0.85× (lento imponente).

### 2.10 Zona 3 — Acueducto del Lamento (AGUA) completa

**Materials:** `gota_lamento`, `cristal_escarcha`, `nucleo_abisal`.
**Stages:** 7 etapas + boss.
**Items nuevos AGUA:** `espada_lamento` (SWORD), `arco_glacial` (BOW), `cota_glacial` (ARMOR), `escudo_glacial` (SHIELD).
**Recetas:** `craft_cota_cuero_glacial` (placeholder).

**Boss Lyss** (`boss_lyss.gd` 400+ líneas + `.tscn`):
1. Látigo Helado (hitbox rect lineal)
2. Nova de Hielo (AoeTelegraph + AoE + FREEZE)
3. Triple Tiro (3 fireballs spread)
4. Vórtice Gravedad F2 (pull player hacia boss)
5. Canto Helado F2 (aura aplica SLOW si player <220px)
6. **Muralla Estática Refleja F2** (refleja proyectiles del player — REQ-INFRA grande resuelto)

### 2.11 Zona 4 — Cumbres de la Tempestad (VIENTO/LUZ) completa

**Materials:** `pluma_tormenta`, `fragmento_cielo_roto`, `nucleo_fulgurante`.
**Stages:** 5 etapas + mini-boss etapa 3 (Capitán de los Vientos R3) + boss stage.
**Items nuevos VIENTO/LUZ/SOMBRA:** 9 items (3 weapons + 3 armors + 3 shields).
- VIENTO: arco_huracan, manto_viento, paves_viento
- LUZ: vara_luz, casulla_luz, halo_luz
- SOMBRA: daga_sombra, capa_sombra, orbe_sombra

**Boss Vael** (`boss_vael.gd` 350+ líneas + `.tscn`):
1. Ráfaga Arcana (3 proyectiles delay 0.12s)
2. Patada Frontal (hitbox + knockback fuerte 300/-180)
3. Destello Sanador (heal 8% HP, auto-cast F2 si HP ≤ 30%)
4. Salto Cegador F2 (jump + landing AoE 90px + aplica STUN player)
5. **Lanza de Luz Penetrante F2** (Line2D tracking lerp 1.8 rad/s + tick damage cada 0.3s — REQ-INFRA grande resuelto)

HP 0.95× MAGE R4 base. Velocidad 1.6× (boss más rápido del juego).

`zona4_etapa_3.tres` marked `is_mini_boss = true`.

### 2.12 Set Bonuses cósmicos VIENTO/LUZ/SOMBRA — runtime efectivo

`SetBonusData` enum extendido a 7 elementos + 6 fields nuevos:
- `viento_move_speed_pct_2pc`, `viento_desequilibrio_chance_mult_3pc`
- `luz_passive_hp_regen_2pc`, `luz_bendicion_heal_mult_3pc`
- `sombra_miasma_duration_mult_2pc`, `sombra_miasma_chance_mult_3pc`

3 .tres nuevos: `set_bonus_viento`, `set_bonus_luz`, `set_bonus_sombra`.

**Wireado runtime (decisión Leo prioritaria):**
- HitboxComponent + Projectile: helpers `_get_element_status_chance(elem) / _get_bendicion_heal_pct() / _get_miasma_duration_mult()`. Solo team=1 (player) consulta SetBonusSystem. MIASMA con duration_override si SOMBRA 2pc activo.
- PlayerStatsComponent._apply_set_bonus extendido: LUZ 2pc → player.set_luz_passive_regen(rate). VIENTO 2pc → bump multiplicativo move_speed_mult.
- player.gd: `_luz_passive_regen_per_sec` field + `_tick_luz_passive_regen(delta)` accumulator (cada 1.0s `health.heal()`).

### 2.13 Mini-boss stage type

`StageData.is_mini_boss: bool` nuevo flag.
`stage_banner.gd`: muestra "MINI-BOSS — ETAPA N / M" en dorado tamaño intermedio entre normal y BOSS.
Zona 4 etapa 3 marcada (Capitán de los Vientos).

### 2.14 World/StageManager multi-zona

`StageManager.current_zone: int = 1` + `ZONE_STAGE_PATHS` dict.
API: `set_zone(N)` + `get_stages_for_zone(N) → Array[StageData]`.
`World._load_default_stages` consume zona activa con fallback compat zona 1.
`StageData.boss_scene_override: PackedScene` — boss propio sin tocar routing por clase.

### 2.15 Projectile vampire heal + reflexión

**Vampire heal (LUZ):**
- `Projectile.source_entity: Node` + `set_source(entity)` API.
- LUZ branch en `_try_apply_element_status` → `_apply_bendicion_heal_to_source()` cura source_entity 5% HP máx (con LUZ 3pc set bonus mult).
- 13 sites de `proj.launch(...)` actualizados con `proj.set_source(self)`.

**Reflexión (Lyss Muralla):**
- `Projectile.reflect(new_team, new_source, new_direction)` API: swap team + source + reset pierce_hit_set + tinte dorado.
- Lyss boss F2 estado: cada frame durante MURALLA_ACTIVE busca proyectiles team=1 dentro de radio 90px → reflect(2, self, hacia_player).

### 2.16 ShieldComponent extensiones

- `add_temporary_charges(N, duration)`: +N cargas temporales con expiración + clamp current ≤ max original al expirar.
- `consume_charge_force(N)`: destruye N cargas force-mode sin requerir is_blocking (Tank R2 Gancho Ascendente).

### 2.17 HitboxComponent.ignore_shield

Flag para skip de escudo defensor (pool §4 Arma Imbuida).
`HurtboxComponent.receive_hit` chequea `source.ignore_shield` antes de llamar `shield.try_absorb`.

### 2.18 Save loadout PlayerSkillSystem

- `PlayerSkillSystem._serialize_state / _restore_state` (slots como IDs string).
- `SaveSystem._build_save_data` incluye `skill_loadout`.
- Autoload reordenado: `PlayerSkillSystem` antes de `SaveSystem` para load order.
- player.gd: equip default solo si slot está vacío tras load (save respetado).

### 2.19 Doc updates

- `.claude/docs/habilidades_generales.md` reescrita extensa:
  - §2 tabla R4 actualizada con 7 bosses canon
  - §3 status genérico marcado IMPL con 12 .tres
  - §4.1/4.2/4.2.5/4.3 10 skills variants marcadas IMPL + tabla canónica de assignment por zona
  - §5 PlayerSkillSystem IMPL + 6 skills + arquitectura
  - §7.5 reescrita doble eje natural/cósmico con tablas
  - §8 actualizado
- `.claude/docs/fases.md`: sección "Zonas 2/3/4 lógica anticipadamente" + decisiones canon
- `.claude/docs/glossary.md`: 6 elementos canon + doble eje
- `docs/features/combat/element_system.md`: tablas extendidas
- `docs/features/zones/zona_3_acueducto.md`: Lyss skill rename
- `docs/features/zones/zona_4_cumbres.md`: reescrito completo con LUZ canon
- `.claude/agents/narrative-lore.md`: zona "Aurora Cegadora" (LUZ)

### 2.20 Tests creados (no ejecutados — sin Godot binario en shell)

| Test | Cobertura |
|---|---|
| `status_effect_component_test.gd` | 18 tests stack modes, magnitude policies, ticks, remove, clear |
| `player_skill_system_test.gd` | 13 tests equip/unequip, can_use, try_use, cooldown decay, signals |
| `element_status_synergy_test.gd` | 10 tests Fractura consume, Miasma bypass armor, Bendición canonical |
| `element_system_test.gd` extendido | 7 tests nuevos triángulo secundario + cross-triángulo neutral |

---

## 3. Estado actual

### 3.1 Decisiones tomadas (Leo)

- **6 elementos canon definitivos**: FUEGO, AGUA, TIERRA, VIENTO, LUZ, SOMBRA. RAYO descartado.
- **Diseño dual eje**: natural vs cósmico (espec Leo doc).
- **Política variants por zona** (no rareza/random/spawn).
- **GDD §5.3 sync diferido** post-playtest.
- **SetBonus cósmico prioritario sobre otras opciones**.
- **Boss override per-stage** vía `StageData.boss_scene_override`.
- **Wireado SetBonusSystem via query helpers** (no runtime vars sincronizadas).
- **Vael Lanza Luz tracking lerp 1.8 rad/s** (esquivable).
- **Lyss Muralla refleja con tinte dorado** (legibilidad player).
- **BENDICION vampire al atacante** (interpretación pragmática spec).
- **MIASMA bypass armor + halve furia** según spec exacta.

### 3.2 Decisiones pendientes Leo

1. **GDD §5.3 oficial sigue con 3 elementos** — sync cuando Leo apruebe edición (CLAUDE.md prohíbe sin permiso explícito).
2. **Tests integration cosmic statuses** — scene tree mocks SetBonusSystem + FuriaComponent. Tests puros solo validan canon static.
3. **Lyss healing en proyectil reflejado** — si proyectil LUZ reflejado golpea, ¿Lyss recibe vampire heal (source = Lyss tras reflect)?
4. **Tank skill variants zona 2 + zona 4** — tabla canon no asigna variant para Tank en esas zonas (queda canon Taunt). Considerar variant.
5. **Drop tables zona 2/3 wireado items dedicados FUEGO/AGUA** — los items existen pero no son loot todavía. Editar `zona2_boss_items.tres` + `zona3_boss_items.tres`.
6. **Tunear chances/cooldowns/damages post-playtest**:
   - Element status 30% chance puede ser mucho para LUZ vampire infinito o poco para SOMBRA snowball.
   - Vael velocidad 1.6× puede ser overwhelming.
   - Arma Imbuida 5s + Desequilibrio CD penalty puede stack overpowered.

### 3.3 Repo state

- **Sucio masivo.** ~95 archivos nuevos + ~35 modificados acumulados.
- **NO commiteado.** Per regla local Leonardo, no commit sin pedido explícito.

---

## 4. Qué sigue (próxima sesión)

### 4.1 Validación primero

**Compile + tests headless en Godot 4.6:**
```bash
godot --headless --script res://tests/systems/element_system_test.gd
godot --headless --script res://tests/systems/status_effect_component_test.gd
godot --headless --script res://tests/systems/player_skill_system_test.gd
godot --headless --script res://tests/systems/element_status_synergy_test.gd
godot --headless --script res://tests/systems/r2_skills_test.gd
godot --headless --script res://tests/systems/capstone_skills_test.gd
```

**In-game smoke tests prioritarios:**
1. **Zona 1**: validar nada regresó. Quemadura BURN visible, Congelación slow, Fractura próximo hit +20%.
2. **Zona 2 skill variants**: enemies MELEE = Corte Giratorio, Archers = Disparo Reactivo, Mages = Erupción Terrestre.
3. **Zona 3 boss Lyss**: F2 → Muralla Estática refleja proyectiles del player. Hacer fireball + ver tinte dorado regresar.
4. **Zona 4 boss Vael**: F2 → Lanza de Luz Penetrante Line2D tracking lerp + tick damage.
5. **SetBonus cósmico**: equipar 2 items LUZ → +1.5 HP/s regen pasivo. 3 items LUZ → vampire heal 5%→10%.
6. **SetBonus SOMBRA**: 2pc → Miasma 5s→7.5s. 3pc → chance 30%→45%.
7. **PlayerSkills**: equipar arma, atacar para Furia, presionar 1/2/3 → Embestida/Bola Fuego/Onda Sísmica.

### 4.2 Backlog lógico restante

1. **Tests integration cosmic statuses** — scene tree mocks SetBonusSystem + FuriaComponent.
2. **UI MainMenu selector zona** — wirear `StageManager.set_zone(N)` button. API existe, falta UI.
3. **Sistema logros / achievements** — track kills, primeras vez bosses. Nueva feature.
4. **Tutorial integrado** — UI explicaciones in-game.
5. **Coliseo Fase 4 prep** — backend estructural sin servidor real (Firebase/Supabase).
6. **Tank skill variants zona 2 + zona 4** (canon Taunt actual).
7. **Drop tables zona 2/3 wireado** items dedicados FUEGO/AGUA en `_boss_items.tres`.
8. **Lyss healing en proyectil reflejado** (edge case opcional).
9. **GDD §5.3 sync** cuando Leo apruebe.

### 4.3 Backlog visual (TODAS las zonas)

- Arte IA + sprites + parallax por zona (Midjourney/SD/Nano Banana).
- Audio pipeline + tracks per-zona + SFX por skill.
- VFX por status (Quemadura llamas, Congelación cristales, Fractura crack, Desequilibrio swirl, Bendición halo, Miasma aura verde).
- HUD chips player skills con cooldowns + Furia meter.
- UI loadout player skills (drag-and-drop o picker).
- UI bestiario interactivo.

---

## 5. Contexto necesario para próxima sesión

### 5.1 Arquitectura nuevos componentes

- **StatusEffectComponent**: hijo runtime de Player + Enemy. Lifecycle + signals. Owner aplica side effects vía signals + queries.
- **EnemySkillData**: Resource .tres. Dispatch por id en `enemy.gd`. `_r2_skill_data` set en `_ready()` desde `R2_SKILL_RESOURCES` const o override por zona.
- **PlayerSkillSystem**: autoload registrado ANTES de SaveSystem (orden importa). 3 slots, signals, `_serialize_state/_restore_state`.

### 5.2 Convenciones canon

**Status effect ids:** `slow, espiritu_marcial, post_dash_damage, post_dash_invis, burn, stun, fractura (filename vulnerable.tres), desequilibrio, bendicion, miasma (filename poison.tres), muralla_estatica`.

Mismatches filename ↔ id intencionales (`vulnerable.tres → id "fractura"`, `poison.tres → id "miasma"`) — filenames legacy.

**Boss state ints:** Guardian 100s, Duelista 200s, Ignis 300s, Lyss 400s, Vael 500s. Próximos: 600+.

**HurtboxComponent:** bypass_shield si `source.ignore_shield` → skip try_absorb.
**ShieldComponent:** `consume_charge_force(N)` para skills hostiles. `add_temporary_charges(N, dur)` para skills aliadas.
**SetBonusSystem:** consulta en HitboxComponent/Projectile via helpers `_get_*_mult`. Solo team=1 (player) tiene sets.

### 5.3 Reglas canon 6 elementos

- Triángulo primario: FUEGO > TIERRA > AGUA > FUEGO (×1.5/×0.66).
- Triángulo secundario: VIENTO > LUZ > SOMBRA > VIENTO.
- Cross-triángulo: ×1.0 neutral.
- Mismo elemento ×1.0. NEUTRO involucrado ×1.0.

**Status synergy on-hit (30% base):**
- FUEGO=Quemadura, AGUA=Congelación, TIERRA=Fractura single-use, VIENTO=Desequilibrio
- LUZ=Bendición vampire heal source (NO status defender), SOMBRA=Miasma bypass armor + halve furia

### 5.4 Lecciones canon vigentes

- Edit pierde tabs → PowerShell `[char]9`.
- Variant inference con warnings-as-errors → tipar explícito.
- Tests headless NO cargan autoloads.
- Stats = Base + Equipo + Skills + Set (orden: en PlayerStatsComponent.recalculate).
- Bosses herencia Enemy + override _tick_state con state >= 100.
- Element synergy queries SetBonusSystem solo si team=1.

---

## 6. Archivos clave consolidado

### Files creados (~95 total)

**Code scripts (~15):**
- `scripts/data/status_effect_data.gd, enemy_skill_data.gd, player_skill_data.gd`
- `scripts/components/status_effect_component.gd`
- `scripts/systems/player_skill_system.gd`
- `scripts/entities/boss_{ignis,lyss,vael}.gd`

**Scenes (~3):**
- `scenes/entities/boss_{ignis,lyss,vael}.tscn`

**Tests (~3):**
- `tests/systems/{status_effect_component,player_skill_system,element_status_synergy}_test.gd`

**Resources status effects (12):**
- `resources/status_effects/{slow,espiritu_marcial,post_dash_damage,post_dash_invis,burn,stun,poison,freeze,vulnerable,muralla_estatica,desequilibrio,bendicion}.tres`

**Resources enemy skills (14):**
- `resources/enemy_skills/r2_{melee,tank,archer,mage}.tres` (canon, 4)
- `resources/enemy_skills/r2_{melee_giratorio,melee_tajo_doble,melee_patada,melee_salto_asalto,melee_arma_imbuida,mage_nova_hielo,mage_erupcion_terrestre,mage_rafaga_arcana,archer_disparo_reactivo,tank_gancho_ascendente}.tres` (variants, 10)

**Resources player skills (6):**
- `resources/player_skills/{embestida,bola_fuego,onda_sismica,curacion,escudo_magico,sombra}.tres`

**Resources materials (9):**
- `resources/materials/{fragmento_ascuas,mineral_hierro_rojo,nucleo_igneo,gota_lamento,cristal_escarcha,nucleo_abisal,pluma_tormenta,fragmento_cielo_roto,nucleo_fulgurante}.tres`

**Resources items (15 cósmicos + FUEGO/AGUA extra):**
- VIENTO: arco_huracan, manto_viento, paves_viento
- LUZ: vara_luz, casulla_luz, halo_luz
- SOMBRA: daga_sombra, capa_sombra, orbe_sombra
- FUEGO extra: arco_brasas, vara_brasas
- AGUA dedicados: espada_lamento, arco_glacial, cota_glacial, escudo_glacial

**Resources set bonuses (3 cósmicos):**
- `resources/set_bonuses/set_bonus_{viento,luz,sombra}.tres`

**Resources stages (19 — zonas 2-4):**
- Zona 2: zona2_etapa_1..6 + zona2_etapa_boss
- Zona 3: zona3_etapa_1..7 + zona3_etapa_boss
- Zona 4: zona4_etapa_1..5 + zona4_etapa_boss

**Resources drop tables (7):**
- zona2/3/4 materials + zona2/3 boss_materials + boss_items

**Resources recipes (3):**
- craft_peto_brasas, craft_aegis_igneo, craft_cota_cuero_glacial

### Files modificados claves

| Archivo | Cambios principales |
|---|---|
| `scripts/data/item_data.gd` | Element enum 4→7 valores (6 elementos canon) |
| `scripts/systems/game_config.gd` | ELEMENT_ADVANTAGE dict doble triángulo + helper comments |
| `scripts/components/hitbox_component.gd` | Element synergy + ignore_shield + SetBonus query helpers + vampire heal source |
| `scripts/projectiles/projectile.gd` | source_entity + set_source + reflect API + SetBonus helpers + vampire heal |
| `scripts/components/hurtbox_component.gd` | FRACTURA consume + invuln direccional + bypass_shield |
| `scripts/components/shield_component.gd` | add_temporary_charges + consume_charge_force |
| `scripts/entities/player.gd` | Status migration completa + miasma furia halve + desequilibrio cancel swing + luz passive regen + PlayerSkillSystem default loadout post-save |
| `scripts/entities/enemy.gd` | StatusEffectComponent child + STUN gate + slow*freeze mult + DESEQUILIBRIO handler + R3 skills nuevas + R2 skill dispatch por id + R2_SKILL_TABLE→.tres migration + 10 skill variants executors + proj.set_source en 4 sites |
| `scripts/systems/stage_manager.gd` | current_zone + ZONE_STAGE_PATHS + set_zone/get_stages_for_zone |
| `scripts/systems/save_system.gd` | skill_loadout serialize/restore + autoload reorder |
| `scripts/world/world.gd` | StageData.boss_scene_override priority + zona load + ZONA_SKILL_VARIANTS + _apply_zone_skill_variant |
| `scripts/data/stage_data.gd` | boss_scene_override + is_mini_boss fields |
| `scripts/data/enemy_spawn_entry.gd` | @export_enum 6 elementos |
| `scripts/data/set_bonus_data.gd` | enum 4→7 + 6 fields cósmicos |
| `scripts/ui/{inventory_screen,hud_combat}.gd` | display + color VIENTO/LUZ/SOMBRA |
| `scripts/ui/stage_banner.gd` | mini-boss branch dorado |
| `scripts/components/player_stats_component.gd` | LUZ passive regen + VIENTO move_speed bump compuestos |
| `scripts/entities/boss_lyss.gd` | Muralla Estática refleja proyectiles + skill nombre rename + aura cyan |
| `project.godot` | autoload PlayerSkillSystem reorder + input map skill_1/2/3 |
| `tests/systems/element_system_test.gd` | 7 tests nuevos triángulo secundario + cross |
| `resources/status_effects/{freeze,vulnerable,poison}.tres` | values + ids ajustados según spec eje natural/cósmico |
| `resources/stages/zona4_*.tres` | element NEUTRO → VIENTO/LUZ + lore canon |

---

## 7. Estado Fase 3 final

```
✅ Sistema StatusEffect genérico (12 statuses)
✅ Element synergy doble eje + 6 elementos canon Leo
✅ Triángulos primario + secundario + cross-neutral
✅ Status synergy on-hit 30% diseño dual eje
✅ SetBonus cósmicos VIENTO/LUZ/SOMBRA runtime efectivo
✅ Skill variants por zona wireados (4 zonas × 3-4 classes)
✅ EnemySkillData Resource + dispatch por id (14 skills .tres)
✅ 10 skills pool §4 implementadas (variants Set B/C)
✅ 3 R3 skills nuevas (Lluvia Flechas, Meteoros, Muralla Estática)
✅ Projectile vampire heal + reflect API
✅ HitboxComponent.ignore_shield (Arma Imbuida)
✅ HurtboxComponent FRACTURA consume + invuln direccional + bypass_shield
✅ ShieldComponent.add_temporary_charges + consume_charge_force
✅ PlayerSkillSystem (Furia → habilidad, 6 skills + save loadout + 3 slots + input map)
✅ Zona 1 completa (canon GDD)
✅ Zonas 2, 3, 4 lógica completas (materials, stages, bosses propios)
✅ 7 bosses canon completos (Guardián, Duelista, Cazadora, Heraldo, Ignis, Lyss, Vael)
✅ 15+ items elementos completos
✅ 6 set bonuses (FUEGO/AGUA/TIERRA + VIENTO/LUZ/SOMBRA) — todos efectivos runtime
✅ Mini-boss stage type + banner UI
✅ World/StageManager multi-zona
✅ Lyss Muralla Estática refleja proyectiles (REQ-INFRA resuelta)
✅ Vael Lanza Luz Penetrante Line2D tracking (REQ-INFRA resuelta)

⏹ Tests integration con scene tree (mocks SetBonusSystem + FuriaComponent)
⏹ UI MainMenu selector zona (API lista, falta UI)
⏹ Sistema logros / achievements (nuevo)
⏹ Tutorial integrado (visual+UI)
⏹ Coliseo Fase 4 prep
⏹ Visual TODAS las zonas (arte/sprites/parallax/audio/VFX)
⏹ HUD player skills + Furia meter
⏹ UI loadout player skills
⏹ GDD §5.3 sync (post-playtest)
⏹ Drop tables zona 2/3 wireado items dedicados
⏹ Tank skill variants zona 2/4 (canon Taunt actual)
⏹ Lyss healing edge case en proyectil reflejado
```

**Total acumulado:** 58 tasks cerradas. Fase 3 lógica ~95% completa. Próximo paso: validación in-game + visual estético.

---

## 8. Comandos validación

```gdscript
# Cambiar zona desde debug console
StageManager.set_zone(2)  # Fragua Cenicienta
StageManager.set_zone(3)  # Acueducto Lamento
StageManager.set_zone(4)  # Cumbres Tempestad
get_tree().change_scene_to_file("res://scenes/world.tscn")

# Forzar skill activa (debug)
PlayerSkillSystem.force_execute(load("res://resources/player_skills/curacion.tres"))

# Aplicar status manual a player (debug)
var burn = load("res://resources/status_effects/burn.tres")
get_node("/root/World/Player").status_effects.apply(burn)

# Validar canon elementos
print(GameConfig.element_modifier(ItemData.Element.FUEGO, ItemData.Element.TIERRA))  # 1.5
print(GameConfig.element_modifier(ItemData.Element.VIENTO, ItemData.Element.LUZ))    # 1.5
print(GameConfig.element_modifier(ItemData.Element.FUEGO, ItemData.Element.VIENTO))  # 1.0 (cross)
print(GameConfig.element_modifier(ItemData.Element.SOMBRA, ItemData.Element.VIENTO)) # 1.5

# Validar set bonus runtime (con player que tenga 2 items LUZ equipados)
print(SetBonusSystem.is_active(ItemData.Element.LUZ, 2))  # true si 2pc LUZ activo
print(get_node("/root/World/Player")._luz_passive_regen_per_sec)  # 1.5

# Validar skill variant aplicado a enemy zona 2
StageManager.set_zone(2)
# Spawn enemy MELEE R2 manualmente o via stage
# Verificar enemy._r2_skill_data.id == &"r2_melee_giratorio"
```

---

**Fin handoff completo.** Próxima sesión: validación headless + smoke tests + visual.
