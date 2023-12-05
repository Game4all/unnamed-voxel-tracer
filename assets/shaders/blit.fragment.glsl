#version 450

#define DEBUG_NORMALS 1

layout(binding = 0) uniform sampler2D frameColor;
layout(binding = 1) uniform sampler2D frameNormals;
layout(binding = 2) uniform sampler2D framePositions;

layout(location = 0) in vec2 texPos;

out vec4 fragColor;

void main() {
    vec4 color = texture(frameColor, texPos);
    fragColor = vec4(color.xyz,  1.0);
}