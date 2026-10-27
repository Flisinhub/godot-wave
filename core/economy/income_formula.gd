class_name IncomeFormula
extends RefCounted

const IncomeParams = preload("res://core/economy/income_params.gd")

## IncomeFormula - SFE5 Master Formula for Unit Elimination Bounties.
## Pure mathematical function with zero scene-tree or node side effects.
## Fully aligned with sfe5.wiki/income specification and reference cases.

static func compute(p: IncomeParams) -> int:
	if p == null:
		return 1

	var hp_eff: float = p.base_health * maxf(0.01, p.health_mult)
	var sh_eff: float = p.base_shield * maxf(0.01, p.health_mult)
	var dmg_eff: float = p.weapon_damage * maxf(0.0, p.damage_mult)
	var period: float = maxf(0.01, p.attack_period)

	var s: float = 0.0
	if p.has_weapon:
		s = (hp_eff + sh_eff) / 3.0 + dmg_eff / period
	else:
		s = ((hp_eff + sh_eff) / 3.0) * 2.0

	# Energy modifier: if max_energy > 0 -> s = s * (max_energy / 50.0)
	if p.max_energy > 0.0:
		s *= (p.max_energy / 50.0)

	# Non-linear damping curve
	if s > 500000.0:
		s = pow(s / 10.0, 0.32) * 3.0
	else:
		s = pow(maxf(0.0, s), 0.32)

	# Player distribution & split income
	if p.split_income:
		s *= 10.0 * 0.9
	else:
		var players: float = clampf(float(p.player_count), 1.0, 12.0)
		var player_factor: float = (12.0 - players) / 4.0
		s *= 4.0 * player_factor

	# Global income rate constant
	s *= 0.24

	# Category multiplier
	var cat_mult: float = p.category_multiplier
	if cat_mult <= 0.0:
		cat_mult = _get_default_category_mult(p.category)
	s *= cat_mult

	# Difficulty multiplier
	s *= maxf(0.01, p.difficulty_mult)

	# Flat pedestal puzzle bonus
	s += p.pedestal_bonus

	return maxi(1, int(round(s)))


static func _get_default_category_mult(cat: String) -> float:
	match cat.to_lower():
		"structure":
			return 8.0
		"heroic":
			return 4.0
		"elite", "map_boss":
			return 6.0
		"summoned_boss":
			return 2.0
		"pinnacle_boss":
			return 6.0
		_:
			return 1.0
