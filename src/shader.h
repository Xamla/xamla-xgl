#pragma once


class Shader
{
private:

  class GLShader {
  public:
    GLShader(GLenum type)
      : shader(0)
      , type(type) {
      shader = glCreateShader(type);
      if (shader == 0) {
         throw XglException("Creating shader object failed.");
      }
    }

    ~GLShader() {
      glDeleteShader(shader);
    }

    GLuint get() const {
      return shader;
    }

    void compile(const std::string& source) {
      const GLchar *code = source.c_str();

      glShaderSource(shader, 1, &code, NULL);
      glCompileShader(shader);

      GLint success;
      glGetShaderiv(shader, GL_COMPILE_STATUS, &success);

      if (!success) {
        GLchar infoLog[512];
        glGetShaderInfoLog(shader, 512, NULL, infoLog);
        std::string errorMessage(std::string("ERROR::SHADER::") + getTypeString() + "::COMPILATION_FAILED\n");
        errorMessage += infoLog;
        std::cout << errorMessage << std::endl;
        throw XglException(errorMessage);
      }
    }

  private:
    GLuint shader;
    GLenum type;

    std::string getTypeString() const {
      if (type == GL_VERTEX_SHADER) {
        return "VERTEX_SHADER";
      } else if (type == GL_FRAGMENT_SHADER) {
        return "FRAGMENT_SHADER";
      } else {
        return "unknown";
      }
    }
  };

  class GLProgram {
  public:
    GLProgram()
      : program(0) {
      program = glCreateProgram();
      if (program == 0) {
        throw XglException("Creating program object failed.");
      }
    }

    ~GLProgram() {
      glDeleteProgram(program);
      program = 0;
    }

    GLuint get() const {
      return program;
    }

    void use() const {
      glUseProgram(program);
    }

    void attachShader(GLuint shader) {
      glAttachShader(program, shader);
    }

    void attachShader(const GLShader& shader) {
      attachShader(shader.get());
    }

    void link() {
      glLinkProgram(program);

      GLint success;
      glGetProgramiv(program, GL_LINK_STATUS, &success);

      if (!success) {
        GLchar infoLog[512];
        glGetProgramInfoLog(program, 512, NULL, infoLog);
        std::string errorMessage("ERROR::SHADER::PROGRAM::LINKING_FAILED\n");
        errorMessage += infoLog;
        std::cout << errorMessage << std::endl;
        throw XglException(errorMessage);
      }
    }

  private:
    GLuint program;
  };

public:
  Shader() {
  }

  void create(const std::string& vertexCode, const std::string& fragmentCode) {

    GLShader vertex(GL_VERTEX_SHADER);
    vertex.compile(vertexCode);

    GLShader fragment(GL_FRAGMENT_SHADER);
    fragment.compile(fragmentCode);

    // Shader Program
    std::unique_ptr<GLProgram> program(new GLProgram());
    program->attachShader(vertex);
    program->attachShader(fragment);
    program->link();

    this->program.swap(program);
  }

  void load(const std::string& vertexPath, const std::string& fragmentPath) {

    std::ifstream vShaderFile, fShaderFile;
    std::stringstream vShaderStream, fShaderStream;

    // ensures ifstream objects can throw exceptions:
    vShaderFile.exceptions(std::ifstream::badbit);
    fShaderFile.exceptions(std::ifstream::badbit);

    try {
      vShaderFile.open(vertexPath);
      fShaderFile.open(fragmentPath);

      // read file's buffer contents into streams
      vShaderStream << vShaderFile.rdbuf();
      fShaderStream << fShaderFile.rdbuf();
    }
    catch (const std::ifstream::failure &e) {
      throw std::runtime_error("ERROR::SHADER::FILE_NOT_SUCCESFULLY_READ");
    }

    create(vShaderStream.str(), fShaderStream.str());
  }

  // Uses the current shader
  void use() const {
    if (program) {
      program->use();
    }
  }

  GLuint getProgram() const {
    return program ? program->get() : 0;
  }

private:
  std::unique_ptr<GLProgram> program;
};
