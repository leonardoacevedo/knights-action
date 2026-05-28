# Knights Action — Documento de Diseño de Juego v2.2

**Proyecto:** Knights Action (Nombre en clave)
**Autor:** Leonardo (Leo) — Director Creativo
**Pipeline de Desarrollo:** AI-First (Claude Code / Cowork para programación, IA generativa para arte)
**Fecha:** 28 de Mayo de 2026 (v2.2 — sync 6 elementos canon)
**Estado:** Pre-producción / Fase 3 en desarrollo

---

## 0. Sobre este documento

Este GDD está escrito para ser leído **tanto por humanos como por IA**. El autor desarrolla solo, dirigiendo a Claude Code (programación) y herramientas de IA generativa (arte, audio, animación). Por eso, cada sección incluye especificaciones técnicas suficientemente concretas para que una IA pueda ejecutarlas sin ambigüedad.

**Regla del documento:** si una sección no puede ser entendida por Claude Code como una instrucción ejecutable, está mal escrita y hay que reescribirla.

---

## 1. Pilares de Diseño

Decisiones no negociables. Cualquier feature futura debe reforzar al menos uno; si contradice uno, se descarta.

1. **Mi build importa, mi skill también.** Ni puro loot, ni puro reflejos. La intersección.
2. **Cada muerte enseña algo.** Nada debe sentirse aleatorio o injusto.
3. **El ranking premia al que mejora, no al que farmea.** El tiempo invertido cuenta menos que la habilidad.
4. **5 minutos bastan, 5 horas también.** Sesiones cortas con profundidad opcional.

---

## 2. Resumen del Proyecto

- **Género:** Action-RPG / Plataformas 2D Side-Scroller con meta-juego competitivo asincrónico.
- **Plataforma Objetivo:** Móvil (iOS/Android). Desarrollo y testing en PC con Godot.
- **Motor:** Godot Engine 4.x (GDScript).
- **Estilo Visual:** Arte 2D vectorial, paleta saturada pero limpia. Referencias estéticas: *Dead Cells*, *Knights & Dragons*, *Hollow Knight* (en su lectura de silueta).
- **Pipeline de Producción:**
  - **Código:** Claude Code (programación principal) + Claude Cowork (tareas de gestión y documentación).
  - **Arte 2D:** IA generativa (Midjourney, Stable Diffusion, Nano Banana o equivalentes) con post-procesamiento manual mínimo.
  - **Animación:** Esqueletal en Godot (AnimationTree) sobre sprites generados.
  - **Audio:** IA generativa (Suno, ElevenLabs) + librerías libres.
- **Fantasía del Jugador:** *"Soy un guerrero que crece zona a zona, perfecciono mi build y mi técnica, y desafío a ecos de otros guerreros para ganar Gloria."*

---

## 3. Bucle Principal de Jugabilidad

### 3.1 Loop de sesión (5-10 minutos)

1. **Entrada:** El jugador abre la app, ve dailies, su Gloria actual y un acceso rápido a "Última zona / Coliseo".
2. **Acción:** Completa una etapa PvE (3-5 min) **o** una batalla de Coliseo (1-3 min).
3. **Recompensa:** Loot, XP, materiales, y/o Gloria.
4. **Decisión:** Craftear, asignar puntos, equipar, o volver a jugar.

### 3.2 Loop de progresión (días/semanas)

1. **Caza:** Avanza en zonas PvE, completa etapas y derrota bosses.
2. **Recolección:** Acumula materiales elementales específicos por zona.
3. **Gestión:** Craftea y fusiona equipamiento; asigna puntos de skill.
4. **Competición:** Lleva su build al Coliseo y mide su skill contra otros.
5. **Repetición:** Nuevas zonas, nuevos elementos, mejores builds, ranking más alto.

---

## 4. Combate

### 4.1 Filosofía

Combate en tiempo real, agresivo, recompensa el compromiso. La defensa es un recurso limitado, no una postura permanente. **El sistema de Momentum** es el corazón del feel del juego.

### 4.2 Controles (Layout Móvil)

