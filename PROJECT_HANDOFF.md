# 🛡️ Special Forces Elite 5 (SFE5) — Documento de Traspaso y Guía del Proyecto (Handoff)

> **Versión del Motor:** Godot Engine 4.7.2 (Forward+ / Jolt Physics 3D)  
> **Lenguaje:** GDScript con tipado estático estricto  
> **Estado de Pruebas:** 110 / 110 pruebas pasando (100% Verde)  
> **Rendimiento:** Simulación masiva de >1.000 unidades Zerg a >75-95 FPS sostenidos  
> **Repositorio GitHub:** `https://github.com/Flisinhub/godot-wave.git`  
> **Fecha de Actualización:** Octubre 2026  

---

## 📋 1. Visión del Proyecto y Resumen Ejecutivo

**Special Forces Elite 5 (SFE5)** es un juego 3D de estrategia en tiempo real (RTS), defensa táctica de base y elementos de rol (RPG), inspirado directamente en el popular arcade de StarCraft II (*Special Forces Elite*) y ambientado en el hostil planeta volcánico de **Char**.

El jugador lidera a un Comandante Héroe Terran (o arquetipos como Jim Raynor, Tychus Findlay, Nova Terra, Zeratul, Tassadar o Egon Stetmann) junto a un pelotón de infantería para defender el Centro de Mando perimetral frente a miles de criaturas biológicas del Enjambre Zerg. Durante la partida, el jugador acumula minerales por bajas alienígenas, investiga mejoras progresivas en la Terminal de Armería, despliega torretas automáticas, sube de nivel los atributos RPG de su héroe y resiste oleadas de enjambres masivos y encuentros con Jefes de Evento de múltiples fases.

---

## ⚡ 2. Cómo Ejecutar y Probar el Proyecto (Onboarding Rápido)

### A. Ejecutar el Juego en Godot
1. Clona el repositorio:
   ```bash
   git clone https://github.com/Flisinhub/godot-wave.git
   cd godot-wave
   ```
2. Abre **Godot Engine 4.7.2** (o versión 4.x compatible).
3. Importa el proyecto seleccionando el archivo `project.godot`.
4. Pulsa **F5** (o botón *Play*). La escena principal configurada es:
   `res://levels/main_level.tscn`
