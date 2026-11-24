extends Node3D

## Builds static trimesh collision for imported city meshes at runtime.
## Large architectural scenes may take a short moment to initialize.
@export var generate_city_collisions: bool = true
@export var collision_layer: int = 1

func _ready() -> void:
    if generate_city_collisions:
        var city := get_node_or_null("City")
        if city:
            _add_collisions(city)

func _add_collisions(root: Node) -> void:
    for child in root.get_children():
        if child is MeshInstance3D and child.mesh and child.mesh.get_surface_count() > 0:
            var faces := child.mesh.get_faces()
            if faces.size() >= 3:
                var body := StaticBody3D.new()
                body.name = child.name + "_Collision"
                body.collision_layer = collision_layer
                var shape := ConcavePolygonShape3D.new()
                shape.set_faces(faces)
                var collision := CollisionShape3D.new()
                collision.shape = shape
                body.add_child(collision)
                add_child(body)
                body.global_transform = child.global_transform
                body.owner = get_tree().current_scene
        _add_collisions(child)
