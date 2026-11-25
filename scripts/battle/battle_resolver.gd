class_name BattleResolver
extends RefCounted

const BASE_DAMAGE: Dictionary[Judge.Judgement, float] = {
	Judge.Judgement.HELLISH: 12.0,
	Judge.Judgement.PERFECT: 10.0,
	Judge.Judgement.GREAT: 7.0,
	Judge.Judgement.GOOD: 5.0,
}
const ECHO_DELAY: float = 0.3

var random: RandomNumberGenerator = RandomNumberGenerator.new()


func resolve_judgment(
	event: RhythmJudgment, state: BattleState, miss_penalty: RhythmPenalty
) -> void:
	if state.outcome != BattleState.Outcome.ACTIVE or event.phase == Judge.Phase.HOLD_START:
		return
	if event.tier == Judge.Judgement.MISS:
		resolve_rhythm_penalty(miss_penalty, state)
		return
	var bonus: float = state.get_modifier(ItemDefinition.Effect.DAMAGE, event.instrument)
	var missing_health: float = 1.0 - state.player_health / state.player_max_health
	bonus += missing_health * state.get_modifier(
		ItemDefinition.Effect.LOW_HEALTH_DAMAGE, event.instrument
	)
	var damage: float = BASE_DAMAGE[event.tier] * (1.0 + bonus)
	var chance: float = clampf(
		state.get_modifier(ItemDefinition.Effect.CRIT_CHANCE, event.instrument), 0.0, 1.0
	)
	if chance > 0.0 and random.randf() < chance:
		damage *= 2.0
	_apply_enemy_damage(damage, state)
	var echo: float = state.get_modifier(ItemDefinition.Effect.ECHO, event.instrument)
	if echo > 0.0 and state.outcome == BattleState.Outcome.ACTIVE:
		state.pending_echoes.append(Vector2(ECHO_DELAY, damage * echo))


func advance_effects(delta: float, state: BattleState) -> void:
	if state.outcome != BattleState.Outcome.ACTIVE:
		state.pending_echoes.clear()
		return
	for index: int in range(state.pending_echoes.size() - 1, -1, -1):
		state.pending_echoes[index].x -= delta
		if state.pending_echoes[index].x <= 0.0:
			var damage: float = state.pending_echoes[index].y
			state.pending_echoes.remove_at(index)
			_apply_enemy_damage(damage, state)
			if state.outcome != BattleState.Outcome.ACTIVE:
				return


func resolve_rhythm_penalty(penalty: RhythmPenalty, state: BattleState) -> void:
	if penalty == null or state.outcome != BattleState.Outcome.ACTIVE:
		return
	var resistance: float = clampf(
		state.get_modifier(ItemDefinition.Effect.RESISTANCE, ItemDefinition.Instrument.ALL),
		0.0, 0.75
	)
	state.player_health = maxf(
		0.0, state.player_health - maxf(0.0, penalty.damage) * (1.0 - resistance)
	)
	if state.player_health == 0.0:
		state.outcome = BattleState.Outcome.DEFEAT
	else:
		state.add_player_status(penalty.status_id)


func finish_chart(state: BattleState) -> void:
	if state.outcome == BattleState.Outcome.ACTIVE and state.pending_echoes.is_empty():
		state.outcome = BattleState.Outcome.DEFEAT


func _apply_enemy_damage(amount: float, state: BattleState) -> void:
	if state.outcome != BattleState.Outcome.ACTIVE:
		return
	state.boss_health = maxf(0.0, state.boss_health - amount)
	if state.boss_health == 0.0:
		state.outcome = BattleState.Outcome.VICTORY
		state.pending_echoes.clear()
