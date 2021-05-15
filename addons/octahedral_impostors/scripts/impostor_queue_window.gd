tool

extends Control

const ProfileResource = preload("profile_resource.gd")
const FileUtils = preload("baking/utils/file_utils.gd")
const OctaImpostorIcon = preload("../icons/icon_octaimpostor.svg")
const ProfilesDir = "res://addons/octahedral_impostors/profiles/"

const icon_checkbox_checked := preload("res://addons/octahedral_impostors/icons/checkbox_checked.svg")
const icon_checkbox_unchecked := preload("res://addons/octahedral_impostors/icons/checkbox_unchecked.svg")

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var queue_tree: Tree = $VBoxContainer/TabContainer/QueuedScenes/Panel/QueuedScenes
onready var profile_option_button: OptionButton = $VBoxContainer/TabContainer/Settings/GridContainer/ProfileOptionButton
onready var directory_save_dialog :FileDialog = $DirectorySelectDialog
onready var directory_path_edit :LineEdit = $VBoxContainer/TabContainer/Settings/HBoxContainer/DirectoryPathEdit
onready var info_dialog : AcceptDialog = $InfoDialog
onready var baker = $BakerScript

var plugin: EditorPlugin
var octa_imp_items := []


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



func get_all_octaimpostor_nodes_in_scene(node: Node) -> Array:
	var result := []
	if node is OctaImpostor:
		result.append(node)
	for child in node.get_children():
		result += get_all_octaimpostor_nodes_in_scene(child)
	return result


func get_selected_octaimpostor_nodes() -> Array:
	var result := []
	for item in octa_imp_items:
		var tex = item.get_button(0,0)
		if tex == icon_checkbox_checked:
			result.append(item.get_metadata(0))
	return result


func set_scene_to_bake(_node: Spatial) -> void:
	baker.plugin = plugin
	baker.baking_viewport = $ViewportBaking
	baker.baking_postprocess_plane = $ViewportBaking/PostProcess
	read_baking_profiles(profile_option_button)
	var scene_root: Node = get_tree().get_edited_scene_root()
	if scene_root == null:
		scene_root = Spatial.new() # just to ommit error in console
	var imp_nodes := get_all_octaimpostor_nodes_in_scene(scene_root)
	print(imp_nodes)

	queue_tree.clear()

	var root = queue_tree.create_item()
	queue_tree.set_hide_root(true)
	var scene_root_tree = queue_tree.create_item(root)
	scene_root_tree.set_text(0, scene_root.name)

	octa_imp_items = []
	for imp in imp_nodes:
		var tree_child = queue_tree.create_item(scene_root_tree)
		var text = String(imp.get_path()).replace(String(scene_root.get_path()), "")
		tree_child.set_text(0, text)
		tree_child.add_button(0, icon_checkbox_checked, 0)
		tree_child.set_metadata(0, imp)
		tree_child.set_icon(0,OctaImpostorIcon)
		octa_imp_items.append(tree_child)


func bake_scene(node: OctaImpostor) -> void:
	var dir = Directory.new()
	var gen_dir = String(node.get_path()).sha256_text()
	var dir_loc =  directory_path_edit.text.plus_file(gen_dir)

	dir.make_dir_recursive(dir_loc)
	baker.save_path = dir_loc.plus_file("impostor.tscn")
	print("Trying to bake:", baker.save_path)
	# TODO: remove all old impostors
	baker.frames_xy = node.frames_xy
	baker.is_full_sphere = node.is_full_sphere
	var multiplier: int = pow(2, node.atlas_resolution)
	baker.atlas_resolution = 1024 * multiplier
	baker.profile = node.profile
	baker.set_scene_to_bake(node)
	yield(baker.bake(), "completed")



func _on_QueuedScenes_button_pressed(item: TreeItem , column: int, id: int) -> void:
	if item.get_button(column, 0) == icon_checkbox_checked:
		item.set_button(column, 0, icon_checkbox_unchecked)
	else:
		item.set_button(column, 0, icon_checkbox_checked)


func _on_GenerateButton_pressed() -> void:
	var imps = get_selected_octaimpostor_nodes()
	if not FileUtils.dir_is_empty(directory_path_edit.text):
		info_dialog.dialog_text = "Save directory must exist and must be empty!"
		info_dialog.popup_centered()
		return
	for x in imps:
		bake_scene(x)
		yield(baker, "bake_done")


func _on_DirectorySelectDialog_dir_selected(dir):
	directory_path_edit.text = dir


func _on_DirectorySelectButton_pressed():
	directory_save_dialog.popup_centered()
