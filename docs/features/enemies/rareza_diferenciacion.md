# Diferenciación de enemies por rareza R1/R2/R3

**Fecha de implementación:** 2026-05-25
**Implementado por:** Claude Code (orquestación) + `enemy-ai` (diseño + implementación) + `balance-engineer` (audit drop tables)
**Fase del proyecto:** 2 — Loop Básico
**Sección GDD relevante:** §7.3 (escalado de IA por rareza), §13 (scope Fase 2)
**Pilar(es) reforzado(s):** #1 (mi build importa — R2/R3 requieren responder con build/skill), #2 (cada muerte enseña — tells visuales claras por rareza), #3 (skill > farmeo — bloqueo y dodge premian timing)

---

## Qué hace

Implementa las diferencias de **comportamiento + visual + drops** entre rarezas R1, R2 y R3 que pide GDD §7.3. Antes, las rarezas solo escalaban stats (HP/daño/telegraph) — el comportamiento era idéntico. Ahora:

- **R1:** sin cambios. Movimiento simple, ataques telegrafiados, sin bloqueo.
- **R2:** bloquea ocasionalmente con aura azul cuando detecta el wind-up del jugador. Tras absorber, contraataca.
- **R3:** dashea lateralmente para esquivar ataques + tiene una **skill especial** con telegrafía larga (1.5s) y daño aumentado (×1.5).

Visualmente, R2 tiene tint azulado y +5% scale; R3 tiene tint violeta-dorado, +10% scale y aura de partículas en IDLE. R4 queda sin tocar (es trabajo del `boss-designer`).

## Por qué (pilares)

- **Pilar #1 — Mi build importa.** R3 fuerza al jugador a responder con técnica (esquivar la skill, leer telegraph). Builds tanky sobreviven los blocks de R2; builds DPS fuerzan la apertura.
- **Pilar #2 — Cada muerte enseña.** Cada rareza tiene un tell visual obligatorio: aura azul = R2 bloqueando, tint violeta = R3 puede dashear o usar skill, "!" largo = skill incoming. El jugador no puede sentir que algo fue "injusto" — las señales están.
- **Pilar #3 — Skill > farmeo.** Bloqueo y dodge premian al que lee el combate. Drop tables por rareza fuerzan a perseguir kills de mejor calidad (R3 dropea Esencia) en lugar de farmear R1 trash.

## Cómo se integra

### Behavior

El state machine de `Enemy` (`scripts/entities/enemy.gd`) se amplió con **3 estados nuevos**:

```
IDLE → CHASE → TELEGRAPH → ATTACK → RECOVERY → IDLE
                ↓ (R2, 40% chance, player attacking)
              BLOCK (0.5-1.0s, aura azul, hurtbox invulnerable)
                ↓
              TELEGRAPH (contraataque inmediato)

CHASE → DODGE (R3, 25% chance, dash lateral 120px, 4s cooldown)
      → SKILL_TELEGRAPH (R3, 1.5s, hot skill) → SKILL_ATTACK (×1.5 dmg) → RECOVERY
```

Las guards `if rarity >= R2` y `if rarity >= R3` aseguran que los nuevos estados no se activen en R1.

### Visual (StickFigure)

- Tint aplicado vía `modulate` del sprite root.
- Scale aplicado al nodo enemy directamente.
- R3 aura: `GPUParticles2D` con `amount=14` (mitad que un boss para ser mobile-friendly), color violeta.

### Drops

- Nuevas drop tables en `resources/enemies/drop_tables/`:
  - `enemy_r1_materials.tres`
  - `enemy_r2_materials.tres`
  - `enemy_r3_materials.tres`
- Cada `EnemySpawnEntry` en stage puede asignar `material_drops` apuntando a la tabla de su rareza. Si no se asigna, cae al fallback de stage.
- `zona1_etapa_2.tres` actualizada con mix `[Melee R1 ×2, Tank R2 ×1, Melee R3 ×1]`.

## Decisiones técnicas no obvias

1. **Bloqueo R2 via `hurtbox.invulnerable = true`** en lugar de simular el `ShieldComponent` del jugador. Razón: el enemy no tiene escudo equipable — es "instinto defensivo", no un sistema con cargas. Patrón: el `hurtbox.receive_hit()` ya chequea `invulnerable` primero y skipea `take_damage`. Cleanup garantizado en `_change_state` al salir de BLOCK.

2. **Duck typing `_target.get("is_attacking")`** para detectar wind-up del jugador. Razón: evita import del script `Player` y mantiene `Enemy` desacoplado. Si el target no expone `is_attacking`, retorna null → `== true` es false → safe no-op.

