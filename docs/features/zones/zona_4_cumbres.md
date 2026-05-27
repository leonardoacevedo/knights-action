# Diseño de Zona 4: Cumbres de la Luz Tormentosa

**Módulo:** World Generation / Level Design
**Elemento Principal:** Viento / Luz (canon 27/05 — 6 elementos definitivos: FUEGO, AGUA, TIERRA, VIENTO, LUZ, SOMBRA)
**Rango de Nivel Sugerido:** 35 - 45
**Directiva para el Agente (Claude):** Esta zona requiere la implementación de un vector de fuerza de viento global que empuje pasivamente al jugador y altere las parábolas de salto.

---

## 1. Lore y Estética Visual

* **Lore:** La cúspide de la dimensión espejo. Las tormentas de luz pura han desgarrado las mentes de los Ecos más antiguos, convirtiéndolos en seres erráticos de luz cegadora y viento huracanado.
* **Paleta de Colores:** Púrpuras oscuros (contraste), dorados radiantes vibrantes y blancos intensos cegadores.
* **Parallax Background:**
  * Capa 1: Escombros levitando a alta velocidad.
  * Capa 2: Nubes negras densas con destellos lumínicos internos.
  * Capa 3: Abismo infinito.
* **Hazards (Peligros Ambientales):**
  * **Vientos Huracanados:** Empujan al jugador hacia una dirección específica (cambia cada X segundos), afectando la distancia del Dash.
  * **Caída al Vacío:** No hay suelo seguro continuo.

## 2. Estructura de Etapas

* **Total de Etapas:** 5 Etapas + 1 Mini-boss (Etapa 3) + 1 Sala de Jefe.
* **Pacing:** Verticalidad extrema, plataformas pequeñas, alta agilidad requerida.

## 3. Bestiario y Habilidades (Spawns)

### 3.1 Arpía de la Brisa (Arquero R2 — Element VIENTO)
Alta evasión, atacan mientras vuelan.
* **Habilidad Principal:** `Disparo Reactivo` (Tiros casi instantáneos).
* **Habilidad Secundaria:** `Disparo en Abanico` (3 plumas cortantes en cono frontal).

### 3.2 Gólem de Tormenta (Tanque R2/R3 — Element LUZ)
Hechos de mampostería flotante y nubes resplandecientes.
* **Habilidad Principal:** `Provocación (Taunt)` (Atrae el focus del jugador).
* **Habilidad Secundaria:** `Guardia Espinada` (Postura defensiva; devuelve daño melee como destello lumínico + Stagger).

### 3.3 Hoja del Viento (Guerrero R3 — Element VIENTO)
Samuráis espectrales. Rompen las defensas del jugador sistemáticamente.
* **Habilidad Principal:** `Corte Cruzado` (Ataque frontal rápido).
* **Habilidad Secundaria:** `Gancho Ascendente` (Si el jugador bloquea, este ataque destruye 2 cargas de escudo inmediatamente).

## 4. Peleas Especiales (Mini-Boss y Boss)

### 4.1 Mini-Boss (Etapa 3): Capitán de los Vientos (Arquero R3 Elite — Element VIENTO)
* Lucha en una plataforma suspendida diminuta.
* Abusa de **Tiro Mortal (Snipe)** (Láser dorado que persigue al jugador 2s antes de disparar). Obliga a usar *iframes* del Dash para sobrevivir.

### 4.2 Boss Final: Vael, el Señor de la Luz Cegadora (R4 — Element LUZ)
Arena sin paredes, peligro de caída inminente. El jefe más rápido del juego.
* **Mecánicas Activas:**
  * Usa **Ráfaga Arcana** (3 dardos de luz veloces consecutivos).
  * Usa **Lanza de Luz Penetrante** (Láser continuo de 2s que barre la pantalla).
  * Usa **Patada Frontal** (Gap creator: si el jugador se acerca demasiado y es codicioso, lo empuja hacia el abismo).

## 5. Loot Table y Recursos

* **Drops Comunes:** Pluma de Tormenta, Fragmento de Cielo Roto.
* **Drops Raros:** Núcleo Fulgurante (Material de Tier 3 para crafteos de End-game — encarnación de luz radiante en cristal).
* **Recetas Desbloqueadas:** Set de Armadura Tormentosa, Espada Doble de Viento (Alta acumulación de Momentum).

---

## 6. Decisión canónica de elementos (27/05)

Leo confirmó: los **6 elementos finales** del juego son FUEGO, AGUA, TIERRA, VIENTO, LUZ, SOMBRA. El elemento RAYO que aparecía en versiones anteriores de este documento queda **descartado** — su slot semántico (5) lo ocupa LUZ. La narrativa de "Rayo Penetrante" se renombró a "Lanza de Luz Penetrante" + "Señor del Relámpago" a "Señor de la Luz Cegadora". El feel sigue siendo similar (CC duro corto = STUN), solo cambia la fantasía visual.
