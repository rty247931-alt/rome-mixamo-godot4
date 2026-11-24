extends Node

@export_category("FOV")
@export var normal_fov: float = 75.0
@export var sprint_fov: float = 85.0
@export var transition_speed: float = 8.0

@onready var player: CharacterBody3D = owner.get_parent() as CharacterBody3D
@onready var camera: Camera3D = owner.get_node("Head/Camera3D")


func update_fov(delta: float) -> void:
	if player == null:
		return

	var horizontal_speed := Vector2(
		player.velocity.x,
		player.velocity.z
	).length()

	var is_moving := horizontal_speed > 0.2
	var is_sprinting: bool = player.input_controller.sprint_held
	var is_grounded := player.is_on_floor()

	var target_fov := normal_fov

	if is_moving and is_sprinting and is_grounded:
		target_fov = sprint_fov

	camera.fov = lerp(
		camera.fov,
		target_fov,
		min(transition_speed * delta, 1.0)
	)
