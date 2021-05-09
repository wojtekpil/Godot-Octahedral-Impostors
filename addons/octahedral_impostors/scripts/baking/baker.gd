
extends Spatial

const MeshUtils = preload("utils/mesh_utils.gd")
const MapBaker = preload("map_baker.gd")
const SceneBaker = preload("scene_baker.gd")

const MultiBakeScene = preload("../../scenes/multi_bake_scene.tscn")


var map_bakers := [
	preload("maps/albedo_map.gd"),
	preload("maps/normalmap_map.gd"),
	preload("maps/depth_map.gd")
]

var frames_xy := 8

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
	$Viewport/PostProcess.visible = false
	$Viewport/PostProcess.mesh.surface_set_material(0, null)


func save_map(map_baker: MapBaker, atlas_image: Image):
	atlas_image.convert(map_baker.image_format())
	atlas_image.save_png("res://result_ " + map_baker.get_name() + ".png")
	var tex: ImageTexture = ImageTexture.new()
	tex.flags = 0
	tex.create_from_image(atlas_image)
	$Control/TextureRect.texture = tex


func bake_map(map_baker: MapBaker, scene: Spatial, vp: Viewport, postprocess: Mesh) -> void:
	map_baker.viewport_setup(vp)
	if map_baker.setup_postprocess_plane(postprocess, scene_baker.get_camera()):
		$Viewport/PostProcess.visible = true
	map_baker_process_materials(map_baker, scene)
	scene_baker.set_scene_to_bake(scene)
	yield(scene_baker, "atlas_ready")
	save_map(map_baker, scene_baker.atlas_image)
	map_baker.viewport_cleanup(vp)
	scene_baker.cleanup()
	postprocess_plane_cleanup()


func _ready():
	scene_baker = MultiBakeScene.instance()
	# only for testing purposes
	var test_scene = load("res://assets/monkey/monkey.tscn").instance()
	scene_baker.frames_xy = frames_xy
	$Viewport.add_child(scene_baker)
	add_child(test_scene)
	prepare_scene_to_bake(test_scene)
	for mapbaker in map_bakers:
		yield(bake_map(mapbaker.new(), test_scene, $Viewport, $Viewport/PostProcess.mesh), "completed")
	remove_child(test_scene)
