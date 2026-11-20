class_name ItemCatalog
extends RefCounted

const DEFINITIONS: Array[ItemDefinition] = [
	preload("res://assets/items/damage_boost.tres"),
	preload("res://assets/items/metronome.tres"),
	preload("res://assets/items/merch.tres"),
	preload("res://assets/items/tuning_fork.tres"),
	preload("res://assets/items/frayed_string.tres"),
	preload("res://assets/items/new_sticks.tres"),
	preload("res://assets/items/delay_pedal.tres"),
]


static func get_definition(item_id: StringName) -> ItemDefinition:
	for definition: ItemDefinition in DEFINITIONS:
		if definition.id == item_id:
			return definition
	return null
