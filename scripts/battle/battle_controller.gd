extends Node2D

const ENCOUNTER_ID: StringName = &"demo_boss"
const PLAYER_HEALTH: float = 100.0
const BOSS_HEALTH: float = 55.0
const BOSS_ATTACK_DAMAGE: float = 35.0
const BOSS_ATTACK_BEATS: Array[int] = [3, 7, 11]

@export_group("Boss Rhythm Penalties")
@export var missed_note_penalty: RhythmPenalty
@export var extra_note_penalty: RhythmPenalty

@onready var _rhythm_core: RhythmCore = $RhythmCore
@onready var _player_health_label: Label = $BattleHud/Readout/PlayerHealth
@onready var _boss_health_label: Label = $BattleHud/Readout/BossHealth
@onready var _result_label: Label = $BattleHud/Readout/Result
@onready var _retry_button: Button = $BattleHud/Readout/RetryButton

var _state: BattleState
var _resolver: BattleResolver = BattleResolver.new()
var _next_boss_attack: int = 0


func _ready() -> void:
	_state = BattleState.new(PLAYER_HEALTH, BOSS_HEALTH, GameState.get_battle_loadout())
	_rhythm_core.note_judged.connect(_on_rhythm_core_note_judged)
	_rhythm_core.extra_note_played.connect(_on_rhythm_core_extra_note_played)
	_rhythm_core.song_beat_reached.connect(_on_rhythm_core_song_beat_reached)
	_rhythm_core.chart_completed.connect(_on_rhythm_core_chart_completed)
	_retry_button.pressed.connect(_on_retry_button_pressed)
	_refresh_health()


func _on_rhythm_core_note_judged(event: RhythmJudgment) -> void:
	_resolver.resolve_judgment(event, _state, missed_note_penalty)
	_publish_state()


func _on_rhythm_core_extra_note_played(_lane: int, _song_time_sec: float) -> void:
	_resolver.resolve_rhythm_penalty(extra_note_penalty, _state)
	_publish_state()


func _on_rhythm_core_song_beat_reached(beat: int) -> void:
	while (
		_next_boss_attack < BOSS_ATTACK_BEATS.size()
		and BOSS_ATTACK_BEATS[_next_boss_attack] <= beat
	):
		_next_boss_attack += 1
		_resolver.resolve_boss_attack(BOSS_ATTACK_DAMAGE, _state)
	_publish_state()


func _on_rhythm_core_chart_completed() -> void:
	if _state.outcome == BattleState.Outcome.ACTIVE:
		_resolver.finish_chart(_state)
		_publish_state()


func _on_retry_button_pressed() -> void:
	var reload_result: Error = get_tree().reload_current_scene()
	if reload_result != OK:
		push_error("Could not restart the battle: %s" % error_string(reload_result))


func _publish_state() -> void:
	_refresh_health()
	if _state.outcome == BattleState.Outcome.ACTIVE or _retry_button.visible:
		return
	if _state.outcome == BattleState.Outcome.VICTORY:
		GameState.record_victory(ENCOUNTER_ID)
		_result_label.text = "Victory"
	else:
		_result_label.text = "Defeat"
	_retry_button.show()
	_rhythm_core.stop_chart()


func _refresh_health() -> void:
	_player_health_label.text = "Player HP: %.1f / %.0f" % [
		_state.player_health, _state.player_max_health,
	]
	_boss_health_label.text = "Boss HP: %.1f / %.0f" % [
		_state.boss_health, _state.boss_max_health,
	]
