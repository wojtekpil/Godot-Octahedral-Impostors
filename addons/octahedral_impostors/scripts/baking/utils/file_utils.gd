static func get_by_ext_in_dir(path: String, extension: String = "tres") -> Array:
	var result = []
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() && file_name.get_extension() == extension:
				result.append(path.plus_file(file_name))
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path: ", path)
	return result


static func get_resources_in_dir(path: String) -> Array:
	var result = []
	var files = get_by_ext_in_dir(path)
	for res in files:
		result.append(load(res))
	return result


static func dir_is_empty(path: String) -> bool:
	var dir = Directory.new()
	if dir.open(path) != OK:
		print("Directory ", path, " doesn't exists.")
		return false
	dir.list_dir_begin(true)
	var file_name = dir.get_next()
	if file_name != "":
		print("Directory ", path, " is not empty.")
		return false
	return true