5. En la pantalla inicial (*SFEStartModal*):
   - Elige el nivel de dificultad: `Casual`, `Normal`, `Hard`, `Brutal` o `Torment`.
   - Selecciona tu Héroe inicial o pulsa `🎲 RANDOM HERO` (+50 minerales de bonificación y 1% de probabilidad de desbloquear al mítico *Xel'Naga Harbinger*).
   - Haz clic en **DEPLOY TO CHAR** (o pulsa `Espacio`/`Enter`).

### B. Controles en Partida
| Acción | Control |
|---|---|
| **Mover Cámara** | Teclas `W`, `A`, `S`, `D` o bordes de pantalla (*Edge Scrolling*) |
| **Acelerar Cámara** | Mantener `Shift` mientras te desplazas |
| **Zoom de Cámara** | Rueda del ratón |
| **Selección Individual** | Clic Izquierdo sobre una unidad o estructura |
| **Selección Múltiple (Caja)** | Arrastrar con Clic Izquierdo (marco verde SC2) |
| **Mover Unidades / Héroe** | Clic Derecho en el terreno (formación táctica con espaciado anti-colisión) |
| **Órdenes de Combate** | Tecla `S` (Stop / Detenerse), Tecla `H` (Hold Position / Mantener posición) |
| **Habilidades del Héroe** | Teclas `Q`, `W`, `E`, `R` (o clics en la tarjeta de mando inferior) |
| **Alternar Compuerta** | Clic izquierdo sobre la compuerta o aproximar Marines aliados |
| **Terminal de Armería** | Acércate al terminal en la base o pulsa su botón en la consola SC2 |

### C. Ejecución de la Suite de Pruebas Automatizadas
El proyecto incluye un arnés de pruebas automatizado que corre de manera independiente en modo headless:
```powershell
# En Windows (usando tu binario de consola de Godot 4.7.2):
& "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_runner.gd

# En Linux / Mac / CLI estándar:
godot --headless --path . -s tests/test_runner.gd
```
**Resultado esperado:**
```
Total Tests: 110
Passed: 110
ALL ACTIVE TEST SUITES PASSED! [STATUS: GREEN]
```

### D. Verificación Rápida de Arranque del Nivel (Headless Boot)
```bash
godot --headless --path . --quit-after 200
```
Comprueba que el nivel inicialice todos los subsistemas (SwarmSimulation, WaveManager, RTSController, SC2HUDRoot, Economy y Armory) y cierre con código de salida 0 sin excepciones nulas.

---

## 🏛️ 3. Arquitectura y Reglas Inviolables del Código

Para que el proyecto mantenga su estabilidad, rendimiento masivo y elegancia técnica, **debes respetar estrictamente estas 5 reglas de diseño**:

```
                                  [ SignalBus ] (Autoload)
                                        │
     ┌───────────────────┬──────────────┴───────────────┬───────────────────┐
     │                   │                               │                   │
[ MainLevel ]     [ SFEEconomyManager ]        [ SFECombatEngine ]    [ SFXManager ]
     │                   │                               │             (7 Buses)
     ├─ SwarmSimulation ─┼─ Recompensas Alianzas         ├─ Daño Físico / Spell
     │   ├─ SwarmData    └─ Crossfire Nullification      ├─ Armadura Plana y %
     │   ├─ FlowField                                    ├─ Daño Estructural
     │   ├─ SpatialHash                                  └─ SFEBuffEngine (Stacks)
     │   └─ SwarmRenderer (MultiMesh)
     │
     ├─ ArmoryTerminal & UpgradeManager (Tiers 1-5 Balística, Blindaje, Torretas)
     ├─ Unidades Aliadas & Héroes (VisualRoot + AnimationPlayer)
     ├─ Jefes de Evento (Brutalisk / Híbrido con Fases de Vida)
     ├─ Perímetro Base (CommandCenter, Búnkeres, Compuertas, AutoTurret3D)
     └─ SC2HUDRoot (Minimap, StatPanel, CommandCard, BossHealthBarUI)
```

### Regla 1: Desacoplamiento de `VisualRoot` (Inviolable)
Todas las entidades físicas (`BaseUnit3D`, `HeroUnit3D`, `CommandCenter`, `BunkerStructure`, `AutoTurret3D`, `GateStructure`) deben colocar sus mallas 3D, efectos visuales y `AnimationPlayer` **exclusivamente dentro de un nodo hijo llamado `VisualRoot`**.
* El nodo raíz contiene el script lógico, el `CollisionShape3D`, el `NavigationAgent3D` y las capas de colisión.
* **Nunca** modifiques las colisiones o la jerarquía de nodos raíz al sustituir o actualizar modelos 3D.
* La base inferior de las mallas debe situarse a nivel de suelo (`y = 0.0`).

### Regla 2: Renderizado del Enjambre por GPU Batching (`SwarmRenderer`)
Para procesar más de 1.000 a 2.000 Zergs simultáneamente a >75 FPS:
* Los enemigos masivos del Enjambre no usan nodos `CharacterBody3D` individuales con esqueletos en CPU.
* Se simulan como partículas boids en `SwarmSimulation` y se dibujan mediante `MultiMeshInstance3D` en `SwarmRenderer` con deformación por vertex displacement en GPU (`assets/shaders/zerg_swarm.gdshader`).
* Cualquier nueva cepa del enjambre debe registrarse en `data/swarm/` con su arquetipo numérico.

### Regla 3: Regla de Anulación de Fuego Cruzado (*Crossfire Nullification*)
En [core/economy/sfe_economy_manager.gd](file:///e:/Juego%20Godot/core/economy/sfe_economy_manager.gd), **únicamente** las bajas asestadas directamente por unidades o estructuras del bando aliado (`Faction.ALLIED`) otorgan recompensas monetarias de minerales y experiencia al héroe. Las bajas causadas por fuego amigo o colisiones neutrales otorgan estrictamente 0 minerales.

### Regla 4: Determinismo y Seguridad en Modo Headless
Todo shader, tween, reproductor de audio (`AudioStreamPlayer3D`) y sistema de partículas (`GPUParticles3D`) debe incorporar una guarda contra el servidor headless:
```gdscript
if DisplayServer.get_name() == "headless":
    return # o desactivar renderizado de audio/GPU
```
Esto garantiza que la suite de pruebas unitarias y de integración se pueda ejecutar en servidores CI/CD sin tarjeta gráfica y sin crasheos.

### Regla 5: Persistencia Atómica en Dos Archivos (`BankManager`)
La persistencia de carrera del jugador ([core/persistence/bank_manager.gd](file:///e:/Juego%20Godot/core/persistence/bank_manager.gd)) utiliza una estrategia de doble archivo: archivo principal `.save` y copia de respaldo `.bak`, verificados con hash criptográfico SHA-256. Nunca realices escrituras no atómicas en disco para evitar corrupciones en caso de cierre forzado.

---

## 📦 4. Inventario de lo que ya está Creado e Implementado al 100%

### A. Modelos 3D (.glb) y Shaders PBR
* **Modelos Binarios Generados en `assets/models/`:**
  * `marine.glb`: Soldado de infantería Terran con armadura espacial y rifle Gauss.
  * `raynor.glb`: Comandante Jim Raynor con armadura pesada y rifle C-14 mejorado.
  * `command_center.glb`: Fortaleza planetaria industrial Terran con chimeneas y antenas.
  * `bunker.glb`: Búnker reforzado de aleación de neodimio con troneras de disparo.
  * `structures/auto_turret.glb`: Torreta automática perimetral con torreta rotatoria doble.
  * `zergling.glb`: Zergling veloz con garras quitinosas y crestas dorsales.
  * `roach.glb`: Cucaracha Zerg blindada con glándulas ácidas incandescentes.
  * `baneling.glb`: Cepa suicida rodante con sacos ventrales de ácido verde fluorescente.
  * `hydralisk.glb`: Atacante a media distancia con crestas alargadas y placas óseas.
* **Jerarquía de Animaciones:** Cada modelo cuenta con tracks de `AnimationPlayer` para `idle`, `walk` / `run`, `shoot` / `attack` y `death`.
* **Shaders de Terreno y Enjambre:**
  * `char_terrain.gdshader`: Roca basáltica volcánica de Char.
  * `lava_fissure.gdshader`: Grietas de magma con emisión de luz naranja incandescente.
  * `terran_base_deck.gdshader`: Cubierta metálica de la base con remaches y óxido.
  * `zerg_creep.gdshader`: Charcos bio-pustulares de Creep que pulsan orgánicamente.
  * `zerg_swarm.gdshader`: Shader cinemático masivo en GPU con modos de locomoción para cada cepa.

### B. Motor de Simulación del Enjambre (`core/swarm/`)
* [swarm_simulation.gd](file:///e:/Juego%20Godot/core/swarm/swarm_simulation.gd): Bucle boids de alto rendimiento capaz de mover 2.048 agentes simultáneamente.
* [swarm_flow_field.gd](file:///e:/Juego%20Godot/core/swarm/swarm_flow_field.gd): Campo vectorial de navegación que recalcula rutas dinámicas hacia el Centro de Mando o unidades aliadas evitando obstáculos.
* [swarm_spatial_hash.gd](file:///e:/Juego%20Godot/core/swarm/swarm_spatial_hash.gd): Particionado espacial por celdas con búsqueda por cuadrantes (máximo 12 candidatos evaluados) que previene el coste cuadrático $O(N^2)$.
* **Física Anti-Túnel Blindada:** La relajación cinemática entre unidades se procesa antes de los límites de colisión, evitando que los Zergs atraviesen muros o compuertas incluso bajo apiñamiento extremo.

### C. Sistema de Combate SFE5 (`core/combat/`)
* [sfe_combat_engine.gd](file:///e:/Juego%20Godot/core/combat/sfe_combat_engine.gd):
  * Fórmulas exactas de daño: físico vs hechizo (*spell*), penetración de blindaje y armadura plana.
  * Mitigación estructural: los búnkeres y murallas mitigan el daño directo de infantería (35%/25%), pero reciben un multiplicador devastador de **3.5x** ante explosiones de Banelings.
* [sfe_buff_engine.gd](file:///e:/Juego%20Godot/core/combat/sfe_buff_engine.gd):
  * Gestor de estados y potenciadores: velocidad de Stimpack, ralentizaciones ácidas y acumulación de stacks de ametralladora rotatoria para Tychus (hasta 20 stacks).

### D. Economía, Dificultades y Persistencia (`core/economy/`, `core/persistence/`)
* [sfe_economy_manager.gd](file:///e:/Juego%20Godot/core/economy/sfe_economy_manager.gd):
  * Billetera de minerales compartida, bonificaciones por bajas alienígenas y control de gastos en armería.
* [sfe_difficulty_manager.gd](file:///e:/Juego%20Godot/core/economy/sfe_difficulty_manager.gd):
  * 5 Niveles:
    * **Casual (0):** 1.50x minerales, 0.75x vida enemiga, evolución de colmena cada 180s.
    * **Normal (1):** 1.00x minerales, 1.00x vida enemiga, evolución de colmena cada 120s.
    * **Hard (2):** 0.80x minerales, 1.30x vida enemiga, evolución de colmena cada 90s.
    * **Brutal (3):** 0.65x minerales, 1.75x vida enemiga, evolución de colmena cada 60s.
    * **Torment (4):** 0.50x minerales, 2.50x vida enemiga, evolución de colmena cada 40s.
* [bank_manager.gd](file:///e:/Juego%20Godot/core/persistence/bank_manager.gd):
  * Persistencia atómica de la carrera del jugador: bajas totales históricas, victorias, derrotas y cálculo automático del nivel de veteranía (1 nivel por cada 100 bajas).

### E. Héroes y Progresión RPG (`core/heroes/`, `entities/allies/`)
* [hero_selector.gd](file:///e:/Juego%20Godot/core/heroes/hero_selector.gd) y recursos en `data/heroes/`:
  * **Jim Raynor:** Comandante de asalto, rifle Gauss y Stimpack militar.
  * **Tychus Findlay:** Blindaje pesado, granada fragmentaria y pasiva de ametralladora rotatoria.
  * **Nova Terra:** Francotiradora de élite, invisibilidad táctica y granadas trituradoras.
  * **Zeratul:** Asesino del Vacío con teletransporte *Blink* y tajo giratorio *Shadow Cleave*.
  * **Tassadar:** Alto Templario Protoss con *Psionic Storm* en área y escudo de plasma.
  * **Egon Stetmann (Medic):** Especialista de apoyo con rayo curativo inteligente *Heal Beam* y matriz defensiva.
  * **Xel'Naga Harbinger:** Arquetipo secreto místico con trascendencia dimensional (1% de probabilidad al elegir héroe aleatorio).
* [hero_unit_3d.gd](file:///e:/Juego%20Godot/entities/allies/hero_unit_3d.gd):
  * Sistema de subida de nivel RPG en combate: restaura 25% de vida y 50% de energía, otorga +3 puntos de atributo y proyecta un haz de luz dorada celestial con textos flotantes 3D.

### F. Terminal de Armería y Torretas Automáticas (`core/upgrades/`, `entities/structures/`)
* [armory_upgrade_manager.gd](file:///e:/Juego%20Godot/core/upgrades/armory_upgrade_manager.gd):
  * Árbol de mejoras progresivas en minerales:
    * **Arsenal Balístico (Tiers 1–5):** +15% de daño, +8% de cadencia de tiro y +0.6m de alcance por nivel.
    * **Supervivencia y Blindaje (Tiers 1–5):** +2 de armadura plana, +2.5 HP/s de regeneración pasiva y mitigación de daño.
    * **Mejoras de Habilidad:** Reducción de cooldowns y supresión del coste de vida de Stimpack.
    * **Despliegue de Torretas:** Permite construir hasta 6 torretas automáticas defensivas en el perímetro (125 minerales cada una).
* [armory_terminal.gd](file:///e:/Juego%20Godot/entities/structures/armory_terminal.gd) y [armory_terminal.tscn](file:///e:/Juego%20Godot/entities/structures/armory_terminal.tscn):
  * Estructura interactiva en la base con sensor `Area3D` (proximidad de 4.0m) y enlace directo a la botonera de la interfaz de usuario.
* [auto_turret_3d.gd](file:///e:/Juego%20Godot/entities/structures/auto_turret_3d.gd) y [auto_turret_3d.tscn](file:///e:/Juego%20Godot/entities/structures/auto_turret_3d.tscn):
  * Torreta automatizada con rotación completa en 360°, rango de 10.5m, disparo gemelo de 14 de daño balístico e IA de priorización de amenazas.

### G. Interfaz de Usuario y Consola StarCraft II (`ui/`)
* [sfe_start_modal.gd](file:///e:/Juego%20Godot/ui/sfe_start_modal.gd):
  * Ventana de despliegue previa a la misión: visualización de perfil de veteranía de BankManager, selector de las 5 dificultades y catálogo de héroes con ficha técnica detallada.
* [sc2_hud_root.gd](file:///e:/Juego%20Godot/ui/sc2_hud_root.gd):
  * **Barra de Mando Superior (Top Bar):** Badge de dificultad coloreado, temporizador de evolución Zerg (`HIVE LVL X (Next: Ys)`), contador de hostiles vivos en la oleada actual, barra de integridad del Centro de Mando, billetera de minerales (`💎 X MINERALS`) y nivel de veteranía (`⭐ VET LVL X`).
  * **Consola Inferior SC2:**
    * [sc2_minimap.gd](file:///e:/Juego%20Godot/ui/sc2_minimap.gd): Minimapa en tiempo real con posiciones de la base, murallas, héroe y enjambre.
    * [sc2_stat_panel.gd](file:///e:/Juego%20Godot/ui/sc2_stat_panel.gd): Panel central con retrato del héroe o unidad seleccionada, barras de vida/energía/escudos, daño de arma y nivel RPG.
    * [sc2_command_card.gd](file:///e:/Juego%20Godot/ui/sc2_command_card.gd): Rejilla de órdenes tácticas de 3x5 con atajos de teclado completos (`Q`, `W`, `E`, `R`, `S`, `H`).
* [floating_text_manager.gd](file:///e:/Juego%20Godot/core/vfx/floating_text_manager.gd):
  * Textos flotantes 3D en billboard para ganancias de minerales (`+5 MINERALS`, `+50 MINERALS`) y notificaciones de subida de nivel (`LEVEL UP!`).

---

## 🎯 5. Lo que Falta por Hacer (Roadmap para Concluir el Proyecto)

Para llevar el juego de su estado actual a un lanzamiento final completo, hemos dividido las tareas pendientes en **4 bloques de trabajo prioritarios**:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ROADMAP DE CONCLUSIÓN                           │
├────────────────────────┬───────────────────────────────────────────────┤
│ BLOQUE 1 (Prioridad 1) │ Sistema de Audio y Paisaje Sonoro (SFXManager)│
├────────────────────────┼───────────────────────────────────────────────┤
│ BLOQUE 2 (Prioridad 1) │ Jefes de Evento y Oleadas en Vivo (M3)        │
├────────────────────────┼───────────────────────────────────────────────┤
│ BLOQUE 3 (Prioridad 2) │ Campaña de 30 Rondas y Generador de Oleadas   │
├────────────────────────┼───────────────────────────────────────────────┤
│ BLOQUE 4 (Prioridad 3) │ Menús Finales, Pantalla Victoria y Pulido     │
└────────────────────────┴───────────────────────────────────────────────┘
```

### 🔴 Bloque 1: Sistema de Audio y Paisaje Sonoro (Hito M4)
* **Objetivo:** Dar vida acústica al combate, las armas balísticas y los chillidos extraterrestres.
* **Archivos a Crear / Conectar:**
  1. `res://core/audio/sfx_manager.gd` (Registrarlo como Autoload en `project.godot`).
  2. Implementar la API descrita en `PROJECT.md`:
     ```gdscript
     func play_sfx_3d(sound_id: StringName, global_pos: Vector3, max_polyphony: int = 4) -> void
     func play_sfx_2d(sound_id: StringName, volume_db: float = 0.0) -> void
     func play_voice_alert(alert_id: StringName) -> void
     func play_hero_voice(line_id: StringName) -> void
     ```
  3. **Pool de Reproductores:** 24 nodos `AudioStreamPlayer3D` para efectos espaciales de disparos/garras y 8 nodos `AudioStreamPlayer` para UI y música.
  4. **Buses de Audio:** Conectar con `res://default_bus_layout.tres` (ya presente en el proyecto con buses: `Master`, `Music`, `Voice`, `Ambience`, `SFX`, `Weapons`, `Swarm`).
  5. **Archivos de Sonido (.wav):**
     - Disparos del fusil Gauss C-14 de los Marines.
     - Cañones gemelos de la `AutoTurret3D` y ráfagas del Búnker.
     - Explosión ácida del Baneling y proyectil de espinas del Hydralisk.
     - Chillidos de muerte biológica Zerg.
     - Avisos de voz tácticos de la Adjutant Terran: *"Base under attack"*, *"Insufficient minerals"*, *"Wave incoming"*.

### 🔴 Bloque 2: Jefes de Evento y UI de Vida Cinemática (Hito M3)
* **Objetivo:** Introducir los encuentros épicos contra jefes masivos.
* **Archivos a Crear:**
  1. `res://entities/enemies/boss_brutalisk_3d.gd` y `.tscn`:
     - Leviatán de 8.000 HP con escala monumental.
     - **Fase 1 (100%–66% HP):** Golpes terrestres con aturdimiento en área (*Ground Slam*).
     - **Fase 2 (66%–33% HP):** Emisión de nova ácida (*Acid Nova*) y generación de crías de Banelings.
     - **Fase 3 (<33% HP):** Frenesí cataclísmico (+50% velocidad y daño berserk).
  2. `res://entities/enemies/boss_hybrid_3d.gd` y `.tscn`:
     - Entidad psiónica de 10.000 HP y 4.000 de Escudo de Plasma.
     - Habilidades: Onda de choque psiónica (*Psionic Shockwave* con drenaje de energía del héroe), vórtice gravitacional (*Graviton Vortex* que inmoviliza marines) e invocación de grietas del vacío (*Swarm Rift*).
  3. `res://ui/boss_health_bar_ui.gd` y `.tscn`:
     - Barra de vida cinematográfica anclada en la parte superior central de la pantalla.
     - Capa doble: barra de escudo psiónico cian sobre barra de vida escarlata con muescas en el 66% y 33% de fase.
     - Deslizador de aviso de canalización de habilidades del jefe (*Ability Windup Slider*).
  4. **Conexión en `WaveManager`:**
     - Integrar la aparición de los nuevos arquetipos Zerg (Baneling e Hydralisk) en las oleadas 3 en adelante de `levels/main_level.gd`.

### 🟡 Bloque 3: Campaña de 30 Rondas y Variedad de Oleadas
* **Objetivo:** Completar el bucle de juego desde la ronda 1 hasta la victoria en la ronda 30.
* **Tareas:**
  1. Ampliar el diccionario de oleadas en `levels/main_level.gd` (o crear un recurso dedicado `res://data/waves/wave_schedule.gd`):
     - **Rondas 1–5 (Primer Contacto):** Enjambres ligeros de Zerglings con aproximación frontal.
     - **Rondas 6–10 (Presión de Asedio):** Grupos mixtos de Zerglings y Roaches, culminando en la **Ronda 10 con el primer Jefe Brutalisk**.
     - **Rondas 11–19 (Guerra de Brecha):** Oleadas rápidas de Banelings kamikaze contra las compuertas perimetrales e Hydralisks bombardeando desde fuera del alcance de los búnkeres.
     - **Ronda 20 (Asalto Psiónico):** Invasión de enjambre masivo liderada por el **Híbrido Dominador**.
     - **Rondas 21–29 (Apocalipsis Zerg):** Oleadas combinadas de más de 1.500 criaturas simultáneas con evoluciones de colmena en nivel máximo.
     - **Ronda 30 (Clímax Final):** Batalla por la supervivencia contra los Leviatanes alfa para ganar la misión de Char.

### 🟢 Bloque 4: Menús Finales, Pantalla de Victoria/Derrota y Pulido
* **Tareas:**
  1. **Pantalla de Fin de Partida (`VictoryDefeatModal`):**
     - Desglose detallado al finalizar: tiempo de supervivencia, oleadas completadas, total de bajas alienígenas, minerales recolectados y nivel de veteranía alcanzado.
     - Botones para *"Jugar de Nuevo"* o *"Volver al Menú"*.
  2. **Menú de Pausa (Tecla `Escape`):**
     - Opciones para ajustar volumen por canal (Música, Efectos, Voces) vinculado a los buses de audio de Godot.
     - Ajustes de gráficos (pantalla completa, calidad de sombras y glow).
  3. **Comportamiento Táctico de Marines:**
     - Pulir la orden de "Entrar al Búnker" para que los Marines de infantería puedan guarnecerse dentro de los 4 búnkeres perimetrales y disparar protegidos desde el interior.

---

## 📂 6. Estructura de Directorios del Proyecto

```
e:\Juego Godot\
├── assets/
│   ├── materials/          # Materiales PBR (.tres) de terreno, estructuras y unidades
│   ├── models/             # Modelos tridimensionales binarios (.glb) y mallas ArrayMesh
│   │   └── structures/     # Modelos de búnker, torreta y centro de mando
│   └── shaders/            # Shaders GLSL optimizados (zerg_swarm.gdshader, lava, creep)
├── core/
│   ├── combat/             # SFECombatEngine, SFEBuffEngine
│   ├── economy/            # SFEEconomyManager, SFEDifficultyManager
│   ├── events/             # Puzzles espaciales y zonas de invocación de jefes
│   ├── heroes/             # HeroSelector, HeroData, definiciones de arquetipos
│   ├── persistence/        # BankManager (guardado atómico SHA-256)
│   ├── swarm/              # SwarmSimulation, SwarmRenderer, SwarmSpatialHash, SwarmFlowField
│   ├── upgrades/           # ArmoryUpgradeManager (árbol de mejoras y torretas)
│   └── vfx/                # CombatVFXPool, FloatingTextManager, StructureDamageVFX
├── data/
│   ├── enemies/            # EnemyData resources
│   ├── heroes/             # Recursos de héroes (marine, tychus, nova, zeratul, tassadar, etc.)
│   ├── skills/             # Recursos de habilidades (stimpack, blink, storm, heal_beam)
│   └── swarm/              # Arquetipos numéricos del enjambre (zergling, roach, baneling, hydra)
├── entities/
│   ├── allies/             # BaseUnit3D, HeroUnit3D
│   ├── enemies/            # BaseEnemy3D, BossBrutalisk3D (pendiente), BossHybrid3D (pendiente)
│   └── structures/         # CommandCenter, BunkerStructure, GateStructure, ArmoryTerminal, AutoTurret3D
├── levels/
│   └── main_level.tscn     # Escena principal jugable en el planeta Char
├── tests/
│   ├── test_runner.gd      # Ejecutor maestro de pruebas (110 tests)
│   ├── test_p2_e2e_tier1.gd# Cobertura de funcionalidades (F01–F16)
│   ├── test_p2_e2e_tier2.gd# Casos límite y esquinas (B01–B12)
│   ├── test_p2_e2e_tier3.gd# Combinaciones cruzadas de sistemas (C01–C08)
│   └── test_p2_e2e_tier4.gd# Escenarios de partida en tiempo real (S01–S05)
└── tools/
    ├── generate_environment.gd # Generador procedural de terreno basáltico y lava
    ├── generate_models.gd      # Exportador GLTF de modelos binarios .glb
    └── generate_structures.gd  # Herramientas de generación de geometría Terran
```

---

## 💡 7. Consejos y Buenas Prácticas para el Desarrollador

1. **Usa los Tests como Escudo Protector:**
   Antes de hacer cualquier commit o cambio de calado, ejecuta en consola `godot --headless --path . -s tests/test_runner.gd`. Si las 110 pruebas pasan en verde, tienes la garantía matemática de que no has roto las economías, colisiones ni la física del enjambre.
2. **Prueba Nuevos Modelos en `VisualRoot`:**
   Si deseas agregar animaciones o modelos importados desde Blender, reemplaza los nodos dentro de `$VisualRoot`. No toques las cajas de colisión ni los agentes de navegación del nodo superior.
3. **Optimización Extrema de GDScript:**
   En bucles que procesen entidades masivas (como `SwarmSimulation`), evita `dict.has()` o llamadas redundantes a funciones trigonométricas por frame. Usa arrays lineales indexados por ID y construye matrices `Basis` por componentes analíticos.
4. **Para Soporte o Preguntas del Código:**
   Revisa los comentarios detallados de cabecera en cada script de `core/` y la suite de pruebas en `tests/`, donde cada mecánica tiene tests con entradas y salidas numéricas exactas.

¡Mucho éxito con la continuación del proyecto! SFE5 tiene los cimientos técnicos más sólidos posibles en Godot 4.7.2. 🚀
