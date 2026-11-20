extends CanvasLayer

@onready var _toggle: Button = $ItemsButton
@onready var _panel: PanelContainer = $ItemsPanel
@onready var _items: VBoxContainer = $ItemsPanel/Content/Items
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


func _on_game_state_inventory_changed() -> void:
	_refresh_items()


func _set_open(open: bool) -> void:
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
	for child: Node in _items.get_children():
		_items.remove_child(child)
		child.queue_free()
	var inventory: Dictionary[StringName, int] = GameState.get_battle_loadout()
	var item_ids: Array[StringName] = inventory.keys()
	item_ids.sort()
	for item_id: StringName in item_ids:
		var definition: ItemDefinition = GameState.get_item_definition(item_id)
		var row: HBoxContainer = HBoxContainer.new()
		if definition != null and definition.icon != null:
			var icon: TextureRect = TextureRect.new()
			icon.texture = definition.icon
			icon.custom_minimum_size = Vector2(40, 40)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
		var label: Label = Label.new()
		var item_name: String = definition.display_name if definition != null else String(item_id)
		label.text = "%s ×%d" % [item_name, inventory[item_id]]
		if definition != null:
			label.tooltip_text = definition.description
		row.add_child(label)
		_items.add_child(row)
	if inventory.is_empty():
		var empty: Label = Label.new()
		empty.text = "No items"
		_items.add_child(empty)
