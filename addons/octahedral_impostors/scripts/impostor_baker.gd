tool
extends WindowDialog

enum SHADER_TYPE { LIGHT, STANDARD, TEXTURE_ARRAY }

export (int) var frames_root_number = 16
export (int) var image_dimensions = 4096
export (float) var atlas_coverage = 1.0
export (bool) var is_full_sphere = false
export (bool) var dilatation_postprocess = true
export (SHADER_TYPE) var shader_type = SHADER_TYPE.STANDARD
export (bool) var export_as_packed_scene = true
export (bool) var use_half_resolution_data_maps = false
export (String) var export_path = "res://export_images/"

var plugin: EditorPlugin

var result_image: Image = Image.new()
var result_image_normal: Image = Image.new()
var result_image_depth: Image = Image.new()
var result_image_metallic: Image = Image.new()
var result_image_roughness: Image = Image.new()

var camera_distance: float = 1.0
var rendered_counter: int = 0
var current_frame: Vector2 = Vector2(0, 0)

onready var baking_camera: Camera = $MainContainer/ViewportContainer/ViewportBaking/Camera
onready var progress_bar: ProgressBar = $MainContainer/Panel/container/progress
onready var dilatation_pipeline = $DilatatePipeline
var scene_to_bake: Spatial
var imported_scene_scale: Vector3 = Vector3.ZERO

var normal_material := preload("../materials/normal_baker.material")
var standard_shader := preload("../materials/shaders/ImpostorShader.shader")
var texarr_shader := preload("../materials/shaders/ImpostorShaderTexArr.shader")
var light_shader := preload("../materials/shaders/ImpostorShaderLight.shader")

var save_path: String
var base_filename := "base.png"
var normal_filename := "norm.png"
var depth_alpha_filename := "depth_alpha.png"
var orm_filename := "orm.png"
var packedscene_filename := "imposter.tscn"

enum BAKER_STATE {
	INIT,
	CAMERA_PLACEMENT,
	NOP,
	METALLIC_VIEW,
	SCREENSHOT_METALLIC,
	ROUGHNESS_VIEW,
	SCREENSHOT_ROUGHNESS,
	DEPTH_VIEW,
	SCREENSHOT_DEPTH,
	MATERIAL_NORMAL,
	SCREENSHOT_NORMAL,
	SCREENSHOT,
	FINISH
}
enum SLIDESHOW_STATE { INIT, BEGIN, SESSION, DILATION_POSTPROCESS, SAVE, FINISH, CANCEL }

enum BAKING_ORM_TYPE { METALLIC, ROUGHNESS }

var baker_state = BAKER_STATE.INIT
var slideshow_state = SLIDESHOW_STATE.INIT


func set_scene_to_bake(node: Spatial) -> void:
	create_images()

	if scene_to_bake:
		scene_to_bake.queue_free()

	scene_to_bake = node.duplicate()
	scene_to_bake.show()
	$MainContainer/ViewportContainer/ViewportBaking/BakedContainer.add_child(scene_to_bake)

	scene_to_bake.translation = Vector3()
	scene_to_bake.rotation = Vector3()
	var aabb: AABB = get_scene_to_bake_aabb()
	imported_scene_scale = scene_to_bake.scale
	update_scene_to_bake_transform()

	camera_distance = aabb.size.length()
	print("Camera distance: ", camera_distance)
	baking_camera.size = camera_distance
	baking_camera.far = camera_distance * 2.0
	baking_camera.transform.origin.z = camera_distance
	var mat_depth = $MainContainer/ViewportContainer/ViewportBaking/Camera/DepthPostProcess.mesh.surface_get_material(0)
	mat_depth.set_shader_param("depth_scaler", baking_camera.far )


func update_scene_to_bake_transform() -> void:
	scene_to_bake.scale = imported_scene_scale * atlas_coverage
	var aabb: AABB = get_scene_to_bake_aabb()
	scene_to_bake.translation -= aabb.position + aabb.size / 2.0


func get_scene_to_bake_aabb(node := scene_to_bake) -> AABB:
	var aabb := AABB(Vector3.ONE * 65536.0, -Vector3.ONE * 65536.0 * 2.0)
	if node is GeometryInstance and not node is CSGShape:
		aabb = aabb.merge(node.get_transformed_aabb())
	for child in node.get_children():
		aabb = aabb.merge(get_scene_to_bake_aabb(child))

	return aabb


