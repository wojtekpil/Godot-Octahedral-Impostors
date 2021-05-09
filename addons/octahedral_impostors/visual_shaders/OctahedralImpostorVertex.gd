tool
extends VisualShaderNodeCustom
class_name VisualShaderNodeOCtaImpVert

func _init() -> void:
	set_input_port_default_value(0, 12)
	set_input_port_default_value(1, false)
	set_input_port_default_value(2, 1.0)
	set_input_port_default_value(3, 0.5)

func _get_name() -> String:
	return "OctahedralImpostorVertex"

func _get_category() -> String:
	return "OctahedralImpostors"

#func _get_subcategory():
#	return ""

func _get_description() -> String:
	return "Vertex shader of octahedral impostor"


func _get_input_port_count() -> int:
	return 5

func _get_input_port_name(port: int):
	match port:
		0:
			return "impostor_frames_xy"
		1:
			return "is_full_sphere"
		2:
			return "scale"
		3:
			return "aabb_max"
		4:
			return "uv_quad"

func _get_input_port_type(port: int):
	match port:
		0:
			return VisualShaderNode.PORT_TYPE_SCALAR
		1:
			return VisualShaderNode.PORT_TYPE_BOOLEAN
		2:
			return VisualShaderNode.PORT_TYPE_SCALAR
		3:
			return VisualShaderNode.PORT_TYPE_SCALAR
		4:
			return VisualShaderNode.PORT_TYPE_VECTOR

func _get_output_port_count() -> int:
	return 4

func _get_output_port_name(port: int):
	match port:
		0:
			return "vertex"
		1:
			return "normal"
		2:
			return "tangent"
		3:
			return "binormal"

func _get_output_port_type(port: int):
	match port:
		0:
			return VisualShaderNode.PORT_TYPE_VECTOR
		1:
			return VisualShaderNode.PORT_TYPE_VECTOR
		2:
			return VisualShaderNode.PORT_TYPE_VECTOR
		3:
			return VisualShaderNode.PORT_TYPE_VECTOR

