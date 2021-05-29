tool

extends Control

const ProfileResource = preload("profile_resource.gd")
const FileUtils = preload("baking/utils/file_utils.gd")
const OctaImpostorIcon = preload("../icons/icon_octaimpostor.svg")
const ProfilesDir = "res://addons/octahedral_impostors/profiles/"

const icon_checkbox_checked := preload("res://addons/octahedral_impostors/icons/checkbox_checked.svg")
const icon_checkbox_unchecked := preload("res://addons/octahedral_impostors/icons/checkbox_unchecked.svg")

onready var queue_tree: Tree = $VBoxContainer/TabContainer/QueuedScenes/Panel/QueuedScenes

onready var directory_save_dialog: FileDialog = $DirectorySelectDialog
onready var directory_path_edit: LineEdit = $VBoxContainer/TabContainer/Settings/HBoxContainer/DirectoryPathEdit
onready var generate_button: Button = $VBoxContainer/PanelContainer/MarginContainer/GridContainer/HBoxContainer2/GenerateButton
onready var progress_bar: ProgressBar = $VBoxContainer/PanelContainer/MarginContainer/GridContainer/HBoxContainer/ProgressBar
onready var settings_container: Container = $VBoxContainer/TabContainer
onready var info_dialog: AcceptDialog = $InfoDialog
onready var confirm_dialog: ConfirmationDialog = $ConfirmationBakeDialog
onready var baker = $BakerScript

onready var profile_option_button: OptionButton = $VBoxContainer/TabContainer/Settings/GridContainer/ProfileOptionButton
onready var profile_checkbox: CheckBox = $VBoxContainer/TabContainer/Settings/GridContainer/OverwriteProfileCheckbox

onready var resolution_option_button: OptionButton = $VBoxContainer/TabContainer/Settings/GridContainer/ResolutionOptionButton
onready var resolution_checkbox: CheckBox = $VBoxContainer/TabContainer/Settings/GridContainer/OverwriteResolutionCheckbox

var plugin: EditorPlugin
var octa_imp_items := []
var scene_root: Node = null
var impostor_scene_filename := "impostor.tscn"
var prohibited_dirs := ["", "res://", "res://addons", "res://addons/"]
var generated_nodes = ["generated-impostor", "generated-shadow-impostor"]


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
	progress_bar.value = 0
	baker.plugin = plugin
	baker.baking_viewport = $ViewportBaking
	baker.baking_postprocess_plane = $ViewportBaking/PostProcess
	read_baking_profiles(profile_option_button)
	scene_root = get_tree().get_edited_scene_root()
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


func change_disabled_child_controls(node: Node, disabled: bool) -> void:
	if node is Control and node.has_method("set_disabled"):
		node.disabled = disabled
	for child in node.get_children():
		change_disabled_child_controls(child, disabled)


func bake_scene(node: OctaImpostor) -> void:
	var dir = Directory.new()
	var gen_dir = String(node.get_path()).sha256_text()
	var dir_loc = directory_path_edit.text.plus_file(gen_dir)
	var save_file = dir_loc.plus_file(impostor_scene_filename)

	dir.make_dir_recursive(dir_loc)
	if dir.file_exists(save_file):
		dir.remove(save_file)
		plugin.get_editor_interface().get_resource_filesystem().scan()
	baker.save_path = save_file
	print("Trying to bake:", baker.save_path)
	# TODO: remove all old impostors
	baker.frames_xy = node.frames_xy
	baker.create_shadow_mesh = node.create_shadow_mesh
	baker.is_full_sphere = node.is_full_sphere
	baker.optimize_atlas_size = node.optimize_atlas_size
	if profile_checkbox.pressed:
		baker.profile = profile_option_button.get_selected_metadata()
	else:
		baker.profile = node.profile
	var multiplier: int = pow(2, node.atlas_resolution)
	if resolution_checkbox.pressed:
		multiplier = pow(2, resolution_option_button.selected)
	baker.atlas_resolution = 1024 * multiplier
	baker.set_scene_to_bake(node, true)
	yield(baker.bake(), "completed")


func generate() -> void:
	generate_button.disabled = true
	change_disabled_child_controls(settings_container, true)
	var imps := get_selected_octaimpostor_nodes()
	var imps_size := imps.size()
	var imps_counter := 0.0
	for x in imps:
		for child in x.get_children():
			if child.name in generated_nodes:
				x.remove_child(child)
		bake_scene(x)
		yield(baker, "bake_done")
		if baker.generated_impostor != null:
			var local_imp = baker.generated_impostor.duplicate()
			local_imp.name = "generated-impostor"
			x.add_child(local_imp)
			local_imp.owner = scene_root
		else:
			print("Problem generating impostor for: ", x.get_path())
		if x.create_shadow_mesh:
			if baker.generated_shadow_impostor != null:
				var local_shadow_imp = baker.generated_shadow_impostor.duplicate()
				local_shadow_imp.name = "generated-shadow-impostor"
				x.add_child(local_shadow_imp)
				local_shadow_imp.owner = scene_root
			else:
				print("Problem generating shadow impostor for: ", x.get_path())
		imps_counter += 1.0
		progress_bar.value = (imps_counter/imps_size) * 100.0
	generate_button.disabled = false
	change_disabled_child_controls(settings_container, false)


func _on_QueuedScenes_button_pressed(item: TreeItem , column: int, id: int) -> void:
	if item.get_button(column, 0) == icon_checkbox_checked:
		item.set_button(column, 0, icon_checkbox_unchecked)
	else:
		item.set_button(column, 0, icon_checkbox_checked)


func _on_GenerateButton_pressed() -> void:
	var directory = Directory.new();
	var dir_exists: bool = directory.dir_exists(directory_path_edit.text)
	if not dir_exists or directory_path_edit.text in prohibited_dirs:
		info_dialog.dialog_text = "Save directory must exist and must be correct!"
		info_dialog.popup_centered()
		return
	if not FileUtils.dir_is_empty(directory_path_edit.text):
		confirm_dialog.popup_centered()
		return
	generate()


func _on_DirectorySelectDialog_dir_selected(dir):
	directory_path_edit.text = dir


func _on_DirectorySelectButton_pressed():
	directory_save_dialog.popup_centered()


func _on_ConfirmationBakeDialog_confirmed() -> void:
	generate()
