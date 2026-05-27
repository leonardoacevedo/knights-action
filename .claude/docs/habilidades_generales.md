# Habilidades Generales — Catálogo y Viabilidad Técnica

> **Propósito:** catálogo único de skills (enemies + player), con estado de implementación, viabilidad técnica y dependencias de infraestructura. Doc vivo — agregar skills nuevas acá antes de implementarlas.

> **Source of truth:** este archivo es el índice. Cada skill implementada se documenta en código (`enemy.gd`, `player.gd`) y se referencia acá con su estado. Si una skill no aparece acá, no es canon.

---

## 1. Filosofía (NO negociable)

Toda skill — enemy o player — cumple los siguientes principios:

1. **Animation Lock / Regla de Compromiso.** Una vez iniciado el windup, NO se cancela si el target se mueve fuera de rango. El usuario "se compromete" — el cooldown se consume y el efecto se ejecuta (aunque pegue al aire). Evita baiting infinito.
   - **Implementación canon:** `velocity.x = 0.0` durante `TELEGRAPH` / `SKILL_TELEGRAPH` / `R2_SKILL_TELEGRAPH` en `enemy.gd`. ✅ Ya vigente.

2. **Telegrafía visible obligatoria.** Mínimo 0.5s antes del impacto, máximo dependiendo del daño (one-shots requieren ≥0.7s; skills R4 boss ≥1.0s). El jugador SIEMPRE puede leer el intent.
   - GDD §7.3. Pilar #2: "cada muerte enseña algo".

3. **Cada skill refuerza el rol del arquetipo.** Melee = presión / rompe-guardia. Tank = control / desgaste. Archer = kiteo / castigo a distancia. Mage = denegación de área / burst.

4. **Cooldown > 0.** Skills sin CD son spammeables — rompen el ritmo de combate. Mínimo 3s.

5. **Performance mobile.** No más de 6 partículas simultáneas por skill activa. Reusá process_material. Sin instancias por frame.

---

## 2. Estado de Implementación Actual

### Regla de progresión (NO negociable, vigente)

- **R1 = 1 skill total** (su ataque básico cuenta como skill 1).
- **R2 = 2 skills total** (hereda ataque básico R1 + suma skill R2 con CD).
- **R3 = 3 skills total** (hereda ataque básico R1 + skill R2 + suma skill R3 con CD).
- **R4 = boss** (5+ patrones propios, no sigue esta tabla — ver `boss_guardian.gd`).
- **Mejoras del ataque básico R1 se heredan a R2/R3.** Si el R1 mage tiene "Orbe Flamígero" (AoE on impact), entonces R2/R3 mage que disparan ataque básico también dispara Orbe Flamígero. Las skills R2 (path separado) NO reciben las mejoras del ataque básico (evita stacking de overkill).

### Tabla de skills implementadas

| Clase | R1 (ataque básico = 1 skill) | R2 (hereda R1 + suma 1) | R3 (hereda R1+R2 + suma 1) | R4 (boss) |
|---|---|---|---|---|
| Melee | ✅ Corte espada arco frontal | ✅ + Embestida-dash + knockback | ✅ + **Sed de Sangre** (buff +20% vel/atk 5s, CD 12s). Skill genérica R3 (hitbox ampliada) eliminada — era redundante con ataque básico. | ✅ Guardián (5 patrones) + **Ignis** zona 2 (Hammer Overhead, Salto Sísmico + lava PersistentHazard, Lluvia Meteoros, Sed de Sangre F2, Corte Giratorio F2) |
| Tank | ✅ Hammer overhead | ✅ + **Taunt MMO clásico** — redirige **100%** del daño que el player hace a aliados (radio 45px) hacia el tank por 3s. **Además fuerza al player:** facing hacia el tank + pull horizontal a SPEED completa hasta pegarse (35px). Player conserva salto/ataque/bloqueo/dash, solo el movimiento lateral está override. Marker "!" pulsante + flash rojo de pantalla + aura naranja + tinte sprite + líneas a aliados + damage floater grande sobre tank. CD 12s. **Decisión Leo:** aunque se sienta "roto", el taunt DEBE ser así para cumplir su rol. | ✅ + **Muralla Estática** (27/05) — aplica status `muralla_estatica` 1.2s. Invuln direccional frontal: ataques desde el frente del tank (mismo signo que `current_facing`) son bloqueados con damage floater "BLOCK!". Ataques por la espalda entran normales. Sin hitbox propio — skill defensivo puro. Aura azul GPUParticles + DEF up. | — |
| Archer | ✅ Flecha Perforante (single arrow, pierce ×3) | ✅ + Ráfaga 3 flechas spread ±15° (CD 8s) | ✅ + **Lluvia de Flechas** (27/05) — 3 `AoeTelegraph` amarillos staggered (spread 70px) bajo player. Tras 0.55s, damage radial 42px en cada posición. Reemplaza "proyectil potenciado" genérico. | — |
| Mage | ✅ Orbe Flamígero (fireball + AoE radial 35px / 60% daño on impact) | ✅ + Canalizar 1.2s → fireball ×1.8 size + ×1.5 daño (CD 10s) | ✅ + **Lluvia de Meteoros** (27/05) — 3 `AoeTelegraph` rojos staggered (spread 80px). Tras 0.55s, AoE damage 42px + aplica BURN 3s/4dmg/tick. | ✅ Heraldo + **Lyss** zona 3 (Látigo Helado, Nova de Hielo + FREEZE, Triple Tiro, Vórtice Gravedad F2, Canto Helado F2) |