- **Lado izquierdo:** Joystick virtual de movimiento.
- **Lado derecho:**
  - **1 botón Ataque Básico**
  - **3 botones de Skill** (slots equipables)
  - **1 botón Dash**
  - **1 botón Bloquear** (mantener)

### 4.3 Mecánicas Core

#### Ataque Básico
- Fuente principal de daño y única forma de generar **Furia**.
- Cada impacto exitoso: +10 Furia y +1 al contador de Momentum.

#### Dash
- Desplazamiento físico corto, ~100ms de duración.
- **6 frames de invulnerabilidad (~100ms a 60fps)** — ventana de habilidad, no escape gratuito.
- Cooldown corto (~0.8s).

#### Bloqueo (Escudo)
- Solo disponible si el escudo equipado tiene cargas.
- **Cargas por rareza:**
  - R1 (Común): 0 cargas. Solo stats pasivas.
  - R2 (Raro): 1 carga.
  - R3 (Épico): 2 cargas.
  - R4 (Legendario): 3 cargas.
- **Recarga PvE:** se restauran al alcanzar un checkpoint o completar la etapa.
- **Recarga Coliseo:** sin recarga durante la batalla.

#### Furia (antes "Maná")
- Recurso para usar Skills.
- **No se regenera automáticamente.** Solo aumenta al conectar Ataque Básico.
- **Decay:** si no atacás durante 5 segundos, perdés 5 Furia/segundo. Refuerza agresividad.
- Capacidad máxima: 100 (modificable por equipo/skills).

#### Sistema de Momentum (CORE)
- Contador visible: 1x → 2x → ... → 10x.
- **+1 por cada golpe conectado (ataque básico o skill).**
- **Resetea a 0 al recibir daño físico.** Bloquear lo congela 1 segundo, no lo resetea.
- **Efectos escalados por nivel de Momentum:**
  - Daño total × (1 + 0.05 × Momentum). En 10x = +50% daño.
  - Drop rate × (1 + 0.1 × Momentum). En 10x = +100% drops.
  - Furia ganada × (1 + 0.05 × Momentum).
- **Feedback visual y sonoro fuerte** a partir de 5x (color cambia, audio se intensifica, partículas alrededor del personaje).

---

## 5. Sistema de Equipamiento

### 5.1 Tipos de Equipamiento (Slots)

Tres piezas modulares:

| Tipo | Función Principal | Atributos Derivados |
| :--- | :--- | :--- |
| **Arma** | Define el Daño Físico/Elemental Base | Elemento Ofensivo, Velocidad de Ataque (implícita) |
| **Armadura** | Define la Defensa Base | Resistencia Elemental, Afinidad Elemental |
| **Escudo** | Define la capacidad de Bloqueo | Cargas de Bloqueo, Stats Pasivos (HP/Def) extra |

### 5.2 Escalado por Rareza

El tier del ítem dicta su potencial máximo y la cantidad de afijos (stats secundarias) que puede rodar al craftearse.

| Rareza | Tier | Stats Secundarias | Cargas Escudo | Notas de Diseño / Efectos Especiales |
| :--- | :---: | :---: | :---: | :--- |
| **Común** | R1 | 1 | 0 | Stats base bajas. Solo otorga pasivas si es escudo. |
| **Raro** | R2 | 2 | 1 | Stats medias. Primer tier viable para mecánicas defensivas activas. |
| **Épico** | R3 | 3 | 2 | Stats altas. Añade 1 efecto especial menor (ej. +5% velocidad de carga de Furia). |
| **Legendario** | R4 | 3 | 3 | *Excluido del MVP*. Stats máximas. Efecto especial mayor que altera la build. |

### 5.3 Elementos

Sistema de fortalezas y debilidades con **dos ejes ortogonales** (canon definitivo v2.2 — decisión Leo 27/05/2026).

**6 elementos canon:** FUEGO (1), AGUA (2), TIERRA (3), VIENTO (4), LUZ (5), SOMBRA (6). NEUTRO (0) sin ventaja/desventaja. ~~RAYO~~ descartado — el slot semántico de "CC duro corto" (stun visual) lo ocupa LUZ.

