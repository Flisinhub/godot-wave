# Guía paso a paso — R0 (Verificación) y R1 (Partida SFE5 completa)

> Complemento de `ROADMAP_v2.md`. Pensada para ejecutarse en orden, con comandos copiables.
> Todo lo que aquí se afirma sobre el repo sale de leer `origin/main` del 27/10/2026; los resultados reales se miden y registran en R0.

## 0. Correcciones al diagnóstico anterior

1. **`main_level` ya usa la cadena de engendradores por defecto.** `_setup_spawner_network()` genera 3 spawners con `MapGenerator` y `SpawnerChain`, y `WaveManager` solo arranca si el modo tiene `use_waves_mode = true` (solo Nightmare). R1 pasa de "enchufar la cadena" a "dejarla fiable y completa".
2. **Hallazgos clave que afectan a R0/R1:**
   - El CI usa la imagen `barichello/godot-ci:4.3.0`, pero el proyecto es **4.7** (`config/features`) y el runner dice "4.7.2". El CI no puede abrir el proyecto con 4.3.
   - `tests/test_output.txt` **está versionado** aunque figura en `.gitignore`.
   - `export_presets.cfg` está en `.gitignore`, así que **no está en el repo** aunque el changelog dice que se añadió.
   - `tests/test_runner.gd` **lista las suites a mano** con `preload(...)`; mover tests exige editar el runner.
   - Seed: `main_level` lee `sess.active_seed` (con valor por defecto 12345), pero `GameSession` define `map_seed`. Salvo que `active_seed` exista en otro sitio, **todas las partidas usarían la seed 12345**.
   - No hay contador de presupuesto (`x/300`) en el HUD, ni iconos de engendradores en el minimapa, ni lectura de argumentos de línea de comandos para la seed.

---

# PARTE A — R0: Verificación y línea base

**Objetivo:** saber con evidencia qué funciona. **Regla:** en R0 no se arregla casi nada; se mide, se anota y se limpia.

## Paso 0.0 — Entorno
- Godot 4.7.2-stable win64 console / editor.

## Paso 0.1 — Ejecutar la batería de tests
- Medir tests totales, tiempo, fallos. Anotar en `docs/STATE_REAL.md`.

## Paso 0.2 — Arreglar el CI (versión de Godot)
- Actualizar `.github/workflows/ci.yml` a Godot 4.7.2 con `chickensoft-games/setup-godot@v2`.

## Paso 0.3 — Reproducir las cifras del CHANGELOG
- Medir simulaciones y benchmarks reales.

## Paso 0.4 — Auditoría jugando (10 minutos, F5)
- Tabla de 32 puntos evaluada y registrada.

## Paso 0.5 — Reorganizar los tests
- `tests/unit`, `tests/integration`, `tests/legacy`.
- Runner dinámico que itera directorios.

## Paso 0.6 — Sacar `test_output.txt` del repo
- `git rm --cached tests/test_output.txt`.

## Paso 0.7 — `export_presets.cfg`
- Des-ignorar en `.gitignore` y versionar o ajustar notas.

## Paso 0.8 — Tags y CHANGELOG honestos
- Distinguir capas estructurales de jugabilidad final verificada.

## Paso 0.9 — README reproducible
- Comandos exactos.

## Paso 0.10 — Documentos de estado y evidencias
- `docs/STATE_REAL.md`, `docs/EVIDENCE.md`, `docs/KNOWN_ISSUES.md`.

---

# PARTE B — R1: Partida SFE5 completa de principio a fin

**Objetivo:** una partida determinista (seed) con 3 engendradores encadenados, presupuesto de 300, base que defender, y final de victoria/derrota coherente, con datos visibles en pantalla.

- [x] Paso 1.1: ADR-11 (Escena oficial) y ADR-16 (Base del jugador).
- [x] Paso 1.2: Seed fiable (`GameSession.map_seed`) + `--seed=` por CLI + visualización en HUD.
- [x] Paso 1.3: Cadena configurable y verificada (1 a 3 spawners, prerequisitos).
- [x] Paso 1.4: Presupuesto de 300 en el HUD (`EnemyBudgetLabel`).
- [x] Paso 1.5: Minimapa con estado de spawners (gris bloqueado, rojo activo, verde destruido).
- [x] Paso 1.6: Unificar final de partida `_end_game(victory)` con total ganado y modal único.
- [x] Paso 1.7: Aislar modo rondas (`is_waves_mode`).
- [x] Paso 1.8: Test de integración de la escena principal (`test_main_level_spawner_flow.gd`).
- [x] Paso 1.9: Partida completa de evidencia con `--seed=1234`.
- [x] Paso 1.10: Tag `v0.20` tras jugar.
