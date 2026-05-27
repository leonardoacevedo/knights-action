# Diseño de Zona 2: La Fragua Cenicienta

**Módulo:** World Generation / Level Design
**Elemento Principal:** Fuego (Ventaja contra Tierra, Desventaja contra Agua)
**Rango de Nivel Sugerido:** 15 - 25
**Directiva para el Agente (Claude):** Implementar la lógica de nivel, spawns y Hazards ambientales siguiendo este documento. Asegurar que los enemigos utilicen los recursos de habilidades (`.tres`) correspondientes.

---

## 1. Lore y Estética Visual

* **Lore:** Ruinas de la forja original de los Ecos. Los espíritus herreros, consumidos por la ira, están encadenados a yunques candentes y su rabia alimenta los ríos de magma.
* **Paleta de Colores:** Tonos carbón, rojos intensos, naranjas y amarillos brillantes.
* **Parallax Background:** * Capa 1: Cadenas gigantes colgando.
  * Capa 2: Muros de piedra volcánica derruidos.
  * Capa 3: Ríos de lava cayendo en la distancia.
* **Hazards (Peligros Ambientales):**
  * **Charcos de Lava:** Áreas en el suelo que aplican Daño por Segundo (DoT) si se pisan.

## 2. Estructura de Etapas

* **Total de Etapas:** 6 Etapas normales + 1 Sala de Jefe.
* **Pacing:** Combates en áreas cerradas (forjas) que limitan la movilidad.

## 3. Bestiario y Habilidades (Spawns)

### 3.1 Esclavo de Escoria (Mago R1/R2)
Esqueletos envueltos en fuego. Mantienen distancia y dividen el campo de batalla.
* **Habilidad R1:** `Orbe Flamígero` (Proyectil lento con daño AoE).
* **Habilidad R2:** `Muro de Llamas` (Línea de fuego persistente por 4s).

### 3.2 Centinela de Fundición (Tanque R2)
Armaduras vacías pesadas, lentas pero contundentes. Obligan al jugador a usar dashes verticales.
* **Habilidad Principal:** `Escudo Cargado` (Embestida frontal que resta 1 carga de escudo).
* **Habilidad Secundaria:** `Golpe Terremoto` (Pisada que ralentiza al jugador un 50% por 2s).

### 3.3 Maestro Forjador (Guerrero R3)
Demonios ágiles con martillos gigantes. Son los "Elites" de la zona.
* **Habilidad Principal:** `Corte Giratorio` (Avanzan lentamente girando el martillo, AoE de 1.5s).
* **Habilidad Secundaria:** `Arma Imbuida` (Buff de 5s: sus ataques ignoran el escudo del jugador).

## 4. Boss Final: Ignis, el Martillo Demente (R4)

Enemigo anclado parcialmente al centro de la arena mediante cadenas.
* **Fase 1 (100% - 50% HP):**
  * Usa **Salto Sísmico** (aterriza dejando charcos de lava permanentes durante la pelea).
  * Usa **Lluvia de Meteoros** (golpea el yunque y caen 3 proyectiles rastreadores).
* **Fase 2 (Menos de 50% HP):**
  * Se libera de las cadenas. 
  * Activa **Sed de Sangre** (+20% velocidad de movimiento y ataque permanente).
  * Añade **Corte Giratorio** persiguiendo agresivamente al jugador.

## 5. Loot Table y Recursos

* **Drops Comunes:** Fragmento de Ascuas, Mineral de Hierro Rojo.
* **Drops Raros:** Núcleo Ígneo (Material R3 esencial para armas de Fuego y refinamiento).
* **Recetas Desbloqueadas:** Set de Armadura de Brasas (Afinidad Fuego), Martillo Meteórico.