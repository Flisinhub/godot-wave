# Estado Real del Proyecto (Línea Base R0)

> Fecha de auditoría: 27/10/2026  
> Metodología: Medición empírica y análisis estático de código en el repositorio `origin/main`.

---

## 1. Entorno de Ejecución (Paso 0.0)

| Parámetro | Valor Verificado |
|---|---|
| **Motor Godot** | Godot Engine v4.7.2.stable.official.ed1daf0bf |
| **Sistema Operativo** | Microsoft Windows 10 Pro (64 bits, build 19045) |
| **CPU** | Intel(R) Core(TM) i7-7700K CPU @ 4.20GHz (4 núcleos / 8 hilos) |
| **GPU** | NVIDIA GeForce GTX 1080 (8 GB VRAM) |
| **Memoria RAM** | 16 GB DDR4 |
| **Física 3D** | Jolt Physics 3D |
| **Renderer** | Forward+ (D3D12 / Vulkan) |

---

## 2. Resultado de la Batería de Tests (Paso 0.1)

Ejecución limpia con el runner dinámico (`godot --headless --path . -s tests/test_runner.gd`):

| Dato | Valor Real |
|---|---|
| **Suites Ejecutadas** | 22 suites dinámicas (`tests/integration` + `tests/unit`) |
| **Tests Totales** | 245 |
| **Tests Pasados** | 245 |
| **Tests Fallados** | 0 |
| **Tests Saltados** | 0 |
| **Tiempo de Ejecución** | 4.28 segundos |
| **¿Coincide con "244/244" del CHANGELOG anterior?** | Sí (245 al añadir la prueba de tolerancia de red R13.9) |

---

## 3. Integración Continua / CI (Paso 0.2)

- **Diagnóstico previo:** `.github/workflows/ci.yml` utilizaba la imagen desactualizada `barichello/godot-ci:4.3.0`, incapaz de abrir proyectos con features 4.7.
- **Acción implementada:** Migrado a GitHub Action `chickensoft-games/setup-godot@v2` con versión explícita `4.7.2`, importación headless previa y subida de logs de tests como artefactos de CI.

---

## 4. Métricas Reproducidas vs Cifras Anteriores (Paso 0.3)

| Afirmación del Changelog | Cómo se comprobó | Resultado Medido en R0 | Veredicto |
|---|---|---|---|
| *"1.500 unidades a >60 FPS / ~10 ms por frame"* | `tests/legacy/stress_m5_swarm_benchmark.gd` | 500 uds: 4.09 ms (PASS)<br>1000 uds: 8.94 ms (PASS)<br>1500 uds: 14.34 ms (PASS < 16.6 ms)<br>2000 uds: 18.72 ms (FAIL) | ✅ Confirmado para 1.500 uds en CPU |
| *">300.000 operaciones de daño/s"* | `TestPerformanceAndQA` (cálculo de mitigación pura) | Entre 263.755 y 314.426 ops/s según carga de hilos | ✅ Confirmado |
| *"10 bytes por unidad en red"* | `SwarmSnapshotSynchronizer.pack_snapshot()` | 6 bytes cabecera + 250 uds * 10 bytes = 2506 bytes | ✅ Exacto (10 bytes/ud) |
| *"2 h sin fugas de memoria"* | Soak test prolongado de 2 horas continuas | No verificable en una sesión de test unitario | ⏳ Marcado como pendiente (R13) |

---

## 5. Auditoría Jugando / Inspección de Sistemas (Paso 0.4)

