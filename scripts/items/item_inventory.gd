extends Node

signal inventory_changed

const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const DAMAGE_BOOST: ItemDefinition = preload("res://assets/items/damage_boost.tres")

var _items: Dictionary[StringName, ItemDefinition] = {}
var _quantities: Dictionary[StringName, int] = {}


# seeds the session with one example item so battle damage exercises the framework
func _ready() -> void:
	add_item(DAMAGE_BOOST)


# adds copies of a definition and keeps each id tied to one resource
func add_item(item: ItemDefinition, quantity: int = 1) -> bool:
	if item == null or item.id == &"" or quantity <= 0:
		return false
	if _items.has(item.id) and _items[item.id] != item:
		return false
	_items[item.id] = item
	_quantities[item.id] = get_quantity(item.id) + quantity
	inventory_changed.emit()
	return true


# removes copies only when the full quantity is available
func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	var owned: int = get_quantity(item_id)
	if quantity <= 0 or quantity > owned:
		return false
	if owned == quantity:
		_items.erase(item_id)
		_quantities.erase(item_id)
	else:
		_quantities[item_id] = owned - quantity
	inventory_changed.emit()
	return true


# returns definitions for the owned items so a menu can list them
func get_items() -> Array[ItemDefinition]:
	return _items.values()


# returns the owned stack size, including zero for absent items
func get_quantity(item_id: StringName) -> int:
	return _quantities.get(item_id, 0)


# applies flat bonuses first, then the sum of percentage bonuses
func get_modified_stat(stat: ItemDefinition.Stat, base_value: float) -> float:
	var flat: float = 0.0
	var percent: float = 0.0
	for item_id: StringName in _items:
		var item: ItemDefinition = _items[item_id]
		if item.stat != stat:
			continue
		var quantity: int = _quantities[item_id]
		flat += item.flat_bonus * quantity
		percent += item.percent_bonus * quantity
	return (base_value + flat) * (1.0 + percent / 100.0)
