shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 albedo : hint_color = vec4(1, 1, 1, 1);
uniform float specular = 0.5f;
uniform float metallic = 0f;
uniform float roughness : hint_range(0, 1) = 1f;

uniform sampler2DArray imposterBaseTexture : hint_albedo;
uniform sampler2DArray imposterNormalDepthTexture : hint_albedo;
uniform sampler2DArray imposterORMTexture : hint_albedo;
uniform vec2 imposterFrames = vec2(16f, 16f);
uniform vec3 positionOffset = vec3(0f);
uniform bool isFullSphere = true;
uniform bool isTransparent = true;
uniform float alpha_clamp = 0.5f;
uniform float scale = 1.0f;
uniform float depth_scale = 0.05f;
uniform float normalmap_depth = 1.0f;

varying flat vec2 grid_classic;
varying vec4 quad_blend_weights;

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
	vec3 octant = sign(pivotToCamera);

	//  |x| + |y| + |z| = 1
	float sum = dot(pivotToCamera, octant);
	vec3 octahedron = pivotToCamera / sum;

	return vec2(
	octahedron.x + octahedron.z,
	octahedron.z - octahedron.x);
}

vec2 VectorToGrid(vec3 vec)
{
	if (isFullSphere)
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
	vec3 position = vec3(coord.x - coord.y, 0f, -1.0 + coord.x + coord.y);
	vec2 absolute = abs(position.xz);
	position.y = 1f - absolute.x - absolute.y;

	return position;
}

vec3 GridToVector(vec2 coord)
{
	if (isFullSphere)
	{
		return OctaSphereEnc(coord);
	}
	else
	{
		return OctaHemiSphereEnc(coord);
	}
}

vec3 FrameXYToRay(vec2 frame, vec2 frameCountMinusOne)
{
	//divide frame x y by framecount minus one to get 0-1
	vec2 f = frame.xy / frameCountMinusOne;
	//bias and scale to -1 to 1

	vec3 vec = GridToVector(f);
	vec = normalize(vec);
	return vec;
}

vec3 SpriteProjection(vec3 pivotToCameraRayLocal, float frames, vec2 size, vec2 coord)
{
	vec3 z = normalize(pivotToCameraRayLocal);
	vec3 x, y;
	x = normalize(cross(vec3(0.0, 1.0, 0.0), z));
	y = normalize(cross(x, z));
	//cross product doesnt work if we look directly from bottom
	if (z.y < -.9999f)
	{
		x = vec3(1, 0, 0);
		y = vec3(0, 0, -1);
	}

	vec2 uv = ((coord * frames) - 0.5) * 2.0; //-1 to 1

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
	res.xyz /= (res.x + res.y + res.z);
	return res;
}

void vertex()
{

	vec2 framesMinusOne = imposterFrames - vec2(1);
	vec3 cameraPos_WS = (CAMERA_MATRIX * vec4(vec3(0), 1.0)).xyz;
	vec3 cameraPos_OS = (inverse(WORLD_MATRIX) * vec4(cameraPos_WS, 1.0)).xyz;

	vec3 pivotToCameraRay = normalize(cameraPos_OS);

	vec2 grid = VectorToGrid(pivotToCameraRay);
	//bias and scale to 0 to 1
	grid = clamp((grid + 1.0) * 0.5, vec2(0, 0), vec2(1, 1));
	grid *= framesMinusOne;
	vec2 gridFloor = floor(grid);
	quad_blend_weights = quadBlendWieghts(fract(grid));
	vec2 texcoord = UV * (1.0 / imposterFrames.x);

	//radius * 2
	vec2 size = vec2(2.0) * scale;
	vec2 projectedFrame = gridFloor;
	//convert frame coordinate to octahedron direction
	vec3 projectedQuadARray = FrameXYToRay(projectedFrame, framesMinusOne);
	vec3 projectedQuadBRray = FrameXYToRay(projectedFrame + mix(vec2(0, 1), vec2(1, 0), quad_blend_weights.w), framesMinusOne);
	vec3 projectedQuadCRray = FrameXYToRay(projectedFrame + vec2(1), framesMinusOne);
	vec3 projectedQuadRay = projectedQuadARray * quad_blend_weights.x +
	projectedQuadBRray * quad_blend_weights.y +
	projectedQuadCRray * quad_blend_weights.z;
	vec3 projected = SpriteProjection(normalize(projectedQuadRay), imposterFrames.x, size, texcoord.xy);
	
	VERTEX.xyz = projected + positionOffset;
	grid_classic = gridFloor;
	NORMAL = normalize(projectedQuadRay);
	TANGENT = cross(NORMAL,vec3(0,0,-1));
	BINORMAL = cross(TANGENT, NORMAL);
}

vec4 blendedColor(vec2 uv, vec2 grid_pos, vec4 grid_weights, sampler2DArray atlasTexture)
{
	vec4 res;
	vec2 layer_quad_a =  grid_pos;
	vec2 layer_quad_b = layer_quad_a + mix(vec2(0, 1), vec2(1, 0), quad_blend_weights.w);
	vec2 layer_quad_c = layer_quad_a + vec2(1,1);

	vec4 quad_a, quad_b, quad_c;
	quad_a = texture(atlasTexture, vec3(uv, layer_quad_a.y*imposterFrames.x+layer_quad_a.x));
	quad_b = texture(atlasTexture, vec3(uv, layer_quad_b.y*imposterFrames.x+layer_quad_b.x));
	quad_c = texture(atlasTexture, vec3(uv, layer_quad_c.y*imposterFrames.x+layer_quad_c.x));
	res = quad_a * grid_weights.x + quad_b * grid_weights.y + quad_c * grid_weights.z;
	return res;
}

void fragment()
{
	vec2 base_uv = UV;
	
	vec3 view_dir = normalize(normalize(-VERTEX)*mat3(TANGENT,-BINORMAL,NORMAL));
	float depth = blendedColor(base_uv, grid_classic, quad_blend_weights, imposterNormalDepthTexture).a;
	base_uv -= view_dir.xy / view_dir.z * (depth * depth_scale);
	
	vec4 baseTex;
	vec4 normalTex;
	vec4 ormTex;
	baseTex = blendedColor(base_uv, grid_classic, quad_blend_weights, imposterBaseTexture);
	normalTex = blendedColor(base_uv, grid_classic, quad_blend_weights, imposterNormalDepthTexture);
	ormTex = blendedColor(base_uv, grid_classic, quad_blend_weights, imposterORMTexture);

	baseTex.a = clamp(pow(baseTex.a, alpha_clamp), 0f, 1f);

	
	if (baseTex.a - alpha_clamp < 0f)
	{
		discard;
	}
	

	ALBEDO = baseTex.rgb * albedo.rgb;
	ALPHA = mix(1.0f,baseTex.a,float(isTransparent));
	NORMALMAP = normalTex.xyz;
	NORMALMAP_DEPTH = normalmap_depth;
	METALLIC = ormTex.b * metallic;
	SPECULAR = specular;
	ROUGHNESS = ormTex.g * roughness;
}
