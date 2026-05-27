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
| Melee | ✅ Corte espada arco frontal | ✅ + Embestida-dash + knockback | ✅ + **Sed de Sangre** (buff +20% vel/atk 5s, CD 12s). Skill genérica R3 (hitbox ampliada) eliminada — era redundante con ataque básico. | ✅ Guardián (5 patrones) |
| Tank | ✅ Hammer overhead | ✅ + **Taunt MMO clásico** — redirige **100%** del daño que el player hace a aliados (radio 45px) hacia el tank por 3s. **Además fuerza al player:** facing hacia el tank + pull horizontal a SPEED completa hasta pegarse (35px). Player conserva salto/ataque/bloqueo/dash, solo el movimiento lateral está override. Marker "!" pulsante + flash rojo de pantalla + aura naranja + tinte sprite + líneas a aliados + damage floater grande sobre tank. CD 12s. **Decisión Leo:** aunque se sienta "roto", el taunt DEBE ser así para cumplir su rol. | ✅ + skill genérica potenciada (hammer ×1.5 daño con telegrafía 1.5s) | — |
| Archer | ✅ Flecha Perforante (single arrow, pierce ×3) | ✅ + Ráfaga 3 flechas spread ±15° (CD 8s) | ✅ + proyectil potenciado (×1.5 daño, telegrafía 1.5s) | — |
| Mage | ✅ Orbe Flamígero (fireball + AoE radial 35px / 60% daño on impact) | ✅ + Canalizar 1.2s → fireball ×1.8 size + ×1.5 daño (CD 10s) | ✅ + proyectil potenciado (fireball ×1.5 daño, telegrafía 1.5s) | — |

**Capstones del árbol player** (efectos pasivos/buffs temporales activos hoy):
- `agil_golpe_tras_dash` — +10% daño 0.5s post-dash (POST_DASH_DAMAGE_PCT)
- `agil_sombra_del_valle` — invis 0.5s post-dash + ventaja elemental garantizada
- `guerrero_espiritu_marcial` — +20% daño 2s tras bloquear
- `mago_resonancia_arcana` — +1 Furia/s pasiva
- `mago_ventaja_aguzada` — +15% al multiplicador de ventaja elemental
- Stats cableados: BLOCK_CHARGES, IFRAMES_PCT, MOVE_SPEED_PCT, DASH_COOLDOWN_PCT, EVADE_PCT, etc.

**Skills activas del player (Furia → efecto):** ⛔ NO implementado. Sistema pendiente — ver §6.

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
| Dash con i-frames | `DashComponent` |
| Knockback al player | `player.apply_external_velocity(push)` |
| Buffs temporales con timer | `_post_dash_damage_timer`, `_espiritu_marcial_timer` |
| Element propagado | `hitbox.element`, `hurtbox.element` |
| Set Bonuses afinidad | `SetBonusSystem` |
| Furia (player) ya acumula + decae | `FuriaComponent` |

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
| **Status Effect System genérico** | Resource `StatusEffectData` + `StatusEffectComponent` por entity. Maneja stacking, refresh, expiration, signals. Hoy todo es ad-hoc (flags + timers por skill). Necesita ~200 líneas + refactor de skills existentes. |
| **EnemySkill como Resource .tres** | Como propone Leo en su doc. Migra la `R2_SKILL_TABLE` hardcoded a `resources/enemy_skills/*.tres`. Lógica de ejecución sigue en código (executor por `telegraph_type`). Permite asignar skills al spawn entry. Beneficio: balance sin recompile + variants fáciles. Costo: ~150 líneas + migración de skills R2 actuales. |
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
| Guerrero | R2 | Salto de Asalto (gap closer + AoE caída) | OK | Telegrafía sombra circular en suelo (requiere AoeTelegraph scene). Knockback ya tenemos. |
| Guerrero | R3 | Rugido de Guerra + Stagger | REQ-INFRA | Stagger = State.STUNNED en player (no implementado). Si no se puede hacer Stagger, reducir a Slow 50% por 1s. |
| Tank | R1 | Provocación / forced-look | NO | Ver §3 ⛔. Reinterpretar como aura visual + flag de prioridad UI. |
| Tank | R2 | Escudo Cargado (embestida + rompe 1 carga escudo player) | PARC | Embestida ya tenemos (similar al melee R2). "Romper carga del escudo player" = nuevo hook en `player.shield.consume_charge_force(1)`. ~5 líneas. |
| Tank | R3 | Muralla Estática (invuln frontal + refleja) | REQ-INFRA | Invuln direccional viable (~10 líneas). Refleja proyectiles requiere infra nueva. Reducir a "ignora proyectiles" si no se quiere reflexión. |
| Archer | R1 | Flecha Perforante (ignora colisión con otros enemies) | IMPL | Flag `pierce_enemies + pierce_count` en `Projectile`. Activo para Archer R1 base. Trail Line2D. |
| Archer | R2 | Lluvia de Flechas (3 AoE telegrafiados que caen tras 0.5s) | REQ-INFRA | Necesita AoeTelegraph + sistema de "drop after delay" (Timer + spawn). ~30 líneas. |
| Archer | R3 | Flecha Aturdidora (stun 1s) | NO | Ver §3 ⛔. Reducir a Slow 70% por 0.7s. |
| Mage | R1 | Orbe Flamígero (AoE explosivo post-impacto) | IMPL | `aoe_on_impact` flag en `Projectile`. AoeTelegraph 0.4s + daño radial 35px/60%. Solo Mage R1 base. |
| Mage | R2 | Nova de Hielo (zona fija bajo player que explota tras windup) | PARC | AoeTelegraph + spawn de AoE explosivo. Similar a Lluvia. |
| Mage | R3 | Lluvia de Meteoros (3 homing) | REQ-INFRA | Projectile homing. Si no, reducir a 3 proyectiles secuenciales straight con timing. |

