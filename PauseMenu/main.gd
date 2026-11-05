extends Node2D
@onready var main = $"."
@onready var pause_menu = $CanvasLayer/Pausemenu

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pause_menu.visible = false
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_pause()


func toggle_pause():
	get_tree().paused = !get_tree().paused
	pause_menu.visible = get_tree().paused
