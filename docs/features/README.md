# docs/features/

Una entrada Markdown por **feature implementada**. Es la **documentación viva** que pide el §12.1 del GDD.

## Cuándo escribir una entrada

Cada vez que:
- Se implementa una feature del GDD (ej. Momentum, Refinamiento, Coliseo).
- Se diseña un item, enemigo, boss, zona o skill nueva.
- Se introduce un patrón de arquitectura nuevo.
- Se toma una decisión técnica no obvia que hay que recordar.

## Organización

```
docs/features/
├── README.md                        # (este archivo).
├── combat/                          # sistemas de combate.
│   ├── momentum.md
│   ├── furia_decay.md
│   └── ...
├── equipment/
│   ├── refinement.md
│   ├── set_bonuses.md
│   └── ...
├── items/                           # items individuales.
│   ├── weapons/
│   ├── armors/
│   └── shields/
├── enemies/                         # mobs R1-R3.
│   └── valle_de_los_ecos/
│       ├── wood_spirit.md
│       └── ...
├── bosses/                          # bosses R4.
│   └── valle_de_los_ecos/
│       └── guardian_maleza.md
├── zones/
│   └── valle_de_los_ecos.md
├── skills/
│   ├── warrior/
│   ├── mage/
│   └── agile/
├── coliseum/
│   ├── eco_upload.md
│   ├── glory_system.md
│   └── ...
├── ui/
│   ├── refinement_menu.md
│   └── ...
└── architecture/                    # decisiones de arquitectura.
    ├── state_machine_pattern.md
    └── ...
```

## Template — feature genérica

```markdown
# <Nombre de la feature>

**Fecha de implementación:** YYYY-MM-DD
**Implementado por:** Claude Code (con dirección de Leo)
**Fase del proyecto:** <1-5>
**Sección GDD relevante:** §<X.Y>
**Pilar(es) reforzado(s):** #1 / #2 / #3 / #4

---

## Qué hace

<2-4 frases. Explicación accionable para alguien que abre este archivo en frío.>

## Por qué (pilares)

<Conexión con uno o más de los 4 pilares. Cita el pilar y explica cómo esta feature lo refuerza.>

## Cómo se integra

<Diagrama o descripción de cómo encaja con sistemas existentes. Qué autoloads usa, qué señales emite/escucha, qué componentes interviene.>

## Decisiones técnicas no obvias

<Cualquier "por qué hice X en vez de Y" que un colaborador no entendería leyendo solo el código.>

## Cómo testear manualmente

<Pasos concretos para que Leo (o un tester) valide la feature en Godot Editor o build mobile.>

## Tests unitarios

<Lista de archivos en `tests/` con qué cubren.>

## Assets necesarios (si aplica)

<Sprites, audio, fonts pendientes — delegar a `art-prompt-engineer` si arte.>

## Archivos tocados

- `scripts/...`
- `resources/...`
- `scenes/...`

## Pendientes / mejoras futuras

<TODO list si la feature quedó "v1" con cosas por iterar.>
```

## Template — diseño de item

```markdown
# <Nombre del item>

**Slot:** Arma / Armadura / Escudo
**Rareza:** R<1-3>
**Elemento:** Tierra / Fuego / Agua
**Zona origen:** <zona>
**Diseñado:** YYYY-MM-DD

## Stats

- Daño base / Defensa base: X
- Cargas de escudo: X (si escudo)
- Afijos posibles al craftear: <lista>
- Efecto especial (R3 only): <descripción>

## Receta de crafteo

- X de <material>
- Y oro

## Lore (1 línea)

> "<flavor>"

## Prompt de arte usado

```
<prompt completo>
```

## Notas de balance

- DPS comparativo vs tier: <%>
- Aprobado por `balance-engineer`: SÍ / NO + fecha.
```

## Template — diseño de enemigo

```markdown
# <Nombre del enemigo>

**Especie:** <nombre>
**Rareza:** R<1-3>
**Zona:** <zona>
**Rango de nivel:** N-M
**Diseñado:** YYYY-MM-DD

## Stats

- HP: X
- Daño base: X
- Defensa: X
- Resistencias: <elementos>

## Comportamiento

<Resumen del state machine. Estados principales y triggers.>

## Ataques y telegrafías

| Ataque | Windup | Daño | Cooldown | Tell visual / audio |
| :--- | :---: | :---: | :---: | :--- |
| ... | ... | ... | ... | ... |

## Contra-estrategia

<Qué debe hacer el jugador para ganar eficientemente. Pista para futuro Bestiario tier 3.>

## Drops

- <material 1>: X% chance, cantidad N
- ...

## Lore (Bestiario)

- Tier 1 (10 kills): "<frase 1>"
- Tier 2 (50 kills): "<frase 2>"
- Tier 3 (100 kills): "<frase 3 con hint>"

## Prompt de arte

```
<prompt completo>
```
```

## Reglas

1. **Un archivo por feature**, no mezclar varias.
2. **Markdown estándar.** Sin HTML salvo necesidad real.
3. **Fechas en formato ISO** (YYYY-MM-DD).
4. **Linkear al GDD** por sección (§X.Y), no por número de página.
5. **Actualizar** si la feature cambia significativamente; **no borrar** el archivo (queda histórico).
6. **Si una feature se descarta** post-implementación: mover a `docs/features/archived/` con nota de por qué.