### 4.2 Set B (Alternativo)

| Clase | Rareza | Nombre | Estado | Notas |
|---|---|---|---|---|
| Guerrero | R1 | Tajo Doble | OK | 2 hitboxes secuenciales 0.1s separados. Trivial. |
| Guerrero | R2 | Corte Giratorio (AoE 1.5s rotación) | OK | Hitbox activa con rotación continua. ~20 líneas. |
| Guerrero | R3 | Sed de Sangre (buff propio +vel/atk 5s) | IMPL | `_skill_r3_buff_cooldown` (12s) + `_r3_buff_timer`. Prioridad máxima en CHASE. VFX aura roja + tinte sprite. |
| Tank | R1 | Golpe Terremoto (AoE + Slow 50% / 2s) | REQ-INFRA | Slow requiere `_external_speed_mult` en player. |
| Tank | R2 | Gancho (proyectil que arrastra) | PARC | Tween de player hacia tank si proyectil acierta. ~30 líneas. Player nota "no responde" durante el pull — comunicar con flag visual. |
| Tank | R3 | Guardia Espinada (refleja melee + Stagger) | REQ-INFRA | Reflejar daño = redirigir back al atacante. Stagger ver §3. |
| Archer | R1 | Disparo en Abanico (3 flechas cono frontal) | OK | Idéntico al R2 actual pero como ataque básico R1. |
| Archer | R2 | Trampa de Cazador (estática que inmoviliza) | REQ-INFRA + NO inmovilización. | PersistentHazard scene + Slow 70% al pisar. |
| Archer | R3 | Flecha Explosiva (adherente + explota 1.5s) | OK | Projectile con onHit → Timer → AoE radial. ~25 líneas. |
| Mage | R1 | Látigo Relámpago (línea instantánea tras windup largo) | OK | Hitbox rectangular activa 0.1s tras telegraph. ~15 líneas. |
| Mage | R2 | Muro de Llamas (línea fija 4s) | REQ-INFRA | PersistentHazard. ~30 líneas. |
| Mage | R3 | Rayo Penetrante (láser 2s que persigue lento) | REQ-INFRA | Line2D que se actualiza cada frame con interpolación lenta hacia player. ~40 líneas. |

### 4.3 Set C (Táctico)

