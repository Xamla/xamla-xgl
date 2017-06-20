#pragma once

#include "material.h"


struct Vertex {
  glm::vec3 Position;
  glm::vec3 Normal;
  glm::vec2 TexCoords;
  glm::vec4 Color;
};


class Mesh {
public:
  static Mesh* createQuadMesh(float xdim = 1.0f, float ydim = 1.0f) {

    std::vector<GLuint> indices = {
      0, 1, 2,
      2, 1, 3
    };

    xdim *= 0.5;
    ydim *= 0.5;
    std::vector<Vertex> vertices = {
        // Position              // Normal             // UV            // Color
      { { -xdim,  ydim,  0.0f }, { 0.0f, 0.0f, 1.0f }, { 0.0f,  1.0f }, { .0f, .0f, .0f, .0f } },
      { { -xdim, -ydim,  0.0f }, { 0.0f, 0.0f, 1.0f }, { 0.0f,  0.0f }, { .0f, .0f, .0f, .0f } },
      { {  xdim,  ydim,  0.0f }, { 0.0f, 0.0f, 1.0f }, { 1.0f,  1.0f }, { .0f, .0f, .0f, .0f } },
      { {  xdim, -ydim,  0.0f }, { 0.0f, 0.0f, 1.0f }, { 1.0f,  0.0f }, { .0f, .0f, .0f, .0f } }
    };

    return new Mesh(vertices, indices);
  }

  Mesh(
    const std::vector<Vertex> &vertices,
    const std::vector<GLuint> &indices,
    const std::shared_ptr<Material>& material = std::shared_ptr<Material>()
  )
    : vertices(vertices)
    , indices(indices)
    , material(material)
    , VAO(0), VBO(0), EBO(0) {
    this->setupMesh();      // set the vertex buffers and its attribute pointers
  }

  Mesh & operator =(const Mesh &) = delete;
  Mesh(const Mesh &) = delete;

  ~Mesh() {
    glDeleteVertexArrays(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteBuffers(1, &EBO);
  }

  void draw(Material *overrideMaterial = nullptr) const {
    Material *material = overrideMaterial != nullptr ? overrideMaterial : this->material.get();

    if (material) {
      material->bind();
    }

    // Draw mesh
    glBindVertexArray(this->VAO);
    glDrawElements(GL_TRIANGLES, this->indices.size(), GL_UNSIGNED_INT, 0);
    glBindVertexArray(0);

    if (material) {
      material->unbind();
    }
  }

  std::vector<Vertex> *getVertices(){
    return &vertices;
  }

  const std::shared_ptr<Material>& getMaterial() const { return material; }
  void setMaterial(const std::shared_ptr<Material>& material) { this->material = material; }

private:
  std::shared_ptr<Material> material;
  std::vector<Vertex> vertices;
  std::vector<GLuint> indices;

  GLuint VAO, VBO, EBO;

  // Initializes all the buffer objects/arrays
  void setupMesh() {
    // Create buffers/arrays
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
    glGenBuffers(1, &EBO);
    glBindVertexArray(VAO);

    // Load data into vertex buffers
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(Vertex), &vertices.front(), GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(GLuint), &indices.front(), GL_STATIC_DRAW);

    // Set the vertex attribute pointers
    // Vertex Positions
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid*)nullptr);

    // Vertex Normals
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid*)offsetof(Vertex, Normal));

    // Vertex Texture Coords
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid*)offsetof(Vertex, TexCoords));

    // Vertex Color
    glEnableVertexAttribArray(3);
    glVertexAttribPointer(3, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid*)offsetof(Vertex, Color));

    glBindVertexArray(0);
  }
};
