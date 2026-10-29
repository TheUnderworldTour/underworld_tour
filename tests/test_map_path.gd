extends SceneTree

const MapPathScript = preload("res://scripts/map_path.gd")
const MapScene: PackedScene = preload("res://scenes/map_scene.tscn")
var _failures: int = 0


# defers the checks until the scene tree is ready to receive the map scene
func _initialize() -> void:
	call_deferred("_run")


# records a failed condition while allowing the remaining checks to report their results
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


# checks map generation across 320 configurations, then verifies camera scrolling
func _run() -> void:
	var scene: Node3D = MapScene.instantiate()
	root.add_child(scene)
	var path: Node3D = scene.get_node("MapPath")
	var terrain: MeshInstance3D = scene.get_node("MapSurface")
	_check_terrain(terrain)
	var seen_types: Dictionary = {}
	var width_totals: Dictionary = {1: 0, 2: 0, 3: 0}
	# cover short maps, normal maps, longer maps and an out-of-range path cap
	for count in [2, 3, 9, 20]:
		for limit in [1, 2, 3, 7]:
			for seed_value in range(1, 21):
				path.node_count = count
				path.max_active_paths = limit
				path.generation_seed = seed_value
				path.generate_path()
				# track incoming links and counts independently from the generator's own bookkeeping
				var incoming: Dictionary = {}
				var edges_per_row: Dictionary = {}
				var nodes_per_row: Dictionary = {}
				for connection: Vector2i in path.connections:
					var from_node = path.map_nodes[connection.x]
					var to_node = path.map_nodes[connection.y]
					_check(to_node.row == from_node.row + 1, "Edges must advance one row")
					incoming[to_node.id] = true
					edges_per_row[from_node.row] = int(edges_per_row.get(from_node.row, 0)) + 1
				for map_node in path.map_nodes:
					seen_types[map_node.node_type] = true
					nodes_per_row[map_node.row] = int(nodes_per_row.get(map_node.row, 0)) + 1
					_check(map_node.row == 0 or incoming.has(map_node.id), "Every node must be reachable")
					_check(map_node.row == count - 1 or not map_node.next_node_ids.is_empty(), "No dead ends")
					_check(absf(map_node.position.x) <= 3.8, "Nodes must stay inside pillars")
					# verify the actual generated visual rather than checking only the graph data
					var anchor: Node3D = path.get_node("GeneratedPath/MapNode_%d_%s" % [map_node.id, MapPathScript.NodeType.keys()[map_node.node_type]])
					var token: MeshInstance3D = anchor.get_node("Token")
					_check(token.mesh == path._token_meshes[MapPathScript.TOKEN_NAMES[map_node.node_type]], "Wrong token mesh for encounter type")
					var bounds: AABB = token.mesh.get_aabb()
					_check(is_equal_approx(maxf(bounds.size.x, bounds.size.z) * token.scale.x, path.token_diameter), "Token sizing inconsistent")
					_check(is_equal_approx(anchor.position.y + token.position.y + bounds.position.y * token.scale.y, path._token_base_height(anchor.position.x, anchor.position.z)), "Token base must follow terrain")
					_check(token.material_override == null, "Authored token materials must be preserved")
					for other_node in path.map_nodes:
						if other_node.row == map_node.row and other_node.id > map_node.id:
							_check(absf(other_node.position.x - map_node.position.x) >= path.token_diameter + 0.3, "Tokens need horizontal breathing room")
				for row_index in range(count - 1):
					_check(int(edges_per_row.get(row_index, 0)) <= mini(limit, 3), "Active path cap exceeded")
					_check(int(edges_per_row.get(row_index, 0)) > 0, "Disconnected row")
					if limit == 3 and row_index > 0:
						width_totals[nodes_per_row[row_index]] += 1
				_check_path_geometry(path)
				_check(nodes_per_row[0] == 1 and nodes_per_row[count - 1] == 1, "Endpoints must be single nodes")
				_check(path.map_nodes[0].node_type == MapPathScript.NodeType.START, "Missing start type")
				_check(path.map_nodes[-1].node_type == MapPathScript.NodeType.FINISH, "Missing finish type")
				# regenerate with the same seed to catch unstable placement or accumulated visuals
				var signature: String = _signature(path)
				var visual_count: int = path.get_node("GeneratedPath").get_child_count()
				path.generate_path()
				_check(_signature(path) == signature, "Seed must reproduce graph and types")
				_check(path.get_node("GeneratedPath").get_child_count() == visual_count, "Regeneration duplicated visuals")
				_check(path.get_child_count() == 15, "Regeneration duplicated pillars or containers")
				# release queued meshes regularly during the seed sweep.
				await process_frame
	_check(seen_types.size() == MapPathScript.NodeType.size(), "Encounter types were not all generated")
	_check(width_totals[2] > width_totals[3] * 2, "Two-path sections should be substantially more common")
	print("Intermediate row widths with cap 3: ", width_totals)
	var camera: Camera3D = scene.get_node("Camera3D")
	# advance camera motion explicitly so frame timing cannot affect the assertions
	camera.set_process(false)
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for step in range(100):
		camera._unhandled_input(wheel)
	_check(is_equal_approx(camera.target_map_z, camera.map_top), "Upper scroll clamp changed")
	camera._process(100.0)
	_check(is_equal_approx(camera.position.z, camera.map_top + camera.camera_offset_z), "Camera did not slide to target")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for step in range(100):
		camera._unhandled_input(wheel)
	_check(is_equal_approx(camera.target_map_z, camera.map_bottom), "Lower scroll clamp changed")
	print("Map validation: 320 configurations, repeatability, regeneration, types and scrolling; failures: ", _failures)
	scene.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


