# Handoff — 28 May 2026, 17:24 (Fase 3 cierre lógico + HUD redesign + lore Z2-4 + GDD v2.2)

**Sesión larga end-to-end.** Cierre lógico Fase 3: HUD redesign matching imagen referencia + visuales bosses/mobs procedural + contenido zonas 2-4 (items + recetas + lore + drops + mini-boss) + sync GDD v2.2 (6 elementos canon) + commit `da2b347` pusheado a `origin/main`.

**Fase del proyecto:** 3 — Sistemas RPG Completos. **Lógica ~99% cerrada**. Falta exclusivamente arte IA + audio + playtest validatorio.
**GDD versión vigente:** **v2.2** (sync 6 elementos canon 28/05).
**Commit:** [`da2b347`](https://github.com/<repo>/commit/da2b347) — 82 archivos, +6193 −114.

---

## 1. Resumen ejecutivo

Sesión más grande del proyecto. **24 tasks completadas** consecutivas. Cubre 5 áreas: UI / Visual / Combat / Contenido / Docs. Cero in-game playtest — todo desarrollo + simulación. Integrity check pasó (188 .tres / 103 .gd / 129 ids, 0 broken refs).

**Highlights:**
1. **HUD redesign Fase 1-3** matching imagen referencia Leo aprobó: PlayerAvatar + LevelBadge + StageLabel + EnemyInfo + skill chips reorganizados. PortraitFactory autoload híbrido (PNG si existe, procedural fallback).
2. **BossFigure + EnemyFigure refactor** — bosses ya no son stick figures. Silueta llena + 7 armas signature procedurales (Mazo Musgoso Guardian / Martillo Demente Ignis / etc). Mobs con accesorios por clase.
3. **Hitbox swing honesto (Pilar #2)** — polígono que rota con swing + scale por sprite. Espada=filo entero, Hammer=solo cabeza.
4. **6 statuses con VFX** + 6 player skills con VFX + grito visual Tank taunt.
5. **14 items elementales** (cobertura 6 elementos × 4 weapon types) + 14 recetas crafteo + drop tables Z2/Z3/Z4 wireados.
6. **Mini-boss Capitán de los Vientos** scene dedicada + Z4E3 spawn override.
7. **9 archivos lore** Z2/Z3/Z4 (mundo + bestiario + materiales por zona).
8. **GDD v2.2** sync §5.3 (6 elementos canon + dual triangle natural/cósmico).
9. **Backgrounds zona 1 reemplazados** con Gemini PNGs (alpha real tras script flood fill).

---

## 2. Cambios concretos sesión

### 2.1 UI / HUD redesign (Fase 1-3)

**Archivos:** `scripts/ui/hud_combat.gd` (+613 líneas), `scripts/systems/portrait_factory.gd` (nuevo, 38 líneas), `project.godot` (autoload).

- **Fase 1** PlayerAvatar 64dp top-left + LevelBadge 32dp dorado debajo (conectado a `PlayerProgression.level_up`). StageLabel top-center sobre Momentum (`StageManager.stage_started/pending` triggers).
- **Fase 2** EnemyInfo top-right (avatar + nombre + HP bar roja + rareza label). Trackea primer enemy R2+ del stage; hide on died/cleared.
- **Fase 3** skill chips reorganizados bottom-right encima touch buttons. 56dp circular. Cooldown overlay shrinkable.
- **PortraitFactory** API: `get_portrait(id) -> Texture2D | null` chequea `assets/art/portraits/<id>.png`. Cuando lleguen PNGs IA → drop in dir, se carga auto sin tocar código.

**Decisiones Leo cerradas en spec** (`docs/features/ui/hud_combat_redesign.md`):
1. ✅ Furia canon (no Maná)
2. ✅ 6 botones GDD §4.2 (3 skills + Atk Básico grande + Dash + Block)
3. ✅ Portraits híbrido (PNG si existe, procedural fallback)
4. ✅ Stage label + Momentum ambos visibles top-center
5. ✅ "25" = nivel personaje

### 2.2 Visual refactor (BossFigure + EnemyFigure + signature weapons)

**Archivos nuevos:** `scripts/rendering/boss_figure.gd` (~670 líneas), `scripts/rendering/enemy_figure.gd` (~220 líneas).

**BossFigure** extends StickFigure. Mantiene API (set_state/telegraph/block_burst). Override `_draw()` con silueta llena:
- 4 `figure_style`: KNIGHT / BEAST / SIRENA / GOLEM
- 5 `head_style`: HELMET / HORNS / HALO / HOOD / TIARA
- `has_cape` + cape_color animated
- Glow ovalado pulsante atrás del torso (boss presence)
- **7 armas signature procedurales:** ROOTED_MAUL (Guardian) / DEMENT_HAMMER (Ignis) / ICE_SCEPTER (Lyss) / LIGHT_LANCE (Vael) / DUAL_RAPIERS (Duelista) / CRESCENT_BOW (Cazadora) / VORTEX_STAFF (Heraldo)

**EnemyFigure** llama `super._draw()` + dibuja accesorios overlay por `class_style`:
- MELEE: casco + chestplate + cinturón
- TANK: yelmo grande con visor T + 2 hombreras + cresta + cinturón ancho
- ARCHER: capucha + cara en sombra con ojo brillante + carcaj con 3 flechas
- MAGE: sombrero cónico inclinado + ala dorada + amuleto cyan colgando

**7 boss .tscn updated** con script BossFigure + figure_style + head_style + colors + signature_weapon. **4 enemy .tscn updated** con script EnemyFigure + class_style + accent + leather colors.

### 2.3 Combat refactor (hitbox swing honesto + bug fixes)

**Hitbox swing animado** (`scripts/components/hitbox_component.gd` +160 líneas):
- `WEAPON_HITBOX_DEFAULTS` por visual_type (SWORD reach 50 / HAMMER reach 36 con damage_zone 0.35 = solo cabeza)
- `setup_weapon_swing(visual_type, reach, width, arc_deg, damage_zone, scale_mult)` — lazy crea `ConvexPolygonShape2D`
- `update_swing_arc(progress, facing)` — recalcula polígono trapezoidal rotado cada frame
- `clear_swing_shape()` — revierte al legacy rectangular

**ItemData fields nuevos** (`scripts/data/item_data.gd:67-77`):
- `weapon_reach: float` — alcance desde mano
- `weapon_width: float` — grosor filo/cabeza
- `weapon_arc_deg: float` — barrido swing en grados
- `weapon_damage_zone: float` — 0-1 fracción que daña (1.0 = filo entero)

**Player + Enemy** hook llamado en `_start_attack/_change_state(State.ATTACK)`:
- `scale_mult = sprite.scale.x * sprite.weapon_scale` (boss 3.65× boost vs player 1.0)
- Cada frame en ventana ATTACK_ACTIVE: `update_swing_arc(progress, facing)`

**Hurtboxes por silueta**:
- Player: 22×56 → **18×54**
- Enemy base: 22×56 → **18×54**
- Tank: **26×60** (robusto)
- Archer: **15×52** (delgado)

**Bug fixes:**
- ✅ Lyss MURALLA_WINDUP_SECONDS / ACTIVE_SECONDS / COOLDOWN_MIN/MAX / REFLECT_RADIUS — 5 constantes faltantes que crasheaban F2 zona 3
- ✅ Tank taunt range 400px (`detect_range * 0.8`) → **180px** (`R2_TANK_TAUNT_PLAYER_RANGE` ~3 enemies)
- ✅ R3 Lluvia Flechas/Meteoros con proyectiles cayendo visibles (eran solo telegraph circle antes)
- ✅ Nova Hielo + Erupción Terrestre + Salto Asalto con `_spawn_aoe_impact_burst` (eran invisibles antes)
- ✅ Ignis override `_implicit_weapon_visual_type → HAMMER` (era MELEE class pero blande martillo)

### 2.4 VFX

**Status effect VFX** (`scripts/components/status_effect_component.gd` +150 líneas):
- `_spawn_status_vfx(id)` lifecycle: attached al parent en `apply`, free en `remove/expire/clear`
- Por id: burn (llamas), freeze (cristales), fractura (crack + glow), desequilibrio (swirl), bendicion (halo dorado), miasma (aura verde)

**Player skill VFX** (`scripts/systems/player_skill_system.gd` +280 líneas):
- Curación (chispas + cruz roja), Embestida (trail naranja), Bola Fuego (muzzle flash), Onda Sísmica (anillos shockwave), Escudo Mágico (hex rotando follow), Sombra (humo púrpura)

**Grito visual Tank taunt** — texto "¡EHH!" con pop-in scale + onda expansiva 32-segmentos naranja.

### 2.5 Contenido (items + recetas + drops + mini-boss + bg)

**14 items elementales** (`resources/items/weapons/*.tres`):
- Espadas: montana / sable_brisa / alborada
- Arcos: pedernal / solar / eclipse
- Varas: raices / tempestad / abismo
- Mazos: fragua / glacial / tormenta / radiante / lugubre

**14 recetas crafteo** generadas con python batch (`resources/recipes/craft_*.tres`). Materials canon por elemento + Piedra Resonancia + gold cost coherente.

**Drop tables Z2/Z3/Z4 wireados:**
- `zona2_boss_items.tres` += martillo_fragua FUEGO
- `zona3_boss_items.tres` rebuilt AGUA puro (vara_cristal + arco_glacial + cota_glacial + escudo_glacial + espada_lamento + maza_glacial)
- `zona4_boss_items.tres` **nuevo** dedicado VIENTO/LUZ (12 items)
- `zona4_etapa_boss.tres` ref drop table corregida (antes apuntaba a Z2 boss items)

**Mini-boss Capitán de los Vientos** (`scenes/entities/mini_boss_capitan_vientos.tscn` nuevo):
- BossFigure custom: capa dorada militar + casco horns + arco signature (CRESCENT_BOW)
- enemy_class=2 ARCHER, rarity=R3, element=VIENTO
- weapon_scale 1.35, body_scale_mult 1.1
- Z4E3 stage: `boss_scene_override = mini_boss_capitan_vientos.tscn`, `is_mini_boss = true`
- **world.gd routing extendido** para que `is_mini_boss + boss_scene_override` use scene custom sin requerir R4

**Zone chaining** (`scripts/world/world.gd:_on_run_completed`): zona 1→2→3→4 automático. Zona 4 final → MainMenu reset. `main_menu.gd._on_historia_pressed` fuerza `StageManager.set_zone(1)` al arrancar nueva run.

**Backgrounds zona 1 reemplazados:**
- 4 PNGs Gemini con alpha real tras flood fill script (checker fake transparency removida)
- Watermark Gemini cropped esquina inferior izquierda
- `world.gd` scales aspect-preserving uniformes (0.6 / 0.50 / 0.35) + position Y tuneado + motion_mirroring corregido per layer
- Shader `white_to_alpha` removido (no necesario con alpha real)

### 2.6 Lore zonas 2-4 (9 archivos nuevos)

**Estructura uniforme** matching zona 1 style (imperio caído + fragmentos preservados):
- `fragua_cenicienta.md` + `bestiario_zona_2.md` + `materiales_zona_2.md`
- `acueducto_lamento.md` + `bestiario_zona_3.md` + `materiales_zona_3.md`
- `cumbres_tempestad.md` + `bestiario_zona_4.md` + `materiales_zona_4.md`

**Progresión conciencia narrativa:** Valle (sin recordar) → Fragua (insistencia sin sentido) → Acueducto (espera + Lyss alma propia) → Cumbres (conciencia plena, Vael sabe lo que es).

**3 Núcleos cosmológicamente conectados** (Ígneo/Abisal/Fulgurante) — pista narrativa post-MVP.

### 2.7 Docs canon updated

- **GDD v2.1 → v2.2** sync §5.3 (6 elementos canon + dual triangle natural/cósmico + status synergy 30%). MVP §11 actualizado. Changelog agregado.
- **glossary.md** +BossFigure +EnemyFigure +Weapon Swing Hitbox +Status Effect VFX entries.
- **formulas.md** +tabla scale por entidad + fórmulas weapon swing arc + post-scale dimensions.
- **canon_estilo_visual.md** nuevo (`docs/features/visual/`) — master style + 12 prompts ready-to-paste Gemini para zonas 2/3/4.
- **hud_combat_redesign.md** nuevo (`docs/features/ui/`) — spec con 5 decisiones cerradas + implementation plan 4 fases.
- **phase_2_retrospective.md** nuevo — cierre Fase 2 documentado.

---

## 3. Decisiones Leo cerradas esta sesión

1. ✅ **6 elementos canon GDD §5.3** sync (RAYO descartado, LUZ ocupa slot 5)
2. ✅ **HUD redesign** matching imagen referencia (Furia / 6 botones / portraits híbrido / stage+momentum / "25"=nivel)
3. ✅ **C híbrido portraits** (PNG si existe, procedural fallback)
4. ✅ **Hitbox honesta** por arma (decisión: arma + animado + todas entidades + hurtboxes ajustados)
5. ✅ **Backgrounds zona 1** mantener (BG cielo 1920×1080, MID/FORE más chicos con aspect coherente)
6. ✅ **Sigue lore en `docs/lore/`** estilo zona 1 expandido a zonas 2-4

---

## 4. Estado actual

### 4.1 Repo state

- ✅ Commit `da2b347` aplicado en `main` local
- ✅ Pusheado a `origin/main` por Leo
- ✅ Working tree limpio
- ✅ Integrity check: 188 .tres + 103 .gd + 129 ids — **0 broken refs**

### 4.2 Tareas completadas (24/24)

```
1-6. Hitbox swing arc + scale + hurtboxes (todas entidades)
7. StageManager._is_pending reset (ya estaba fixed)
8. VFX status effects (6 statuses)
9. HUD chips skills + cooldown ring
10. Validar 14 items schema
11. Drop tables Z2/Z3/Z4 wireados
12. Phase 2 retrospective + glossary + formulas
13-15. Lore Z2/Z3/Z4 (9 files)
16. Canon visual master + 12 prompts Gemini
17. HUD redesign spec
18. HUD Fase 1 implementation
19. Headless syntax + integrity validation
20. HUD Fase 2 (EnemyInfo)
21. HUD Fase 3 (skill chips reorganización)
22. Mini-boss Capitán scene + routing
23. 14 recetas crafteo
24. HURT state cleanup (documentado, no implementado)
```

### 4.3 Pendientes próxima sesión (bloqueados por playtest o assets externos)

**Bloqueado por playtest in-game:**
- Validar feel HUD redesign en runtime
- Validar bosses visuales en arena
- Validar hitbox swing arc cumple Pilar #2 honesto
- Validar zone chaining 1→2→3→4 end-to-end
- Validar drops Z2/Z3/Z4 items dedicados rolean
- Validar mini-boss Capitán visualmente distinguible de archer normal
- Smoke tests handoff 27/05 (6 suites headless + smoke tests in-game)

**Bloqueado por assets externos:**
- 12 prompts Gemini canon Z2/3/4 ready-to-paste → Leo genera PNGs
- 11 portrait PNGs (player + 7 bosses + Capitán) → Leo genera Gemini
- Audio pipeline (1 track zona × 4 + 1 combate + SFX por skill/status)
- PNG weapons per arma (pipeline explicado, no implementado — esperando PNGs IA)

**No bloqueado** (cuando quieras):
- Tests integration cosmic statuses (scene tree mocks SetBonusSystem + FuriaComponent)
- UI loadout skills player (drag-and-drop asignar skill → slot)
- Tree unlock skills player (drop / unlock / fijas por clase — decisión Leo)
- Tank skill variants Z2/Z4 (canon Taunt actual)
- Lyss healing en proyectil reflejado (edge case)
- Sistema bestiario interactivo (GDD §9.2)
- Tutorial integrado (criterio cierre Fase 3)

---

## 5. Contexto necesario para próxima sesión

### 5.1 Arquitectura nuevos componentes

**BossFigure / EnemyFigure** — subclases de StickFigure. Mantienen API completa (set_state/telegraph/block_burst). Render via `_draw()` override:
- BossFigure: silueta llena + signature weapons procedurales + glow ovalado
- EnemyFigure: llama `super._draw()` (skeleton + armas) + dibuja accesorios overlay por class_style

**Cuando lleguen PNGs IA bosses/mobs:** swap = cambiar node `StickFigure` type a `Sprite2D` con texture. Los métodos de animation (state_changed, etc) se reemplazan por `AnimationPlayer` apuntando al sprite. Refactor menor, no requiere cambiar enemy.gd/player.gd.

**PortraitFactory** autoload — carga PNG por id desde `assets/art/portraits/<id>.png`. Si no existe, returns null y caller dibuja procedural. **Para activar IA portrait:** drop file con nombre canon (ej. `player_knight.png`, `boss_lyss.png`) → next load lo detecta auto.

**Hitbox swing arc** — `setup_weapon_swing` lazy crea CollisionShape2D dedicado con ConvexPolygonShape2D. `update_swing_arc(progress, facing)` cada frame durante ATTACK_ACTIVE. Bosses con `weapon_scale` 1.8 + `sprite.scale` 2.0 dan reach efectivo ~131px (Guardian hammer). Si feel sobredimensionado, tunear constants en `WEAPON_HITBOX_DEFAULTS`.

### 5.2 Convenciones canon vigentes

- **6 elementos** canon GDD v2.2 §5.3 — FUEGO/AGUA/TIERRA/VIENTO/LUZ/SOMBRA. Dual triangle natural (FUEGO>TIERRA>AGUA, VIENTO neutral) + cósmico (VIENTO>LUZ>SOMBRA). Cross ×1.0
- **Status synergy on-hit 30%** base — FUEGO=Burn / AGUA=Freeze / TIERRA=Fractura / VIENTO=Desequilibrio / LUZ=Bendición (vampire heal source) / SOMBRA=Miasma (bypass armor)
- **Weapon hitbox defaults:** SWORD reach 50 / damage_zone 1.0 (filo entero), HAMMER reach 36 / damage_zone 0.35 (solo cabeza), NONE reach 24 / damage_zone 1.0
- **scale_mult** = `sprite.scale.x * sprite.weapon_scale` (boss Guardian 3.65× / Ignis 3.00× / Duelista 2.44×)
- **Filenames legacy** mantienen `vulnerable.tres → id "fractura"` y `poison.tres → id "miasma"` — no romper
- **Zone chaining:** MODO HISTORIA fuerza `set_zone(1)` al arrancar. `_on_run_completed` avanza zona o vuelve menú
- **Mini-boss detection:** `data.is_mini_boss && data.boss_scene_override != null` → usa scene custom para cualquier rareza (no solo R4)

### 5.3 Lecciones canon nuevas esta sesión

- **Edit pierde tabs intermitentemente** → seguir patrón handoff 25/05 (vigente)
- **Gemini Imagen** fake alpha (checker) + watermark esquina inferior izq → workflow flood fill + crop documentado en `canon_estilo_visual.md` §4-6
- **PNG sizes per layer canon:** BG 1920×1080 keep / MID 1280×720 (16:9) / FORE tira 1280×360 (32:9) / viewport 1152×648
- **HUD CanvasLayer + touch_controls scene separados** — chips visualization en hud_combat = info, botones reales en touch_controls = input
- **Test in-editor antes de in-game** cuando el cambio es UI puro — Leo confirma layout antes de seguir fases

---

## 6. Archivos modificados / creados esta sesión

Total: 82 archivos (32 modified + 50 created).

| Categoría | Archivos |
|---|---|
| Code scripts modified | `hitbox_component.gd` / `status_effect_component.gd` / `item_data.gd` / `enemy.gd` / `player.gd` / `boss_lyss.gd` / `boss_ignis.gd` / `player_skill_system.gd` / `hud_combat.gd` / `main_menu.gd` / `world.gd` |
| Code scripts new | `boss_figure.gd` / `enemy_figure.gd` / `portrait_factory.gd` |
| Scenes modified | 7 boss .tscn + 4 enemy .tscn + player.tscn + enemy.tscn + world.tscn |
| Scenes new | `mini_boss_capitan_vientos.tscn` |
| Resources items new | 14 weapon .tres |
| Resources recipes new | 14 recipe .tres |
| Resources drops modified | Z2/Z3 boss items + Z4 etapa 3+boss |
| Resources drops new | `zona4_boss_items.tres` |
| Assets new | 4 PNG backgrounds (Gemini) |
| Docs canon modified | GDD v2.2 / glossary / formulas |
| Docs lore new | 9 archivos Z2/Z3/Z4 |
| Docs features new | `phase_2_retrospective.md` / `hud_combat_redesign.md` / `canon_estilo_visual.md` |
| Config | `project.godot` autoload PortraitFactory |

---

## 7. Estado Fase 3 final

✅ Skills enemy R2/R3 variants per zona (canon 27/05)
✅ Set bonuses 6 elementos
✅ StatusEffect system genérico
✅ PlayerSkillSystem
✅ SetBonusSystem
✅ Momentum / Furia / Refinamiento / Crafteo / Drops integrados
✅ 4 bosses únicos + 7 bosses totales con patrones reales
✅ 14 items elementales nuevos (cobertura 6 elementos × 4 weapon types)
✅ Lore canon zonas 1-4
✅ GDD v2.2 sync 6 elementos
✅ HUD redesign Fase 1-3
✅ Bosses + mobs visualmente refactorizados procedural
✅ Hitbox honesto Pilar #2
✅ Mini-boss Capitán scene
✅ Zone chaining 1→4
✅ Backgrounds zona 1 con alpha real
✅ Phase 2 retrospective + Phase 3 lógica cerrada

❌ Arte IA portraits + bosses + mobs + parallax Z2/3/4 (12 prompts ready)
❌ Audio pipeline + tracks per zona + SFX
❌ Playtest validatorio end-to-end zona 1
❌ Tests headless smoke (handoff 27/05)
❌ Sistema bestiario interactivo
❌ Tutorial integrado

**Criterio cierre Fase 3 (GDD §13):** *"Una zona completa es jugable de principio a fin"* — falta solo arte + audio + playtest. Lógica 99% cerrada.

---

## 8. Próxima sesión sugerida

**Si Leo arranca con PNGs Gemini generados:**
1. Drop PNGs en `assets/art/portraits/` + `assets/art/zona{2,3,4}/backgrounds/`
2. Verificar alpha real (sips + python script si Gemini falló)
3. Wire `world.gd` para Z2/3/4 backgrounds (mismo pattern Z1)
4. Test in-editor + ajustar offsets/scales

**Si Leo prioriza playtest:**
1. Abrir Godot, validar el commit corre sin errores
2. MODO HISTORIA → zona 1 stage 1→5+boss
3. Verificar zone chaining → zona 2 → 3 → 4 → vuelve menú
4. Confirmar HUD redesign feel mobile
5. Smoke test mini-boss Capitán Z4E3

**Si Leo quiere seguir lógica:**
1. UI loadout skills player (drag-and-drop)
2. Tree unlock skills decisión + implementación
3. Tests integration cosmic statuses
4. Tank skill variants Z2/Z4

---

**Fin handoff sesión 28/05 17:24.**

> 🔗 Handoff anterior: [`2026-05-27-1830-bug-assets-bg.md`](2026-05-27-1830-bug-assets-bg.md) — cierre lógica anterior + bug assets BG identificado (resuelto esta sesión).
