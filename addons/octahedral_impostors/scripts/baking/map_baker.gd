tool

func get_name() -> String:
    return "unknown"


func is_srgb() -> bool:
    return true


func is_normalmap() -> bool:
    return false


func is_dilatated() -> bool:
    return false


func use_as_dilatate_mask() -> bool:
    return false


func image_format() -> int:
    return Image.FORMAT_RGBA8


func recommended_scale_divider(image_dimmension: Vector2) -> Vector2:
    return image_dimmension


func viewport_setup(viewport: Viewport) -> void:
    pass


func viewport_cleanup(viewport: Viewport) -> void:
    pass


func setup_postprocess_plane(plane: Mesh, camera: Camera) -> bool:
    return false


func map_bake(org_material: Material) -> Material:
    return org_material