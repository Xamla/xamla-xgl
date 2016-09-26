#pragma once

#include <SOIL/SOIL.h>
#include <assimp/Importer.hpp>
#include <assimp/scene.h>
#include <assimp/postprocess.h>
#include <glm/gtx/transform.hpp>

#include "mesh.h"
#include "material.h"
#include "light.h"


GLint loadTextureFromFile(const std::string &path, bool flipV = false);
template<typename T> void flipVInplace(T *image, int width, int height, int channels);
template<typename ... Args> std::string string_format(const std::string& format, Args ... args);


class Model {
public:
  Model(const std::shared_ptr<Shader> &defaultShader)
    : defaultShader(defaultShader)
    , pose(1.0f) {
  }
  
  // Draws the model, and thus all its meshes
  void draw(const glm::mat4 &view, const glm::mat4 &projection, const Light& light, Material *overrideMaterial = nullptr) {
    for (size_t i = 0; i < meshes.size(); ++i) {
      prepareShader(overrideMaterial != nullptr ? *overrideMaterial : *meshes[i]->getMaterial(), view, projection, light);
      meshes[i]->draw(overrideMaterial);
    }
  }
  
  const glm::mat4& getPose() const { return pose; }
  void setPose(const glm::mat4& value) { pose = value; }
    
  // Loads a model with supported ASSIMP extensions from file and stores the resulting meshes in the meshes vector.
  void loadModel(const std::string &path) {
    // Read file via ASSIMP
    Assimp::Importer importer;
    const aiScene *scene = importer.ReadFile(path, aiProcess_Triangulate | aiProcess_FlipUVs);

    // Check for errors
    if (!scene || scene->mFlags == AI_SCENE_FLAGS_INCOMPLETE || !scene->mRootNode) {
      throw XglException(std::string("ERROR::ASSIMP:: ") + importer.GetErrorString());
    }

    // Retrieve the directory path of the filepath
    this->directory = path.substr(0, path.find_last_of('/'));

    this->processNode(scene->mRootNode, scene);
  }
  
  void addMesh(const std::shared_ptr<Mesh>& mesh) {
    meshes.push_back(mesh);
  }
  
  size_t getMeshCount() const {
    return meshes.size();
  }
  
  std::shared_ptr<Mesh> getMeshAt(size_t index) {
    if (index > meshes.size())
      throw XglException("Index out of range.");
    return meshes[index];
  }
  
private:
  glm::mat4 pose;
  std::vector<std::shared_ptr<Mesh> > meshes;
  std::string directory;
  std::vector<Texture> texturesLoaded;   // Stores all the textures loaded so far, optimization to make sure textures aren't loaded more than once.
  std::shared_ptr<Shader> defaultShader;

  void prepareShader(const Material &material, const glm::mat4 &view, const glm::mat4 &projection, const Light& light) {
    std::shared_ptr<Shader> shader = material.getShader();
    if (!shader) {
      shader = defaultShader;
    }

    shader->use();
    GLuint program = shader->getProgram();
    
    GLint modelLoc       = glGetUniformLocation(program, "model");
    GLint viewLoc        = glGetUniformLocation(program, "view");
    GLint projectionLoc  = glGetUniformLocation(program, "projection");

    GLint lightColorLoc  = glGetUniformLocation(program, "lightColor");
    GLint lightPosLoc    = glGetUniformLocation(program, "lightPos");
    GLint viewPosLoc     = glGetUniformLocation(program, "viewPos");

    glUniformMatrix4fv(modelLoc, 1, GL_FALSE, glm::value_ptr(pose));
    glUniformMatrix4fv(viewLoc, 1, GL_FALSE, glm::value_ptr(view));
    glUniformMatrix4fv(projectionLoc, 1, GL_FALSE, glm::value_ptr(projection));

    // point light is currently the only supported light type
    if (light.getType() == LightType::Point) {
      const PointLight& pl = static_cast<const PointLight&>(light);

      glUniform3fv(lightPosLoc, 1, glm::value_ptr(pl.getPosition()));
      glUniform3fv(lightColorLoc, 1, glm::value_ptr(pl.getColor()));

      if (viewPosLoc >= 0) {
        auto pos = glm::vec3(glm::inverse(view)[3]);
        glUniform3fv(viewPosLoc, 1, glm::value_ptr(pos));
      }
    }
  }

  // Processes a node in a recursive fashion. Processes each individual mesh located at the node and repeats this process on its children nodes (if any).
  void processNode(aiNode *node, const aiScene *scene) {
    // Process each mesh located at the current node
    //printf("nummeshes: %d\n", node->mNumMeshes);
    for (int i = 0; i < node->mNumMeshes; ++i) {
      // The node object only contains indices to index the actual objects in the scene.
      // The scene contains all the data, node is just to keep stuff organized (like relations between nodes).
      aiMesh *mesh = scene->mMeshes[node->mMeshes[i]];
      this->meshes.push_back(std::shared_ptr<Mesh>(this->processMesh(mesh, scene)));
    }

    // After we've processed all of the meshes (if any) we then recursively process each of the children nodes
    for (int i = 0; i < node->mNumChildren; ++i) {
      this->processNode(node->mChildren[i], scene);
    }
  }

