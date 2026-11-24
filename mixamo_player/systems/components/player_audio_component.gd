extends Node


# =========================================================
# JUMP
# =========================================================

@export_category("Jump")

@export var jump_sounds: Array[AudioStream] = []


# =========================================================
# LANDING
# =========================================================

@export_category("Landing")

@export var landing_sounds: Array[AudioStream] = []


# =========================================================
# FOOTSTEPS
# =========================================================

@export_category("Footsteps")

@export var default_footstep_sounds: Array[AudioStream] = []

@export var footstep_surfaces: Array[MixamoFootstepSurfaceData] = []


# =========================================================
# WATER
# =========================================================

@export_category("Water")

@export var dive_sound: AudioStream

@export var surface_sound: AudioStream

@export var underwater_loop_sound: AudioStream


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	_apply_audio_settings()


# =========================================================
# DISTRIBUTION
# =========================================================

func _apply_audio_settings() -> void:
	var player: Node = owner

	if player == null:
		push_error(
			"PlayerAudioComponent: Player owner not found."
		)
		return

	var movement_component: Node = player.get_node_or_null(
		"MovementComponent"
	)

	var fall_component: Node = player.get_node_or_null(
		"FallComponent"
	)

	var footstep_component: Node = player.get_node_or_null(
		"FootstepComponent"
	)

	var swimming_component: Node = player.get_node_or_null(
		"SwimmingComponent"
	)

	_apply_jump_audio(
		movement_component
	)

	_apply_landing_audio(
		fall_component
	)

	_apply_footstep_audio(
		footstep_component
	)

	_apply_water_audio(
		swimming_component
	)


# =========================================================
# JUMP
# =========================================================

func _apply_jump_audio(
	movement_component: Node
) -> void:
	if movement_component == null:
		return

	movement_component.set(
		"jump_sounds",
		jump_sounds
	)


# =========================================================
# LANDING
# =========================================================

func _apply_landing_audio(
	fall_component: Node
) -> void:
	if fall_component == null:
		return

	fall_component.set(
		"landing_sounds",
		landing_sounds
	)


# =========================================================
# FOOTSTEPS
# =========================================================

func _apply_footstep_audio(
	footstep_component: Node
) -> void:
	if footstep_component == null:
		return

	var current_default: MixamoFootstepSurfaceData = (
		footstep_component.get(
			"default_surface"
		) as MixamoFootstepSurfaceData
	)

	var runtime_default: MixamoFootstepSurfaceData

	if current_default != null:
		runtime_default = (
			current_default.duplicate(true)
			as MixamoFootstepSurfaceData
		)

	else:
		runtime_default = MixamoFootstepSurfaceData.new()
		runtime_default.surface_id = &"default"

	runtime_default.sounds = (
		default_footstep_sounds
	)

	footstep_component.set(
		"default_surface",
		runtime_default
	)

	if not footstep_surfaces.is_empty():
		footstep_component.set("surfaces", footstep_surfaces)


# =========================================================
# WATER
# =========================================================

func _apply_water_audio(
	swimming_component: Node
) -> void:
	if swimming_component == null:
		return

	swimming_component.set(
		"enter_water_sound",
		dive_sound
	)

	swimming_component.set(
		"exit_water_sound",
		surface_sound
	)

	swimming_component.set(
		"underwater_loop_sound",
		underwater_loop_sound
	)