func octa_hemisphere_enc(coord: Vector2) -> Vector3:
	var position: Vector3 = Vector3(coord.x - coord.y, 0, -1.0 + coord.x + coord.y)
	var absolute: Vector3 = position.abs()
	position.y = 1.0 - absolute.x - absolute.z

	return position


func octa_sphere_enc(coord: Vector2) -> Vector3:
	coord = coord * 2.0 - Vector2(1.0, 1.0)
	var position: Vector3 = Vector3(coord.x, 0, coord.y)
	var absolute: Vector3 = position.abs()
	position.y = 1.0 - absolute.x - absolute.z

	if position.y < 0:
		var pos_sign: Vector3 = position.sign()
		position.x = pos_sign.x * (1.0 - absolute.z)
		position.z = pos_sign.z * (1.0 - absolute.x)

	return position


func take_screenshot() -> Image:
	var image: Image = $MainContainer/ViewportContainer/ViewportBaking.get_texture().get_data()
	image.flip_y()
	image.convert(Image.FORMAT_RGBAH)
	return image


func setup_position(position: Vector3) -> void:
	var z: Vector3 = position.normalized()
	if z.abs() == Vector3(0, 1, 0):
		baking_camera.look_at_from_position(position, Vector3.ZERO, Vector3.BACK)
		return
	baking_camera.look_at_from_position(position, Vector3.ZERO, Vector3.UP)


func place_in_image_atlas(position: Vector2, image: Image, atlas_image: Image) -> void:
	var frame_size: int = atlas_image.get_size().x / frames_root_number
	var atlas_offset: Vector2 = position * frame_size

	image.resize(frame_size, frame_size, Image.INTERPOLATE_LANCZOS)
	image.lock()
	atlas_image.blend_rect(image, Rect2(0, 0, frame_size, frame_size), atlas_offset)
	image.unlock()


func grid_to_vector(coord: Vector2) -> Vector3:
	if is_full_sphere:
		return octa_sphere_enc(coord).normalized()
	else:
		return octa_hemisphere_enc(coord).normalized()


func state_camera_placement(coords: Vector2) -> void:
	var position_scaled: Vector2 = coords / float(frames_root_number - 1)
	var pivot_to_camera: Vector3 = grid_to_vector(position_scaled)
#	pivot_to_camera.y *= -1.0
	pivot_to_camera *= camera_distance
	setup_position(pivot_to_camera)


func state_screenshot(coords: Vector2) -> void:
	var image: Image = take_screenshot()
	place_in_image_atlas(coords, image, result_image)


func state_screenshot_normal(coords: Vector2) -> void:
	var image: Image = take_screenshot()
	place_in_image_atlas(coords, image, result_image_normal)


func state_screenshot_depth(coords: Vector2) -> void:
	var image: Image = take_screenshot()
	place_in_image_atlas(coords, image, result_image_depth)


func prepare_baking_material(N, material) -> void:
	var mats = N.mesh.get_surface_count()
	print(mats)

	if mats == 0:
		material.set_shader_param("use_normalmap", false)
		material.set_shader_param("use_alpha_texture", false)
		N.material_override = material
		return

	for m in mats:
		if material:
			material.set_shader_param("texture_albedo", null)
			material.set_shader_param("normal_texture", null)
			material.set_shader_param("alpha_scissor_threshold", 0.0)
			material.set_shader_param("normal_scale", 0.0)
			material.set_shader_param("use_normalmap", false)
			material.set_shader_param("use_alpha_texture", false)
			
			var original_mat = N.mesh.surface_get_material(m)
			if (original_mat is SpatialMaterial):
				print(original_mat)
				material.set_shader_param("normal_texture", original_mat.normal_texture)
				if original_mat.normal_enabled:
					material.set_shader_param("use_normalmap", true)
					material.set_shader_param("alpha_scissor_threshold", original_mat.params_alpha_scissor_threshold)
					material.set_shader_param("normal_scale", original_mat.normal_scale)
				if original_mat.params_use_alpha_scissor:
					material.set_shader_param("use_alpha_texture", true)
					material.set_shader_param("texture_albedo", original_mat.albedo_texture)
			else:
				print("Not a SpatialMaterial:")
				print(original_mat)
		N.set_surface_material(m, material)


