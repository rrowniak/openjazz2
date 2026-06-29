#version 330 core
in vec2 TexCoords;
out vec4 color;

uniform sampler2D image;

void main()
{
    vec4 tex = texture(image, TexCoords);
    color = vec4(0.0, 1.0, 0.0, tex.a * 0.45);
}
