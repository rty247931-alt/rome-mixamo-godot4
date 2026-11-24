extends Node3D

@export var move_speed: float = 0.8
@export var pause_time: float = 1.8
var route: Array[Vector3] = []
var target_index: int = 0
var pause_left: float = 0.0
var animation_player: AnimationPlayer

func _ready() -> void:
	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player and animation_player.has_animation("Idle"):
		animation_player.play("Idle")

func _process(delta: float) -> void:
	if route.size() < 2:
		return
	if pause_left > 0.0:
		pause_left -= delta
		return
	var target := route[target_index]
	var offset := target - global_position
	offset.y = 0.0
	if offset.length() < 0.18:
		target_index = (target_index + 1) % route.size()
		pause_left = pause_time
		if animation_player and animation_player.has_animation("Idle"):
			animation_player.play("Idle")
		return
	var direction := offset.normalized()
	global_position += direction * move_speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-8.0 * delta))
	if animation_player and animation_player.has_animation("Walk") and animation_player.current_animation != "Walk":
		animation_player.play("Walk")