func update_scene_to_bake_material(node, material) -> void:
	if node is MeshInstance:
		prepare_baking_material(node,material)
	for N in node.get_children():
		if N is MeshInstance:
			prepare_baking_material(N, material)
		if N.get_child_count() > 0:
			update_scene_to_bake_material(N, material)


func prepare_mesh_instance_orm_texture(node: MeshInstance, orm_type: int) -> void:
	var mats: int = node.mesh.get_surface_count()
	var mats_node: int = node.get_surface_material_count()
	if mats != mats_node:
		print("ORM baking not supported")
		return
	for m in mats:
		var mat: Material = node.mesh.surface_get_material(m)
		if ! (mat is SpatialMaterial):
			continue
		var mat_dup: Material = mat.duplicate()
		match orm_type:
			BAKING_ORM_TYPE.METALLIC:
				mat_dup.albedo_texture = mat.metallic_texture
				mat_dup.albedo_color = Color(mat.metallic, mat.metallic, mat.metallic)
			BAKING_ORM_TYPE.ROUGHNESS:
				mat_dup.albedo_texture = mat.roughness_texture
				mat_dup.albedo_color = Color(mat.roughness, mat.roughness, mat.roughness)
		node.set_surface_material(m, mat_dup)


func prepare_orm_texture(node: Spatial, orm_type: int) -> void:
	if node is MeshInstance:
		prepare_mesh_instance_orm_texture(node, orm_type)
	for N in node.get_children():
		if N is MeshInstance:
			prepare_mesh_instance_orm_texture(N, orm_type)
		if N.get_child_count() > 0:
			prepare_orm_texture(N, orm_type)


func cleanup_mesh_instance_orm_texture(node: MeshInstance) -> void:
	var mats: int = node.mesh.get_surface_count()
	var mats_node: int = node.get_surface_material_count()
	if mats != mats_node:
		print("ORM baking not supported.")
		return
	for m in mats:
		node.set_surface_material(m, null)


func cleanup_orm_texture(node: Spatial) -> void:
	if node is MeshInstance:
		cleanup_mesh_instance_orm_texture(node)
	for N in node.get_children():
		if N is MeshInstance:
			cleanup_mesh_instance_orm_texture(N)
		if N.get_child_count() > 0:
			cleanup_orm_texture(N)


func state_screenshotMetallic(coords: Vector2) -> void:
	var image: Image = take_screenshot()
	place_in_image_atlas(coords, image, result_image_metallic)


func state_screenshotRoughness(coords: Vector2) -> void:
	var image: Image = take_screenshot()
	place_in_image_atlas(coords, image, result_image_roughness)


