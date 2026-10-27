# Special Forces Elite 5 (SFE5) — Phase 2 Test Infrastructure Specification

**Document:** `TEST_INFRA.md`  
**Location:** Project Root (`e:\Juego Godot\TEST_INFRA.md`)  
**Engine:** Godot Engine 4.7.2-stable Forward Plus (Windows D3D12 / Jolt Physics 3D)  
**Standard:** Dual-Track Quality Assurance & Progressive Testability  
**Author:** `test_writer_p2_e2e`  
**Date:** 2026-10-17  

---

## 1. Testing Methodology & Architectural Philosophy

Phase 2 of Special Forces Elite 5 introduces high-fidelity 3D models, an interactive Armory terminal, a 5-tier upgrade progression system, automated defensive turrets, two specialized Zerg strains (Banelings and Hydralisks), two multi-phase Event Bosses (Brutalisk and Hybrid Dominator), a dynamic cinematic boss health bar UI, and a 7-bus spatial soundscape with real-time ducking and rate limiting.

To rigorously validate this expanded feature set without regressions, the test infrastructure uses a **4-Tier Testing Methodology**:

```
┌────────────────────────────────────────────────────────────────────────┐
│               Tier 4: Real-World Application Scenarios                │
│       Multi-wave battles, progression loops, boss climax battles       │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
┌───────────────────────────────────┴────────────────────────────────────┐
│              Tier 3: Cross-Feature Combinations (Pairwise)             │
│   Upgrades + Combat, Banelings + Structures, Boss + UI, Audio Ducking   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
┌───────────────────────────────────┴────────────────────────────────────┐
│            Tier 2: Boundary & Corner Cases (Extreme Values)            │
│    Zero minerals, max upgrades, turret caps, premature burst, shields   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
┌───────────────────────────────────┴────────────────────────────────────┐
│              Tier 1: Feature Coverage (Category-Partition)             │
│    All 16 Phase 2 features verified in isolation against contracts     │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Category-Partition Testing
Each feature's domain is partitioned into disjoint equivalence classes (valid inputs, edge states, invalid/rejection conditions). Tests execute representative samples from each partition to ensure complete functional coverage.

### 1.2 Boundary Value Analysis (BVA)
Numeric inputs and thresholds are tested at the boundaries:
- Minimum values ($0$, negative, minimum damage floor of $1.0$).
- Exact threshold values (e.g. 100 minerals for Tier 1 Ballistics, $1.4\,\text{m}$ detonation trigger, $66\%$ and $33\%$ HP boss phase triggers).
- Off-by-one / near-boundary values ($99$ minerals, $1.41\,\text{m}$ range, 7th turret placement attempt when cap is 6).
- Maximum values (Tier 5 upgrade clamp, $50\%$ progressive mitigation cap, 4-voice polyphony limit).

### 1.3 Pairwise & Cross-Feature Integration
Multi-subsystem interactions are tested to ensure clean decoupling and correct data propagation:
- **Upgrades $\times$ Combat:** Ballistics and Armor tier multipliers correctly scaling `SFECombatEngine` physical and structural calculations.
- **Kamikaze Mechanics $\times$ Base Structures:** Baneling $3.5\times$ structural multiplier applying exclusively to structures while sparing infantry from the structural multiplier.
- **Boss Lifecycle $\times$ HUD Interface:** Health, shield, and cast timer signals correctly synchronizing with `BossHealthBarUI`.
- **High-Density Combat $\times$ Audio Throttling:** Rapid weapon discharges and swarm attacks processed through polyphony limits and voice ducking without stalling.

### 1.4 Real-World Workloads
End-to-end integration scenarios simulating realistic game sessions:
- Multi-wave swarm assaults against fortified Terran perimeters.
- Full economy-driven Armory visit and upgrade purchasing cycles.
- Multi-phase boss encounters with ability casts, stun cleanses, and victory bounty collection.

### 1.5 Progressive Testability Invariant
Tests are architected with **Progressive Testability**:
- Tests can run immediately in headless CI/CD.
- Interface contracts, mathematical equations, and existing system integrations (`SFECombatEngine`, `SFEEconomyManager`, `SwarmData`, etc.) are verified deterministically.
- Downstream milestone implementations (M1 models, M2 Armory scripts, M3 boss nodes, M4 audio files) are verified dynamically when present, and skipped gracefully with standard diagnostics (`skip_test("Milestone M... pending: ...")`) when pending.
- No test produces false failures due to missing unbuilt assets from future milestones, guaranteeing a green baseline throughout parallel development.

---

## 2. Complete Feature-to-Tier Mapping Matrix (Features 1–16)

The following matrix maps all 16 features from `PROJECT.md § Feature Inventory` across all four testing tiers:

| # | Feature Name | Milestone | Tier 1: Feature Coverage | Tier 2: Boundary / Corner Case | Tier 3: Cross-Feature Combination | Tier 4: Real-World Scenario |
|---|--------------|-----------|--------------------------|--------------------------------|-----------------------------------|-----------------------------|
| **1** | Marine & Raynor .glb Models & Animations | M1 | `test_f01_marine_raynor_models_and_animations`: Validates VisualRoot encapsulation, AnimationPlayer tracks (`idle`, `run`, `shoot`, `death`). | `test_b12_headless_safety_all_systems`: Headless verification with zero display crashes. | `test_c03_stimpack_tier3_combined_with_ballistics_t5`: Raynor firing animations with upgraded attack speed. | `test_s03_wave_5_brutalisk_boss_climax_battle`: Hero Raynor engaging boss in real-time combat. |
| **2** | Zerg Swarm .glb Models & MultiMesh LODs | M1 | `test_f02_zerg_swarm_models_and_multimesh`: Checks archetypes 0, 1, 2, 3 registered in SwarmRenderer with LOD meshes. | `test_b12_headless_safety_all_systems`: MultiMesh buffer resizing and allocation limits. | `test_c04_baneling_swarm_crossfire_against_perimeter_and_marines`: MultiMesh instances taking combat damage. | `test_s05_audio_and_visual_stress_battle_under_headless`: 1,000 active swarm units batched in MultiMesh. |
| **3** | Defensive Structures .glb Models | M1 | `test_f03_defensive_structures_models`: Verifies CommandCenter and BunkerStructure models under VisualRoot with immutable collisions. | `test_b05_turret_placement_boundary_and_choke_cost`: Distance from CommandCenter boundary check ($24.0\,\text{m}$). | `test_c02_armor_upgrades_combined_with_bunker_and_wall_defense`: Structures receiving armor upgrade mitigation. | `test_s01_full_wave_3_baneling_breach_scenario`: Defensive perimeter enduring swarm assault. |
| **4** | Armory Terminal 3D Station & Interaction Zone | M2 | `test_f04_armory_terminal_station_and_zone`: Area3D $4.0\,\text{m}$ proximity trigger, [E] prompt, and terminal open/close signals. | `test_b01_zero_and_insufficient_minerals_armory_purchase`: Transaction rejection when minerals insufficient. | `test_c03_stimpack_tier3_combined_with_ballistics_t5`: Upgrades unlocked at Armory applied to live Hero. | `test_s02_armory_progression_over_five_waves`: Player visiting Armory between waves to upgrade kit. |
| **5** | Ballistic Arsenal Upgrades (Tiers 1–5) | M2 | `test_f05_ballistic_arsenal_upgrades_math`: Validates $+15\%$ dmg/tier, $+8\%$ speed/tier, $+0.6\,\text{m}$ range/tier and costs ($100$ to $1500$). | `test_b02_exact_mineral_balance_boundary`: Exact 100 minerals spending, leaving 0; `test_b03_max_upgrade_tier_clamp`: Clamping at Tier 5. | `test_c01_ballistics_upgrade_combined_with_turret_fire`: Ballistics scaling AutoTurret3D weapon damage. | `test_s02_armory_progression_over_five_waves`: Progressive damage scaling across multiple combat waves. |
| **6** | Armor & Survival Upgrades (Tiers 1–5) | M2 | `test_f06_armor_survival_upgrades_math`: Validates $+2$ flat armor, $+2.5\,\text{HP/s}$, plasma shields, $+4\%$ struct mitigation/tier. | `test_b03_max_upgrade_tier_clamp`: Clamping at Tier 5; zero mineral rejection. | `test_c02_armor_upgrades_combined_with_bunker_and_wall_defense`: Wall mitigation scaling from 35% to 55%. | `test_s02_armory_progression_over_five_waves`: Enhanced unit survival during heavy wave pressure. |
| **7** | Hero Ability Progression & Ultimates | M2 | `test_f07_hero_ability_progression_and_ultimates`: Stimpack HP penalty elimination, Penetrating Round scaling, Hyperion unlock ($800$ min). | `test_b01_zero_and_insufficient_minerals_armory_purchase`: Unable to unlock Hyperion with $<800$ minerals. | `test_c03_stimpack_tier3_combined_with_ballistics_t5`: 0 HP Stimpack combined with Tier 5 Ballistics. | `test_s04_wave_10_hybrid_dominator_and_orbital_bombardment`: Casting Orbital Bombardment to break boss shields. |
| **8** | Automated Perimeter Turrets | M2 | `test_f08_automated_perimeter_turrets`: AutoTurret3D stats ($350\,\text{HP}$, $2$ armor, $14\,\text{dmg}$, $10.5\,\text{m}$ range, $0.35\,\text{s}$ cd, $125$ min). | `test_b04_turret_deployment_cap_limit_6`: Enforcing hard cap of 6 active turrets; `test_b05_turret_placement_boundary_and_choke_cost`: Proximity bounds. | `test_c01_ballistics_upgrade_combined_with_turret_fire`: Turrets benefiting from Ballistics damage bonuses. | `test_s01_full_wave_3_baneling_breach_scenario`: Turrets prioritizing Banelings during swarm rush. |
| **9** | Baneling Kamikaze Strain | M3 | `test_f09_baneling_kamikaze_strain`: Archetype 2, $30\,\text{HP}$, $8.5\,\text{m/s}$, $1.4\,\text{m}$ trigger, $40\,\text{dmg}$ to units, $3.5\times$ ($140\,\text{dmg}$) to structures. | `test_b06_baneling_premature_detonation_at_range`: Killed at $>1.4\,\text{m}$ yields $50\%$ damage ($20\,\text{dmg}$, $70$ struct); `test_b07_baneling_structure_multiplier_boundary`: Units take $1\times$. | `test_c04_baneling_swarm_crossfire_against_perimeter_and_marines`: Baneling detonation damaging wall and nearby marines. | `test_s01_full_wave_3_baneling_breach_scenario`: Baneling breach breaching outer defensive perimeter. |
| **10** | Hydralisk Ranged Artillery Strain | M3 | `test_f10_hydralisk_ranged_artillery`: Archetype 3, $80\,\text{HP}$, $4.8\,\text{m/s}$, $9.0\,\text{m}$ range, $16\,\text{dmg}$, secondary target penetration ($8\,\text{dmg}$). | `test_b08_hydralisk_extreme_range_and_cutoff`: Target moving past $9.0\,\text{m}$ windup cutoff and armor subtraction. | `test_c06_hydralisk_spine_penetration_through_marines_and_bunker`: Spine piercing primary and secondary targets in a line. | `test_s03_wave_5_brutalisk_boss_climax_battle`: Hydralisks providing ranged artillery support to boss. |
| **11** | Brutalisk Multi-Phase Event Boss | M3 | `test_f11_brutalisk_multiphase_boss`: $8,000\,\text{HP}$, $12$ armor, Phase 1 Ground Slam, Phase 2 Acid Nova + Banelings ($\le 66\%$), Phase 3 Frenzy ($\le 33\%$). | `test_b10_boss_burst_phase_skip_edge_case`: Huge burst damage transitioning across multiple phases in 1 tick. | `test_c05_brutalisk_phase_transition_with_boss_health_bar_ui`: Phase transitions signaling health bar color and notches. | `test_s03_wave_5_brutalisk_boss_climax_battle`: Full multi-phase encounter ending with 2,500 mineral bounty. |
| **12** | Hybrid Dominator Event Boss | M3 | `test_f12_hybrid_dominator_boss`: $10,000\,\text{HP}$, $4,000$ shield, $8$ armor, Psionic Shockwave, Graviton Vortex, Swarm Rift. | `test_b09_boss_shield_absorption_limits`: Damage absorbing fully into shield before penetrating HP. | `test_c08_hybrid_dominator_shockwave_with_hero_energy_drain`: Shockwave dealing spell damage and draining hero energy. | `test_s04_wave_10_hybrid_dominator_and_orbital_bombardment`: Wave 10 climax encounter against the apex Hybrid. |
| **13** | Cinematic Boss Health Bar UI | M3 | `test_f13_cinematic_boss_health_bar_ui`: Dual-layer health/shield bar, phase dividers at $66\%$ and $33\%$, ability cast warning slider. | `test_b09_boss_shield_absorption_limits`: Shield bar disappearing when shield drops to 0. | `test_c05_brutalisk_phase_transition_with_boss_health_bar_ui`: Color shifts (Crimson -> Orange -> Magenta). | `test_s03_wave_5_brutalisk_boss_climax_battle`: Health bar tracking entire boss encounter and fading on death. |
| **14** | 7-Bus Audio Layout & Ducking | M4 | `test_f14_seven_bus_audio_layout_and_ducking`: Master, Music, Voice, Ambience, SFX (Weapons, Explosions, Swarm), limiter and voice ducking sidechain. | `test_b12_headless_safety_all_systems`: Audio server dummy execution in headless mode without crashes. | `test_c07_audio_sidechain_ducking_during_mass_firefight`: Voice line ducking Weapons and SFX by $-3.0\,\text{dB}$. | `test_s05_audio_and_visual_stress_battle_under_headless`: Soundscape operating cleanly during 1,000-unit firefight. |
| **15** | SFXManager Pooling & Rate Limiting | M4 | `test_f15_sfx_manager_pooling_and_rate_limiting`: 24 3D spatial players, 8 2D players, max polyphony of 4 per sound ID, pitch jitter ($0.94-1.06$). | `test_b11_audio_polyphony_saturation_stress`: 50 rapid calls clamped to 4 voices without dropping frames. | `test_c07_audio_sidechain_ducking_during_mass_firefight`: Pooled audio players routed through correct sub-buses. | `test_s05_audio_and_visual_stress_battle_under_headless`: Audio pool recycled under sustained combat stress. |
| **16** | Dynamic Soundscape & Voice Alerts | M4 | `test_f16_dynamic_soundscape_and_voice_alerts`: Sound catalog identifiers, Adjutant tactical alerts, Raynor acknowledgments, rate limits. | `test_b12_headless_safety_all_systems`: Voice alert cooldown (min 15s) preventing duplicate voice playback. | `test_c07_audio_sidechain_ducking_during_mass_firefight`: Adjutant alerts triggering combat voice ducking. | `test_s03_wave_5_brutalisk_boss_climax_battle`: Boss roar, combat gunfire, and tactical alerts triggered in sequence. |

---

## 3. Test Suites Directory Structure & File Manifest

The E2E test suites are organized in `res://tests/` alongside the test runner:

