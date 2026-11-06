extends Resource

enum Stat {
	DAMAGE, CRIT_CHANCE, CRIT_MULTIPLIER, HIT_WINDOW, PERFECT_WINDOW, MAX_HEALTH,
	DAMAGE_RESISTANCE, GUITAR_RESISTANCE, BASS_RESISTANCE, DRUMS_RESISTANCE, KEYS_RESISTANCE
}

const OnHitEffect = preload("res://scripts/items/on_hit_effect.gd")

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var stat: Stat = Stat.DAMAGE
@export var flat_bonus: float = 0.0
@export var percent_bonus: float = 0.0
@export var on_hit_effects: Array[OnHitEffect] = []
