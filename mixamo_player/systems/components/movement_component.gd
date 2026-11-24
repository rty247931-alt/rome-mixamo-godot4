extends Node


@export_category("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var acceleration: float = 14.0
@export var deceleration: float = 18.0


@export_category("Jump")
@export var jump_velocity: float = 5.5


@export_category("Jump Audio")
@export var jump_sounds: Array[AudioStream] = []

@export_range(-30.0, 6.0, 0.5)
var jump_volume_db: float = 0.0

@export_range(0.5, 1.5, 0.01)
var jump_min_pitch: float = 0.95

@export_range(0.5, 1.5, 0.01)
var jump_max_pitch: float = 1.05


@export_category("Gravity")
@export var gravity: float = 18.0


@export_category("Step Handling")
@export var step_enabled: bool = true
@export var step_check_distance: float = 0.7
@export var maximum_step_height: float = 0.45
@export var minimum_step_height: float = 0.05

@export var step_down_start_height: float = 0.6
@export var step_down_distance: float = 0.8

@export_range(0.0, 1.0, 0.05)
var minimum_step_surface_normal: float = 0.7


@onready var player: CharacterBody3D = owner.get_parent() as CharacterBody3D

@onready var jump_player: AudioStreamPlayer3D = owner.get_node(
	"Audio/JumpPlayer"
)

@onready var lower_ray: RayCast3D = owner.get_node(
	"StepDetector/LowerRay"
)

@onready var upper_ray: RayCast3D = owner.get_node(
	"StepDetector/UpperRay"
)

@onready var step_down_ray: RayCast3D = owner.get_node(
	"StepDetector/StepDownRay"
)


func _update_step_rays(input_vector: Vector2) -> void:
	if input_vector.length_squared() <= 0.001:
		return

	var local_direction: Vector3 = Vector3(
		input_vector.x,
		0.0,
		input_vector.y
	).normalized()

	var forward_target: Vector3 = (
		local_direction * step_check_distance
	)

	lower_ray.target_position = forward_target
	upper_ray.target_position = forward_target

	step_down_ray.position = Vector3(
		local_direction.x * step_check_distance,
		step_down_start_height,
		local_direction.z * step_check_distance
	)

	step_down_ray.target_position = Vector3(
		0.0,
		-step_down_distance,
		0.0
	)

	lower_ray.force_raycast_update()
	upper_ray.force_raycast_update()
	step_down_ray.force_raycast_update()


func _handle_steps(input_vector: Vector2) -> void:
	if not step_enabled:
		return

	if input_vector.length_squared() <= 0.001:
		return

	if not player.is_on_floor():
		return

	if player.velocity.y > 0.0:
		return

	if not lower_ray.is_colliding():
		return

	if upper_ray.is_colliding():
		return

	if not step_down_ray.is_colliding():
		return

	var surface_normal: Vector3 = (
		step_down_ray.get_collision_normal()
	)

	if surface_normal.y < minimum_step_surface_normal:
		return

	var step_point: Vector3 = (
		step_down_ray.get_collision_point()
	)

	var step_height: float = (
		step_point.y - player.global_position.y
	)

	if step_height < minimum_step_height:
		return

	if step_height > maximum_step_height:
		return

	var upward_motion: Vector3 = Vector3(
		0.0,
		step_height,
		0.0
	)

	if player.test_move(
		player.global_transform,
		upward_motion
	):
		return

	player.global_position.y = step_point.y

	if player.velocity.y < 0.0:
		player.velocity.y = 0.0


func _play_jump_sound() -> void:
	if jump_sounds.is_empty():
		return

	var valid_sounds: Array[AudioStream] = []

	for sound in jump_sounds:
		if sound != null:
			valid_sounds.append(sound)

	if valid_sounds.is_empty():
		return

	var selected_index: int = randi_range(
		0,
		valid_sounds.size() - 1
	)

	var selected_sound: AudioStream = (
		valid_sounds[selected_index]
	)

	jump_player.stream = selected_sound
	jump_player.volume_db = jump_volume_db

	jump_player.pitch_scale = randf_range(
		jump_min_pitch,
		jump_max_pitch
	)

	jump_player.play()
