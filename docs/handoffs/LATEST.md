> **Origen:** [2026-05-26-noche.md](2026-05-26-noche.md) · 26 May 2026 noche (Fase 3 progreso).

# Handoff — 26 May 2026, sesión noche (Fase 3 progreso)

**Fase:** 3 — Sistemas RPG Completos (en progreso, ~50% del scope).

## 🎯 ARRANCAR PRÓXIMA SESIÓN

Juego debería cargar limpio tras 2 hotfixes. Próxima feature recomendada: **Set Bonuses** o **Sistema Oro real**.

**Primer paso:**
1. Abrir Godot, correr proyecto.
2. Probar XP-on-kill: matar enemies → toast "+N XP" top-left → nivel sube → banner central → árbol skills tiene punto nuevo.
3. Reportar feel.

## Lo hecho esta sesión

### Hotfixes apertura
- `PlayerProgression.get_tree()` chocaba con `Node.get_tree()` → renombrado a `get_skill_tree()`.
- `skill_tree_screen.gd` inferencia de tipo Array falla → tipar `Array[Color]` explícito.

### T33 — XP-on-kill completo
- `GameConfig.xp_for_kill(rarity)` — R1=10, R2=25, R3=60, R4=300.
- `ExperienceSystem` autoload con patrón DropSystem.
- `XpToast` dorado top-left con stacking + `LevelUpBanner` central con overshoot.
- Progresión PERSISTE entre Game Over (es del personaje, no run-specific).
- NO multiplica XP por Momentum (decisión: nivel = progresión, no farmeo).
- 8 tests.

## Estado Fase 3

```
✅ Zona 1 completa (6 stages)
✅ Sistema Elementos (backend + asignación zona 1)
✅ Árbol de Skills (backend 30 nodos + UI)
✅ XP-on-kill (toast + banner + persistencia)

⏹ Set Bonuses (2pc/3pc afinidad)
⏹ Sistema Oro real (placeholder=0 en refinamiento/crafteo/respec)
⏹ Pool R3 armor/escudo
⏹ Arte IA + sprites + parallax
⏹ Audio pipeline
⏹ Momentum HUD final
```

## Brechas conocidas

- **6 capstones del árbol con TODO:** invisibilidad post-dash, bonus post-bloqueo temporal, regen Furia/s, BLOCK_CHARGES +1 escudo, Furia por nivel, varios stats no cableados (MOVE_SPEED_PCT, DASH_COOLDOWN_PCT, IFRAMES_PCT, EVADE_PCT, ELEMENTAL_DAMAGE_PCT).
- **Armaduras/escudos sin element útil:** `player.hurtbox.element` no se conecta a armadura.
- **Persistencia entre cierres:** sin SaveSystem, todo se pierde al cerrar Godot.

## Sugerencias vivas (no urgentes — ver `docs/sugerencias.md`)

1. Cap 1.0 drops → bonus count overflow (decisión Leo).
2. HURT state sin uso en enemy.gd (decisión Leo: implementar i-frames o limpiar).
3. `StageManager.reset()` no resetea `_is_pending` (1 línea, bajo riesgo).
4. Drop tables por enemy específico (no solo por rareza).
5. Object pool material toast (solo si stutter mobile).
6. Sprites diferenciados por rareza (Fase 5).
7. SFX por evento (Fase 5).

## Lecciones canon vigentes

- `duplicate(true)` para items dropeados.
- `EnemyBlockHandler` cargas reales > miss-shield.
- Triángulo elemental se calcula en el atacante.
- Stats = Base + Equipo + Skills + Set.
- Edit pierde tabs → PowerShell `[char]9`.
- Lección ambient_tint: verificar exports antes/después de tocar Resources.
- **Nunca pisar APIs nativas de Node** (`get_tree`, `get_parent`, etc).
- **Tipar arrays con literales** (`var x: Array[T] = [...]`).
- **XP NO multiplica por Momentum** (nivel = progresión, no farmeo).
- **Progresión persiste entre runs** (no resetea al Game Over).

## Memoria vigente

- `feedback_priorizar_fase_3.md` → cerrar Fase 3 antes de Coliseo (Fase 4).
- `feedback_delegar_a_subagentes.md` → Regla 6 vigente.

Doc completo en `2026-05-26-noche.md`.
