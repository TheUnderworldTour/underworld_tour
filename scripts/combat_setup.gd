extends Node

const RHYTHM_SCENE := "res://scenes/rhythm_core.tscn"

# Active player positioning
const ACTIVE_POS := Vector2(192.0,461.0)

# Benched player positioning
const BENCH_X := 1013.0
const BENCH_START_Y := 488.0
const BENCH_SPACING_Y := 150.0
const BENCH_SCALE := Vector2(0.72,0.72)

# Enemy positiioning
const ENEMY_Y := 233.0
const ENEMY_CENTER_X := 571.0
const ENEMY_SPACING := 150.0
const ENEMY_SCALE := Vector2(0.2,0.2)

var characters: Array[String] = ["guitarist", "bassist", "pianist", "drummer"]
var enemy_pool: Array[String] = ["skeleton1"]

var active_player := "guitarist"
var active_enemies: Array[String] = []

var _spawned_enemies: Array[EnemyPortrait] = []

func set_active_player(player:String)-> void:
	if player not in characters:
		push_warning("Unknown Player: "+ player)
		return
	active_player = player
	var scene := _get_rhythm_scene()
	if scene:
		_apply_player_layout(scene)
		
func set_enemies(enemies: Array[String])-> void:
	active_enemies = enemies
	var scene := _get_rhythm_scene()
	if scene:
		_apply_enemies(scene)
		
func init_combat() -> Error:
	var tree := get_tree()
	var old := tree.current_scene
	var err := tree.change_scene_to_file(RHYTHM_SCENE)
	if err != OK:
		return err
	
	while tree.current_scene == old or tree.current_scene == null:
		await tree.process_frame
	
	var scene := _get_rhythm_scene()
	if scene == null:
		return ERR_CANT_CREATE
	_apply_player_layout(scene)
	_apply_enemies(scene)
	return OK	
	
func _get_rhythm_scene() -> RhythmCore:
	var s:= get_tree().current_scene
	if s and s.scene_file_path == RHYTHM_SCENE:
		return s as RhythmCore
	return null
	
func _apply_player_layout(scene:RhythmCore) -> void:
	# keep track of the stack (of benched characters)
	var bench_index := 0
	# iterate through all valid characters
	for c in characters:
		# fetch their portrait
		var p:= scene.get_node_or_null(c.capitalize() + "Portrait") as CharacterPortrait
		if p == null:
			push_warning("Missing portrait node for " + c)
			continue

		if c == active_player: # if they are to be active
			p.position = ACTIVE_POS
			p.scale = Vector2(1.0,1.0)
			scene.character_portrait = p
			p.z_index = 0
			#bench_index += 1
		else: # if they are to be benched
			p.position = Vector2(BENCH_X, BENCH_START_Y + bench_index * BENCH_SPACING_Y)
			p.scale = BENCH_SCALE
			p.z_index = 0
			bench_index += 1
			
func _apply_enemies(scene: RhythmCore)-> void:
	for e in _spawned_enemies:
		if is_instance_valid(e):
			e.queue_free()
	_spawned_enemies.clear()
	
	var count := active_enemies.size()
	for i in count:
		var enemy := _make_enemy(active_enemies[i])
		
		var offset := (i - (count -1)/2.0) * ENEMY_SPACING
		enemy.position = Vector2(ENEMY_CENTER_X + offset, ENEMY_Y)
		enemy.scale = ENEMY_SCALE
		scene.add_child(enemy)
		_spawned_enemies.append(enemy)
		
func _make_enemy(enemy_name: String) -> EnemyPortrait:
	var enemy := EnemyPortrait.new()
	enemy.name = enemy_name
	
	var sprite := Sprite2D.new()
	sprite.name = "Portrait"
	enemy.add_child(sprite)
	
	enemy.character_name = enemy_name
	return enemy
