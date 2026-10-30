@tool
extends MeshInstance3D

const TERRAIN_SHADER: Shader = preload("res://assets/map_scene/volcanic_ground.gdshader")
const CELL_SIZE: float = 0.5
const HALF_WIDTH: float = 6.0
const HALF_DEPTH: float = 20.0

@export_range(0.0, 0.8, 0.05) var height_variation: float = 0.45:
	set(value):
		height_variation = value
		# rebuild on inspector edits only after the node has entered the scene tree
		if is_inside_tree():
			_build_terrain()


# builds the ground when the scene opens in the editor or starts at runtime
func _ready() -> void:
	_build_terrain()


# keeps generated preview resources visible but excludes them from saved scenes
func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh" or property.name == "material_override":
		# the terrain rebuilds these resources on load, so storing them duplicates data
		property.usage = int(property.usage) & ~PROPERTY_USAGE_STORAGE


# shared by the actual mesh, tokens and paths; no shader-only displacement.
# interpolate the same triangle split used by _build_terrain.
# returns the rendered surface height by interpolating the correct grid triangle
func get_height_at(x: float, z: float) -> float:
	# keep boundary samples inside the final valid grid cell
	var cell_x: float = clampf(x, -HALF_WIDTH, HALF_WIDTH - 0.0001)
	var cell_z: float = clampf(z, -HALF_DEPTH, HALF_DEPTH - 0.0001)
	# locate the lower grid corner and measure fractional position within the cell
	var x0: float = floorf((cell_x + HALF_WIDTH) / CELL_SIZE) * CELL_SIZE - HALF_WIDTH
	var z0: float = floorf((cell_z + HALF_DEPTH) / CELL_SIZE) * CELL_SIZE - HALF_DEPTH
	var u: float = (cell_x - x0) / CELL_SIZE
	var v: float = (cell_z - z0) / CELL_SIZE
	var a: float = _vertex_height(x0, z0)
	var b: float = _vertex_height(x0 + CELL_SIZE, z0)
	var c: float = _vertex_height(x0, z0 + CELL_SIZE)
	var d: float = _vertex_height(x0 + CELL_SIZE, z0 + CELL_SIZE)

	# the diagonal separates the first triangle from the second triangle in this cell
	if u + v <= 1.0:
		return a + (b - a) * u + (c - a) * v
	return d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)


# combines broad and small waves into deterministic gentle hills
func _vertex_height(x: float, z: float) -> float:
	# different wavelengths break up regular ridges while keeping the total amplitude bounded
	var hills: float = sin(z * 0.29 + x * 0.35) * 0.55
	hills += cos(x * 0.8 - z * 0.16) * 0.3
	hills += sin(x * 1.7 + z * 0.93) * 0.15
	return 0.15 + hills * height_variation


# rebuilds the triangulated ground slab, closes its sides and applies the volcanic material
func _build_terrain() -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z_index in range(80):
		for x_index in range(24):
			var x: float = -HALF_WIDTH + float(x_index) * CELL_SIZE
			var z: float = -HALF_DEPTH + float(z_index) * CELL_SIZE
			var a: Vector3 = Vector3(x, _vertex_height(x, z), z)
			var b: Vector3 = Vector3(x + CELL_SIZE, _vertex_height(x + CELL_SIZE, z), z)
			var c: Vector3 = Vector3(x, _vertex_height(x, z + CELL_SIZE), z + CELL_SIZE)
			var d: Vector3 = Vector3(x + CELL_SIZE, _vertex_height(x + CELL_SIZE, z + CELL_SIZE), z + CELL_SIZE)
			# emit the same two triangle splits used by the height sampler
			for point: Vector3 in [a, b, c, b, d, c]:
				surface.add_vertex(point)
	# close the slab edges so the small hills never expose a paper-thin board.
	for edge_index in range(4):
		var edge_start: Vector2 = [Vector2(-6, -20), Vector2(6, -20), Vector2(6, 20), Vector2(-6, 20)][edge_index]
		var edge_end: Vector2 = [Vector2(6, -20), Vector2(6, 20), Vector2(-6, 20), Vector2(-6, -20)][edge_index]
		# match side segments to the top grid so the slab boundary stays closed
		var steps: int = roundi(edge_start.distance_to(edge_end) / CELL_SIZE)
		for step in range(steps):
			var first: Vector2 = edge_start.lerp(edge_end, float(step) / float(steps))
			var last: Vector2 = edge_start.lerp(edge_end, float(step + 1) / float(steps))
			var a: Vector3 = Vector3(first.x, _vertex_height(first.x, first.y), first.y)
			var b: Vector3 = Vector3(last.x, _vertex_height(last.x, last.y), last.y)
			var c: Vector3 = Vector3(first.x, -0.9, first.y)
			var d: Vector3 = Vector3(last.x, -0.9, last.y)
			for point: Vector3 in [a, c, b, b, c, d]:
				surface.add_vertex(point)
	# derive lighting normals from the generated geometry before committing the mesh
	surface.generate_normals()
	mesh = surface.commit()
	var ground_material: ShaderMaterial = ShaderMaterial.new()
	ground_material.shader = TERRAIN_SHADER
	material_override = ground_material
