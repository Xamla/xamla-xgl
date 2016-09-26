#version 330 core

struct Material {
  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
  float shininess;
  float opacity;
}; 
  
uniform Material material;

in vec2 TexCoords;
in vec4 VertexColor;
out vec4 color;

uniform sampler2D texture_diffuse1;

void main()
{
  color = texture(texture_diffuse1, TexCoords) + VertexColor;
  color[3] = color[3] * material.opacity;
}
