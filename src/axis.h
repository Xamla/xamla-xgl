#pragma once

#include <memory>

class Axis {
public:
  Axis() 
    : angles(0,0,0)
    , scales(1,1,1)
    , translation(0,0,0) {
    init();
  }

  void draw(const glm::mat4 &projection, const glm::mat4 &view) {
    shader->use();

    glm::mat4 model;
    model = glm::scale(model, scales);
    model = glm::rotate(model, glm::float32(angles.y), glm::vec3(0, 1, 0));
    model = glm::rotate(model, glm::float32(angles.x), glm::vec3(1, 0, 0));
    model = glm::rotate(model, glm::float32(angles.z), glm::vec3(0, 0, 1));
    model = glm::translate(model, translation);

    glUniformMatrix4fv(glGetUniformLocation(shader->getProgram(), "projection"), 1, GL_FALSE, glm::value_ptr(projection));
    glUniformMatrix4fv(glGetUniformLocation(shader->getProgram(), "view"), 1, GL_FALSE, glm::value_ptr(view));
    glUniformMatrix4fv(glGetUniformLocation(shader->getProgram(), "model"), 1, GL_FALSE, glm::value_ptr(model));

    glBindVertexArray(axisVAO);
    glDrawElements(GL_TRIANGLES, 36, GL_UNSIGNED_INT, 0);
    glBindVertexArray(0);
  }

  const Shader& getShader() const {
    return *shader;
  }

  void setAngles(const glm::vec3& angles) {
    this->angles = angles;
  }

  void setScales(const glm::vec3& scales) {
    this->scales = scales;
  }

  void setTranslation(const glm::vec3& translation) {
    this->translation = translation;
  }

private:
  GLuint axisVAO, texture;
  std::unique_ptr<Shader> shader;
  glm::vec3 angles;
  glm::vec3 scales;
  glm::vec3 translation;

  void init() {
    printf("axis shader\n");
    shader.reset(new Shader("./shaders/Axis.VertexShader.glsl", "./shaders/Axis.FragmentShader.glsl"));
    printf("axis shader loaded\n");
    scales = glm::vec3(1);

    // Set up vertex data (and buffer(s)) and attribute pointers
    GLfloat vertices[] = {
      // Vertices           // Texture   // Color

      // Y
      -0.1f,  0.0f,  0.0f,  0.0f, 0.0f,  0.0f, 1.0f, 0.0f,
      -0.1f,  1.0f,  0.0f,  0.0f, 0.0f,  0.0f, 1.0f, 0.0f,
       0.1f,  0.0f,  0.0f,  0.0f, 0.0f,  0.0f, 1.0f, 0.0f,
       0.1f,  1.0f,  0.0f,  0.0f, 0.0f,  0.0f, 1.0f, 0.0f,

       0.0f,  0.0f,  0.1f,  0.0f, 0.0f,  0.0f, 1.0f, 0.0f,
       0.0f,  1.0f,  0.1f,  0.0f, 0.0f,  0.0f, 1.0f, 0.0f,
       0.0f,  0.0f, -0.1f,  0.0f, 0.0f,  0.0f, 1.0f, 0.0f,
       0.0f,  1.0f, -0.1f,  0.0f, 0.0f,  0.0f, 1.0f, 0.0f,

      // X
       0.0f, -0.1f,  0.0f,  0.0f, 0.0f,  1.0f, 0.0f, 0.0f,
       1.0f, -0.1f,  0.0f,  0.0f, 0.0f,  1.0f, 0.0f, 0.0f,
       0.0f,  0.1f,  0.0f,  0.0f, 0.0f,  1.0f, 0.0f, 0.0f,
       1.0f,  0.1f,  0.0f,  0.0f, 0.0f,  1.0f, 0.0f, 0.0f,

       0.0f,  0.0f,  0.1f,  0.0f, 0.0f,  1.0f, 0.0f, 0.0f,
       1.0f,  0.0f,  0.1f,  0.0f, 0.0f,  1.0f, 0.0f, 0.0f,
       0.0f,  0.0f, -0.1f,  0.0f, 0.0f,  1.0f, 0.0f, 0.0f,
       1.0f,  0.0f, -0.1f,  0.0f, 0.0f,  1.0f, 0.0f, 0.0f,

      // Z
       0.0f, -0.1f,  0.0f,  0.0f, 0.0f,  0.0f, 0.0f, 1.0f,
       0.0f, -0.1f,  1.0f,  0.0f, 0.0f,  0.0f, 0.0f, 1.0f,
       0.0f,  0.1f,  0.0f,  0.0f, 0.0f,  0.0f, 0.0f, 1.0f,
       0.0f,  0.1f,  1.0f,  0.0f, 0.0f,  0.0f, 0.0f, 1.0f,

       0.1f,  0.0f,  0.0f,  0.0f, 0.0f,  0.0f, 0.0f, 1.0f,
       0.1f,  0.0f,  1.0f,  0.0f, 0.0f,  0.0f, 0.0f, 1.0f,
      -0.1f,  0.0f,  0.0f,  0.0f, 0.0f,  0.0f, 0.0f, 1.0f,
      -0.1f,  0.0f,  1.0f,  0.0f, 0.0f,  0.0f, 0.0f, 1.0f
    };

    GLint indices[] = {
      // Y
      0, 1, 2,
      2, 3, 1,
      4, 5, 6,
      6, 7, 5,

      // X
      8, 9, 10,
      10, 11, 9,
      12, 13, 14,
      14, 15, 13,

      // Z
      16, 17, 18,
      18, 19, 17,
      20, 21, 22,
      22, 23, 21
    };

    // First, set the container's VAO, VBO and EBO
    GLuint VBO, EBO;
    glGenVertexArrays(1, &axisVAO);
    glGenBuffers(1, &VBO);
    glGenBuffers(1, &EBO);

    glBindVertexArray(axisVAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

    // Position attribute
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), (GLvoid*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), (GLvoid*)(3 * sizeof(GLfloat)));
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), (GLvoid*)(5 * sizeof(GLfloat)));
    glEnableVertexAttribArray(2);
    glBindVertexArray(0);
  }
};
