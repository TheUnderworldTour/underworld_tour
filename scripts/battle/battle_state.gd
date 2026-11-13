class_name BattleState
extends RefCounted

enum Outcome { ACTIVE, VICTORY, DEFEAT }

var player_max_health: float
var boss_max_health: float
var player_health: float
var boss_health: float
var outcome: Outcome = Outcome.ACTIVE
var _player_statuses: Array[StringName] = []
var _loadout: Dictionary[StringName, int]


func _init(
	starting_player_health: float,
	starting_boss_health: float,
	loadout: Dictionary[StringName, int]
) -> void:
	player_max_health = starting_player_health
	boss_max_health = starting_boss_health
	player_health = player_max_health
	boss_health = boss_max_health
	_loadout = loadout.duplicate()


func get_item_quantity(item_id: StringName) -> int:
	return _loadout.get(item_id, 0)


func add_player_status(status_id: StringName) -> void:
	if status_id != &"" and not has_player_status(status_id):
		_player_statuses.append(status_id)


func has_player_status(status_id: StringName) -> bool:
	return _player_statuses.has(status_id)
