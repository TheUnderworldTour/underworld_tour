class_name BattleState
extends RefCounted

enum Outcome { ACTIVE, VICTORY, DEFEAT }

var player_max_health: float
var boss_max_health: float
var player_health: float
var boss_health: float
var pending_echoes: Array[Vector2] = []
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


func get_modifier(effect: ItemDefinition.Effect, instrument: ItemDefinition.Instrument) -> float:
	var total: float = 0.0
	for item_id: StringName in _loadout:
		var definition: ItemDefinition = ItemCatalog.get_definition(item_id)
		if definition == null or definition.effect != effect:
			continue
		var applies: bool = definition.instrument == ItemDefinition.Instrument.ALL
		applies = applies or definition.instrument == instrument
		applies = applies or (
			definition.instrument == ItemDefinition.Instrument.MELODIC
			and instrument in [
				ItemDefinition.Instrument.GUITAR,
				ItemDefinition.Instrument.BASS,
				ItemDefinition.Instrument.KEYS,
			]
		)
		if applies:
			total += definition.amount * _loadout[item_id]
	return total


func get_item_quantity(item_id: StringName) -> int:
	return _loadout.get(item_id, 0)


func add_player_status(status_id: StringName) -> void:
	if status_id != &"" and not has_player_status(status_id):
		_player_statuses.append(status_id)


func has_player_status(status_id: StringName) -> bool:
	return _player_statuses.has(status_id)
