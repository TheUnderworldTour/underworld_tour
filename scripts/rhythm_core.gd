extends Node2D

const NOTE_SCENE := preload("res://scenes/note.tscn")

const PERFECT_WINDOW := 0.05
const PERFECT_SCORE := 100
const GOOD_SCORE := 50

@export var start_delay_beats := 4
@export var chart: Array[Vector2i] = []

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

@onready var _character_portrait: CharacterPortrait = $CharacterPortrait

func _ready() -> void:
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
	_score += PERFECT_SCORE if accuracy <= PERFECT_WINDOW else GOOD_SCORE
	_character_portrait.play_good()
	_update_hud()


func _on_note_missed() -> void:
	_combo = 0
	_character_portrait.play_bad()
	_update_hud()
	for i in range(_notes.size() - 1, -1, -1):
		if not is_instance_valid(_notes[i]):
			_notes.remove_at(i)

func _update_hud() -> void:
	_score_label.text = "Score: %d" % _score
	_combo_label.text = "Combo: %d" % _combo
