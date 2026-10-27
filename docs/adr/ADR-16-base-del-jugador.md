# ADR-16: Representación y Comportamiento de la Base del Jugador

## Contexto
En *Special Forces Elite 5*, los jugadores defienden una base fortificada ("Fortaleza Planetaria / Planetary Fortress"). En el código base actual, `main_level.tscn` utiliza la estructura `CommandCenter` (conectada a los sistemas de salud, HUD, telemetría y derrota `base_destroyed`), mientras que `PlanetaryFortress` es una clase separada con cañón Ibis probada únicamente en entornos secundarios.

## Decisión
Se adopta la **Opción A (Conservadora y segura para R1)**:
1. Mantener `CommandCenter` como la entidad central que representa la base del jugador en `main_level.tscn`.
2. Para efectos de reglas de juego, su destrucción dispara unívocamente la condición de derrota.
3. Se unifican los textos de interfaz y HUD para referirse a ella como "Centro de Mando / Fortaleza Planetaria".
4. La sustitución de la entidad física por la clase `PlanetaryFortress` con armas autónomas avanzadas se pospone a las fases de combate avanzado (R2–R3), eliminando cualquier riesgo de regresión en navegación de enjambres, cálculo de perímetros o cableado de señales durante R1.

## Consecuencias
- Cero riesgo de romper el grafo de obstáculos de navegación o las señales de derrota durante la estabilización de R1.
- Experiencia de juego coherente y predecible.