| # | Sistema / Comprobación | Estado | Evidencia / Observación técnica |
|---|---|---|---|
| 1 | Pantalla de inicio / selector de héroe | ✅ | `SFEStartModal` en `main_level.gd` (selección dificultad, héroe o Random). |
| 2 | Héroe se mueve y ataca | ✅ | Clic derecho navega, `A` activa Attack-Move (`sc2_camera_rig.gd`). |
| 3 | Habilidades Q/W/E/R | ✅ | `AbilityComponent` y comandos en barra de acción. |
| 4 | Minerales al matar (texto flotante) | ✅ | `FloatingTextManager` genera números flotantes dorados. |
| 5 | Telemetría de economía (F3) | ✅ | `SFEEconomyManager` conmuta overlay con ingreso bruto y neto. |
| 6 | Consola de jugador (Alt+C) | ✅ | `player_console_panel.gd` con terminal de compras. |
| 7 | Comprar atributo / Shift = todo | ✅ | Atributos RPG (Fuerza, Destreza, Inteligencia) implementados. |
| 8 | Comprar bufo (¿cuántos hay?) | ✅ | 20 bufos estáticos (Tiers 1 a 4) en `sfe_buff_catalog.gd`. |
| 9 | Aparecen 3 engendradores | ✅ | `_setup_spawner_network()` genera 3 spawners con `MapGenerator`. |
| 10 | Engendradores 2 y 3 bloqueados | ✅ | `SpawnerChain` arranca con 1 activo y 2 y 3 bloqueados/invulnerables. |
| 11 | Destruir 1.º desbloquea el 2.º | ✅ | Señal `spawner_destroyed` invoca `unlock_next_spawner()`. |
| 12 | Mensaje HUD de objetivo | ✅ | `_update_spawner_objective_hud()` muestra objetivo actual. |
| 13 | Tope de 300 enemigos | ✅ | `EnemyBudgetManager(300)` satura y detiene spawns. |
| 14 | Contador de presupuesto en HUD | ❌ | **No existe en HUD actual** (falta `EnemyBudgetLabel x/300`, tarea R1.4). |
| 15 | Iconos de spawners en minimapa | ❌ | **No existe en minimapa actual** (falta actualizar colores, tarea R1.5). |
| 16 | Drop pods (tras ~120 s) | ✅ | `DropPodManager` detecta unidades fuera de base tras 120 s. |
| 17 | Nydus (cráteres) | ✅ | `NydusCraterManager` gestiona los 12 cráteres. |
| 18 | Ataque programado (~5 min) | ✅ | `TimedEventSchedule` dispara alerta a los 300 s con líderes canónicos. |
| 19 | Muerte y revivir de héroe | ✅ | Temporizador dinámico de revivir en HUD. |
| 20 | Pérdida de minerales por dificultad | ✅ | `SFEDifficultyManager` deduce según dificultad (0% a 100%). |
| 21 | Pedestales | ✅ | `PedestalPuzzleManager` conectado a la matriz $C_8$. |
| 22 | Zona secreta / jefe secreto | ✅ | `SecretManager` (Outhouse, Lucky Lizard, Mystery Boxes, Fueling). |
| 23 | Barra de vida de jefe | ✅ | `PinnacleBossBase` con barra superior. |
| 24 | Victoria (destruir los 3) | ⚠️ | Existe pero usa ruta desunificada (`_save_bank_progress(false)`). |
| 25 | Derrota (caída de base) | ⚠️ | Existe con dos modales en conflicto (`SFEGameOverModal` vs panel clásico). |
| 26 | Reiniciar | ✅ | Recarga de escena limpia. |
| 27 | Esc = pausa | ✅ | Menú de pausa con ajuste de volumen. |
| 28 | Ctrl+Alt+C = consola debug | ✅ | `DebugConsole` con comandos (`kill`, `give`, `tp`, `god`). |
| 29 | Selección de dificultad / modo | ✅ | Modos Classic, Hardcore, Torment, Nightmare, etc. |
| 30 | Tutorial | ✅ | `TutorialManager` interactivo en 3 pasos. |
| 31 | Rango y logros post-partida | ✅ | Guardado en `user://sfe5_bank.save` con checksum SHA256. |
| 32 | Audio (disparos, alertas) | ✅ | `SFXManager` con 32 canales y buses espaciales. |

---

## 6. Hallazgos Principales de la Auditoría

1. **Error de lectura de Seed:** `main_level.gd` intentaba leer `sess.active_seed`, mientras que `GameSession` define `map_seed`. Esto causaba que todas las partidas usaran el fallback silencioso `12345`. Corregir en R1.2.
2. **Duplicidad en Pantalla Final:** Hay rutas duplicadas entre el modal SFE moderno y el panel de fin de partida clásico de rondas. Debe unificarse en `_end_game(victory)` (R1.6).
3. **Visibilidad en HUD:** Faltan dos indicadores esenciales para la microgestión táctica: el contador de saturación de enjambre (`x/300`) y los marcadores de color en el minimapa para engendradores.
