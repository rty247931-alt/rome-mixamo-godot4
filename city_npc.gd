extends Node3D
## Lightweight pedestrian brain: patrol, pause, turn, and use imported Mixamo clips.

@export var move_speed: float = 0.85
@export var pause_time: float = 1.4
@export var turn_speed: float = 7.0

var route: Array[Vector3] = []
var target_index: int = 0
var pause_left: float = 0.0
var animation_player: AnimationPlayer
var walk_clip: StringName = &""
var idle_clip: StringName = &""

func _ready() -> void:
	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		return
	for clip in animation_player.get_animation_list():
		var lower := String(clip).to_lower()
		if walk_clip == &"" and (lower.contains("walk") or lower.contains("run")):
			walk_clip = clip
		if idle_clip == &"" and (lower.contains("idle") or lower.contains("stand")):
			idle_clip = clip
	if idle_clip != &"":
		_play_clip(idle_clip)
	elif animation_player.get_animation_list().size() > 0:
		_play_clip(animation_player.get_animation_list()[0])

func _process(delta: float) -> void:
	if route.size() < 2:
		return
	if pause_left > 0.0:
		pause_left = maxf(0.0, pause_left - delta)
		if pause_left == 0.0:
			_play_walking()
		return
	var target := route[target_index]
	var offset := target - global_position
	offset.y = 0.0
	if offset.length() < 0.28:
		target_index = (target_index + 1) % route.size()
		pause_left = pause_time
		_play_idle()
		return
	var direction := offset.normalized()
	global_position += direction * move_speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-turn_speed * delta))
	_play_walking()

func _play_walking() -> void:
	if walk_clip != &"":
		_play_clip(walk_clip)

func _play_idle() -> void:
	if idle_clip != &"":
		_play_clip(idle_clip)

func _play_clip(clip: StringName) -> void:
	if animation_player and animation_player.current_animation != clip:
		animation_player.play(clip)