#### Eje natural — control + daño elemental puro

Triángulo primario:
- **Fuego > Tierra**
- **Tierra > Agua**
- **Agua > Fuego**
- VIENTO independiente dentro de este eje (no entra al triángulo).

#### Eje cósmico — alteración de stats, supervivencia, maldiciones

Triángulo secundario:
- **Viento > Luz**
- **Luz > Sombra**
- **Sombra > Viento**

#### Modificadores de daño

| Relación | Multiplicador |
| :--- | :---: |
| Ventaja (dentro de su triángulo) | **×1.5** |
| Desventaja (dentro de su triángulo) | **×0.66** |
| Cross-triángulo (ej. FUEGO vs LUZ) | ×1.0 neutral |
| Mismo elemento | ×1.0 |
| NEUTRO involucrado (cualquier lado) | ×1.0 |

#### Status Synergy on-hit (30% chance base)

Cada golpe con elemento no-NEUTRO tiene **30% chance** de aplicar status:

| Elemento | Status | Efecto |
| :--- | :--- | :--- |
| **FUEGO** | Quemadura | DOT 3s, 3 dmg/tick |
| **AGUA** | Congelación | -30% velocidad / 2s |
| **TIERRA** | Fractura | próximo golpe recibido +20%, **single-use**, ventana 5s |
| **VIENTO** | Desequilibrio | interrumpe ataque actual + 1.5s CD penalty |
| **LUZ** | Bendición Divina | vampire heal — atacante recupera 5% HP máx (NO aplica status al defender) |
| **SOMBRA** | Miasma | DOT 5s 2 dmg/tick + **bypass armor** + -50% Furia gen del defensor |

LUZ es la excepción: efecto va al **atacante** (heal source), no al defender. SOMBRA stack mode INDEPENDENT — snowballea lategame.

#### Implicación gameplay por elemento

- **FUEGO** — DOT sostenido suma a daño base. Sinérgico con armas rápidas.
- **AGUA** — kiteo fácil. Enemies ralentizados 2s con cada golpe.
- **TIERRA** — combo: aplicar Fractura + golpear con build físico/elemental fuerte = ventaja masiva.
- **VIENTO** — control puro. Enemies con casts largos se ven cancelados sistemáticamente.
- **LUZ** — sustain. Vampirismo permite agresión sostenida sin retroceder.
- **SOMBRA** — presión. DOT que ignora armor + ahoga Furia del enemy. Target no puede limpiar el stack.

Implementación: `GameConfig.ELEMENT_ADVANTAGE` (doble triángulo), `HitboxComponent._try_apply_element_status`, `Projectile._try_apply_element_status`. Status data en `resources/status_effects/{burn,freeze,vulnerable,desequilibrio,bendicion,poison}.tres`.

> **Nota canon:** filenames legacy `vulnerable.tres` → id `fractura` y `poison.tres` → id `miasma`. Mismatch intencional, no romper.

### 5.4 Afinidad de Equipo (Set Bonuses)

Equipar piezas del mismo elemento desbloquea sinergias:
- **2 piezas mismo elemento:** Bonus pasivo (ej. +15% resistencia al elemento opuesto).
- **3 piezas mismo elemento:** Habilidad pasiva única (ej. Tierra: tus ataques tienen 10% de generar una raíz que ralentiza al objetivo 2s).

Esto convierte el crafteo de "perseguir stats" a "perseguir builds".

### 5.5 Crafteo y Fusión

- Cada zona dropea materiales específicos.
- Receta = X materiales + Y oro + tiempo (instantáneo en MVP, configurable post-launch).
- **Fusión:** combinar 3 piezas R(n) del mismo tipo = 1 pieza R(n+1) con stats aleatorizadas.

### 5.6 Sistema de Refinamiento (+1 a +10)

