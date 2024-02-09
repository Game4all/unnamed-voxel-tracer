
#define MAP_DIMENSION 512

#define CHUNK_DIMENSION 8
#define MAP_CHUNK_DIMENSION (MAP_DIMENSION / CHUNK_DIMENSION)

#define EPSILON 0.001

/// Whether the voxel has a subvoxel model.
#define VOXEL_ATTR_SUBVOXEL (1 << 24)

layout(binding = 9) buffer voxelData {
    uint data[];
};

layout(binding = 10) buffer mapData {
    uint chunks[];
};

layout(binding = 11) buffer models {
    layout(rgba8) image3D model[];
};


uint map_getVoxelRaw(ivec3 pos) {
    uint blk_idx = chunks[((pos.x / CHUNK_DIMENSION) + MAP_CHUNK_DIMENSION * ((pos.y / CHUNK_DIMENSION) + (pos.z / CHUNK_DIMENSION) * MAP_CHUNK_DIMENSION))];

    if (blk_idx > 0) {
        return data[(blk_idx - 1) * CHUNK_DIMENSION * CHUNK_DIMENSION * CHUNK_DIMENSION 
        + (pos.x % CHUNK_DIMENSION) + ((pos.z % CHUNK_DIMENSION) * CHUNK_DIMENSION + (pos.y % CHUNK_DIMENSION)) * CHUNK_DIMENSION ];
    } 
    else
        return 0; 
}

vec4 map_getVoxel(ivec3 pos) {
    return unpackUnorm4x8(map_getVoxelRaw(pos));
}

uint map_getChunkFlags(ivec3 pos) {
    return chunks[pos.x + MAP_CHUNK_DIMENSION * (pos.y + pos.z * MAP_CHUNK_DIMENSION)];
}

struct HitInfo {
    bool is_hit;
    vec3 hit_pos;
    vec3 normal;
};


HitInfo traceMap(in vec3 rayOrigin, in vec3 rayDir, int maxSteps) {
    // add a delta to prevent grid aligned rays
    if (rayDir.x == 0)
        rayDir.x = 0.001;
    if (rayDir.y == 0)
        rayDir.y = 0.001;
    if (rayDir.z == 0)
        rayDir.z = 0.001;


    const ivec3 bounds = ivec3(MAP_DIMENSION);

    const vec3 normals[] = {
        vec3(-1,0,0),
        vec3(1,0,0),
        vec3(0,-1,0),
        vec3(0,1,0),
        vec3(0,0,-1),
        vec3(0,0,1)
    };
    
    ivec3 raySign = ivec3(sign(rayDir));
    ivec3 rayPositivity = (1 + raySign) >> 1;
    vec3 rayInv = 1.0 / rayDir;

    int minIdx = 0;
    vec3 t = vec3(1);

    // map pos
    ivec3 gridsCoords = ivec3(rayOrigin);
    vec3 withinGridCoords = rayOrigin - gridsCoords;

    uint stepSize = 0;

    for (int stepCount = 0; stepCount < maxSteps; stepCount++) {
        if ((!any(greaterThanEqual(gridsCoords, bounds))) && !any(lessThan(gridsCoords, ivec3(0)))) {
            uvec3 pos = uvec3(gridsCoords) + uvec3(withinGridCoords);
            uint chunk_index = map_getChunkFlags(ivec3(pos) >> 3);

            if (chunk_index != 0) 
            {
                uint block = map_getVoxelRaw(ivec3(pos));

                if (block != 0) {
                    uint faceId = 0;
                    if (minIdx == 0)
                        faceId = -rayPositivity.x + 2;
                    if (minIdx == 1)
                        faceId = -rayPositivity.y + 4;
                    if (minIdx == 2)
                        faceId = -rayPositivity.z + 6;

                    return HitInfo(true, vec3(gridsCoords + withinGridCoords), normals[faceId - 1]);
                }
                else
                {
                    if (stepSize != 0) {
                        gridsCoords += ivec3(withinGridCoords);
                        withinGridCoords = fract(withinGridCoords);
                        stepSize = 0;
                    }
                }
            } 
            else
            {
                if (stepSize != 3) {
                    withinGridCoords += gridsCoords & 7;
                    gridsCoords -= gridsCoords & 7;
                    stepSize = 3;
                }
            }

            /// dda stepping
            t = ((rayPositivity << stepSize) - withinGridCoords) * rayInv;
            minIdx = t.x < t.y ? (t.x < t.z ? 0 : 2) : (t.y < t.z ? 1 : 2);

            gridsCoords[minIdx] += int(raySign[minIdx] << stepSize);
            withinGridCoords += rayDir * t[minIdx];
            withinGridCoords[minIdx] = ((1 - rayPositivity[minIdx]) << stepSize) * 0.999f;
        }
        else break;
    }

    return HitInfo(false, vec3(-1.0), vec3(0));
}

// vec4 traceModel()