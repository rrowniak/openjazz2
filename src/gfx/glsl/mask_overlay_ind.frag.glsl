#version 330 core
in vec2 TexCoords;
out vec4 color;

uniform sampler2D image;

void main()
{
    float index = texture(image, TexCoords).r;
    color = vec4(0.5, 0.5, 0.5, (index > 0.0 ? 0.65 : 0.0));
}
