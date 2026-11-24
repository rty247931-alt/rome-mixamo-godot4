extends Node

@export_category("Walking Bob")
@export var walk_frequency: float = 8.0
@export var walk_horizontal_amount: float = 0.025
@export var walk_vertical_amount: float = 0.035

@export_category("Sprint Bob")
@export var sprint_frequency: float = 11.0
@export var sprint_horizontal_amount: float = 0.04
@export var sprint_vertical_amount: float = 0.055

@export_category("Smoothing")
@export var return_speed: float = 10.0

@onready var player: CharacterBody3D = owner.get_parent() as CharacterBody3D
@onready var camera: Camera3D = owner.get_node("Head/Camera3D")

var bob_time: float = 0.0
var base_camera_position: Vector3


func _ready() -> void:
	base_camera_position = Vector3.ZERO


func update_head_bob(delta: float) -> void:
	if player == null:
		return

	var horizontal_speed := Vector2(
		player.velocity.x,
		player.velocity.z
	).length()

	var is_moving := horizontal_speed > 0.2
	var is_grounded := player.is_on_floor()

	if is_moving and is_grounded:
		var frequency := walk_frequency
		var horizontal_amount := walk_horizontal_amount
		var vertical_amount := walk_vertical_amount

		if player.input_controller.sprint_held:
			frequency = sprint_frequency
			horizontal_amount = sprint_horizontal_amount
			vertical_amount = sprint_vertical_amount

		bob_time += delta * frequency

		var target_position := base_camera_position

		target_position.x += cos(bob_time * 0.5) * horizontal_amount
		target_position.y += sin(bob_time) * vertical_amount

		var offset := Vector3(camera.h_offset, camera.v_offset, 0).lerp(
			target_position,
			min(return_speed * delta, 1.0)
		)
		camera.h_offset = offset.x
		camera.v_offset = offset.y
	else:
		bob_time = 0.0

		var offset := Vector3(camera.h_offset, camera.v_offset, 0).lerp(
			base_camera_position,
			min(return_speed * delta, 1.0)
		)

		camera.h_offset = offset.x
		camera.v_offset = offset.y
