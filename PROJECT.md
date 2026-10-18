# Project: Special Forces Elite 5 (SFE5) — Phase 2: Full StarCraft II Fidelity

## Architecture
Special Forces Elite 5 (SFE5) is a high-performance tactical RTS defense game developed in Godot Engine 4.7.2 (Forward+ / Jolt Physics 3D). The game pits Terran infantry and hero commanders against massive alien Zerg swarms on the volcanic planet of Char.

```
                                  [ SignalBus ] (Autoload)
                                        │
     ┌───────────────────┬──────────────┴───────────────┬───────────────────┐
     │                   │                               │                   │
[ MainLevel ]     [ SFEEconomyManager ]        [ SFECombatEngine ]    [ SFXManager ]
     │                   │                               │             (7-bus Audio)
     ├─ SwarmSimulation ─┼─ KillContext Bounty           ├─ Physical vs Spell
     │   ├─ SwarmData    └─ Crossfire Nullification      ├─ Flat & Progressive Armor
     │   ├─ FlowField                                    ├─ Structural 35%/25%
     │   ├─ SpatialHash                                  └─ SFEBuffEngine (Stacks)
     │   └─ SwarmRenderer (MultiMesh)
     │
     ├─ ArmoryTerminal & UpgradeManager (Tiers 1-5 Ballistics, Armor, Turrets)
     ├─ Allied Units & HeroRaynor (VisualRoot + AnimationPlayer)
     ├─ Event Bosses (Brutalisk / Hybrid Dominator with Multi-Phase Health)
     ├─ Base Perimeter (CommandCenter, Bunkers, Gates, Auto-Turrets)
     └─ SC2HUDRoot (Minimap, StatPanel, CommandCard, BossHealthBarUI)
```

