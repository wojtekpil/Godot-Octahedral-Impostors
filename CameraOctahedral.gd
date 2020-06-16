extends Camera

export(int) var frameSquareSize = 16
export(int) var imageSquareSize = 2048
export(float) var cameraDistance = 1.0
export(bool) var isFullSphere = true
export(bool) var generateStandardShader = false



var objectPos: Vector3 = Vector3(0,0,0)

var resultImage: Image = Image.new()
var resultImageNormal: Image = Image.new()
var resultImageDepth: Image = Image.new()
var resultImageMetallic: Image = Image.new()

var rendered_counter: int = 0

var progressBar: ProgressBar
var current_frame: Vector2 = Vector2(0,0)

var normal_material = preload("res://materials/normal_baker.material")
var scene_to_bake: Spatial



enum BAKER_STATE {INIT, CAMERA_PLACEMENT, NOP,METALLIC_VIEW, SCREENSHOT_METALLIC, DEPTH_VIEW, SCREENSHOT_DEPTH, MATERIAL_NORMAL ,SCREENSHOT_NORMAL, SCREENSHOT, FINISH}
enum SLIDESHOW_STATE {INIT, BEGIN, SESSION, FINISH}

var baker_state = BAKER_STATE.INIT
var slideshow_state = SLIDESHOW_STATE.INIT

func octaHemiSphereEnc( coord: Vector2 ) -> Vector3:
	var position: Vector3 = Vector3(coord.x - coord.y, 0, -1.0 + coord.x + coord.y)
	var absolute: Vector3 = position.abs()
	position.y = 1.0 - absolute.x - absolute.z

	return position;


func octaSphereEnc( coord: Vector2 ) -> Vector3:
	coord = coord * 2.0 - Vector2(1.0, 1.0)
	var position: Vector3 = Vector3(coord.x, 0, coord.y)
	var absolute: Vector3 = position.abs()
	position.y = 1.0 - absolute.x - absolute.z
	
	if position.y < 0:
		var pos_sign: Vector3 = position.sign()
		position.x = pos_sign.x * (1.0 - absolute.z)
		position.z = pos_sign.z * (1.0 - absolute.x)

	return position;


func takeScreenshot() -> Image:
	var image = get_viewport().get_texture().get_data()
	image.flip_y()
	return image


func setupPosition(position: Vector3) -> void:
	var z = position.normalized()
	if z.abs() == Vector3(0,1,0):
		look_at_from_position(position, objectPos, Vector3.BACK)
		return
	look_at_from_position(position, objectPos, Vector3.UP)


func placeInImageAtlas(position: Vector2, image: Image, atlasImage: Image) -> void:
	var frameSize: int = imageSquareSize/frameSquareSize;
	image.resize(frameSize, frameSize)
	var atlasOffset: Vector2 = position * frameSize
	image.lock()
	atlasImage.blend_rect(
		image,
		#alpha_temp_image,
		Rect2(0,0,frameSize, frameSize),
		atlasOffset
	)
	image.unlock()


func gridToVector(coord: Vector2) -> Vector3:
	if isFullSphere:
		return octaSphereEnc(coord).normalized()
	else:
		return octaHemiSphereEnc(coord).normalized()


func stateCameraPlacement(coords: Vector2) -> void:
	var positionScaled: Vector2 = coords / float(frameSquareSize - 1)
	var pivotToCamera: Vector3 = gridToVector(positionScaled)
	pivotToCamera *= cameraDistance
	setupPosition(pivotToCamera)


func stateScreenshot(coords: Vector2):
	var image: Image = takeScreenshot()
	placeInImageAtlas(coords, image, resultImage)


func stateScreenshotNormal(coords: Vector2):
	var image: Image = takeScreenshot()
	placeInImageAtlas(coords, image, resultImageNormal)

func stateScreenshotDepth(coords: Vector2):
	var image: Image = takeScreenshot()
	placeInImageAtlas(coords, image, resultImageDepth)


func updateSceneToBakeMaterial(node, material) -> void:
	if node is MeshInstance:
		node.material_override = material
	for N in node.get_children():
		if N is MeshInstance:
			N.material_override = material
		if N.get_child_count() > 0:
			updateSceneToBakeMaterial(N, material)


func prepareMeshInstanceMetallicTexture(node):
	var mats = node.mesh.get_surface_count()
	var mats_node = node.get_surface_material_count()
	if mats != mats_node:
		print("Metallic baking not supported")
		return
	for m in mats:
		var mat = node.mesh.surface_get_material(m)
		if ! (mat is SpatialMaterial):
			continue
		var mat_dup = mat.duplicate()
		mat_dup.albedo_texture = mat_dup.metallic_texture
		node.set_surface_material(m,mat_dup)

func prepareMetallicTexture(node):
	if node is MeshInstance:
		prepareMeshInstanceMetallicTexture(node)
	for N in node.get_children():
		if N is MeshInstance:
			prepareMeshInstanceMetallicTexture(N)
		if N.get_child_count() > 0:
			prepareMetallicTexture(N)


func cleanupMeshInstanceMetallicTexture(node):
	var mats = node.mesh.get_surface_count()
	var mats_node = node.get_surface_material_count()
	if mats != mats_node:
		print("Metallic baking not supported")
		return
	for m in mats:
		node.set_surface_material(m,null)


