extends CanvasLayer

const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const GOLD: Color = Color(0.646, 0.498, 0.154)
const CREAM: Color = Color(0.974, 0.852, 0.713)
const PLUM: Color = Color(0.09, 0.055, 0.105, 0.98)

var _panel: PanelContainer
var _items: HBoxContainer
var _toggle: Button
var _paused_battle: bool = false


# keeps the inventory controls responsive while the battle is paused
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var menu_theme: Theme = Theme.new()
	menu_theme.set_stylebox("panel", "PanelContainer", _style(PLUM))
	menu_theme.set_stylebox("panel", "TooltipPanel", _style(PLUM))
	menu_theme.set_stylebox("normal", "Button", _style(PLUM))
	menu_theme.set_stylebox("hover", "Button", _style(PLUM.lightened(0.15)))
	menu_theme.set_stylebox("pressed", "Button", _style(PLUM.lightened(0.25)))
	menu_theme.set_color("font_color", "Button", CREAM)
	menu_theme.set_color("font_color", "Label", CREAM)
	menu_theme.set_color("font_color", "TooltipLabel", CREAM)

	var overlay: Control = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.theme = menu_theme
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toggle = Button.new()
	_toggle.text = "▦"
	_toggle.tooltip_text = "Items"
	_toggle.add_theme_font_size_override("font_size", 24)
	overlay.add_child(_toggle)
	_toggle.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toggle.offset_left = -64
	_toggle.offset_right = -16
	_toggle.offset_top = 16
	_toggle.offset_bottom = 60
	_toggle.pressed.connect(_on_inventory_button_pressed)

	_panel = PanelContainer.new()
	overlay.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -226
	_panel.offset_right = -16
	_panel.offset_top = 68
	var content: VBoxContainer = VBoxContainer.new()
	_panel.add_child(content)
	var title: Label = Label.new()
	title.text = "Items"
	content.add_child(title)
	_items = HBoxContainer.new()
	content.add_child(_items)
	_panel.hide()
	ItemInventory.inventory_changed.connect(_refresh_items)
	_refresh_items()


# closes the menu with escape without sending that input into the battle
func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


# releases a pause owned by this menu if the battle scene is removed
func _exit_tree() -> void:
	if _paused_battle:
		get_tree().paused = false


# toggles the menu from the right-side button
func _on_inventory_button_pressed() -> void:
	_set_open(not _panel.visible)


# resumes only when this menu was responsible for pausing the battle
func _set_open(open: bool) -> void:
	_panel.visible = open
	_toggle.text = "×" if open else "▦"
	_toggle.tooltip_text = "Close items" if open else "Items"
	if open:
		_paused_battle = not get_tree().paused
		get_tree().paused = true
	elif _paused_battle:
		get_tree().paused = false
		_paused_battle = false


# lists owned items and uses a numbered tile when an item has no artwork
func _refresh_items() -> void:
	for child: Node in _items.get_children():
		_items.remove_child(child)
		child.queue_free()
	var index: int = 1
	for item: ItemDefinition in ItemInventory.get_items():
		var tile: Button = Button.new()
		tile.custom_minimum_size = Vector2(48, 48)
		tile.icon = item.icon
		tile.expand_icon = true
		tile.focus_mode = Control.FOCUS_NONE
		tile.mouse_default_cursor_shape = Control.CURSOR_HELP
		if item.icon == null:
			tile.text = str(index)
		var count: int = ItemInventory.get_quantity(item.id)
		tile.tooltip_text = "%s ×%d\n%s" % [item.display_name, count, item.description]
		_items.add_child(tile)
		index += 1
	if index == 1:
		var empty: Label = Label.new()
		empty.text = "No items"
		_items.add_child(empty)


# matches the map popup palette for the panel, buttons and hover tooltips
func _style(background: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
