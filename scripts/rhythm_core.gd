extends Node2D

signal damage_generated(amount: float)
signal hit_resolved(amount: float, critical: bool, echo: bool)
signal status_applied(status_id: StringName, duration_seconds: float)

signal health_changed(current: float, maximum: float)

enum DamageType { GENERIC, GUITAR, BASS, DRUMS, KEYS }

const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const RESISTANCE_STATS: Array[ItemDefinition.Stat] = [
	ItemDefinition.Stat.DAMAGE_RESISTANCE,
	ItemDefinition.Stat.GUITAR_RESISTANCE,
	ItemDefinition.Stat.BASS_RESISTANCE,
	ItemDefinition.Stat.DRUMS_RESISTANCE,
	ItemDefinition.Stat.KEYS_RESISTANCE,
]

const BattleHitResolver = preload("res://scripts/items/battle_hit_resolver.gd")

const NOTE_SCENE := preload("res://scenes/note.tscn")

const PERFECT_WINDOW := 0.05
const PERFECT_SCORE := 100
const GOOD_SCORE := 50

@export var start_delay_beats := 4
@export var base_max_health: float = 100.0
@export var perfect_hit_damage: float = 10.0
@export var good_hit_damage: float = 5.0
@export_range(0.0, 100.0) var crit_chance_percent: float = 0.0
@export var crit_multiplier: float = 2.0
@export var chart: Array[Vector2i] = []

var _hit_resolver: BattleHitResolver = BattleHitResolver.new()
var _current_health: float
var _score := 0
var _combo := 0
var _next_note := 0
var _notes: Array[Note] = []

@onready var _conductor: AudioStreamPlayer = $Conductor
@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _combo_label: Label = $HUD/ComboLabel
@onready var _receptors: Array[Dictionary] = [
	{"direction": 0, "position": Vector2(500, 550)},
	{"direction": 1, "position": Vector2(800, 550)},
	{"direction": 2, "position": Vector2(650, 550)},
	{"direction": 3, "position": Vector2(350, 550)},
]


func _ready() -> void:
	_current_health = get_max_health()
	ItemInventory.inventory_changed.connect(_on_inventory_changed)
	# keep timed effects scoped to this battle and forward events to battle consumers
	add_child(_hit_resolver)
	_hit_resolver.damage_generated.connect(damage_generated.emit)
	_hit_resolver.hit_resolved.connect(hit_resolved.emit)
	_hit_resolver.status_applied.connect(status_applied.emit)
	# This will hopefully be replaced by a .json file in the future
	chart = [
		Vector2i(4, 0), Vector2i(6, 1), Vector2i(8, 2), Vector2i(10, 3),
		Vector2i(12, 0), Vector2i(12, 1), Vector2i(14, 2), Vector2i(16, 3),
	]
	chart.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	_conductor.beat.connect(_on_beat)
	_conductor.play_with_beat_offset(start_delay_beats)


func _on_beat(position: int) -> void:
	while _next_note < chart.size() and chart[_next_note].x - _conductor.beats_before_start <= position:
		_spawn_note(chart[_next_note])
		_next_note += 1


func _spawn_note(entry: Vector2i) -> void:
	var note: Note = NOTE_SCENE.instantiate()
	note.target_beat = entry.x
	note.direction = entry.y
	note.target_position = _receptors[entry.y]["position"]
	note.hit.connect(_on_note_hit)
	note.missed.connect(_on_note_missed)
	$Playfield.add_child(note)
	_notes.append(note)


const HIT_ACTIONS := {
	"hit_up": 0,
	"hit_right": 1,
	"hit_down": 2,
	"hit_left": 3,
}


func _unhandled_input(event: InputEvent) -> void:
	var direction := -1
	for action: String in HIT_ACTIONS:
		if event.is_action_pressed(action):
			direction = HIT_ACTIONS[action]
			break
	if direction == -1:
		return
	var best: Note = null
	var best_accuracy := INF
	for note in _notes:
		if not is_instance_valid(note) or note.direction != direction or not note.can_hit():
			continue
		var accuracy: float = note.get_accuracy()
		if accuracy < best_accuracy:
			best = note
			best_accuracy = accuracy
	if best != null:
		best.hit_note()


func _on_note_hit(accuracy: float) -> void:
	_combo += 1
	var perfect_window: float = clampf(
		ItemInventory.get_modified_stat(ItemDefinition.Stat.PERFECT_WINDOW, PERFECT_WINDOW),
		0.0, 0.075
	)
	var perfect: bool = accuracy <= perfect_window
	_score += PERFECT_SCORE if perfect else GOOD_SCORE
	# emit combat damage separately so item bonuses do not affect rhythm scoring
	var base_damage: float = perfect_hit_damage if perfect else good_hit_damage
	_hit_resolver.resolve_hit(base_damage, crit_chance_percent, crit_multiplier)
	_update_hud()


func _on_note_missed() -> void:
	_combo = 0
	_update_hud()
	for i in range(_notes.size() - 1, -1, -1):
		if not is_instance_valid(_notes[i]):
			_notes.remove_at(i)


func _update_hud() -> void:
	_score_label.text = "Score: %d" % _score
	_combo_label.text = "Combo: %d" % _combo

# reads maximum health from current inventory bonuses
func get_max_health() -> float:
	return maxf(1.0, ItemInventory.get_modified_stat(ItemDefinition.Stat.MAX_HEALTH, base_max_health))


# exposes health to future battle interface and enemy logic
func get_current_health() -> float:
	return _current_health


# combines general and instrument resistance and returns the health actually lost
func apply_incoming_damage(amount: float, damage_type: DamageType = DamageType.GENERIC) -> float:
	var resistance: float = ItemInventory.get_modified_stat(ItemDefinition.Stat.DAMAGE_RESISTANCE, 0.0)
	if damage_type != DamageType.GENERIC:
		resistance += ItemInventory.get_modified_stat(RESISTANCE_STATS[damage_type], 0.0)
	var damage: float = minf(_current_health, maxf(0.0, amount) * (1.0 - clampf(resistance, 0.0, 80.0) / 100.0))
	_current_health -= damage
	if damage > 0.0:
		health_changed.emit(_current_health, get_max_health())
	return damage


# clamps health when a boost is removed and reports max health changes
func _on_inventory_changed() -> void:
	var maximum: float = get_max_health()
	_current_health = minf(_current_health, maximum)
	health_changed.emit(_current_health, maximum)
