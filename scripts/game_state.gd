extends Node

signal inventory_changed

const SAVE_PATH: String = "user://game_state.json"
const SAVE_VERSION: int = 1
const ITEM_DEFINITIONS: Array[ItemDefinition] = [
	preload("res://assets/items/damage_boost.tres"),
]

var _inventory: Dictionary[StringName, int] = {&"damage_boost": 1}
var _cleared_encounters: Dictionary[StringName, bool] = {}
var _save_loaded: bool = true


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		_save_loaded = load_game()


func has_item(item_id: StringName) -> bool:
	return get_item_quantity(item_id) > 0


func get_item_quantity(item_id: StringName) -> int:
	return _inventory.get(item_id, 0)


func get_item_definition(item_id: StringName) -> ItemDefinition:
	for definition: ItemDefinition in ITEM_DEFINITIONS:
		if definition.id == item_id:
			return definition
	return null


func get_battle_loadout() -> Dictionary[StringName, int]:
	return _inventory.duplicate()


func add_item(item_id: StringName, quantity: int = 1) -> bool:
	if (
		get_item_definition(item_id) == null
		or quantity <= 0
		or quantity > 2147483647 - get_item_quantity(item_id)
	):
		return false
	return _set_item_quantity(item_id, get_item_quantity(item_id) + quantity)


func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	if quantity <= 0 or quantity > get_item_quantity(item_id):
		return false
	return _set_item_quantity(item_id, get_item_quantity(item_id) - quantity)


func record_victory(encounter_id: StringName) -> void:
	_cleared_encounters[encounter_id] = true
	save_game()


func has_cleared_encounter(encounter_id: StringName) -> bool:
	return _cleared_encounters.get(encounter_id, false)


func save_game() -> bool:
	# Preserve an unreadable or newer save until it can be loaded successfully.
	if not _save_loaded:
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		push_error("Could not open the game save for writing.")
		return false
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"inventory": _inventory,
		"cleared_encounters": _cleared_encounters.keys(),
	}, "\t"))
	file.flush()
	var write_result: Error = file.get_error()
	file.close()
	if write_result != OK:
		push_error("Could not write the game save.")
		return false
	var rename_result: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(SAVE_PATH + ".tmp"),
		ProjectSettings.globalize_path(SAVE_PATH)
	)
	if rename_result != OK:
		push_error("Could not replace the game save.")
		return false
	return true


func load_game() -> bool:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _reject_save()
	var data: Dictionary = parsed
	if data.get("version") != SAVE_VERSION:
		return _reject_save()
	var inventory_data: Variant = data.get("inventory")
	var cleared_data: Variant = data.get("cleared_encounters")
	if not inventory_data is Dictionary or not cleared_data is Array:
		return _reject_save()
	var inventory: Dictionary[StringName, int] = {}
	for item_id: Variant in inventory_data:
		var quantity: Variant = inventory_data[item_id]
		if not item_id is String or String(item_id).is_empty():
			return _reject_save()
		if not (quantity is float or quantity is int):
			return _reject_save()
		if not is_finite(float(quantity)) or quantity <= 0 or quantity != floor(float(quantity)):
			return _reject_save()
		if quantity > 2147483647:
			return _reject_save()
		# Keep unknown IDs so temporarily unavailable definitions retain ownership.
		inventory[StringName(item_id)] = int(quantity)
	var cleared: Dictionary[StringName, bool] = {}
	for encounter_id: Variant in cleared_data:
		if not encounter_id is String or String(encounter_id).is_empty():
			return _reject_save()
		cleared[StringName(encounter_id)] = true
	_inventory = inventory
	_cleared_encounters = cleared
	_save_loaded = true
	inventory_changed.emit()
	return true


func _set_item_quantity(item_id: StringName, quantity: int) -> bool:
	var previous: int = get_item_quantity(item_id)
	if quantity == 0:
		_inventory.erase(item_id)
	else:
		_inventory[item_id] = quantity
	if not save_game():
		if previous == 0:
			_inventory.erase(item_id)
		else:
			_inventory[item_id] = previous
		return false
	inventory_changed.emit()
	return true


func _reject_save() -> bool:
	_save_loaded = false
	push_error("Game save is invalid or uses an unsupported version.")
	return false
