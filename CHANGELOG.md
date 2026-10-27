# Changelog — Special Forces Elite 5 (Godot 4.7.2)

> **Nota metodológica (Línea base R0):** Hasta completar las fases de juego extremo a extremo (R1..R13), las versiones describen capas y sistemas *arquitectónicamente implementados y verificados con pruebas automatizadas*, no necesariamente *jugables de principio a fin sin ajustes de diseño*. Las pruebas de saturación prolongada (soak test de 2 horas) se encuentran marcadas como *pendientes de verificación completa en R13*.

Todos los cambios notables de este proyecto están documentados en este archivo, siguiendo el formato [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) y las versiones de [Semantic Versioning](https://semver.org/lang/es/).

---

## [0.20.0-estructura] — 2026-10-27
### Capa Estructural 15 y 16: Rendimiento, QA, Extras y Presupuestos
- **Añadido:**
  - `core/qa/performance_benchmarks.gd`: Suite integral de benchmarking y pruebas de estrés para CPU, simulación de enjambre (1.500 unidades a > 60 FPS / ~14.3 ms de cálculo de simulación en CPU), rendimiento de cálculo de daño (> 260.000–300.000 operaciones/s), empaquetado de red en 10 bytes y reciclaje de memoria SoA sin fugas. *(Nota R0: Soak test continuo de 2 h marcado como pendiente R13)*.
  - `core/meta/secret_hero_manager.gd`: Mecánica de activación de héroes secretos según probabilidad `(6 - dificultad)%`, requisito de $\ge 3000$ puntos de logro y catálogo de 6 héroes originales de ciencia ficción (ADR-06).
  - `core/events/calendar_event_manager.gd`: Eventos de calendario real (Navidad, Año Nuevo, April Fools, Halloween) con temas visuales y modificadores ambientales.
  - `export_presets.cfg`: Presets de exportación para Windows Desktop (D3D12/Vulkan) y Linux/X11 con PCK embebido (versionado en repositorio).
  - `tests/unit/test_performance_and_qa.gd` y `tests/unit/test_secret_heroes_and_calendar.gd`: Tests automatizados integrados en el test runner dinámico (245/245 tests pasando en verde).
  - `docs/LEGAL.md`: Declaración de descargo de responsabilidad y propiedad intelectual respecto a StarCraft II y Blizzard Entertainment.

## [0.13.0] — 2026-10-27
### Fase 14: UI/UX, Audio y Pulido Visual
- **Añadido:**
  - `core/tutorial/tutorial_manager.gd`: Sistema de bienvenida interactivo de 3 pasos (Mover Héroe -> Comprar Mejora -> Destruir Engendrador).
  - `core/ui/accessibility_and_color_manager.gd`: Paletas de alto contraste accesibles para daltonismo (Protanopía, Deuteranopía, Tritanopía) y factor de escala de interfaz.
  - `core/ui/localization_manager.gd`: Gestor de cadenas bilingüe (Español / Inglés) para HUD, alertas tácticas y modos de juego.
  - Integración en `tests/unit/test_ui_audio_and_polish.gd` con validación de SFXManager y texto flotante.

## [0.12.0] — 2026-10-27
### Fase 13: Multijugador Cooperativo en Red
- **Añadido:**
  - `docs/adr/ADR-01-multiplayer-architecture.md`: Documento de decisión arquitectónica (Host autoritativo con snapshots comprimidos).
  - `core/multiplayer/player_slot.gd`: Abstracción de ranuras de jugador (1 a 6 jugadores, con soporte de hasta 10 en modo dedicado).
  - `core/multiplayer/swarm_snapshot_synchronizer.gd`: Empaquetado binario ultra-comprimido (10 bytes por unidad en red: posición cuantizada + HP).
  - `core/multiplayer/network_session_manager.gd`: Lobby, votaciones democráticas de dificultad/expulsión, validación de compras en servidor y recálculo de suministro por desconexión.

## [0.11.0] — 2026-10-27
### Fase 12: Meta, Rangos, Logros y Persistencia
- **Añadido:**
  - `core/meta/rank_system.gd`: Curva de progresión pura cuadrática de SFE5 ($125L^2 + 9875L - P = 0$), rangos R hasta S-Max.
  - `core/meta/achievement_system.gd`: Motor de logros declarativo con catálogo inicial de 30 logros y desbloqueo de Torment.
  - `core/meta/game_settings.gd`: Persistencia de configuración en JSON (`user://sfe5_settings.json`).
  - `core/meta/player_profile_stats.gd`: Estadísticas de por vida serializadas en banco (`user://sfe5_bank.save`).

## [0.10.0] — 2026-10-27
### Fase 11: Modos de Juego y Consola de Desarrollo
- **Añadido:**
  - `core/modes/game_mode_manager.gd`: Motor de modos de juego (Classic, Torment, Hardcore, Nightmare, Split Income, Mutation, 10-Player).
  - `core/modes/debug_console.gd`: Consola de desarrollador accesible mediante atajo (`Ctrl+Alt+C`).
  - Catálogo de recursos `.tres` para los 8 modos en `data/modes/`.

## [0.9.0] — 2026-10-27
### Fase 10: Jefes Cúspide y Rituales de Invocación
- **Añadido:**
  - `core/bosses/summoning_ritual.gd`: 4 controladores de ritual (pisar balizas, construir estructuras, mantener zona y destruir monumentos).
  - `core/bosses/pinnacle_boss_base.gd`: Máquina de estados multifase (100%..66%, 66%..33%, <33%), canalizaciones e inmunidad selectiva.
  - `core/bosses/pinnacle_boss_catalog.gd`: Catálogo canónico con los 11 jefes (Odin, Gorgon, Diablo, Chaindog, Hybrid Behemoth, Hybrid Experimented, Eclipse, Hell's Gate, General Clinton, Celestial Kerrigan, Narud).
  - `core/bosses/boss_reward_manager.gd`: Reparto de 100k minerales, 300 puntos de rango y desbloqueo de unidades secretas en Torment.

## [0.8.0] — 2026-10-27
### Fase 9: Fases de Historia, Puzzles y Eventos
- **Añadido:**
  - `core/puzzles/f2_solver.gd`: Solucionador algebraico determinista sobre campo finito $\mathbb{F}_2$ con eliminación gaussiana XOR.
  - `core/puzzles/pedestal_puzzle_manager.gd`: Puzzle canónico de 8 pedestales con matriz circulante $C_8$ y modo de asistencia.
  - `core/story/story_phase_manager.gd`: Fases de historia (Zerg -> Protoss 1 -> Protoss 2 con 3 cristales -> Jefes Cúspide).
  - `core/events/secret_manager.gd`: Secretos de mapa (Outhouse con +10 suministro, Lagarto afortunado, Cajas misteriosas, Estación de combustible).

## [0.7.0] — 2026-10-27
### Fase 8: Presión Externa y Ataques Programados
- **Añadido:**
  - `core/events/timed_event_schedule.gd`: Cronograma de ataques de colmena cada 300 s con secuencia de 7 líderes canónicos.
  - `core/events/drop_pod_manager.gd`: Cápsulas de desembarco cinéticas contra unidades aliadas fuera del perímetro de base tras los 120 s de paz.
  - `core/events/nydus_crater_manager.gd`: 12 cráteres fijos en el mapa con 4 niveles de poder (Minor, Standard, Greater, Ultra Nydus).
  - Alertas tácticas integradas en el HUD superior con flecha de dirección y cuenta atrás.

## [0.6.0] — 2026-10-27
### Fase 6: Unidades Élite, Veteranía y Reclutamiento
- **Añadido:**
  - `core/components/elite_component.gd`: Ascenso a Élite y acumulación de veteranía (+125 daño plano y ×1.6667 velocidad de ataque al matar).
  - `core/recruitment/unit_recruitment_manager.gd`: Control de suministro estricto y unidades de apoyo de visión (Observer con bufo Ace invulnerable).
  - `core/vfx/category_ring_styler.gd`: Anillos de selección con código de color canónico SFE5 (verde, amarillo, naranja, rojo).

## [0.5.0] — 2026-10-27
### Fase 7: Dificultades, Muerte y Revivir
- **Añadido:**
  - Matriz completa de dificultades (Casual, Normal, Hard, Brutal, Torment, Impossible).
  - Pérdida escalonada de mineral (0% a 100%) y retención/pérdida de bufos en muerte según dificultad.
  - Temporizador de reaparición dinámico: $T = T_{\text{base}} + (\text{nivel} \times \Delta t)$.

## [0.4.0] — 2026-10-27
### Fase 5: Héroes y Habilidades
- **Añadido:**
  - `core/components/ability_component.gd`: Gestión de energía, recargas, tipos de lanzamiento (área, proyectil, canalización, cono).
  - `core/components/experience_component.gd`: Curva de experiencia, subida de niveles y bonificaciones por bajas.
  - 6 héroes canónicos de la Tanda A con habilidades activas e iniciales balanceadas.

## [0.3.0] — 2026-10-27
### Fase 4: Consola del Jugador, Atributos y Bufos
- **Añadido:**
  - Atributos RPG canónicos: Fuerza (+25 HP / +0.15 regen), Destreza (+daño físico / +velocidad de ataque), Inteligencia (+energía / escalado de habilidades).
  - Catálogo de 20 bufos estáticos (Tiers 1 a 4) con exclusión mutua por tier.
  - Mecánica de bufo Demiurge (cheat-death con 180 s de enfriamiento).

## [0.2.0] — 2026-10-27
### Fase 3: Engendradores y Generación del Mapa
- **Añadido:**
  - `entities/structures/spawner_node.gd`: Nidos con invulnerabilidad condicional por cadena de objetivos.
  - `levels/map_generator.gd`: Generación procedural de 50 spawners repartidos en los 4 cuadrantes del mapa.

## [0.1.0] — 2026-10-27
### Fase 1: Economía Fiel a SFE5
- **Añadido:**
  - `core/economy/income_formula.gd`: Fórmula matemática pura de ingreso pasivo por segundo: $I = \lfloor \text{round}(2.5 + 0.05 \times M) \times D_{\text{mult}} \rfloor$.
  - Anulación de recompensa por fuego cruzado entre enemigos zerg.

## [0.0.0] — 2026-10-27
### Fase 0: Higiene del Repositorio y Arquitectura Base
- **Añadido:**
  - Estructuración del repositorio, archivo de documentos obsoletos en `docs/archive/`.
  - Creación de `ROADMAP.md` unificado como único documento maestro de planificación.
  - Configuración del test runner headless en Godot 4.7.2.
