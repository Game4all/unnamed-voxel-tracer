
#define MAP_DIMENSION 256

#define CHUNK_DIMENSION 8
#define MAP_CHUNK_DIMENSION 32

layout(binding = 2) buffer voxelData {
    uint data[];
};

layout(binding = 3) buffer mapData {
    uint chunks[];
};

vec4 map_getVoxel(ivec3 pos) {
    if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, ivec3(MAP_DIMENSION))))
        return vec4(0.);

    return unpackUnorm4x8(data[pos.x + MAP_DIMENSION * (pos.y + pos.z * MAP_DIMENSION)]);
}

uint map_getChunkFlags(ivec3 pos) {
    if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, ivec3(MAP_CHUNK_DIMENSION))))
        return 0;

    const ivec3 chPos = pos;

    return chunks[chPos.x + MAP_CHUNK_DIMENSION * (pos.y + pos.z * MAP_CHUNK_DIMENSION)];
}

