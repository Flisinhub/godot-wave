# Guía de Datos y Creación de Contenido — SFE5 Godot

Esta guía explica la arquitectura basada en datos (*data-driven*) de SFE5 Godot y cómo crear o extender unidades, héroes, bufos, mejoras y engendradores sin modificar el código fuente del motor.

---

## 1. Principio Fundamental
En SFE5, **todo el contenido vive en recursos tipados (`.tres`)**. 
El motor de juego (`MainLevel`, `SwarmSimulation`, `SFEEconomyManager`) nunca hardcodea atributos ni estadísticas de combate.
Al arrancar, `DataCatalog` escanea recursivamente `res://data/` e indexa todos los recursos en tablas O(1).

---

## 2. Esquemas de Datos (`core/data/`)

| Clase | Extiende | Ubicación | Propósito |
|---|---|---|---|
| `UnitData` | `Resource` | `core/data/unit_data.gd` | Unidades estándar, defensas y enemigos del enjambre |
| `HeroData` | `Resource` | `core/heroes/hero_data.gd` | Héroes RPG jugables con atributos STR/DEX/INT y crecimiento |
| `AbilityData` | `Resource` | `core/data/ability_data.gd` | Habilidades activas, pasivas, auras y canalizaciones |
| `BuffData` | `Resource` | `core/data/buff_data.gd` | Bufos por tiers (1–7) y supremos (Ace, Demiurge) |
| `UpgradeData` | `Resource` | `core/data/upgrade_data.gd` | Mejoras raciales progresivas (daño, armadura, vida...) |
| `SpawnerData` | `Resource` | `core/data/spawner_data.gd` | Nidos y engendradores de cadena (ciclo 20s) |
| `BossData` | `UnitData` | `core/data/boss_data.gd` | Jefes de mapa y cúspide con rituales y fases |
| `EventData` | `Resource` | `core/data/event_data.gd` | Eventos cronometrados, invasiones y drop pods |
| `DifficultyData` | `Resource` | `core/data/difficulty_data.gd` | Multiplicadores de ingreso y penalizaciones por muerte |
| `ModeData` | `Resource` | `core/data/mode_data.gd` | Modos de juego (Classic, Hardcore, Nightmare...) |

---

## 3. Cómo añadir una nueva Unidad Enemiga

Para añadir una unidad enemiga (por ejemplo, `mutalisk_data.tres`):

1. Ve a `data/enemies/` y duplica un `.tres` existente (p. ej. `hydralisk_data.tres`).
2. Nómbralo `mutalisk_data.tres`.
3. Abre el archivo en el inspector de Godot o en un editor de texto y configura:
   ```ini
   [gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]
   [ext_resource type="Script" path="res://data/enemies/enemy_data.gd" id="1_enemy_data"]

   [resource]
   script = ExtResource("1_enemy_data")
   id = &"mutalisk"
   unit_name = "Mutalisk"
   race = "zerg"
   category = "normal"
   max_health = 120.0
   move_speed = 7.5
   attack_damage = 9.0
   attack_range = 3.0
   attack_cooldown = 1.0
   kill_reward = 18
   body_color = Color(0.3, 0.15, 0.45, 1)
   accent_color = Color(0.8, 0.9, 0.1, 1)
   mesh_scale = Vector3(1.2, 0.9, 1.2)
   tags = ["light", "biological", "flying"]
   ```
4. `DataCatalog` la detectará automáticamente como unidad zerg y `SFEEconomyManager` calculará su botín mediante la Fórmula Maestra de SFE5.

---

## 4. Cómo añadir un nuevo Bufo por Tier (1–7)

1. En `data/buffs/`, crea un recurso `mi_bufo.tres` usando `res://core/combat/sfe_buff_def.gd` o `res://core/data/buff_data.gd`:
   ```ini
   [gd_resource type="Resource" script_class="SFEBuffDef" load_steps=2 format=3]
   [ext_resource type="Script" path="res://core/combat/sfe_buff_def.gd" id="1_buff_def"]

   [resource]
   script = ExtResource("1_buff_def")
   buff_id = &"plasma_overload"
   display_name = "Plasma Overload"
   tier = 3
   mineral_cost = 2500
   default_duration = 15.0
   default_max_stacks = 1
   stat_multipliers = {
       "attack_speed": 1.4,
       "spell_damage": 1.25
   }
   flat_modifiers = {}
   conditions = ["always"]
   ```

---

## 5. Cómo configurar un Engendrador de Cadena (`SpawnerData`)

Para la cadena de engendradores (Fase 3):
1. Crea `data/spawners/roach_warren_tier1.tres`:
   ```ini
   [gd_resource type="Resource" script_class="SpawnerData" load_steps=2 format=3]
   [ext_resource type="Script" path="res://core/data/spawner_data.gd" id="1_spawner"]

   [resource]
   script = ExtResource("1_spawner")
   id = &"spawner_roach_01"
   spawner_name = "Roach Warren Tier 1"
   family = "roach"
   level = 1
   required_spawner_id = &"spawner_zergling_01"  # Desbloqueado al destruir el nido de zerglings
   group_size = 4
   cycle_seconds = 20.0
   structure_health = 1800.0
   structure_armor = 6.0
   buffs_on_destroyed = ["armor_boost"]
   mineral_reward = 350
   ```

---

## 6. Validación Automatizada
Ejecuta la suite de verificación para asegurarte de que no hay IDs duplicados ni referencias rotas:
```bash
godot --headless --path . -s tests/test_runner.gd
```
O evalúa el validador estático programáticamente:
```gdscript
var report = DataValidator.validate_all("res://data")
assert(report.valid, "Errores de datos: " + str(report.errors))
```
