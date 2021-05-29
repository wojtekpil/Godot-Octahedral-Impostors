tool

extends Spatial

const MeshUtils = preload("utils/mesh_utils.gd")
const MapBaker = preload("map_baker.gd")
const SceneBaker = preload("scene_baker.gd")
const Exporter = preload("../../scenes/exporter.tscn")
const ProfileResource = preload("../profile_resource.gd")

const MultiBakeScene = preload("../../scenes/multi_bake_scene.tscn")

const shadow_filename_prefix = "shadow-"

# emitted when bake is done
signal bake_done

var baking_viewport: Viewport
var baking_postprocess_plane: MeshInstance
var texture_preview: TextureRect = null


var frames_xy := 12
var is_full_sphere := false
var create_shadow_mesh := false
var plugin: EditorPlugin = null
var profile: ProfileResource = preload("res://addons/octahedral_impostors/profiles/standard.tres")
var atlas_resolution = 2048
var optimize_atlas_size = false
var atlas_coverage = 1.0
var save_path: String
var generated_impostor: MeshInstance = null
var generated_shadow_impostor: MeshInstance = null

onready var exporter = $Exporter
onready var dilatation_pipeline = $DilatatePipeline

var scene_baker: SceneBaker
var scene_materials_cache := {}
var scene_to_bake: Spatial = null

func prepare_scene_to_bake(scene: Spatial):
	MeshUtils.create_materials_cache(scene, scene_materials_cache)


func map_baker_process_materials(map_baker: MapBaker, scene: Spatial) -> void:
	if scene is MeshInstance:
		var mats: int = scene.get_surface_material_count()
		for m in mats:
			var original_mat = MeshUtils.get_material_cached(scene, m, scene_materials_cache)
			var map_to_bake_mat = map_baker.map_bake(original_mat)
			scene.set_surface_material(m, map_to_bake_mat)
	for child in scene.get_children():
		map_baker_process_materials(map_baker, child)


func postprocess_plane_cleanup() -> void:
	baking_postprocess_plane.visible = false
	baking_postprocess_plane.mesh.surface_set_material(0, null)


func preview_map(atlas_image: Image):
	var tex: ImageTexture = ImageTexture.new()
	tex.flags = 0
	tex.create_from_image(atlas_image)
	if texture_preview != null:
		texture_preview.texture = tex


func bake_map(map_baker: MapBaker, scene: Spatial, vp: Viewport, postprocess: Mesh) -> void:
	vp.keep_3d_linear = not map_baker.is_srgb() or map_baker.is_normalmap()
	map_baker.viewport_setup(vp)
	if map_baker.setup_postprocess_plane(postprocess, scene_baker.get_camera()):
		baking_postprocess_plane.visible = true
	map_baker_process_materials(map_baker, scene)
	scene_baker.set_scene_to_bake(scene)
	yield(scene_baker, "atlas_ready")
	var result_image = scene_baker.atlas_image
	if map_baker.is_dilatated():
		yield(dilatation_pipeline.dilatate(result_image, map_baker.use_as_dilatate_mask()), "completed")
		result_image = dilatation_pipeline.processed_image
	exporter.save_map(map_baker, result_image)
	preview_map(result_image)
	map_baker.viewport_cleanup(vp)
	scene_baker.cleanup()
	postprocess_plane_cleanup()


func setup_bake_resolution(scene_baker: SceneBaker, map_baker: MapBaker) -> void:
	var resolution = atlas_resolution
	if optimize_atlas_size:
		resolution = map_baker.recommended_scale_divider(atlas_resolution)
	scene_baker.atlas_resolution = resolution
	baking_viewport.size = Vector2(resolution, resolution)


func bake():
	print("Baking using profile: ", profile.name)
	scene_baker = MultiBakeScene.instance()
	exporter.export_path = save_path.get_base_dir()
	exporter.packedscene_filename = save_path.get_file()
	exporter.frames_xy = frames_xy
	exporter.is_full_sphere = is_full_sphere
	exporter.plugin = plugin
	scene_baker.atlas_coverage  =atlas_coverage
	scene_baker.frames_xy = frames_xy
	scene_baker.is_full_sphere = is_full_sphere
	baking_viewport.add_child(scene_baker)
	add_child(scene_to_bake)
	print("Preparing scene to bake", scene_to_bake)
	prepare_scene_to_bake(scene_to_bake)

	#bake main map
	var map_baker = profile.map_baker_with_alpha_mask.new()
	print("Baking main map: ", map_baker.get_name())
	setup_bake_resolution(scene_baker, map_baker)
	yield(bake_map(map_baker, scene_to_bake, baking_viewport, baking_postprocess_plane.mesh), "completed")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")

	for mapbaker in profile.standard_map_bakers:
		map_baker = mapbaker.new()
		print("Baking: ", map_baker.get_name())
		setup_bake_resolution(scene_baker, map_baker)
		yield(bake_map(map_baker, scene_to_bake, baking_viewport, baking_postprocess_plane.mesh), "completed")
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
	
	print("Exporting...")
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = profile.main_shader
	exporter.scale_instance = scene_baker.get_camera().size / 2.0
	var shader_shadow_mat: ShaderMaterial = null
	if create_shadow_mesh and profile.shadows_shader != null:
		shader_shadow_mat = ShaderMaterial.new()
		shader_shadow_mat.shader = profile.shadows_shader
	yield(exporter.export_scene(shader_mat, false, shader_shadow_mat), "completed")
	generated_impostor = exporter.generated_impostor
	generated_shadow_impostor = exporter.generated_shadow_impostor

	remove_child(scene_to_bake)
	print("Exporting impostor done.")
	emit_signal("bake_done")


func make_nodes_visible(node: Spatial) -> void:
	if node.has_method("set_visible"):
		node.visible = true
		print("Make node: ", node.name, " visible")
	for child in node.get_children():
		make_nodes_visible(child)


func set_scene_to_bake(node: Spatial, all_child_visible = false) -> void:
	scene_to_bake = node.duplicate()
	scene_to_bake.set_physics_process(false)
	scene_to_bake.set_process(false)
	scene_to_bake.translation = Vector3()
	scene_to_bake.rotation = Vector3()
	if all_child_visible:
		make_nodes_visible(scene_to_bake)
