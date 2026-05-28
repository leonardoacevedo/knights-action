# Fórmulas del Juego

Toda fórmula numérica del juego, en un solo lugar. Cuando ajustés un número, **actualizá acá** y dejá registro de antes/después.

---

## Combate

### Daño con Momentum

```
daño_total = daño_base × (1 + 0.05 × momentum)
```

| Momentum | Multiplicador | Daño relativo |
| :---: | :---: | :---: |
| 0 (1x) | 1.00 | 100% |
| 1 (2x) | 1.05 | 105% |
| 3 (4x) | 1.15 | 115% |
| 5 (6x) | 1.25 | 125% |
| 7 (8x) | 1.35 | 135% |
| 10 (10x) | 1.50 | 150% |

Source: GDD §4.3.

### Drop rate con Momentum

```
drop_rate = base × (1 + 0.1 × momentum)
```

| Momentum | Multiplicador |
| :---: | :---: |
| 0 | 1.00 |
| 5 | 1.50 |
| 10 | 2.00 |

Source: GDD §4.3.

### Furia ganada con Momentum

```
furia_ganada = base × (1 + 0.05 × momentum)
```

Mismo multiplicador que el daño.

### Daño elemental — ventaja/desventaja

```
con ventaja:    daño × 1.5
con desventaja: daño × 0.66
neutral:        daño × 1.0
```

Source: GDD §5.3.

### Triángulos elementales (GDD §5.3 v2.2 — 6 elementos canon)

**Eje natural** (control + daño puro):
```
Fuego  > Tierra
Tierra > Agua
Agua   > Fuego
Viento — independiente dentro del eje natural
```

**Eje cósmico** (santidad / maldad):
```
Viento > Luz
Luz    > Sombra
Sombra > Viento
```

**Cross-triángulo:** ×1.0 neutral (ej. FUEGO vs LUZ, AGUA vs SOMBRA).
**Mismo elemento:** ×1.0. **NEUTRO involucrado:** ×1.0.

Implementación: `GameConfig.ELEMENT_ADVANTAGE` (doble triángulo).

### Decay de Furia

```
si tiempo_desde_último_ataque > 5.0:
    furia -= 5 / segundo (mientras la condición se mantenga)
```

Source: GDD §4.3.

### Cargas de escudo por rareza

```
R1: 0
R2: 1
R3: 2
R4: 3 (post-MVP)
```

Recarga:
- PvE: al checkpoint o fin de etapa.
- Coliseo: NO se recarga durante la batalla.

Source: GDD §4.3.

---

## Equipamiento

### Refinamiento

```
stat_final = stat_base × (1 + 0.05 × nivel_refinamiento)
```

Stat máximo: nivel +10 → ×1.5 stat base.

| Nivel | Bonus |
| :---: | :---: |
| +1 | +5% |
| +2 | +10% |
| +3 | +15% |
| +4 | +20% |
| +5 | +25% |
| +6 | +30% |
| +7 | +35% |
| +8 | +40% |
| +9 | +45% |
| +10 | +50% |

### Probabilidad de éxito por nivel

| Nivel objetivo | P(éxito) | Penalización |
| :---: | :---: | :--- |
| +1 | 1.00 | — |
| +2 | 1.00 | — |
| +3 | 1.00 | — |
| +4 | 0.70 | pérdida de materiales |
| +5 | 0.70 | pérdida de materiales |
| +6 | 0.50 | pérdida de materiales |
| +7 | 0.50 | pérdida de materiales |
| +8 | 0.30 | **-1 Nivel** |
| +9 | 0.20 | **-1 Nivel** |
| +10 | 0.10 | **-1 Nivel** |

**Pergamino de Protección** en +8/+9/+10: evita pérdida de nivel. **No** devuelve materiales.

**Implementación:**
```gdscript
if randf() <= probabilidad_objetivo:
    success()
else:
    fail()
```

Source: GDD §5.6.

### Expected attempts hasta +N (sin pergamino)

Esperanza matemática estimada para llegar a +N partiendo de +0, considerando el rebote por downgrade en +8/+9/+10:

| Target | Expected attempts (aprox.) |
| :---: | :---: |
| +1 | 1.0 |
| +3 | 3.0 |
| +5 | ~4.6 |
| +7 | ~7.0 |
| +8 | ~10 (con rebote complica) |
| +10 | **22+** |

Validar con script de simulación en `tests/sims/refinement_sim.gd`. Estos números son aproximación rápida; el agente `balance-engineer` debe correr la cadena de Markov completa.

---

## Progresión

### XP requerida por nivel

```
xp_para_subir(nivel_actual) = 100 × nivel_actual^1.5
```

| Nivel | XP para el siguiente |
| :---: | :---: |
| 1 | 100 |
| 2 | 283 |
| 5 | 1118 |
| 10 | 3162 |
| 15 | 5809 |
| 20 | 8944 |
| 25 | 12500 |
| 29 | 15616 |

XP total acumulada al nivel 30: ≈150-180k (validar con script).

Source: GDD §6.1.

### Fórmula de stats finales

```
stats_totales = stats_base(nivel) + stats_equipamiento + bonus_skills + bonus_set
```

