tool

# extends OctahedralImpostorMapBaker
extends "../map_baker.gd"

var normal_material = preload("../../../materials/normal_baker.material")

func get_name() -> String:
	return "normal"


func is_normalmap() -> bool:
	return true


func is_dilatated() -> bool:
	return true


func image_format() -> int:
	return Image.FORMAT_RGH


func _cleanup_baking_material(material: Material) -> void:
	material.set_shader_param("texture_albedo", null)
	material.set_shader_param("normal_texture", null)
	material.set_shader_param("alpha_scissor_threshold", 0.0)
	material.set_shader_param("normal_scale", 0.0)
	material.set_shader_param("use_normalmap", false)
	material.set_shader_param("use_alpha_texture", false)


func _mimic_original_spatial_material(original_mat: SpatialMaterial, material: Material) -> void:
	if original_mat.normal_enabled:
		material.set_shader_param("normal_texture", original_mat.normal_texture)
		material.set_shader_param("use_normalmap", true)
		material.set_shader_param("normal_scale", original_mat.normal_scale)
	if original_mat.params_use_alpha_scissor:
		material.set_shader_param("use_alpha_texture", true)
		material.set_shader_param("alpha_scissor_threshold", original_mat.params_alpha_scissor_threshold)
		material.set_shader_param("texture_albedo", original_mat.albedo_texture)


func _mimic_original_shader_material(original_mat: ShaderMaterial, material: Material) -> void:
	# TODO ADD NORMAL TEXTURE, ORM
	var alpha_scissors = original_mat.get_shader_param("alpha_scissor_threshold")
	var albedo_tex = original_mat.get_shader_param("texture_albedo")
	if float(alpha_scissors) > 0.0 and albedo_tex != null:
		material.set_shader_param("use_alpha_texture", true)
		material.set_shader_param("texture_albedo", albedo_tex)
		material.set_shader_param("alpha_scissor_threshold", alpha_scissors)
	else:
		print("Alpha texture not recognized")


func map_bake(org_material: Material) -> Material:
	_cleanup_baking_material(normal_material)
	if org_material is SpatialMaterial:
		_mimic_original_spatial_material(org_material, normal_material)
	elif org_material is ShaderMaterial:
		_mimic_original_shader_material(org_material, normal_material)
	else:
		print("Unrecognized material during normal baking")
	return normal_material
