#version 330 core

struct Material {
  //vec3 ambient;
  vec3 diffuse;
  //vec3 specular;
  float shininess;
  float opacity;
}; 
  
uniform Material material;


uniform vec3 lightPos;
uniform vec3 lightColor;
uniform vec3 viewPos;

out vec4 color;

in vec4 VertexColor;
in vec3 FragPos;
in vec3 Normal;

void main() {
  // Ambient
  float ambientStrength = 0.2f;
  vec3 ambient = ambientStrength * lightColor;

  // Diffuse
  vec3 norm = normalize(Normal);
  vec3 lightDir = normalize(lightPos - FragPos);
  float diff = max(dot(norm, lightDir), 0.0);
  vec3 diffuse = diff * lightColor;

  // Specular
  float specularStrength = 0.5f;
  vec3 viewDir = normalize(viewPos - FragPos);
  vec3 reflectDir = reflect(-lightDir, norm);
  float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
  vec3 specular = specularStrength * spec * lightColor;

  vec3 result = (ambient + diffuse + specular) * mix(material.diffuse, vec3(VertexColor), VertexColor[3]);
  color = vec4(result, material.opacity);
}
