# Feature: XP por kill de enemy

**Estado:** implementado (2026-05-26)
**GDD:** §6.1 — Nivel del personaje, curva XP
**Fase:** 3

---

## Qué hace

Cada enemy que muere otorga XP al player según su rareza. La XP se acumula en
`PlayerProgression`, que dispara `level_up` cuando se alcanza el umbral de nivel.
El feedback visual incluye un toast "+N XP" (arriba-izquierda del HUD) y un
banner central "¡NIVEL N!" al subir de nivel.

---

## Curva XP por rareza

| Rareza | XP por kill | Justificación orientativa |
|--------|-------------|---------------------------|
| R1 (común) | 10 | ~10 kills = nivel 1→2 (100 XP) |
| R2 (raro) | 25 | ~4 kills = nivel 1→2 |
| R3 (épico) | 60 | ~1.7 kills = nivel 1→2 |
| R4 (boss) | 300 | ~3 bosses = nivel 5→6 (~447 XP gap) |

Una run completa de zona 1 (6 etapas, mix de enemies + 1 boss) entrega
aproximadamente 1000–1100 XP → ≈1 nivel si entrás en nivel 1, ≈0.5 nivel
si entrás en nivel 5. Pendiente validación con `balance-engineer`.

---

## Sin multiplicador de Momentum

Decisión de diseño: el nivel del personaje es **progresión**, no farmeo.
Momentum ya multiplica drops (×2) y Furia generada. Agregar un multiplicador
de XP haría que el speedrun de zona 1 con Momentum alto grindee niveles muy
rápido, rompiendo el pilar #3 ("el ranking premia al que mejora, no al que farmea").

Si en el futuro se quiere agregar: implementar `XP_MOMENTUM_MULT` constante en
`GameConfig` y multiplicar en `ExperienceSystem._on_enemy_died`.

---

## Arquitectura

### Cómo se conecta

```
World._spawn_stage(data)
  └─ por cada enemy:
       ├─ StageManager.register_enemy(enemy)
       ├─ DropSystem.register_enemy(enemy, entry.material_drops)
       └─ ExperienceSystem.register_enemy(enemy, entry.rarity)  ← nuevo

ExperienceSystem._on_enemy_died(enemy)
  └─ PlayerProgression.add_xp(xp)
       └─ xp_gained.emit(amount, total) → XpToastContainer._on_xp_gained()
       └─ level_up.emit(new_level, 1)   → LevelUpBanner._on_level_up()
```

### Archivos creados / modificados

| Archivo | Rol |
|---------|-----|
| `scripts/systems/experience_system.gd` | Autoload. Conecta muerte de enemy con XP al player. |
| `scripts/systems/game_config.gd` | `XP_PER_RARITY` + `xp_for_kill(rarity)` estático. |
| `scripts/world/world.gd` | Llama `ExperienceSystem.register_enemy` en `_spawn_stage`. |
| `scripts/ui/game_over_screen.gd` | `ExperienceSystem.reset()` en retry. PlayerProgression NO se resetea. |
| `scripts/ui/xp_toast.gd` | Toast "+N XP" dorado, slide-in desde izquierda, stacking. |
| `scripts/ui/xp_toast_container.gd` | Gestiona el stack de toasts, escucha `PlayerProgression.xp_gained`. |
| `scripts/ui/level_up_banner.gd` | Banner central "¡NIVEL N!", overshoot + hold + fade, no bloquea input. |
| `scenes/ui/xp_toast.tscn` | Escena del toast individual. |
| `scenes/ui/xp_toast_container.tscn` | Escena del container de toasts. |
| `scenes/ui/level_up_banner.tscn` | Escena del banner de level-up. |
| `scenes/ui/hud_combat.tscn` | Agrega XpToastContainer + LevelUpBanner como hijos. |
| `project.godot` | Registra `ExperienceSystem` como autoload (después de PlayerProgression). |

---

## Decisiones técnicas

### Patrón calcado de DropSystem
`ExperienceSystem` sigue exactamente el mismo patrón de registro que `DropSystem`
(incluyendo los tres bugs-fixes: doble registro, tree_exited sin died, reset en Game Over).
Facilita mantenimiento: si DropSystem evoluciona, ExperienceSystem hace lo mismo.

### XP calculada al registrar, no al morir
`_enemy_xp[enemy] = xp` en `register_enemy` evita que un cambio de rareza en
runtime (edge case: nunca debería pasar) afecte el XP otorgado. Defensivo.

### Toast separado (no reusar MaterialToast)
Separar visual y lógica: el toast de XP stackea por "xp" (clave única) mientras
que el de materiales stackea por id de material. Fusionar complicaría el modelo
de stacking. Código extra mínimo dado que `XpToast` ≈ `MaterialToast` simplificado.

### LevelUpBanner no bloquea input
`mouse_filter = IGNORE` en todos los nodos. `process_mode` default (no ALWAYS).
El banner es feedback cosmético — el combate continúa durante la animación (pilar #4).

---

## Persistencia

`PlayerProgression` NO se resetea al reintentar desde Game Over. Nivel y puntos
de habilidad son datos del personaje, no de la run. Esto es intencional: el
jugador que falla varias veces igual sube de nivel — reduce el castigo del Game Over
y refuerza el pilar #2 ("cada muerte enseña algo") sin bloquear progresión.

Persistencia entre cierres del juego: **pendiente** (SaveSystem no implementado en Fase 3).

---

## Tests

`tests/systems/experience_system_test.gd`:
- `xp_for_kill(R1)` → 10.
- `xp_for_kill(R4)` → 300.
- `xp_for_kill(rareza inválida)` → 0.
- Todas las rarezas (R1–R4) tienen entrada en el dict (ningún valor 0 silencioso).
- Tests de integración documentados (requieren editor con autoloads activos).

---

## Pendientes / TODOs

- [ ] **Balance audit** con `balance-engineer`: validar que la curva de XP no genere niveles
  demasiado rápido o demasiado lento en una run típica de zona 1.
- [ ] **XP por stage cleared**: bonus de XP al completar una etapa (diferente de XP por kill).
  Feature futura — no en MVP de esta iteración.
- [ ] **Persistencia entre cierres del juego**: cuando SaveSystem se implemente, leer/escribir
  `_level`, `_xp`, `_skill_points_available`, `_unlocked_nodes` de PlayerProgression.
- [ ] **XP bonus por Momentum**: si Leo quiere agregar multiplicador futuro, agregar
  `XP_MOMENTUM_MULT` en `GameConfig` y usarlo en `ExperienceSystem._on_enemy_died`.
- [ ] **Sprite/icono real** para el toast de XP (actualmente usa ColorRect dorado como placeholder).