func baker_process(coords: Vector2) -> void:
	match baker_state:
		BAKER_STATE.INIT:
			pass
		BAKER_STATE.CAMERA_PLACEMENT:
			state_camera_placement(coords)
			baker_state = BAKER_STATE.NOP
		BAKER_STATE.NOP:
			if shader_type != SHADER_TYPE.LIGHT:
				baker_state = BAKER_STATE.METALLIC_VIEW
			else:
				baker_state = BAKER_STATE.DEPTH_VIEW
			$MainContainer/ViewportContainer/ViewportBaking.keep_3d_linear = true
		BAKER_STATE.METALLIC_VIEW:
			prepare_orm_texture(scene_to_bake, BAKING_ORM_TYPE.METALLIC)
			baker_state = BAKER_STATE.SCREENSHOT_METALLIC
		BAKER_STATE.SCREENSHOT_METALLIC:
			state_screenshotMetallic(coords)
			cleanup_orm_texture(scene_to_bake)
			baker_state = BAKER_STATE.ROUGHNESS_VIEW
		BAKER_STATE.ROUGHNESS_VIEW:
			prepare_orm_texture(scene_to_bake, BAKING_ORM_TYPE.ROUGHNESS)
			baker_state = BAKER_STATE.SCREENSHOT_ROUGHNESS
		BAKER_STATE.SCREENSHOT_ROUGHNESS:
			state_screenshotRoughness(coords)
			cleanup_orm_texture(scene_to_bake)
			baker_state = BAKER_STATE.DEPTH_VIEW
		BAKER_STATE.DEPTH_VIEW:
			baker_state = BAKER_STATE.SCREENSHOT_DEPTH
			$MainContainer/ViewportContainer/ViewportBaking/Camera/DepthPostProcess.visible = true
		BAKER_STATE.SCREENSHOT_DEPTH:
			state_screenshot_depth(coords)
			$MainContainer/ViewportContainer/ViewportBaking/Camera/DepthPostProcess.visible = false
			baker_state = BAKER_STATE.MATERIAL_NORMAL
		BAKER_STATE.MATERIAL_NORMAL:
			update_scene_to_bake_material(scene_to_bake, normal_material)
			baker_state = BAKER_STATE.SCREENSHOT_NORMAL
		BAKER_STATE.SCREENSHOT_NORMAL:
			state_screenshot_normal(coords)
			update_scene_to_bake_material(scene_to_bake, null)
			baker_state = BAKER_STATE.SCREENSHOT
			$MainContainer/ViewportContainer/ViewportBaking.keep_3d_linear = false
		BAKER_STATE.SCREENSHOT:
			state_screenshot(coords)
			baker_state = BAKER_STATE.FINISH
		BAKER_STATE.FINISH:
			rendered_counter += 1
			baker_state = BAKER_STATE.INIT


func state_session() -> bool:
	baker_process(current_frame)
	if (
		rendered_counter == frames_root_number * frames_root_number
		&& baker_state == BAKER_STATE.FINISH
	):
		return true
	if baker_state == BAKER_STATE.INIT:
		baker_state = BAKER_STATE.CAMERA_PLACEMENT
		print(current_frame)
	elif baker_state == BAKER_STATE.FINISH:
		current_frame.x += 1
		if current_frame.x >= frames_root_number:
			current_frame.x = 0
			current_frame.y += 1
	return false


func export_images(img_path: String) -> void:
	var dir: Directory = Directory.new()
	if not dir.dir_exists(img_path):
		dir.make_dir_recursive(img_path)

	var half_res = image_dimensions/2.0
	var tex_packer = TexturePacker.new()
	var img_norm_depth: Image
	var img_orm: Image

	result_image.convert(Image.FORMAT_RGBA8)
	if dilatation_postprocess:
		yield(dilatation_pipeline.dilatate(result_image), "completed")
		result_image = dilatation_pipeline.processed_image
	result_image.save_png(img_path.plus_file(base_filename))
	#do not pack normals with other 

	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")

	if dilatation_postprocess:
		yield(dilatation_pipeline.dilatate_mask(result_image, result_image_depth), "completed")
		result_image_depth = dilatation_pipeline.processed_image
	result_image_depth.convert(Image.FORMAT_R8);
	if(use_half_resolution_data_maps):
		result_image_depth.resize(half_res, half_res, Image.INTERPOLATE_LANCZOS)
	result_image_depth.save_png(img_path.plus_file(depth_alpha_filename))

	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")

	if dilatation_postprocess:
		yield(dilatation_pipeline.dilatate_mask(result_image, result_image_normal), "completed")
		result_image_normal = dilatation_pipeline.processed_image
	if(use_half_resolution_data_maps):
		result_image_normal.resize(half_res, half_res, Image.INTERPOLATE_LANCZOS)
	result_image_normal.save_png(img_path.plus_file(normal_filename))

	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	
	if shader_type != SHADER_TYPE.LIGHT:
		img_orm = tex_packer.pack_orm(null, result_image_roughness, result_image_metallic)
		if dilatation_postprocess:
			yield(dilatation_pipeline.dilatate_mask(result_image, img_orm), "completed")
			img_orm = dilatation_pipeline.processed_image
		if(use_half_resolution_data_maps):
			img_orm.resize(half_res, half_res, Image.INTERPOLATE_LANCZOS)
		img_orm.save_png(img_path.plus_file(orm_filename))


