tool

extends Spatial

const MeshUtils = preload("utils/mesh_utils.gd")
const MapBaker = preload("map_baker.gd")
const SceneBaker = preload("scene_baker.gd")
const Exporter = preload("../../scenes/exporter.tscn")
const ProfileResource = preload("../profile_resource.gd")

const MultiBakeScene = preload("../../scenes/multi_bake_scene.tscn")

export(NodePath) onready var baking_viewport = get_node(baking_viewport) as Viewport
export(NodePath) onready var baking_postprocess_plane = get_node(baking_postprocess_plane) as MeshInstance
export(NodePath) onready var texture_preview = get_node(texture_preview) as TextureRect


var frames_xy := 12
var is_full_sphere := false
var plugin: EditorPlugin = null
var profile: ProfileResource = preload("res://addons/octahedral_impostors/profiles/standard.tres")

onready var exporter = $Exporter
onready var dilatation_pipeline = $DilatatePipeline

var scene_baker: SceneBaker
var scene_materials_cache := {}

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
	exporter.export_path = "res://tests/"
	exporter.frames_xy = frames_xy
	exporter.is_full_sphere = is_full_sphere
	exporter.plugin = plugin
	# only for testing purposes
	var test_scene = load("res://assets/monkey/monkey.tscn").instance()
	scene_baker.frames_xy = frames_xy
	scene_baker.is_full_sphere = is_full_sphere
	baking_viewport.add_child(scene_baker)
	add_child(test_scene)
	print("Preparing scene to bake", test_scene)
	prepare_scene_to_bake(test_scene)

	#bake main map
	print("Baking main map: ", profile.map_baker_with_alpha_mask)
	yield(bake_map(profile.map_baker_with_alpha_mask.new(), test_scene, baking_viewport, baking_postprocess_plane.mesh), "completed")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")

	for mapbaker in profile.standard_map_bakers:
		print("Baking: ", mapbaker)
		yield(bake_map(mapbaker.new(), test_scene, baking_viewport, baking_postprocess_plane.mesh), "completed")
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
	
	print("Exporting...")
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = profile.main_shader
	exporter.scale_instance = scene_baker.get_camera().size / 2.0
	exporter.export_scene(shader_mat, false)
	remove_child(test_scene)
	print("Exporting impostor done.")
