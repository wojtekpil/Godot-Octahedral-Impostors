tool

static func _create_node_mat_cache(node: Spatial, materials_cache: Dictionary) -> void:
	var np := String(node.get_path())
	if node.mesh == null:
		print("MeshInstance without mesh: ", np)
		return
	var mats: int = node.mesh.get_surface_count()
	var mats_node: int = node.get_surface_material_count()
	if mats != mats_node:
		print("Materials count in MeshInstance and Mesh differs!", np)
		return
	var arr = []
	arr.resize(mats)
	for m in mats:
		arr[m] = node.get_surface_material(m)
		if arr[m] == null:
			arr[m] = node.mesh.surface_get_material(m)
	materials_cache[node.get_instance()] = arr


static func create_materials_cache(node: Spatial, materials_cache: Dictionary) -> void:
	if node is MeshInstance:
		_create_node_mat_cache(node, materials_cache)
	for child in node.get_children():
		create_materials_cache(child, materials_cache)


static func get_material_cached(node: Spatial, surface: int, materials_cache: Dictionary):
	var np := String(node.get_path())
	var r_id: RID = node.get_instance()
	if not materials_cache.has(r_id):
		print("Warning no material is cached for node: ", np)
		return null
	var node_cache = materials_cache.get(r_id)
	if node_cache.size() < surface:
		print("Warning no surface ", surface, " for material: ", np)
		return null
	return node_cache[surface]
