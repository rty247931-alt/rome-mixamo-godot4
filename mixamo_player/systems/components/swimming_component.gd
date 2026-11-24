extends Node


signal entered_water
signal exited_water
signal underwater_started
signal underwater_ended


@export_category("Swimming")
@export var swim_speed: float = 4.0
@export var fast_swim_speed: float = 6.0
@export var vertical_swim_speed: float = 3.0
@export var swim_acceleration: float = 8.0
@export var swim_deceleration: float = 6.0


@export_category("Buoyancy")
@export var buoyancy_enabled: bool = true
@export var buoyancy_strength: float = 1.2


@export_category("Underwater")
@export var surface_margin: float = 0.15


@export_category("Swimming Camera")
@export var swim_camera_sway_enabled: bool = true
@export var swim_camera_sway_speed: float = 2.0
@export var swim_camera_sway_amount: float = 1.2
@export var swim_camera_return_speed: float = 4.0


@export_category("Water Audio")
@export var enter_water_sound: AudioStream
@export var exit_water_sound: AudioStream
@export var underwater_loop_sound: AudioStream

@export_range(-30.0, 6.0, 0.5)
var water_event_volume_db: float = 0.0

@export_range(-30.0, 6.0, 0.5)
var underwater_volume_db: float = -6.0


@onready var player: CharacterBody3D = owner.get_parent() as CharacterBody3D
@onready var camera: Camera3D = owner.get_node("Head/Camera3D")

@onready var underwater_overlay: ColorRect = owner.get_node(
	"UI/UnderwaterOverlay"
)

@onready var movement_player: AudioStreamPlayer3D = owner.get_node(
	"Audio/MovementPlayer"
)

@onready var underwater_loop_player: AudioStreamPlayer = owner.get_node(
	"Audio/UnderwaterLoopPlayer"
)


var is_in_water: bool = false
var is_underwater: bool = false
var water_surface_y: float = 0.0

var swim_sway_time: float = 0.0


func _ready() -> void:
	underwater_overlay.visible = false

	if not underwater_loop_player.finished.is_connected(
		_on_underwater_loop_finished
	):
		underwater_loop_player.finished.connect(
			_on_underwater_loop_finished
		)


func enter_water(surface_y: float) -> void:
	water_surface_y = surface_y

	if is_in_water:
		return

	is_in_water = true
	entered_water.emit()


func exit_water() -> void:
	if not is_in_water:
		return

	is_in_water = false
	_stop_underwater_effects()

	exited_water.emit()


func update_swimming(delta: float) -> void:
	if player == null:
		return

	if not is_in_water:
		return

	_update_underwater_state()
	_update_swim_velocity(delta)


func update_camera_effects(delta: float) -> void:
	if is_in_water:
		_update_swim_camera(delta)
	else:
		_update_camera_return(delta)


func _update_underwater_state() -> void:
	var camera_y: float = camera.global_position.y

	var underwater_now: bool = (
		camera_y < water_surface_y - surface_margin
	)

	if underwater_now == is_underwater:
		return

	is_underwater = underwater_now
	underwater_overlay.visible = is_underwater

	if is_underwater:
		# الصوت يعمل فقط في نفس لحظة ظهور تأثير الغوص.
		_play_water_event_sound(enter_water_sound)
		_start_underwater_audio()

		underwater_started.emit()

	else:
		# صوت الخروج يعمل فقط عندما تخرج الكاميرا من الماء.
		_play_water_event_sound(exit_water_sound)
		_stop_underwater_audio()

		underwater_ended.emit()


func _update_swim_velocity(delta: float) -> void:
	var input_vector: Vector2 = player.input_controller.move_vector

	var direction: Vector3 = Vector3(
		input_vector.x,
		0.0,
		input_vector.y
	)

	direction = player.camera_rig.movement_direction(input_vector)
	direction.y = 0.0
	direction = direction.limit_length()

	var current_speed: float = fast_swim_speed if player.input_controller.sprint_held else swim_speed
	var target_x: float = direction.x * current_speed
	var target_z: float = direction.z * current_speed

	player.velocity.x = move_toward(
		player.velocity.x,
		target_x,
		swim_acceleration * delta
	)

	player.velocity.z = move_toward(
		player.velocity.z,
		target_z,
		swim_acceleration * delta
	)

	if direction == Vector3.ZERO:
		player.velocity.x = move_toward(
			player.velocity.x,
			0.0,
			swim_deceleration * delta
		)

		player.velocity.z = move_toward(
			player.velocity.z,
			0.0,
			swim_deceleration * delta
		)

	var vertical_input: float = 0.0

	if player.input_controller.jump_held:
		vertical_input += 1.0

	if player.input_controller.crouch_held:
		vertical_input -= 1.0

	if vertical_input != 0.0:
		player.velocity.y = move_toward(
			player.velocity.y,
			vertical_input * vertical_swim_speed,
			swim_acceleration * delta
		)

	elif buoyancy_enabled:
		player.velocity.y = move_toward(
			player.velocity.y,
			buoyancy_strength,
			swim_acceleration * delta
		)

	else:
		player.velocity.y = move_toward(
			player.velocity.y,
			0.0,
			swim_deceleration * delta
		)


func _update_swim_camera(delta: float) -> void:
	if not swim_camera_sway_enabled:
		_update_camera_return(delta)
		return

	var horizontal_speed: float = Vector2(
		player.velocity.x,
		player.velocity.z
	).length()

	if horizontal_speed < 0.2:
		_update_camera_return(delta)
		return

	swim_sway_time += delta * swim_camera_sway_speed

	var target_roll: float = (
		sin(swim_sway_time)
		* swim_camera_sway_amount
	)

	camera.rotation_degrees.z = lerpf(
		camera.rotation_degrees.z,
		target_roll,
		minf(delta * swim_camera_return_speed, 1.0)
	)


func _update_camera_return(delta: float) -> void:
	camera.rotation_degrees.z = lerpf(
		camera.rotation_degrees.z,
		0.0,
		minf(delta * swim_camera_return_speed, 1.0)
	)


func _play_water_event_sound(sound: AudioStream) -> void:
	if sound == null:
		return

	movement_player.stream = sound
	movement_player.volume_db = water_event_volume_db
	movement_player.play()


func _start_underwater_audio() -> void:
	if underwater_loop_sound == null:
		return

	underwater_loop_player.stream = underwater_loop_sound
	underwater_loop_player.volume_db = underwater_volume_db

	if not underwater_loop_player.playing:
		underwater_loop_player.play()


func _stop_underwater_audio() -> void:
	if underwater_loop_player.playing:
		underwater_loop_player.stop()


func _stop_underwater_effects() -> void:
	var was_underwater: bool = is_underwater

	is_underwater = false
	underwater_overlay.visible = false

	_stop_underwater_audio()

	if was_underwater:
		underwater_ended.emit()


func _on_underwater_loop_finished() -> void:
	if is_underwater and underwater_loop_sound != null:
		underwater_loop_player.play()
