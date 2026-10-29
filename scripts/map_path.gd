extends Node3D

enum NodeType { START, COMBAT, ELITE, ITEM, SHOP, STORY, FINISH }

const MAX_ACTIVE_PATHS: int = 3
const PATH_SHADER: Shader = preload("res://assets/map_scene/dotted_path.gdshader")
const TOKEN_SCENE: PackedScene = preload("res://assets/map_scene/map_icons.glb")
const TOKEN_NAMES: Array[StringName] = [&"story", &"combat", &"elite", &"item", &"shop", &"story", &"elite"]
const ENCOUNTER_TYPES: Array[NodeType] = [
	NodeType.COMBAT, NodeType.ELITE, NodeType.ITEM, NodeType.SHOP, NodeType.STORY
]

@export_range(2, 100, 1) var node_count: int = 9 # number of rows, including endpoints.
@export var start_z: float = 14.0
@export var end_z: float = -18.0
@export var path_width: float = 3.0
@export_range(1, 3, 1) var max_active_paths: int = 3
@export var generation_seed: int = 0 # zero randomizes; other values reproduce a map.
@export_range(0.0, 1.0, 0.05) var placement_variation: float = 0.8
@export_range(0.0, 0.5, 0.01) var path_wobble: float = 0.24
@export_range(0.5, 1.5, 0.05) var token_diameter: float = 1.05

# graph data remains independent of token visuals and future hover behavior.
class MapNode:
	extends RefCounted
	var id: int
	var row: int
	var node_type: NodeType
	var position: Vector3
	var next_node_ids: Array[int] = []

	# stores a node's graph identity, encounter type and terrain-aware position
	func _init(new_id: int, new_row: int, new_type: NodeType, point: Vector3) -> void:
		id = new_id
		row = new_row
		node_type = new_type
		position = point

var map_nodes: Array[MapNode] = []
var connections: Array[Vector2i] = []
var connection_paths: Array[PackedVector3Array] = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _path_visuals: Node3D
var _token_meshes: Dictionary[StringName, Mesh] = {}
var _line_material: ShaderMaterial
@onready var _terrain: MeshInstance3D = get_node("../MapSurface") as MeshInstance3D


# loads shared token meshes and builds the initial map and border pillars
func _ready() -> void:
	_load_token_meshes()
	_line_material = ShaderMaterial.new()
	_line_material.shader = PATH_SHADER
	generate_path()
	generate_pillars()


# rebuilds the graph, tokens and curved connections from the current settings
func generate_path() -> void:
	if generation_seed == 0:
		_random.randomize()
	else:
		_random.seed = generation_seed
	# discard the old graph before replacing its visual container
	map_nodes.clear()
	connections.clear()
	connection_paths.clear()
	if is_instance_valid(_path_visuals):
		remove_child(_path_visuals)
		_path_visuals.queue_free()
	_path_visuals = Node3D.new()
	_path_visuals.name = "GeneratedPath"
	add_child(_path_visuals)

	# clamp runtime assignments as well as inspector inputs
	var row_count: int = maxi(node_count, 2)
	var path_limit: int = clampi(max_active_paths, 1, MAX_ACTIVE_PATHS)
	var previous_row: Array[int] = []
	var row_widths: Array[int] = []
	# decide structure before spending random values on placement or encounter types.
	for row_index in range(row_count):
		var width: int = _choose_row_width(path_limit)
		if row_index == 0 or row_index == row_count - 1:
			width = 1
		elif row_index == 1:
			width = mini(path_limit, 2)
		elif width == 3 and row_widths[-1] == 3:
			width = 2 # avoid long stretches of three parallel paths.
		row_widths.append(width)
	for row_index in range(row_count):
		var width: int = row_widths[row_index]
		var current_row: Array[int] = _create_row(row_index, row_count, width)
		_connect_rows(previous_row, current_row)
		previous_row = current_row

	for map_node in map_nodes:
		_add_token(map_node)
	# share one bend per row gap so neighboring routes drift in the same direction
	var bends: Array[float] = []
	for row_index in range(row_count - 1):
		bends.append(_random.randf_range(-1.0, 1.0) * clampf(path_wobble, 0.0, 0.5))
	for connection in connections:
		_add_connection(map_nodes[connection.x].position, map_nodes[connection.y].position, bends[map_nodes[connection.x].row])


# chooses a row width with two routes favored over bottlenecks and three-way branches
func _choose_row_width(path_limit: int) -> int:
	if path_limit == 1:
		return 1
	var roll: float = _random.randf()
	# two paths are the norm; occasional bottlenecks and three-way branches.
	if roll < 0.15:
		return 1
	if path_limit == 3 and roll > 0.75:
		return 3
	return 2


