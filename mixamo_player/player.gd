extends CharacterBody3D
## Drag player.tscn into any 3D level. All paths are relative to this folder.
signal jumped
signal landed(impact_speed: float)
signal respawned
signal fall_damage_requested(damage: float)

const CameraScript = preload("third_person_camera.gd")
@export_group("Movement")
@export var walk_speed: float = 2.5
@export var run_speed: float = 5.8
@export var acceleration: float = 18.0
@export var deceleration: float = 22.0
@export var air_acceleration: float = 6.0
@export var turn_speed: float = 12.0
@export var jump_velocity: float = 7.0
@export var gravity_force: float = 22.0
@export var max_fall_speed: float = 45.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.14
@export_group("Setup")
@export var controls_enabled: bool = true
@export var show_touch_on_desktop: bool = true
@export var auto_respawn: bool = true
@export var respawn_below_y: float = -20.0

@onready var visual: Node3D = $Visual
@onready var animation_player: AnimationPlayer = $Visual/YBot/AnimationPlayer
@onready var systems: Node3D = $Components
@onready var movement_component: Node = $Components/MovementComponent
@onready var crouch_component: Node = $Components/CrouchComponent
@onready var swimming_component: Node = $Components/SwimmingComponent
@onready var fall_component: Node = $Components/FallComponent
@onready var interaction_component: Node = $Components/InteractionComponent
@export var enable_rigidbody_push: bool = true
@export var rigidbody_push_force: float = 45.0
@onready var input_controller: CanvasLayer = $PlayerInput
var camera_rig: Node3D
var animation_state: StringName = &""
var _spawn_transform: Transform3D
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _jump_previous: bool = false
var _landing_time: float = 0.0
var _air_time: float = 0.0

func _ready() -> void:
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(46)
	floor_stop_on_slope = true
	_spawn_transform = global_transform
	input_controller.force_touch_controls = show_touch_on_desktop
	input_controller.set_touch_visible(show_touch_on_desktop or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"))
	camera_rig = CameraScript.new()
	camera_rig.name = "CameraRig"
	camera_rig.camera = $Components/Head/Camera3D
	add_child(camera_rig)
	input_controller.look_changed.connect(camera_rig.rotate_view)
	input_controller.zoom_changed.connect(camera_rig.zoom)
	input_controller.respawn_requested.connect(respawn)
	get_viewport().size_changed.connect(_resize_system_ui)
	_resize_system_ui()
	input_controller.interact_requested.connect(_request_interaction)
	swimming_component.entered_water.connect(func(): input_controller.set_swimming(true))
	swimming_component.exited_water.connect(func(): input_controller.set_swimming(false))
	jumped.connect(movement_component._play_jump_sound)
	fall_component.fall_damage_requested.connect(func(damage: float): fall_damage_requested.emit(damage))
	for ray in [systems.get_node("GroundCheck"), systems.get_node("StepDetector/LowerRay"), systems.get_node("StepDetector/UpperRay"), systems.get_node("StepDetector/StepDownRay")]:
		ray.add_exception(self)
	# Existing water areas monitor layer 1. Keep layer 2 for identifying players.
	set_collision_layer_value(1, true)
	_play(&"Idle")

func _physics_process(delta: float) -> void:
	input_controller.enabled = controls_enabled
	input_controller.sample()
	_jump_buffer = maxf(0, _jump_buffer - delta)
	if not controls_enabled:
		_jump_buffer = 0.0
		_interaction_queued = false
	if input_controller.take_jump():
		_jump_buffer = jump_buffer_time
	if swimming_component.is_in_water:
		_jump_buffer = 0.0
		_coyote = 0.0
		_air_time = 0.0
		fall_component.lowest_fall_velocity = 0.0
		fall_component.was_on_floor = is_on_floor()
		swimming_component.update_swimming(delta)
		move_and_slide()
		_update_systems(delta, true)
		_play(&"Idle")
		if auto_respawn and global_position.y < respawn_below_y:
			respawn()
		return
	crouch_component.update_crouch(delta)
	camera_rig.position.y = systems.get_node("Head").position.y - 0.15
	var grounded: bool = is_on_floor()
	if grounded:
		_coyote = coyote_time
		_air_time = 0.0
	else:
		_coyote = maxf(0, _coyote - delta)
		_air_time += delta
		velocity.y = maxf(velocity.y - gravity_force * delta, -max_fall_speed)
	var direction: Vector3 = camera_rig.movement_direction(input_controller.move_vector)
	var target_speed: float = run_speed if input_controller.sprint_held else walk_speed
	if crouch_component.is_crouching:
		target_speed = crouch_component.crouch_speed
	var target_velocity: Vector3 = direction * target_speed
	var rate: float = acceleration if direction.length_squared() > 0.001 else deceleration
	if not grounded:
		rate = air_acceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
	if direction.length_squared() > 0.005:
		# Mixamo Y Bot faces +Z in its source file.
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-turn_speed * delta))
	if _jump_buffer > 0.0 and _coyote > 0.0 and not crouch_component.is_crouching:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_landing_time = 0.0
		_play(&"Jump", 0.1)
		jumped.emit()
	if _jump_previous and not input_controller.jump_held and velocity.y > jump_velocity * 0.5:
		velocity.y = jump_velocity * 0.5
	_jump_previous = input_controller.jump_held
	var local_direction: Vector3 = global_basis.inverse() * direction
	var step_input := Vector2(local_direction.x, local_direction.z)
	movement_component._update_step_rays(step_input)
	movement_component._handle_steps(step_input)
	fall_component.capture_fall_state()
	var downward_speed: float = -velocity.y
	move_and_slide()
	if not grounded and is_on_floor():
		if _air_time > 0.12:
			_landing_time = 0.38
			landed.emit(downward_speed)
		_air_time = 0.0
	fall_component.update_after_movement(delta)
	_update_systems(delta, false)
	_update_animation(delta)
	if auto_respawn and global_position.y < respawn_below_y:
		respawn()

