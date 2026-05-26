# Glosario de Knights Action

Términos del juego, definidos. Es **canon**. Si introducís un término nuevo, agregalo acá.

---

## Recursos del jugador

### Furia
Recurso para usar Skills. Sustituye al "Maná" tradicional.
- **Capacidad máxima:** 100 (modificable por equipo y skills).
- **Generación:** +10 por cada Ataque Básico que conecte.
- **NO regenera pasivamente.**
- **Decay:** si no atacás durante 5s, perdés 5 Furia/s.

GDD §4.3.

### HP
Vida del personaje. Aumenta con nivel y con stat de armadura.

### Momentum
Multiplicador de combate (1x → 10x).
- **+1** por cada golpe conectado (ataque básico o skill).
- **Resetea a 0** al recibir daño **físico**.
- Bloquear **congela** Momentum 1 segundo (no resetea).
- Aplica a:
  - Daño: `× (1 + 0.05 * mom)` → +50% en 10x.
  - Drops: `× (1 + 0.1 * mom)` → +100% en 10x.
  - Furia ganada: `× (1 + 0.05 * mom)`.

GDD §4.3 (sistema CORE).

---

## Equipamiento

### Slots
Tres slots por personaje:
- **Arma:** daño físico/elemental base.
- **Armadura:** defensa base + resistencia/afinidad elemental.
- **Escudo:** cargas de bloqueo + stats pasivos.

### Rarezas
| Rareza | Tier | Afijos | Cargas escudo |
| :--- | :--- | :--- | :--- |
| Común | R1 | 1 | 0 |
| Raro | R2 | 2 | 1 |
| Épico | R3 | 3 | 2 |
| Legendario | R4 | 3 | 3 (excluido del MVP) |

GDD §5.2.

### Afijo (Stat Secundaria)
Stat adicional rolled aleatoriamente al craftear. Cantidad depende de rareza (R1=1, R2=2, R3=3).

### Refinamiento
Sistema de mejora de +1 a +10 sobre un item.
- **Fórmula:** `Stat Final = Stat Base * (1 + 0.05 * nivel_refinamiento)`.
- Probabilidad de éxito decreciente: 100% en +1/+2/+3, 70% en +4/+5, 50% en +6/+7, 30/20/10% en +8/+9/+10.
- Fallo en +4 a +7 = pérdida de materiales.
- Fallo en +8/+9/+10 = **-1 Nivel de Refinamiento** (salvo Pergamino).

GDD §5.6.

### Piedras de Resonancia
Material universal de refinamiento. Se consume en cada intento de mejora (+1 a +10). Su propiedad resonante permite que el filo, el temple o el peso de un item se reajuste a un estado superior sin refundirlo. Rareza R1 (común). Implementada como `resources/materials/piedra_resonancia.tres`.

### Pergamino de Protección
Consumible (drop de Ligas Altas — Coliseo, Fase 4). En +8/+9/+10, evita la pérdida de nivel si fallás. Los materiales base (Piedra + Oro) se consumen igualmente. Rareza R3 (épico). Implementado como `resources/materials/pergamino_proteccion.tres`. No tiene drop table activa todavía.

### Fusión
Combinar 3 piezas R(n) del mismo tipo → 1 pieza R(n+1) con stats aleatorias.

### Afinidad de Equipo (Set Bonus)
- **2pc mismo elemento:** bonus pasivo (ej. +15% resistencia al opuesto).
- **3pc mismo elemento:** habilidad pasiva única.

GDD §5.4.

---

## Elementos

### Triángulo elemental MVP
- Fuego > Tierra
- Tierra > Agua
- Agua > Fuego

Daño con **ventaja**: ×1.5. Daño con **desventaja**: ×0.66.

Post-launch: Viento, Rayo, Sombra.

---

## Progresión

### Nivel del personaje
Cap MVP: **30**. Por subir nivel: 1 punto de skill + leve HP/Furia.

### XP
Curva: `xp_requerida = 100 * nivel^1.5`.

### Punto de Skill
Moneda del árbol de habilidades. 1 punto por level-up. Total disponibles MVP: 30 (uno por nivel).

### Árbol de Habilidades
Tres ramas no exclusivas: **Guerrero, Mago, Ágil**. ~30 nodos en total.

### Respec
Resetear el árbol de skills y recuperar todos los puntos. Costo: oro + materiales comunes. **Nunca dinero real.**

---

## Combate

### Ataque Básico
Acción principal. Genera Furia y suma Momentum.

### Dash
Desplazamiento de ~100ms con 6 frames de invulnerabilidad. Cooldown ~0.8s.

### Bloqueo
Mantener el botón. Consume cargas del escudo equipado. Congela Momentum 1s. No resetea.

