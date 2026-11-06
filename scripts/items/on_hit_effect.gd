extends Resource

enum Kind { DAMAGE_OVER_TIME, ECHO_STRIKES, STATUS }

@export var kind: Kind = Kind.DAMAGE_OVER_TIME
@export_range(0.0, 100.0) var chance_percent: float = 100.0
@export var triggers_on_echo: bool = false
@export var damage: float = 1.0
@export_range(0.01, 60.0) var interval_seconds: float = 0.25
@export_range(1, 30) var strike_count: int = 3
@export_range(0.01, 120.0) var duration_seconds: float = 3.0
@export var status_id: StringName
