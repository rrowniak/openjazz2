#version 330 core
in vec2 TexCoords;
out vec4 color;

uniform sampler1D palette;
uniform sampler2D image;
uniform vec3 spriteColor;

void main()
{    
    float index = texture(image, TexCoords).r;
    color = vec4(spriteColor, 1.0) * texture(palette, index);
    // jj2 palettes seems to miss an alpha channel so we have to
    // fix that in-place
    if (index == 0) {
        color.w = 0.0;
    } else {
        color.w = 1.0;
    }
}

