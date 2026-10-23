extends Node3D

@export var node_count: int = 9
@export var start_z: float = 14.0
@export var end_z: float = -18.0
@export var path_width: float = 3.0

var cube_material: StandardMaterial3D
var line_material: StandardMaterial3D


func _ready() -> void:
	cube_material = StandardMaterial3D.new()
	cube_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	cube_material.albedo_color = Color(0.362, 0.373, 0.376, 1.0)

	line_material = StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

	generate_path()
	generate_pillars()


func generate_path() -> void:
	var previous_point := Vector3.ZERO
	var count := maxi(node_count, 2)

	for i in range(count):
		# progress goes from 0 at the start to 1 at the end
		var progress := float(i) / float(count - 1)

		var point := Vector3(
			randf_range(-path_width, path_width),
			0.4,
			lerpf(start_z, end_z, progress)
		)

		# keep the first and last cubes centered
		if i == 0 or i == count - 1:
			point.x = 0.0

		add_cube(point)

		if i > 0:
			add_connection(previous_point, point)

		previous_point = point


func add_cube(point: Vector3) -> void:
	var cube := MeshInstance3D.new()
	var shape := BoxMesh.new()

	shape.size = Vector3(0.6, 0.6, 0.6)
	cube.mesh = shape
	cube.material_override = cube_material

	add_child(cube)
	cube.position = point


func add_connection(from_point: Vector3, to_point: Vector3) -> void:
	# Put the connecting bar just above the board.
	var start := Vector3(from_point.x, 0.15, from_point.z)
	var finish := Vector3(to_point.x, 0.15, to_point.z)

	var line := MeshInstance3D.new()
	var shape := BoxMesh.new()

	shape.size = Vector3(0.1, 0.06, start.distance_to(finish))
	line.mesh = shape
	line.material_override = line_material

	add_child(line)
	line.position = (start + finish) / 2.0
	line.look_at(to_global(finish), Vector3.UP)

func generate_pillars() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.45, 0.48)
	material.roughness = 1.0

	# seven pillars along each side of the map
	for i in range(7):
		var progress := float(i) / 6.0
		var pillar_z := lerpf(start_z, end_z, progress)

		for side in [-1, 1]:
			var pillar := MeshInstance3D.new()
			var shape := BoxMesh.new()

			shape.size = Vector3(0.7, 2.5, 0.7)
			pillar.mesh = shape
			pillar.material_override = material

			add_child(pillar)

			# board edges are at X = -6 and X = 6
			# Y places the bottom of each pillar on the board
			pillar.position = Vector3(
				side * 5.0,
				1.35,
				pillar_z
			)
