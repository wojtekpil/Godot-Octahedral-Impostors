shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 albedo : hint_color = vec4(1, 1, 1, 1);
uniform float specular = 0.5f;
uniform float metallic = 0f;
uniform float roughness : hint_range(0, 1) = 1f;

uniform sampler2D imposterTextureAlbedo : hint_albedo;
uniform sampler2D imposterTextureNormal : hint_normal;
uniform sampler2D imposterTextureDepth : hint_white;
uniform vec2 imposterFrames = vec2(16f, 16f);
uniform vec3 positionOffset = vec3(0f);
uniform bool isFullSphere = true;
uniform float alpha_clamp = 0.5f;
uniform bool dither = false;
uniform float scale = 1.0f;
uniform float depth_scale : hint_range(0, 1) = 1.0f;
uniform float normalmap_depth : hint_range(-5, 5)  = 1.0f;
uniform float aabb_max = 1.0;

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
	//coord = (0, 0.27)
	//pos = -0.27, 0, -0.63
	
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
	vec2 f = (frame.xy/ frameCountMinusOne);
	//bias and scale to -1 to 1

	vec3 vec = GridToVector(f);
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
	// basically its length difference betwen center and vertex - "not precise"
	// projectedVertexRayLength is bigger than projectedNormalRayLength when vertex is
	// further than "main front facing billboard"
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

void vertex()
{
	vec2 framesMinusOne = imposterFrames - vec2(1);
	vec3 cameraPos_WS = (CAMERA_MATRIX * vec4(vec3(0), 1.0)).xyz;
	vec3 cameraPos_OS = (inverse(WORLD_MATRIX) * vec4(cameraPos_WS, 1.0)).xyz;

	//TODO: check if this is correct. We are using orho projected images, so
	// camera far away
	vec3 pivotToCameraRay = (cameraPos_OS) * 10.0;
	vec3 pivotToCameraDir = normalize(cameraPos_OS);
	
	vec2 grid = VectorToGrid(pivotToCameraDir);
	//bias and scale to 0 to 1
	grid = clamp((grid + 1.0) * 0.5, vec2(0, 0), vec2(1, 1));
	grid *= framesMinusOne;
	grid = clamp(grid, vec2(0), vec2(framesMinusOne));
	vec2 gridFloor = min(floor(grid), framesMinusOne);
	vec2 gridFract = fract(grid);
	
	//radius * 2
	vec2 size = vec2(2.0) * scale;
	vec3 projected = SpriteProjection(pivotToCameraDir, size, UV);
	vec3 vertexToCameraRay = (pivotToCameraRay - (projected));
	vec3 vertexToCameraDir = normalize(vertexToCameraRay);
	
	frame1 = gridFloor;
	quad_blend_weights = quadBlendWieghts(gridFract);
	//convert frame coordinate to octahedron direction
	vec3 projectedQuadADir = FrameXYToRay(frame1, framesMinusOne);
	
	frame2 = clamp(frame1 + mix(vec2(0, 1), vec2(1, 0), quad_blend_weights.w), vec2(0,0), framesMinusOne);
	vec3 projectedQuadBDir = FrameXYToRay(frame2, framesMinusOne);
	
	frame3 = clamp(frame1 + vec2(1), vec2(0,0), framesMinusOne);
	vec3 projectedQuadCDir = FrameXYToRay(frame3, framesMinusOne);

	frame1_normal = (MODELVIEW_MATRIX *vec4(projectedQuadADir, 0)).xyz;
	frame2_normal = (MODELVIEW_MATRIX *vec4(projectedQuadBDir, 0)).xyz;
	frame3_normal = (MODELVIEW_MATRIX *vec4(projectedQuadCDir, 0)).xyz;

	//calcute virtual planes projections
	vec3 plane_x1, plane_y1, plane_x2, plane_y2, plane_x3, plane_y3;
	calcuateXYbasis(projectedQuadADir, plane_x1, plane_y1);
	uv_frame1 = virtualPlaneUV(projectedQuadADir, plane_x1, plane_y1, pivotToCameraRay, vertexToCameraRay, scale);
	xy_frame1 = projectOnPlaneBasis(-vertexToCameraDir, projectedQuadADir, plane_x1, plane_y1).xy;

	calcuateXYbasis(projectedQuadBDir, plane_x2, plane_y2);
	uv_frame2 = virtualPlaneUV(projectedQuadBDir, plane_x2, plane_y2, pivotToCameraRay, vertexToCameraRay, scale);
	xy_frame2 = projectOnPlaneBasis(-vertexToCameraDir, projectedQuadBDir, plane_x2, plane_y2).xy;
	
	calcuateXYbasis(projectedQuadCDir, plane_x3, plane_y3);
	uv_frame3 = virtualPlaneUV(projectedQuadCDir, plane_x3, plane_y3, pivotToCameraRay, vertexToCameraRay, scale);
	xy_frame3 = projectOnPlaneBasis(-vertexToCameraDir, projectedQuadCDir, plane_x3, plane_y3).xy;

	//to fragment shader
	VERTEX.xyz = projected + positionOffset;
	VERTEX.xyz +=pivotToCameraDir* aabb_max;

	NORMAL = normalize(pivotToCameraDir);
	TANGENT= normalize(cross(NORMAL,vec3(0.0, 1.0, 0.0)));
	BINORMAL = normalize(cross(TANGENT,NORMAL));
}

