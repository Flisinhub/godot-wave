# Problemas Conocidos y Triaje de Bugs (Known Issues)

## Prioridad P0 (Bloqueantes de Partida)
- *Ninguno detectado en la suite de 245 tests ni en la inicialización.*

## Prioridad P1 (Grave / Inconsistencia de Lógica Central)
- **ISSUE-01: Seed fija e ignorada por discrepancia de nombre**
  - *Ubicación:* `levels/main_level.gd` (línea 478) vs `core/game_session.gd` (línea 13).
  - *Descripción:* `main_level.gd` consulta `sess.active_seed`, mientras que `GameSession` define `map_seed`. Como resultado, la condición falla siempre y la partida cae al fallback silencioso `12345`.
  - *Solución planificada:* Paso 1.2 (R1).

- **ISSUE-02: Rutas duplicadas de Fin de Partida y guardado de banco**
  - *Ubicación:* `levels/main_level.gd` (`_on_all_spawners_cleared` vs `_on_base_destroyed`).
  - *Descripción:* La victoria llama `_save_bank_progress(false)` pasando `is_game_over = false`, mientras la derrota muestra dos modales distintos (`SFEGameOverModal` y `game_over_panel`).
  - *Solución planificada:* Paso 1.6 (R1).

## Prioridad P2 (Falta de Visibilidad / UI)
- **ISSUE-03: Falta de contador de presupuesto de enemigos en el HUD**
  - *Descripción:* El jugador no puede ver cuántos enemigos hay activos contra el tope de 300 (`x/300`).
  - *Solución planificada:* Paso 1.4 (R1).

- **ISSUE-04: Falta de iconos de estado de engendradores en el minimapa**
  - *Descripción:* El minimapa no refleja qué engendradores están bloqueados (gris), activos (rojo) o destruidos (verde).
  - *Solución planificada:* Paso 1.5 (R1).
