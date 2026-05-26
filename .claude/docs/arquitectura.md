# Arquitectura del Proyecto

Este documento describe **cómo está organizado el código y los datos** de Knights Action. Si vas a tocar algo no trivial, leelo primero.

## Filosofía

- **Composición sobre herencia.** Cada entidad (jugador, enemigo, boss) es un nodo con **componentes** que encapsulan comportamientos reutilizables (`HealthComponent`, `HitboxComponent`, etc.).
- **Datos en Resources, lógica en scripts.** Items, enemigos, skills, zonas: todo se define como `Resource` (`.tres`) en `resources/`. La lógica vive en `.gd`.
- **Sistemas globales son autoloads.** Estado y servicios compartidos (Momentum, Inventario, Coliseo) son singletons registrados en `project.godot`.
- **Señales antes que polling.** Cualquier comunicación inter-nodo se hace por `signal`, no leyendo estado en `_process`.
- **Una responsabilidad por archivo.** Si un script crece >200 líneas o mezcla dos preocupaciones, partilo.

## Capas del proyecto

```
┌──────────────────────────────────────────────────┐
│ UI (HUD, Menús)               ← scripts/ui/      │
├──────────────────────────────────────────────────┤
│ Sistemas globales (autoloads) ← scripts/systems/ │
│   - MomentumSystem                               │
│   - InventorySystem                              │
│   - ProgressionSystem                            │
│   - UpgradeManager                               │
│   - ColiseumService                              │
│   - SaveSystem                                   │
│   - GameState                                    │
├──────────────────────────────────────────────────┤
│ Entidades (player, enemigos, bosses)             │
│   ← scripts/player.gd                            │
│   ← scripts/enemies/                             │
│   ← scripts/bosses/                              │
├──────────────────────────────────────────────────┤
│ Componentes reutilizables                        │
│   ← scripts/components/                          │
│   - HealthComponent                              │
│   - HitboxComponent / HurtboxComponent           │
│   - FuriaComponent / DashComponent / ...         │
├──────────────────────────────────────────────────┤
│ Datos (Resource custom)                          │
│   ← scripts/data/                                │
│   - ItemData, WeaponData, ArmorData, ShieldData  │
│   - EnemyData, BossData                          │
│   - SkillData, SkillNodeData                     │
│   - ZoneData, StageData                          │
│   - EcoData, AIProfile                           │
├──────────────────────────────────────────────────┤
│ .tres en resources/  (instancias concretas)      │
└──────────────────────────────────────────────────┘
```

## Cómo se relacionan

### Ejemplo: el jugador ataca a un enemigo

```
Player.gd
  └─ Input "attack" → start_attack()
     └─ HitboxComponent.enable()
        └─ area_entered signal → toca HurtboxComponent del enemigo
           └─ enemy.HealthComponent.take_damage(N)
              ├─ health_changed.emit(...)  → HUD se actualiza
              └─ MomentumSystem.on_hit_landed()
                 ├─ momentum_changed.emit(...) → HUD se actualiza
                 └─ FuriaComponent.add(10 * momentum_multiplier())
```

Todo conectado por señales. Nada de un componente lee directamente otro componente — siempre vía señal o vía interface pública.

### Ejemplo: el jugador refina un item

```
UI Refinement menu
  └─ usuario tap "Refinar"
     └─ UpgradeManager.attempt_upgrade(item, use_scroll)
        ├─ consume_materials() (InventorySystem)
        ├─ randf() vs SUCCESS_TABLE[target_level]
        ├─ éxito: item.refinement_level += 1
        ├─ fallo +8/+9/+10 sin scroll: refinement_level -= 1
        ├─ upgrade_succeeded.emit / upgrade_failed.emit
        └─ UI escucha señal y muestra resultado animado
```

## Reglas duras

### Para nuevos componentes
1. Heredan de `Node` o `Node2D`.
2. Exponen su API por funciones públicas + señales.
3. **No leen el padre directamente** (no `get_parent().something`).
4. Pueden tener `@export` de parámetros configurables (max_health, daño, etc.).
5. Si necesitan referencia a otro componente del mismo nodo, se la pasa el padre al inicializar (inyección).

### Para nuevos sistemas (autoloads)
1. Heredan de `Node`.
2. Registrados en `project.godot` bajo `[autoload]`.
3. Globales, accesibles desde cualquier script por su nombre (`MomentumSystem.something`).
4. Emiten señales para cambios de estado.
5. **No tienen estado mutable expuesto sin getter** — siempre encapsular.

### Para nuevos Resources
1. Heredan de `Resource` con `class_name`.
2. Todos los campos son `@export` con tipo fuerte.
3. Sin métodos con lógica de juego — son solo datos. Si necesitás lógica, ponela en un sistema o en una entidad que use el resource.
4. Archivos `.tres` van en `resources/<categoría>/`.

### Para escenas (`.tscn`)
1. Una escena por entidad principal (player, enemigo, boss).
2. Una escena por nivel de UI (cada menú es su escena).
3. Etapas PvE son escenas separadas dentro de `scenes/zones/<zona>/`.
4. **No metas lógica de juego en `script` de la escena raíz si puede ir en un componente.**

## Convenciones de comunicación

| Necesidad | Mecanismo |
| :--- | :--- |
| Componente A debe avisar a B en el mismo nodo | señal emitida por A, conectada por el padre al método de B |
| Componente de un nodo debe avisar al sistema global | señal del componente → autoload escucha (vía padre o suscripción directa al `_ready`) |
| Sistema global debe avisar a UI | señal del autoload → HUD se conecta en `_ready` |
| UI debe pedir acción al sistema | llamada directa al autoload (`UpgradeManager.attempt_upgrade(...)`) |

## Patrón: State Machine de enemigos / bosses

Sin plugin. Cada estado es una clase que extiende `RefCounted` con métodos `enter()`, `process(delta)`, `exit()`. La entidad mantiene un `current_state` y delega `_physics_process` a él. Ver detalle en [`.claude/agents/enemy-ai.md`](.claude/agents/enemy-ai.md) y [`.claude/agents/boss-designer.md`](.claude/agents/boss-designer.md).

## Anti-patrones del proyecto

- ❌ `get_node("../../Sibling/Child")` — frágil.
- ❌ Lógica de combate en script de UI.
- ❌ `_process` con trabajo pesado.
- ❌ Hardcodear stats de items en `.gd`.
- ❌ Mezclar concerns: un script "manager" que hace 5 cosas.
- ❌ Plugin del lado de plataforma específica (no portable a Android).

## Estado actual

A día 21/05/2026:
- `scripts/player.gd` (CharacterBody2D) tiene lógica monolítica de movimiento, dash, ataque, furia. **Refactor candidato** cuando empiece a meterse Momentum y Bloqueo — extraer a componentes.
- `scripts/components/health_component.gd` es el primer componente. Sirve de patrón.
- No hay autoloads aún. Primer autoload natural: `MomentumSystem` cuando se implemente.

## Cuando ampliés esta arquitectura

Documentá el cambio en `docs/features/architecture/<nombre>.md` y actualizá este archivo si introducís una capa o regla nueva.