El refinamiento aumenta linealmente las estadísticas base del ítem. 
**Fórmula Matemática:** `Stat Final = Stat Base * (1 + (0.05 * Nivel_Refinamiento))`
*(Cada nivel otorga exactamente un 5% extra sobre la estadística base de daño o defensa).*

#### Tabla de Progresión y Riesgos

Al intentar subir de nivel un ítem, el `UpgradeManager` debe evaluar la siguiente tabla de probabilidades y consecuencias de fallo. Todo intento consume *Oro* y *Piedras de Resonancia*.

| Nivel Objetivo | Incremento Total Stat | Prob. de Éxito | Penalización por Fallo | Feedback Visual (Godot Shader) |
| :---: | :---: | :---: | :--- | :--- |
| **+1** | + 5% | 100% | Ninguna | Apariencia Estándar |
| **+2** | + 10% | 100% | Ninguna | Apariencia Estándar |
| **+3** | + 15% | 100% | Ninguna | Apariencia Estándar |
| **+4** | + 20% | 70% | Pérdida de materiales | Apariencia Estándar |
| **+5** | + 25% | 70% | Pérdida de materiales | Brillo sutil intermitente (Color Elemento) |
| **+6** | + 30% | 50% | Pérdida de materiales | Brillo sutil intermitente (Color Elemento) |
| **+7** | + 35% | 50% | Pérdida de materiales | Brillo sutil intermitente (Color Elemento) |
| **+8** | + 40% | 30% | **-1 Nivel de Refinamiento** | Partículas intensas y estela de luz |
| **+9** | + 45% | 20% | **-1 Nivel de Refinamiento** | Partículas intensas y estela de luz |
| **+10** | + 50% | 10% | **-1 Nivel de Refinamiento** | Resplandor máximo / Aura completa |

#### Notas de Implementación (GDScript)

* **RNG:** La probabilidad se debe evaluar generando un número flotante entre 0.0 y 1.0 mediante `randf()`. Ejemplo para +4: `if randf() <= 0.70: success() else: fail()`.
* **Pergaminos de Protección:** Si el jugador usa este consumible especial (obtenido en Ligas Altas) al intentar +8, +9 o +10, la condición de penalización ("-1 Nivel") se omite, pero los materiales base se consumen igualmente.

---

## 6. Sistema de Progresión

### 6.1 Nivel del Personaje

- Subir nivel otorga: 1 punto de skill + aumento automático leve de HP/Furia base.
- **Curva de XP:** exponencial moderada. XP requerida = `100 × nivel^1.5`.
- Nivel máximo MVP: 30.

### 6.2 Árbol de Habilidades

Tres ramas, no exclusivas:

- **Rama Guerrero:** Daño físico, vida, supervivencia.
- **Rama Mago:** Daño elemental, Furia máxima, eficiencia de skills.
- **Rama Ágil:** Velocidad, dash mejorado, esquiva.

Total de nodos MVP: ~30. Cada nodo cuesta 1 punto.

### 6.3 Respec

- Permitido en cualquier momento.
- Costo: pequeña cantidad de oro y materiales comunes. **Nunca dinero real.**
- Refuerza pilar #1 (experimentar builds).

### 6.4 Fórmula Final

```
Stats Totales = Stats Base (Nivel) + Stats de Equipamiento + Bonus de Skills + Bonus de Set
```

---

## 7. Estructura de Niveles e IA

### 7.1 Estructura de Zona

- Cada zona tiene **5-8 etapas + 1 boss final**.
- Etapas duran 2-5 minutos cada una.
- **Sin auto-scaling.** Cada zona tiene un rango de nivel fijo (ej. Valle de los Ecos = niveles 1-15).
- Volver a zonas antiguas con nivel alto = power fantasy intencional.

### 7.2 Modo Eco Profundo (replayability)

Una vez completada una zona, se desbloquea su versión "Eco Profundo":
- Enemigos +20 niveles, IA agresiva (R2/R3 mínimo).
- Drops exclusivos de materiales de alta rareza.
- Misma zona, misma arte: cero costo de contenido, alta retención.

### 7.3 Escalado de IA por Rareza

