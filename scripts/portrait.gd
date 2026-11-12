class_name CharacterPortrait
extends Node2D

@onready var portrait: Node2D = $Portrait

func _get_portrait_root()-> String: # a function so sub classes can override
	return "res://assets/character_portraits/"

@export var character_name: String = "guitarist":
	set(value):
		character_name = value
		if is_node_ready():
			_reload()
# Derived, functions with updates
var portrait_folder: String:
	get:
		return _get_portrait_root() + character_name + "/"

# Portrait lists to pick from
var idle_portraits: Array[Texture2D] = []
var good_portraits: Array[Texture2D] = []
var bad_portraits: Array[Texture2D] = []

# Current state trackers
var current_texture: Texture2D
var state_version:=0

# animation vars
var bpm:=240
var state_timer = ( 60.0/bpm ) * 0.25
# Idle tracker
var idle_timer:= 0.0
var idle_frame:=1
# Hold note tracker
@export var hold_frame_time = 0.0
var holding := false
var hold_timer := 0.0
var hold_frame := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	_load_portraits()
	if idle_portraits.size() > 0:
		_show(idle_portraits[0])

# Load portraits from file path
func _load_portraits() -> void:
	idle_portraits.clear()
	good_portraits.clear()
	bad_portraits.clear()
	
	var dir := DirAccess.open(portrait_folder)
	if dir == null:
		push_error("Can't open portraits folder: " + portrait_folder)
		return
	
	var files: Array[String] = []
	for f in dir.get_files():
		var clean := f.trim_suffix(".import").trim_suffix(".remap")
		if clean.get_extension() in ["png", "webp", "jpg"] and not files.has(clean):
			files.append(clean)
	files.sort()
	
	for f in files:
		var texture:= load(portrait_folder.path_join(f)) as Texture2D
		if texture == null:
			continue
		var base := f.get_basename()
		if "_idle_" in base:
			idle_portraits.append(texture)
		elif "_play_" in base:
			good_portraits.append(texture)
		elif "_bad_" in base:
			bad_portraits.append(texture)

# Reload portrait to update changes
func _reload()-> void:
	holding = false
	state_version += 1
	idle_timer = 0.0
	idle_frame = 0
	_load_portraits()
	if idle_portraits.size() > 0:
		_show(idle_portraits[0])

# Updates internal BPM
func set_bpm(new_bpm: int)-> void:
	bpm = new_bpm
	state_timer = ( 60.0/bpm ) * 0.25

# Update displaying texture
func _show(texture: Texture2D) -> void:
	current_texture = texture
	portrait.texture = current_texture

# Check if this is an idle texture
func _is_idle(texture: Texture2D) -> bool:
	return texture in idle_portraits

# Updates current image texture
func set_state(texture: Texture2D, duration: float = 0.5) -> void:
	if texture == null or holding: # invalid texture or in hold state
		return
	
	state_version+=1
	var current_version := state_version
	_show(texture) # display texture
	
	if _is_idle(texture): # reset idle timer and begin idle animation
		idle_timer = 0.0
		idle_frame = idle_portraits.find(texture)
		return
	
	var actual_duration = duration if duration != 0.25 else state_timer
	await get_tree().create_timer(actual_duration).timeout # set timer
	
	if current_version == state_version and idle_portraits.size() > 0: # return to idle animation
		_show(idle_portraits[0])

# grab a random image from the passed pool
func _pick_random(pool: Array[Texture2D]) -> Texture2D:
	if pool.is_empty():
		return null
	if pool.size()==1:
		return pool[0]
	
	var pick := pool[randi() % pool.size()]
	while pick == current_texture:
		pick = pool[randi() % pool.size()]
	
	return pick

# Play a random good emote
func play_good() -> void:
	set_state(_pick_random(good_portraits))

# Play a random bad emote
func play_bad() -> void:
	var texture := _pick_random(bad_portraits)
	if texture == null:
		return
	if holding: # if bad note played during hold
		_show(texture)
		hold_timer = 0.0
		return
	set_state(texture)

# begin looped playing during a hold note
func start_hold()->void:
	if holding or good_portraits.is_empty():
		return
	holding = true
	state_version += 1
	hold_timer = 0.0
	hold_frame = randi() % good_portraits.size()
	_show(good_portraits[hold_frame])

# stop looped playing
func stop_hold() -> void:
	if not holding:
		return
		
	holding = false
	state_version += 1
	idle_timer = 0.0
	idle_frame = 0
	if idle_portraits.size() > 0:
		_show(idle_portraits[0])
	
# on/off for playing a hold note
func set_holding(value: bool)-> void:
	if value:
		start_hold()
	else:
		stop_hold()

# update the frames for hold notes
func _update_hold(delta: float)->void:
	if good_portraits.size() < 2: # only 1 portrait to bounce between
		return
	hold_timer += delta
	var interval = hold_frame_time if hold_frame_time > 0.0 else state_timer *4
	if hold_timer >= interval:
		hold_timer -= interval
		hold_frame = (hold_frame + 1) % good_portraits.size()
		_show(good_portraits[hold_frame])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if holding:
		_update_hold(delta)
		return
	
	if idle_portraits.size() < 2:
		return
	
	idle_timer +=delta
	var beat_interval = state_timer * 4
	
	if idle_timer >= beat_interval:
		idle_timer -= beat_interval
		if _is_idle(current_texture):
			idle_frame = (idle_frame + 1) % idle_portraits.size()
			set_state(idle_portraits[idle_frame])