# places typed graph nodes in separated random zones and samples their ground height
func _create_row(row_index: int, row_count: int, width: int) -> Array[int]:
	var result: Array[int] = []
	var progress: float = float(row_index) / float(row_count - 1)
	# keep tokens inside the pillars, including when edited in the inspector.
	var horizontal_extent: float = clampf(absf(path_width), 1.0, 3.8)
	var zone_width: float = horizontal_extent * 2.0 / float(width)
	var depth_step: float = (end_z - start_z) / float(row_count - 1)
	var variation: float = clampf(placement_variation, 0.0, 1.0)
	for lane in range(width):
		# leave breathing room between adjacent tokens while retaining random zones.
		var center_x: float = -horizontal_extent + zone_width * (float(lane) + 0.5)
		var jitter_limit: float = zone_width * 0.32
		if width > 1:
			jitter_limit = minf(jitter_limit, maxf((zone_width - token_diameter - 0.3) * 0.5, 0.0))
		var x: float = center_x + _random.randf_range(-1.0, 1.0) * jitter_limit * variation
		var z: float = lerpf(start_z, end_z, progress)
		# stagger depth within a small fraction of row spacing so rows retain their order
		z += _random.randf_range(-0.18, 0.18) * depth_step * variation
		if row_index == 0 or row_index == row_count - 1:
			x = 0.0
			z = lerpf(start_z, end_z, progress)
		var point: Vector3 = Vector3(x, _token_base_height(x, z), z)
		var node_type: NodeType = ENCOUNTER_TYPES[_random.randi_range(0, ENCOUNTER_TYPES.size() - 1)]
		if row_index == 0:
			node_type = NodeType.START
		elif row_index == row_count - 1:
			node_type = NodeType.FINISH
		var node_id: int = map_nodes.size()
		map_nodes.append(MapNode.new(node_id, row_index, node_type, point))
		result.append(node_id)
	return result


# links ordered rows so every node has a route onward within the active path cap
func _connect_rows(previous_row: Array[int], current_row: Array[int]) -> void:
	if previous_row.is_empty():
		return
	# ordered grouping splits/merges without crossings. each gap has exactly
	# max(previous width, current width) edges, so at most three active paths.
	var edge_count: int = maxi(previous_row.size(), current_row.size())
	for edge_index in range(edge_count):
		# map edge slots proportionally onto both rows to create ordered splits or merges
		var from_index: int = floori(float(edge_index * previous_row.size()) / float(edge_count))
		var to_index: int = floori(float(edge_index * current_row.size()) / float(edge_count))
		var from_id: int = previous_row[from_index]
		var to_id: int = current_row[to_index]
		map_nodes[from_id].next_node_ids.append(to_id)
		connections.append(Vector2i(from_id, to_id))


# caches the named token meshes while preserving their original materials
func _load_token_meshes() -> void:
	# the glb is a display lineup with offsets. reuse each named mesh, not its
	# display transform, and keep the authored surface materials intact.
	var library: Node3D = TOKEN_SCENE.instantiate() as Node3D
	for token_name in TOKEN_NAMES:
		var source: MeshInstance3D = library.get_node(NodePath(token_name)) as MeshInstance3D
		_token_meshes[token_name] = source.mesh
	# cached mesh resources remain referenced after the temporary display scene is freed
	library.free()


# creates a metadata anchor and centers a consistently sized token above its footprint
func _add_token(map_node: MapNode) -> void:
	var anchor: Node3D = Node3D.new()
	anchor.name = "MapNode_%d_%s" % [map_node.id, NodeType.keys()[map_node.node_type]]
	# keep graph identity on the anchor for later hover and selection behavior
	anchor.set_meta("map_node_id", map_node.id)
	# keep graph identity on the anchor for later hover and selection behavior
	anchor.set_meta("node_type", map_node.node_type)
	_path_visuals.add_child(anchor)
	anchor.position = map_node.position
	var token: MeshInstance3D = MeshInstance3D.new()
	token.name = "Token"
	token.mesh = _token_meshes[TOKEN_NAMES[map_node.node_type]]
	var bounds: AABB = token.mesh.get_aabb()
	var diameter: float = clampf(token_diameter, 0.5, 1.5)
	# normalize the largest horizontal dimension without distorting the model
	var scale_factor: float = diameter / maxf(bounds.size.x, bounds.size.z)
	token.scale = Vector3.ONE * scale_factor
	# center each mesh horizontally and seat its base above the path ribbon.
	token.position = Vector3(
		-bounds.get_center().x * scale_factor,
		-bounds.position.y * scale_factor,
		-bounds.get_center().z * scale_factor
	)
	anchor.add_child(token)


