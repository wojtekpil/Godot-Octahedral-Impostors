extends EditorInspectorPlugin

const ProfileProperty = preload("octa_impostor_profile_property.gd")


func can_handle(object: Object) -> bool:
	return object is OctaImpostor


func parse_property(object: Object, type: int, path: String, hint: int, hint_text: String, usage: int) -> bool:
	var ob_imp: OctaImpostor = object as OctaImpostor
	if path == "profile":
		add_property_editor(path, ProfileProperty.new())
		return true
	return false
