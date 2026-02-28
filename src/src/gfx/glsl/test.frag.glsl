#version 330 core

out vec4 final_color;
uniform vec4 color;

void main() {
    final_color = color;
    // final_color = vec4(1.0, 0.5, 0.2, 1.0);
    // gl_FragColor = vec4(1.0, 0.5, 0.2, 1.0);
}