### Core Architecture Invariants
1. **Decoupled Visual Root**: All physical entities (`BaseUnit3D`, `HeroRaynor`, `CommandCenter`, `BunkerStructure`, `AutoTurret3D`, `BossBrutalisk3D`) strictly encapsulate visual representations inside a child `VisualRoot` node. Root `CollisionShape3D`, `NavigationAgent3D`, and physical layers/masks are never modified by visual updates.
2. **GPU Swarm Batching**: Swarm units (>1,000 active Zerglings, Roaches, Banelings, Hydralisks) are batched via `MultiMeshInstance3D` in `SwarmRenderer`, utilizing GPU vertex displacement (`assets/shaders/zerg_swarm.gdshader`) to eliminate CPU animation/rigging overhead and maintain >60 FPS (measured 75.4 FPS).
3. **Crossfire Nullification Rule**: In `SFEEconomyManager`, only kills delivered by `Faction.ALLIED` grant mineral bounties. Non-allied kills award strictly 0 minerals.
4. **Deterministic Headless Execution**: All shaders, audio players, tweens, and particle systems include explicit guards for `DisplayServer.get_name() == "headless"` to guarantee 100% clean test execution without driver crashes or null exceptions.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Marine & Raynor .glb Models & Animations | Real-time optimized 3D .glb models for Terran Marine and Hero Raynor with PBR textures and AnimationPlayer (idle, run, shoot, death) under VisualRoot. | M1 | Survey / ORIGINAL_REQUEST |
| 2 | Zerg Swarm .glb Models & MultiMesh LODs | Real-time optimized .glb biological models for Zerglings, Roaches, Banelings, and Hydralisks with LOD meshes extracted for MultiMeshInstance3D batching. | M1 | Survey / ORIGINAL_REQUEST |
| 3 | Defensive Structures .glb Models | Industrial Terran .glb models for Command Center / Planetary Fortress and Perimeter Bunkers preserving exact collision boxes. | M1 | Survey / ORIGINAL_REQUEST |
| 4 | Armory Terminal 3D Station & Interaction Zone | Physical interactive base terminal at base perimeter with 4.0m Area3D proximity detector, [E] prompt, and modal/SC2 console card integration. | M2 | Survey / ORIGINAL_REQUEST |
| 5 | Ballistic Arsenal Upgrades (Tiers 1–5) | Progressive weapon upgrades (+15% dmg/tier, +8% attack speed/tier, +0.6m range/tier) deducting minerals via SFEEconomyManager. | M2 | Survey / ORIGINAL_REQUEST |
| 6 | Armor & Survival Upgrades (Tiers 1–5) | Progressive survivability upgrades (+2 flat armor/tier, +2.5 HP/s regen/tier, plasma shields, +4% structural mitigation/tier). | M2 | Survey / ORIGINAL_REQUEST |
| 7 | Hero Ability Progression & Ultimates | Stimpack HP penalty elimination, Penetrating Round cooldown/energy/plasma trail, and unlockable Orbital Bombardment ultimate. | M2 | Survey / ORIGINAL_REQUEST |
| 8 | Automated Perimeter Turrets | Deployable 360° twin-Gatling autocannon defense turrets (125 min, max 6 active, 10.5m range, 14 dmg, priority targeting). | M2 | Survey / ORIGINAL_REQUEST |
| 9 | Baneling Kamikaze Strain | Fast (8.5 m/s) rolling bio-bomb with 1.4m detonation trigger dealing 40 damage to units and 3.5x multiplier (140 damage) to structures; 50% premature pop. | M3 | Survey / ORIGINAL_REQUEST |
| 10 | Hydralisk Ranged Artillery Strain | Medium-range (9.0m) acid spine attacker firing 28 m/s projectiles dealing 16 physical damage and penetrating primary and secondary targets. | M3 | Survey / ORIGINAL_REQUEST |
| 11 | Brutalisk Multi-Phase Event Boss | Gargantuan 8,000 HP hive leviathan with 3 phases: Ground Slam stun (P1), Acid Nova + Baneling brood (P2), and Cataclysmic Frenzy (P3). | M3 | Survey / ORIGINAL_REQUEST |
| 12 | Hybrid Dominator Event Boss | Psionic 10,000 HP + 4,000 Shield apex entity with Psionic Shockwave (AoE + energy drain), Graviton Vortex root, and Swarm Rift summons. | M3 | Survey / ORIGINAL_REQUEST |
| 13 | Cinematic Boss Health Bar UI | Screen-top dual-layer health and plasma shield bar widget in SC2HUDRoot with phase notches (66%, 33%) and ability windup warning slider. | M3 | Survey / ORIGINAL_REQUEST |
| 14 | 7-Bus Audio Layout & Ducking | Master, Music, Voice, Ambience, SFX (Weapons, Explosions, Swarm) bus layout with audio limiter and voice-activated ducking (-3 dB). | M4 | Survey / ORIGINAL_REQUEST |
| 15 | SFXManager Pooling & Rate Limiting | Autoload manager with 24 3D spatial players and 8 2D players, polyphony clamping (max 4 per ID), pitch jitter (0.94-1.06), and inverse distance attenuation. | M4 | Survey / ORIGINAL_REQUEST |
| 16 | Dynamic Soundscape & Voice Alerts | Procedural and sample playback for weapon discharges, biological screeches, tactical Adjutant alerts ("Base under attack"), and Hero acknowledgments. | M4 | Survey / ORIGINAL_REQUEST |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M0 | E2E Testing Suite & Infra (Dual Track) | Comprehensive 4-Tier requirement-driven test suite & runner (TEST_INFRA.md, TEST_READY.md) | None | IN_PROGRESS |
| M1 | 3D Models (.glb), Animations & Visual Fidelity | Features 1, 2, 3: GLTFDocument pipeline, .glb models for Marine, Raynor, Swarm strains, and Structures with AnimationPlayer under VisualRoot | None | IN_PROGRESS |
| M2 | Armory Terminal & SFE5 Upgrades System | Features 4, 5, 6, 7, 8: Armory 3D terminal, UpgradeManager, Tiers 1-5 Ballistics & Armor, Hero skills, AutoTurret3D | M1 Interface Contracts | PLANNED |
| M3 | Zerg Swarm Expansion & Event Bosses | Features 9, 10, 11, 12, 13: Baneling kamikaze, Hydralisk ranged spine, Brutalisk 3-phase boss, Hybrid Dominator, BossHealthBarUI | M1 Interface Contracts | PLANNED |
| M4 | Soundscape & Dynamic SFX | Features 14, 15, 16: SFXManager, 7-bus layout, procedural audio synthesis, 24 3D audio pool, tactical voice alerts | None | PLANNED |
| M5 | Global Integration & Adversarial Hardening | Pass 100% of E2E test suite (Tiers 1-4) + Tier 5 Adversarial Coverage Hardening + Victory Forensic Audit | M1, M2, M3, M4, M0 | PLANNED |

---

## Interface Contracts

### 1. VisualRoot ↔ Unit & Structure Entities
- **Parent**: `CharacterBody3D` or `StaticBody3D`
- **Child Contract**: Must have `$VisualRoot` (Node3D).
- **Invariants**: Root collision shapes (`CollisionShape3D`) must remain unchanged at root level. Visual meshes lowest vertices must be flush with ground (`y = 0.0`).
- **AnimationPlayer**: Located at `$VisualRoot/AnimationPlayer` with tracks: `"idle"`, `"run"` or `"walk"`, `"attack"` or `"shoot"`, `"death"`.

