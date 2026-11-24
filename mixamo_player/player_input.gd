extends CanvasLayer

signal look_changed(delta: Vector2)
signal zoom_changed(amount: float)
signal respawn_requested
signal interact_requested

@export var force_touch_controls: bool = true
@export_range(0.0, 0.5, 0.01) var dead_zone: float = 0.12
@export_range(0.001, 0.02, 0.001) var touch_sensitivity: float = 0.006
@export_range(0.001, 0.02, 0.001) var mouse_sensitivity: float = 0.003
@export var invert_look_y: bool = false
@export var run_toggle: bool = true
@export var crouch_toggle: bool = true
@export_range(0.1, 2.0, 0.1) var zoom_step: float = 0.4
var enabled: bool = true:
	set(value):
		if enabled != value:
			enabled = value
			clear_input()
var move_vector := Vector2.ZERO
var crouch_held: bool = false
var sprint_held: bool = false
var jump_held: bool = false
var _jump_queued: bool = false
var _jump_previous: bool = false
var _focused: bool = true
var _fingers: Dictionary = {}
var _positions: Dictionary = {}
var _stick_finger: int = -1
var _look_finger: int = -1
var _mouse_look: bool = false
var _run_latched: bool = false
var _crouch_latched: bool = false
var _in_water: bool = false
@onready var overlay = $TouchControls

func _ready() -> void:
	overlay.visibility_changed.connect(clear_input)
	set_touch_visible(force_touch_controls or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"))

func _process(_delta: float) -> void:
	if get_tree().paused:
		clear_input()

func set_touch_visible(value: bool) -> void:
	if not value and overlay.editing:
		overlay.finish_editing()
		if overlay.editing:
			return
	overlay.visible = value
	clear_input()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_focused = false
		clear_input()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_focused = true

func _exit_tree() -> void:
	if _mouse_look:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func clear_input() -> void:
	_fingers.clear()
	_positions.clear()
	_stick_finger = -1
	_look_finger = -1
	_jump_queued = false
	_jump_previous = false
	_run_latched = false
	_crouch_latched = false
	jump_held = false
	sprint_held = false
	crouch_held = false
	move_vector = Vector2.ZERO
	if _mouse_look:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_look = false
	if is_instance_valid(overlay):
		overlay.cancel_drag()
		overlay.update_feedback(Vector2.ZERO, false, false, false, false)

func set_swimming(value: bool) -> void:
	if _in_water == value:
		return
	_in_water = value
	clear_input()
	overlay.set_swimming(value)

func sample() -> void:
	if not enabled or not _focused or get_tree().paused:
		clear_input()
		return
	if overlay.editing:
		move_vector = Vector2.ZERO
		jump_held = false
		sprint_held = false
		crouch_held = false
		return
	var keyboard := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	move_vector = (keyboard + stick_vector()).limit_length()
	sprint_held = Input.is_physical_key_pressed(KEY_SHIFT) or _run_latched or _fingers.values().has("run")
	crouch_held = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C) or _crouch_latched or _fingers.values().has("crouch")
	jump_held = Input.is_physical_key_pressed(KEY_SPACE) or _fingers.values().has("jump")
	if jump_held and not _jump_previous:
		_jump_queued = true
	_jump_previous = jump_held
	overlay.update_feedback(stick_vector(), jump_held, sprint_held, crouch_held, _fingers.values().has("use"))

func take_jump() -> bool:
	var result: bool = _jump_queued
	_jump_queued = false
	return result

func stick_vector() -> Vector2:
	if _stick_finger == -1 or not _positions.has(_stick_finger):
		return Vector2.ZERO
	var value: Vector2 = overlay.joystick_vector(_positions[_stick_finger])
	var magnitude := value.length()
	if magnitude <= dead_zone:
		return Vector2.ZERO
	return value.normalized() * clampf((magnitude - dead_zone) / (1.0 - dead_zone), 0.0, 1.0)

func _input(event: InputEvent) -> void:
	if get_tree().paused:
		clear_input()
		return
	if not enabled or not _focused:
		return
	if event is InputEventScreenTouch and (not event.pressed or event.canceled):
		if _fingers.has(event.index):
			if event.canceled:
				clear_input()
			else:
				_end_touch(event.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _fingers.has(event.index):
		_drag_touch(event.index, event.position, event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _fingers.has(-100):
			_end_touch(-100)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and _mouse_look:
			_mouse_look = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _mouse_look:
			_emit_look(event.relative * mouse_sensitivity)
			get_viewport().set_input_as_handled()
		elif _fingers.has(-100):
			_drag_touch(-100, event.position, event.relative)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not _focused or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if overlay.editing:
				overlay.finish_editing()
			clear_input()
		elif event.physical_keycode == KEY_F6:
			set_touch_visible(not overlay.visible)
		elif not overlay.editing:
			if event.physical_keycode == KEY_E:
				interact_requested.emit()
			elif event.physical_keycode == KEY_R:
				respawn_requested.emit()
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		if not overlay.visible:
			set_touch_visible(true)
		if _begin_touch(event.index, event.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and overlay.visible:
			if _begin_touch(-100, event.position):
				get_viewport().set_input_as_handled()
		elif not overlay.editing:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_mouse_look = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_changed.emit(-zoom_step)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_changed.emit(zoom_step)

func _begin_touch(index: int, position: Vector2) -> bool:
	var role: String = overlay.role_at(position)
	if overlay.editing:
		if overlay.begin_drag(index, position):
			_fingers[index] = "edit"
			return true
		return false
	if role == "stick":
		if _stick_finger != -1:
			return true
		_stick_finger = index
	elif role == "look":
		if _look_finger != -1:
			return true
		_look_finger = index
	elif role == "":
		return false
	_fingers[index] = role
	_positions[index] = position
	match role:
		"jump": _jump_queued = true
		"run":
			if run_toggle:
				_run_latched = not _run_latched
				_fingers[index] = "toggle"
		"crouch":
			if crouch_toggle and not _in_water:
				_crouch_latched = not _crouch_latched
				_fingers[index] = "toggle"
		"use": interact_requested.emit()
		"zoom_in": zoom_changed.emit(-zoom_step)
		"zoom_out": zoom_changed.emit(zoom_step)
		"reset": respawn_requested.emit()
	sample()
	return true

func _drag_touch(index: int, position: Vector2, relative: Vector2) -> void:
	_positions[index] = position
	if _fingers[index] == "edit":
		overlay.drag_control(index, position)
	elif index == _look_finger:
		_emit_look(relative / overlay.ui_scale * touch_sensitivity)
	sample()

func _emit_look(amount: Vector2) -> void:
	if invert_look_y:
		amount.y = -amount.y
	look_changed.emit(amount)

func _end_touch(index: int) -> void:
	overlay.end_drag(index)
	_fingers.erase(index)
	_positions.erase(index)
	if index == _stick_finger:
		_stick_finger = -1
	if index == _look_finger:
		_look_finger = -1
	sample()
