class_name Note
extends Area2D

## Emitted when the player hits the note. `accuracy` is the absolute time
## in seconds between the input and the note's target beat.
signal hit(accuracy: float)

## Emitted when the note's hit window passes without input.
signal missed

## Beat number (from the conductor) this note should be struck on.
@export var target_beat := 0

## Direction the arrow points: 0 = up, 1 = right, 2 = down, 3 = left.
@export_range(0, 3) var direction := 0

## How many beats before the target beat the note spawns on screen.
@export var beats_early := 4

## Half-width of the hit window in seconds. Input within this time of the
## target beat counts as a hit.
@export var hit_window := 0.15

var _conductor: AudioStreamPlayer
var _sec_per_beat: float = 0.6
var _travel_time: float = 2.4
var _has_been_hit := false
var _off_screen_position: Vector2
## Where the note should be when the player strikes it; always assigned
## by the spawner (rhythm_core.gd) before the note enters the tree.
var target_position: Vector2

@onready var _arrow: Sprite2D = $Arrow


func _ready() -> void:
	_conductor = get_tree().get_first_node_in_group("conductor")
	if _conductor != null:
		_sec_per_beat = _conductor.sec_per_beat
	_travel_time = beats_early * _sec_per_beat
	_off_screen_position = _get_spawn_position()
	_arrow.rotation_degrees = direction * 90.0
	position = _off_screen_position


func _physics_process(_delta: float) -> void:
	# Check to make sure we should actually show notes
	if _has_been_hit or _conductor == null:
		return
	if not _conductor.is_song_running():
		return
	var target_time := target_beat * _sec_per_beat
	var spawn_time := target_time - _travel_time
	if _conductor.song_position < spawn_time:
		return
	
	var progress := clampf((_conductor.song_position - spawn_time) / _travel_time, 0.0, 1.0)
	position = _off_screen_position.lerp(target_position, progress)
	if progress >= 1.0:
		_check_miss()


func can_hit() -> bool:
	return not _has_been_hit and _get_accuracy() <= hit_window


func get_accuracy() -> float:
	return _get_accuracy()


func hit_note() -> void:
	if _has_been_hit:
		return
	_has_been_hit = true
	hit.emit(_get_accuracy())
	_despawn()


func is_in_window() -> bool:
	return _get_accuracy() <= hit_window


func _get_accuracy() -> float:
	var target_time: float = target_beat * _sec_per_beat
	return absf(_conductor.song_position - target_time)


func _check_miss() -> void:
	if _get_accuracy() > hit_window:
		_has_been_hit = true
		missed.emit()
		_despawn()


func _get_spawn_position() -> Vector2:
	return Vector2(target_position.x, target_position.y - 800.0)


func _despawn() -> void:
	queue_free()
