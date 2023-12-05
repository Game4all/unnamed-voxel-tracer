#version 450

layout(location = 0) out vec2 texPosition;

void main() {
    vec2 vertices[4] = vec2[](
        vec2(-1.0, -1.0),
        vec2( 1.0, -1.0),
        vec2(-1.0,  1.0),
        vec2( 1.0,  1.0)
    );

    gl_Position = vec4(vertices[gl_VertexID], 0.0, 1.0);
    texPosition = (vertices[gl_VertexID] + vec2(1.0)) * 0.5;
}