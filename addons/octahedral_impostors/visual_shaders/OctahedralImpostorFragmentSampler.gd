tool
extends VisualShaderNodeCustom
class_name VisualShaderNodeOCtaImpFragSamp

func _init() -> void:
	set_input_port_default_value(3, 1.0)
	set_input_port_default_value(4, 12)

func _get_name() -> String:
	return "OctahedralImpostorFragmentSampler"

func _get_category() -> String:
	return "OctahedralImpostors"

#func _get_subcategory():
#	return ""

func _get_description() -> String:
	return "Fragment shader of octahedral impostor for sampling other atlas maps"


func _get_input_port_count() -> int:
	return 2

func _get_input_port_name(port: int):
	match port:
		0:
			return "imp_data"
		1:
			return "texture_atlas"

func _get_input_port_type(port: int):
	match port:
		0:
			return VisualShaderNode.PORT_TYPE_TRANSFORM
		1:
			return VisualShaderNode.PORT_TYPE_SAMPLER

func _get_output_port_count() -> int:
	return 2

func _get_output_port_name(port: int):
	match port:
		0:
			return "albedo"
		1:
			return "alpha"

func _get_output_port_type(port: int):
	match port:
		0:
			return VisualShaderNode.PORT_TYPE_VECTOR
		1:
			return VisualShaderNode.PORT_TYPE_SCALAR

func _get_code(input_vars: Array, output_vars: Array, mode: int, type: int) -> String:
	var code = """
mat4 imp_data = %s;
vec2 uv_f1 = vec2(imp_data[0][0], imp_data[0][1]);
vec2 uv_f2 = vec2(imp_data[1][0], imp_data[1][1]);
vec2 uv_f3 = vec2(imp_data[2][0], imp_data[2][1]);

vec4 dataTex = blenderColors(uv_f1, uv_f2, uv_f3, quad_blend_weights, %s);
	""" % [
		input_vars[0],
		input_vars[1]
	]
	return (code +
		output_vars[0] + " = dataTex.rgb;" +
		output_vars[1] + " = dataTex.a;")
