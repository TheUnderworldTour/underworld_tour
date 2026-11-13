extends Control

func _on_resume_pressed() -> void:
	get_tree().paused = false
	visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_settings_pressed() -> void:
	print ("Settings pressed")