func _get_global_code(mode: int) -> String:
	return """
varying vec2 uv_frame1;
varying vec2 xy_frame1;
varying flat vec2 frame1;
varying flat vec3 frame1_normal;
varying vec2 uv_frame2;
varying vec2 xy_frame2;
varying flat vec2 frame2;
varying flat vec3 frame2_normal;
varying vec2 uv_frame3;
varying vec2 xy_frame3;
varying flat vec2 frame3;
varying flat vec3 frame3_normal;
varying vec4 quad_blend_weights;
varying vec3 righ_vector;

vec2 VecToSphereOct(vec3 pivotToCamera)
{
	vec3 octant = sign(pivotToCamera);

	//  |x| + |y| + |z| = 1
	float sum = dot(pivotToCamera, octant);
	vec3 octahedron = pivotToCamera / sum;

	if (octahedron.y < 0f)
	{
		vec3 absolute = abs(octahedron);
		octahedron.xz = octant.xz * vec2(1.0f - absolute.z, 1.0f - absolute.x);
	}
	return octahedron.xz;
}

vec2 VecToHemiSphereOct(vec3 pivotToCamera)
{
	pivotToCamera.y = max(pivotToCamera.y, 0.001);
	pivotToCamera = normalize(pivotToCamera);
	vec3 octant = sign(pivotToCamera);

	//  |x| + |y| + |z| = 1
	float sum = dot(pivotToCamera, octant);
	vec3 octahedron = pivotToCamera / sum;

	return vec2(
	octahedron.x + octahedron.z,
	octahedron.z - octahedron.x);
}

vec2 VectorToGrid(vec3 vec, bool is_full_sphere)
{
	if (is_full_sphere)
	{
		return VecToSphereOct(vec);
	}
	else
	{
		return VecToHemiSphereOct(vec);
	}
}

//for sphere
vec3 OctaSphereEnc(vec2 coord)
{
	coord = (coord - 0.5) * 2.0;
	vec3 position = vec3(coord.x, 0f, coord.y);
	vec2 absolute = abs(position.xz);
	position.y = 1f - absolute.x - absolute.y;

	if (position.y < 0f)
	{
		position.xz = sign(position.xz) * vec2(1.0f - absolute.y, 1.0f - absolute.x);
	}

	return position;
}

//for hemisphere
vec3 OctaHemiSphereEnc(vec2 coord)
{	
	//coord = (0, 0.27)
	//pos = -0.27, 0, -0.63
	
	vec3 position = vec3(coord.x - coord.y, 0f, -1.0 + coord.x + coord.y);
	vec2 absolute = abs(position.xz);
	position.y = 1f - absolute.x - absolute.y;
	return position;
}

vec3 GridToVector(vec2 coord, bool is_full_sphere)
{
	if (is_full_sphere)
	{
		return OctaSphereEnc(coord);
	}
	else
	{
		return OctaHemiSphereEnc(coord);
	}
}

vec3 FrameXYToRay(vec2 frame, vec2 frameCountMinusOne, bool is_full_sphere)
{
	//divide frame x y by framecount minus one to get 0-1
	vec2 f = (frame.xy/ frameCountMinusOne);
	//bias and scale to -1 to 1

	vec3 vec = GridToVector(f, is_full_sphere);
	vec = normalize(vec);
	return vec;
}

vec3 SpriteProjection(vec3 pivotToCameraRayLocal, vec2 size, vec2 loc_uv)
{
	vec3 z = normalize(pivotToCameraRayLocal);
	vec3 x, y;
	vec3 up = vec3(0,1,0);
		//cross product doesnt work if we look directly from bottom
	if (abs(z.y) > 0.999f)
	{
		up = vec3(0,0,-1);
	}
	x = normalize(cross(up, z));
	y = normalize(cross(x, z));

	loc_uv -= vec2(0.5,0.5);
	vec2 uv = (loc_uv) * 2.0; //-1 to 1

	vec3 newX = x * uv.x;
	vec3 newY = y * uv.y;

	vec2 vecSize = size * 0.5;

	newX *= vecSize.x;
	newY *= vecSize.y;

	return newX + newY;
}

vec4 quadBlendWieghts(vec2 coords)
{
	vec4 res;
	/* 0 0 0
	0 0 0
	1 0 0 */
	res.x = min(1f - coords.x, 1f - coords.y);
	/* 1 0 0
	0 0 0
	0 0 1 */
	res.y = abs(coords.x - coords.y);
	/* 0 0 1
	0 0 0
	0 0 0 */
	res.z = min(coords.x, coords.y);
	/* 0 0 0
	0 0 1
	0 1 1 */
	res.w = ceil(coords.x - coords.y);
	//res.xyz /= (res.x + res.y + res.z);
	return res;
}


//this function works well in orthogonal projection. It works okeyish with further distances of perspective projection
vec2 virtualPlaneUV(vec3 plane_normal,vec3  plane_x, vec3  plane_y, vec3 pivotToCameraRay, vec3 vertexToCameraRay, float size)
{
	plane_normal = normalize(plane_normal);
	plane_x = normalize(plane_x);
	plane_y = normalize(plane_y);

	// plane_normal is normalized but pivotToCameraRay & vertexToCameraRay are NOT
	// so what are we doing here ?
	// We are calculating length of pivotToCameraRay projected onto plane_normal
	// so pivotToCameraRay is vector to camera from CENTER OF object
	// we are recalculting this distance taking into account new plane normal
	float projectedNormalRayLength = dot(plane_normal, pivotToCameraRay);
	// tihs is direction is almost the same as origin, but its to individual vertex
	// not sure this is correct for perspective projection
	float projectedVertexRayLength = dot(plane_normal, vertexToCameraRay);
	// basically its length difference betwen center and vertex - 'not precise'
	// projectedVertexRayLength is bigger than projectedNormalRayLength when vertex is
	// further than 'main front facing billboard'
	// so offsetLength is getting smaller, otherwise is getting bigger
	float offsetLength = projectedNormalRayLength/projectedVertexRayLength;

	// ok so offsetLength is just a length 
	// we want a vector so we multiply it by vertexToCameraRay to get this offset
	// now what are we REALY doing is calculuating distance difference
	// se are SUBSTRACTING pivotToCameraRay vector
	// we would get difference between center of plane and vertex rotated
	vec3 offsetVector = vertexToCameraRay * offsetLength - pivotToCameraRay;

	// we got the offset of rotated vertex, but we need to offset it from correct plane axis
	// so again we projecting length of intersection (offset of rotated vertex) onto plane_x 
	// and plane_y
	vec2 duv = vec2(
				dot(plane_x , offsetVector),
				dot(plane_y, offsetVector)
	);

	//we are in space -1 to 1
	duv /= 2.0 * size;
	duv += 0.5;
	return duv;
}

void calcuateXYbasis(vec3 plane_normal, out vec3 plane_x, out vec3 plane_y)
{
	vec3 up = vec3(0,1,0);
		//cross product doesnt work if we look directly from bottom
	if (abs(plane_normal.y) > 0.999f)
	{
		up = vec3(0,0,1);
	}
	plane_x = normalize(cross(plane_normal, up));
	plane_y = normalize(cross(plane_x, plane_normal));
}

vec3 projectOnPlaneBasis(vec3 ray, vec3 plane_normal, vec3 plane_x, vec3 plane_y)
{
	//reproject plane normal onto planeXY basos
	return normalize(vec3( 
		dot(plane_x,ray), 
		dot(plane_y,ray), 
		dot(plane_normal,ray) 
	));
}
	"""

