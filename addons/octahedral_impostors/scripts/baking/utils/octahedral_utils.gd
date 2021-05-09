
static func octa_hemisphere_enc(coord: Vector2) -> Vector3:
	var position: Vector3 = Vector3(coord.x - coord.y, 0, -1.0 + coord.x + coord.y)
	var absolute: Vector3 = position.abs()
	position.y = 1.0 - absolute.x - absolute.z

	return position


static func octa_sphere_enc(coord: Vector2) -> Vector3:
	coord = coord * 2.0 - Vector2(1.0, 1.0)
	var position: Vector3 = Vector3(coord.x, 0, coord.y)
	var absolute: Vector3 = position.abs()
	position.y = 1.0 - absolute.x - absolute.z

	if position.y < 0:
		var pos_sign: Vector3 = position.sign()
		position.x = pos_sign.x * (1.0 - absolute.z)
		position.z = pos_sign.z * (1.0 - absolute.x)

	return position

static func grid_to_vector(coord: Vector2, is_full_sphere: bool) -> Vector3:
	if is_full_sphere:
		return octa_sphere_enc(coord).normalized()
	else:
		return octa_hemisphere_enc(coord).normalized()