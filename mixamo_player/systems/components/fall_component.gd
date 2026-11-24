extends Node


signal landed(impact_speed: float)
signal fall_damage_requested(damage: float)


@export_category("Landing")
@export var minimum_landing_speed: float = 3.0

@export_category("Landing Camera Effect")
@export var landing_camera_effect_enabled: bool = true
@export var landing_kick_strength: float = 0.6
@export var maximum_camera_kick: float = 4.0
@export var camera_return_speed: float = 10.0

@export_category("Landing Audio")
@export var landing_sounds: Array[AudioStream] = []
@export_range(-30.0, 6.0, 0.5) var landing_volume_db: float = 0.0
@export_range(0.5, 1.5, 0.01) var minimum_pitch: float = 0.95
@export_range(0.5, 1.5, 0.01) var maximum_pitch: float = 1.05

@export_category("Fall Damage")
@export var fall_damage_enabled: bool = true
@export var safe_fall_speed: float = 10.0
@export var damage_per_speed: float = 5.0
@export var maximum_fall_damage: float = 100.0


@onready var player: CharacterBody3D = owner.get_parent() as CharacterBody3D
@onready var camera: Camera3D = owner.get_node("Head/Camera3D")
@onready var land_player: AudioStreamPlayer3D = owner.get_node(
	"Audio/LandPlayer"
)


var was_on_floor: bool = true
var lowest_fall_velocity: float = 0.0
var camera_kick: float = 0.0


func _ready() -> void:
	if player == null:
		return

	was_on_floor = player.is_on_floor()


func capture_fall_state() -> void:
	if player == null:
		return

	if not player.is_on_floor():
		lowest_fall_velocity = minf(
			lowest_fall_velocity,
			player.velocity.y
		)


func update_after_movement(delta: float) -> void:
	if player == null:
		return

	var is_on_floor_now: bool = player.is_on_floor()

	if is_on_floor_now and not was_on_floor:
		_process_landing()

	if is_on_floor_now:
		lowest_fall_velocity = 0.0

	was_on_floor = is_on_floor_now

	_update_camera_effect(delta)


func _process_landing() -> void:
	var impact_speed: float = absf(lowest_fall_velocity)

	if impact_speed < minimum_landing_speed:
		return

	landed.emit(impact_speed)

	_play_landing_sound()

	if landing_camera_effect_enabled:
		camera_kick = minf(
			impact_speed * landing_kick_strength,
			maximum_camera_kick
		)

	if not fall_damage_enabled:
		return

	if impact_speed <= safe_fall_speed:
		return

	var damage: float = (
		impact_speed - safe_fall_speed
	) * damage_per_speed

	damage = minf(
		damage,
		maximum_fall_damage
	)

	fall_damage_requested.emit(damage)


func _update_camera_effect(delta: float) -> void:
	if not landing_camera_effect_enabled:
		camera.rotation_degrees.x = 0.0
		return

	camera_kick = move_toward(
		camera_kick,
		0.0,
		camera_return_speed * delta
	)

	camera.rotation_degrees.x = camera_kick


func _play_landing_sound() -> void:
	if landing_sounds.is_empty():
		return

	var valid_sounds: Array[AudioStream] = []

	for sound in landing_sounds:
		if sound != null:
			valid_sounds.append(sound)

	if valid_sounds.is_empty():
		return

	land_player.stream = valid_sounds.pick_random()
	land_player.volume_db = landing_volume_db
	land_player.pitch_scale = randf_range(
		minimum_pitch,
		maximum_pitch
	)

	land_player.play()
