extends Node3D
## Orbit rig stays independent of the character's facing direction.
@export var distance: float = 4.3
@export var min_distance: float = 1.5
@export var max_distance: float = 7.0
@export var pitch_min: float = -65.0
@export var pitch_max: float = 35.0
@export var sensitivity: float = 1.0
var yaw: float = 0.0
var pitch: float = deg_to_rad(-16.0)
var arm: SpringArm3D
var camera: Camera3D

func _ready() -> void:
	position.y = 1.45
	arm = SpringArm3D.new()
	arm.name = "CollisionArm"
	arm.spring_length = distance
	arm.margin = 0.15
	arm.collision_mask = 1
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	arm.shape = sphere
	add_child(arm)
	if get_parent() is CollisionObject3D:
		arm.add_excluded_object(get_parent().get_rid())
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
	camera.fov = 65.0
	camera.near = 0.08
	if camera.get_parent() != null:
		camera.reparent(arm, false)
	else:
		arm.add_child(camera)
	camera.current = true
	rotation = Vector3(pitch, yaw, 0)

func rotate_view(delta: Vector2) -> void:
	yaw -= delta.x * sensitivity
	pitch = clampf(pitch - delta.y * sensitivity, deg_to_rad(pitch_min), deg_to_rad(pitch_max))

func zoom(amount: float) -> void:
	distance = clampf(distance + amount, min_distance, max_distance)

func _process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-22.0 * delta))
	rotation.x = lerp_angle(rotation.x, pitch, 1.0 - exp(-22.0 * delta))
	arm.spring_length = lerpf(arm.spring_length, distance, 1.0 - exp(-12.0 * delta))

func movement_direction(input: Vector2) -> Vector3:
	# Camera looks down -Z. W / stick up therefore has negative input.y.
	return Basis(Vector3.UP, rotation.y) * Vector3(input.x, 0, input.y)
