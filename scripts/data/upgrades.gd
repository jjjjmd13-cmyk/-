extends RefCounted
## Level-up cards.
##   rarity  common / rare / legendary (border colour, and how often they show)
##   heroes  limits a card to specific heroes
##   group   skill branches: taking one card of a group closes the others
##   needs   evolutions: appear once both listed cards are at their max
##   boss    legendary cards offered only as a boss reward

const POOL := [
	{"id": "might", "max": 5, "rarity": "common"},
	{"id": "frenzy", "max": 4, "rarity": "common"},
	{"id": "swift", "max": 4, "rarity": "common"},
	{"id": "vitality", "max": 5, "rarity": "common"},
	{"id": "precision", "max": 4, "rarity": "common"},
	{"id": "regeneration", "max": 4, "rarity": "common"},
	{"id": "ironskin", "max": 4, "rarity": "common"},
	{"id": "magnet", "max": 3, "rarity": "common"},
	{"id": "reach", "max": 3, "rarity": "common"},
	{"id": "swiftstep", "max": 3, "rarity": "common"},
	{"id": "ferocity", "max": 3, "rarity": "rare"},
	{"id": "vampirism", "max": 3, "rarity": "rare"},
	{"id": "focus", "max": 4, "rarity": "rare"},
	{"id": "multishot", "max": 3, "rarity": "rare", "heroes": ["mage", "ranger"]},
	{"id": "piercing", "max": 3, "rarity": "rare", "heroes": ["mage", "ranger"]},
	{"id": "shadowstep", "max": 3, "rarity": "rare", "heroes": ["rogue"]},
	{"id": "venom", "max": 3, "rarity": "rare", "heroes": ["rogue", "ranger"]},
	{"id": "thorns", "max": 3, "rarity": "rare", "heroes": ["knight"]},
	{"id": "cleave", "max": 3, "rarity": "rare", "heroes": ["knight", "rogue"]},

	# Skill branches: two paths per skill, picking one closes the other.
	{"id": "rogue_skill_a", "group": "rogue_skill", "slot": "skill", "heroes": ["rogue"]},
	{"id": "rogue_skill_b", "group": "rogue_skill", "slot": "skill", "heroes": ["rogue"]},
	{"id": "rogue_skill2_a", "group": "rogue_skill2", "slot": "skill2", "heroes": ["rogue"]},
	{"id": "rogue_skill2_b", "group": "rogue_skill2", "slot": "skill2", "heroes": ["rogue"]},
	{"id": "rogue_ult_a", "group": "rogue_ult", "slot": "ult", "heroes": ["rogue"]},
	{"id": "rogue_ult_b", "group": "rogue_ult", "slot": "ult", "heroes": ["rogue"]},
	{"id": "mage_skill_a", "group": "mage_skill", "slot": "skill", "heroes": ["mage"]},
	{"id": "mage_skill_b", "group": "mage_skill", "slot": "skill", "heroes": ["mage"]},
	{"id": "mage_skill2_a", "group": "mage_skill2", "slot": "skill2", "heroes": ["mage"]},
	{"id": "mage_skill2_b", "group": "mage_skill2", "slot": "skill2", "heroes": ["mage"]},
	{"id": "mage_ult_a", "group": "mage_ult", "slot": "ult", "heroes": ["mage"]},
	{"id": "mage_ult_b", "group": "mage_ult", "slot": "ult", "heroes": ["mage"]},
	{"id": "ranger_skill_a", "group": "ranger_skill", "slot": "skill", "heroes": ["ranger"]},
	{"id": "ranger_skill_b", "group": "ranger_skill", "slot": "skill", "heroes": ["ranger"]},
	{"id": "ranger_skill2_a", "group": "ranger_skill2", "slot": "skill2", "heroes": ["ranger"]},
	{"id": "ranger_skill2_b", "group": "ranger_skill2", "slot": "skill2", "heroes": ["ranger"]},
	{"id": "ranger_ult_a", "group": "ranger_ult", "slot": "ult", "heroes": ["ranger"]},
	{"id": "ranger_ult_b", "group": "ranger_ult", "slot": "ult", "heroes": ["ranger"]},
	{"id": "knight_skill_a", "group": "knight_skill", "slot": "skill", "heroes": ["knight"]},
	{"id": "knight_skill_b", "group": "knight_skill", "slot": "skill", "heroes": ["knight"]},
	{"id": "knight_skill2_a", "group": "knight_skill2", "slot": "skill2", "heroes": ["knight"]},
	{"id": "knight_skill2_b", "group": "knight_skill2", "slot": "skill2", "heroes": ["knight"]},
	{"id": "knight_ult_a", "group": "knight_ult", "slot": "ult", "heroes": ["knight"]},
	{"id": "knight_ult_b", "group": "knight_ult", "slot": "ult", "heroes": ["knight"]},

	# Evolutions: unlocked by maxing two cards.
	{"id": "evo_executioner", "rarity": "legendary", "needs": ["might", "ferocity"]},
	{"id": "evo_tempest", "rarity": "legendary", "needs": ["swift", "swiftstep"]},
	{"id": "evo_plague", "rarity": "legendary", "needs": ["venom", "piercing"]},
	{"id": "evo_nightblade", "rarity": "legendary", "needs": ["venom", "shadowstep"]},
	{"id": "evo_blood_armor", "rarity": "legendary", "needs": ["vampirism", "thorns"]},
	{"id": "evo_barrage", "rarity": "legendary", "needs": ["multishot", "frenzy"]},
	{"id": "evo_whirlwind", "rarity": "legendary", "needs": ["cleave", "reach"]},

	# Boss rewards (waves 5 and 10).
	{"id": "boss_undying", "rarity": "legendary", "boss": true},
	{"id": "boss_berserk", "rarity": "legendary", "boss": true},
	{"id": "boss_ascendance", "rarity": "legendary", "boss": true},
	{"id": "boss_colossus", "rarity": "legendary", "boss": true},
	{"id": "boss_hunter", "rarity": "legendary", "boss": true},
	{"id": "boss_crown", "rarity": "legendary", "boss": true},
]

