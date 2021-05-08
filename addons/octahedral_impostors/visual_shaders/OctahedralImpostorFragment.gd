tool
extends VisualShaderNodeCustom
class_name VisualShaderNodeOCtaImpFrag

func _init() -> void:
	set_input_port_default_value(3, 1.0)
	set_input_port_default_value(4, 12)

func _get_name() -> String:
	return "OctahedralImpostorFragment"

func _get_category() -> String:
	return "OctahedralImpostors"

#func _get_subcategory():
#	return ""

func _get_description() -> String:
	return "Fragment shader of octahedral impostor"


func _get_input_port_count() -> int:
	return 5

func _get_input_port_name(port: int):
	match port:
		0:
			return "albedo_atlas"
		1:
			return "depth_atlas"
		2:
			return "normal_atlas"
		3:
			return "depth_scale"
		4:
			return "impostor_frames_xy"

func _get_input_port_type(port: int):
	match port:
		0:
			return VisualShaderNode.PORT_TYPE_SAMPLER
		1:
			return VisualShaderNode.PORT_TYPE_SAMPLER
		2:
			return VisualShaderNode.PORT_TYPE_SAMPLER
		3:
			return VisualShaderNode.PORT_TYPE_SCALAR
		4:
			return VisualShaderNode.PORT_TYPE_SCALAR

func _get_output_port_count() -> int:
	return 3

func _get_output_port_name(port: int):
	match port:
		0:
			return "albedo"
		1:
			return "alpha"
		2:
			return "normal"

func _get_output_port_type(port: int):
	match port:
		0:
			return VisualShaderNode.PORT_TYPE_VECTOR
		1:
			return VisualShaderNode.PORT_TYPE_SCALAR
		2:
			return VisualShaderNode.PORT_TYPE_VECTOR

func _get_global_code(mode: int) -> String:
	return """
vec4 blenderColors(vec2 uv_1, vec2 uv_2, vec2 uv_3, vec4 grid_weights, sampler2D atlasTexture)
{
	vec4 quad_a, quad_b, quad_c;
	
	quad_a = textureLod(atlasTexture, uv_1, 0.0f);
	quad_b = textureLod(atlasTexture, uv_2, 0.0f);
	quad_c = textureLod(atlasTexture, uv_3, 0.0f);
	//return quad_a;
	return quad_a * grid_weights.x + quad_b * grid_weights.y + quad_c * grid_weights.z;
}

vec3 normal_from_normalmap(vec4 normalTex, vec3 tangent, vec3 binormal, vec3 f_norm)
{
	vec3 normalmap;
	normalmap.xy = normalTex.xy * 2.0 - 1.0;
	normalmap.z = sqrt(max(0.0, 1.0 - dot(normalmap.xy, normalmap.xy)));
	normalmap = normalize(normalmap);
	return normalize(tangent * normalmap.x + binormal * normalmap.y + f_norm * normalmap.z);
}

vec3 blendedNormals(vec2 uv_1, vec3 f1_n, 
					vec2 uv_2, vec3 f2_n, 
					vec2 uv_3, vec3 f3_n, 
					vec3 tangent, vec3 binormal,
					vec4 grid_weights, sampler2D atlasTexture)
{
	vec4 quad_a, quad_b, quad_c;
	
	quad_a = textureLod(atlasTexture, uv_1, 0.0f);
	quad_b = textureLod(atlasTexture, uv_2, 0.0f);
	quad_c = textureLod(atlasTexture, uv_3, 0.0f);
	vec3 norm1 = normal_from_normalmap(quad_a, tangent, binormal, f1_n);
	vec3 norm2 = normal_from_normalmap(quad_b, tangent, binormal, f2_n);
	vec3 norm3 = normal_from_normalmap(quad_c, tangent, binormal, f3_n);
	return normalize(norm1 * grid_weights.x + norm2 * grid_weights.y + norm3 * grid_weights.z);
}

vec2 recalculateUV(vec2 uv_f,  vec2 frame, vec2 xy_f, vec2 frame_size, float d_scale, sampler2D depthTexture)
{
	//clamp for parallax sampling
	uv_f = clamp(uv_f, vec2(0), vec2(1));
	vec2 uv_quad = frame_size * (frame + uv_f);
	//paralax
	vec4 n_depth = (textureLod( depthTexture, uv_quad, 0 ));
	uv_f = xy_f * (0.5-n_depth.r) * d_scale + uv_f;
	//clamp parallax offset
	uv_f = clamp(uv_f, vec2(0), vec2(1));
	uv_f =  frame_size * (frame + uv_f);
	//clamped full UV
	return clamp(uv_f, vec2(0), vec2(1));
}
	"""

func _get_code(input_vars: Array, output_vars: Array, mode: int, type: int) -> String:
	var code = """
vec2 quad_size = vec2(1f) / %s;
float _depth_scale = %s;
vec2 uv_f1 = recalculateUV(uv_frame1, frame1, xy_frame1, quad_size, _depth_scale, %s);
vec2 uv_f2 = recalculateUV(uv_frame2, frame2, xy_frame2, quad_size, _depth_scale, %s);
vec2 uv_f3 = recalculateUV(uv_frame3, frame3, xy_frame3, quad_size, _depth_scale, %s);

vec4 baseTex = blenderColors(uv_f1, uv_f2,  uv_f3, quad_blend_weights, %s);
vec3 normalTex = blendedNormals(uv_f1, frame1_normal,
								uv_f2, frame2_normal, 
								uv_f3, frame3_normal,
								TANGENT, BINORMAL,
								quad_blend_weights, %s);
	""" % [
		input_vars[4],
		input_vars[3], 
		input_vars[1],
		input_vars[1],
		input_vars[1],
		input_vars[0],input_vars[2] 
	]
	return (code +
		output_vars[0] + " = baseTex.rgb;" +
		output_vars[1] + " = baseTex.a;" +
		output_vars[2] + " = normalTex.xyz;" )