| Clase | Rareza | Nombre | Estado | Notas |
|---|---|---|---|---|
| Guerrero | R1 | Patada Frontal (rango corto + knockback) | OK | Reusar Hitbox melee con damage menor + knockback. Trivial. |
| Guerrero | R2 | Gancho Ascendente (rompe 2 cargas escudo) | PARC | Similar a Tank R2 set A "Escudo Cargado". |
| Guerrero | R3 | Arma Imbuida (buff propio, ataques ignoran escudo) | PARC | Flag en hitbox `ignore_shield: bool`. ShieldComponent verifica antes de absorber. ~10 líneas. |
| Tank | R1 | Golpe de Escudo (interrumpe ataque/dash player) | REQ-INFRA | "Interrumpir dash" = cancelar dash en curso → DashComponent.cancel(). "Interrumpir ataque" = cancelar swing → player.cancel_attack(). Ambos requieren hooks nuevos. ~20 líneas. |
| Tank | R2 | Salto Sísmico (AoE + zona persistente 2s) | REQ-INFRA | PersistentHazard + AoeTelegraph. |
| Tank | R3 | Vórtice de Gravedad (pull masivo) | NO / parcial | Ver §3 ⛔. Si se hace, área limitada + duración 1s máx. |
| Archer | R1 | Disparo Reactivo (rápido, bajo daño) | OK | Proyectil con velocity ×2 + damage ÷2. Trivial. |
| Archer | R2 | Flecha Tóxica (nube DOT 3s) | REQ-INFRA | DOT + PersistentHazard. |
| Archer | R3 | Tiro Mortal / Snipe (laser sigue, dispara fijo) | REQ-INFRA | Similar a Mage R3 set B. |
| Mage | R1 | Ráfaga Arcana (3 proyectiles rápidos sucesivos) | OK | 3 calls a `_spawn_projectile()` con delay 0.1s. ~10 líneas. |
| Mage | R2 | Erupción Terrestre (pilar desde suelo bajo player) | OK | AoeTelegraph + spawn de hitbox vertical tras delay. |
| Mage | R3 | Tormenta Persecutoria (nube + rayos periódicos 4s) | REQ-INFRA | PersistentHazard que sigue al player + spawn de rayos cada N seg. |

---

## 5. Skills del Jugador — Sistema Pendiente

**Estado actual:** Furia ya acumula (+10/golpe, decay 5/s tras 5s sin atacar, cap 100). NO se gasta en nada todavía.

**Sistema requerido (no implementado):**
- Catálogo `PlayerSkillData` (Resource) con: nombre, costo Furia, CD, efecto, animación.
- 3 slots equipables (joystick + 5 botones disponibles → 3 botones libres para skills).
- UI de asignación skill→slot (drag-and-drop o picker).
- Sistema de ejecución (validar Furia + CD, animar, aplicar efecto, consumir Furia, iniciar CD).
- Cómo se obtienen skills? **Decisión pendiente Leo**: ¿drop? ¿unlock por árbol? ¿pre-fijas por clase?

**Pool propuesto inicial (cuando se implemente el sistema):**

| Slot | Nombre | Costo Furia | CD | Efecto |
|---|---|---|---|---|
| 1 | Embestida | 30 | 4s | Dash extendido con damage. Atraviesa enemies (similar Melee R2 pero al revés). |
| 2 | Onda Sísmica | 50 | 8s | AoE radial 100px que stuns enemies 0.3s. |
| 3 | Bola de Fuego | 40 | 6s | Proyectil grande que explota al impactar (similar Mage R2). |
| 4 | Curación | 60 | 15s | Recupera 30% HP. |
| 5 | Furia Berserker | 80 | 20s | +30% daño 5s, consume toda la Furia. |
| 6 | Escudo Mágico | 40 | 10s | +3 cargas de bloqueo temporales. |
| 7 | Sombra | 70 | 25s | Invisibilidad 2s, próximo ataque ×2 daño. |
| 8 | Flecha Eléctrica | 35 | 5s | Proyectil que rebota entre 3 enemies. |

**Status:** TODOS pendientes. Sistema requerido en sesión separada con scope completo.

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

## 8. Pendientes futuros (post Fase 3 visual)

Acordado con Leo: cuando termine la Fase 3 (arte + audio + HUD polish), abrir sesión dedicada a:

- **Revisar TODAS las skills implementadas con más detalle** — feel, balance, telegrafías, interacciones entre skills, edge cases. Especialmente: taunt MMO real (¿se siente bien con override de input?), set bonus 3pc TIERRA "bloqueo infinito", balance R3 mage (proyectil potenciado + Orbe Flamígero AoE heredado), interacciones boss + mobs durante prueba con cap 1+8.
- **Sistema de skills activas del jugador** (Furia → efecto). Ver §5 — sistema grande sin scope cerrado, decisiones pendientes.
- **StatusEffect system genérico** (ver §3 🔴) — habilita Slow/Stun/Stagger/DOT estandarizados. Hoy todo es ad-hoc.
- **EnemySkill como Resource .tres** (ver §3 🔴) — migra tabla hardcoded a data-drive. Justificable cuando entre zona 2.
- **Pool de skills marcadas OK no implementadas** (Set A/B/C). Implementación incremental cuando justifique scope.
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
