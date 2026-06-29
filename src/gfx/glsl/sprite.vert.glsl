#version 330 core
layout (location = 0) in vec4 vertex; // <vec2 position, vec2 texCoords>

out vec2 TexCoords;

uniform vec2 pos;
uniform vec2 spriteSize;
uniform mat4 view;
uniform mat4 projection;

void main()
{
    TexCoords = vertex.zw;
    vec2 vertexPos = vertex.xy * spriteSize + pos;
    gl_Position = projection * view * vec4(vertexPos, 0.0, 1.0);
}