func workaround_texturearray_import(pack_path: String) -> void:
	#ugly workaround forcing godot to import image as TextureArray
	var textures_arr = [base_filename, normal_filename, orm_filename]
	var tmp: Template

	for tex in textures_arr:
		tmp = Template.new("texture_array.import")
		tmp.fill("SOURCE_FILE", pack_path.plus_file(tex))
		tmp.fill("GRID_SIZE", str(frames_root_number))
		tmp.save(pack_path.plus_file(tex) + ".import")


func export_packed_scene(pack_path: String) -> void:
	if shader_type == SHADER_TYPE.TEXTURE_ARRAY:
		var gv = Engine.get_version_info()
		if gv.major != 3 || gv.minor != 2:
			push_warning("Running on untested Godot version. Please use 3.2.x!")
		workaround_texturearray_import(pack_path)
	
	yield(export_images(pack_path), "completed");

	var root: Spatial = Spatial.new()
	var mi: MeshInstance = MeshInstance.new()

	var mat: ShaderMaterial = ShaderMaterial.new()
	match shader_type:
		SHADER_TYPE.LIGHT:
			mat.shader = light_shader
		SHADER_TYPE.STANDARD:
			mat.shader = standard_shader
		SHADER_TYPE.TEXTURE_ARRAY:
			mat.shader = texarr_shader

	if plugin:
		plugin.get_editor_interface().get_resource_filesystem().scan()

	# wait until the images have all been (re)imported.
	print("Waiting for resources on disk...")
	while not (
		ResourceLoader.exists(pack_path.plus_file(base_filename))
		and ResourceLoader.exists(pack_path.plus_file(normal_filename))
		and (
			ResourceLoader.exists(pack_path.plus_file(orm_filename))
			if shader_type != SHADER_TYPE.LIGHT
			else true
		)
	):
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
	
	print("Creating material...")

	mat.set_shader_param("imposterFrames", Vector2(frames_root_number, frames_root_number))
	mat.set_shader_param("isFullSphere", is_full_sphere)
	mat.set_shader_param("aabb_max", camera_distance/4.0)
	mat.set_shader_param("scale", camera_distance/2.0)

	var base_tex = null
	var norm_tex = null
	var depth_alpha_tex = null

	print("Texture Array workaround ??...")
	#workaround for TextureArray, because of yield we cannot do it in other function
	while base_tex == null || norm_tex == null || depth_alpha_tex == null:
		base_tex = load(pack_path.plus_file(base_filename))
		norm_tex = load(pack_path.plus_file(normal_filename))
		depth_alpha_tex = load(pack_path.plus_file(depth_alpha_filename))
		yield(get_tree(), "idle_frame")

	print("More parameters for material...")
	mat.set_shader_param("imposterBaseTexture", base_tex)
	mat.set_shader_param("imposterNormalDepthTexture", norm_tex)
	mat.set_shader_param("imposterDepthAlphaTexture", depth_alpha_tex)

	if shader_type != SHADER_TYPE.LIGHT:
		mat.set_shader_param("isTransparent", false)
		mat.set_shader_param("metallic", 1.0)

		var orm_tex = null
		while orm_tex == null:
			orm_tex = load(pack_path.plus_file(orm_filename))
			yield(get_tree(), "idle_frame")

		mat.set_shader_param("imposterORMTexture", orm_tex)

	var quad_mesh: QuadMesh = QuadMesh.new()

	root.add_child(mi)
	root.name = "Impostor"
	mi.owner = root
	mi.mesh = quad_mesh
	mi.mesh.surface_set_material(0, mat)

	var packed_scene: PackedScene = PackedScene.new()
	packed_scene.pack(root)
	ResourceSaver.save(pack_path.plus_file(packedscene_filename), packed_scene)
	print("Imposter ready!")


