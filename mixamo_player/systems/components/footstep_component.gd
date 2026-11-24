extends Node


@export_category("Step Timing")
@export var walk_interval: float = 0.48
@export var sprint_interval: float = 0.32
@export var crouch_interval: float = 0.62


@export_category("Ground Grace")
@export var ground_grace_time: float = 0.12


@export_category("Surface Library")
@export var surfaces: Array[MixamoFootstepSurfaceData] = []
@export var default_surface: MixamoFootstepSurfaceData


@onready var player: CharacterBody3D = owner.get_parent() as CharacterBody3D
@onready var ground_check: RayCast3D = owner.get_node("GroundCheck")

@onready var footstep_player: AudioStreamPlayer3D = owner.get_node(
	"Audio/FootstepPlayer"
)


var step_timer: float = 0.0
var air_timer: float = 0.0
var last_sound: AudioStream = null


func update_footsteps(
	delta: float,
	is_crouching: bool
) -> void:
	if player == null:
		return

	var horizontal_speed: float = Vector2(
		player.velocity.x,
		player.velocity.z
	).length()

	# إذا توقف اللاعب، نبدأ دورة خطوات جديدة.
	if horizontal_speed < 0.2:
		step_timer = 0.0
		air_timer = 0.0
		return

	# أثناء ملامسة الأرض نلغي مؤقت الهواء.
	if player.is_on_floor():
		air_timer = 0.0

	else:
		air_timer += delta

		# لا نشغل خطوات أثناء وجود اللاعب بالهواء.
		# لكن لا نصفر Step Timer مباشرة بسبب الدرج.
		if air_timer >= ground_grace_time:
			step_timer = 0.0

		return

	var current_interval: float = walk_interval

	if is_crouching:
		current_interval = crouch_interval

	elif player.input_controller.sprint_held:
		current_interval = sprint_interval

	step_timer += delta

	if step_timer >= current_interval:
		step_timer = 0.0
		_play_footstep()


func _play_footstep() -> void:
	var surface: MixamoFootstepSurfaceData = _get_current_surface()

	if surface == null:
		return

	if surface.sounds.is_empty():
		return

	var sound: AudioStream = _get_random_sound(
		surface.sounds
	)

	if sound == null:
		return

	footstep_player.stream = sound
	footstep_player.volume_db = surface.volume_db

	footstep_player.pitch_scale = randf_range(
		surface.min_pitch,
		surface.max_pitch
	)

	footstep_player.play()

	last_sound = sound


func _get_current_surface() -> MixamoFootstepSurfaceData:
	ground_check.force_raycast_update()

	if not ground_check.is_colliding():
		return default_surface

	var collider: Object = ground_check.get_collider()

	if collider == null:
		return default_surface

	var node: Node = collider as Node

	while node != null:
		for surface: MixamoFootstepSurfaceData in surfaces:
			if surface == null:
				continue

			var group_name: StringName = StringName(
				"footstep_" + String(surface.surface_id)
			)

			if node.is_in_group(group_name):
				return surface

		node = node.get_parent()

	return default_surface


func _get_random_sound(
	sound_list: Array[AudioStream]
) -> AudioStream:
	if sound_list.is_empty():
		return null

	if sound_list.size() == 1:
		return sound_list[0]

	var available_sounds: Array[AudioStream] = []

	for sound: AudioStream in sound_list:
		if sound != null and sound != last_sound:
			available_sounds.append(sound)

	if available_sounds.is_empty():
		return sound_list.pick_random()

	return available_sounds.pick_random()