func cleanupMetallicTexture(node):
	if node is MeshInstance:
		cleanupMeshInstanceMetallicTexture(node)
	for N in node.get_children():
		if N is MeshInstance:
			cleanupMeshInstanceMetallicTexture(N)
		if N.get_child_count() > 0:
			cleanupMetallicTexture(N)


func stateScreenshotMetallic(coords: Vector2):
	var image: Image = takeScreenshot()
	placeInImageAtlas(coords, image, resultImageMetallic)


func baker_process(coords: Vector2) -> void:
	match baker_state:
		BAKER_STATE.INIT:
			pass
		BAKER_STATE.CAMERA_PLACEMENT:
			stateCameraPlacement(coords)
			baker_state = BAKER_STATE.NOP
		BAKER_STATE.NOP:
			if generateStandardShader:
				baker_state = BAKER_STATE.METALLIC_VIEW
			else:
				baker_state = BAKER_STATE.MATERIAL_NORMAL
		BAKER_STATE.METALLIC_VIEW:
			prepareMetallicTexture(scene_to_bake)
			baker_state = BAKER_STATE.SCREENSHOT_METALLIC
		BAKER_STATE.SCREENSHOT_METALLIC:
			stateScreenshotMetallic(coords)
			cleanupMetallicTexture(scene_to_bake)
			baker_state = BAKER_STATE.DEPTH_VIEW
		BAKER_STATE.DEPTH_VIEW:
			baker_state = BAKER_STATE.SCREENSHOT_DEPTH
			$DepthPostProcess.visible = true
		BAKER_STATE.SCREENSHOT_DEPTH:
			stateScreenshotDepth(coords)
			$DepthPostProcess.visible = false
			baker_state = BAKER_STATE.MATERIAL_NORMAL
		BAKER_STATE.MATERIAL_NORMAL:
			updateSceneToBakeMaterial(scene_to_bake, normal_material)
			baker_state = BAKER_STATE.SCREENSHOT_NORMAL
		BAKER_STATE.SCREENSHOT_NORMAL:
			stateScreenshotNormal(coords)
			updateSceneToBakeMaterial(scene_to_bake, null)
			baker_state = BAKER_STATE.SCREENSHOT
		BAKER_STATE.SCREENSHOT:
			stateScreenshot(coords)
			baker_state = BAKER_STATE.FINISH
		BAKER_STATE.FINISH:
			rendered_counter += 1
			baker_state = BAKER_STATE.INIT


func stateSession() -> bool:
	baker_process(current_frame)
	if rendered_counter == frameSquareSize*frameSquareSize && baker_state == BAKER_STATE.FINISH:
		return true
	if baker_state == BAKER_STATE.INIT:
		baker_state = BAKER_STATE.CAMERA_PLACEMENT
		print(current_frame)
	elif baker_state == BAKER_STATE.FINISH:
		current_frame.x +=1
		if current_frame.x >= frameSquareSize:
			current_frame.x = 0
			current_frame.y += 1
	return false


func slideshow_process():
	match slideshow_state:
		SLIDESHOW_STATE.INIT:
			pass
		SLIDESHOW_STATE.BEGIN:
			rendered_counter = 0
			current_frame = Vector2(0,0)
			slideshow_state = SLIDESHOW_STATE.SESSION
		SLIDESHOW_STATE.SESSION:
			if stateSession():
				slideshow_state = SLIDESHOW_STATE.FINISH
		SLIDESHOW_STATE.FINISH:
			resultImage.convert(Image.FORMAT_RGBA8)
			resultImage.save_png("result.png")
			resultImageNormal.save_png("result_normal.png")
			if generateStandardShader:
				resultImageDepth.save_png("result_depth.png")
				resultImageMetallic.save_png("result_metallic.png")
			print("Image Saved!")
			slideshow_state = SLIDESHOW_STATE.INIT


func _ready():
	resultImage.create(imageSquareSize, imageSquareSize, false, Image.FORMAT_RGBAH)
	resultImage.fill(Color(0,0,0,0))
	resultImageNormal.create(imageSquareSize, imageSquareSize, false, Image.FORMAT_RGBAH)
	resultImageDepth.create(imageSquareSize, imageSquareSize, false, Image.FORMAT_RGBAH)
	resultImageMetallic.create(imageSquareSize, imageSquareSize, false, Image.FORMAT_RGBAH)
	progressBar = get_parent().get_parent().get_node("container").get_node("progress");
	scene_to_bake = get_parent().get_node("BakedContainer").get_child(0)
	

func _process(_delta):
	progressBar.value = float(rendered_counter)/float(frameSquareSize*frameSquareSize)
	if(slideshow_state != SLIDESHOW_STATE.INIT):
		progressBar.value = clamp(progressBar.value, 0, 0.99)
	slideshow_process()


func _on_Button_pressed():
	slideshow_state = SLIDESHOW_STATE.BEGIN


func _on_SpinBox_value_changed(value: float):
	cameraDistance = value
	far = 2.0*value
	size = value


func _on_CheckboxFullSphere_toggled(state: bool):
	isFullSphere = state


func _on_SpinBoxGridSize_value_changed(value: float):
	frameSquareSize = value


func _on_CheckboxDepth_toggled(state: bool):
	generateStandardShader = state
