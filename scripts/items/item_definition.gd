class_name ItemDefinition
extends Resource

enum Instrument { ALL, GUITAR, BASS, KEYS, DRUMS, MELODIC }
enum Effect { DAMAGE, PERFECT_WINDOW, RESISTANCE, CRIT_CHANCE, LOW_HEALTH_DAMAGE, ECHO }

@export var instrument: Instrument = Instrument.ALL
@export var effect: Effect = Effect.DAMAGE
@export var amount: float = 0.0

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
