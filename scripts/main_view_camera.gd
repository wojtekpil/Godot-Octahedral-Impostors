extends Camera


func _on_SpinBox_value_changed(value: float):
	transform.origin = Vector3(0, 0, value)
	size = value
	far = 2.0 * value
