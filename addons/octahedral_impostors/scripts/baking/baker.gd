tool

extends Spatial

const MeshUtils = preload("utils/mesh_utils.gd")
const MapBaker = preload("map_baker.gd")
const SceneBaker = preload("scene_baker.gd")
const Exporter = preload("../../scenes/exporter.tscn")
const ProfileResource = preload("../profile_resource.gd")

const MultiBakeScene = preload("../../scenes/multi_bake_scene.tscn")

# emitted when bake is done
signal bake_done

var baking_viewport: Viewport
var baking_postprocess_plane: MeshInstance
var texture_preview: TextureRect = null


var frames_xy := 12
var is_full_sphere := false
var plugin: EditorPlugin = null
var profile: ProfileResource = preload("res://addons/octahedral_impostors/profiles/standard.tres")
var atlas_resolution = 2048
var atlas_coverage = 1.0
var save_path: String

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
	vp.keep_3d_linear = not map_baker.is_srgb()
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


func bake():
	print("Baking using profile: ", profile.name)
	scene_baker = MultiBakeScene.instance()
	exporter.export_path = save_path.get_base_dir()
	exporter.packedscene_filename = save_path.get_file()
	exporter.frames_xy = frames_xy
	exporter.is_full_sphere = is_full_sphere
	exporter.plugin = plugin

	scene_baker.atlas_resolution = atlas_resolution
	baking_viewport.size = Vector2(atlas_resolution, atlas_resolution)
	scene_baker.atlas_coverage  =atlas_coverage
	scene_baker.frames_xy = frames_xy
	scene_baker.is_full_sphere = is_full_sphere
	baking_viewport.add_child(scene_baker)
	add_child(scene_to_bake)
	print("Preparing scene to bake", scene_to_bake)
	prepare_scene_to_bake(scene_to_bake)

	#bake main map
	print("Baking main map: ", profile.map_baker_with_alpha_mask)
	yield(bake_map(profile.map_baker_with_alpha_mask.new(), scene_to_bake, baking_viewport, baking_postprocess_plane.mesh), "completed")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")

	for mapbaker in profile.standard_map_bakers:
		print("Baking: ", mapbaker)
		yield(bake_map(mapbaker.new(), scene_to_bake, baking_viewport, baking_postprocess_plane.mesh), "completed")
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
	
	print("Exporting...")
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = profile.main_shader
	exporter.scale_instance = scene_baker.get_camera().size / 2.0
	yield(exporter.export_scene(shader_mat, false), "completed")
	remove_child(scene_to_bake)
	print("Exporting impostor done.")
	emit_signal("bake_done")


func set_scene_to_bake(node: Spatial) -> void:
	scene_to_bake = node.duplicate()
	scene_to_bake.translation = Vector3()
	scene_to_bake.rotation = Vector3()