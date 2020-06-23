extends Camera

export (int) var frames_root_number = 16
export (int) var image_dimmension = 4096
export (float) var camera_distance = 1.0
export (bool) var is_full_sphere = true
export (bool) var is_standard_shader = false
export (bool) var export_as_packed_scene = true
export (String) var export_path = "res://export_images/"

var object_pos: Vector3 = Vector3(0, 0, 0)

var result_image: Image = Image.new()
var result_image_normal: Image = Image.new()
var result_image_depth: Image = Image.new()
var result_image_metallic: Image = Image.new()
var result_image_roughness: Image = Image.new()

var rendered_counter: int = 0
var current_frame: Vector2 = Vector2(0, 0)

var progress_bar: ProgressBar
var scene_to_bake: Spatial

var normal_material = preload("res://materials/normal_baker.material")
var standard_shader = preload("res://materials/shaders/ImpostorShader.shader")
var light_shader = preload("res://materials/shaders/ImpostorShaderLight.shader")

var base_filename = "base.png"
var normal_depth_filename = "norm_depth.png"
var orm_filename = "orm.png"
var packedscene_filename = "imposter.tscn"

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
enum SLIDESHOW_STATE { INIT, BEGIN, SESSION, FINISH }

enum BAKING_ORM_TYPE { METALLIC, ROUGHNESS }

var baker_state = BAKER_STATE.INIT
var slideshow_state = SLIDESHOW_STATE.INIT


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
	var image: Image = get_viewport().get_texture().get_data()
	image.flip_y()
	return image


func setup_position(position: Vector3) -> void:
	var z: Vector3 = position.normalized()
	if z.abs() == Vector3(0, 1, 0):
		look_at_from_position(position, object_pos, Vector3.BACK)
		return
	look_at_from_position(position, object_pos, Vector3.UP)


func place_in_image_atlas(position: Vector2, image: Image, atlas_image: Image) -> void:
	var frame_size: int = image_dimmension / frames_root_number
	var atlas_offset: Vector2 = position * frame_size
	image.resize(frame_size, frame_size)
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


func update_scene_to_bake_material(node, material) -> void:
	if node is MeshInstance:
		node.material_override = material
	for N in node.get_children():
		if N is MeshInstance:
			N.material_override = material
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
			if is_standard_shader:
				baker_state = BAKER_STATE.METALLIC_VIEW
			else:
				baker_state = BAKER_STATE.MATERIAL_NORMAL
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
			$DepthPostProcess.visible = true
		BAKER_STATE.SCREENSHOT_DEPTH:
			state_screenshot_depth(coords)
			$DepthPostProcess.visible = false
			baker_state = BAKER_STATE.MATERIAL_NORMAL
		BAKER_STATE.MATERIAL_NORMAL:
			update_scene_to_bake_material(scene_to_bake, normal_material)
			baker_state = BAKER_STATE.SCREENSHOT_NORMAL
		BAKER_STATE.SCREENSHOT_NORMAL:
			state_screenshot_normal(coords)
			update_scene_to_bake_material(scene_to_bake, null)
			baker_state = BAKER_STATE.SCREENSHOT
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
	var tex_packer = TexturePacker.new()
	var img_norm_depth: Image
	var img_orm: Image

	result_image.convert(Image.FORMAT_RGBA8)
	result_image.save_png(img_path + base_filename)
	img_norm_depth = tex_packer.pack_normal_depth(result_image_normal, result_image_depth)
	img_norm_depth.save_png(img_path + normal_depth_filename)
	if is_standard_shader:
		img_orm = tex_packer.pack_orm(null, result_image_roughness, result_image_metallic)
		img_orm.save_png(img_path + orm_filename)