La dificultad mecánica está ligada a la rareza del enemigo, no solo a sus stats:

- **R1:** Movimiento simple, ataques telegrafiados, sin bloqueo.
- **R2:** Bloquea ocasionalmente, obliga a romper guardia.
- **R3:** Usa skills y dash, fuerza esquivas activas.
- **R4 (Boss):** Espejo del jugador. Cargas de escudo múltiples, skills, dash, patrones complejos. **Telegrafía obligatoria** (ventana de 0.5-1s antes de cada ataque pesado).

---

## 8. Coliseo (Meta-juego competitivo)

**Esta es la sección más diferenciadora del juego. Es lo que retiene jugadores a largo plazo.**

### 8.1 Concepto

PvP asincrónico contra "Ecos" — copias controladas por IA de personajes reales de otros jugadores, con su build, equipo y skills.

### 8.2 Justificación Narrativa

> *"Los Ecos son fragmentos de almas de guerreros caídos atrapados en una dimensión espejo. Combatirlos no los mata — los libera. La Gloria que ganás es el reconocimiento de esas almas."*

### 8.3 Funcionamiento

1. Al alcanzar nivel 10, se desbloquea el Coliseo.
2. El jugador entra y se le presentan **3 Ecos candidatos** con Gloria similar a la suya.
3. Elige uno y pelea en una arena estándar (1v1).
4. **Victoria:** +Gloria, recompensas (oro, materiales).
5. **Derrota:** -Gloria, sin pérdida de equipamiento.

### 8.4 Sistema de Gloria

- **Punto de partida:** todos empiezan con 1000 Gloria.
- **Por victoria:** +25 a +50 (más si ganás contra alguien de Gloria más alta).
- **Por derrota:** -15 a -30.
- **Ranking global** por Gloria. Temporadas mensuales con recompensas top.

### 8.5 Comportamiento de Ecos (versión MVP factible para dev solo)

Como sos solo y no querés meterte con machine learning real, el MVP usa **4 perfiles de IA predefinidos**:

- **Agresivo:** Ataca constantemente, usa skills rápido, bloquea poco.
- **Defensivo:** Bloquea/esquiva más, contraataca.
- **Equilibrado:** Mezcla ambos según situación.
- **Caster:** Prioriza skills y mantiene distancia.

Cuando subís tu Eco al servidor, se analiza tu telemetría de últimas 10 batallas (¿cuántas veces atacaste? ¿cuántas bloqueaste? ¿usaste dash mucho?) y se asigna automáticamente uno de los 4 perfiles. **Tu build sí es 100% tuya**, solo el comportamiento es perfilado.

### 8.6 Implementación Técnica

- Backend mínimo: **Firebase** o **Supabase** (gratis hasta cierto uso).
- Cada Eco se guarda como JSON: build + perfil IA + Gloria.
- Sin servidores de juego, sin sincronización en tiempo real.
- Anti-cheat básico: validación de stats máximas al subir Eco.

---

## 9. Sistemas de Engagement

### 9.1 Misiones Diarias

3 misiones rotativas cada 24h. Ejemplos:
- "Derrota 50 enemigos con daño elemental"
- "Completa una etapa sin recibir daño"
- "Gana 3 batallas en el Coliseo"

Recompensas: materiales raros, oro, cosméticos (post-launch).

### 9.2 Bestiario

Cada enemigo derrotado X veces (10/50/100) otorga:
- Entrada de lore.
- Bonus permanente pequeño contra esa especie (+0.5% / +1% / +2% daño).

### 9.3 Logros (post-MVP)

Sistema clásico. Recompensas cosméticas y de prestigio.

---

## 10. Mundo Inicial: "El Valle de los Ecos"

- **Temática:** Bosque luminoso, raíces gigantes, puentes colgantes, partículas de polen en el aire.
- **Elemento Principal:** Tierra / Físico.
- **Paleta visual de referencia (para IA generativa):** verdes saturados, dorados cálidos, marrones profundos. Estilo "vectorial limpio con sombras planas".
- **Rango de Nivel:** 1-15.
- **Etapas:** 6 etapas + 1 boss.
- **Enemigos:**
  - Espíritus de madera (R1, niveles 1-5)
  - Guerreros de corteza (R2, niveles 4-10)
  - Chamanes de espinas (R3, niveles 8-14)
