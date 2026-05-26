# Sistema de Etapas (Stages)

**Fecha de implementación:** 2026-05-24
**Implementado por:** Claude Code (con dirección de Leo)
**Fase del proyecto:** 1
**Sección GDD relevante:** §3 (Mapa), §7 (Enemies), §10 (Boss)
**Pilar(es) reforzado(s):** #2 (Cada muerte enseña algo), #4 (5 minutos bastan)

---

## Qué hace

Reemplaza el spawn "1 partida = N enemies fijos" por una **secuencia de etapas**. Cada etapa es un encuentro PvE con un set de enemies concretos. Cuando el jugador limpia todos los enemies de la etapa, automáticamente avanza a la siguiente — más enemies, más fuertes, distinta rareza, hasta llegar al boss (R4) de la etapa final.

Toda la configuración de etapas es **data-driven** vía `StageData.tres`. Para cambiar una zona/etapa no se toca código: se edita el `.tres`.

## Por qué (pilares)

- **#4 — 5 minutos bastan, 5 horas también.** La etapa 1 es corta (3 melee R1, ~30s). Cada etapa que el jugador supera es un "save point" implícito: cierra una secuencia limpia y siente progreso. Jugadores casuales aprietan 1-2 etapas; los que se quedan, encadenan hasta el boss.
- **#2 — Cada muerte enseña algo.** La progresión por rareza (R1→R2→R3→R4) es legible: el sprite cambia de color y tamaño según rareza, telegraph se alarga, HP se siente. Si te mata un R3, sabés que era una versión "más dura" del mismo arquetipo, no algo aleatorio.

## Cómo se integra

Tres capas:

```
StageData (.tres)        ← datos puros: spawns, nombre, tinte ambiental
       ↓
StageManager (autoload)  ← orquesta progresión, trackea alive_count, emite signals
       ↓
World (scene)            ← spawn físico, cleanup entre etapas, tint ambient
       ↓
StageBanner (UI)         ← muestra "ETAPA N - Nombre" al iniciar cada stage
```

**Flujo runtime:**
1. `World._ready` carga `stages: Array[StageData]` (o cargas defaults de `resources/stages/`).
2. `StageManager.configure(stages)` + `start_run()` → emite `run_started`, `stage_started(stage[0], 0)`.
3. `World._on_stage_started`: limpia enemies anteriores + proyectiles, aplica `ambient_tint`, spawnea los enemies de `stage.spawns`.
4. Por cada enemy spawneado, `StageManager.register_enemy(enemy)` se suscribe a su `HealthComponent.died`.
5. Cuando `_alive_count == 0` → `stage_cleared(idx)` → tras 1.5s, `stage_started(stage[idx+1])` o `run_completed`.
6. `StageBanner` (CanvasLayer) escucha los 3 signals y muestra texto + fade in/out.

**Rareza enemy (`GameConfig.EnemyRarity`):**
- R1: 1.0× HP, 1.0× DMG, sin telegraph extra
- R2: 1.5× HP, 1.3× DMG, +0.0s telegraph, tinte cyan, sprite 1.05×
- R3: 2.5× HP, 1.6× DMG, +0.05s telegraph, tinte violeta, sprite 1.12×
- R4: 4.5× HP, 2.2× DMG, +0.30s telegraph, tinte dorado, sprite 1.45× (boss)

`enemy.gd._ready` lee `enemy_class + rarity` y aplica mults via `GameConfig.enemy_health_with_rarity()` etc.

## Decisiones técnicas no obvias

1. **StageManager como autoload, no como nodo en World.** Sobrevive a reload de scene → futuro respawn/retry no pierde estado. Patrón consistente con MomentumSystem/InventorySystem.

2. **Pausa de 1.5s entre `stage_cleared` y `stage_started` siguiente** (`ADVANCE_DELAY_SECONDS`). Da tiempo a respirar y leer el banner. Sin pausa, el flujo se siente atropellado.

3. **Banner usa `process_mode = ALWAYS`** y NO pausa el juego. Es indicativo, no modal. El combate sigue de fondo durante la transición (aunque no haya enemies vivos en ese momento).

4. **Tween en `_apply_ambient_tint`** (0.6s) para que el cambio de color sea progresivo, no abrupto. Refuerza la sensación de "el ambiente se oscurece" al avanzar.

5. **Boss = enemy R4 con escala 1.45× y telegraph +0.30s.** Es un placeholder visual hasta tener un boss propio (con state machine multifase, fases de HP, escudo con cargas, etc.). Para Fase 1 alcanza para validar el bucle "stage → boss → run completada".

