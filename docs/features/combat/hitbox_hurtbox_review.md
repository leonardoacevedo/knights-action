# Review — Hitbox de arma vs Hurtbox de cuerpo (29/05/2026)

> Review READ-ONLY pedido por Leo: "que la hitbox de armas sea acorde al diseño (excepto arco/vara = proyectil); mazo grande de boss → hitbox grande; mob chico → hurtbox chica; boss grande → hurtbox grande".
> **Estado: análisis, no aplicado.** Es tuning VISUAL — se verifica/ajusta mejor en el editor de Godot (donde se ve el shape sobre el sprite), idealmente junto al playtest. No se blind-editaron valores de colisión.

---

## Corrección importante a la primera auditoría

La primera pasada asumió que TODOS usan el sistema de swing-arc (`setup_weapon_swing` + `WEAPON_HITBOX_DEFAULTS`). **Falso para los bosses.** Hay DOS mecanismos distintos:

| Quién | Mecanismo de hitbox | Tamaño definido en |
|---|---|---|
| **Player + mobs genéricos (melee/tank)** | swing-arc (`setup_weapon_swing`, reach × scale_mult) | `WEAPON_HITBOX_DEFAULTS` (código) |
| **Los 7 bosses** | `hitbox.set_active(true)` directo sobre el **rectángulo legacy** | `HitboxShape` hand-authored en cada `.tscn` |

Los bosses **nunca** entran a `State.ATTACK` genérico ni llaman `setup_weapon_swing` (usan `_change_to_boss_state` con patrones propios). Por eso los números de reach "132px / 122px" de la primera auditoría **no aplican a bosses** — eran del path genérico que no usan.

---

## Valores REALES

### Bosses (rect legacy del .tscn — root-level, NO escala con sprite.scale; hand-tuned)

`reach = HitboxShape.position.x + size.x/2` (px absolutos desde el centro del cuerpo).

| Boss | Hitbox rect (w×h) | position.x | **reach real** | Arma signature | ¿Acorde? (verificar en editor) |
|---|---|---|---|---|---|
| **Ignis** | 78×56 | 52 | **~91px** | DEMENT_HAMMER (yunque grande) | sospecha CORTO — el yunque dibujado parece pasar los 91px |
| **Guardian** | 72×54 | 50 | **~86px** | ROOTED_MAUL (mazo grande) | sospecha CORTO — mazo grande, reach 86 |
| **Duelista** | 58×42 | 40 | **~69px** | DUAL_RAPIERS (floretes ~73px) | probablemente OK (69 ≈ 73) |
| Lyss/Vael/Cazadora/Heraldo | — | — | ranged | proyectil | ✅ sin hitbox melee |

**Hurtbox boss (rect .tscn, hand-sized):** Ignis 46×116, Guardian 44×112, Duelista 32×82, etc. = 75-104% del cuerpo dibujado → **bien calibrados**. Tu pedido "boss grande → hurtbox grande" YA está cubierto (manual por .tscn).

### Player + mobs genéricos (swing-arc)

- SWORD default reach **50** (× scale_mult). Player scale_mult=1.0 → 50px desde el origen del nodo Hitbox. La hoja dibujada mide `blade_len 22 × weapon_scale` desde la **mano** (origen distinto) → la punta visual queda ~29px del centro. El reach 50 es **generoso** (phantom reach), pero el "50 vs 22" no es comparación directa por el offset de orígenes.
- HAMMER default reach 36 / damage_zone 0.35 (solo cabeza). Tank mob.
- NONE (puños) reach 24.
- **Hurtbox mob:** fijo (18×54 base / tank 26×60 / archer 15×52). NO escala con rareza — **intencional** (comentario `enemy.gd:306`: "Solo escala el visual; hitbox/hurtbox se mantienen consistentes"). Gap menor: R3 mob (cuerpo ×1.12) con hurtbox base = ~10% chico.

---

## Por qué NO se aplicó nada todavía

1. **Boss hitbox = tuning visual.** Saber si el rect de Ignis (91px) cubre el yunque dibujado requiere VER el shape sobre el sprite (el editor de Godot lo muestra y se arrastra). Calcularlo headless desde `boss_figure.gd` (cadena `s × weapon_scale × sprite.scale`, orígenes mano vs nodo) es frágil y un valor mal puesto empeora un hitbox hand-tuned.
2. **Es código de combate** (scope de los bloqueantes del playtest). Cambiarlo ahora obliga a re-validar.
3. **P5 (hurtbox mob por rareza) contradice un intent documentado** (`enemy.gd:306`). No se cambia un diseño explícito sin confirmación.

---

## Checklist de tuning en editor (para Leo, junto al playtest)

Abrí cada boss `.tscn`, hacé visible el `HitboxShape`, comparalo con el arma dibujada en una pose de ataque:

- [ ] **Ignis** — si el yunque pasa los 91px: agrandar `RectangleShape2D_ignis_hit` (ej. `size 78×56 → ~110×64`) y/o `position.x 52 → ~62`. Valor de arranque: reach ~120-130px.
- [ ] **Guardian** — si el mazo pasa los 86px: `size 72×54 → ~100×62`, `position.x 50 → ~60`. Arranque reach ~110-120px.
- [ ] **Duelista** — probablemente dejarlo (69 ≈ floretes 73). Verificar.
- [ ] **Player sword** — si se siente largo/fantasma: bajar `WEAPON_HITBOX_DEFAULTS[1].reach` 50 → ~40 (hitbox_component.gd). Es un solo número, tunable in-game.
- [ ] **Hurtbox R3 mobs** (opcional, contradice intent 306): escalar el Hurtbox con la rareza, o dejar como está (gap ~10%, casi imperceptible).

**Los bosses ranged (Lyss/Vael/Cazadora/Heraldo) y arco/vara del player: NO tocar** — son proyectil, no tienen hitbox melee (verificado correcto).

---

## Valores de arranque propuestos (si se aplican, verificar en editor después)

| Cambio | Archivo | De → A |
|---|---|---|
| Ignis hitbox rect | `scenes/entities/boss_ignis.tscn` | `78×56 @x52` → `110×64 @x62` (reach 91→117) |
| Guardian hitbox rect | `scenes/entities/boss_guardian.tscn` | `72×54 @x50` → `100×62 @x60` (reach 86→110) |
| Player/mob sword reach | `scripts/components/hitbox_component.gd` | `WEAPON_HITBOX_DEFAULTS[1].reach 50 → 40` |

Duelista, hurtboxes de boss: dejar. P5 hurtbox mob: decisión pendiente (contradice intent).