  Mesh *processMesh(aiMesh *mesh, const aiScene *scene) {
    // Data to fill
    std::vector<Vertex> vertices;
    std::vector<GLuint> indices;
    
    auto material = std::make_shared<Material>();
    material->setShader(defaultShader);

    // Walk through each of the mesh's vertices
    //printf("numvertices: %d, numfaces: %d, materialIndices: %d\n", mesh->mNumVertices, mesh->mNumFaces, mesh->mMaterialIndex);

    for (GLuint i = 0; i < mesh->mNumVertices; ++i) {
      Vertex vertex;

      // We declare a placeholder vector since assimp uses its own vector class that doesn't directly
      // convert to glm's vec3 class so we transfer the data to this placeholder glm::vec3 first.
      glm::vec3 vector;

      // Positions
      vector.x = mesh->mVertices[i].x;
      vector.y = mesh->mVertices[i].y;
      vector.z = mesh->mVertices[i].z;
      vertex.Position = vector;

      // Normals
      vector.x = mesh->mNormals[i].x;
      vector.y = mesh->mNormals[i].y;
      vector.z = mesh->mNormals[i].z;
      vertex.Normal = vector;

      // Texture Coordinates
      if (mesh->mTextureCoords[0]) { // Does the mesh contain texture coordinates
        glm::vec2 vec;
        // A vertex can contain up to 8 different texture coordinates. We thus make the assumption that we won't
        // use models where a vertex can have multiple texture coordinates so we always take the first set (0).
        vec.x = mesh->mTextureCoords[0][i].x;
        vec.y = mesh->mTextureCoords[0][i].y;
        vertex.TexCoords = vec;
      }
      else {
        vertex.TexCoords = glm::vec2(0.0f, 0.0f);
      }

      vertices.push_back(vertex);
    }

    // Now wak through each of the mesh's faces (a face is a mesh its triangle) and retrieve the corresponding vertex indices.
    for (GLuint i = 0; i < mesh->mNumFaces; ++i) {
      aiFace face = mesh->mFaces[i];

      // Retrieve all indices of the face and store them in the indices vector
      for (GLuint j = 0; j < face.mNumIndices; ++j)
        indices.push_back(face.mIndices[j]);
    }

    // Process materials
    if (mesh->mMaterialIndex >= 0) {
      aiMaterial *m = scene->mMaterials[mesh->mMaterialIndex];

      // We assume a convention for sampler names in the shaders. Each diffuse texture should be named
      // as 'texture_diffuseN' where N is a sequential number ranging from 1 to MAX_SAMPLER_NUMBER.
      // Same applies to other texture as the following list summarizes:
      // Diffuse: texture_diffuseN
      // Specular: texture_specularN
      // Normal: texture_normalN

      // 1. Diffuse maps
      std::vector<Texture> diffuseMaps = loadMaterialTextures(m, aiTextureType_DIFFUSE, "texture_diffuse");
      material->addTextures(diffuseMaps.begin(), diffuseMaps.end());

      // 2. Specular maps
      std::vector<Texture> specularMaps = loadMaterialTextures(m, aiTextureType_SPECULAR, "texture_specular");
      material->addTextures(specularMaps.begin(), specularMaps.end());
    }

    // Return a mesh object created from the extracted mesh data
    return new Mesh(vertices, indices, material);
  }

  // Checks all material textures of a given type and loads the textures if they're not loaded yet.
  // The required info is returned as a Texture struct.
  std::vector<Texture> loadMaterialTextures(aiMaterial *mat, aiTextureType type, const std::string &typeName)
  {
    std::vector<Texture> textures;
    for (GLuint i = 0; i < mat->GetTextureCount(type); ++i) {
      aiString str;
      mat->GetTexture(type, i, &str);

      // Check if texture was loaded before and if so, continue to next iteration: skip loading a new texture
      bool skip = false;
      for (GLuint j = 0; j < texturesLoaded.size(); ++j) {
        if (texturesLoaded[j].path == str) {
          textures.push_back(texturesLoaded[j]);
          skip = true; // A texture with the same filepath has already been loaded, continue to next one. (optimization)
          break;
        }
      }

      if (!skip) {   // If texture hasn't been loaded already, load it
        Texture texture;
        std::string path = this->directory + std::string("/") + std::string(str.C_Str());
        texture.id = loadTextureFromFile(path, false);
        texture.type = typeName;
        texture.path = str;
        textures.push_back(texture);
        this->texturesLoaded.push_back(texture);  // Store it as texture loaded for entire model, to ensure we won't unnecesery load duplicate textures.
      }
    }

    return textures;
  }
};


inline GLint loadTextureFromFile(const std::string &path, bool flipV) {
   //Generate texture ID and load texture data
  GLuint textureID;
  glGenTextures(1, &textureID);

  int width = 0, height = 0;
  //SOIL_load_OGL_texture(path.c_str(), 3, textureID)
  unsigned char *image = SOIL_load_image(path.c_str(), &width, &height, 0, SOIL_LOAD_RGB);
  if (image == nullptr) {
    throw XglException(string_format("Texture loading faild (%s), error: %s!\n", path.c_str(), SOIL_last_result()));
  }
  
  printf("loaded texture size: %dx%d\n", width, height);
  
  if (flipV) {
    flipVInplace(image, width, height, 3);
  }

  // Assign texture to ID
  glBindTexture(GL_TEXTURE_2D, textureID);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, image);

  SOIL_free_image_data(image);

  glGenerateMipmap(GL_TEXTURE_2D);

  // Parameters
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glBindTexture(GL_TEXTURE_2D, 0);

  return textureID;
}
