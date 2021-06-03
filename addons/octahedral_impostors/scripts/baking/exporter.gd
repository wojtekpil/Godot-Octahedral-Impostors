tool

extends Spatial

const MapBaker = preload("map_baker.gd")

var plugin: EditorPlugin = null
var export_path := "res://"
var frames_xy := 12
var is_full_sphere := false
var scale_instance := 1.0
var position_offset := Vector3.ZERO
var packedscene_filename := "impostor.tscn"

var saved_maps := {}
var generated_impostor: MeshInstance = null
var generated_shadow_impostor: MeshInstance = null

func rescan_filesystem():
	var plugin_filesystem = plugin.get_editor_interface().get_resource_filesystem()
	plugin_filesystem.scan()
	print("Scanning filesystem...")
	yield(get_tree(), "idle_frame")
	while plugin_filesystem.is_scanning():
		yield(get_tree(), "idle_frame")
		if not is_inside_tree():
			print("Not inside a tree...")
			return


func save_map(map_baker: MapBaker, atlas_image: Image):
	var dir = Directory.new()
	var save_path = export_path.plus_file("result_" + map_baker.get_name() + ".png")
	print("Saving image in ", save_path)
	atlas_image.convert(map_baker.image_format())
	#remove old file if exists
	if dir.file_exists(save_path):
		dir.remove(save_path)
		yield(rescan_filesystem(), "completed")
	atlas_image.save_png(save_path)
	saved_maps[map_baker.get_name()] = save_path


func all_resource_exists() -> bool:
	for x in saved_maps:
		if not ResourceLoader.exists(saved_maps[x]):
			return false
	return true


func wait_for_correct_load_texture(path: String) -> void:
	var texture = null
	while texture == null:
		texture = load(path)
		yield(get_tree(), "idle_frame")


func wait_on_resources() -> void:
	# TODO: check if texture type is correct
	
	yield(rescan_filesystem(), "completed")
	# according to Zyllans comment in his heightmap plugin importing takes place
	# after scanning so we need to yield some more...
	print("Waiting for import to finish...")
	for counter in saved_maps.size() * 2.0:
		yield(get_tree(), "idle_frame")

	# wait until the images have all been (re)imported.
	print("Waiting for resources on disk...")
	while not all_resource_exists():
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")

	print("Resource should now exists...")
	for counter in saved_maps.size() * 2.0:
		yield(get_tree(), "idle_frame")
	
	#not sure if needed
	print("Waiting for correct texture loading")
	for x in saved_maps:
		yield(wait_for_correct_load_texture(saved_maps[x]), "completed")


func export_scene(mat: Material, texture_array: bool = false, shadow_mat: Material = null) -> Spatial:
	# TODO: textureArray workaround
	if plugin == null:
		print("Cannot export outside plugin system")
		return null

	var root: Spatial = Spatial.new()
	var mi: MeshInstance = MeshInstance.new()
	var mi_shadow: MeshInstance = MeshInstance.new()
	
	yield(wait_on_resources(), "completed")
	print("Creating material...")
	mat.set_shader_param("imposterFrames", Vector2(frames_xy, frames_xy))
	mat.set_shader_param("isFullSphere", is_full_sphere)
	mat.set_shader_param("aabb_max", scale_instance/2.0)
	mat.set_shader_param("scale", scale_instance)
	mat.set_shader_param("positionOffset", position_offset)

	if shadow_mat != null:
		print("Creating shadow material...")
		shadow_mat.set_shader_param("imposterFrames", Vector2(frames_xy, frames_xy))
		shadow_mat.set_shader_param("isFullSphere", is_full_sphere)
		shadow_mat.set_shader_param("aabb_max", -scale_instance/2.0)
		shadow_mat.set_shader_param("scale", scale_instance)
		shadow_mat.set_shader_param("positionOffset", position_offset)
		mi_shadow.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	print("Loading resources...")
	for x in saved_maps:
		var texture = load(saved_maps[x])
		mat.set_shader_param("imposterTexture" + x.capitalize(), texture)
		if shadow_mat != null:
			shadow_mat.set_shader_param("imposterTexture" + x.capitalize(), texture)

	var quad_mesh: QuadMesh = QuadMesh.new()
	root.add_child(mi)
	root.name = "Impostor"
	mi.owner = root
	mi.name = "mesh-impostor"
	mi.mesh = quad_mesh
	mi.mesh.surface_set_material(0, mat)
	if shadow_mat != null:
		root.add_child(mi_shadow)
		mi_shadow.owner = root
		mi_shadow.mesh = quad_mesh.duplicate()
		mi_shadow.name = "shadow-impostor"
		mi_shadow.mesh.surface_set_material(0, shadow_mat)

	var packed_scene: PackedScene = PackedScene.new()
	packed_scene.pack(root)
	var err = ResourceSaver.save(export_path.plus_file(packedscene_filename), packed_scene)
	if err != OK:
		print("Error while exporting to path: ", export_path.plus_file(packedscene_filename))
		print("Failure! CODE =", err)
		return null
	else:
		print("Imposter ready!")
	generated_impostor = mi
	generated_shadow_impostor = mi_shadow
	return root