func export_packed_scene(pack_path: String) -> void:
	var root: Spatial = Spatial.new()
	var mi: MeshInstance = MeshInstance.new()

	export_images(pack_path)

	var mat: ShaderMaterial = ShaderMaterial.new()
	if is_standard_shader:
		mat.shader = standard_shader
	else:
		mat.shader = light_shader
	var quad_mesh: QuadMesh = QuadMesh.new()
	mi.mesh = quad_mesh
	mi.mesh.surface_set_material(0, mat)
	mi.name = "Imposter"
	root.name = "Scene"
	root.add_child(mi)
	mi.owner = root
	mat.set_shader_param("imposterFrames", Vector2(frames_root_number, frames_root_number))
	mat.set_shader_param("isFullSphere", is_full_sphere)

	var albedo_texture: StreamTexture = load(pack_path + base_filename)
	mat.set_shader_param("imposterBaseTexture", albedo_texture)

	var normal_depth_texture: StreamTexture = load(pack_path + normal_depth_filename)
	mat.set_shader_param("imposterNormalDepthTexture", normal_depth_texture)

	if is_standard_shader:
		mat.set_shader_param("isTransparent", false)
		mat.set_shader_param("metallic", 1.0)

		var orm_texture: StreamTexture = load(pack_path + orm_filename)
		mat.set_shader_param("imposterORMTexture", orm_texture)

	var packed_scene: PackedScene = PackedScene.new()
	packed_scene.pack(root)
	ResourceSaver.save(pack_path + packedscene_filename, packed_scene)
	print("Imposter tscn ready")


func slideshow_process() -> void:
	match slideshow_state:
		SLIDESHOW_STATE.INIT:
			pass
		SLIDESHOW_STATE.BEGIN:
			rendered_counter = 0
			current_frame = Vector2(0, 0)
			slideshow_state = SLIDESHOW_STATE.SESSION
		SLIDESHOW_STATE.SESSION:
			if state_session():
				slideshow_state = SLIDESHOW_STATE.FINISH
		SLIDESHOW_STATE.FINISH:
			if export_as_packed_scene:
				export_packed_scene(export_path)
			else:
				export_images(export_path)
			print("Imposter Saved!")
			slideshow_state = SLIDESHOW_STATE.INIT


func create_images():
	result_image.create(image_dimmension, image_dimmension, false, Image.FORMAT_RGBAH)
	result_image.fill(Color(0, 0, 0, 0))
	result_image_normal.create(image_dimmension, image_dimmension, false, Image.FORMAT_RGBAH)
	result_image_depth.create(image_dimmension, image_dimmension, false, Image.FORMAT_RGBAH)
	result_image_metallic.create(image_dimmension, image_dimmension, false, Image.FORMAT_RGBAH)
	result_image_roughness.create(image_dimmension, image_dimmension, false, Image.FORMAT_RGBAH)
	#make default as roughth
	result_image_roughness.fill(Color(1, 1, 1))


func _ready():
	create_images()
	progress_bar = get_parent().get_parent().get_node("Panel/container/progress")
	scene_to_bake = get_parent().get_node("BakedContainer").get_child(0)


func _process(_delta):
	progress_bar.value = float(rendered_counter) / float(frames_root_number * frames_root_number)
	if slideshow_state != SLIDESHOW_STATE.INIT:
		progress_bar.value = clamp(progress_bar.value, 0, 0.99)
	slideshow_process()


func _on_Button_pressed():
	slideshow_state = SLIDESHOW_STATE.BEGIN


func _on_SpinBox_value_changed(value: float):
	camera_distance = value
	far = 2.0 * value
	size = value


func _on_CheckboxFullSphere_toggled(state: bool):
	is_full_sphere = state


func _on_SpinBoxGridSize_value_changed(value: float):
	frames_root_number = value


func _on_CheckboxDepth_toggled(state: bool):
	is_standard_shader = state


func _on_CheckBoxPackedScene_toggled(state: bool):
	export_as_packed_scene = state


func _on_OptionButtonImgRes_item_selected(new_dimm: int):
	var multiplier: int = pow(2, new_dimm)
	image_dimmension = 1024 * multiplier
	create_images()
