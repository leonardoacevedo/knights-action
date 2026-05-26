# Boss: El Guardián de la Maleza

> **Zona:** Valle de los Ecos (Zona 1, etapa 4).
> **Elemento dominante:** Tierra.
> **Estado:** Restaurado e integrado el 25/05/2026 desde `_wip/`. Pendiente playtest validatorio.

## Identidad

- Boss R4 inaugural del MVP (GDD §10).
- Espejo del jugador: bloquea con cargas REALES, dashea, telegrafía y tiene fases.
- Fantasía: "una bestia de roca y musgo que pisa fuerte, te empuja a leer su intent".
- Cargas de escudo: **4** (recargables — ver más abajo).
- HP base: 200 (TANK) × 4.5 (RARITY_HP_MULT[R4]) = **900 HP**.
- Daño base: 5 (TANK) × 2.2 (RARITY_DAMAGE_MULT[R4]) = **11 dmg base** (los patrones aplican mults).
- Scale visual: rarity_scale_for(R4)=1.45 × 1.40 boss boost = **~2.0× del enemy normal**.

## Decisión técnica: bloqueo (Opción A)

**Reusamos `EnemyBlockHandler`** (el componente que `enemy-ai` creó para el Fix 1
de R2/R3). NO existe un `BossShieldComponent` separado. Esto unifica el patrón:

- `hurtbox.shield = _block_handler` permanente en el boss.
- El handler se setea con `shield_charges = 4` desde `boss_guardian.gd::_setup_shield`.
- Cada hit del player → `HurtboxComponent.receive_hit` → `shield.try_absorb()` → consume 1 carga REAL.
- Al llegar a 0 cargas → `_on_shield_broken` apaga el aura, screen-shake, ventana de daño.
- Recarga: ver siguiente sección.

Justificación vs Opción B (componente boss-only):
- Mismo flow que R2: una sola fuente de bloqueo enemy, un solo bug surface.
- La "complejidad extra" del boss (cargas, regen, fase) vive en `boss_guardian.gd`,
  no en el handler. Separación de responsabilidades clara.
- Lo que era `_wip/enemy_shield_component.gd` fue borrado (Leo pre-autorizó en handoff).

## Recarga de cargas

Mix de dos triggers:
- **(a) Al entrar a Fase 2 (HP <50%):** `_restore_shield()` reset a max + grito visual ("se enfurece").
- **(b) Cada `SHIELD_AUTOREGEN_SECONDS = 12s` desde el último golpe en 0 cargas:** reset automático.

Lo que NO hay (descartado):
- Recarga al usar skill especial — el boss ya tiene mucha rotación, sumar otro trigger lo vuelve confuso.
- Cargas infinitas — el player necesita ver el "broken state" para sentir progreso.

## Fases

### Fase 1 (HP 100% → 50%)

| Patrón | Windup | Active | Damage mult | Cooldown | Trigger |
|---|---:|---:|---:|---|---|
| Embestida (CHARGE) | 0.55 s | 0.55 s | ×1.4 | 4-6.5 s | dist 1.8× to 460 |
| Raíces (3 AoE) | 0.7 s | 0.4 s | ×1.1 | 5-7.5 s | dist < 460 |
| Gap-Close Dash | 0.3 s | 0.4 s | ×0.9 | 3-4.5 s | dist > 2.5× attack_range |
| Melee swing (heredado) | 0.4 s (TANK) | 0.1 s | ×1.0 | natural | dist < 50 |

### Fase 2 (HP <50%)

- **Trigger:** al cruzar 50% HP, el boss salta y aplasta (Slam, único, ×1.8 dmg, AoE 140px).
- Mantiene todos los patrones de F1 con cooldowns ×0.75 (más agresivo).
- Recarga las cargas de escudo al transicionar.
- **Nuevo patrón: Tormenta de Espinas** — AoE 200px, windup 1.0s, ×1.6 dmg, cooldown 7.5-10.5s. Solo F2.

## Gap-Close Dash (feature nueva por feedback Leo)

Leo en playtest: "el boss debe usar dash para acercarse, debe ser un jugador más".

- Si el player se aleja >2.5× attack_range pero está dentro del rango razonable
  (<1.5× CHARGE_TRIGGER_DISTANCE), el boss telegraphea 0.3s y dashea hacia el player
  a 1100 px/s por 0.4s o hasta que entra a melee range.
- Hitbox activo durante el dash con daño ×0.9 (penaliza al player que está en la línea
  pero no es el "ataque pesado").
- Cooldown 3-4.5s. Permite que el boss persiga activamente sin loopear.

## Aura visual

