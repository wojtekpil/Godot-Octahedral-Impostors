tool
extends EditorPlugin

const tool_menu_text = "Scene Octahedral Impostors Baker..."

var button: Button
var converter: WindowDialog
var selected_object: Spatial
var batch_converter: WindowDialog
var octa_impostor_editor_inspector: EditorInspectorPlugin

# Handles objects that are either geometry instances or have such children.
# CSG objects don't have a proper bounding box, so they can't be used.
func handles(object: Object) -> bool:
	var handles := false

	if object is Spatial:
		if object is GeometryInstance and not (object is CSGShape):
			handles = true
		else:
			for child in object.get_children():
				if handles(child):
					handles = true
					break

	button.visible = handles
	return handles


func edit(object: Object) -> void:
	selected_object = object


func _enter_tree() -> void:
	button = Button.new()
	button.flat = true
	button.text = "Convert to Impostor"
	button.hide()
	button.connect("pressed", self, "_on_Button_pressed")
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, button)
	
	converter = preload("ImpostorBakerWindow.tscn").instance()
	converter.plugin = self
	get_editor_interface().get_base_control().add_child(converter)

	batch_converter =  preload("ImpostorQueueWindow.tscn").instance()
	batch_converter.plugin = self
	get_editor_interface().get_base_control().add_child(batch_converter)
	add_tool_menu_item(tool_menu_text, self, "batch_baking")

	octa_impostor_editor_inspector = preload("scripts/octa_impostor_editor_inspector_plugin.gd").new()
	add_inspector_plugin(octa_impostor_editor_inspector)


func _exit_tree() -> void:
	remove_inspector_plugin(octa_impostor_editor_inspector)
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, button)
	converter.queue_free()
	button.queue_free()
	remove_tool_menu_item(tool_menu_text)
	batch_converter.free()


func _on_Button_pressed() -> void:
	if selected_object:
		converter.popup_centered()
		converter.set_scene_to_bake(selected_object)


func batch_baking(ud): 
	batch_converter.popup_centered()
	batch_converter.set_scene_to_bake(null)


func update_all_octaimpostor_lod_nodes(node, camera):
	if node == null:
		return
	if node is OctaImpostor:
		node.editor_camera = camera
	for child in node.get_children():
		update_all_octaimpostor_lod_nodes(child, camera)


func forward_spatial_gui_input(camera, event):
	update_all_octaimpostor_lod_nodes(get_tree().get_edited_scene_root(), camera)
	return false