vec4 blenderColors(vec2 uv_1, vec2 uv_2, vec2 uv_3, vec4 grid_weights, sampler2D atlasTexture)
{
	vec4 quad_a, quad_b, quad_c;
	
	quad_a = textureLod(atlasTexture, uv_1, 0.0f);
	quad_b = textureLod(atlasTexture, uv_2, 0.0f);
	quad_c = textureLod(atlasTexture, uv_3, 0.0f);
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

void fragment()
{
	vec2 quad_size = vec2(1f) / imposterFrames;
	vec2 uv_f1 = recalculateUV(uv_frame1, frame1, xy_frame1, quad_size, depth_scale, imposterTextureDepth);
	vec2 uv_f2 = recalculateUV(uv_frame2, frame2, xy_frame2, quad_size, depth_scale, imposterTextureDepth);
	vec2 uv_f3 = recalculateUV(uv_frame3, frame3, xy_frame3, quad_size, depth_scale, imposterTextureDepth);

	vec4 baseTex = blenderColors(uv_f1, uv_f2,  uv_f3, quad_blend_weights, imposterTextureAlbedo);
	vec3 normalTex = blendedNormals(uv_f1, frame1_normal,
									uv_f2, frame2_normal,
									uv_f3, frame3_normal,
									TANGENT, BINORMAL,
									 quad_blend_weights, imposterTextureNormal);
	ALBEDO = baseTex.rgb * albedo.rgb;
	NORMAL =normalTex.xyz;
	
	if(dither)
	{
		float opacity =  baseTex.a;
		int x = int(FRAGCOORD.x) % 4;
		int y = int(FRAGCOORD.y) % 4;
		int index = x + y * 4;
		float limit = 0.0;
		if (x < 8) {
			if (index == 0) limit = 0.0625;
			if (index == 1) limit = 0.5625;
			if (index == 2) limit = 0.1875;
			if (index == 3) limit = 0.6875;
			if (index == 4) limit = 0.8125;
			if (index == 5) limit = 0.3125;
			if (index == 6) limit = 0.9375;
			if (index == 7) limit = 0.4375;
			if (index == 8) limit = 0.25;
			if (index == 9) limit = 0.75;
			if (index == 10) limit = 0.125;
			if (index == 11) limit = 0.625;
			if (index == 12) limit = 1.0;
			if (index == 13) limit = 0.5;
			if (index == 14) limit = 0.875;
			if (index == 15) limit = 0.375;
		}
		// Is this pixel below the opacity limit? Skip drawing it
		if (opacity < limit * alpha_clamp)
		discard;
	}
	else {
		ALPHA = float(baseTex.a>alpha_clamp);
		ALPHA_SCISSOR = 0.5;
	}
	METALLIC = metallic;
	SPECULAR = specular;
	ROUGHNESS = roughness;
}
