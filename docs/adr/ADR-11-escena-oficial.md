# ADR-11: Escena Oficial del Juego y Escenas de Pruebas

## Contexto
El repositorio contenía dos escenas principales de juego en desarrollo: `res://levels/main_level.tscn` (con mapa completo, enjambre masivo, interfaz SC2 HUD, selección de dificultad, héroe y eventos) y `res://levels/spawner_arena.tscn` (un entorno aislado de pruebas para engendradores).

## Decisión
1. **`res://levels/main_level.tscn` se establece como la ÚNICA escena oficial de juego canónica**, configurada como `run/main_scene` en `project.godot`.
2. `spawner_arena.tscn` y `spawner_arena.gd` se trasladan a `res://levels/test/` como entorno de prueba técnica para validar mecánicas de engendradores sin el peso de la escena principal completa.
3. No se realizará una fusión destructiva en R1: todas las mejoras de jugabilidad, HUD y flujo de partida se centran en `main_level.gd`.

## Consecuencias
- Claridad total sobre la ruta de ejecución y pruebas de usuario.
- Aislamiento seguro de herramientas de test sin contaminar la raíz de `levels/`.
