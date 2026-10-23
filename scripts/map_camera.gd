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
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_map_z -= scroll_step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_map_z += scroll_step

		target_map_z = clampf(
			target_map_z,
			map_top,
			map_bottom
		)

func _process(delta: float) -> void:
	var destiniation_z := target_map_z + camera_offset_z
	
	position.z = move_toward(
		position.z,
		destiniation_z,
		slide_speed * delta
	)