**Capstones del árbol player** (efectos pasivos/buffs temporales activos hoy):
- `agil_golpe_tras_dash` — +10% daño 0.5s post-dash (POST_DASH_DAMAGE_PCT)
- `agil_sombra_del_valle` — invis 0.5s post-dash + ventaja elemental garantizada
- `guerrero_espiritu_marcial` — +20% daño 2s tras bloquear
- `mago_resonancia_arcana` — +1 Furia/s pasiva
- `mago_ventaja_aguzada` — +15% al multiplicador de ventaja elemental
- Stats cableados: BLOCK_CHARGES, IFRAMES_PCT, MOVE_SPEED_PCT, DASH_COOLDOWN_PCT, EVADE_PCT, etc.

**Skills activas del player (Furia → efecto):** ✅ Sistema IMPL (27/05). Lógica completa + 6 skills .tres iniciales + autoload `PlayerSkillSystem` + input map (skill_1/2/3 → teclas 1/2/3). Pendiente: UI de equipado + tree de unlock. Ver §5.

---

## 3. Infraestructura — Qué tenemos vs qué falta

### ✅ Disponible hoy
| Capability | Dónde vive |
|---|---|
| State machine enemy con telegraph/attack/recovery | `enemy.gd` |
| Cooldowns múltiples independientes | `_skill_cooldown`, `_skill_r2_cooldown` |
| Proyectiles (arrow, fireball) con `Projectile.launch()` | `scenes/projectiles/` |
| Partículas configurables (`GPUParticles2D` por código) | patrón `_spawn_*_aura` |
| Slash trails (`Line2D` + tween fade) | R2 melee embestida |
| Damage soak / redirect | `HurtboxComponent.taunt_soaker` |
| AoE radial (boss multi-target) | `boss_guardian.gd._aoe_*` |
| Bloqueo de cargas | `EnemyBlockHandler` |
| Cargas temporales del escudo | `ShieldComponent.add_temporary_charges(N, dur)` |
| Dash con i-frames | `DashComponent` |
| Knockback al player | `player.apply_external_velocity(push)` |
| Status effects genérico (slow/burn/stun/poison/freeze/vulnerable/muralla_estatica) | `StatusEffectComponent` + `resources/status_effects/*.tres` |
| Invuln direccional | `HurtboxComponent._is_blocked_by_directional_invuln` (status `muralla_estatica`) |
| Daño extra al "vulnerable" defensor | `HurtboxComponent.receive_hit` multiplica si target tiene status |
| Element → Status synergy (FUEGO=BURN, AGUA=FREEZE, TIERRA=VULNERABLE, 30% chance) | `HitboxComponent._try_apply_element_status` + `Projectile._try_apply_element_status` |
| Element propagado | `hitbox.element`, `hurtbox.element` |
| Set Bonuses afinidad | `SetBonusSystem` |
| Furia (player) ya acumula + decae + se gasta | `FuriaComponent` + `PlayerSkillSystem.try_use(slot)` |
| Persistencia skill loadout | `SaveSystem` + `PlayerSkillSystem._serialize_state` |

