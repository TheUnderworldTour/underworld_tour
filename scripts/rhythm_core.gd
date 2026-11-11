class_name RhythmCore
extends Node2D

signal note_judged(event: RhythmJudgment)
signal extra_note_played(lane: int, song_time_sec: float)
signal song_beat_reached(beat: int)
signal chart_completed

const NOTE_SCENE := preload("res://scenes/note.tscn")
const HIT_ACTIONS: Dictionary[String, int] = {
	"hit_up": 0,
	"hit_right": 1,
	"hit_down": 2,
	"hit_left": 3,
}

@export var start_delay_beats := 4
@export var chart: Array[Vector2i] = []

@onready var _conductor: AudioStreamPlayer = $Conductor
@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _combo_label: Label = $HUD/ComboLabel
@onready var _judgement_label: Label = $HUD/JudgementLabel
@onready var _receptors: Array[Dictionary] = [
	{"direction": 0, "position": Vector2(500, 550)},
	{"direction": 1, "position": Vector2(800, 550)},
	{"direction": 2, "position": Vector2(650, 550)},
	{"direction": 3, "position": Vector2(350, 550)},
]

@onready var character_portrait: CharacterPortrait = $CharacterPortrait

var _judge: Judge
var _next_note: int = 0
var _completed_notes: int = 0
var _chart_stopped: bool = false
var _notes: Array[Note] = []


func _ready() -> void:
	# This will hopefully be replaced by a .json file in the future
	# 3 = left, 0 = up, 2 = down, 1 = right
	chart = [
		Vector2i(1, 3), Vector2i(1, 0), Vector2i(4, 0), Vector2i(4, 2), Vector2i(8, 2), 
		Vector2i(9, 3), Vector2i(10, 0), Vector2i(11, 0),
	]
	chart.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	_judge = Judge.new()
	add_child(_judge)
	_judge.judged.connect(_on_judge_judged)
	_conductor.beat.connect(_on_conductor_beat)
	_conductor.play_with_beat_offset(start_delay_beats)


func _unhandled_input(event: InputEvent) -> void:
	if _chart_stopped:
		return
	var direction: int = -1
	for action: String in HIT_ACTIONS:
		if event.is_action_pressed(action):
			direction = HIT_ACTIONS[action]
			break
	if direction == -1:
		return
	var best: Note = null
	var best_accuracy: float = INF
	for note: Note in _notes:
		if not is_instance_valid(note) or note.direction != direction or not note.can_hit():
			continue
		var accuracy: float = note.get_accuracy()
		if accuracy < best_accuracy:
			best = note
			best_accuracy = accuracy
	if best != null:
		best.hit_note()
	elif _conductor.is_song_running():
		extra_note_played.emit(direction, _conductor.song_position)


func stop_chart() -> void:
	_chart_stopped = true
	_conductor.stop()
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)


func _on_conductor_beat(position: int) -> void:
	if _chart_stopped:
		return
	if _conductor.is_song_running():
		song_beat_reached.emit(position - _conductor.beats_before_start)
	if _chart_stopped:
		return
	while _next_note < chart.size() and chart[_next_note].x - _conductor.beats_before_start <= position:
		_spawn_note(chart[_next_note])
		_next_note += 1


func _spawn_note(entry: Vector2i) -> void:
	var note: Note = NOTE_SCENE.instantiate()
	note.chart_note_id = _next_note
	note.target_beat = entry.x
	note.direction = entry.y
	note.target_position = _receptors[entry.y]["position"]
	note.hit.connect(_on_note_hit.bind(note))
	note.missed.connect(_on_note_missed.bind(note))
	note.hold_completed.connect(_on_note_hold_completed.bind(note))
	note.hold_broken.connect(_on_note_hold_broken.bind(note))
	$Playfield.add_child(note)
	_notes.append(note)


func _on_note_hit(accuracy: float, note: Note) -> void:
	_judge.judge_note_hit(note, accuracy)
	character_portrait.play_good()


func _on_note_missed(note: Note) -> void:
	_judge.judge_note_miss(note)
	_prune_despawned_notes()
	character_portrait.play_bad()


func _on_note_hold_completed(release_accuracy: float, note: Note) -> void:
	_judge.judge_hold_completed(note, release_accuracy)


func _on_note_hold_broken(note: Note) -> void:
	_judge.judge_hold_broken(note)
	_prune_despawned_notes()


func _prune_despawned_notes() -> void:
	for i in range(_notes.size() - 1, -1, -1):
		if not is_instance_valid(_notes[i]):
			_notes.remove_at(i)


func _on_judge_judged(
	judgement: Judge.Judgement, accuracy: float, time_error: float, note: Note, phase: Judge.Phase
) -> void:
	if _chart_stopped:
		return
	_score_label.text = "Score: %d" % _judge.score
	_combo_label.text = "Combo: %d" % _judge.combo
	_show_judgement(judgement)

	var event: RhythmJudgment = RhythmJudgment.new()
	event.note_id = note.chart_note_id
	event.lane = note.direction
	event.target_beat = note.target_beat
	event.song_time_sec = _conductor.song_position
	event.tier = judgement
	event.phase = phase
	event.accuracy_sec = accuracy
	event.time_error_sec = time_error if is_finite(accuracy) else INF
	event.has_input_timing = is_finite(accuracy)
	note_judged.emit(event)
	if phase != Judge.Phase.HOLD_START:
		_completed_notes += 1
		if _completed_notes == chart.size():
			chart_completed.emit()


func _show_judgement(judgement: Judge.Judgement) -> void:
	var text: String = Judge.Judgement.keys()[judgement]
	_judgement_label.text = text
	_judgement_label.modulate = Judge.TIER_COLORS[judgement]
	_judgement_label.scale = Vector2.ONE * 1.25
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_judgement_label, "scale", Vector2.ONE, 0.08)
	tween.tween_property(_judgement_label, "modulate:a", 0.0, 0.4).set_delay(0.15)
