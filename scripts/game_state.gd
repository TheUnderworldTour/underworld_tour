extends Node

# Inventory and cleared encounters survive battle scene reloads.
var _inventory: Dictionary[StringName, int] = {&"damage_boost": 1}
var _cleared_encounters: Dictionary[StringName, bool] = {}


func get_battle_loadout() -> Dictionary[StringName, int]:
	return _inventory.duplicate()


func record_victory(encounter_id: StringName) -> void:
	_cleared_encounters[encounter_id] = true


func has_cleared_encounter(encounter_id: StringName) -> bool:
	return _cleared_encounters.get(encounter_id, false)
