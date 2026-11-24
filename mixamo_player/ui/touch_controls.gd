extends Control

@export_range(480.0, 1080.0, 10.0) var reference_short_side: float = 720.0
@export var respect_safe_area: bool = true
@export var settings_file: String = "user://mixamo_mobile_controls_v1.cfg"
var editing: bool = false
var ui_scale: float = 1.0
var _defaults: Dictionary = {}
var _layout: Dictionary = {}
var _selected: Control
var _drag_finger: int = -1
var _drag_offset := Vector2.ZERO
var _config := ConfigFile.new()
var _orientation: String = "landscape"
@onready var source = get_parent()
@onready var safe_area: Control = $SafeArea
@onready var controls: Control = $SafeArea/Controls
@onready var joystick: Control = $SafeArea/Controls/Joystick
@onready var knob: Control = $SafeArea/Controls/Joystick/Knob
@onready var editor_panel: Control = $SafeArea/Editor
@onready var selected_label: Label = $SafeArea/Editor/Margin/Rows/Selected
@onready var size_slider: HSlider = $SafeArea/Editor/Margin/Rows/SizeRow/Size
@onready var sensitivity_slider: HSlider = $SafeArea/Editor/Margin/Rows/SensitivityRow/Sensitivity
@onready var opacity_slider: HSlider = $SafeArea/Editor/Margin/Rows/OpacityRow/Opacity

func _ready() -> void:
	for control: Control in controls.get_children():
		_defaults[control.name] = {
			"anchors": Vector4(control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom),
			"offsets": Vector4(control.offset_left, control.offset_top, control.offset_right, control.offset_bottom),
			"size": control.size
		}
	_config.load(settings_file)
	source.touch_sensitivity = clampf(float(_config.get_value("options", "sensitivity", source.touch_sensitivity)), 0.001, 0.02)
	controls.modulate.a = clampf(float(_config.get_value("options", "opacity", 0.85)), 0.25, 1.0)
	source.run_toggle = bool(_config.get_value("options", "run_toggle", source.run_toggle))
	source.crouch_toggle = bool(_config.get_value("options", "crouch_toggle", source.crouch_toggle))
	$SafeArea/EditButton.pressed.connect(start_editing)
	$SafeArea/Editor/Margin/Rows/Actions/Done.pressed.connect(finish_editing)
	$SafeArea/Editor/Margin/Rows/Actions/Reset.pressed.connect(reset_layout)
	size_slider.value_changed.connect(_resize_selected)
	sensitivity_slider.value = source.touch_sensitivity
	sensitivity_slider.value_changed.connect(func(value: float): source.touch_sensitivity = value)
	opacity_slider.value = controls.modulate.a
	opacity_slider.value_changed.connect(func(value: float): controls.modulate.a = value)
	$SafeArea/Editor/Margin/Rows/Toggles/Run.button_pressed = source.run_toggle
	$SafeArea/Editor/Margin/Rows/Toggles/Crouch.button_pressed = source.crouch_toggle
	$SafeArea/Editor/Margin/Rows/Toggles/Run.toggled.connect(func(value: bool): source.run_toggle = value)
	$SafeArea/Editor/Margin/Rows/Toggles/Crouch.toggled.connect(func(value: bool): source.crouch_toggle = value)
	resized.connect(_resize_layout)
	_resize_layout()

func _resize_layout() -> void:
	if not is_node_ready() or size.x <= 0 or size.y <= 0:
		return
	source.clear_input()
	var usable := Rect2(Vector2.ZERO, size)
	if respect_safe_area and OS.has_feature("mobile"):
		var screen_safe := Rect2(DisplayServer.get_display_safe_area())
		var screen_to_canvas := get_viewport().get_screen_transform().affine_inverse()
		usable = (screen_to_canvas * screen_safe).intersection(usable)
		if not usable.has_area():
			usable = Rect2(Vector2.ZERO, size)
	ui_scale = minf(usable.size.x, usable.size.y) / reference_short_side
	safe_area.position = usable.position
	safe_area.scale = Vector2.ONE * ui_scale
	safe_area.size = usable.size / ui_scale
	var next_orientation := "landscape" if size.x >= size.y else "portrait"
	if next_orientation != _orientation or _layout.is_empty():
		_orientation = next_orientation
		_layout = _config.get_value(_orientation, "layout", {}).duplicate(true)
	for control: Control in controls.get_children():
		_restore_control(control)
		_apply_custom(control)
	update_feedback(Vector2.ZERO, false, false, false, false)

func _restore_control(control: Control) -> void:
	var defaults: Dictionary = _defaults[control.name]
	var anchors: Vector4 = defaults.anchors
	var offsets: Vector4 = defaults.offsets
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w

func _apply_custom(control: Control) -> void:
	if not _layout.has(str(control.name)):
		return
	var custom: Dictionary = _layout[str(control.name)]
	var center: Vector2 = custom.get("center", Vector2(0.5, 0.5))
	var factor := clampf(float(custom.get("scale", 1.0)), 0.7, 1.6)
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.size = _defaults[control.name].size * factor
	control.position = _clamp_position(center * safe_area.size - control.size * 0.5, control.size)

