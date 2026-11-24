extends Node
@export var interaction_distance: float = 3.0
@export var default_text: String = "اضغط زر تفاعل"
@onready var player: CharacterBody3D = owner.get_parent()
@onready var interaction_ray: RayCast3D = owner.get_node("Head/Camera3D/InteractionRay")
@onready var camera: Camera3D = interaction_ray.get_parent()
@onready var interaction_ui: Control = owner.get_node("UI/InteractionUI")
@onready var interaction_label: Label = owner.get_node("UI/InteractionUI/InteractionLabel")
var current_target: Node = null

func _ready() -> void:
	interaction_ray.add_exception(player)
	interaction_ray.collision_mask = 1
	interaction_ui.hide()

func update_interaction() -> void:
	current_target = null
	interaction_ui.hide()
	if not player.controls_enabled:
		return
	var origin: Vector3 = player.global_position + Vector3.UP
	var screen_center: Vector2 = camera.get_viewport().get_visible_rect().size * 0.5
	var ray_origin: Vector3 = camera.project_ray_origin(screen_center)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_center)
	interaction_ray.global_position = ray_origin
	interaction_ray.target_position = interaction_ray.global_basis.inverse() * ray_direction * (ray_origin.distance_to(origin) + interaction_distance)
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return
	var point: Vector3 = interaction_ray.get_collision_point()
	if origin.distance_to(point) > interaction_distance:
		return
	var collider: Object = interaction_ray.get_collider()
	var target: Node = collider as Node
	while target != null and not target.has_method("interact"):
		target = target.get_parent()
	if target == null:
		return
	# A second ray prevents reaching through a wall beside the orbit camera.
	var query := PhysicsRayQueryParameters3D.create(origin, point, 1, [player.get_rid()])
	query.collide_with_areas = true
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider != collider:
		var hit_node: Node = hit.collider as Node
		if hit_node != target and not target.is_ancestor_of(hit_node):
			return
	current_target = target
	interaction_label.text = str(target.call("get_interaction_text")) if target.has_method("get_interaction_text") else default_text
	interaction_ui.show()
	interaction_label.show()

func handle_interaction_input() -> void:
	update_interaction()
	if is_instance_valid(current_target):
		current_target.call("interact", player)