# captures graph structure, curve samples, positions and types for repeatability checks
func _signature(path: Node3D) -> String:
	var result: String = str(path.connections) + str(path.connection_paths)
	for map_node in path.map_nodes:
		result += "%s:%s;" % [map_node.position, map_node.node_type]
	return result


# checks route attachments, terrain clearance and unwanted crossings within each row gap
func _check_path_geometry(path: Node3D) -> void:
	for edge_index in range(path.connections.size()):
		var edge: Vector2i = path.connections[edge_index]
		var points: PackedVector3Array = path.connection_paths[edge_index]
		_check(Vector2(points[0].x, points[0].z).is_equal_approx(Vector2(path.map_nodes[edge.x].position.x, path.map_nodes[edge.x].position.z)), "Curve start detached")
		_check(Vector2(points[-1].x, points[-1].z).is_equal_approx(Vector2(path.map_nodes[edge.y].position.x, path.map_nodes[edge.y].position.z)), "Curve end detached")
		for point in points:
			_check(is_equal_approx(point.y, path._ground_height(point.x, point.z) + 0.045), "Path must follow terrain")
		for segment_index in range(points.size() - 1):
			var midpoint: Vector3 = points[segment_index].lerp(points[segment_index + 1], 0.5)
			_check(midpoint.y > path._ground_height(midpoint.x, midpoint.z), "Path segment buried in terrain")
		# compare each pair once and ignore links belonging to different row gaps
		for other_index in range(edge_index + 1, path.connections.size()):
			var other_edge: Vector2i = path.connections[other_index]
			if path.map_nodes[edge.x].row != path.map_nodes[other_edge.x].row:
				continue
			var other_points: PackedVector3Array = path.connection_paths[other_index]
			for segment in range(points.size() - 1):
				for other_segment in range(other_points.size() - 1):
					var a: Vector2 = Vector2(points[segment].x, points[segment].z)
					var b: Vector2 = Vector2(points[segment + 1].x, points[segment + 1].z)
					var c: Vector2 = Vector2(other_points[other_segment].x, other_points[other_segment].z)
					var d: Vector2 = Vector2(other_points[other_segment + 1].x, other_points[other_segment + 1].z)
					var hit: Variant = Geometry2D.segment_intersects_segment(a, b, c, d)
					if hit != null:
						# shared graph endpoints are valid intersections; crossings elsewhere are failures
						var at_shared_start: bool = edge.x == other_edge.x and segment == 0 and other_segment == 0
						var at_shared_end: bool = edge.y == other_edge.y and segment == points.size() - 2 and other_segment == other_points.size() - 2
						_check(at_shared_start or at_shared_end, "Curves crossed away from a node")


# compares sampled mesh triangles with height queries and checks the relief bounds
func _check_terrain(terrain: MeshInstance3D) -> void:
	# confirm height queries agree with triangle interiors, not just vertices.
	var faces: PackedVector3Array = terrain.mesh.get_faces()
	var minimum_height: float = 10.0
	var maximum_height: float = -10.0
	for triangle_index in range(0, 3840, 37):
		var offset: int = triangle_index * 3
		# sample triangle interiors to catch interpolation errors that vertex-only checks would miss
		var center: Vector3 = (faces[offset] + faces[offset + 1] + faces[offset + 2]) / 3.0
		_check(absf(terrain.get_height_at(center.x, center.z) - center.y) < 0.0001, "Height query must match rendered triangle")
		minimum_height = minf(minimum_height, center.y)
		maximum_height = maxf(maximum_height, center.y)
	_check(maximum_height - minimum_height > 0.2, "Ground must have real height variation")
	_check(minimum_height >= -0.3 and maximum_height <= 0.6, "Ground relief must stay gentle")
