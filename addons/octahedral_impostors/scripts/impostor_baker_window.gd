tool
extends WindowDialog

const ProfileResource = preload("profile_resource.gd")
const FileUtils = preload("baking/utils/file_utils.gd")

const ProfilesDir = "res://addons/octahedral_impostors/profiles/"

var plugin: EditorPlugin

onready var baker = $BakerScript

onready var profile_option_button: OptionButton = $MainContainer/Panel/container/HBoxContainer5/OptionButtonProfile

func read_baking_profiles(profile_button: OptionButton) -> Array:
	profile_button.clear()
	var profiles: Array = FileUtils.get_resources_in_dir(ProfilesDir)
	var profile_id = 0
	for prof in profiles:
		if prof is ProfileResource:
			profile_button.add_item(prof.name, profile_id)
			profile_button.set_item_metadata(profile_id, prof)
			profile_id += 1
	return profiles


func set_scene_to_bake(node: Spatial) -> void:
	baker.set_scene_to_bake(node)


func _ready():
	baker.plugin = plugin
	baker.baking_viewport = $ViewportBaking
	baker.baking_postprocess_plane = $ViewportBaking/PostProcess
	baker.texture_preview = $MainContainer/TextureRect
	read_baking_profiles(profile_option_button)
	baker.profile = profile_option_button.get_selected_metadata()

func _process(_delta):
	pass


func _on_Generate_pressed():
	$FileDialog.popup_centered()


func _on_SpinBox_value_changed(value: float):
	baker.atlas_coverage = value/100.0


func _on_CheckboxFullSphere_toggled(state: bool):
	baker.is_full_sphere = state


func _on_SpinBoxGridSize_value_changed(value: float):
	baker.frames_xy = int(value)


func _on_OptionButtonProfile_item_selected(profile_idx: int):
	baker.profile = profile_option_button.get_item_metadata(profile_idx)


func _on_CheckBoxShadow_toggled(state: bool):
	baker.create_shadow_mesh = state


func _on_OptionButtonImgRes_item_selected(new_dimm: int):
	var multiplier: int = pow(2, new_dimm)
	baker.atlas_resolution = 1024 * multiplier


func _on_FileDialog_file_selected(path: String) -> void:
	baker.save_path = path
	baker.bake()


func _on_ImpostorBaker_popup_hide() -> void:
	pass


func _on_CheckBoxHalfResolution_toggled(state: bool):
	pass