### 🟡 Infra parcial — usable con extensión chica
| Capability | Qué falta |
|---|---|
| Telegrafía AoE en suelo (círculo, cono, línea) | ✅ `AoeTelegraph` IMPL: `scenes/effects/aoe_telegraph.tscn` + `scripts/effects/aoe_telegraph.gd`. API `setup(radius, duration, color)`. Listo para Salto de Asalto, Nova de Hielo, Erupción Terrestre, etc. |
| Spawn de zona persistente (trampa, muro fuego, nube veneno) | Crear `PersistentHazard` Area2D con damage por tick + lifetime |
| Status effect "Slow" en player | Reusar `move_speed_mult` con timer; pero hoy `move_speed_mult` es propiedad permanente del player (set por PlayerStatsComponent). Necesita override temporal: agregar `_external_speed_mult: float` + `_external_speed_timer: float` en `player.gd` (~10 líneas). |
| Status effect "Stagger" / "Stun" (interrumpe player) | Agregar `State.STUNNED` en player.gd con timer + skip de inputs |
| DOT (Damage Over Time) | Timer en `HurtboxComponent` que aplica daño cada N segundos. Necesita schema (duration, tick_interval, damage_per_tick, source). |
| Buff propio del enemy (+vel ataque, +daño temporal) | Pattern de `_espiritu_marcial_active` aplicado al enemy. Trivial. |
| Invulnerabilidad direccional (frontal/back) | Check de `attack.global_position.x` vs `enemy.global_position.x` en `HurtboxComponent.receive_hit`. Trivial pero edge cases (player atrás vs lateral). |

### 🔴 Infra grande — sistema nuevo
| Capability | Qué requiere |
|---|---|
| **Status Effect System genérico** | ✅ IMPL 27/05. `StatusEffectData` (Resource) + `StatusEffectComponent` (Node hijo de Player/Enemy). Stack modes REFRESH/EXTEND/INDEPENDENT/IGNORE + magnitude policies KEEP_MAX/MIN/LATEST/SUM + tick interval para DOTs. **10 .tres**: slow, espiritu_marcial, post_dash_damage, post_dash_invis, burn, stun, poison, freeze, vulnerable, muralla_estatica. Player.gd y Enemy.gd consumen vía signals + queries `has(id)/get_magnitude(id)`. Migrados: Espíritu Marcial, slow externo (Mareo Frío), post-dash damage, post-dash invis. Tests puros: `tests/systems/status_effect_component_test.gd`. |
| **EnemySkill como Resource .tres** | ✅ IMPL parcial 27/05. `EnemySkillData` (Resource) + 4 .tres en `resources/enemy_skills/r2_{melee,tank,archer,mage}.tres`. Migrados: telegraph_sec, cd_min, cd_max, attack_duration, damage_mult, params dict (dash_distance, taunt_radius, projectile_count, etc.). `R2_SKILL_TABLE` const sigue como fallback defensivo. Pendiente: migrar consts hardcoded R2_MELEE_DASH_DISTANCE etc. a `_r2_param("dash_distance", default)`. |
| **Projectile homing / seek** | Modificar `Projectile.gd` con flag `homing_target: Node2D` + `homing_strength: float`. Update direction cada frame hacia target. Trivial pero requiere tunear feel. |
| **Reflexión de proyectiles** | `Projectile` debe poder cambiar `team` al impactar superficie reflectante (Area2D del Tank R3 set A "Muralla Estática"). Necesita signal + check de owner. Edge case: ¿quién hace daño? El reflejado o el reflejante? |

### ⛔ Inviable / mal-fit para nuestro juego
| Skill propuesta | Por qué no |
|---|---|
| ~~**Forced "look at enemy"**~~ | **DESCARTADO 27/05.** Leo aceptó override de input para el Taunt MMO del Tank R2: el player es forzado a mirar + acercarse al tank durante 3s. Se sintió necesario para que el taunt sea TAUNT real. Aplicable a otros skills futuros si Leo lo aprueba caso por caso. Ver §2 Tank R2. |
| **Inmovilización total del player ("Flecha Aturdidora", "Trampa de Cazador" 100% lock)** | Bloquea inputs frustrante en mobile. Mejor: reducir a 0.3s máx (límite del Espíritu Marcial) o usar Slow 50% en vez de Stun completo. |
| **Vórtice de gravedad que arrastra player (Tank C R3)** | Físicamente posible pero rompe el feel del joystick (player nota que "no responde"). Conflicto con Pilar #1 ("mi skill importa"). Si se hace, requiere flag visual claro + duración corta. |

---

## 4. Pool Propuesto — Catálogo Futuro