6. **`auto_load_default_stages = true`** en World: si Leo abre `world.tscn` y el array está vacío, carga las 4 stages MVP automáticamente. Evita el caso "abrí el .tscn y no hay enemies".

7. **Playground mode** (stages vacío): fallback al spawn legacy con `GameConfig.TEST_*_COUNT` para iterar 1 stage manual sin tocar `.tres`. Útil para playtest puntual.

## Etapas del MVP (Zona 1)

Archivos en `resources/stages/`:

| Archivo | Display name | Spawns | Total | Rareza | Ambient |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `zona1_etapa_1.tres` | Avanzada de Vanguardia | 3 Melee | 3 | R1 | Neutro |
| `zona1_etapa_2.tres` | Pelotón de Guarnición | 3 Melee + 2 Tank | 5 | R2 | Cyan suave |
| `zona1_etapa_3.tres` | Cacería de Élites | 3 Melee + 3 Tank + 2 Archer + 2 Mage | 10 | R3 | Violeta tenue |
| `zona1_etapa_4.tres` | Guardián de la Maleza | 1 Tank | 1 | R4 (boss) | Dorado/rojo |

## Cómo testear manualmente

1. Abrir Godot, ejecutar `scenes/world.tscn`.
2. Validar: banner "ETAPA 1 / 4 — AVANZADA DE VANGUARDIA" aparece al inicio.
3. Matar los 3 melee R1 → banner "ETAPA COMPLETADA" → tras 1.5s, "ETAPA 2 / 4 — PELOTÓN DE GUARNICIÓN".
4. Validar: en etapa 2, los enemies se ven con tinte cyan, son más resistentes (1.5× HP, 1.3× DMG).
5. Matar los 5 enemies → etapa 3.
6. Validar: 10 enemies R3 violeta. Más lentos de matar.
7. Limpiar etapa 3 → etapa 4 (BOSS).
8. Validar: 1 enemy R4 dorado, MUCHO más grande (sprite 1.45×), telegraph notoriamente más largo.
9. Matarlo → banner "VICTORIA / ZONA COMPLETADA".

**Variar config:** abrir `resources/stages/zona1_etapa_2.tres` en el editor de Godot, cambiar el `count` de la entry, guardar, re-ejecutar. Cambio inmediato sin tocar código.

## Tests unitarios

Pendiente. Sugerido:
- `tests/test_stage_manager.gd` — verifica que `register_enemy` + `died` reduce `alive_count` y emite `stage_cleared` cuando llega a 0.
- `tests/test_rarity_mults.gd` — confirma fórmulas `enemy_health_with_rarity` para los 4 tiers.

## Assets necesarios

Ninguno por ahora — todo es procedural (StickFigure + tint + scale).

A futuro:
- Boss sprite dedicado (no solo un tank R4 escalado).
- SFX de "stage cleared".
- SFX de "boss intro".

## Archivos tocados

**Nuevos:**
- `scripts/data/enemy_spawn_entry.gd` — Resource entry
- `scripts/data/stage_data.gd` — Resource stage
- `scripts/systems/stage_manager.gd` — autoload
- `scripts/ui/stage_banner.gd` — UI banner
- `scenes/ui/stage_banner.tscn`
- `resources/stages/zona1_etapa_1.tres` ... `zona1_etapa_4.tres`
- `docs/features/world/stages_system.md` (este archivo)

**Modificados:**
- `scripts/systems/game_config.gd` — enum EnemyRarity + mults + helpers
- `scripts/entities/enemy.gd` — `@export var rarity`, usa helpers `*_with_rarity`, aplica tint + scale
- `scripts/world/world.gd` — refactor completo a stage-driven
- `scenes/world.tscn` — removido Enemy hardcodeado, agregado StageBanner
- `project.godot` — registrado autoload StageManager

## Pendientes / mejoras futuras

- [ ] Boss real R4 (state machine multifase) en lugar de tank escalado.
- [ ] Drops por etapa: items y materiales según rareza más alta del stage.
- [ ] SFX/música por etapa.
- [ ] Música cambia/sube de intensidad al llegar al boss stage.
- [ ] Banner "GAME OVER" si el player muere durante una stage.
- [ ] Retry / "siguiente intento" al fallar el boss.
- [ ] Stages persisten progreso (savepoint en etapa X).
- [ ] Eco Profundo: stages +20 niveles para zona ya completada (GDD §X).
- [ ] Tests unitarios listados arriba.
- [ ] Confirmar que reload de scene no duplica connects al autoload (StageManager).

---

## Update 2026-05-24 12:50 — Botón START + layouts + visuals

Cambios incrementales tras feedback de Leo del primer playtest:

### Botón START por etapa

