extends Sprite2D

func _process(_delta: float) -> void:
	# Only display the "off receptor" when key isn't being pressed
	visible = not Input.is_action_pressed("ui_left")
