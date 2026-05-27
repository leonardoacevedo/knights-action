# Diseño de Zona 3: El Acueducto del Lamento

**Módulo:** World Generation / Level Design
**Elemento Principal:** Agua / Hielo (Ventaja contra Fuego, Desventaja contra Tierra)
**Rango de Nivel Sugerido:** 25 - 35
**Directiva para el Agente (Claude):** Implementar la lógica de esta zona integrando un modificador de físicas en el `CharacterBody2D` del jugador (suelo resbaladizo).

---

## 1. Lore y Estética Visual

* **Lore:** Una ciudad sumergida que fue un santuario de sanación. La tristeza congeló el agua, atrapando a las almas en un laberinto de cristal y desesperación.
* **Paleta de Colores:** Azules profundos, cian brillante, blancos y plata.
* **Parallax Background:** * Capa 1: Pilares de mármol blanco congelados.
  * Capa 2: Cascadas detenidas en el tiempo.
  * Capa 3: Profundidades oscuras del océano/lago subterráneo.
* **Hazards (Peligros Ambientales):**
  * **Hielo Fricción Cero:** Ciertas plataformas reducen el freno (`velocity.x = move_toward(...)` ajustado a valores muy bajos), haciendo que el jugador resbale.

## 2. Estructura de Etapas

* **Total de Etapas:** 7 Etapas normales + 1 Sala de Jefe.
* **Pacing:** Énfasis en plataformeo preciso y esquiva de proyectiles en áreas amplias.

## 3. Bestiario y Habilidades (Spawns)

### 3.1 Náyade Congelada (Arquero R1/R2)
Espectros flotantes. Especialistas en mantener al jugador inmovilizado.
* **Habilidad R1:** `Flecha Perforante` (Proyectil de hielo veloz).
* **Habilidad R2:** `Trampa de Cazador` (Loto de hielo en el suelo; inmoviliza 1s al pisarlo).

### 3.2 Caballero de Escarcha (Guerrero R2/R3)
Soldados de cristal. Castañean al caminar y castigan la pasividad.
* **Habilidad Principal:** `Tajo Doble` (Ataque rápido cruzado).
* **Habilidad Secundaria:** `Salto de Asalto` (Gap closer con indicador circular rojo).

### 3.3 Sacerdote de Mareas (Mago R3)
Clérigos corruptos. Su objetivo es denegar grandes porciones del suelo.
* **Habilidad Principal:** `Nova de Hielo` (Aparece bajo los pies del jugador).
* **Habilidad Secundaria:** `Erupción Terrestre` (Pilar de hielo instantáneo con tracking, obliga al jugador a estar siempre en movimiento).

## 4. Boss Final: Lyss, la Sirena de Hielo (R4)

Arena dividida: plataformas de hielo pequeñas sobre agua profunda. Caer al agua reduce la velocidad de movimiento un 40% hasta volver a saltar.
* **Mecánicas Activas:**
  * Usa **Látigo Helado** (Rango medio, hitbox rectangular muy preciso y rápido).
  * Usa **Muralla Estática** (Refleja ataques a distancia/magia del jugador).
  * Usa **Vórtice de Gravedad** (Chupa al jugador hacia el agua central si no usa el dash alejándose constantemente durante 2 segundos).

## 5. Loot Table y Recursos

* **Drops Comunes:** Gota de Lamento, Cristal de Escarcha Puro.
* **Drops Raros:** Núcleo Abisal (Material R3 esencial para resistencia al Fuego).
* **Recetas Desbloqueadas:** Set de Armadura Glacial (Afinidad Agua), Arco de Tempestad.