Estado: **PROP** = propuesta sin implementar · **PARC** = parcialmente viable · **OK** = factible con infra actual o extensión chica · **REQ-INFRA** = requiere sistema nuevo (ver §3 🔴) · **NO** = inviable / mal-fit

### 4.1 Set A (Canónico — del doc original Leo)

| Clase | Rareza | Nombre | Estado | Notas técnicas |
|---|---|---|---|---|
| Guerrero | R1 | Corte Cruzado | OK | Equivale al ataque básico actual. |
| Guerrero | R2 | Salto de Asalto (gap closer + AoE caída) | IMPL (27/05) | `r2_melee_salto_asalto.tres` + `_enter_r2_salto_asalto / _tick_r2_salto_asalto`. AoeTelegraph + jump arc + landing damage radial 75px + knockback. |
| Guerrero | R3 | Rugido de Guerra + Stagger | REQ-INFRA | Stagger = State.STUNNED en player (no implementado). Si no se puede hacer Stagger, reducir a Slow 50% por 1s. |
| Tank | R1 | Provocación / forced-look | NO | Ver §3 ⛔. Reinterpretar como aura visual + flag de prioridad UI. |
| Tank | R2 | Escudo Cargado (embestida + rompe 1 carga escudo player) | PARC | Embestida ya tenemos (similar al melee R2). "Romper carga del escudo player" = nuevo hook en `player.shield.consume_charge_force(1)`. ~5 líneas. |
| Tank | R3 | Muralla Estática (invuln frontal + refleja) | REQ-INFRA | Invuln direccional viable (~10 líneas). Refleja proyectiles requiere infra nueva. Reducir a "ignora proyectiles" si no se quiere reflexión. |
| Archer | R1 | Flecha Perforante (ignora colisión con otros enemies) | IMPL | Flag `pierce_enemies + pierce_count` en `Projectile`. Activo para Archer R1 base. Trail Line2D. |
| Archer | R2 | Lluvia de Flechas (3 AoE telegrafiados que caen tras 0.5s) | REQ-INFRA | Necesita AoeTelegraph + sistema de "drop after delay" (Timer + spawn). ~30 líneas. |
| Archer | R3 | Flecha Aturdidora (stun 1s) | NO | Ver §3 ⛔. Reducir a Slow 70% por 0.7s. |
| Mage | R1 | Orbe Flamígero (AoE explosivo post-impacto) | IMPL | `aoe_on_impact` flag en `Projectile`. AoeTelegraph 0.4s + daño radial 35px/60%. Solo Mage R1 base. |
| Mage | R2 | Nova de Hielo (zona fija bajo player que explota tras windup) | IMPL (27/05) | `r2_mage_nova_hielo.tres` + `_enter_r2_nova_hielo / _tick_r2_nova_hielo`. AoeTelegraph 70px + AoE damage + aplica FREEZE. |
| Mage | R3 | Lluvia de Meteoros (3 homing) | REQ-INFRA | Projectile homing. Si no, reducir a 3 proyectiles secuenciales straight con timing. |

### 4.2 Set B (Alternativo)

| Clase | Rareza | Nombre | Estado | Notas |
|---|---|---|---|---|
| Guerrero | R1 | Tajo Doble | IMPL (27/05) | `r2_melee_tajo_doble.tres` + `_enter_r2_tajo_doble / _tick_r2_tajo_doble`. 2 hits secuenciales 0.1s gap. Cada hit 0.9× dmg. |
| Guerrero | R2 | Corte Giratorio (AoE 1.5s rotación) | IMPL (27/05) | `r2_melee_giratorio.tres` + `_enter_r2_giratorio / _tick_r2_giratorio`. Hitbox activo todo el spin + avance lento + multi-hit tick. |
| Guerrero | R3 | Sed de Sangre (buff propio +vel/atk 5s) | IMPL | `_skill_r3_buff_cooldown` (12s) + `_r3_buff_timer`. Prioridad máxima en CHASE. VFX aura roja + tinte sprite. |
| Tank | R1 | Golpe Terremoto (AoE + Slow 50% / 2s) | REQ-INFRA | Slow requiere `_external_speed_mult` en player. |
| Tank | R2 | Gancho (proyectil que arrastra) | PARC | Tween de player hacia tank si proyectil acierta. ~30 líneas. Player nota "no responde" durante el pull — comunicar con flag visual. |
| Tank | R3 | Guardia Espinada (refleja melee + Stagger) | REQ-INFRA | Reflejar daño = redirigir back al atacante. Stagger ver §3. |
| Archer | R1 | Disparo en Abanico (3 flechas cono frontal) | OK | Idéntico al R2 actual pero como ataque básico R1. |
| Archer | R2 | Trampa de Cazador (estática que inmoviliza) | REQ-INFRA + NO inmovilización. | PersistentHazard scene + Slow 70% al pisar. |
| Archer | R3 | Flecha Explosiva (adherente + explota 1.5s) | OK | Projectile con onHit → Timer → AoE radial. ~25 líneas. |
| Mage | R1 | Látigo Lumínico (línea instantánea tras windup largo) | OK | Hitbox rectangular activa 0.1s tras telegraph. ~15 líneas. Element LUZ. |
| Mage | R2 | Muro de Llamas (línea fija 4s) | REQ-INFRA | PersistentHazard. ~30 líneas. |
| Mage | R3 | Lanza de Luz Penetrante (láser 2s que persigue lento) | REQ-INFRA | Line2D que se actualiza cada frame con interpolación lenta hacia player. ~40 líneas. Element LUZ. |

