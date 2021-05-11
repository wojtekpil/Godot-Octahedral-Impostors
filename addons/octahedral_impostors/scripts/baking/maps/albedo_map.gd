tool

# extends OctahedralImpostorMapBaker
extends "../map_baker.gd"

func get_name() -> String:
    return "albedo"


func is_dilatated() -> bool:
    return true


func use_as_dilatate_mask() -> bool:
    return true


func map_bake(org_material: Material) -> Material:
    return org_material