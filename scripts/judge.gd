class_name Judge
extends Node

## Classifies note accuracy into judgement tiers, tracks score, combo,
## and hit tallies, and emits a single [signal judged] event that the
## rest of the game (HUD, effects) consumes.

signal judged(
	judgement: Judgement, accuracy: float, time_error: float, note: Note, phase: Phase
)

enum Judgement { PERFECT, GREAT, GOOD, MISS }
enum Phase { TAP, HOLD_START, HOLD_END }

## Half-width in seconds of each judgement window, ordered tightest first.
const WINDOWS := {
	Judgement.PERFECT: 0.045,
	Judgement.GREAT: 0.09,
	Judgement.GOOD: 0.135,
}

## Half-width in seconds for long-note release timing.
const RELEASE_PERFECT_WINDOW := 0.045
const RELEASE_GOOD_WINDOW := 0.09

const SCORES := {
	Judgement.PERFECT: 300,
	Judgement.GREAT: 200,
	Judgement.GOOD: 100,
	Judgement.MISS: 0,
}

## Accuracy fraction each judgement contributes toward a final grade.
const ACCURACY_WEIGHTS := {
	Judgement.PERFECT: 1.0,
	Judgement.GREAT: 0.7,
	Judgement.GOOD: 0.4,
	Judgement.MISS: 0.0,
}

const TIER_COLORS := {
	Judgement.PERFECT: Color.GOLD,
	Judgement.GREAT: Color.HOT_PINK,
	Judgement.GOOD: Color.GREEN,
	Judgement.MISS: Color.RED,
}

var score := 0
var combo := 0
var max_combo := 0
var tally := {
	Judgement.PERFECT: 0,
	Judgement.GREAT: 0,
	Judgement.GOOD: 0,
	Judgement.MISS: 0,
}
var accuracy_sum := 0.0
var note_count := 0


func judge_note_hit(note: Note, accuracy: float, phase: Phase = Phase.TAP) -> void:
	_judge(_classify(accuracy), accuracy, note.get_time_error(), note, phase)


func judge_note_miss(note: Note) -> void:
	_judge(Judgement.MISS, INF, 0.0, note, Phase.TAP)


func judge_hold_completed(note: Note, release_accuracy: float) -> void:
	# The hold body succeeded; judge the release timing on its own scale.
	var judgement := Judgement.GOOD
	if release_accuracy <= RELEASE_PERFECT_WINDOW:
		judgement = Judgement.PERFECT
	elif release_accuracy > RELEASE_GOOD_WINDOW:
		judgement = Judgement.GOOD
	# Release timing is relative to the tail. The current callback supplies
	# only an absolute error, so signed release timing is unavailable.
	_judge(judgement, release_accuracy, INF, note, Phase.HOLD_END)


func judge_hold_broken(note: Note) -> void:
	_judge(Judgement.MISS, INF, 0.0, note, Phase.HOLD_END)


func get_final_accuracy() -> float:
	if note_count == 0:
		return 0.0
	return accuracy_sum / note_count


func _classify(accuracy: float) -> Judgement:
	for judgement: Judgement in WINDOWS:
		if accuracy <= WINDOWS[judgement]:
			return judgement
	return Judgement.MISS


func _judge(
	judgement: Judgement, accuracy: float, time_error: float, note: Note, phase: Phase
) -> void:
	tally[judgement] += 1
	score += SCORES[judgement]
	accuracy_sum += ACCURACY_WEIGHTS[judgement]
	note_count += 1
	if judgement == Judgement.MISS:
		combo = 0
	else:
		combo += 1
		max_combo = maxi(max_combo, combo)
	judged.emit(judgement, accuracy, time_error, note, phase)