func _clamp_position(point: Vector2, extent: Vector2) -> Vector2:
	return point.clamp(Vector2.ONE * 8, safe_area.size - extent - Vector2.ONE * 8)

func role_at(point: Vector2) -> String:
	for control: Control in controls.get_children():
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return str(control.get_meta("action", ""))
	if $SafeArea/LookArea.get_global_rect().has_point(point):
		return "look"
	return ""

func joystick_vector(point: Vector2) -> Vector2:
	var local_point := joystick.get_global_transform().affine_inverse() * point
	return ((local_point - joystick.size * 0.5) / (minf(joystick.size.x, joystick.size.y) * 0.38)).limit_length()

func update_feedback(direction: Vector2, jump: bool, run: bool, crouch: bool, interact: bool) -> void:
	knob.position = (joystick.size - knob.size) * 0.5 + direction * minf(joystick.size.x, joystick.size.y) * 0.28
	$SafeArea/Controls/Jump.set_pressed_no_signal(jump)
	$SafeArea/Controls/Run.set_pressed_no_signal(run)
	$SafeArea/Controls/Crouch.set_pressed_no_signal(crouch)
	$SafeArea/Controls/Interact.set_pressed_no_signal(interact)

func set_swimming(value: bool) -> void:
	$SafeArea/Controls/Jump.text = "صعود" if value else "قفز"
	$SafeArea/Controls/Crouch.text = "غوص" if value else "انحناء"
	$SafeArea/Controls/Run.text = "تسريع" if value else "ركض"

func start_editing() -> void:
	if not source.enabled:
		return
	source.clear_input()
	editing = true
	editor_panel.show()
	$SafeArea/EditButton.hide()
	selected_label.text = "اسحب أي زر لتغيير مكانه، ثم عدّل حجمه"

func finish_editing() -> void:
	var error := save_settings()
	if error != OK:
		selected_label.text = "تعذّر حفظ الإعدادات: %s" % error_string(error)
		return
	editing = false
	source.clear_input()
	editor_panel.hide()
	$SafeArea/EditButton.show()
	if is_instance_valid(_selected):
		_selected.modulate = Color.WHITE
	_selected = null

func save_settings() -> Error:
	_config.set_value(_orientation, "layout", _layout)
	_config.set_value("options", "sensitivity", source.touch_sensitivity)
	_config.set_value("options", "opacity", controls.modulate.a)
	_config.set_value("options", "run_toggle", source.run_toggle)
	_config.set_value("options", "crouch_toggle", source.crouch_toggle)
	return _config.save(settings_file)

func begin_drag(index: int, point: Vector2) -> bool:
	if _drag_finger != -1:
		return false
	for control: Control in controls.get_children():
		if control.get_global_rect().has_point(point):
			if is_instance_valid(_selected):
				_selected.modulate = Color.WHITE
			_selected = control
			_selected.modulate = Color(1, 0.85, 0.45)
			_drag_finger = index
			_drag_offset = safe_area.get_global_transform().affine_inverse() * point - control.position
			selected_label.text = "العنصر المحدد: " + str(control.get_meta("title", control.name))
			size_slider.set_value_no_signal(float(_layout.get(str(control.name), {}).get("scale", 1.0)))
			return true
	return false

func drag_control(index: int, point: Vector2) -> void:
	if index != _drag_finger or not is_instance_valid(_selected):
		return
	var local_point := safe_area.get_global_transform().affine_inverse() * point
	_selected.position = _clamp_position(local_point - _drag_offset, _selected.size)
	_remember_selected()

func end_drag(index: int) -> void:
	if index == _drag_finger:
		cancel_drag()

func cancel_drag() -> void:
	_drag_finger = -1

func _remember_selected() -> void:
	_layout[str(_selected.name)] = {
		"center": (_selected.position + _selected.size * 0.5) / safe_area.size,
		"scale": _selected.size.x / _defaults[_selected.name].size.x
	}
	_config.set_value(_orientation, "layout", _layout.duplicate(true))

func _resize_selected(value: float) -> void:
	if not is_instance_valid(_selected):
		return
	var center := _selected.position + _selected.size * 0.5
	_selected.size = _defaults[_selected.name].size * value
	_selected.position = _clamp_position(center - _selected.size * 0.5, _selected.size)
	_remember_selected()
	update_feedback(Vector2.ZERO, false, false, false, false)

func reset_layout() -> void:
	source.clear_input()
	_layout.clear()
	_config.set_value(_orientation, "layout", {})
	for control: Control in controls.get_children():
		_restore_control(control)
		control.modulate = Color.WHITE
	_selected = null
	selected_label.text = "أُعيد التخطيط الأصلي لهذا الاتجاه"
	update_feedback(Vector2.ZERO, false, false, false, false)
