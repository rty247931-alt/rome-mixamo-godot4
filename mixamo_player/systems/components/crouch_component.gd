extends Node

@export_category("Crouch")
@export var standing_height: float = 1.8
@export var crouching_height: float = 1.0

@export var standing_head_y: float = 1.6
@export var crouching_head_y: float = 1.0

@export var transition_speed: float = 8.0
@export var crouch_speed: float = 1.5

@onready var player: CharacterBody3D = owner.get_parent() as CharacterBody3D
@onready var collision_shape: CollisionShape3D = owner.get_parent().get_node("CollisionShape3D")
@onready var head: Node3D = owner.get_node("Head")
@onready var ceiling_check: ShapeCast3D = owner.get_node("Head/CeilingCheck")

var is_crouching: bool = false


func _ready() -> void:
	collision_shape.shape = collision_shape.shape.duplicate()
	# يمنع فحص السقف من اكتشاف جسم اللاعب نفسه.
	if player != null:
		ceiling_check.add_exception(player)


func update_crouch(delta: float) -> void:
	if player == null:
		return

	if player.input_controller.crouch_held:
		is_crouching = true
	else:
		ceiling_check.force_shapecast_update()

		if not ceiling_check.is_colliding():
			is_crouching = false

	_apply_crouch(delta)


func _apply_crouch(delta: float) -> void:
	var capsule := collision_shape.shape as CapsuleShape3D

	if capsule == null:
		return

	var target_height := standing_height
	var target_head_y := standing_head_y

	if is_crouching:
		target_height = crouching_height
		target_head_y = crouching_head_y

	capsule.height = move_toward(
		capsule.height,
		target_height,
		transition_speed * delta
	)

	collision_shape.position.y = capsule.height * 0.5

	head.position.y = move_toward(
		head.position.y,
		target_head_y,
		transition_speed * delta
	)


func get_speed_override() -> float:
	if is_crouching:
		return crouch_speed

	return -1.0
