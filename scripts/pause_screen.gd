extends Node2D
@onready var main = $"."
@onready var pause_menu = $CanvasLayer/PauseMenu

func _ready():
	pause_menu.visible = false
	pass 

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause(): 
	get_tree().paused = !get_tree().paused
	pause_menu.visible = get_tree().paused
