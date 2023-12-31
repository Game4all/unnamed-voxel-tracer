

/// Initalizes the variables required for DDA
void dda_init(in vec3 rayOrigin, in vec3 rayDir, out ivec3 mapPos, out vec3 deltaDist, out ivec3 rayStep, out vec3 sideDist, out bvec3 mask) {
    mapPos = ivec3(floor(rayOrigin.xyz + 0.));
    deltaDist = abs(vec3(length(rayDir.xyz)) / rayDir.xyz);
    rayStep = ivec3(sign(rayDir.xyz));
    sideDist = (sign(rayDir.xyz) * (vec3(mapPos) - rayOrigin.xyz) + (sign(rayDir.xyz) * 0.5) + 0.5) * deltaDist;
    mask = bvec3(false);
}

void dda_step(inout ivec3 mapPos, inout vec3 deltaDist, in ivec3 rayStep, inout vec3 sideDist, inout bvec3 mask) {
    mask = lessThanEqual(sideDist.xyz, min(sideDist.yzx, sideDist.zxy));			
	sideDist += vec3(mask) * deltaDist;
	mapPos += ivec3(vec3(mask)) * rayStep;
}

float dda_distance(in vec3 rayDir, in vec3 deltaDist, in vec3 sideDist, in bvec3 mask) {
    return length(vec3(mask) * (sideDist - deltaDist)) / length(rayDir);
}

vec2 intersectAABB(vec3 rayOrigin, vec3 rayDir, vec3 boxMin, vec3 boxMax) {
    vec3 tMin = (boxMin - rayOrigin) / rayDir;
    vec3 tMax = (boxMax - rayOrigin) / rayDir;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    return vec2(tNear, tFar);
};