Override del `BossAura` heredado de Enemy:
- `amount = 30` (vs 28 del genérico R4).
- `lifetime = 1.8s`, `emission_sphere_radius = 32px` (halo más ancho).
- Color verde-dorado (Color(0.85, 0.95, 0.45) → Color(0.45, 0.70, 0.15)) — identidad del Valle.
- Scale de partículas 0.6-1.4 (más grandes).
- Persistente — se apaga solo cuando todas las cargas se rompen (señal visual de exposición).

## Integración al spawn

Sin tocar `zona1_etapa_4.tres` (sigue siendo `TANK + R4 + is_boss=true`). En `world.gd`:

```gdscript
# Boss override: si la stage es boss + la entry es R4, reemplazamos el
# Tank R4 genérico por el Guardián de la Maleza.
if data.is_boss and entry.rarity == GameConfig.EnemyRarity.R4 and scene_boss_guardian != null:
    scene = scene_boss_guardian
```

`scene_boss_guardian` es un `@export var PackedScene` con preload de
`scenes/entities/boss_guardian.tscn`. Editable desde el inspector.

## Archivos involucrados

- `scripts/entities/boss_guardian.gd` (~485 líneas, extends Enemy).
- `scripts/entities/boss_guardian.gd.uid` (uid preservado de `_wip/`).
- `scenes/entities/boss_guardian.tscn` (hereda de `enemy.tscn`, override script + visual).
- `scripts/world/world.gd` (1 @export nuevo + 4 líneas en `_spawn_stage`).

Reutilizados sin cambios:
- `scripts/components/enemy_block_handler.gd` (Fix 1 de enemy-ai).
- `scripts/components/hurtbox_component.gd` (duck typing del shield).
- `scenes/entities/enemy.tscn` (el boss hereda).
- `resources/stages/zona1_etapa_4.tres` (intacto).

## Smoke checks para playtest

1. **Spawn:** correr el juego, llegar a etapa 4 → debe aparecer un boss verde-musgo grande con halo verde-dorado denso, no un tank R4 dorado normal.
2. **Cargas reales:** golpear al boss 4 veces seguidas → cada hit muestra floater dorado con cargas restantes (4, 3, 2, 1, 0). En el 5º golpe, aura se apaga + screen-shake fuerte; ese golpe SÍ aplica daño al HP.
3. **Regen:** dejar al boss 12s sin golpearlo (después de romper escudo) → aura debe reaparecer + burst dorado, próximos golpes se absorben de nuevo.
4. **Gap-close:** alejarse del boss hasta el borde del mapa → el boss telegraphea brevemente (0.3s) y dashea horizontal hacia el player. NO debe quedarse parado caminando.
5. **Patrones agresivos:** quedarse a distancia media (300px) → debe ver charge + raíces alternando con cooldowns de 4-7s (no 8-15 como antes). El boss no debe sentirse pasivo.
6. **Telegraphs leíbles:** cada ataque pesado tiene el "!" de telegraph visible al menos 0.4s antes — verificar que se ve y se puede esquivar.
7. **Fase 2:** bajarle el HP hasta cruzar 50% → boss salta alto y aterriza con AoE (Slam). Screen-shake fuerte. Después de eso, aparece patrón nuevo: Tormenta de Espinas (anillo violeta grande, 1s windup).
8. **Drops + muerte:** matar al boss → loot card de stage cleared se dispara, fade-out del cadáver normal, no se queda colisión.

## Pendientes / TODOs

- **UI específica de boss** (HP bar grande arriba, nombre, count de cargas visible). Leo dijo "bonus si queda tiempo". No implementado.
- **SFX**: hits absorb, broken, slam, storm, gap-close. Pendiente fase de audio.
- **Variante Eco Profundo** (+20 niveles, drops exclusivos GDD §7.2). Para más adelante.
- **Sprite final** del Guardián. Hasta sprites IA → StickFigure verde-musgo.
- **Skill especial telegrafiada larga** distinta de la Tormenta (Leo mencionó "skills" en plural). Por ahora 1 ultimate alcanza para Fase 2 — sumar otra si el playtest pide más variedad.
- **Test unitario** del state machine boss (transición de fase exacta, recarga de cargas, cooldowns post-F2). Pendiente.

## Decisión técnica: por qué no clase separada

El boss extends `Enemy` en vez de ser una clase nueva (CharacterBody2D propio):

- Reusa salto multi-hop, gravity, facing, target detection (200+ líneas que ya están pulidas).
- Los estados boss (CHARGE/ROOTS/SLAM/STORM/GAP_CLOSE) son ints >=100 que no chocan con el enum `State` del padre (el match cae a `_:` cuando no matchea).
- `_tick_state` override delega al padre si no estamos en estado boss.
- Riesgo conocido: si el padre cambia el match para incluir todos los ints, podría pisar. Mitigación: guard `if state >= BOSS_STATE_CHARGE_WINDUP: return` antes del `super._tick_state`.
