class_name Note
extends Area2D

## Emitted when the player hits the note. `accuracy` is the absolute time
## in seconds between the input and the note's target beat.
signal hit(accuracy: float)

## Emitted when a long note's hold runs to completion with the key held.
## `release_accuracy` is the absolute seconds the release lands from the
## hold's end beat (INF if the hold auto-completed while still held).
signal hold_completed(release_accuracy: float)

## Emitted when a long note's hold is dropped before its end beat.
signal hold_broken

## Emitted when the note's hit window passes without input.
signal missed

## Chart coordinates of this note: x = beat to strike, y = lane (0 = up,
## 1 = right, 2 = down, 3 = left), z = length in beats (1 = tap note).
@export var chart_coords := Vector3i.ZERO

## How many beats before the target beat the note spawns on screen.
@export var beats_early := 4

## Half-width of the hit window in seconds. Input within this time of the
## target beat counts as a hit.
@export var hit_window := 0.15

@onready var _hit_box: CollisionShape2D = $HitBox

var _conductor: AudioStreamPlayer
var _sec_per_beat: float = 0.6
var _travel_time: float = 2.4
var _has_been_hit := false
var _holding := false
var _off_screen_position: Vector2
## Where the note should be when the player strikes it; always assigned
## by the spawner (rhythm_core.gd) before the note enters the tree.
var target_position: Vector2
var chart_note_id: int = -1

var target_beat: int:
	get:
		return chart_coords.x


var lane: int:
	get:
		return chart_coords.y


var length_beats: int:
	get:
		return chart_coords.z

const TRAVEL_DISTANCE := 800
const BAR_WIDTH := 30.0
const CORNER_RADIUS := 12.0

func _ready() -> void:
	_conductor = get_tree().get_first_node_in_group("conductor")
	if _conductor != null:
		_sec_per_beat = _conductor.sec_per_beat
	_travel_time = beats_early * _sec_per_beat
	_off_screen_position = _get_spawn_position()
	position = _off_screen_position
	
	var tail_height := _get_tail_height()
	if tail_height > 0.0:
		var shape: RectangleShape2D = _hit_box.shape
		shape.size = Vector2(shape.size.x, shape.size.y + tail_height)
		_hit_box.position.y = -tail_height / 2.0
		_hit_box.scale = Vector2(1.1, 1.1) * 1.0

func _draw() -> void:
	var tail_height := _get_tail_height()
	if tail_height <= 0.0:
		return
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color.WHITE # can be changed to match arrows
	style_box.set_corner_radius_all(CORNER_RADIUS)
	var bar_rect := Rect2(-BAR_WIDTH / 2.0, -tail_height, BAR_WIDTH, tail_height)
	style_box.draw(get_canvas_item(), bar_rect)


func _physics_process(_delta: float) -> void:
	# Check to make sure we should actually show notes
	if _conductor == null:
		return
	if not _conductor.is_song_running():
		return
	var spawn_time := target_beat * _sec_per_beat - _travel_time
	if _conductor.song_position < spawn_time:
		return
	if _has_been_hit:
		return
	var progress: float = (_conductor.song_position - spawn_time) / _travel_time
	if _holding:
		# Keep scrolling past the receptor until the tail end arrives.
		position = _off_screen_position.lerp(target_position, progress)
		_process_hold_end()
		return
	position = _off_screen_position.lerp(target_position, clampf(progress, 0.0, 1.0))
	if progress >= 1.0:
		_check_miss()


func can_hit() -> bool:
	return not _has_been_hit and not _holding and _get_accuracy() <= hit_window


func is_holding() -> bool:
	return _holding


func get_accuracy() -> float:
	return _get_accuracy()


## Signed time in seconds between the song clock and the note's target
## beat. Positive means the player input (or the clock) is late.
func get_time_error() -> float:
	var target_time: float = target_beat * _sec_per_beat
	return _conductor.song_position - target_time


func hit_note() -> void:
	if _has_been_hit or _holding:
		return
	if length_beats > 1:
		_holding = true
		hit.emit(_get_accuracy())
		return
	_has_been_hit = true
	hit.emit(_get_accuracy())
	_despawn()


## Called by the input owner (rhythm_core.gd) when the lane key is
## released while this note is being held. Releasing after the tail end
## completes the hold; releasing early breaks it.
func release_hold() -> void:
	if not _holding:
		return
	_holding = false
	_has_been_hit = true
	var end_time := (target_beat + length_beats) * _sec_per_beat
	var release_error: float = _conductor.song_position - end_time
	if release_error >= 0.0:
		hold_completed.emit(absf(release_error))
	else:
		hold_broken.emit()
	_despawn()


func _process_hold_end() -> void:
	if _conductor.song_position < (target_beat + length_beats) * _sec_per_beat:
		return
	_holding = false
	_has_been_hit = true
	hold_completed.emit(INF)
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

func _get_tail_height() -> float:
	return length_beats * (TRAVEL_DISTANCE / beats_early)
