# ROADMAP — Clon de Special Forces Elite 5 (SFE5) en Godot 4.7

> **Documento único de planificación.** Sustituye a `PROJECT.md`, `PROJECT_HANDOFF.md`, `TEST_INFRA.md` y `TEST_READY.md` (archivarlos en `docs/archive/`).
> **Referencia de diseño:** `informe_sfe5_wiki_completo.md` (datos de sfe5.wiki: fórmulas, tablas, jefes, modos).
> **Regla de oro:** cada hito termina con *algo que se puede jugar y notar distinto*. Si no se puede jugar, no cuenta como hecho.

---

## Índice

0. [Cómo usar este roadmap](#0-cómo-usar-este-roadmap)
1. [Diagnóstico y principios](#1-diagnóstico-y-principios)
2. [Inventario del estado actual](#2-inventario-del-estado-actual)
3. [Mapa general de fases](#3-mapa-general-de-fases)
4. [Fase 0 — Higiene del repositorio](#fase-0--higiene-del-repositorio)
5. [Fase 1 — Economía fiel a SFE5](#fase-1--economía-fiel-a-sfe5)
6. [Fase 2 — Capa de datos (Resources)](#fase-2--capa-de-datos-resources)
7. [Fase 3 — Engendradores y generación del mapa](#fase-3--engendradores-y-generación-del-mapa)
8. [Fase 4 — Consola del jugador, atributos y bufos](#fase-4--consola-del-jugador-atributos-y-bufos)
9. [Fase 5 — Héroes y habilidades](#fase-5--héroes-y-habilidades)
10. [Fase 6 — Unidades élite, veteranía y apoyo](#fase-6--unidades-élite-veteranía-y-apoyo)
11. [Fase 7 — Dificultades, muerte y revivir](#fase-7--dificultades-muerte-y-revivir)
12. [Fase 8 — Presión externa y ataques programados](#fase-8--presión-externa-y-ataques-programados)
13. [Fase 9 — Fases de historia, puzzles y eventos](#fase-9--fases-de-historia-puzzles-y-eventos)
14. [Fase 10 — Jefes cúspide](#fase-10--jefes-cúspide)
15. [Fase 11 — Modos de juego](#fase-11--modos-de-juego)
16. [Fase 12 — Meta: rangos, logros y guardado](#fase-12--meta-rangos-logros-y-guardado)
17. [Fase 13 — Multijugador cooperativo](#fase-13--multijugador-cooperativo)
18. [Fase 14 — UI/UX, audio y pulido visual](#fase-14--uiux-audio-y-pulido-visual)
19. [Fase 15 — Rendimiento, QA y lanzamiento](#fase-15--rendimiento-qa-y-lanzamiento)
20. [Fase 16 — Extras: héroes secretos y eventos de calendario](#fase-16--extras-héroes-secretos-y-eventos-de-calendario)
21. [Ruta crítica y dependencias](#ruta-crítica-y-dependencias)
22. [Decisiones de arquitectura abiertas (ADR)](#decisiones-de-arquitectura-abiertas-adr)
23. [Riesgos y mitigaciones](#riesgos-y-mitigaciones)
24. [Métricas de progreso](#métricas-de-progreso)
25. [Plantilla de sesión de trabajo](#plantilla-de-sesión-de-trabajo)
26. [Backlog de ideas (no comprometido)](#backlog-de-ideas-no-comprometido)
27. [Apéndices](#apéndices)

---

## 0. Cómo usar este roadmap

### Convenciones
- **Tamaños:** `S` (≤ 1 sesión), `M` (2–4 sesiones), `L` (1–2 semanas), `XL` (más de 2 semanas; dividir antes de empezar).
- **Casillas:** `[ ]` pendiente · `[~]` en curso · `[x]` hecho · `[-]` descartado (anotar motivo).
- **Prioridad:** `P0` bloqueante · `P1` núcleo del juego · `P2` importante · `P3` deseable.
- **Hito jugable (HJ):** definición explícita de *qué puede hacer el jugador* al terminar la fase.
- **Criterio de hecho (CdH):** condiciones verificables. Una tarea sin CdH no está lista para empezar.

### Reglas de trabajo
1. **Una sola fase activa** (máximo dos si una es de datos/contenido). Las demás no se tocan.
2. **Nada de trabajo especulativo.** No se crean modelos, audio ni UI de algo cuyo sistema todavía no existe.
3. **Tag de Git por hito jugable** (`v0.1-economia`, `v0.2-spawners`…). Siempre se puede volver a una versión jugable.
4. **Un test por regla de negocio**, no una batería gigante por sistema. Los tests protegen fórmulas y reglas; no sustituyen a jugar.
5. **Contenido = datos.** Un héroe, bufo, jefe o engendrador nuevo debe poder añadirse creando un `.tres`, sin tocar el motor.
6. **Arte provisional primero.** Cubos, cápsulas y colores planos hasta que la mecánica esté validada.
7. **Revisión semanal de 15 min:** actualizar casillas de este archivo, mover lo que no avanza al backlog.

### Definición de "hecho" global (aplica a cualquier tarea)
- [ ] Funciona en una partida real (no solo en test headless).
- [ ] Tiene al menos un test automatizado si contiene una fórmula o regla.
- [ ] No rompe `godot --headless --path . -s tests/test_runner.gd`.
- [ ] Sin errores ni warnings nuevos en la consola del editor.
- [ ] Casilla marcada en este documento y commit con mensaje `feat(fase-N): …`.

---

## 1. Diagnóstico y principios

### 1.1 Qué es SFE5 realmente (según la wiki)
SFE5 es un **mapa cooperativo de supervivencia** (hasta 6 jugadores, 10 en modo especial) cuya identidad se sostiene en:

1. **Concentración extrema de poder** en 1–2 unidades (la dispersión se castiga).
2. **Economía por bajas**: el mineral procede de matar enemigos, con una fórmula concreta (`s^0.32`, multiplicadores por categoría y dificultad).
3. **Cadena de engendradores** (spawners) que se desbloquean en orden, con ciclo de 20 s y tope de 300 enemigos vivos.
4. **Consola de jugador** con 4 atributos, ~500 mejoras raciales y bufos en 7 niveles + bufos supremos (Ace, Demiurge, Máxima Experiencia).
5. **Variabilidad intra-partida**: mapa procedural, eventos cronometrados, puzzles (pedestales), jefes cúspide con rituales de invocación.
6. **Sin meta-progresión de poder**: cada partida empieza de cero.

### 1.2 Dónde está hoy el repo (resumen)
- Muy buena base técnica: enjambre masivo por GPU, héroe con habilidades, HUD estilo SC2, armería, torretas, pruebas headless.
- **Falta casi todo lo que define a SFE5**: cadena de engendradores, fórmula de ingresos, consola de bufos por tiers, jefes cúspide, eventos, rangos.
- El roadmap anterior planteaba "30 rondas" (no existe en SFE5) y priorizaba audio antes que bucle de juego.

### 1.3 Principios de diseño del clon
| Principio | Consecuencia práctica |
|---|---|
| Fidelidad mecánica > fidelidad visual | Primero números y reglas; luego modelos |
| Data-driven | Todo contenido en `Resource` (.tres) con esquemas tipados |
| Determinismo | Misma *seed* → mismo mapa, mismos engendradores, mismos eventos |
| Separación simulación/presentación | La lógica no depende de nodos visuales (clave para multijugador y tests) |
| Escalabilidad al caos | Diseñar pensando en 300 enemigos vivos + 6 jugadores desde el principio |
| Iteración corta | Hitos jugables pequeños, nada de "mega-fases" opacas |

### 1.4 Qué NO se hará (al menos hasta la Fase 15)
- Réplica 1:1 de los 42 héroes desde el inicio (se empieza con 6, luego 12, luego el resto).
- Los 500 upgrades raciales a mano: se generarán desde plantillas de datos.
- Marketplace, cuentas online, rankings globales.
- Fidelidad de modelos de StarCraft II (limitaciones de licencia y de tiempo). Arte propio o de assets libres.

---

## 2. Inventario del estado actual

Clasificación de lo que ya existe en el repositorio:

### 2.1 Conservar tal cual (base sólida)
| Sistema | Ubicación | Notas |
|---|---|---|
| Simulación de enjambre (SoA, flow field, spatial hash, MultiMesh) | `core/swarm/` | Es el motor de combate masivo; reutilizar para los engendradores |
| Combate (daño físico/hechizo, armadura, buff engine) | `core/combat/` | Revisar contra el modelo de daño de la wiki (ver Fase 4) |
| Héroe jugable con habilidades Q/W/E/R | `entities/allies/hero_unit_3d.gd` | Dividir en componentes (ver Fase 5) |
| Cámara RTS y selección | `levels/rts_camera_3d.gd`, controlador RTS | Mantener |
| HUD SC2 (minimapa, panel, tarjeta de órdenes) | `ui/` | Mantener; adaptar a la consola SFE5 |
| Datos de héroes y habilidades | `data/heroes/`, `data/skills/` | 12 héroes y 23 habilidades: buen punto de partida |
| Infraestructura de tests headless | `tests/test_runner.gd` | Mantener; podar tests redundantes |
| Pedestales (esqueleto) | `core/puzzles/`, `levels/pedestal_node.gd` | Completar con el solver (Fase 9) |
| Eventos secretos (esqueleto) | `core/events/` | Hell's Gate y zona secreta: punto de partida para jefes |

### 2.2 Refactorizar
| Elemento | Problema | Acción |
|---|---|---|
| `core/wave_manager.gd` (130 líneas) | Oleadas con conteos fijos por ronda | Sustituir por `SpawnerChain` (Fase 3); mantener solo como modo opcional "Rondas" |
| `core/economy/sfe_economy_manager.gd` | Bounty plano × multiplicador | Reescribir con la fórmula maestra (Fase 1) |
| `core/upgrades/armory_upgrade_manager.gd` | Mejoras en 5 tiers fijos | Migrar a consola de atributos + bufos por tier (Fase 4) |
| `levels/main_level.gd` (820 líneas) | Orquesta demasiadas cosas | Dividir: `GameSession`, `LevelBuilder`, `HudBinder` |
| `entities/allies/hero_unit_3d.gd` (853 líneas) | Monolito | Componentes: `StatsComponent`, `AbilityComponent`, `ExperienceComponent`, `BuffComponent` |
| `project.godot` | Nombre "Nuevo Proyecto de Juego"; solo 1 autoload | Renombrar, registrar autoloads reales |

### 2.3 Congelar (no tocar hasta nueva orden)
- Pipeline de modelos `.glb` y generación procedural de meshes/audio (`tools/`).
- Benchmarks de enjambre (`core/swarm/swarm_benchmark.gd`, `tests/stress_*`): útiles, pero la optimización ya es suficiente.
- Tests "forensic/adversarial/empirical" (`tests/*audit*`, `tests/*challenger*`): archivar en `tests/legacy/` y quedarse con la batería principal.

### 2.4 Inconsistencias a resolver en Fase 0
- Docs mencionan `BossBrutalisk3D` y `BossHybrid3D`; el repo tiene `boss_nydus_3d` y `boss_omega_ultralisk_3d`.
- Docs mencionan `SFXManager` y `core/audio/`; no existen.
- La estructura de carpetas en docs usa rutas de Windows (`e:\Juego Godot\`); limpiar.
- README afirma métricas (110/110 tests, >1000 unidades a 75–95 FPS) que deben revalidarse y fecharse.

---

## 3. Mapa general de fases

| Fase | Nombre | Prioridad | Tamaño | Hito jugable al terminar |
|---|---|---|---|---|
| 0 | Higiene del repositorio | P0 | S | Proyecto limpio, tests verdes, docs unificadas |
| 1 | Economía fiel a SFE5 | P0 | M | Cada baja da el mineral correcto según dificultad |
| 2 | Capa de datos | P0 | M | Añadir una unidad/bufo/engendrador = crear un `.tres` |
| 3 | Engendradores y mapa | P1 | XL | Cadena de engendradores funcional, partida con objetivo |
| 4 | Consola, atributos y bufos | P1 | XL | Compras de atributos y bufos tier 1–7 |
| 5 | Héroes y habilidades | P1 | XL | 6 → 12 → 42 héroes, selección y progresión |
| 6 | Élite, veteranía, apoyo | P2 | L | Convertir un marine en unidad élite; unidades de visión |
| 7 | Dificultades, muerte, revivir | P1 | M | Penalizaciones y ritmo por dificultad |
| 8 | Presión externa | P2 | L | Drop pods, nydus y ataques cada 5 min |
| 9 | Historia, puzzles, eventos | P2 | XL | Fases Protoss, cristales, pedestales |
| 10 | Jefes cúspide | P1 | XL | Primer jefe con ritual de invocación; luego los 11 |
| 11 | Modos de juego | P2 | L | Classic, Hardcore, Nightmare, Mutation… |
| 12 | Meta: rangos, logros, banks | P3 | L | Rango, logros y guardado persistente |
| 13 | Multijugador cooperativo | P2 | XL | 2–6 jugadores en red |
| 14 | UI/UX, audio, pulido | P2 | XL | Experiencia presentable |
| 15 | Rendimiento, QA, lanzamiento | P1 | L | Versión 1.0 estable |
| 16 | Extras | P3 | M | Héroes secretos, eventos de calendario |

### Hitos de versión (para etiquetas Git)
| Versión | Contiene | Se considera "jugable" cuando… |
|---|---|---|
| `v0.1` | Fases 0–2 | La economía responde a la fórmula y hay catálogo de datos |
| `v0.2` | Fase 3 (parcial) | Una cadena de 3 engendradores se juega de principio a fin |
| `v0.3` | Fase 4 (parcial) | Puedo comprar atributos y 3 bufos |
| `v0.4` | Fases 5 + 7 (parciales) | 6 héroes y dificultades con penalización |
| `v0.5` | Fase 10 (1.er jefe) | Puedo invocar y vencer a un jefe cúspide |
| `v0.6` | Fases 8 + 9 (parciales) | Ataques programados y primer puzzle |
| `v0.7` | Fase 11 | Modos Classic / Hardcore / Nightmare |
| `v0.8` | Fase 13 | Multijugador básico |
| `v0.9` | Fases 12 + 14 | Meta, UI y audio presentables |
| `v1.0` | Fase 15 | Release |

---

## Fase 0 — Higiene del repositorio
**Prioridad:** P0 · **Tamaño:** S · **Dependencias:** ninguna
**HJ:** abro el proyecto, pulso F5, juego igual que antes, pero el repo es legible y todos los tests pasan.

### Tareas
- [x] **0.1** Renombrar el proyecto en `project.godot` (`config/name="SFE5 — Godot"`). `S`
- [x] **0.2** Crear `docs/archive/` y mover `PROJECT.md`, `PROJECT_HANDOFF.md`, `TEST_INFRA.md`, `TEST_READY.md`. Dejar `README.md` corto + este `ROADMAP.md`. `S`
- [x] **0.3** Reescribir `README.md`: qué es, cómo ejecutar, controles, enlace al roadmap. Quitar métricas no verificadas o fecharlas. `S`
- [x] **0.4** Mover tests de auditoría/adversariales/empíricos a `tests/legacy/`; el runner principal solo carga `tests/unit/` y `tests/integration/`. `M`
- [x] **0.5** Ejecutar la batería actual y anotar el resultado real (nº de tests, tiempo, fallos). `S`
- [x] **0.6** Registrar autoloads reales: `SignalBus`, `GameSession`, `GameConfig` (vacíos al principio). `S`
- [x] **0.7** Añadir `.gitignore` completo (`.godot/`, `*.import` según criterio, `export_presets.cfg` local). `S`
- [x] **0.8** Crear estructura de carpetas objetivo (ver Apéndice B). `S`
- [x] **0.9** Configuración de GitHub Actions: ejecutar tests headless en cada push (imagen `barichello/godot-ci` o similar). `M`
- [x] **0.10** Plantilla de commits (`feat|fix|refactor|test|docs(fase-N): mensaje`). `S`
- [x] **0.11** Crear etiqueta `v0.0-base` con el estado actual. `S`
- [x] **0.12** Documento `docs/DESIGN_NOTES.md` con enlace al informe de la wiki y decisiones de diseño. `S`

### CdH
- `git clone` + abrir en Godot + F5 = nivel jugable, sin errores rojos.
- CI en verde en GitHub.
- `README.md` < 80 líneas; `ROADMAP.md` es la única fuente de planificación.

---

## Fase 1 — Economía fiel a SFE5
**Prioridad:** P0 · **Tamaño:** M · **Dependencias:** Fase 0
**HJ:** al matar enemigos de distinta categoría y dificultad, recibo cantidades de mineral coherentes con la wiki, y el mineral inicial y el suministro dependen del número de jugadores.

### 1.1 Fórmula maestra (según wiki)
Implementar como **función pura** (sin nodos), en `core/economy/income_formula.gd`:

```
Vida_eff   = VidaBase   × MultVida
Escudo_eff = EscudoBase × MultVida
Daño_eff   = DañoArma   × MultDaño

s = (Vida_eff + Escudo_eff)/3 + Daño_eff / PeriodoAtaque        # unidad armada
s = ((Vida_eff + Escudo_eff)/3) × 2                             # unidad desarmada
si EnergíaMax > 0:  s = s × (EnergíaMax / 50)

si s > 500000:  s = ((s/10)^0.32) × 3
si no:          s = s^0.32

Split Income:   s = s × 10 × 0.9
Compartido:     s = s × 4 × ((12 − Jugadores) / 4)
                s = s × 0.24                                    # incomeRate

Multiplicadores de categoría:
  Estructura ×8 · Heroica ×4 · Élite/MapBoss ×6 · Jefe invocado ×2 · Jefe principal ×6

+ BonoPedestal (si el puzzle está resuelto)
mínimo garantizado: 1
```
> ⚠ Contrastar con la calculadora `/income` de sfe5.wiki: guardar 20+ casos de referencia como tests. Las divergencias se documentan en `docs/DESIGN_NOTES.md`.

### Tareas
- [x] **1.1** `IncomeFormula.compute(params: IncomeParams) -> int` con todas las ramas (armada/desarmada/energía/overflow/split/compartido). `M`
- [x] **1.2** `IncomeParams` (Resource/RefCounted): vida, escudo, daño, periodo, energía, categoría, nº jugadores, split, handicap, bono pedestal, multiplicadores de dificultad. `S`
- [x] **1.3** Tabla de casos de referencia `tests/unit/income_reference_cases.json` (mínimo 20: zergling, roach, hydra, ultralisk, estructura, héroe, élite, jefe invocado, jefe principal, desarmada, con energía, overflow >500k, split, 1 vs 6 jugadores). `M`
- [x] **1.4** Test que recorre los casos y compara con tolerancia ±1. `S`
- [x] **1.5** Reemplazar `base_bounty` en `SFEEconomyManager.process_kill` por la fórmula. Mantener la **regla de Crossfire Nullification** solo si se confirma que existe en SFE5 (ver ADR-03). `M`
- [x] **1.6** Minerales iniciales = `12000 / nº jugadores`; bono Random Hero = `15000 / nº jugadores`. `S`
- [x] **1.7** Suministro: 80 en solitario; −10 por jugador extra; mínimo 30; recalcular al abandonar. Bono +10 del secreto *Outhouse* (stub). `S`
- [x] **1.8** Multiplicador de ingreso por dificultad (Casual ×1.15 … Impossible ×0.30). `S`
- [x] **1.9** Distribución del botín: compartido entre jugadores vs `Split Income` (el asesino se lo lleva todo con handicap 0.9). `M`
- [x] **1.10** Texto flotante `+N` con color por categoría (verde estructura, amarillo heroica, naranja élite, rojo jefe). `S`
- [x] **1.11** Panel de depuración (F3): última baja, parámetros, `s` intermedio, resultado. `S`
- [x] **1.12** Estadísticas de partida: minerales totales ganados, por fuente, por minuto. `S`
- [x] **1.13** Etiqueta `v0.1-economia` tras validar que todo lo anterior pasa en tests y en juego real. `S`

### CdH
- 20+ casos de referencia pasando.
- Una partida de 5 min con 1 y con 6 jugadores simulados muestra economías distintas.
- Cambiar la dificultad cambia el ingreso sin tocar código.

---

## Fase 2 — Capa de datos (Resources)
**Prioridad:** P0 · **Tamaño:** M · **Dependencias:** Fase 0
**HJ:** puedo crear un nuevo enemigo, bufo o engendrador duplicando un `.tres` y verlo en partida.

### Esquemas principales (`core/data/`)
| Resource | Campos clave |
|---|---|
| `UnitData` | id, nombre, raza, categoría (normal/heroica/élite/estructura/jefe), vida, escudo, armadura, daño, periodo de ataque, alcance, velocidad, energía máx., tags (aéreo, camuflado, penetra-armadura…), escena |
| `HeroData` | extiende `UnitData` + atributos base, habilidades, curva de nivel, retrato |
| `AbilityData` | id, tipo (activa/pasiva/aura), coste de energía, enfriamiento, efectos, objetivo |
| `BuffData` | id, tier (1–7 o suprema), nombre, coste, efectos modulares, condiciones (quieto, moviéndose, sin daño, energía al 100 %) |
| `UpgradeData` | id, categoría (daño, armadura, vida, energía, vel. ataque), raza, nivel, coste, efecto |
| `SpawnerData` | id, familia, nivel, unidad(es), tamaño de grupo, ciclo (20 s), requisito (spawner anterior), bufos al destruirse |
| `BossData` | extiende `UnitData` + ritual, fases, habilidades, recompensa (100.000 min., 300 puntos) |
| `EventData` | id, disparador, temporizador, recompensas, condiciones |
| `DifficultyData` | multiplicador de ingreso, tiempo de revivir, incremento por nivel, mineral perdido, bufos perdidos |
| `ModeData` | reglas activables (sin bufos, sin protoss, split income, nightmare…) |

### Tareas
- [x] **2.1** Definir las clases `Resource` con `class_name`, tipado estricto y `@export` documentados. `M`
- [x] **2.2** `DataCatalog` (autoload): carga recursiva de `res://data/**/*.tres`, índices por id, validación al arranque. `M`
- [x] **2.3** Validador de datos (herramienta de editor): detecta ids duplicados, referencias rotas, valores fuera de rango. `M`
- [x] **2.4** Migrar `data/heroes/*.tres` (12) y `data/skills/*.tres` (23) a los nuevos esquemas. `M`
- [x] **2.5** Migrar `data/enemies/` (zergling, roach) y añadir banshee, hydralisk, baneling, ultralisk como datos. `M`
- [x] **2.6** Migrar `data/buffs/` (5) al nuevo `BuffData` con tiers. `S`
- [x] **2.7** Documento `docs/DATA_GUIDE.md`: cómo añadir una unidad, un bufo, un engendrador. `S`
- [x] **2.8** Test: el catálogo carga sin errores y todos los ids son únicos. `S`
- [x] **2.9** Script de importación opcional CSV→`.tres` para generar masivamente mejoras (preparación de Fase 4). `M`

### CdH
- Añadir un enemigo nuevo solo con un `.tres` + escena (sin tocar `.gd` del motor).
- Validador devuelve 0 errores sobre todo `data/`.

---

## Fase 3 — Engendradores y generación del mapa
**Prioridad:** P1 · **Tamaño:** XL · **Dependencias:** Fases 1, 2
**HJ:** la partida tiene un objetivo claro: destruir engendradores en cadena mientras el enemigo presiona a la base.

### 3.1 Reglas (según wiki)
- Ciclo de **20 s**.
- **Invulnerable** hasta que se destruya el engendrador del eslabón anterior.
- **Tope de 300 enemigos vivos**: si se supera, los engendradores pausan su producción.
- **Enemigos coloreados:** al destruir el engendrador de una clase, esa clase adquiere bufos aleatorios permanentes (color en modelo + salto de estadísticas).
- **Penetración de armadura:** Ravager, Vile Ravager, Hunter Killer, Lurker, Hybrid Nemesis ignoran la armadura.
- Generación procedural: **mezcla de familias** de engendradores y defensas por partida.

### 3.2 Tareas — Núcleo
- [x] **3.1** `SpawnerNode` con temporizador de ciclo, estado (bloqueado/activo/destruido) y señales. `M`
- [x] **3.2** `SpawnerChain`: grafo de dependencias (qué engendrador libera cuál). `M`
- [x] **3.3** Invulnerabilidad condicional + indicador visual (escudo/ícono de candado) y tooltip. `S`
- [x] **3.4** `EnemyBudgetManager`: contador global de vivos; pausa de producción al superar 300 (valor configurable en `GameConfig`). `S`
- [x] **3.5** Integración con `SwarmSimulation`: los engendradores inyectan unidades en la simulación masiva (no instancias de nodo individuales). `L`
- [x] **3.6** Sistema de "clase de enemigo" (zerglings, roaches, hydras…) como entidad lógica con su lista de bufos. `M`
- [x] **3.7** **Enemigos coloreados:** al destruir el engendrador de una clase, sortear bufos permanentes, aplicar color por shader (parámetro por instancia en MultiMesh) y ajustar estadísticas. `L`
- [x] **3.8** Flag `ignora_armadura` en `UnitData` y respeto en `SFECombatEngine`. `S`
- [x] **3.9** Retirar `WaveManager` por rondas del flujo por defecto (dejarlo tras `ModeData.rondas`). `M`

### 3.3 Tareas — Generación procedural
- [x] **3.10** `MapSeed`: semilla única de partida (mostrada en UI y copiable). `S`
- [x] **3.11** `SpawnerFamily` (Resource): familia de engendradores (p. ej. "Zergling Nest", "Roach Warren", "Hydra Den") con niveles. `M`
- [x] **3.12** `MapGenerator`: elige familias, las coloca en puntos de interés del nivel, construye la cadena. Determinista por seed. `L`
- [x] **3.13** Colocación de defensas enemigas (cañones, torres, spores) por familia. `M`
- [x] **3.14** Puntos de aparición fijos en el nivel (`Marker3D`) y reglas de separación mínima. `S`
- [x] **3.15** Nivel de prueba reducido (arena pequeña) para validar la cadena sin cargar el mapa completo. `M`
- [x] **3.16** Minimapa: iconos de engendradores (bloqueado/activo/destruido). `S`

### 3.4 Tareas — Bucle de victoria/derrota
- [x] **3.17** Fortaleza Planetaria (`PlanetaryFortress`): vida, mejoras, derrota inmediata al caer. (Hoy: `CommandCenter`.) `M`
- [x] **3.18** Objetivo de victoria: erradicar todas las estructuras enemigas, nidos, oleadas y jefes. `M`
- [x] **3.19** Pantalla de fin de partida con estadísticas (tiempo, bajas, minerales, spawners destruidos). `M`

### 3.5 Tests
- [x] **3.T1** Un engendrador bloqueado no recibe daño; al caer el anterior, sí.
- [x] **3.T2** Con 300 vivos no se genera ningún enemigo más; baja a 299 y se reanuda.
- [x] **3.T3** Misma seed → misma cadena y colocación (hash de la configuración).
- [x] **3.T4** Clase con bufos coloreados: estadísticas cambian tras destruir su engendrador.

### CdH
- Partida de principio a fin con 3 engendradores encadenados + victoria y derrota funcionales.
- Los 300 enemigos se mantienen a ≥ 60 FPS en tu equipo de referencia (ver Fase 15).

---

## Fase 4 — Consola del jugador, atributos y bufos
**Prioridad:** P1 · **Tamaño:** XL · **Dependencias:** Fases 1, 2
**HJ:** abro la consola (Alt+C), compro atributos y bufos y noto que mi unidad se vuelve mucho más fuerte; concentrar mineral en una unidad compensa más que dispersarlo.

### 4.1 Atributos (según wiki)
| Atributo | Efecto |
|---|---|
| Fuerza | Vida máxima + daño físico/cuerpo a cuerpo |
| Destreza | Velocidad de ataque, evasión, daño a distancia |
| Inteligencia | Energía máx., regeneración, potencia de habilidades |
| Aguante | Resistencia, armadura, regeneración de vida |
- **Shift + clic:** invierte *todo* el mineral restante en un atributo.
- *Neutron Armor* es una mejora de reducción fija, no un atributo.

### 4.2 Orden de poder recomendado (flujo de la wiki)
```
Mejoras propias de la unidad  →  Mejoras raciales primarias (~500)  →  Bufos de consola (T1–T7 + Ace + Demiurge)  →  Atributos puros
```

### 4.3 Tareas — Consola
- [x] **4.1** `PlayerConsole` (UI): pestañas *Unidad / Raza / Bufos / Atributos*. Atajo **Alt+C**. `L`
- [x] **4.2** Selección de la unidad objetivo de la compra (heredada de la selección actual). `S`
- [x] **4.3** Previsualización de coste y efecto antes de comprar. `M`
- [x] **4.4** Tooltips con valor actual → valor tras compra. `S`
- [x] **4.5** Soporte Shift (gastar todo) y Ctrl (comprar ×5, opcional). `S`

### 4.4 Tareas — Atributos y mejoras
- [x] **4.6** `StatsComponent`: base + atributos + mejoras + bufos → estadística efectiva; caché con invalidación por señal. `L`
- [x] **4.7** Curva de coste por atributo (progresiva) en `GameConfig`. `S`
- [x] **4.8** Mejoras raciales: 5 categorías (daño, armadura, vida, energía, vel. ataque) × 3 razas × N niveles. Generar `.tres` desde plantilla (tarea 2.9). `L`
- [ ] **4.9** Mejoras específicas de unidad (baratas y críticas) para cada héroe/unidad inicial. `L`
- [x] **4.10** *Neutron Armor* como mejora independiente. `S`

### 4.5 Tareas — Bufos por tier
Implementar un `BuffComponent` con **un bufo activo por tier** (máx. 7 + supremos).

| Tier | Rol | Bufos a implementar (primera tanda) |
|---|---|---|
| 1 | Utilidad/Visión | **Optical Lens** (camuflaje si no recibes daño 2 s) |
| 2 | Defensa temprana | Mitigación plana, regeneración de escudo/vida |
| 3 | Daño dinámico | **Momentum** (hasta 5 acumulaciones moviéndote, +5 % c/u), **Predator** (+100 % vs heroicos; +150 % tras 5 s sin daño) |
| 4 | Control de daño y energía | **Static Charge** (hasta 10 cargas: +1 % daño, +2 reg/s), **Quantum Field** (energía 100 % → +75 % daño de hechizo 4 s), **Enhanced Regeneration** |
| 5 | Crítico | Multiplicadores de crítico y penetración |
| 6 | Posicionamiento | **Bulwark/Braced** (+5 % acumulable hasta quieto) |
| 7 | Maestría | Amplificación porcentual de raza + vida masiva |

- [x] **4.11** Motor de condiciones de bufo (quieto, en movimiento, sin daño en N s, energía al 100 %, en combate). `M`
- [x] **4.12** Bufos T1–T2. `M`
- [x] **4.13** Bufos T3 (Momentum, Predator). `M`
- [x] **4.14** Bufos T4 (Static Charge, Quantum Field, Enhanced Regeneration). `M`
- [x] **4.15** Bufos T5–T7. `L`
- [x] **4.16** Restricción: un bufo por tier por unidad; reemplazo con reembolso parcial configurable. `S`
- [ ] **4.17** HUD: iconos de bufos activos con acumulaciones y temporizadores. `M`

### 4.6 Tareas — Bufos supremos
- [x] **4.18** **Ace (As):** se compra o se gana al matar colosos (Reinas, Brutaliscos, Jefes). Invulnerabilidad total en soporte/visión; mejoras grandes en combatientes. `M`
- [x] **4.19** **Demiurge:** evita una muerte fatal (cheat-death), reutilización 180 s. `M`
- [x] **4.20** **Máxima Experiencia (nivel 100):** 75.000 minerales; reembolsa 750 por cada nivel ya poseído. `S`

### 4.7 Daño y calculadora
- [ ] **4.21** Pipeline de daño: base → mejoras primarias → bufos estáticos → bufos de postura → debufos del objetivo (p. ej. Ghost EMP) → auras → stacks de élite. `L`
- [ ] **4.22** Modo depuración: desglose del daño paso a paso (equivalente a `/calculator/damage`). `M`
- [ ] **4.23** Debufos y auras: sistema genérico `AuraComponent` / `DebuffComponent`. `M`

### 4.8 Tests
- [x] **4.T1** Momentum: acumula 5 stacks moviéndose, se disipa al parar.
- [x] **4.T2** Un bufo por tier: comprar otro del mismo tier lo reemplaza.
- [x] **4.T3** Demiurge evita la muerte y entra en 180 s de enfriamiento.
- [x] **4.T4** Nivel 100: coste y reembolso correctos para varios niveles iniciales.
- [x] **4.T5** Pipeline de daño: casos de referencia contra calculadora de la wiki.

### CdH
- Un marine con 3 bufos y mejoras duplica su DPS de forma medible y visible.
- El test de "concentración" (ver Apéndice D) muestra que 1 unidad con X mineral > 5 unidades con X/5 cada una.

---

## Fase 5 — Héroes y habilidades
**Prioridad:** P1 · **Tamaño:** XL · **Dependencias:** Fases 2, 4
**HJ:** elijo entre varios héroes con habilidades distintas, subo de nivel y sus habilidades escalan con mis atributos.

### 5.1 Estrategia por oleadas de contenido
| Tanda | Héroes | Objetivo |
|---|---|---|
| A | 6 (Marine, Raynor, Tychus, Nova, Zeratul, Tassadar) | Validar el sistema |
| B | 12 (+ Medic, Ghost, Marauder, Reaper, Spectre, secreto) | Cobertura Terran/Protoss básica |
| C | 24 | Representación de las 3 razas |
| D | 42 | Catálogo completo |

### Tareas
- [x] **5.1** `AbilityComponent`: energía, enfriamientos, lanzamiento (objetivo/punto/sin objetivo), cola de órdenes. `L`
- [x] **5.2** Biblioteca de **efectos reutilizables** (daño en área, aturdimiento, curación, invisibilidad, proyectil, invocación, tormenta). `L`
- [x] **5.3** `ExperienceComponent`: curva de niveles, XP por baja, subida con eventos visuales. `M`
- [x] **5.4** Escalado de habilidades con Inteligencia (daño/duración/enfriamiento). `M`
- [x] **5.5** Pasivas y auras de héroe (p. ej. Tychus pasivo ya existente). `M`
- [x] **5.6** Selector de héroe con descripción, estadísticas base y vista previa. `M`
- [x] **5.7** **Random Hero** (+15.000/jugadores de mineral). `S`
- [x] **5.8** Tanda A: pulir 6 héroes con habilidades finales + tests de cada habilidad. `L`
- [ ] **5.9** Tanda B: 6 héroes más. `L`
- [ ] **5.10** Tanda C: 12 héroes (zerg incluidos). `XL`
- [ ] **5.11** Tanda D: 18 héroes restantes. `XL`
- [x] **5.12** Equilibrado inicial con hoja de cálculo (`docs/balance/heroes.csv`). `M`
- [ ] **5.13** Retratos, iconos y animaciones provisionales (placeholders coherentes). `M`
- [x] **5.14** Habilidades que consumen el estado del bufo (p. ej. Quantum Field + habilidad). `S`

### Plantilla de héroe (para cada nuevo héroe)
```
[ ] .tres de HeroData con estadísticas base y atributos iniciales
[ ] 3–4 habilidades (AbilityData) con efectos de la biblioteca
[ ] Escena con VisualRoot + placeholder
[ ] Test de smoke: spawn, lanzar cada habilidad, morir, revivir
[ ] Entrada en hoja de equilibrado
```

### CdH
- Tanda A completa y jugable; cada héroe se siente distinto en 5 minutos de partida.

---

## Fase 6 — Unidades élite, veteranía y apoyo
**Prioridad:** P2 · **Tamaño:** L · **Dependencias:** Fases 4, 5
**HJ:** compro Veteranía para un marine y se convierte en unidad élite que acumula stacks al matar.

### Tareas
- [x] **6.1** Compra de **Veteranía**: convierte cualquier unidad normal en `Élite`. `M`
- [x] **6.2** Stacks de élite por baja: hasta **+125 de daño plano** y **×1.6667 de velocidad de ataque**. `M`
- [x] **6.3** Reclutamiento de unidades base (marine, zealot, zergling…) con coste y suministro. `M`
- [x] **6.4** Control de suministro: bloqueo de reclutamiento al llegar al límite. `S`
- [x] **6.5** **Unidades de visión:** Blimp, Observer, Overseer. Con Ace → invulnerables. Bufo *Optical Lens* de exploración. `M`
- [ ] **6.6** **Transporte:** Medivac, Warp Prism, Overlord (transporte aéreo seguro). `M`
- [ ] **6.7** **Teletransporte racial:** Einstein-Rosen Bridge, Recall Station, Remote Nydus Network. `L`
- [x] **6.8** Iconografía de categoría (anillos de color: verde/amarillo/naranja/rojo). `S`

### CdH
- Una unidad élite acumula stacks visibles y su DPS sube según la fórmula.
- Un Observer con Ace explora el mapa sin morir.

---

## Fase 7 — Dificultades, muerte y revivir
**Prioridad:** P1 · **Tamaño:** M · **Dependencias:** Fases 1, 4
**HJ:** elijo dificultad y sufro las penalizaciones correspondientes al morir.

### Tabla de referencia
| Dificultad | Ingreso | Revivir base | +por nivel | Mineral perdido | Pérdida de bufos |
|---|---|---|---|---|---|
| Casual | ×1.15 | 15 s | +0.3 s | 0 % | Ninguna |
| Normal | ×1.00 | 20 s | +0.4 s | 25 % | 25 % coste retenido |
| Hard | ×0.80 | 30 s | +0.6 s | 50 % | 50 % coste retenido |
| Brutal | ×0.70 | 40 s | +0.9 s | 75 % | 75 % coste retenido |
| Torment | ×0.60 | 40 s | +0.9 s | 100 % | 100 % |
| Impossible | ×0.30 | 40 s | +0.9 s | 100 % | 100 % |

### Tareas
- [x] **7.1** `DifficultyData` (.tres) × 6 con la tabla anterior. `S`
- [x] **7.2** Votación de dificultad en la sala previa (modo local: selector). `M`
- [x] **7.3** Muerte de héroe: pérdida de mineral y de bufos según dificultad. `M`
- [x] **7.4** Tiempo de revivir = base + (incremento × nivel). Cuenta atrás en HUD. `S`
- [x] **7.5** Reaparición en la base con invulnerabilidad breve. `S`
- [x] **7.6** Escalado de enemigos por dificultad (vida/daño/densidad). `M`
- [x] **7.7** Bloqueo de Torment/Impossible por logros (placeholder hasta Fase 12). `S`
- [x] **7.8** Tests de cálculo de penalizaciones por dificultad. `S`

### CdH
- Misma partida en Casual y en Brutal: diferencias evidentes en ingresos, muertes y tiempos.

---

## Fase 8 — Presión externa y ataques programados
**Prioridad:** P2 · **Tamaño:** L · **Dependencias:** Fases 3, 7
**HJ:** la partida tiene pulso: no puedo quedarme quieto, me llegan amenazas externas y ataques cada 5 minutos.

### Tareas
- [ ] **8.1** **Drop Pods:** cada 45 s (tras 120 s de tregua) caen cápsulas sobre unidades del jugador fuera de la base. `M`
- [ ] **8.2** **Nydus Worms:** emergen de 12 cráteres fijos a partir de la Fase Protoss 1; potencia escalada (Minor → Ultra Nydus) con el nivel de engendrador. `L`
- [ ] **8.3** **Ataques programados** cada 300 s desde la Colmena hacia la base. `M`
- [ ] **8.4** Secuencia de líderes de oleada: 1 Infested General → 3 Rageling → 5 Hellbringer → 7 Brood Emperor → 9 Hybrid Viper → 11 Hybrid Lenkus → 13 Ferocious Brutes. `L`
- [ ] **8.5** Tras vencer la oleada 13, el tiempo de invocación de jefes se divide entre 3. `S`
- [ ] **8.6** Avisos en HUD con cuenta atrás y dirección (flechas en minimapa). `M`
- [ ] **8.7** Estructura de datos `TimedEventSchedule` para registrar todos los eventos cronometrados. `M`
- [ ] **8.8** Tests: calendario de eventos determinista según seed. `S`

### CdH
- 20 minutos de partida con drop pods, 3 ataques programados y un nydus.

---

## Fase 9 — Fases de historia, puzzles y eventos
**Prioridad:** P2 · **Tamaño:** XL · **Dependencias:** Fases 3, 8
**HJ:** progreso a través de fases (Protoss 1, Protoss 2 con cristales Xel'Naga) y resuelvo el puzzle de los pedestales para obtener un bono permanente.

### Tareas — Fases de historia
- [ ] **9.1** `StoryPhaseManager`: estados (Zerg → Protoss 1 → Protoss 2 → Jefes cúspide). `L`
- [ ] **9.2** Disparadores de cada fase (engendradores destruidos, hitos). `M`
- [ ] **9.3** Enemigos Protoss y sus familias de engendradores. `L`
- [ ] **9.4** **Cristales Xel'Naga** (Fase Protoss 2): comportamiento y ritual. `M`
- [ ] **9.5** Cambios ambientales por fase (iluminación, sonido, efectos). `M`

### Tareas — Puzzle de pedestales
Regla: 8 pedestales en anillo; cada pulsación invierte el pedestal y sus **dos vecinos adyacentes**.
- [ ] **9.6** `PedestalPuzzleManager`: estado de 8 bits, toggle con vecinos, detección de resolución. `M`
- [ ] **9.7** **Solucionador en F₂:** resolver `A·x = b` sobre el cuerpo de 2 elementos (eliminación gaussiana con XOR; matriz circulante). `M`
- [ ] **9.8** Modo "ayuda" en depuración: resalta qué pedestales pulsar. `S`
- [ ] **9.9** Recompensa: activa el `BonoPedestal` plano en la fórmula de ingresos. `S`
- [ ] **9.10** Generación del estado inicial del puzzle por seed (siempre resoluble). `S`
- [ ] **9.11** Tests: todas las 2⁸ configuraciones → determinar cuáles son resolubles y verificar el solver. `S`

### Tareas — Eventos y secretos
- [ ] **9.12** **Cajas de cartón (Mystery Boxes)** y lagartos (*Lucky Lizard*) distribuidos por seed. `M`
- [ ] **9.13** Secreto *Outhouse* (+10 supply a todos). `S`
- [ ] **9.14** Evento de la Estación de Gas ("Fueling Up"). `M`
- [ ] **9.15** Eventos de Mengsk (silla/estatua), Voice of the Abyss y antena SR-04 (se enlazan con rituales de jefes, Fase 10). `M`
- [ ] **9.16** Lector de código de partida (equivalente a `/match`): mostrar seed y su contenido. `M`

### CdH
- Resuelvo el puzzle con ayuda del solver y observo el bono en el ingreso.
- Una partida completa recorre las fases de historia hasta la apertura de jefes.

---

## Fase 10 — Jefes cúspide
**Prioridad:** P1 · **Tamaño:** XL · **Dependencias:** Fases 3, 4, 9
**HJ:** completo un ritual, invoco un jefe cúspide, lo derroto y recibo 100.000 minerales y 300 puntos de rango.

### Marco general
- Se habilitan tras la **Fase Protoss 2**.
- Recompensa por jefe: **100.000 minerales** y **300 puntos de rango**.
- En Torment desbloquean unidades secretas de forma permanente.

### Tareas — Infraestructura
- [ ] **10.1** `PinnacleBoss` base: fases, habilidades, barra de vida (reaprovechar UI de jefe), recompensas. `L`
- [ ] **10.2** `SummoningRitual` (Resource + nodo): tipos de ritual reutilizables (pisar balizas, construir N estructuras, destruir objetivos, mantener posición, meter N unidades en zona). `L`
- [ ] **10.3** Barra de vida cinematográfica con muescas de fase y barra de canalización. `M`
- [ ] **10.4** Sistema de recompensas de jefe y de puntos de rango. `S`
- [ ] **10.5** Tests de ritual: simulación de cumplimiento y de fallo. `M`

### Tareas — Los 11 jefes (uno por uno, en este orden sugerido)
| # | Jefe | Ritual | Complejidad |
|---|---|---|---|
| 1 | **Odin, Titan of Armageddon** | Pisar 3 balizas raciales en la diagonal NO–SE | S |
| 2 | **Gorgon, the Skycleaver** | Construir 4 estructuras en el perímetro de la antena SR-04 | M |
| 3 | **Diablo, Lord of Terror** | Evento Estación de Gas + resistir oleadas | M |
| 4 | **Chaindog, the Mauler** | Unidad en las sillas frente a la estatua de Mengsk; mantener zona; destruir estatua | M |
| 5 | **Hybrid Behemoth** | Mantener posición junto al Cristal Xel'Naga; destruir un Cristal del Vacío | M |
| 6 | **Hybrid Experimented** | Igual, por la ruta del cristal opuesto | S |
| 7 | **Eclipse, Destroyer of Worlds** | Unidad sobre el respiradero junto a la Nave Nodriza | M |
| 8 | **Hell's Gate** | 6 unidades heroicas junto a *Voice of the Abyss* | M |
| 9 | **General Clinton** | 20 unidades en la antena "20"; lanza bomba nuclear sobre quien dé el golpe final | L |
| 10 | **Celestial Kerrigan** | Activar el Elemental Slayn → la Reina de Espadas renace celestial | L |
| 11 | **Narud, Servant of Amon** | Destruir 4 Vestigios Antiguos (5 clics rápidos para romper invulnerabilidad). **Concluye la partida.** | L |

- [ ] **10.6–10.16** Un jefe por tarea, con: datos (`BossData`), escena provisional, 2–3 habilidades, ritual, recompensa, test. Cada una `M`–`L`.
- [ ] **10.17** Reutilizar `boss_nydus_3d` y `boss_omega_ultralisk_3d` existentes como base para jefes de prueba. `S`
- [ ] **10.18** Desbloqueo de unidades secretas tras vencer a cada jefe (permanente en Torment; solo sesión en inferiores). `M`
- [ ] **10.19** Jefes invocados (×2) y jefes principales (×6) con multiplicadores de mineral correctos. `S`
- [ ] **10.20** Rebalanceo global de jefes con hoja de equilibrado. `L`

### CdH
- 3 jefes completos y jugables antes de `v0.5`; los 11 antes de `v1.0`.
- Cada ritual es descubrible (pistas visuales) y falla de forma comprensible.

---

## Fase 11 — Modos de juego
**Prioridad:** P2 · **Tamaño:** L · **Dependencias:** Fases 3, 7
**HJ:** puedo elegir entre Classic, Hardcore, Nightmare y Mutation Mode desde el menú principal.

| Modo | Reglas clave |
|---|---|
| **Classic** | Votación de dificultad, héroe, historia, eventos y jefes |
| **Torment** | Dificultad máxima fija; 100 % pérdida; desbloquea secretos |
| **Mutation** | Anfitrión personaliza densidad de enemigos, economía, escalado, coste de mejoras, spawners forzados… |
| **Hardcore** | Sin mejoras en enemigos, sin Protoss, sin compra de bufos, sin héroes estándar (12 unidades élite: 4 por raza), sin eventos bonus |
| **Nightmare** | Oleadas infinitas; base en el centro con barrera de radiación; ciclo de 10 oleadas tras las 100 primeras |
| **Split Income** | El asesino se lleva el botín (handicap 0.9) |
| **10 Player** | 10 jugadores; menos suministro por jugador |
| **Debug** | Consola de desarrollador (**Ctrl+Alt+C**) |

### Tareas
- [ ] **11.1** `ModeData` + `GameConfig` aplican reglas con *feature flags*. `M`
- [ ] **11.2** Menú de sala: selección de modo, dificultad, seed, nº de jugadores. `M`
- [ ] **11.3** **Mutation Mode:** UI de ajustes (sliders) + persistencia de presets. `L`
- [ ] **11.4** **Hardcore:** 12 unidades élite iniciales, desactivar sistemas (bufos, Protoss, eventos bonus). `M`
- [ ] **11.5** **Nightmare:** base central, barrera de radiación, generador de oleadas (1–100 únicas) + ciclo de 10 (Terrestre, Terrestre, Aérea, Terrestre invisible, Élite, Terrestre, Terrestre, Aérea invisible, Terrestre, Jefe). `L`
- [ ] **11.6** Nivel de experiencia Nightmare (`Level X`) en lugar de rango. `S`
- [ ] **11.7** **Split Income** y **10 Player** conectados a Fase 1. `S`
- [ ] **11.8** **Debug console** (Ctrl+Alt+C): spawn de unidades, dar mineral, teletransporte, forzar eventos, saltar a fase. Imprescindible para desarrollo. `M`
- [ ] **11.9** Tests: cada modo arranca, ejecuta 60 s y termina sin errores. `M`

### CdH
- Los 8 modos se lanzan desde el menú. Hardcore y Nightmare se sienten claramente distintos.

---

## Fase 12 — Meta: rangos, logros y guardado
**Prioridad:** P3 · **Tamaño:** L · **Dependencias:** Fases 7, 10
**HJ:** al terminar una partida gano puntos, mi rango sube y se guarda; desbloqueo logros.

### Rangos y puntos
- Rangos: `R` → `D-1` (0 pts) → `D` → `C` → `B` → `A` → `S`, con 10 subdivisiones por letra.
- Subir de D-1 a D-2 cuesta 10.000; cada nivel añade **+250** (10.000, 10.250, 10.500…).
- Derrota: −6.000 · abandono: −8.000 · expulsión por votación: −20.000. Victoria: base escalada por dificultad (máximo en solitario).
- Recompensa de jefe: +300.

### Tareas
- [ ] **12.1** `RankSystem`: puntos ↔ rango/subnivel (función pura + tests con la calculadora de la wiki). `M`
- [ ] **12.2** Cálculo de puntos por partida (victoria/derrota/abandono/expulsión/jefes). `M`
- [ ] **12.3** `AchievementSystem`: motor de logros con condiciones declarativas (`AchievementData`). `L`
- [ ] **12.4** Catálogo inicial de 30 logros → ampliar hasta ~373 (8.040 puntos totales en la wiki). `XL`
- [ ] **12.5** Persistencia local: `user://sfe5_bank.json` (versionado, con checksum anti-corrupción). `M`
- [ ] **12.6** `Settings`: zoom de cámara, volumen, controles, consola (archivo separado editable). `S`
- [ ] **12.7** Cosméticos (no afectan al balance): auras/halos, iconos de minimapa, marcos de rango (Bronce 15 % → Arcoíris 100 %). `L`
- [ ] **12.8** Condición de desbloqueo de Torment por victorias en Brutal. `S`
- [ ] **12.9** Héroes secretos: requisito ≥ 3.000 puntos de logro y dificultad < Torment (preparar, ver Fase 16). `S`
- [ ] **12.10** Pantalla de estadísticas de por vida. `M`

### CdH
- Cierro y abro el juego y conservo rango, logros y ajustes.
- Los casos de la calculadora de rangos de la wiki pasan como tests.

---

## Fase 13 — Multijugador cooperativo
**Prioridad:** P2 · **Tamaño:** XL · **Dependencias:** Fases 3–7 estables
**HJ:** 2–6 personas juegan la misma partida en red.

> **Aviso:** es la fase de mayor riesgo. Decidir el modelo (ADR-01) *antes* de empezar la Fase 3 si es posible, o asumir refactor.

### Tareas
- [ ] **13.1** Decisión ADR-01: *host autoritativo (ENet/Godot High-level Multiplayer)* vs *lockstep determinista*. `M`
- [ ] **13.2** Abstracción de jugador: `PlayerSlot` (id, héroe, minerales, supply, color). `M`
- [ ] **13.3** Lobby y sala: unirse por IP/código, listo/no listo, selección de héroe y dificultad (votación). `L`
- [ ] **13.4** Sincronización de estado: héroes, compras, habilidades, engendradores, jefes, minerales. `XL`
- [ ] **13.5** Enjambre masivo en red: el host simula; los clientes reciben snapshots comprimidos (posición/estado por grupo, interpolación). `XL`
- [ ] **13.6** Compras de consola validadas por el host. `M`
- [ ] **13.7** Desconexión/reconexión y recálculo dinámico del suministro. `M`
- [ ] **13.8** Votaciones (dificultad, expulsión). `M`
- [ ] **13.9** Pruebas de latencia simulada (200 ms, 3 % pérdida). `M`
- [ ] **13.10** Modo 10 jugadores (límites de red). `L`

### CdH
- 4 clientes + 1 host: 20 minutos sin desincronizaciones graves ni cuelgues.

---

## Fase 14 — UI/UX, audio y pulido visual
**Prioridad:** P2 · **Tamaño:** XL · **Dependencias:** núcleo jugable (Fases 3–10)
**HJ:** el juego se ve, suena y se siente cuidado.

### UI/UX
- [ ] **14.1** Menú principal, selección de modo y ajustes. `M`
- [ ] **14.2** Menú de pausa (Esc) con volumen por canal y opciones gráficas. `M`
- [ ] **14.3** Pantalla de victoria/derrota con desglose (tiempo, bajas, minerales, nivel de veteranía). `M`
- [ ] **14.4** Tutorial interactivo (3 pasos: mover, comprar, matar spawner). `L`
- [ ] **14.5** Accesibilidad: daltonismo (paleta alternativa de categorías), escalado de UI, remapeo de teclas. `M`
- [ ] **14.6** Localización: ES/EN con `TranslationServer` y `.po`. `M`
- [ ] **14.7** Notificaciones y alertas (base atacada, jefe invocado, evento próximo). `S`

### Audio (retomar tras el bucle de juego)
- [ ] **14.8** `SFXManager` (autoload): pool de 24 reproductores 3D + 8 2D, polifonía máxima por id, variación de tono. `M`
- [ ] **14.9** Layout de buses (Master, Music, Voice, Ambience, SFX, Weapons, Swarm) y *ducking* por voz. `S`
- [ ] **14.10** Biblioteca mínima de efectos (disparos, impactos, muertes zerg, habilidades, UI). `L`
- [ ] **14.11** Alertas del Adjutant ("Base under attack", "Insufficient minerals", "Wave incoming"). `S`
- [ ] **14.12** Música adaptativa (calma/combate/jefe). `M`

### Pulido visual
- [ ] **14.13** Sustitución progresiva de placeholders por modelos finales (prioridad: héroes, spawners, jefes). `XL`
- [ ] **14.14** VFX de habilidades y de estados de bufo. `L`
- [ ] **14.15** Post-proceso, iluminación por fase de historia. `M`
- [ ] **14.16** Animaciones y feedback de golpe (hit-stop sutil, números de daño). `M`

### CdH
- Un jugador nuevo entiende el juego en 5 min con el tutorial.
- Sin pantalla rota ni sonido ausente en el flujo principal.

---

## Fase 15 — Rendimiento, QA y lanzamiento
**Prioridad:** P1 · **Tamaño:** L · **Dependencias:** casi todo
**HJ:** versión 1.0 estable, empaquetada y publicable.

### Tareas
- [ ] **15.1** Definir equipo de referencia (CPU/GPU/RAM) y presupuesto: 300 enemigos + 6 jugadores ≥ 60 FPS. `S`
- [ ] **15.2** Perfilado (Godot Profiler, Monitors, Visual Profiler) con escenas de estrés. `M`
- [ ] **15.3** Optimización: LOD, culling, agrupación de simulación, pooling de proyectiles/VFX. `L`
- [ ] **15.4** Prueba de saturación larga (soak test): 2 h de partida sin fugas de memoria. `M`
- [ ] **15.5** Matriz de pruebas: Windows/Linux, GPU diversas, resoluciones. `M`
- [ ] **15.6** Revisión de balance con telemetría local (tiempo hasta cada hito, muertes, minerales). `L`
- [ ] **15.7** Lista de bugs conocidos y triaje (P0 bloqueante, P1 grave…). `M`
- [ ] **15.8** Presets de exportación (Windows/Linux), firma, iconos, versión. `M`
- [ ] **15.9** Página del proyecto (itch.io / GitHub Releases), capturas y trailer corto. `M`
- [ ] **15.10** Guía de usuario y *changelog*. `S`
- [ ] **15.11** Revisión legal: nombres, assets y licencias (StarCraft II es IP de Blizzard; clarificar que es un proyecto fan sin ánimo de lucro, sin assets extraídos, y revisar el uso de nombres). `M`
- [ ] **15.12** Beta cerrada con 5–10 testers y recogida de feedback. `L`

### CdH
- 0 bugs P0, ≤ 5 bugs P1 conocidos y documentados; 2 h de partida estable.

---

## Fase 16 — Extras: héroes secretos y eventos de calendario
**Prioridad:** P3 · **Tamaño:** M · **Dependencias:** Fases 5, 12
**HJ:** descubro contenido especial y eventos temporales.

### Tareas
- [ ] **16.1** Mecánica de héroes secretos: probabilidad `(6 − dificultad)%`, condición ≥ 3.000 puntos, deshabilita logros de la partida. `M`
- [ ] **16.2** Héroes secretos (6): decidir si se conservan o se sustituyen por personajes originales (**recomendado**: originales, por evitar figuras reales — ver ADR-06). `M`
- [ ] **16.3** Eventos de calendario real (Navidad, Año Nuevo, April Fools…): temas visuales y reglas ligeras. `M`
- [ ] **16.4** Easter eggs (Outhouse, lagartos, cajas de cartón). `S`
- [ ] **16.5** Secretos del *Xel'Naga Harbinger* (1 % con Random Hero; ya existe un esbozo). `S`

---

## Ruta crítica y dependencias

```
Fase 0 ──► Fase 1 ──┐
   │                ├──► Fase 3 ──► Fase 8 ──► Fase 9 ──► Fase 10 ──► Fase 11 ──► Fase 15
   └─► Fase 2 ──────┤        │                       ▲
                    ├──► Fase 4 ──► Fase 5 ──► Fase 6│
                    │        │                       │
                    └──► Fase 7 ─────────────────────┘
                                         Fase 12 ◄── (10, 7)
                                         Fase 13 ◄── (3–7 estables)
                                         Fase 14 ◄── (núcleo estable)
                                         Fase 16 ◄── (5, 12)
```

**Ruta crítica corta (para tener un juego reconocible lo antes posible):**
`0 → 1 → 2 → 3 (cadena de 3 spawners) → 4 (atributos + 3 bufos) → 7 (dificultades) → 10 (1 jefe) = "SFE5 mínimo jugable"`

### Orden sugerido de las próximas 10 sesiones
1. Fase 0: higiene + CI + etiquetas.
2. Fase 1: `IncomeFormula` + casos de referencia.
3. Fase 1: integración en `SFEEconomyManager` + HUD de depuración.
4. Fase 2: esquemas `UnitData`/`SpawnerData` + `DataCatalog`.
5. Fase 3: `SpawnerNode` + invulnerabilidad condicional.
6. Fase 3: `SpawnerChain` + tope de 300.
7. Fase 3: integración con `SwarmSimulation`.
8. Fase 3: victoria/derrota + `v0.2`.
9. Fase 4: `StatsComponent` + atributos.
10. Fase 4: consola Alt+C + primeros bufos (T3 Momentum, T6 Bulwark).

---

## Decisiones de arquitectura abiertas (ADR)

| ID | Decisión | Opciones | Estado | Cuándo decidir |
|---|---|---|---|---|
| ADR-01 | Modelo de red | Host autoritativo (ENet) · Lockstep determinista | Abierta | Antes de Fase 3 (afecta a la simulación) |
| ADR-02 | Simulación del enjambre | Mantener SoA en GDScript · Mover a GDExtension (C++/Rust) | Abierta | Tras perfilado (Fase 15) |
| ADR-03 | Regla de "Crossfire Nullification" | Mantener · Eliminar (no consta en la wiki) | **Revisar** | Fase 1 |
| ADR-04 | Cámara y perspectiva | 3D con cámara RTS (actual) · 2.5D isométrico fijo | Decidida: 3D RTS | — |
| ADR-05 | Representación de enemigos | MultiMesh puro para masa + nodos solo para élite/jefes | Propuesta | Fase 3 |
| ADR-06 | Héroes secretos con personas reales | Conservar · Sustituir por originales | Propuesta: sustituir | Fase 16 |
| ADR-07 | Formato de guardado | JSON versionado · Binario cifrado | Propuesta: JSON + checksum | Fase 12 |
| ADR-08 | Escala de unidades enemigas | Todas simuladas · Culling por distancia a jugadores | Abierta | Fase 3–15 |
| ADR-09 | Idioma del código/comentarios | Español · Inglés | Abierta (recomendado: código en inglés, docs en español) | Fase 0 |
| ADR-10 | Control de versiones de datos | `.tres` en Git · Generados desde CSV | Propuesta: CSV → `.tres` para masa, a mano para únicos | Fase 2 |

> Cada ADR resuelto se documenta en `docs/adr/NNNN-titulo.md` con contexto, decisión y consecuencias.

---

## Riesgos y mitigaciones

| # | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| R1 | **Alcance inabarcable** (42 héroes, 500 mejoras, 11 jefes) | Alta | Alto | Tandas de contenido, datos generados, "SFE5 mínimo" como meta intermedia |
| R2 | **Multijugador tarde** obliga a reescribir | Alta | Muy alto | Decidir ADR-01 pronto; separar simulación de presentación desde Fase 3 |
| R3 | Rendimiento del enjambre con 6 jugadores y bufos | Media | Alto | Presupuesto de 300 vivos (como el original); perfilar pronto |
| R4 | Desvío hacia lo visual (patrón actual) | Alta | Alto | Regla 2 y 6: placeholders; el arte entra en Fase 14 |
| R5 | Tests excesivos que ralentizan | Media | Medio | Máx. un test por regla; legacy fuera del runner |
| R6 | Documentación desactualizada | Alta | Medio | Un solo documento vivo; revisión semanal |
| R7 | Fórmulas que no coinciden con el original | Media | Medio | Casos de referencia de la wiki y calculadoras |
| R8 | Problemas legales de IP (Blizzard) | Media | Alto | Proyecto fan sin monetización; evitar assets extraídos; revisar nombres antes de publicar |
| R9 | Pérdida de motivación por falta de avances visibles | Alta | Alto | Hitos jugables cortos, tags, capturas/GIFs al cerrar cada fase |
| R10 | Dependencia de generación asistida sin revisión | Media | Medio | Revisar cada commit grande; pruebas manuales; mantener arquitectura simple |
| R11 | Complejidad del mapa procedural | Media | Medio | Empezar con arena pequeña (tarea 3.15) y seeds fijas de prueba |
| R12 | Bufos con condiciones interdependientes (bugs sutiles) | Media | Medio | Motor de condiciones único + tests de cada bufo |

---

## Métricas de progreso

### Cuantitativas (actualizar semanalmente)
| Métrica | Hoy | Meta v0.5 | Meta v1.0 |
|---|---|---|---|
| Héroes jugables | 12 definidos (≈1 jugable) | 6 | 42 |
| Bufos implementados | 5 | 15 | ~40+ |
| Engendradores/familias | 0 | 4 | 15–20 |
| Jefes cúspide | 0 (2 prototipos) | 3 | 11 |
| Modos de juego | 1 | 2 | 8 |
| Eventos programados | 0 | 3 | 15 |
| Tests de reglas (no de auditoría) | — | 60 | 200 |
| FPS con 300 enemigos | por medir | ≥ 60 | ≥ 60 |

### Cualitativas (preguntas de revisión por hito)
- ¿Puedo jugar 10 minutos y divertirme?
- ¿Hay decisiones interesantes (dónde invertir mineral)?
- ¿Se nota la diferencia entre dificultades?
- ¿Alguien nuevo entiende qué hacer?

### Registro de avance (rellenar)
| Fecha | Fase | Qué se completó | Tag | Notas |
|---|---|---|---|---|
| | | | | |

---

## Plantilla de sesión de trabajo

**Antes de empezar (5 min)**
1. Leer la fase activa y escoger **una** tarea con CdH claro.
2. Escribir en una línea: *"Al terminar, podré ver/jugar X"*.

**Durante**
3. Rama corta `fase-N/tarea` · commits pequeños.
4. Si surge una idea nueva → anotar en el backlog; no desviarse.
5. Si algo se complica más de 2 h → dividir la tarea.

**Al terminar (10 min)**
6. Jugar 2 minutos el resultado.
7. Ejecutar tests; marcar casilla en este documento.
8. Commit + push; si cierra un hito → tag + captura/GIF.
9. Anotar en una línea la próxima tarea.

---

## Backlog de ideas (no comprometido)

- Editor visual de engendradores y cadenas dentro del editor de Godot (plugin).
- Modo espectador / replay determinista (aprovecha las seeds).
- Herramienta de equilibrado: simulador headless que juega N partidas con IA simple y reporta ingresos y tiempos.
- Generación de mapas alternativos (planetas distintos: Char, Aiur, Korhal…).
- Modo cooperativo local (pantalla dividida) para 2 jugadores.
- Mods: carga de `.pck` con héroes/bufos nuevos (consecuencia natural del diseño data-driven).
- Sistema de "retos semanales" con seed fija.
- Soporte de mando/gamepad.
- Port a Steam Deck.
- Modo narración con diálogos del Adjutant y briefing de misión.
- Integración con Discord (rich presence).

---

## Apéndices

### Apéndice A — Resumen de la fórmula de ingresos (referencia rápida)
```gdscript
# core/economy/income_formula.gd  (esqueleto)
class_name IncomeFormula

static func compute(p: IncomeParams) -> int:
	var hp := p.base_health * p.health_mult
	var sh := p.base_shield * p.health_mult
	var dmg := p.weapon_damage * p.damage_mult
	var s: float
	if p.has_weapon:
		s = (hp + sh) / 3.0 + dmg / maxf(p.attack_period, 0.01)
	else:
		s = ((hp + sh) / 3.0) * 2.0
	if p.max_energy > 0.0:
		s *= p.max_energy / 50.0
	if s > 500000.0:
		s = pow(s / 10.0, 0.32) * 3.0
	else:
		s = pow(s, 0.32)
	if p.split_income:
		s *= 10.0 * 0.9
	else:
		s *= 4.0 * ((12.0 - p.players) / 4.0)
	s *= 0.24
	s *= p.category_multiplier        # 8 / 4 / 6 / 2 / 6 según categoría
	s += p.pedestal_bonus
	return maxi(1, int(round(s)))
```
> Es un esqueleto fiel a la wiki; validar con los casos de referencia antes de darlo por bueno.

### Apéndice B — Estructura de carpetas objetivo
```
res://
├── core/
│   ├── autoload/          # SignalBus, GameSession, GameConfig, DataCatalog
│   ├── data/              # Resources tipados (UnitData, BuffData, SpawnerData…)
│   ├── economy/
│   ├── combat/
│   ├── components/        # Stats, Ability, Experience, Buff, Aura
│   ├── spawners/          # SpawnerNode, SpawnerChain, MapGenerator
│   ├── events/            # TimedEventSchedule, rituales, drop pods, nydus
│   ├── story/             # StoryPhaseManager, puzzles
│   ├── meta/              # RankSystem, Achievements, Bank
│   ├── net/               # Multijugador (Fase 13)
│   └── swarm/
├── data/                  # .tres de contenido (heroes, buffs, spawners, bosses, difficulties, modes)
├── entities/
├── levels/
├── ui/
├── assets/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── legacy/
├── tools/
└── docs/
    ├── adr/
    ├── balance/
    └── archive/
```

### Apéndice C — Pirámide de pruebas recomendada
| Capa | Cantidad objetivo | Qué cubre | Ejemplo |
|---|---|---|---|
| Unitarias | ~70 % | Fórmulas y reglas puras | `IncomeFormula`, `RankSystem`, solver F₂ |
| Integración | ~25 % | 2–3 sistemas juntos | Spawner + presupuesto de enemigos |
| Smoke / E2E | ~5 % | Arranque de modos y 60 s de partida | `mode_classic_smoke` |
| Manual | Siempre | "¿Es divertido?" | Jugar el hito antes de etiquetar |

### Apéndice D — Test de concentración (validación de filosofía de diseño)
Objetivo: verificar que SFE5 "castiga la dispersión".
1. Escenario A: 1 marine con X minerales en mejoras/bufos/atributos.
2. Escenario B: 5 marines con X/5 cada uno.
3. Mismo oleaje fijo (seed). Medir bajas por minuto y supervivencia.
4. Esperado: A > B de forma clara. Si no, revisar la curva de costes/efectos de la Fase 4.

### Apéndice E — Glosario
| Término | Significado |
|---|---|
| **Spawner / engendrador** | Estructura enemiga que genera unidades en ciclos |
| **Pinnacle Boss** | Jefe cúspide invocado mediante un ritual |
| **Tier (nivel de bufo)** | Una de las 7 ranuras de bufos de consola |
| **Ace (As)** | Bufo supremo (invulnerabilidad en apoyo/visión; mejoras en combate) |
| **Demiurge** | Bufo supremo de *cheat-death*, 180 s de reutilización |
| **Veteranía / Élite** | Conversión de una unidad normal en élite con stacks por baja |
| **Split Income** | Modo en que el asesino se lleva todo el mineral |
| **Banks** | Archivos de guardado de StarCraft II (aquí: `user://sfe5_bank.json`) |
| **HJ / CdH** | Hito jugable / Criterio de hecho |
| **ADR** | Architecture Decision Record |

### Apéndice F — Checklist de lanzamiento v1.0
- [ ] Todas las fases P0/P1 completas.
- [ ] 11 jefes cúspide jugables y balanceados.
- [ ] Modos Classic, Hardcore, Nightmare, Mutation operativos.
- [ ] Multijugador probado con 4+ jugadores (si se mantiene en el alcance).
- [ ] Guardado y rangos estables.
- [ ] Menús, pausa, tutorial y ajustes.
- [ ] Audio básico completo.
- [ ] 2 h de soak test sin fugas.
- [ ] Revisión legal hecha (ver R8).
- [ ] Changelog, guía y página de lanzamiento.
- [ ] Beta cerrada con feedback incorporado.

---

*Última actualización: 27/10/2026 · Revisar y actualizar cada semana.*
