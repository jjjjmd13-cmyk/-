extends RefCounted
## Level-up upgrade pool. "heroes" limits an upgrade to specific heroes.

const POOL := [
	{"id": "might", "max": 6},
	{"id": "frenzy", "max": 5},
	{"id": "swift", "max": 4},
	{"id": "vitality", "max": 6},
	{"id": "precision", "max": 4},
	{"id": "ferocity", "max": 3},
	{"id": "vampirism", "max": 4},
	{"id": "regeneration", "max": 4},
	{"id": "ironskin", "max": 4},
	{"id": "magnet", "max": 3},
	{"id": "focus", "max": 4},
	{"id": "reach", "max": 4},
	{"id": "swiftstep", "max": 3},
	{"id": "multishot", "max": 3, "heroes": ["mage", "ranger"]},
	{"id": "piercing", "max": 3, "heroes": ["mage", "ranger"]},
	{"id": "shadowstep", "max": 3, "heroes": ["rogue"]},
	{"id": "venom", "max": 3, "heroes": ["rogue", "ranger"]},
	{"id": "thorns", "max": 3, "heroes": ["knight"]},
	{"id": "cleave", "max": 3, "heroes": ["knight", "rogue"]},
]

## Always-available fallbacks when the pool runs dry (long endless runs).
const FALLBACKS := [
	{"id": "elixir", "max": 999},
	{"id": "temper", "max": 999},
	{"id": "fortitude", "max": 999},
]


static func roll(hero_id: String, taken: Dictionary, count: int, rng: RandomNumberGenerator) -> Array:
	var options: Array = []
	for u in POOL:
		if u.has("heroes") and not u.heroes.has(hero_id):
			continue
		if int(taken.get(u.id, 0)) >= int(u.max):
			continue
		options.append(u)
	# Fisher-Yates with the run's RNG so results are reproducible per seed.
	for i in range(options.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = options[i]
		options[i] = options[j]
		options[j] = tmp
	var picked := options.slice(0, count)
	for f in FALLBACKS:
		if picked.size() >= count:
			break
		picked.append(f)
	return picked
