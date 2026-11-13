class_name BattleResolver
extends RefCounted

const BASE_DAMAGE: Dictionary[Judge.Judgement, float] = {
	Judge.Judgement.PERFECT: 10.0,
	Judge.Judgement.GREAT: 7.0,
	Judge.Judgement.GOOD: 5.0,
}
const DAMAGE_BOOST_PER_COPY: float = 0.25


func resolve_judgment(
	event: RhythmJudgment, state: BattleState, miss_penalty: RhythmPenalty
) -> void:
	if event.tier == Judge.Judgement.MISS:
		resolve_rhythm_penalty(miss_penalty, state)
		return
	if state.outcome != BattleState.Outcome.ACTIVE or event.phase == Judge.Phase.HOLD_START:
		return
	var multiplier: float = 1.0 + state.get_item_quantity(&"damage_boost") * DAMAGE_BOOST_PER_COPY
	state.boss_health = maxf(0.0, state.boss_health - BASE_DAMAGE[event.tier] * multiplier)
	if state.boss_health == 0.0:
		state.outcome = BattleState.Outcome.VICTORY


func resolve_rhythm_penalty(penalty: RhythmPenalty, state: BattleState) -> void:
	if penalty == null or state.outcome != BattleState.Outcome.ACTIVE:
		return
	state.player_health = maxf(0.0, state.player_health - maxf(0.0, penalty.damage))
	if state.player_health == 0.0:
		state.outcome = BattleState.Outcome.DEFEAT
	else:
		state.add_player_status(penalty.status_id)


func finish_chart(state: BattleState) -> void:
	if state.outcome == BattleState.Outcome.ACTIVE:
		state.outcome = BattleState.Outcome.DEFEAT