- StageManager ahora tiene 2 fases por stage: `stage_pending` (preparada, esperando confirmación) y `stage_started` (combate activo).
- Al recibir `stage_pending`, el World limpia + aplica layout + tint PERO NO spawnea enemies.
- El Banner muestra título + subtítulo + un botón "▶ EMPEZAR ETAPA" gigante (verde, 280×64).
- El jugador puede abrir el inventario, equipar/desequipar, mirar el escenario, y cuando esté listo aprieta START.
- START llama `StageManager.request_combat_start()` → emite `stage_started` → World spawn → banner fade out.

### Layouts distintos por etapa

- Nuevo Resource `StagePlatformConfig` (position, size, color).
- StageData ahora tiene `platform_overrides: Array[StagePlatformConfig]`, `hide_default_platforms: bool`, `show_decorations: bool`.
- World cachea las plataformas default del .tscn al `_ready`. Al cambiar de stage, oculta/muestra y crea/destruye plataformas según el config.
- Layouts MVP:
  - **E1**: defaults (3 plats horizontales).
  - **E2**: 4 plats en zigzag (-450, -100, 250, 560).
  - **E3**: 5 plats dispersas con vertical aumentado (alturas -80 a -280).
  - **E4 (boss)**: arena limpia. `hide_default_platforms=true`, `show_decorations=false`. Sin plataformas, sin árboles, sin luna — solo el boss en su tinte rojo-dorado.

### Visuals de armas

- `StickFigure` ahora tiene `enum WeaponType { NONE, SWORD, BOW, STAFF, HAMMER, SHIELD }`.
- Dos slots: `weapon_main` (mano frontal, sigue swing en ATTACK) y `weapon_off` (mano trasera, típicamente Shield).
- 5 `_draw_<tipo>()` con shapes simples placeholder (espada con guarda, arco con cuerda que se tensa en attack, vara con cristal que crece al castear, martillo con cabezal rectangular grande, escudo ovalado con boss central).
- Player: `_refresh_weapon_visuals()` se conecta a `InventorySystem.equipped_changed`. Al equipar/desequipar arma o escudo, el StickFigure se actualiza.
- Enemy: por clase → `Melee=Sword`, `Tank=Hammer+Shield`, `Archer=Bow`, `Mage=Staff`. Setea en `_ready()`.
- ItemData tiene `@export var visual_type: int` (0-5 según WeaponType). Items existentes actualizados: espada_madera=1, escudo_tablones=5, tunica_aprendiz=0.

### Aura R4

- `enemy.gd._spawn_boss_aura()` crea procedural un GPUParticles2D dorado al `_ready()` si rarity==R4. ~28 partículas, sphere emission radius 22, sube lento (gravity Vector3(0,-25,0)), gradiente dorado → transparente, z_index -1 (detrás del cuerpo).
- Apagada en `_on_died()`.
- Arma escalada 1.4× para R4 → martillo del boss se ve enorme.

### Fix bug hitbox facing player

- Antes: `hitbox.position.x = abs() * current_facing` solo se hacía en `_start_attack()`. Si el jugador giraba sin atacar, la hitbox quedaba del lado del último ataque.
- Ahora: nuevo método `_apply_facing(dir)` en `player.gd` que actualiza sprite + hitbox cada vez que cambia `current_facing`. Llamado desde `_handle_input` y defensivamente desde `_start_attack`.

### Items nuevos para testear rarezas

9 items nuevos en `resources/items/`:

| Item | Slot | Rareza | Stat | Afijos | Visual |
| :--- | :--- | :---: | :---: | :--- | :--- |
| Espada de Hierro | Arma | R2 | 20 | +5HP, +2ATKSPD | Sword |
| Arco Corto | Arma | R2 | 18 | +4HP | Bow |
| Cota de Cuero | Armadura | R2 | 12 | +25HP | — |
| Escudo de Hierro | Escudo | R2 | 10 | +5DEF | Shield |
| Espada Rúnica de Acero | Arma | R3 | 32 | +12HP, +4ATKSPD, +3DEF | Sword |
| Vara de Cristal | Arma | R3 | 30 | +6HP, +3ATKSPD | Staff |
| Coraza de Placas | Armadura | R3 | 24 | +50HP, +5DEF | — |
| Escudo Torre | Escudo | R3 | 18 | +10DEF | Shield |
| Martillo del Guardián | Arma | R4 | 55 | +20HP, +6ATKSPD, +8DEF | Hammer |

Los 12 items (3 R1 + 4 R2 + 4 R3 + 1 R4) se cargan a la mochila al spawn del player. Permite testear todas las visuals + scaling de stats.
