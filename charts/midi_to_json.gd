extends  SceneTree

var data: PackedByteArray
var pos := 0
var tempo_map: Array = []
var raw_notes: Array = []
var division := 480

const BEATS_PER_UNIT := 2.0
const CHORD_WINDOW :=0.25
const GRID := 0.5


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("Usage: godot --headless --script convert.gd -- input.mid output.json")
		quit(1)
		return
	
	var in_file := args[0]
	var out_file := args[1]
	
	var in_path := "res://assets/audio/MIDI/" + in_file
	var out_path := "res://charts/" + out_file
	
	print(in_path)
	print(out_path)
	
	data = FileAccess.get_file_as_bytes(in_path)
	if data.is_empty():
		push_error("Could not read " + in_path)
		quit(1)
		return

	parse()
	var out := convert_notes()

	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write " + out_path)
		quit(1)
		return
	f.store_string(JSON.stringify(out))
	f.close()

	print("Wrote %d notes to %s" % [out.size(), out_path])
	quit()


func u8()-> int: # read a byte
	pos +=1
	return data[pos-1]
	
func u16() -> int: # read in 2 bytes
	return (u8() << 8) | u8()
	
func u32() -> int: # read in 3 bytes
	return (u8() << 24) | (u8() << 16) | (u8() << 8) | u8()
	
func vlq() -> int: # variable length quantity
	var v:=0
	while true:
		var b:=u8()
		v = (v << 7) | (b & 0x7F)
		if not (b & 0x80):
			break
	return v
	
func parse() -> void:
	# read out header
	pos = 4
	u32()
	u16()
	var num_tracks := u16() # read the number of tracks
	division = u16()
	if division & 0x8000:
		push_error("SMPTE timing not supported")
		return
	for t in num_tracks: # parse each individual track
		parse_track()
			
func parse_track() -> void:
	pos += 4
	var length := u32()
	var end := pos+length
	var tick := 0
	var status := 0
	var open := {}

	while pos < end:
		tick += vlq()
		
		if data[pos] & 0x80:
			status = u8()
		
		if status == 0xFF:
			var type :=u8()
			var len := vlq()
			
			if type == 0x51:
				tempo_map.append( [tick, ( data[pos] << 16 ) | ( data[pos + 1] << 8 ) | data[pos+2]])
			pos+=len
		elif status == 0xF0 or status == 0xF7: # sytem exclusion message
			pos += vlq()
		else: 
			var kind := status & 0xF0
			var ch := status & 0x0F
			var a := u8()
			var b := 0
			
			if kind != 0xC0 and kind != 0xD0:
				b = u8()
			var key := ch * 128 + a
			
			if kind == 0x90 and b>0:
				open[key] = tick
			elif kind == 0x80 or (kind == 0x90 and b==0):
				if open.has(key):
					raw_notes.append([open[key], tick, a])
					open.erase(key)
	
	pos = end
	
func ticks_to_sec(tick:int)->float:
	var secs := 0.0
	var last_tick := 0
	var tempo := 500_000 # 120 bpm in ms
	for entry in tempo_map:
		if entry[0] >= tick:
			break
		secs = (entry[0] - last_tick) * tempo /1_000_000.0 / division
		last_tick = entry[0]
		tempo = entry[1]
	secs += (tick - last_tick) * tempo / 1_000_000.0 / division
	return secs
	
func pitch_to_lane(pitch: int, lo: int, hi: int) -> int:
	var random_offset := randi()
	return (pitch + random_offset) % 4
		
func convert_notes() -> Array:
	raw_notes.sort_custom(func(a, b): return a[0] < b[0])
	var tpu := division * BEATS_PER_UNIT    # ticks per unit
	var out := []
	var i := 0
	while i < raw_notes.size():
		var first: int = raw_notes[i][0]
		var group := [raw_notes[i]]
		i += 1
		while i < raw_notes.size() and (raw_notes[i][0] - first) / tpu < CHORD_WINDOW:
			group.append(raw_notes[i])
			i += 1

		group.sort_custom(func(a, b): return a[2] < b[2])   # low -> high pitch
		var picks := [group[0]]
		if group.size() > 1:
			picks.push_front(group[-1])                     # highest first, then lowest

		var start := snappedf(first / tpu, GRID)
		var length := maxf(snappedf((group[0][1] - group[0][0]) / tpu, GRID), GRID)
		var used := {}
		for p in picks:
			var lane: int = p[2] % 4        # placeholder rule: edit by hand afterwards
			while used.has(lane):
				lane = (lane + 1) % 4
			used[lane] = true
			out.append([start, lane, length])
	return out
