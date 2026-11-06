extends Node

signal damage_generated(amount: float)
signal hit_resolved(amount: float, critical: bool, echo: bool)
signal status_applied(status_id: StringName, duration_seconds: float)

const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const OnHitEffect = preload("res://scripts/items/on_hit_effect.gd")

var _random: RandomNumberGenerator = RandomNumberGenerator.new()


# rolls crits for primary rhythm hits after applying the inventory's damage bonus
func resolve_hit(base_damage: float, base_crit_chance: float, base_crit_multiplier: float) -> void:
	var damage: float = ItemInventory.get_modified_stat(ItemDefinition.Stat.DAMAGE, base_damage)
	var chance: float = ItemInventory.get_modified_stat(ItemDefinition.Stat.CRIT_CHANCE, base_crit_chance)
	var critical: bool = _roll_chance(chance)
	if critical:
		var multiplier: float = ItemInventory.get_modified_stat(
			ItemDefinition.Stat.CRIT_MULTIPLIER, base_crit_multiplier
		)
		damage *= maxf(1.0, multiplier)
	_emit_hit(maxf(0.0, damage), critical, false)


# reports real strikes and resolves the effects owned when the strike lands
func _emit_hit(amount: float, critical: bool, echo: bool) -> void:
	damage_generated.emit(amount)
	hit_resolved.emit(amount, critical, echo)
	for item: ItemDefinition in ItemInventory.get_items():
		for effect: OnHitEffect in item.on_hit_effects:
			if effect == null:
				continue
			# echoes can carry secondary effects but can never schedule another echo
			if echo and (not effect.triggers_on_echo or effect.kind == OnHitEffect.Kind.ECHO_STRIKES):
				continue
			for copy in range(ItemInventory.get_quantity(item.id)):
				if _roll_chance(effect.chance_percent):
					_apply_effect(effect)


# dispatches status requests and captures timed effect settings when they proc
func _apply_effect(effect: OnHitEffect) -> void:
	match effect.kind:
		OnHitEffect.Kind.STATUS:
			if effect.status_id != &"" and effect.duration_seconds > 0.0:
				status_applied.emit(effect.status_id, effect.duration_seconds)
		OnHitEffect.Kind.DAMAGE_OVER_TIME:
			var interval: float = maxf(0.01, effect.interval_seconds)
			var ticks: int = floori(effect.duration_seconds / interval + 0.000001)
			_schedule_damage(effect.damage, interval, ticks, false)
		OnHitEffect.Kind.ECHO_STRIKES:
			_schedule_damage(effect.damage, maxf(0.01, effect.interval_seconds), effect.strike_count, true)


# schedules fixed damage within the battle and respects scene-tree pauses
func _schedule_damage(amount: float, interval: float, count: int, echo: bool) -> void:
	if amount <= 0.0:
		return
	for strike in range(count):
		await get_tree().create_timer(interval, false).timeout
		if not is_inside_tree():
			return
		if echo:
			_emit_hit(amount, false, true)
		else:
			# periodic damage is not a strike and cannot trigger on-hit effects
			damage_generated.emit(amount)


# treats zero and guaranteed chances exactly, including after stat modifiers
func _roll_chance(percent: float) -> bool:
	return percent >= 100.0 or (percent > 0.0 and _random.randf() * 100.0 < percent)
