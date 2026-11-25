extends CanvasLayer

@onready var _toggle: Button = $ItemsButton
@onready var _panel: PanelContainer = $ItemsPanel
@onready var _items: GridContainer = $ItemsPanel/Content/Items
@onready var _hover_panel: PanelContainer = $HoverPanel
@onready var _hover_text: Label = $HoverPanel/Text
@onready var _close: Button = $ItemsPanel/Content/CloseButton

var _owns_pause: bool = false


func _ready() -> void:
	_toggle.pressed.connect(_on_items_button_pressed)
	_close.pressed.connect(_on_close_button_pressed)
	$ItemsPanel/Content/DemoItemsButton.pressed.connect(_on_demo_items_button_pressed)
	GameState.inventory_changed.connect(_on_game_state_inventory_changed)
	_refresh_items()


func _input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false


func _on_items_button_pressed() -> void:
	_set_open(not _panel.visible)


func _on_demo_items_button_pressed() -> void:
	if not GameState.equip_demo_items():
		$ItemsPanel/Content/DemoItemsButton.text = "Could not save demo items"
		return
	_set_open(false)
	var result: Error = get_tree().reload_current_scene()
	if result != OK:
		push_error("Could not restart the battle.")


func _on_close_button_pressed() -> void:
	_set_open(false)


func _on_item_tile_mouse_entered(tile: Button, details: String) -> void:
	if not _panel.visible:
		return
	_hover_text.text = details
	_hover_panel.reset_size()
	var viewport_size: Vector2 = _panel.get_viewport_rect().size
	var desired: Vector2 = tile.global_position + Vector2(tile.size.x + 8.0, 0.0)
	_hover_panel.position = Vector2(
		clampf(desired.x, 0.0, maxf(0.0, viewport_size.x - _hover_panel.size.x)),
		clampf(desired.y, 0.0, maxf(0.0, viewport_size.y - _hover_panel.size.y))
	)
	_hover_panel.show()


func _on_item_tile_mouse_exited() -> void:
	_hover_panel.hide()


func _on_game_state_inventory_changed() -> void:
	_refresh_items()


func _set_open(open: bool) -> void:
	_hover_panel.hide()
	_panel.visible = open
	if open:
		_refresh_items()
		_owns_pause = not get_tree().paused
		get_tree().paused = true
		_close.grab_focus()
	elif _owns_pause:
		get_tree().paused = false
		_owns_pause = false


func _refresh_items() -> void:
	_hover_panel.hide()
	for child: Node in _items.get_children():
		_items.remove_child(child)
		child.queue_free()
	var inventory: Dictionary[StringName, int] = GameState.get_battle_loadout()
	var item_ids: Array[StringName] = inventory.keys()
	item_ids.sort()
	for item_id: StringName in item_ids:
		var definition: ItemDefinition = GameState.get_item_definition(item_id)
		var tile: Button = Button.new()
		tile.custom_minimum_size = Vector2(64, 64)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tile.focus_mode = Control.FOCUS_NONE
		var item_name: String = definition.display_name if definition != null else String(item_id)
		var details: String = item_name
		if definition != null:
			details += "\n" + definition.description
		tile.mouse_entered.connect(_on_item_tile_mouse_entered.bind(tile, details))
		tile.mouse_exited.connect(_on_item_tile_mouse_exited)
		if definition != null and definition.icon != null:
			tile.icon = definition.icon
			tile.expand_icon = true
		else:
			tile.text = str(item_ids.find(item_id) + 1)
		var quantity: Label = Label.new()
		quantity.name = "Quantity"
		quantity.text = "×%d" % inventory[item_id]
		quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(quantity)
		quantity.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		quantity.offset_left = 5.0
		quantity.offset_top = -22.0
		quantity.offset_right = 59.0
		quantity.offset_bottom = -3.0
		quantity.add_theme_font_size_override("font_size", 12)
		_items.add_child(tile)
	if inventory.is_empty():
		var empty: Label = Label.new()
		empty.text = "No items"
		_items.add_child(empty)
