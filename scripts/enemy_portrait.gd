class_name EnemyPortrait
extends CharacterPortrait

func _get_portrait_root()-> String:
	return "res://assets/enemy_portraits/"

func _take_hit()->void:
	play_bad()
	
func init(name: String = "skeleton1")-> void:
	character_name = name
