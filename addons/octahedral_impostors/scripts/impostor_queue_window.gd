extends Control

const ProfileResource = preload("profile_resource.gd")

const FileUtils = preload("baking/utils/file_utils.gd")

const ProfilesDir = "res://addons/octahedral_impostors/profiles/"

const icon_checkbox_checked := preload("res://addons/octahedral_impostors/icons/checkbox_checked.svg")
const icon_checkbox_unchecked := preload("res://addons/octahedral_impostors/icons/checkbox_unchecked.svg")

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var queue_tree: Tree = $VBoxContainer/TabContainer/QueuedScenes/Panel/QueuedScenes
onready var profile_option_button: OptionButton = $VBoxContainer/TabContainer/Settings/GridContainer/ProfileOptionButton


func read_baking_profiles(profile_button: OptionButton) -> Array:
	var profiles: Array = FileUtils.get_resources_in_dir(ProfilesDir)
	var profile_id = 0
	for prof in profiles:
		if prof is ProfileResource:
			profile_button.add_item(prof.name)
	return profiles

# Called when the node enters the scene tree for the first time.
func _ready():
	read_baking_profiles(profile_option_button)

	var root = queue_tree.create_item()
	queue_tree.set_hide_root(true)
	var child1 = queue_tree.create_item(root)
	child1.set_text(0, "Scene Name1")
	var child2 = queue_tree.create_item(root)
	child2.set_text(0, "Scene Name2")
	var subchild1 = queue_tree.create_item(child1)
	subchild1.set_text(0, "Subchild1")
	subchild1.add_button(0, icon_checkbox_checked, 0)
	var subchild2 = queue_tree.create_item(child1)
	subchild2.set_text(0, "Subchild2")
	subchild2.add_button(0, icon_checkbox_checked, 1)


func _on_QueuedScenes_button_pressed(item: TreeItem , column: int, id: int) -> void:
	print("Item: ", item, " column: ", column, " id: ", id)
	if item.get_button(column, 0) == icon_checkbox_checked:
		item.set_button(column, 0, icon_checkbox_unchecked)
	else:
		item.set_button(column, 0, icon_checkbox_checked)
