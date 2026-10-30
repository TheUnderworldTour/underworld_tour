class_name CharacterPortrait
extends Node2D

@onready var portrait: Sprite2D = $Portrait

var portraits = {
	"idle_1": preload("res://assets/character_portraits/guitarist/guitarist_idle_1.png"	),
	"idle_2": preload("res://assets/character_portraits/guitarist/guitarist_idle_2.png"	),
	"play_1": preload("res://assets/character_portraits/guitarist/guitarist_play_1.png"),
	"play_2": preload("res://assets/character_portraits/guitarist/guitarist_play_2.png"),
	"bad_1": preload("res://assets/character_portraits/guitarist/guitarist_bad_1.png")
}

var idle_portraits = [
	"idle_1",
	"idle_2"
]

var good_portraits = [
	"play_1",
	"play_2"
]

var bad_portraits = [
	"bad_1"
]

var state_version:=0
var curr_state:="idle_1"

var bpm:=240
var idle_timer:= 0.0
var idle_frame:=1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	pass # Replace with function body.

func set_bpm(new_bpm: int)-> void:
	bpm = new_bpm

func set_state(state: String, duration: float = 0.5) -> void:
	if not portraits.has(state):
		return
	
	curr_state = state
	
	state_version += 1
	var current_version = state_version
	
	portrait.texture = portraits[state]
	
	if state in idle_portraits:
		idle_timer = 0
		idle_frame = idle_portraits.find(state)
		return
	
	await get_tree().create_timer(duration).timeout
	
	if current_version == state_version:
		curr_state = "idle_1"
		portrait.texture = portraits["idle_1"]

func play_good() -> void:
	var idx = randi() % good_portraits.size()
	var state = good_portraits[idx]
	set_state(state)
	pass

func play_bad() -> void:
	var idx = randi() % bad_portraits.size()
	var state = bad_portraits[idx]
	set_state(state)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	idle_timer+=delta
	var beat_interval = 60.0 / max(bpm,1)
	
	if idle_timer >= beat_interval:
		idle_timer -= beat_interval
		if curr_state in  idle_portraits:
			idle_frame = (idle_frame + 1) % idle_portraits.size()
			set_state(idle_portraits[idle_frame])
