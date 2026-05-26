# Estructura de Carpetas — Mapa Completo

Este es el mapa de referencia. Si creás una carpeta nueva, actualizá este archivo.

```
knights-action/
│
├── CLAUDE.md                        # ★ Entry point para Claude. Leer primero.
├── GDD.md                           # ★ Source of truth de diseño (v2.1).
├── README.md                        # (futuro) — README público del proyecto.
│
├── project.godot                    # Config Godot 4.6.
├── icon.svg                         # Ícono del proyecto.
├── icon.svg.import                  # Auto-generado.
├── .editorconfig                    # Coding style cross-editor.
├── .gitattributes
├── .gitignore
├── .godot/                          # Auto-generado por Godot.
│
├── .claude/                         # ★ Config y context para Claude Code.
│   ├── settings.json                # Permisos, env vars, etc.
│   ├── agents/                      # 14 subagentes especializados (.md).
│   │   ├── game-designer.md
│   │   ├── godot-expert.md
│   │   ├── combat-system.md
│   │   ├── equipment-system.md
│   │   ├── progression-system.md
│   │   ├── enemy-ai.md
│   │   ├── boss-designer.md
│   │   ├── ecos-coliseum.md
│   │   ├── balance-engineer.md
│   │   ├── level-designer.md
│   │   ├── ux-mobile.md
│   │   ├── art-prompt-engineer.md
│   │   ├── narrative-lore.md
│   │   └── backend-architect.md
│   ├── commands/                    # 11 slash commands del proyecto (.md).
│   │   ├── feature.md
│   │   ├── design-item.md
│   │   ├── design-enemy.md
│   │   ├── design-boss.md
│   │   ├── design-skill.md
│   │   ├── balance-check.md
│   │   ├── pillar-check.md
│   │   ├── status.md
│   │   ├── new-zone.md
│   │   ├── playtest-log.md
│   │   └── genera-resumen.md        # ★ Handoff al cerrar sesión.
│   └── docs/                        # Docs auxiliares de diseño y dev.
│       ├── reglas-de-trabajo.md     # ★ 6 reglas operativas de Leo (incluye caveman).
│       ├── estilo-caveman.md        # ★ Modo de comunicación default (caveman full/lite).
│       ├── pilares.md
│       ├── arquitectura.md
│       ├── convenciones-gdscript.md
│       ├── glossary.md
│       ├── formulas.md
│       ├── fases.md
│       └── estructura-carpetas.md   # (este archivo).
│
├── docs/                            # Documentación del proyecto.
│   ├── features/                    # ★ Una entrada por feature implementada.
│   │   ├── README.md                # Template + convenciones.
│   │   ├── combat/                  # (al implementar) features de combate.
│   │   ├── equipment/               # (al implementar) features de equipo.
│   │   ├── enemies/
│   │   ├── bosses/
│   │   ├── zones/
│   │   ├── coliseum/
│   │   ├── ui/
│   │   └── architecture/
│   ├── handoffs/                    # ★ Resúmenes entre sesiones.
│   │   ├── README.md                # Convenciones del sistema de handoff.
│   │   ├── LATEST.md                # ★★ Entrypoint para cada nueva sesión.
│   │   └── YYYY-MM-DD-HHMM.md       # Histórico inmutable (uno por /genera-resumen).
│   ├── playtest/                    # (al hacer playtest) feedback logged.
│   └── art/                         # (al generar arte) palettes, prompts.
│
├── scripts/                         # ★ Toda la lógica GDScript.
│   ├── player.gd                    # Player CharacterBody2D.
│   ├── player.gd.uid
│   ├── components/                  # ★ Componentes reutilizables.
│   │   ├── README.md                # (futuro) — patrón de componentes.
│   │   ├── health_component.gd      # ✅ implementado.
│   │   ├── health_component.gd.uid
│   │   └── ...                      # (futuros) hitbox_component, dash_component, etc.
│   ├── systems/                     # ★ Autoloads / singletons.
│   │   ├── README.md
│   │   └── ...                      # (futuros) momentum_system.gd, etc.
│   ├── data/                        # Custom Resource subclasses.
│   │   ├── README.md
│   │   └── ...                      # (futuros) item_data.gd, enemy_data.gd, etc.
│   ├── enemies/                     # (futuro) lógica de enemigos R1-R3.
│   │   ├── enemy_base.gd
│   │   ├── states/
│   │   └── species/
│   ├── bosses/                      # (futuro) lógica de bosses R4.
│   │   ├── boss_base.gd
│   │   ├── patterns/
│   │   └── species/
│   ├── skills/                      # (futuro) lógica de skills equipables.
│   ├── ai/                          # (futuro, Fase 4) Perfiles IA del Coliseo.
│   │   └── profiles/
│   └── ui/                          # (futuro) lógica de HUD y menús.
│       ├── hud/
│       ├── menus/
│       └── controls/
│
├── scenes/                          # ★ Escenas .tscn.
│   ├── world.tscn                   # Escena raíz de prueba (Fase 1).
│   ├── player/
│   │   └── player.tscn
│   ├── enemies/                     # Por zona.
│   │   ├── enemy_dummy.tscn         # Fase 1 placeholder.
│   │   ├── enemy_dummy.gd
│   │   ├── enemy_dummy.gd.uid
│   │   └── valle_de_los_ecos/       # (futuro) sprites del Valle.
│   ├── bosses/                      # (futuro) escenas de bosses.
│   ├── zones/                       # (futuro) escenas de etapas por zona.
│   │   └── valle_de_los_ecos/
│   │       ├── stage_01.tscn
│   │       ├── stage_02.tscn
│   │       └── ...
│   ├── coliseum/                    # (futuro, Fase 4) escenas del Coliseo.
│   └── ui/                          # (futuro) escenas de UI.
│       ├── hud/
│       └── menus/
│
├── resources/                       # ★ Resources .tres = datos del juego.
│   ├── README.md
│   ├── items/                       # (futuro).
│   │   ├── weapons/
│   │   ├── armors/
│   │   ├── shields/
│   │   ├── affixes/
│   │   └── materials/
│   ├── enemies/                     # (futuro) por zona.
│   │   └── valle_de_los_ecos/
│   ├── bosses/                      # (futuro) por zona.
│   │   └── valle_de_los_ecos/
│   ├── skills/                      # (futuro) por rama.
│   │   ├── warrior/
│   │   ├── mage/
│   │   └── agile/
│   └── zones/                       # (futuro).
│       └── valle_de_los_ecos.tres
│
├── tests/                           # ★ Tests unitarios + simulaciones.
│   ├── README.md
│   ├── sims/                        # (futuro) scripts de simulación de balance.
│   ├── components/                  # (futuro) tests de componentes.
│   ├── systems/                     # (futuro) tests de sistemas (UpgradeManager, etc.).
│   ├── enemies/
│   └── bosses/
│
└── assets/                          # (futuro, Fase 2+) Sprites, audio, fonts.
    ├── sprites/
    │   ├── player/
    │   ├── enemies/
    │   ├── bosses/
    │   ├── items/
    │   └── ui/
    ├── backgrounds/
    │   └── valle_de_los_ecos/       # 3-5 capas parallax.
    ├── audio/
    │   ├── music/
    │   └── sfx/
    └── fonts/
```

