extends Node3D

const RHYTHM_SCENE: String = "res://scenes/rhythm_core.tscn"
const NODE_TITLES: Array[String] = ["Enemy", "Enemy", "Elite", "Item", "Shop", "Unknown", "Boss"]

@onready var _map_path: Node3D = $MapPath
@onready var _camera: Camera3D = $Camera3D

var _panel: PanelContainer
var _title: Label
var _fight_button: Button
var _selected_node_id: int = -1


# creates a small screen-space card without blocking clicks elsewhere on the map
func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MapPopupLayer"
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.name = "NodePopup"
	_panel.custom_minimum_size = Vector2(210, 0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.055, 0.105, 0.98)
	style.border_color = Color(0.646, 0.498, 0.154, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(_panel)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	_panel.add_child(layout)
	_title = Label.new()
	_title.name = "EncounterTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(0.974, 0.852, 0.713, 1.0))
	layout.add_child(_title)
	_fight_button = Button.new()
	_fight_button.name = "FightButton"
	_fight_button.text = "Fight"
	_fight_button.custom_minimum_size.y = 38
	_fight_button.pressed.connect(_on_fight_button_pressed)
	layout.add_child(_fight_button)
	_panel.hide()


# tests left clicks against the visible tokens after interface controls handle input
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_popup()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var node_id: int = _pick_node(event.position)
		if node_id >= 0:
			_show_node(node_id)
		else:
			_close_popup()
		get_viewport().set_input_as_handled()


# keeps the popup beside its token as the existing camera scrolls
func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	if _selected_node_id < 0 or _selected_node_id >= _map_path.map_nodes.size():
		_close_popup()
		return
	var point: Vector3 = _map_path.to_global(_map_path.map_nodes[_selected_node_id].position)
	if _camera.is_position_behind(point):
		_close_popup()
		return
	var screen_point: Vector2 = _camera.unproject_position(point)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	# clamp the card to the viewport so edge nodes do not create clipped popups
	_panel.position = (screen_point + Vector2(24, -_panel.size.y - 20)).clamp(
		Vector2(8, 8), (viewport_size - _panel.size - Vector2(8, 8)).max(Vector2(8, 8))
	)


# intersects the mouse ray with each token's top plane and circular footprint
func _pick_node(screen_position: Vector2) -> int:
	var origin: Vector3 = _camera.project_ray_origin(screen_position)
	var direction: Vector3 = _camera.project_ray_normal(screen_position)
	var closest: float = INF
	var selected: int = -1
	for map_node in _map_path.map_nodes:
		# transform into map space so token placement and hit testing use the same coordinates
		var local_origin: Vector3 = _map_path.to_local(origin)
		var local_direction: Vector3 = _map_path.global_basis.inverse() * direction
		if absf(local_direction.y) < 0.0001:
			continue
		var distance: float = (map_node.position.y + 0.12 - local_origin.y) / local_direction.y
		if distance < 0.0 or distance >= closest:
			continue
		var hit: Vector3 = local_origin + local_direction * distance
		var offset: Vector2 = Vector2(hit.x - map_node.position.x, hit.z - map_node.position.z)
		if offset.length() <= clampf(_map_path.token_diameter, 0.5, 1.5) * 0.5 + 0.06:
			closest = distance
			selected = map_node.id
	return selected


# shows every encounter type but exposes an action only for the starting battle
func _show_node(node_id: int) -> void:
	if node_id < 0 or node_id >= _map_path.map_nodes.size():
		return
	_selected_node_id = node_id
	_title.text = NODE_TITLES[_map_path.map_nodes[node_id].node_type]
	_fight_button.visible = node_id == 0
	_fight_button.disabled = false
	# reset the minimum size after hiding the button so preview-only cards shrink
	_panel.size = Vector2.ZERO
	_panel.show()
	_process(0.0)


# dismisses a card without changing route availability or map generation
func _close_popup() -> void:
	_selected_node_id = -1
	_panel.hide()


# enters rhythm core directly; later nodes remain previews until progression exists
func _on_fight_button_pressed() -> void:
	if _selected_node_id != 0:
		return
	_fight_button.disabled = true
	var result: Error = get_tree().change_scene_to_file(RHYTHM_SCENE)
	if result != OK:
		_fight_button.disabled = false
		push_error("could not open rhythm core: %s" % error_string(result))
