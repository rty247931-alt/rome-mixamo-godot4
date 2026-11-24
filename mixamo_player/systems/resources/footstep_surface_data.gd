extends Resource
class_name MixamoFootstepSurfaceData


@export_category("Surface")
@export var surface_id: StringName = &"default"

@export_category("Sounds")
@export var sounds: Array[AudioStream] = []

@export_category("Audio Settings")
@export_range(-30.0, 6.0, 0.5) var volume_db: float = 0.0
@export_range(0.5, 1.5, 0.01) var min_pitch: float = 0.95
@export_range(0.5, 1.5, 0.01) var max_pitch: float = 1.05