- **Boss Final (R4): "El Guardián de la Maleza"**
  - Bestia con armadura de rocas.
  - **3 cargas de escudo.**
  - **Patrones:**
    1. Embestida pesada (telegrafía: ruge 0.8s antes).
    2. Invocación de raíces (3 raíces emergen en posiciones telegrafiadas, daño en área 0.5s después).
    3. Salto aplastante a fase 2 (cuando llega al 50% de HP).
- **Loot Inicial:** Madera Ancestral, Colmillos Duros, Núcleos de Tierra.

---

## 11. Alcance del MVP

**Lo que entra en la v1.0:**

- ✅ Combate base completo con Momentum.
- ✅ 1 zona PvE (Valle de los Ecos) con 6 etapas + boss.
- ✅ 6 elementos (FUEGO, AGUA, TIERRA, VIENTO, LUZ, SOMBRA) en equipamiento — sync v2.2.
- ✅ Rarezas R1-R3 (sin R4).
- ✅ Árbol de skills con ~30 nodos.
- ✅ Crafteo y fusión básica.
- ✅ Coliseo asincrónico con 4 perfiles IA.
- ✅ Sistema de Gloria y ranking.
- ✅ Misiones diarias.
- ✅ Bestiario.
- ✅ Sistema de Refinamiento de Armas (+1 a +10).

**Lo que queda para post-launch:**

- ❌ Zonas 2 y 3 (Fuego y Agua como elementos principales).
- ❌ Rareza R4 Legendaria.
- ~~Elementos Viento, Rayo, Sombra~~ → **Movidos al MVP en v2.2** (canon 27/05). RAYO descartado, slot ocupado por LUZ.
- ❌ Sistema de Reliquias (roguelite-lite).
- ❌ Logros y cosméticos.
- ❌ Eventos de temporada en Coliseo.

---

## 12. Pipeline de Desarrollo AI-First

Esta sección documenta **cómo se construye el juego**, no qué hace el juego. Es crítica para el autor (dev solo apoyado en IA).

### 12.1 Programación: Claude Code

- **Rol:** Programador principal. Implementa sistemas siguiendo este GDD.
- **Flujo de trabajo:**
  1. Leo define una feature específica (ej. "Implementar sistema de Momentum").
  2. Pasa la sección relevante del GDD a Claude Code.
  3. Claude Code escribe el código GDScript, lo prueba, ajusta.
  4. Leo revisa, prueba en Godot, da feedback.
- **Documentación viva:** cada feature implementada se documenta en `/docs/features/`.
- **Tests:** Claude Code escribe tests unitarios cuando sea aplicable (combate, fórmulas).

### 12.2 Gestión y Documentación: Claude Cowork

- **Rol:** Asistente de proyecto.
- **Tareas típicas:**
  - Mantener este GDD actualizado a medida que cambian decisiones.
  - Generar listas de assets necesarios.
  - Trackear progreso de features.
  - Generar prompts optimizados para IA generativa de arte.

### 12.3 Arte 2D: IA Generativa

- **Personajes:**
  - Generación inicial en herramientas como Midjourney o Stable Diffusion.
  - Pose neutra en T-pose, fondo transparente.
  - Separación manual por capas (cabeza, torso, brazos, piernas) para animación esqueletal.
- **Enemigos:** Mismo flujo. Variantes de color por rareza.
- **Escenarios:** Parallax de 3-5 capas generadas independientemente.
- **UI:** Iconos generados por IA + ajustes manuales.
- **Prompt base recomendado:**
  > "2D vector art, clean lines, flat shading, saturated colors, side-view character pose, transparent background, fantasy RPG style, [descripción específica del asset]"

### 12.4 Animación

