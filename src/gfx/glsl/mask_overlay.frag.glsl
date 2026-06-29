#version 330 core
in vec2 TexCoords;
out vec4 color;

uniform sampler2D image;

void main()
{
    vec4 tex = texture(image, TexCoords);
    color = vec4(0.5, 0.5, 0.5, tex.a * 0.65);
}