## Repeatable fillers once the pool runs dry (long endless runs).
const FALLBACKS := [
	{"id": "elixir", "max": 999, "rarity": "common"},
	{"id": "temper", "max": 999, "rarity": "common"},
	{"id": "fortitude", "max": 999, "rarity": "common"},
]

## Small boosts applied automatically on levels without a card choice.
const MINOR := ["minor_damage", "minor_haste", "minor_health", "minor_speed", "minor_crit"]

const RARITY_COLOR := {
	"common": Color(0.62, 0.6, 0.58),
	"rare": Color(0.4, 0.62, 1.0),
	"legendary": Color(1.0, 0.72, 0.25),
}
## Relative chance of a card of each rarity showing up in a normal roll.
const RARITY_WEIGHT := {"common": 1.0, "rare": 0.55, "legendary": 1.0}


static func card(id: String) -> Dictionary:
	for u in POOL + FALLBACKS:
		if u.id == id:
			return u
	return {"id": id, "max": 1, "rarity": "common"}


static func max_of(u: Dictionary) -> int:
	return int(u.get("max", 1))


static func rarity_of(u: Dictionary) -> String:
	# Skill branches are rare by default.
	return u.get("rarity", "rare")


static func is_choice_level(level: int) -> bool:
	## Every other level (and every fifth) asks for a card; the rest auto-apply a small boost.
	return level % 2 == 0 or level % 5 == 0


static func available(hero_id: String, taken: Dictionary, banned: Array, boss: bool) -> Array:
	var out: Array = []
	var closed := {}
	for u in POOL:
		if u.has("group") and taken.has(u.id):
			closed[u.group] = true
	for u in POOL:
		if banned.has(u.id) or bool(u.get("boss", false)) != boss:
			continue
		if u.has("heroes") and not u.heroes.has(hero_id):
			continue
		if int(taken.get(u.id, 0)) >= max_of(u):
			continue
		if u.has("group") and closed.has(u.group):
			continue
		if u.has("needs"):
			var ready := true
			for n in u.needs:
				if int(taken.get(n, 0)) < max_of(card(n)):
					ready = false
			if not ready:
				continue
		out.append(u)
	return out


static func roll(hero_id: String, taken: Dictionary, count: int, rng: RandomNumberGenerator,
		banned: Array = [], need_rare := false, boss := false) -> Array:
	var options := available(hero_id, taken, banned, boss)
	var picked: Array = []
	# A ready evolution always shows up.
	for u in options:
		if u.has("needs") and picked.size() < count:
			picked.append(u)
	options = options.filter(func(u) -> bool: return not picked.has(u))
	if need_rare and picked.is_empty():
		var rares := options.filter(func(u) -> bool: return rarity_of(u) != "common")
		if not rares.is_empty():
			var r = rares[rng.randi_range(0, rares.size() - 1)]
			picked.append(r)
			options.erase(r)
	# Weighted draw without replacement, using the run's RNG.
	while picked.size() < count and not options.is_empty():
		var total := 0.0
		for u in options:
			total += RARITY_WEIGHT[rarity_of(u)]
		var x := rng.randf() * total
		var chosen = options[options.size() - 1]
		for u in options:
			x -= RARITY_WEIGHT[rarity_of(u)]
			if x <= 0.0:
				chosen = u
				break
		picked.append(chosen)
		options.erase(chosen)
	if not boss:
		for f in FALLBACKS:
			if picked.size() >= count:
				break
			picked.append(f)
	return picked