func _update_animation(delta: float) -> void:
	_landing_time = maxf(0, _landing_time - delta)
	var speed: float = Vector2(velocity.x, velocity.z).length()
	animation_player.speed_scale = 1.0
	if not is_on_floor():
		if velocity.y > 0.1:
			_play(&"Jump", 0.12)
		else:
			_play(&"Fall", 0.2)
	elif _landing_time > 0.0 and speed < 0.3:
		_play(&"Land", 0.08)
	elif speed > walk_speed * 1.2:
		_play(&"Run")
		animation_player.speed_scale = clampf(speed / run_speed, 0.65, 1.3)
	elif speed > 0.12:
		_play(&"Walk")
		animation_player.speed_scale = clampf(speed / walk_speed, 0.35, 1.3)
	else:
		_play(&"Idle")

func _play(next: StringName, blend: float = 0.18) -> void:
	if animation_state == next:
		return
	animation_state = next
	animation_player.play(next, blend)

func set_checkpoint(at: Transform3D) -> void:
	_spawn_transform = at

func respawn() -> void:
	swimming_component.exit_water()
	fall_component.lowest_fall_velocity = 0.0
	fall_component.camera_kick = 0.0
	fall_component.was_on_floor = true
	_air_time = 0.0
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_coyote = 0.0
	_jump_buffer = 0.0
	_landing_time = 0.0
	_jump_previous = false
	input_controller.clear_input()
	_play(&"Idle", 0.0)
	respawned.emit()

var _interaction_queued: bool = false

func _request_interaction() -> void:
	if controls_enabled and not input_controller.overlay.editing:
		_interaction_queued = true

func _update_systems(delta: float, in_water: bool) -> void:
	if enable_rigidbody_push:
		for index in get_slide_collision_count():
			var collision := get_slide_collision(index)
			var body := collision.get_collider() as RigidBody3D
			if body == null or body.freeze or absf(collision.get_normal().y) > 0.65:
				continue
			var push := -collision.get_normal()
			push.y = 0
			body.sleeping = false
			body.apply_force(push.normalized() * rigidbody_push_force, collision.get_position() - body.global_position)
	if not in_water:
		systems.get_node("HeadBobComponent").update_head_bob(delta)
		systems.get_node("FootstepComponent").update_footsteps(delta, crouch_component.is_crouching)
	else:
		camera_rig.camera.h_offset = move_toward(camera_rig.camera.h_offset, 0, delta)
		camera_rig.camera.v_offset = move_toward(camera_rig.camera.v_offset, 0, delta)
		fall_component._update_camera_effect(delta)
	systems.get_node("FOVComponent").update_fov(delta)
	swimming_component.update_camera_effects(delta)
	interaction_component.update_interaction()
	if _interaction_queued:
		_interaction_queued = false
		interaction_component.handle_interaction_input()

func _resize_system_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var ui_scale := maxf(1.0, minf(viewport_size.x / 1280.0, viewport_size.y / 720.0))
	var crosshair: ColorRect = systems.get_node("UI/Crosshair")
	crosshair.offset_left = -3 * ui_scale
	crosshair.offset_top = -3 * ui_scale
	crosshair.offset_right = 3 * ui_scale
	crosshair.offset_bottom = 3 * ui_scale
	var label: Label = systems.get_node("UI/InteractionUI/InteractionLabel")
	label.add_theme_font_size_override("font_size", int(21 * ui_scale))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", int(2 * ui_scale))
	label.add_theme_constant_override("shadow_offset_y", int(2 * ui_scale))
	label.offset_left = -300 * ui_scale
	label.offset_right = 300 * ui_scale
	label.offset_top = 28 * ui_scale
	label.offset_bottom = 72 * ui_scale
