class_name RhythmJudgment
extends RefCounted

var note_id: int
var lane: int
var target_beat: int
var song_time_sec: float
var tier: Judge.Judgement
var phase: Judge.Phase
var accuracy_sec: float
var time_error_sec: float
var has_input_timing: bool