## Convenciones de naming en filesystem

- **Carpetas:** `snake_case` o `kebab-case` (consistente por carpeta padre).
- **Archivos `.gd` / `.tscn` / `.tres`:** siempre `snake_case`.
- **Archivos `.md` de docs:** `snake_case`.
- **Sprites / assets:** `tipo_nombre_variante_resolucion.ext` (ej. `enemy_wood_spirit_idle_512.png`).

## Cuándo creás una carpeta nueva

1. Solo si ya tenés ≥3 archivos relacionados que justifiquen agrupar.
2. Agregá `README.md` con 1-3 frases explicando qué va ahí.
3. Actualizá este mapa.

## Cuándo NO creás una carpeta

- Si solo hay 1-2 archivos del tipo (vivan en la raíz de la categoría).
- Por anticiparse a futuro ("voy a crear `scripts/future/`"). Crear al necesitar.
- Para separar por etapa de desarrollo (carpetas tipo `tmp/`, `wip/`).

## Marcado de carpetas ★

Las marcadas con ★ son las que vas a tocar 80% del tiempo:
- `CLAUDE.md`, `GDD.md`.
- `.claude/` (todo).
- `scripts/{components,systems,data}/`.
- `scenes/`.
- `resources/`.
- `docs/features/`.
- `tests/`.
