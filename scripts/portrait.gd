extends Sprite2D

@onready var portrait: Sprite2D = self

var portraits = {
	"idle_1": preload("res://assets/character_portraits/guitarist/guitarist_idle_1.png"	),
	"idle_2": preload("res://assets/character_portraits/guitarist/guitarist_idle_2.png"	),
	"play_1": preload("res://assets/character_portraits/guitarist/guitarist_play_1.png"),
	"play_2": preload("res://assets/character_portraits/guitarist/guitarist_play_2.png"),
	"bad_1": preload("res://assets/character_portraits/guitarist/guitarist_bad_1.png")
}

var state_version:=0
var curr_state:="idle_1"

var bpm:=240
var idle_timer:= 0.0
var idle_frame:=1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func set_bpm(new_bpm: int)-> void:
	bpm = new_bpm

func set_state(state: String, duration: float = 1.5) -> void:
	if not portraits.has(state):
		return
	
	curr_state = state
	
	state_version += 1
	var current_version = state_version
	
	portrait.texture = portraits[state]
	
	if state == "idle_1":
		idle_timer = 0
		idle_frame = int(state.get_slice("_", 1))
		return
	
	await get_tree().create_timer(duration).timeout
	
	if current_version == state_version:
		curr_state = "idle_1"
		portrait.texture = portraits["idle_1"]

func _input(event: InputEvent):
	if event.is_action_pressed("Test_char_0"):
		set_state("idle")
	elif event.is_action_pressed("Test_char_1"):
		set_state("play_1")
	elif event.is_action_pressed("Test_char_2"):
		set_state("play_2")
	return

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	idle_timer+=delta
	var beat_interval = 120.0 / max(bpm,1)
	
	if idle_timer >= beat_interval:
		idle_timer -= beat_interval
		if curr_state == "idle_1" or curr_state == "idle_2":
			idle_frame = 2 if idle_frame == 1 else 1
			set_state("idle_" + str(idle_frame))