### Telegrafía
Ventana visual + sonora que precede a un ataque enemigo. Obligatoria para todo daño grave:
- R1: ≥0.6s.
- R2: ≥0.5s ataques pesados.
- R3: ≥0.4s mínimo.
- R4 (Boss): 0.5-1.0s, obligatoria por patrón pesado.

### Hitstop
Freeze frame al conectar un golpe. 30-80 ms según peso. Da sensación de impacto.

### i-Frames
Frames de invulnerabilidad. El Dash tiene 6 a 60fps (~100ms).

---

## Zonas y Niveles

### Zona
Unidad mayor de contenido PvE: 5-8 etapas + 1 boss + elemento dominante + materiales únicos.

### Etapa
Sección de una zona, 2-5 min de juego. Encuentros + checkpoint opcional.

### Eco Profundo
Modo desbloqueado tras completar una zona. Enemigos +20 niveles, IA agresiva, drops exclusivos.

### Boss
Enemigo R4 que cierra una zona. "Espejo del jugador" con telegrafía obligatoria, fases y patrones complejos.

---

## Meta-juego (Coliseo)

### Coliseo
Meta-juego competitivo asincrónico. Desbloqueado al **nivel 10**.

### Eco
Copia controlada por IA de un personaje real de otro jugador. Lo que peleás en el Coliseo. **No es un bot anónimo** — es un alma atrapada (lore §8.2).

### Gloria
Puntaje del ranking del Coliseo.
- Punto de partida: 1000.
- Victoria: +25 a +50.
- Derrota: -15 a -30.
- Temporadas mensuales con top.

### Perfil IA
Uno de 4 comportamientos asignados a tu Eco al subirlo: **Agresivo, Defensivo, Equilibrado, Caster**. Se infiere de tu telemetría de últimas 10 batallas. Tu **build** sí es 100% tuya.

### Liberar (un Eco)
Vocabulario narrativo: ganar una batalla en el Coliseo equivale a "liberar" al Eco, no a "matarlo".

---

## Sistemas de Engagement

### Misión Diaria
3 misiones que rotan cada 24h. Recompensas: materiales raros, oro.

### Bestiario
Registro de especies derrotadas. Bonus permanente pequeño contra esa especie por kills (10/50/100).

---

## Materiales (MVP — Valle de los Ecos)

### Hierba Antigua
Crece entre grietas de piedra labrada que ya nadie recuerda haber tallado. Su tallo resiste más que la roca bajo sus raíces. Material común (R1) del Valle. Dropea de cualquier enemy. Implementada como `resources/materials/hierba_antigua.tres`.

### Savia Resonante
La sangre lenta de los árboles que sobrevivieron al derrumbe. Condensa siglos en cada gota. Material raro (R2) del Valle. Dropea de enemies R2+. Implementada como `resources/materials/savia_resonante.tres`.

### Esencia del Verdor
Lo que queda cuando el Valle concentra su voluntad en un solo punto. Los guerreros que la portan dicen escuchar algo, pero no pueden explicar qué. Material épico (R3) del Valle. Dropea principalmente de enemies R3 y del boss. Implementada como `resources/materials/esencia_verdor.tres`.

### Lore preexistente (no implementados)
Las entradas Madera Ancestral, Colmillos Duros y Núcleos de Tierra mencionadas en versiones anteriores del glosario son lore canónico pero **no están implementadas como `.tres`** todavía. Se incorporarán cuando se diseñen enemies específicos del Valle con drops únicos (sugerencia en `docs/sugerencias.md` — "Drop tables por enemy específico").

(Materiales de zonas futuras se agregarán al diseñarse.)

---

## Sistemas técnicos

### Resource
Tipo de Godot. En este proyecto, todo dato persistente del juego (item, enemigo, skill, zona) hereda de `Resource` y se guarda como `.tres`.

### Component
Patrón del proyecto: `Node`/`Node2D` que encapsula una responsabilidad reutilizable. Ej. `HealthComponent`, `HitboxComponent`.

### Autoload (Singleton)
Nodo registrado globalmente en `project.godot`. Estado y servicios compartidos.

### State Machine
Patrón usado en IA de enemigos y bosses. Cada estado es una clase con `enter`, `process`, `exit`.

---

## Reglas de extensión

Cuando agregás un término nuevo:
1. Definilo acá con 1-3 frases.
2. Si tiene fórmula, agregala a [`formulas.md`](formulas.md).
3. Si es feature implementada, agregá link a `docs/features/<nombre>.md`.
4. **Una sola definición canon.** Si querés cambiar el significado de un término existente, **modificá la entrada y avisá explícitamente** — no dupliques.