### 4.2.5 Asignación de variants por zona (canon 27/05, decisión Leo)

Las variants del pool §4 se asignan **por zona** (no por rareza ni random). Cada zona tiene set canónico para distinguir bestiario.

| Zona | Melee R2 | Tank R2 | Archer R2 | Mage R2 | Skill R3 (genérica) |
|---|---|---|---|---|---|
| **1 Valle de los Ecos** | Embestida-dash (canon) | Taunt MMO (canon) | Ráfaga 3 flechas (canon) | Canalizar fireball (canon) | Lluvia (Archer) / Meteoros (Mage) / Muralla (Tank) / Sed Sangre (Melee) |
| **2 Fragua Cenicienta** (FUEGO) | Corte Giratorio | Embestida + buff | Disparo Reactivo | Erupción Terrestre | Sed Sangre / Muralla / Lluvia Meteoros (FUEGO) |
| **3 Acueducto Lamento** (AGUA) | Tajo Doble | Gancho Ascendente | Lluvia Flechas | Nova de Hielo | Lluvia Meteoros (AGUA → FREEZE en lugar de BURN) |
| **4 Cumbres Tempestad** (VIENTO/LUZ) | Salto de Asalto | Patada Frontal | Disparo Reactivo | Ráfaga Arcana | Patrones especiales mini-boss + Vael |

**Wireado pendiente:** mapeo concreto `enemy_class + zona → skill .tres`. Opciones:
1. Diccionario `ZONA_SKILL_VARIANTS` en `world.gd` / `StageManager` (key: zona, value: dict class → skill_path).
2. Override per-spawn_entry (más data por stage — campo nuevo en `EnemySpawnEntry`).
3. Override en `world._spawn_stage`: detectar zona via `StageManager.current_zone` y swap `_r2_skill_data` post-spawn.

Recomendación: **opción 3** (override en spawn, sin modificar EnemySpawnEntry).

### 4.3 Set C (Táctico)