Aplicar **aditivo**, no multiplicativo, salvo donde la fuente diga lo contrario explícitamente.

Source: GDD §6.4.

---

## Coliseo

### Gloria por victoria/derrota

```
delta_gloria_victoria   = clamp(25 + (gloria_oponente - tu_gloria) / 100, 25, 50)
delta_gloria_derrota    = clamp(-(15 + (tu_gloria - gloria_oponente) / 100), -30, -15)
```

(Versión preliminar; ajustar con `balance-engineer` y `ecos-coliseum` antes de release.)

Rangos duros:
- Victoria: **+25 a +50**.
- Derrota: **-15 a -30**.

Source: GDD §8.4.

### Asignación de Perfil IA

Umbrales preliminares (ajustar tras playtest):

```
si skill_actions_pct >= 0.30:
    perfil = "caster"
si block_actions_pct >= 0.20:
    perfil = "defensive"
si attack_actions_pct >= 0.60 y block_actions_pct < 0.10:
    perfil = "aggressive"
sino:
    perfil = "balanced"
```

Telemetría de las **últimas 10 batallas** del jugador.

Source: GDD §8.5. Implementación: `ecos-coliseum`.

---

## Bestiario

### Bonus por kills (§9.2)

| Tier | Kills | Bonus daño vs especie |
| :---: | :---: | :---: |
| 1 | 10 | +0.5% |
| 2 | 50 | +1.0% |
| 3 | 100 | +2.0% |

Acumulativo (no multiplicativo entre sí). El bonus tier 3 (+2%) **sustituye** al tier 1 y 2, no se suma.

---

## Reglas de uso

1. **Cambios numéricos pasan por `balance-engineer`** antes de aplicar.
2. **Documentá antes/después en este archivo** cuando ajustés un número.
3. **Si introducís una fórmula nueva**, agregala acá con su fuente (sección del GDD).
4. **Si la fórmula vive en GDScript**, agregá en el script un comentario:
   ```
   # Fórmula documentada en .claude/docs/formulas.md.
   ```
5. **Nunca mantengas dos versiones de una fórmula** (en código y acá divergentes).

## Changelog de fórmulas

| Fecha | Fórmula | Antes | Después | Razón |
| :--- | :--- | :--- | :--- | :--- |
| 2026-05-21 | — | — | — | Inicial: fórmulas extraídas del GDD v2.1. |
| 2026-05-25 | Refinamiento — tabla de prob. | — | Documentada arriba | Backend implementado. Implementación en `upgrade_manager.gd`. |
| 2026-05-28 | Weapon Swing Hitbox | hitbox = rect fijo en frente | polígono rota con swing + scale por sprite | Pilar #2. Defaults SWORD/HAMMER por visual_type + override per ItemData. |

---

## Weapon Swing Hitbox (28/05/2026)

### Forma del polígono

```
start_x = reach × (1 - damage_zone)
end_x   = reach
half_w  = width / 2
taper   = 0.7  (punta 30% más fina que base)

local_pts = [
  (start_x, -half_w),
  (end_x, -half_w × taper),
  (end_x,  half_w × taper),
  (start_x, half_w),
]
```

### Rotación por swing

```
angle = lerp(-arc_rad / 2, +arc_rad / 2, progress)   # progress 0..1
rotated.x = (p.x × cos(angle) - p.y × sin(angle)) × facing
rotated.y =  p.x × sin(angle) + p.y × cos(angle)
```

### Escalado por sprite

```
scale_mult  = sprite.scale.x × sprite.weapon_scale
final_reach = base_reach × scale_mult
final_width = base_width × scale_mult
```

| Entidad | sprite.scale | weapon_scale | mult | SWORD reach | HAMMER reach |
| :--- | :---: | :---: | :---: | :---: | :---: |
| Player | 1.0 | 1.0 | 1.00× | 50 | 36 |
| Mob R1 | 1.0 | 1.0 | 1.00× | 50 | 36 |
| Mob R2 | 1.15 | 1.0 | 1.15× | 57 | 41 |
| Mob R3 | 1.30 | 1.0 | 1.30× | 65 | 47 |
| Guardian TANK R4 | 2.03 | 1.8 | 3.65× | — | 131 |
| Ignis MELEE R4 | 1.67 | 1.8 | 3.00× | — | 108 |
| Duelista MELEE R4 | 1.52 | 1.6 | 2.44× | 122 | — |

### Defaults por visual_type (HitboxComponent.WEAPON_HITBOX_DEFAULTS)

| visual_type | reach | width | arc_deg | damage_zone |
| :--- | :---: | :---: | :---: | :---: |
| 0 (NONE / puños) | 24 | 14 | 100° | 1.00 |
| 1 (SWORD) | 50 | 12 | 130° | 1.00 (filo entero) |
| 4 (HAMMER) | 36 | 26 | 110° | 0.35 (solo cabeza) |

Bow (2) / Staff (3) / Shield (5) excluidos — ranged o no-arma.

### Override por ItemData

Cada `.tres` puede setear `weapon_reach/width/arc_deg/damage_zone` no-cero para reemplazar default. Cero = usar default del visual_type.

Source: `scripts/components/hitbox_component.gd` + `scripts/data/item_data.gd`.
