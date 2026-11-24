extends Area3D


@onready var surface_level: Marker3D = $SurfaceLevel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.has_node("Components/SwimmingComponent"):
		return

	var swimming_component: Node = body.get_node(
		"Components/SwimmingComponent"
	)

	var surface_y: float = surface_level.global_position.y

	swimming_component.enter_water(surface_y)


func _on_body_exited(body: Node3D) -> void:
	if not body.has_node("Components/SwimmingComponent"):
		return

	var swimming_component: Node = body.get_node(
		"Components/SwimmingComponent"
	)

	swimming_component.exit_water()
