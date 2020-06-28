class_name TexturePacker

enum TEXTURE_COMPONENT { R, G, B, A }


func _conv_component(component: int) -> String:
	match component:
		TEXTURE_COMPONENT.R:
			return "r"
		TEXTURE_COMPONENT.G:
			return "g"
		TEXTURE_COMPONENT.B:
			return "b"
		_:
			return "a"


func _texture_pack_component(img_input: Image, img_output: Image, in_cmt: int, out_cmt: int) -> void:
	var i_cmt: String = _conv_component(in_cmt)
	var o_cmt: String = _conv_component(out_cmt)
	img_input.lock()
	for y in range(img_output.get_height()):
		for x in range(img_output.get_width()):
			var ic: Color = img_input.get_pixel(x, y)
			var oc: Color = img_output.get_pixel(x, y)

			oc[o_cmt] = ic[i_cmt]
			img_output.set_pixel(x, y, oc)
	img_input.unlock()


func pack_normal_depth(img_normal: Image, img_depth: Image = null) -> Image:
	var output: Image = Image.new()
	output.create(img_normal.get_width(), img_normal.get_height(), false, Image.FORMAT_RGBAH)
	output.copy_from(img_normal)
	#convert needed after copy_from
	output.convert(Image.FORMAT_RGBA8)
	output.lock()
	#if img_depth:
	_texture_pack_component(img_depth, output, TEXTURE_COMPONENT.R, TEXTURE_COMPONENT.A)

	output.unlock()
	return output


func pack_orm(img_o: Image = null, img_r: Image = null, img_m: Image = null) -> Image:
	var output: Image = Image.new()
	output.create(img_m.get_width(), img_m.get_height(), false, Image.FORMAT_RGBA8)
	output.fill(Color(0, 0, 0, 1))
	output.lock()
	if img_o:
		_texture_pack_component(img_o, output, TEXTURE_COMPONENT.R, TEXTURE_COMPONENT.R)
	if img_r:
		_texture_pack_component(img_r, output, TEXTURE_COMPONENT.R, TEXTURE_COMPONENT.G)
	if img_m:
		_texture_pack_component(img_m, output, TEXTURE_COMPONENT.R, TEXTURE_COMPONENT.B)
	output.unlock()
	return output
