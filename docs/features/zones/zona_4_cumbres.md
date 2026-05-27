# Diseño de Zona 4: Cumbres de la Tempestad

**Módulo:** World Generation / Level Design
**Elemento Principal:** Viento / Rayo
**Rango de Nivel Sugerido:** 35 - 45
**Directiva para el Agente (Claude):** Esta zona requiere la implementación de un vector de fuerza de viento global que empuje pasivamente al jugador y altere las parábolas de salto.

---

## 1. Lore y Estética Visual

* **Lore:** La cúspide de la dimensión espejo. Las tormentas eternas han desgarrado las mentes de los Ecos más antiguos, convirtiéndolos en seres erráticos de pura energía.
* **Paleta de Colores:** Púrpuras oscuros, amarillos eléctricos vibrantes y blancos intensos.
* **Parallax Background:** * Capa 1: Escombros levitando a alta velocidad.
  * Capa 2: Nubes negras densas con relámpagos internos.
  * Capa 3: Abismo infinito.
* **Hazards (Peligros Ambientales):**
  * **Vientos Huracanados:** Empujan al jugador hacia una dirección específica (cambia cada X segundos), afectando la distancia del Dash.
  * **Caída al Vacío:** No hay suelo seguro continuo.

## 2. Estructura de Etapas

* **Total de Etapas:** 5 Etapas + 1 Mini-boss (Etapa 3) + 1 Sala de Jefe.
* **Pacing:** Verticalidad extrema, plataformas pequeñas, alta agilidad requerida.

## 3. Bestiario y Habilidades (Spawns)

### 3.1 Arpía de la Brisa (Arquero R2)
Alta evasión, atacan mientras vuelan.
* **Habilidad Principal:** `Disparo Reactivo` (Tiros casi instantáneos).
* **Habilidad Secundaria:** `Disparo en Abanico` (3 plumas eléctricas en cono frontal).

### 3.2 Gólem de Tormenta (Tanque R2/R3)
Hechos de mampostería flotante y nubes. 
* **Habilidad Principal:** `Provocación (Taunt)` (Atrae el focus del jugador).
* **Habilidad Secundaria:** `Guardia Espinada` (Postura defensiva; devuelve daño melee como choque eléctrico + Stagger).

### 3.3 Hoja del Viento (Guerrero R3)
Samuráis espectrales. Rompen las defensas del jugador sistemáticamente.
* **Habilidad Principal:** `Corte Cruzado` (Ataque frontal rápido).
* **Habilidad Secundaria:** `Gancho Ascendente` (Si el jugador bloquea, este ataque destruye 2 cargas de escudo inmediatamente).

## 4. Peleas Especiales (Mini-Boss y Boss)

### 4.1 Mini-Boss (Etapa 3): Capitán de los Vientos (Arquero R3 Elite)
* Lucha en una plataforma suspendida diminuta. 
* Abusa de **Tiro Mortal (Snipe)** (Láser rojo que persigue al jugador 2s antes de disparar). Obliga a usar *iframes* del Dash para sobrevivir.

### 4.2 Boss Final: Vael, el Señor del Relámpago (R4)
Arena sin paredes, peligro de caída inminente. El jefe más rápido del juego.
* **Mecánicas Activas:**
  * Usa **Ráfaga Arcana** (3 rayos veloces consecutivos).
  * Usa **Rayo Penetrante** (Láser continuo de 2s que barre la pantalla).
  * Usa **Patada Frontal** (Gap creator: si el jugador se acerca demasiado y es codicioso, lo empuja hacia el abismo).

## 5. Loot Table y Recursos

* **Drops Comunes:** Pluma de Tormenta, Fragmento de Cielo Roto.
* **Drops Raros:** Núcleo Fulgurante (Material de Tier 3 para crafteos de End-game).
* **Recetas Desbloqueadas:** Set de Armadura Tormentosa, Espada Doble de Viento (Alta acumulación de Momentum).