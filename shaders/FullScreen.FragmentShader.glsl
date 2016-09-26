#version 330 core

in vec2 textureCoord;
out vec4 color;

uniform sampler2D texture_diffuse1;

void main() {
   vec4 color1 = texture2D(texture_diffuse1, textureCoord);
   gl_FragColor = color1;
}