func _get_code(input_vars: Array, output_vars: Array, mode: int, type: int) -> String:
	var uv = "UV"
	if input_vars[4]:
		uv = input_vars[4]
	var code = """
righ_vector = WORLD_MATRIX[0].xyz;
vec2 _imposterFrames = vec2(%s);
bool _isFullSphere = %s;
float _scale = %s;
float _aabb_max = %s;
vec2 _uv = %s.xy;
vec2 framesMinusOne = _imposterFrames - vec2(1);
vec3 cameraPos_WS = (CAMERA_MATRIX * vec4(vec3(0), 1.0)).xyz;
vec3 cameraPos_OS = (inverse(WORLD_MATRIX) * vec4(cameraPos_WS, 1.0)).xyz;

//TODO: check if this is correct. We are using orho projected images, so
// camera far away
vec3 pivotToCameraRay = (cameraPos_OS) * 10.0;
vec3 pivotToCameraDir = normalize(cameraPos_OS);

vec2 grid = VectorToGrid(pivotToCameraDir, _isFullSphere);
//bias and scale to 0 to 1
grid = clamp((grid + 1.0) * 0.5, vec2(0, 0), vec2(1, 1));
grid *= framesMinusOne;
grid = clamp(grid, vec2(0), vec2(framesMinusOne));
vec2 gridFloor = min(floor(grid), framesMinusOne);
vec2 gridFract = fract(grid);

//radius * 2
vec2 size = vec2(2.0) * _scale;
vec3 projected = SpriteProjection(pivotToCameraDir, size, _uv);
vec3 vertexToCameraRay = (pivotToCameraRay - (projected));
vec3 vertexToCameraDir = normalize(vertexToCameraRay);

frame1 = gridFloor;
quad_blend_weights = quadBlendWieghts(gridFract);
//convert frame coordinate to octahedron direction
vec3 projectedQuadADir = FrameXYToRay(frame1, framesMinusOne, _isFullSphere);

frame2 = clamp(frame1 + mix(vec2(0, 1), vec2(1, 0), quad_blend_weights.w), vec2(0,0), framesMinusOne);
vec3 projectedQuadBDir = FrameXYToRay(frame2, framesMinusOne, _isFullSphere);

frame3 = clamp(frame1 + vec2(1), vec2(0,0), framesMinusOne);
vec3 projectedQuadCDir = FrameXYToRay(frame3, framesMinusOne, _isFullSphere);

frame1_normal = (MODELVIEW_MATRIX *vec4(projectedQuadADir, 0)).xyz;
frame2_normal = (MODELVIEW_MATRIX *vec4(projectedQuadBDir, 0)).xyz;
frame3_normal = (MODELVIEW_MATRIX *vec4(projectedQuadCDir, 0)).xyz;

//calcute virtual planes projections
vec3 plane_x1, plane_y1, plane_x2, plane_y2, plane_x3, plane_y3;
calcuateXYbasis(projectedQuadADir, plane_x1, plane_y1);
uv_frame1 = virtualPlaneUV(projectedQuadADir, plane_x1, plane_y1, pivotToCameraRay, vertexToCameraRay, _scale);
xy_frame1 = projectOnPlaneBasis(-vertexToCameraDir, projectedQuadADir, plane_x1, plane_y1).xy;

calcuateXYbasis(projectedQuadBDir, plane_x2, plane_y2);
uv_frame2 = virtualPlaneUV(projectedQuadBDir, plane_x2, plane_y2, pivotToCameraRay, vertexToCameraRay, _scale);
xy_frame2 = projectOnPlaneBasis(-vertexToCameraDir, projectedQuadBDir, plane_x2, plane_y2).xy;

calcuateXYbasis(projectedQuadCDir, plane_x3, plane_y3);
uv_frame3 = virtualPlaneUV(projectedQuadCDir, plane_x3, plane_y3, pivotToCameraRay, vertexToCameraRay, _scale);
xy_frame3 = projectOnPlaneBasis(-vertexToCameraDir, projectedQuadCDir, plane_x3, plane_y3).xy;

//to fragment shader
projected += pivotToCameraDir* _aabb_max;
vec3 _normal = normalize(pivotToCameraDir);
vec3 _tangent = normalize(cross(_normal,vec3(0.0, 1.0, 0.0)));
vec3 _bitangent = normalize(cross(_tangent,_normal));
	""" % [ 
		input_vars[0], input_vars[1],
		input_vars[2], input_vars[3],
		uv
	]
	return ( code +
		output_vars[0] + " = projected;" +
		output_vars[1] + " = _normal;" +
		output_vars[2] + " = _tangent;" +
		output_vars[3] + " = _bitangent;" )