#pragma once


struct Texture {
  GLuint id;
  std::string type;
  aiString path;
};


class Material {
public:
  Material()
   : diffuseColor(0.7f, 0.7f, 0.7f, 1.0f)
   , opacity(1)
   , facetCulling(false)
   , depthTest(true)
   , depthWrite(true)
   , shininess(16.0f) {
  }

  const glm::vec4& getDiffuseColor() const { return diffuseColor; }
  void setDiffuseColor(const glm::vec4& color) { this->diffuseColor = color; }

  std::shared_ptr<Shader> getShader() const { return shader; }
  void setShader(const std::shared_ptr<Shader>& shader) { this->shader = shader; }

  void addTexture(const Texture& texture) { textures.push_back(texture); }
  
  template<typename TIter>
  void addTextures(TIter begin, TIter end) {
    textures.insert(textures.end(), begin, end);
  }
  
  float getShininess() const { return shininess; }
  void setShininess(float value) { shininess = value; }
  
  float getOpacity() const { return opacity; }
  void setOpacity(float value) { opacity = value; }
  
  bool getFacetCulling() const { return facetCulling; }
  void setFacetCulling(bool value) { facetCulling = value; }
  
  bool getDepthTest() const { return depthTest; }
  void setDepthTest(bool value) { depthTest = value; }
  
  bool getDepthWrite() const { return depthWrite; }
  void setDepthWrite(bool value) { depthWrite = value; }

  void bind() const {
    if (!shader)
      return;
      
    shader->use();

    // Bind appropriate textures
    GLuint diffuse_index = 1;
    GLuint specular_index = 1;
    
    for (GLuint i = 0; i < textures.size(); ++i) {
      glActiveTexture(GL_TEXTURE0 + i); // Active proper texture unit before binding
      // Retrieve texture number (the N in diffuse_textureN)
      std::stringstream ss;
      std::string number;
      std::string name = textures[i].type;

      if (name == "texture_diffuse")
        ss << diffuse_index++; // Transfer GLuint to stream
      else if (name == "texture_specular")
        ss << specular_index++; // Transfer GLuint to stream
      number = ss.str();

      // Now set the sampler to the correct texture unit
      auto samplerName = name + number;
      glUniform1i(glGetUniformLocation(shader->getProgram(), samplerName.c_str()), i);

      // And finally bind the texture
      glBindTexture(GL_TEXTURE_2D, textures[i].id);
    }

    glUniform3fv(glGetUniformLocation(shader->getProgram(), "material.diffuse"), 1, glm::value_ptr(diffuseColor));
    glUniform1f(glGetUniformLocation(shader->getProgram(), "material.shininess"), this->shininess);
    glUniform1f(glGetUniformLocation(shader->getProgram(), "material.opacity"), this->opacity);
    
    if (facetCulling) {
      glEnable(GL_CULL_FACE);
    } else {
      glDisable(GL_CULL_FACE);
    }
    
    if (depthTest) {
      glEnable(GL_DEPTH_TEST);
    } else {
      glDisable(GL_DEPTH_TEST);
    }

    if (depthWrite) {
      glDepthMask(GL_TRUE);
    } else {
      glDepthMask(GL_FALSE);
    }
    
    if (opacity < 1) {
      glEnable(GL_BLEND);
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
  }
  
  void unbind() const {
    for (GLuint i = 0; i < this->textures.size(); ++i) {
      glActiveTexture(GL_TEXTURE0 + i);
      glBindTexture(GL_TEXTURE_2D, 0);
    }
  }

  void updateTextureRGB8(int index, int width, int height, uint8_t *data, bool generateMipmap = false) {
    if (index == textures.size()) {
      Texture texture;
      texture.type = "texture_diffuse";
      texture.path = "<dynamic>";
      glGenTextures(1, &texture.id);
      textures.push_back(texture);
    }
    else if (index > textures.size()) {
      throw XglException("Texture index out of range.");
    }

    const Texture& texture = textures[index];
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, data);
    if (generateMipmap) {
      glGenerateMipmap(GL_TEXTURE_2D);
    }
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);
  }

private:
  glm::vec4 diffuseColor;
  std::shared_ptr<Shader> shader;
  std::vector<Texture> textures;
  float shininess;
  float opacity;
  bool facetCulling;
  bool depthTest;
  bool depthWrite;
};
