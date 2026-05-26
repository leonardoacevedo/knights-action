# resources/

**Datos del juego en formato `.tres`.** Instancias concretas de las clases definidas en `scripts/data/`.

## Filosofía

Toda definición de item, enemigo, boss, skill, zona, etc. vive acá como `.tres`. Es lo que diferencia "datos" (versionables, editables sin tocar código) de "lógica" (código en `scripts/`).

## Organización

```
resources/
├── items/
│   ├── weapons/
│   │   ├── axe_of_valley.tres
│   │   ├── filo_susurrante.tres
│   │   └── ...
│   ├── armors/
│   ├── shields/
│   ├── affixes/                     # pool de afijos que rolean al craftear.
│   │   ├── crit_chance.tres
│   │   ├── hp_flat.tres
│   │   └── ...
│   └── materials/
│       ├── valle_de_los_ecos/
│       │   ├── madera_ancestral.tres
│       │   ├── colmillos_duros.tres
│       │   └── nucleos_de_tierra.tres
│       └── ...
│
├── enemies/
│   └── valle_de_los_ecos/
│       ├── wood_spirit.tres         # R1.
│       ├── bark_warrior.tres        # R2.
│       └── thorn_shaman.tres        # R3.
│
├── bosses/
│   └── valle_de_los_ecos/
│       └── guardian_maleza.tres     # R4.
│
├── skills/
│   ├── warrior/
│   │   ├── slash.tres
│   │   └── ...
│   ├── mage/
│   └── agile/
│
└── zones/
    ├── valle_de_los_ecos.tres
    └── ...
```

## Convenciones

- **Naming:** `snake_case`.
- **Una zona = una carpeta** en `enemies/`, `bosses/`, `materials/`.
- **Sub-resources embebidos** OK pero preferir referencias a `.tres` separados cuando se reusan.
- **No editar `.tres` a mano** salvo correcciones triviales — usar Godot Editor.

## Cómo crear un `.tres` nuevo

1. Abrir Godot Editor.
2. Navegar a la carpeta destino en el FileSystem panel.
3. Botón derecho → "Create New" → "Resource".
4. Buscar la clase de datos (ej. `WeaponData`).
5. Editar campos en el Inspector.
6. Guardar con nombre `snake_case`.

O programáticamente, ver `scripts/data/README.md`.

## Si una clase de `scripts/data/` cambia

- Agregar nuevo campo con default razonable → Godot completa los `.tres` viejos automáticamente.
- Renombrar / eliminar campo → puede perder data. Validar antes de guardar.

## Anti-patrones

- ❌ `.tres` con valores inventados sin pasar por `balance-engineer` cuando se trata de stats core.
- ❌ Carpetas vacías "para el futuro".
- ❌ Nombres en inglés cuando el item tiene nombre español ("frosty_sword.tres" → "espada_helada.tres").
- ❌ Duplicar `.tres` cuando dos items comparten 90% — usar herencia de Resource o composición.

## Linkeo con docs

Por cada `.tres` significativo (item destacado, boss, zona completa), debe haber una entrada en `docs/features/`.

Por ejemplo:
- `resources/bosses/valle_de_los_ecos/guardian_maleza.tres` ↔ `docs/features/bosses/guardian_maleza.md`.