| Clase | Rareza | Nombre | Estado | Notas |
|---|---|---|---|---|
| Guerrero | R1 | Patada Frontal (rango corto + knockback) | IMPL (27/05) | `r2_melee_patada.tres` + `_enter_r2_patada / _tick_r2_patada`. Hitbox corto + knockback fuerte (120/-120). |
| Guerrero | R2 | Gancho Ascendente (rompe 2 cargas escudo) | IMPL (27/05) | `r2_tank_gancho_ascendente.tres` + `_apply_gancho_charges_break` → `ShieldComponent.consume_charge_force(2)`. |
| Guerrero | R3 | Arma Imbuida (buff propio, ataques ignoran escudo) | IMPL (27/05) | `r2_melee_arma_imbuida.tres` + `_enter_r2_arma_imbuida / _tick_arma_imbuida_buff`. 5s buff. `HitboxComponent.ignore_shield = true`. HurtboxComponent saltea shield.try_absorb si source.ignore_shield. |
| Tank | R1 | Golpe de Escudo (interrumpe ataque/dash player) | REQ-INFRA | "Interrumpir dash" = cancelar dash en curso → DashComponent.cancel(). "Interrumpir ataque" = cancelar swing → player.cancel_attack(). Ambos requieren hooks nuevos. ~20 líneas. |
| Tank | R2 | Salto Sísmico (AoE + zona persistente 2s) | REQ-INFRA | PersistentHazard + AoeTelegraph. |
| Tank | R3 | Vórtice de Gravedad (pull masivo) | NO / parcial | Ver §3 ⛔. Si se hace, área limitada + duración 1s máx. |
| Archer | R1 | Disparo Reactivo (rápido, bajo daño) | IMPL (27/05) | `r2_archer_disparo_reactivo.tres` + `_spawn_r2_disparo_reactivo_projectile`. Velocity ×2 + dmg ÷2 + scale 0.8. |
| Archer | R2 | Flecha Tóxica (nube DOT 3s) | REQ-INFRA | DOT + PersistentHazard. |
| Archer | R3 | Tiro Mortal / Snipe (laser sigue, dispara fijo) | REQ-INFRA | Similar a Mage R3 set B. |
| Mage | R1 | Ráfaga Arcana (3 proyectiles rápidos sucesivos) | IMPL (27/05) | `r2_mage_rafaga_arcana.tres` + `_tick_r2_rafaga_arcana`. 3 proyectiles delay 0.12s. Cada uno 0.7× dmg. |
| Mage | R2 | Erupción Terrestre (pilar desde suelo bajo player) | IMPL (27/05) | `r2_mage_erupcion_terrestre.tres` + `_tick_r2_erupcion_terrestre`. AoeTelegraph 50px + AoE damage + FRACTURA. No tracking — single drop fijo. |
| Mage | R3 | Tormenta Persecutoria (nube + rayos periódicos 4s) | REQ-INFRA | PersistentHazard que sigue al player + spawn de rayos cada N seg. |

---

## 5. Skills del Jugador — Sistema Activo

**Estado actual (27/05):** ✅ Sistema lógico IMPL. Furia (+10/golpe, decay 5/s, cap 100) ahora se gasta en skills activas. Pendiente solo UI + tree de unlock.

**Arquitectura:**
- `scripts/data/player_skill_data.gd` — Resource: `id, display_name, cost_furia, cooldown, effect_type, params, icon, color`.
- `scripts/systems/player_skill_system.gd` — Autoload con 3 slots equipados + ejecución validada (Furia + CD + slot ocupado).
- Input map en `project.godot`: `skill_1/2/3 → teclas 1/2/3`. Player.gd llama `PlayerSkillSystem.try_use(slot)`.
- Signals: `skill_used(slot, data) / cooldown_started(slot, cd) / slot_equipped(slot, data) / skill_failed(slot, reason)`.

**EffectTypes implementados:** HEAL, BUFF_DAMAGE, AOE_DAMAGE, AOE_BURN, DASH_FORWARD, SPAWN_PROJECTILE, GAIN_SHIELD, INVIS, APPLY_SLOW_AOE.

**Pool inicial (6 .tres creadas en `resources/player_skills/`):**

| ID | Nombre | Costo Furia | CD | Efecto |
|---|---|---|---|---|
| `embestida` | Embestida | 30 | 4s | Impulso horizontal hacia facing + buff dmg ×1.5 al próximo swing (0.4s). DASH_FORWARD. |
| `bola_fuego` | Bola de Fuego | 40 | 6s | Spawnea fireball con ×1.5 damage. SPAWN_PROJECTILE. |
| `onda_sismica` | Onda Sísmica | 50 | 8s | AoE radial 100px + aplica BURN 3s/4dmg-tick. AOE_BURN. |
| `curacion` | Curación | 60 | 15s | +30% HP máximo. HEAL. |
| `escudo_magico` | Escudo Mágico | 40 | 10s | +2 cargas escudo (placeholder hasta `add_temporary_charges`). GAIN_SHIELD. |
| `sombra` | Sombra | 70 | 25s | Invis 2s + ventaja elemental garantizada al próximo golpe (reutiliza `post_dash_invis`). INVIS. |

**Loadout default (player.gd._ready):** slot 0=Embestida, slot 1=Bola Fuego, slot 2=Onda Sísmica. Override desde UI futura.

**Tests:** `tests/systems/player_skill_system_test.gd` — 13 tests (equip/unequip, can_use, try_use, cooldown decay, force_execute, heal observable, buff_damage status, signal failed reasons, unregister cleanup).