# samples a meandering route and builds a dotted terrain-following ribbon along it
func _add_connection(from_point: Vector3, to_point: Vector3, bend: float) -> void:
	var start: Vector3 = Vector3(from_point.x, 0.15, from_point.z)
	var finish: Vector3 = Vector3(to_point.x, 0.15, to_point.z)
	var points: PackedVector3Array = PackedVector3Array()
	# neighbouring branches share a gentle drift instead of bending into each other.
	var ripple: float = bend * 0.25
	# use more samples on long links to keep the ribbon from cutting through hills
	var sample_count: int = maxi(24, ceili(start.distance_to(finish) / 0.18))
	for sample_index in range(sample_count + 1):
		var progress: float = float(sample_index) / float(sample_count)
		var point: Vector3 = start.lerp(finish, progress)
		# a smooth sideways meander fades out exactly at both node centers.
		point.x += sin(PI * progress) * (bend + ripple * sin(TAU * progress))
		# replace the temporary flat height with the actual surface plus a small clearance
		point.y = _ground_height(point.x, point.z) + 0.045
		points.append(point)
	connection_paths.append(points)

	# a flat ribbon follows the curve without seams between separate box meshes.
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var distance_along: float = 0.0
	for sample_index in range(points.size()):
		# accumulate real curve length so dots keep their spacing on different routes
		if sample_index > 0:
			distance_along += points[sample_index - 1].distance_to(points[sample_index])
		var before: Vector3 = points[maxi(sample_index - 1, 0)]
		var after: Vector3 = points[mini(sample_index + 1, points.size() - 1)]
		var tangent: Vector3 = (after - before).normalized()
		# offset on either side of the curve tangent to give the ribbon its width
		var side: Vector3 = Vector3(-tangent.z, 0.0, tangent.x).normalized() * 0.1
		mesh.surface_set_normal(Vector3.UP)
		var right: Vector3 = points[sample_index] + side
		# sample each ribbon edge separately so both sides stay above cross slopes
		right.y = _ground_height(right.x, right.z) + 0.045
		# width coordinates and distance coordinates let the shader cut round dots
		mesh.surface_set_uv(Vector2(1.0, distance_along))
		mesh.surface_add_vertex(right)
		mesh.surface_set_normal(Vector3.UP)
		var left: Vector3 = points[sample_index] - side
		left.y = _ground_height(left.x, left.z) + 0.045
		mesh.surface_set_uv(Vector2(0.0, distance_along))
		mesh.surface_add_vertex(left)
	mesh.surface_end()
	var line: MeshInstance3D = MeshInstance3D.new()
	line.mesh = mesh
	line.material_override = _line_material
	_path_visuals.add_child(line)


# adds seven border pillars on each side with bases seated on the terrain
func generate_pillars() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.45, 0.48)
	material.roughness = 1.0
	for i in range(7):
		var progress: float = float(i) / 6.0
		var pillar_z: float = lerpf(start_z, end_z, progress)
		for side in [-1, 1]:
			var pillar: MeshInstance3D = MeshInstance3D.new()
			var shape: BoxMesh = BoxMesh.new()
			shape.size = Vector3(0.7, 2.5, 0.7)
			pillar.mesh = shape
			pillar.material_override = material
			add_child(pillar)
			pillar.position = Vector3(side * 5.0, _ground_height(side * 5.0, pillar_z) + 1.25, pillar_z)


# converts a path-local position into terrain space and returns its local surface height
func _ground_height(x: float, z: float) -> float:
	# account for parent transforms rather than assuming both nodes share local coordinates
	var surface_point: Vector3 = _terrain.to_local(to_global(Vector3(x, 0.0, z)))
	surface_point.y = _terrain.get_height_at(surface_point.x, surface_point.z)
	return to_local(_terrain.to_global(surface_point)).y


# finds a safe upright token height by sampling the center and perimeter of its footprint
func _token_base_height(x: float, z: float) -> float:
	# tokens stay upright; sample their footprint so a rising slope cannot cut
	# through a token edge. the small clearance also prevents depth flicker.
	var radius: float = clampf(token_diameter, 0.5, 1.5) * 0.5
	var highest: float = _ground_height(x, z)
	for index in range(12):
		var angle: float = TAU * float(index) / 12.0
		highest = maxf(highest, _ground_height(x + cos(angle) * radius, z + sin(angle) * radius))
	# leave a small gap above the highest sampled point to avoid surface flicker
	return highest + 0.025