### 2. ArmoryUpgradeManager ↔ SFEEconomyManager & Entities
- **Singleton / Autoload**: `ArmoryUpgradeManager` (`res://core/upgrades/armory_upgrade_manager.gd`)
- **API**:
  - `can_purchase_ballistics() -> bool`
  - `purchase_ballistics() -> bool`
  - `can_purchase_armor() -> bool`
  - `purchase_armor() -> bool`
  - `can_purchase_hero_ability(ability_id: StringName) -> bool`
  - `purchase_hero_ability(ability_id: StringName) -> bool`
  - `can_deploy_turret() -> bool`
  - `deploy_turret(world_position: Vector3) -> AutoTurret3D`
- **Signals**:
  - `upgrade_purchased(category: StringName, new_tier: int, cost: int)`
  - `turret_deployed(turret: Node3D, remaining_cap: int)`

### 3. SwarmSimulation ↔ Baneling & Hydralisk Archetypes
- **Archetype ID 2**: Baneling (`res://data/swarm/baneling_archetype.tres`)
  - `base_hp = 30.0`, `base_speed = 8.5`, `attack_range = 1.4` (detonation trigger), `base_damage = 40.0` (3.5x to structures = 140.0).
- **Archetype ID 3**: Hydralisk (`res://data/swarm/hydralisk_archetype.tres`)
  - `base_hp = 80.0`, `base_speed = 4.8`, `attack_range = 9.0`, `base_damage = 16.0` (pierces secondary target for 8.0).
- **SwarmRenderer**: Contains `MultiMeshInstance3D` slots for archetypes 0, 1, 2, 3.

### 4. BossBrutalisk3D & BossHybrid3D ↔ SC2HUDRoot
- **Signals**:
  - `boss_spawned(boss_name: String, max_hp: float, max_shields: float)`
  - `boss_health_changed(current_hp: float, current_shields: float, phase: int)`
  - `boss_ability_casting(ability_name: String, windup_duration: float)`
  - `boss_died()`
- **UI Listener**: `BossHealthBarUI` binds to signals and updates phase notches, health/shield bars, and cast sliders.

### 5. SFXManager ↔ Combat & UI Events
- **Singleton**: `SFXManager` (`res://core/audio/sfx_manager.gd`)
- **API**:
  - `play_sfx_3d(sound_id: StringName, global_pos: Vector3, max_polyphony: int = 4)`
  - `play_sfx_2d(sound_id: StringName, volume_db: float = 0.0)`
  - `play_voice_alert(alert_id: StringName)`
  - `play_hero_voice(line_id: StringName)`

---

## Code Layout
```
e:\Juego Godot\
├── assets/
│   ├── audio/              # SFX & voice audio files (.wav)
│   ├── materials/          # PBR .tres materials
│   ├── models/             # .glb models and ArrayMesh .tres
│   │   └── structures/     # Structure .glb models
│   └── shaders/            # Custom GLSL shaders (zerg_swarm.gdshader)
├── core/
│   ├── audio/              # SFXManager & procedural audio synthesis
│   ├── combat/             # SFECombatEngine, SFEBuffEngine
│   ├── economy/            # SFEEconomyManager, SFEDifficultyManager
│   ├── persistence/        # BankManager
│   ├── swarm/              # SwarmSimulation, SwarmRenderer, SwarmData
│   ├── upgrades/           # ArmoryUpgradeManager
│   └── vfx/                # CombatVFXPool, StructureDamageVFX
├── data/
│   ├── heroes/             # Hero definitions
│   └── swarm/              # SwarmUnitArchetype resources (0, 1, 2, 3)
├── entities/
│   ├── allies/             # BaseUnit3D, HeroRaynor
│   ├── enemies/            # BossBrutalisk3D, BossHybrid3D
│   └── structures/         # CommandCenter, BunkerStructure, ArmoryTerminal, AutoTurret3D
├── levels/
│   └── main_level.tscn     # Primary game level
├── tests/
│   ├── test_runner.gd      # Master test runner
│   ├── test_p2_e2e_tier1.gd# Feature coverage E2E tests
│   ├── test_p2_e2e_tier2.gd# Boundary & corner cases
│   ├── test_p2_e2e_tier3.gd# Cross-feature combinations
│   └── test_p2_e2e_tier4.gd# Real-world application scenarios
└── tools/
    ├── generate_models.gd  # Procedural mesh and GLTF export tools
    └── generate_audio.gd   # Procedural PCM audio generation tools
```