**Pendiente (sesión UI futura):**
- UI de asignación skill→slot (drag-and-drop o picker — pueden vivir en `inventory_screen.tscn`).
- Tree de unlock — cómo se obtienen skills? Decisión Leo: drop / unlock por árbol / pre-fijas por clase.
- Persistencia equipped IDs en SaveSystem (PlayerSkillSystem expone slots, falta wire en `save_system.gd`).
- `ShieldComponent.add_temporary_charges(N, duration)` — hoy GAIN_SHIELD usa `restore_all` como fallback.
- VFX por skill (icono casteando, partículas, sonidos).

---

## 6. Cómo Agregar Skills Nuevas (Workflow)

1. **Editar este doc primero.** Sumar fila a la tabla correspondiente con estado PROP + notas.
2. **Si requiere infra nueva (🔴):** documentar en §3 antes de implementar. Confirmar con Leo si la infra es justificable.
3. **Implementación:**
   - Hoy (hardcoded): editar `R2_SKILL_TABLE` const en `enemy.gd` + agregar lógica en el state correspondiente.
   - Futuro (data-drive): crear `.tres` en `resources/enemy_skills/` + asignar al `EnemySpawnEntry`.
4. **Telegrafía y VFX obligatorios.** No mergear skill sin tell visible.
5. **Test:** mínimo cooldown + damage en test puro. VFX/physics → [INTEGRACION].
6. **Actualizar este doc** cambiando estado a OK/IMPL.

---

## 7. Riesgos y Decisiones Abiertas

| Riesgo | Mitigación |
|---|---|
| Demasiadas skills inflan `enemy.gd` (ya en ~1500 líneas) | Migrar a Resource `.tres` + `EnemySkillComponent` (REQ-INFRA 🔴). Decisión Leo: ¿cuándo? Sugerencia: cuando sumemos zona 2 (más clases). |
| Status effects ad-hoc dispersos | Crear StatusEffectComponent genérico (REQ-INFRA 🔴). Sugerencia: cuando sumemos la 3ra skill que necesita Slow/Stun. |
| Skills del jugador es sistema grande sin scope cerrado | Sesión separada. Decisiones pendientes Leo: drop/unlock/fijas, cómo asignar slots, balance Furia. |
| Performance mobile con muchas partículas simultáneas | Object pool de partículas si vemos stutter en device real. Hoy no se justifica (premature opt). |
| Reflexión de proyectiles confunde (¿quién pega a quién?) | Decisión Leo: si se implementa "Muralla Estática" (Tank R3 set A), confirmar el comportamiento esperado antes de codear. |

---

## 7.5 Element → Status synergy (rediseño 27/05 — Eje natural vs Eje cósmico)

> **Nota de diseño Leo:** Los elementos naturales (Fuego/Agua/Tierra/Viento) se enfocan en **control y daño elemental puro**. El Eje Cósmico (Luz/Sombra) se enfoca en **alteración de estadísticas, supervivencia y maldiciones** — temática santa vs maldad.

Cada hit con elemento no-NEUTRO tiene **30%** de chance de aplicar el efecto correspondiente:

### Eje natural — control + daño

| Elemento | Status | Efecto | Notas |
|---|---|---|---|
| FUEGO (1) | **Quemadura** | DOT 3s, 3 dmg/tick (0.5s) | Tick directo a HP (similar miasma pero NO bypass armor en player) |
| AGUA (2) | **Congelación** | -30% velocidad 2s (mult 0.7) | Reemplaza freeze pesado anterior (0.3×/0.8s) por slow más legible |
| TIERRA (3) | **Fractura** | Próximo golpe recibido +20% dmg, **single-use**, ventana 5s | Se consume en HurtboxComponent.receive_hit |
| VIENTO (4) | **Desequilibrio** | Interrumpe ataque actual + 1.5s CD penalty | Enemy: cancel state machine → RECOVERY + +1.5s a CDs. Player: cancela swing actual |

### Eje cósmico — supervivencia + maldiciones

| Elemento | Status | Efecto | Notas |
|---|---|---|---|
| LUZ (5) | **Bendición Divina** | Vampire heal: atacante recupera 5% HP máx | NO aplica status al defender — heal directo al source. Melee OK, projectile pendiente (no track source) |
| SOMBRA (6) | **Miasma** | DOT 5s 2 dmg/tick + **bypass armor** + **-50% Furia gen** | Stack INDEPENDENT (snowball lategame). Daño directo a health (no flat_defense). Player: furia.add_on_hit halved si miasma activo |

| NEUTRO (0) | — | Sin status | Sin elemento, sin synergy |

### Triángulos elementales