func slideshow_process() -> void:
	match slideshow_state:
		SLIDESHOW_STATE.INIT:
			pass
		SLIDESHOW_STATE.BEGIN:
			rendered_counter = 0
			current_frame = Vector2(0, 0)
			popup_exclusive = true
			$MainContainer/ViewportContainer.stretch = false
			$MainContainer/ViewportContainer/ViewportBaking.size = (
				Vector2.ONE
				* image_dimensions
				/ frames_root_number
			)
			slideshow_state = SLIDESHOW_STATE.SESSION
		SLIDESHOW_STATE.SESSION:
			if state_session():
				slideshow_state = SLIDESHOW_STATE.SAVE
		SLIDESHOW_STATE.SAVE:
			# waiting for completed with yield will crash - Godot 3.3
			if export_as_packed_scene:
				print("EXPORTING AS PACKED SCENE")
				export_packed_scene(save_path)
			else:
				print("EXPORTING ONLY IMAGES")
				export_images(save_path)
			print("Imposter saving!")
			slideshow_state = SLIDESHOW_STATE.FINISH
			
			
		SLIDESHOW_STATE.FINISH:
			# waiting for completed scene generation with yield will 
			# crash so we just check if resource exitsts
			var scene_exsists = ResourceLoader.exists(save_path.plus_file(packedscene_filename))
			if scene_exsists or not export_as_packed_scene:
				print("Finished...")
				call_deferred("hide")
					
		SLIDESHOW_STATE.CANCEL:
			baking_camera.look_at_from_position(
				Vector3(0, 0, camera_distance), Vector3.ZERO, Vector3.UP
			)
			popup_exclusive = false
			$MainContainer/ViewportContainer.stretch = true
			$MainContainer/ViewportContainer/ViewportBaking.size = rect_size
			$MainContainer/ViewportContainer/ViewportBaking.keep_3d_linear = false
			rendered_counter = 0.0
			slideshow_state = SLIDESHOW_STATE.INIT
			#clean up any bake images currantly in progress
			create_images()


func create_images():
	result_image.create(image_dimensions, image_dimensions, false, Image.FORMAT_RGBAH)
	result_image.fill(Color(0, 0, 0, 0))
	# DO NOT SCALE iamges down here. Dilatate will be broken!
	result_image_normal.create(image_dimensions, image_dimensions, false, Image.FORMAT_RGBAH)
	result_image_normal.fill(Color(0.5, 0.5, 0, 1))
	result_image_depth.create(image_dimensions, image_dimensions, false, Image.FORMAT_RGBAH)
	result_image_depth.fill(Color(0.5, 0.5, 0.5, 1))
	result_image_metallic.create(image_dimensions, image_dimensions, false, Image.FORMAT_RGBAH)
	result_image_roughness.create(image_dimensions, image_dimensions, false, Image.FORMAT_RGBAH)
	#make default as rough
	result_image_roughness.fill(Color(1, 1, 1))


func _process(_delta):
	if not progress_bar:
		return

	$MainContainer/Panel/container/Button.text = (
		"Generate"
		if slideshow_state == SLIDESHOW_STATE.INIT
		else "Cancel"
	)

	progress_bar.value = float(rendered_counter) / float(frames_root_number * frames_root_number)
	if slideshow_state != SLIDESHOW_STATE.INIT:
		progress_bar.value = clamp(progress_bar.value, 0, 0.99)
	slideshow_process()


func _on_Button_pressed():
	if slideshow_state == SLIDESHOW_STATE.INIT:
		$FileDialog.popup_centered()
	else:
		slideshow_state = SLIDESHOW_STATE.CANCEL


func _on_SpinBox_value_changed(value: float):
	atlas_coverage = value / 100.0
	update_scene_to_bake_transform()


func _on_CheckboxFullSphere_toggled(state: bool):
	is_full_sphere = state


func _on_SpinBoxGridSize_value_changed(value: float):
	frames_root_number = value


func _on_OptionButtonShaderType_item_selected(shader_type_p: int):
	shader_type = shader_type_p
	print(shader_type)


func _on_CheckBoxPackedScene_toggled(state: bool):
	export_as_packed_scene = state


func _on_OptionButtonImgRes_item_selected(new_dimm: int):
	var multiplier: int = pow(2, new_dimm)
	image_dimensions = 1024 * multiplier
	create_images()


func _on_FileDialog_file_selected(path: String) -> void:
	save_path = path.get_base_dir()
	packedscene_filename = path.get_file()
	slideshow_state = SLIDESHOW_STATE.BEGIN


func _on_ImpostorBaker_popup_hide() -> void:
	if slideshow_state != SLIDESHOW_STATE.INIT:
		slideshow_state = SLIDESHOW_STATE.CANCEL

func _on_CheckBoxHalfResolution_toggled(state: bool):
	use_half_resolution_data_maps = state