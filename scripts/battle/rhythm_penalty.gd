class_name RhythmPenalty
extends Resource

@export_range(0.0, 100.0, 0.5, "or_greater") var damage: float = 0.0
# Optional status recorded on the player for the rest of this encounter.
@export var status_id: StringName