`GameConfig.ELEMENT_ADVANTAGE` — 6 elementos canon Leo 27/05:
- **Primario** (natural): FUEGO > TIERRA > AGUA > FUEGO
- **Secundario** (cósmico+viento): VIENTO > LUZ > SOMBRA > VIENTO
- **Cross-triángulo:** ×1.0 (FUEGO vs VIENTO neutral, AGUA vs LUZ neutral, etc.)
- Mismo elemento: ×1.0. NEUTRO involucrado: ×1.0.

### Wireado

- `HitboxComponent._try_apply_element_status` (melee/hammer/bow swing): branch LUZ → `_apply_bendicion_heal_to_source` (cura attacker), demás elementos → `se.apply(data)` sobre defender.
- `Projectile._try_apply_element_status` (arrow/fireball): LUZ skip (TODO source_entity tracking), demás aplican status.
- `HurtboxComponent.receive_hit`: consume FRACTURA al aplicar multiplicador (single-use).
- `Enemy._on_status_applied(&"desequilibrio")`: cancela attacking state → RECOVERY + suma 1.5s a CDs.
- `Player._on_hit_landed`: halve furia gain si `status_effects.has(&"miasma")`.

### Implicación gameplay

Equipo elemental ahora se "siente" más allá del ×1.5/×0.66 damage:
- **FUEGO** → DOT sostenido suma a daño base. Sinérgico con armas rápidas.
- **AGUA** → kiteo fácil — enemies ralentizados 2s con cada golpe.
- **TIERRA** → combo: aplicar Fractura + golpear segunda vez con build físico/elemental fuerte = ventaja masiva.
- **VIENTO** → control puro — enemies con casts largos se ven cancelados sistemáticamente.
- **LUZ** → sustain — vampirismo permite agresión sostenida sin retroceder.
- **SOMBRA** → presión — DOT que ignora armor + ahoga Furia del enemy. Snowball que el target no puede limpiar.

## 8. Pendientes futuros (post Fase 3 visual)

Acordado con Leo: cuando termine la Fase 3 (arte + audio + HUD polish), abrir sesión dedicada a:

- **Revisar TODAS las skills implementadas con más detalle** — feel, balance, telegrafías, interacciones entre skills, edge cases. Especialmente: taunt MMO real (¿se siente bien con override de input?), set bonus 3pc TIERRA "bloqueo infinito", balance R3 mage (proyectil potenciado + Orbe Flamígero AoE heredado), interacciones boss + mobs durante prueba con cap 1+8.
- **UI de equipado de skills activas del jugador** — actualmente sistema lógico está implementado (ver §5), falta UI para asignar/cambiar skills a slots y tree de unlock.
- ~~**Sistema de skills activas del jugador** (Furia → efecto)~~ ✅ IMPL 27/05 ver §5.
- ~~**StatusEffect system genérico**~~ ✅ IMPL 27/05 ver §3 (slow/burn/stun/post_dash_*/espiritu_marcial todos migrados).
- ~~**EnemySkill como Resource .tres**~~ ✅ IMPL parcial 27/05 ver §3 (telegraph/cd/attack_duration/damage_mult migrados, consts dash_distance/etc pendientes de migrar a params dict).
- **Pool de skills marcadas OK no implementadas** (Set A/B/C). Implementación incremental cuando justifique scope. Ahora con StatusEffect+EnemySkillData habilitados, varias skills "REQ-INFRA" del pool (§4) pasan a "OK con extensión chica".
- **Skills nuevas para clases adicionales** si se agregan más arquetipos en Fase 5+.

---

## 9. Referencias

- GDD §7 — Enemies y bosses
- GDD §4 — Combate moment-to-moment
- `.claude/docs/pilares.md` — los 4 pilares
- `scripts/entities/enemy.gd` — implementación state machine + skills R2/R3
- `scripts/entities/boss_guardian.gd` — R4 Tank boss (Guardián)
- `scripts/entities/boss_duelista.gd` — R4 Melee boss (Duelista de las Cenizas)
- `scripts/entities/boss_cazadora.gd` — R4 Archer boss (Cazadora del Crepúsculo)
- `scripts/entities/boss_heraldo.gd` — R4 Mage boss (Heraldo del Vacío)
- `scripts/data/skill_effect.gd` — stats cableados de capstones (efectos pasivos del player)
- Doc origen ideas: `Downloads/gemini-code-1779846324132.md` (incorporado a este catálogo)