```
tests/
├── test_runner.gd                  # Master SceneTree CLI runner (executes Phase 1 + Phase 2 suites)
├── test_base.gd                    # Base assertion and diagnostic framework (SFE_TestBase)
│
├── test_r1_swarm.gd                # Phase 1 Suite: Swarm & Flow Field Navigation (13 tests)
├── test_r2_combat.gd               # Phase 1 Suite: Combat Engine & Buffs (18 tests)
├── test_r3_economy.gd              # Phase 1 Suite: Economy & Crossfire (6 tests)
├── test_r4_heroes.gd               # Phase 1 Suite: Heroes & RPG Progression (6 tests)
├── test_r5_events_persistence.gd   # Phase 1 Suite: Events, Puzzles & Persistence (15 tests)
├── test_integration_full.gd        # Phase 1 Suite: Integration Scenarios (5 tests)
├── test_sfe5_phase1_playable_integration.gd # Phase 1 Suite: Playable Integration (6 tests)
│
├── test_p2_e2e_tier1.gd            # Phase 2 Tier 1: Feature Coverage (16 tests, 1 per feature)
├── test_p2_e2e_tier2.gd            # Phase 2 Tier 2: Boundary & Corner Cases (12 tests)
├── test_p2_e2e_tier3.gd            # Phase 2 Tier 3: Cross-Feature Combinations (8 tests)
└── test_p2_e2e_tier4.gd            # Phase 2 Tier 4: Real-World Application Scenarios (5 tests)
```

---

## 4. Headless Execution & CLI Command

To execute the entire test suite (all Phase 1 suites + all Phase 2 Tier 1–4 suites) in headless mode:

```powershell
& "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/test_runner.gd
```

### Exit Codes:
- **`0`**: All executed tests passed cleanly with 0 assertion failures.
- **`1`**: One or more assertions failed (diagnostics and backtraces logged to stdout).

---

## 5. Verification & Acceptance Criteria
1. **Zero Facade Tests**: Every test performs genuine logic verification, math calculation, or interface probing.
2. **No False Negatives**: Downstream features not yet implemented gracefully report `[SKIP]` with clear milestone indications without causing exit code 1.
3. **Deterministic Math**: Formulas for weapon damage, armor reduction, progressive mitigation, structural bonuses, and economy transactions are checked with exact delta tolerances.
4. **Clean Engine Teardown**: Zero memory leaks or dangling tree references during headless execution.
