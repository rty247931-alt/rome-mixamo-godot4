extends Node3D

## City source FBX contains UVs and material groups, but its texture links
## are missing. Reconnect the supplied texture atlases at runtime.
@export var generate_city_collisions: bool = true
@export var collision_layer: int = 1

const CITY_ATLAS: Texture2D = preload("res://city/textures/CombinedAllTexturesShadowed.jpg")
const FIGURES_ATLAS: Texture2D = preload("res://city/textures/attachmeentsHalfSize.jpg")

func _ready() -> void:
    var city := get_node_or_null("City")
    if city:
        _apply_city_textures(city)
        if generate_city_collisions:
            _add_collisions(city)

func _apply_city_textures(root: Node) -> void:
    for child in root.get_children():
        if child is MeshInstance3D and child.mesh:
            var mesh: Mesh = child.mesh
            for surface_index in range(mesh.get_surface_count()):
                var source_material := mesh.surface_get_material(surface_index)
                var material_name := ""
                if source_material:
                    material_name = source_material.resource_name.to_lower()
                var node_name := child.name.to_lower()

                var material := StandardMaterial3D.new()
                material.roughness = 0.9
                material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

                if material_name.contains("fire") or node_name.contains("fire"):
                    material.albedo_color = Color(1.0, 0.28, 0.06, 1.0)
                    material.emission_enabled = true
                    material.emission = Color(1.0, 0.12, 0.015, 1.0)
                    material.emission_energy_multiplier = 1.4
                elif material_name.contains("attachment") or node_name.contains("small figures"):
                    material.albedo_texture = FIGURES_ATLAS
                    child.set_surface_override_material(surface_index, material)
                else:
                    # Main city and trees share the large combined UV atlas.
                    material.albedo_texture = CITY_ATLAS
                    child.set_surface_override_material(surface_index, material)

        _apply_city_textures(child)

func _add_collisions(root: Node) -> void:
    for child in root.get_children():
        if child is MeshInstance3D and child.mesh and child.mesh.get_surface_count() > 0:
            var faces: PackedVector3Array = child.mesh.get_faces()
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
