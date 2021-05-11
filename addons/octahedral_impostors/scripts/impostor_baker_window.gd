tool
extends WindowDialog

var plugin: EditorPlugin

func set_scene_to_bake(node: Spatial) -> void:
	pass


func _process(_delta):
	pass


func _on_Generate_pressed():
	$BakerScript.plugin = plugin
	$BakerScript.bake()


func _on_SpinBox_value_changed(value: float):
	pass


func _on_CheckboxFullSphere_toggled(state: bool):
	pass


func _on_SpinBoxGridSize_value_changed(value: float):
	pass


func _on_OptionButtonShaderType_item_selected(shader_type_p: int):
	pass


func _on_CheckBoxPackedScene_toggled(state: bool):
	pass


func _on_OptionButtonImgRes_item_selected(new_dimm: int):
	pass


func _on_FileDialog_file_selected(path: String) -> void:
	pass


func _on_ImpostorBaker_popup_hide() -> void:
	pass


func _on_CheckBoxHalfResolution_toggled(state: bool):
	pass