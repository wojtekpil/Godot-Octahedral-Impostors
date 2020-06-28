tool
extends EditorPlugin

var button: Button
var converter: WindowDialog
var selected_object: Spatial

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
	
	converter = preload("ImpostorBaker.tscn").instance()
	converter.plugin = self
	get_editor_interface().get_base_control().add_child(converter)


func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, button)
	converter.queue_free()
	button.queue_free()


func _on_Button_pressed() -> void:
	if selected_object:
		converter.popup_centered()
		converter.set_scene_to_bake(selected_object)