3. **R3 skill cooldown inicial de 6s al spawn.** Razón: evitar que el R3 use skill inmediatamente cuando spawnea. Si Leo reinicia la etapa varias veces en playtest, puede ver el skill activarse "en CHASE" (lejos del jugador) — sugerencia del agente: agregar `if dist < detect_range * 0.6` como condición adicional. **Decisión pendiente de Leo** post-playtest.

4. **Scale aplicado al nodo enemy** (no al StickFigure interno) para que el hurtbox y hitbox escalen con la rareza. Esto puede tener implicancia sutil en los hitbox sizes — validar en playtest si se siente justo.

5. **Stage elegida para mix: zona1_etapa_2** (no etapa 3). Razón del agente: la etapa 2 es el momento pedagógico ideal para introducir variedad de rarezas. Etapa 3 ya tenía R2 en su composición original y está calibrada para pacing ascendente.

## Cómo testear manualmente (smoke checks)

En Godot Editor, run de `zona1_etapa_2`:

1. **Melee R1 (sin tint):** entra directo. No bloquea ni dashea. Si spammeás ataques, siempre lo golpeás.
2. **Tank R2 (tinte azul, +5% scale):** ocasionalmente cuando empieza tu wind-up, adopta postura defensiva con aura azul. Golpes durante el aura → 0 daño en floater. Tras ~0.7s, contraataca inmediato.
3. **Melee R3 (tinte violeta-dorado, +10% scale, partículas violetas en IDLE):** distinguible desde el spawn. Cada 6-8s muestra "!" largo de 1.5s antes de un golpe más fuerte. Ocasionalmente dashea lateralmente cuando atacás.
4. **R2 cooldown:** atacar repetido al Tank R2 no debe bloquear el 100% del tiempo — ~1 de cada 3-4 intentos. Si bloquea siempre, hay bug en `_block_cooldown`.
5. **R3 esquiva no spammeada:** dodge ~25% chance, no debería ser un wall infinito. Si dashea cada ataque, bajar `DODGE_TRIGGER_CHANCE`.
6. **Drops por rareza visibles:** matar R1 → solo Hierba/Piedra. Matar R3 → puede aparecer Savia o Esencia (raro pero visible).
7. **HUD de bloqueo:** verificar que el "BLOCK!" floater del player NO sale cuando el enemy R2 bloquea TU ataque (es el inverso — el enemy ate tu ataque, no vos al de él).

## Tests unitarios

Ninguno automatizado en este round. `godot-expert` puede agregar tests de regression sobre las transiciones de estado nuevas si Leo lo pide después del playtest.

## Assets necesarios (futuros)

- **Sprites diferenciados por rareza** (cuando llegue arte definitivo) — pendiente de `art-prompt-engineer`. Por ahora tints sobre StickFigure procedural alcanzan.
- **SFX de bloqueo enemy** y de dodge — pendiente, sin pipeline audio.

## Archivos tocados

### Nuevos
- `resources/enemies/drop_tables/enemy_r1_materials.tres`
- `resources/enemies/drop_tables/enemy_r2_materials.tres`
- `resources/enemies/drop_tables/enemy_r3_materials.tres`

### Modificados
- `scripts/entities/enemy.gd` — estados BLOCK, DODGE, SKILL_TELEGRAPH, SKILL_ATTACK + lógica + tints + scale.
- `resources/stages/zona1_etapa_2.tres` — composición de spawns + drop tables por entry + subtitle.

## Pendientes / mejoras futuras

### Decisiones pendientes (post-playtest)
- **¿Agregar `if dist < detect_range * 0.6` al trigger del skill R3?** Para evitar que se vea raro en CHASE lejos del player. Sugerencia del agente.
- **Tuning de chances** (BLOCK 40%, DODGE 25%, SKILL cd 6-8s) según feel del playtest.
- **HURT state** (preexistente, no usado por nadie) — decidir si darle uso (i-frames del enemy) o limpiarlo.

### Drop tables por rareza
- Auditadas por `balance-engineer` en esta misma sesión. Resultado: ver sección final de este doc o el commit asociado.

### Stages 1, 3, 4
- Siguen con composición original (sin mix de rarezas por entry). Si Leo quiere variedad en toda zona 1, hacer un round 2 de `enemy-ai` o `level-designer` para distribuir R1/R2/R3 en las 4 stages.

### Behavior R4 (boss)
- Fuera de scope acá. Se maneja con `boss-designer` cuando se diseñe "El Guardián de la Maleza" (GDD §10).
