extends Camera3D

@export var scroll_step: float = 2.0
@export var slide_speed: float = 10.0

@export var map_top: float = -14.0
@export var map_bottom: float = 14.0

var target_map_z: float
var camera_offset_z: float

func _ready() -> void:
	camera_offset_z = position.y / tan(-rotation.x)
	
	target_map_z = map_bottom
	position.z = target_map_z + camera_offset_z

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