- Esqueletal en Godot, no frame-by-frame.
- Cada personaje: ~6-8 animaciones core (idle, walk, run, attack1, attack2, dash, hurt, death).
- Bosses: +3-5 animaciones específicas de patrones.

### 12.5 Audio

- **Música:** Suno u otro generador. 1 track por zona + 1 track de combate + 1 track de Coliseo.
- **SFX:** ElevenLabs o librerías libres (Freesound, Zapsplat).
- **Voces:** No hay diálogo hablado en MVP.

---

## 13. Plan de Desarrollo por Fases

### Fase 1 — Prototipo de Combate (2-3 meses)
- Cuadrados sobre fondo plano. Joystick, ataque, dash, bloqueo.
- **Hito:** "Pelear se siente bien." Si no, iterar antes de avanzar.

### Fase 2 — Loop Básico (2-3 meses)
- 3 tipos de enemigos placeholder, drop de items, crafteo simple y refinamiento.
- **Hito:** "El loop pelear → lootear → mejorar engancha."

### Fase 3 — Sistemas RPG Completos (3-4 meses)
- Skills, árbol, elementos, Momentum, afinidad de equipo.
- Primera zona con arte generado por IA.
- **Hito:** "Una zona completa es jugable de principio a fin."

### Fase 4 — Coliseo (2-3 meses)
- Backend (Firebase/Supabase), sistema de Ecos, Gloria, matchmaking.
- **Hito:** "Puedo subir mi Eco y pelear contra el de otro tester."

### Fase 5 — Pulido y Lanzamiento (3-4 meses)
- Arte final, audio, UX móvil, balanceo, testing en dispositivos reales.
- **Hito:** "Listo para soft launch."

**Total estimado:** 14-18 meses. Multiplicar mentalmente por 1.5x-2x para estimación realista de dev solo.

---

## 14. Riesgos Identificados

| Riesgo | Mitigación |
|---|---|
| Performance de animación esqueletal en mobile | Limitar huesos por personaje (<20), usar AnimationTree de Godot |
| UI de 5 botones + joystick en pantalla chica | Probar en celular real desde Fase 1, no en PC |
| Corrupción de saves | Guardado redundante (local + cloud) desde día 1 |
| Backend del Coliseo costoso | Firebase free tier alcanza para soft launch; migrar si escala |
| Estilo visual inconsistente (IA generativa) | Mantener un "prompt template" maestro y reutilizar siempre |
| Scope creep (querer agregar features) | Releer pilares antes de cada decisión. Si no refuerza pilar, no entra. |
| Burnout de dev solo | Sprints cortos (2 semanas), pausas planificadas, no medir progreso lineal |

---

## 15. Métricas de Éxito (post-launch)

- **Retención D1:** >30% (industria mobile: 25-35%).
- **Retención D7:** >10%.
- **Sesiones por día:** >2 por jugador activo.
- **% jugadores que llegan al Coliseo:** >40%.
- **Tiempo promedio de sesión:** 5-10 minutos.

---

## 16. Notas Finales

Este GDD es un **documento vivo**. Va a cambiar a medida que se implementen sistemas y se descubran cosas. La regla de oro:

> *"Si lo que diseñé acá no se siente bien al jugarlo, gana el playtest, no el documento."*

Cualquier cambio significativo se versiona (v2.1, v2.2, etc.) y se documenta el porqué.

---

## Changelog

| Versión | Fecha | Cambio | Razón |
| :--- | :--- | :--- | :--- |
| v2.1 | 21/05/2026 | Versión inicial post-setup de proyecto | Documentar pilares + scope MVP. |
| **v2.2** | **28/05/2026** | **§5.3 6 elementos canon (FUEGO/AGUA/TIERRA/VIENTO/LUZ/SOMBRA). Dual triangle eje natural vs cósmico. Status synergy on-hit 30%.** | Sync con código implementado 27/05. RAYO descartado, slot ocupado por LUZ. Eje cósmico (LUZ/SOMBRA) tema "santidad vs maldad" complementa eje natural (control + daño puro). MVP scope §11 actualizado para incluir 6 elementos. |
