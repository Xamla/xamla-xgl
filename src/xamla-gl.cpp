// TODO:
// - Check if EGL allows simple off-screen rendering without window, e.g. see https://devblogs.nvidia.com/parallelforall/egl-eye-opengl-visualization-without-x-server/

#include "xamla-gl.h"

#include <memory>
#include <string>
#include <sstream>
#include <fstream>
#include <iostream>

// GLM Mathemtics
#define GLM_FORCE_RADIANS
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

// GLEW
#define GLEW_STATIC
#include <GL/glew.h>

// GLFW
#include <GLFW/glfw3.h>

#include "tensor_conversion.h"
#include "camera.h"
#include "shader.h"
#include "model.h"
//#include "axis.h"

#include "simple_scene.h"


typedef std::shared_ptr<Material> MaterialHandle;
typedef std::shared_ptr<Mesh> MeshHandle;
typedef std::shared_ptr<Shader> ShaderHandle;


GLFWwindow *xgl_window = nullptr;
bool xgl_window_visible = false;


template<typename T>
void flipVInplace(T *image, int width, int height, int channels) {
    // flip vertical axis
  const int line_size = width * channels;
  T tmp[line_size];
  for (int y=0; y<height/2; ++y) {
    T *src = image + (y * line_size);
    T *dst = image + ((height-y-1) * line_size);
    memcpy(tmp, src, line_size * sizeof(T));
    memcpy(src, dst, line_size * sizeof(T));
    memcpy(dst, tmp, line_size * sizeof(T));
  }
}


template<typename ... Args>
std::string string_format(const std::string& format, Args ... args) {
  size_t size = snprintf(nullptr, 0, format.c_str(), args ...) + 1; // Extra space for '\0'
  std::unique_ptr<char[]> buf(new char[size]);
  std::snprintf(buf.get(), size, format.c_str(), args ...);
  return std::string(buf.get(), buf.get() + size - 1); // We don't want the '\0' inside
}


XGLIMP(void, _, init)(bool show_window, int window_width, int window_height) {
  glfwInit();
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
  if (!show_window) {
    glfwWindowHint(GLFW_VISIBLE, GL_FALSE);
  }
  xgl_window_visible = show_window;
  glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

  if (window_width <= 0) {
    window_width = 1;
  }
  if (window_height <= 0) {
    window_width = 1;
  }
  xgl_window = glfwCreateWindow(window_width, window_height, "xgl_dummy_window", nullptr, nullptr);
  glfwMakeContextCurrent(xgl_window);

  glewExperimental = GL_TRUE;
  glewInit();

  // dump extension list
  /*printf("Extensions:");
  GLint ext_count = 0;
  glGetIntegerv(GL_NUM_EXTENSIONS, &ext_count);
  for (GLint i = 0; i < ext_count; i++) {
    printf("%s\n", (char const*)glGetStringi(GL_EXTENSIONS, i));
  }*/

  GLint max_supported_size = 0;
  glGetIntegerv(GL_MAX_TEXTURE_SIZE, &max_supported_size);
  printf("Max texture size: %d\n", max_supported_size);

  GLint samples = 0;
  glGetIntegerv(GL_MAX_SAMPLES_EXT, &samples);    //We need to find out what the maximum supported samples is
  printf("Supported multi-sampling: %d\n", samples);
}

XGLIMP(void, _, terminate)() {
  glfwDestroyWindow(xgl_window);
  glfwTerminate();
}

XGLIMP(void, _, pollEvents)() {
  glfwPollEvents();
}

XGLIMP(bool, _, windowShouldClose)() {
  return glfwWindowShouldClose(xgl_window) != 0;
}


XGLIMP(Camera *, Camera, new)() {
  return new Camera();
}

XGLIMP(void, Camera, delete)(Camera *camera) {
  delete camera;
}

XGLIMP(void, Camera, getImageSize)(Camera *camera, THIntTensor *output) {
  vec2ToTensor(camera->getImageSize(), output);
}

XGLIMP(void, Camera, setImageSize)(Camera *camera, int width, int height) {
  camera->setImageSize(width, height);
}

XGLIMP(void, Camera, getClipNearFar)(Camera *camera, THDoubleTensor *output) {
  vec2ToTensor(camera->getClipNearFar(), output);
}

XGLIMP(void, Camera, setClipNearFar)(Camera *camera, float near, float far) {
  camera->setClipNearFar(near, far);
}

XGLIMP(float, Camera, getAspectRatio)(Camera *camera) {
  return camera->getAspectRatio();
}

XGLIMP(void, Camera, getPrincipalPoint)(Camera *camera, THDoubleTensor *output) {
  vec2ToTensor(camera->getPrincipalPoint(), output);
}

XGLIMP(void, Camera, getFocalLength)(Camera *camera, THDoubleTensor *output) {
  vec2ToTensor(camera->getFocalLength(), output);
}

XGLIMP(void, Camera, setIntrinsics)(Camera *camera, float fx, float fy, float cx, float cy) {
  camera->setIntrinsics(fx, fy, cx, cy);
}

XGLIMP(void, Camera, copyRenderResult)(Camera *camera, bool vflip, THByteTensor *output) {
  auto sz = camera->getImageSize();
  THByteTensor_resize3d(output, sz[1], sz[0], 3);
  THByteTensor* output_ = THByteTensor_newContiguous(output);
  camera->copyToNormalFrameBuffer();
  uint8_t *data = THByteTensor_data(output_);
  glReadPixels(0, 0, sz[0], sz[1], GL_RGB, GL_UNSIGNED_BYTE, data);
  if (vflip) {
    flipVInplace(data, sz[0], sz[1], 3);
  }
  THByteTensor_freeCopyTo(output_, output);
}

XGLIMP(void, Camera, copyRenderResultF32)(Camera *camera, bool vflip, THFloatTensor *output) {
  auto sz = camera->getImageSize();
  THFloatTensor_resize2d(output, sz[1], sz[0]);
  THFloatTensor* output_ = THFloatTensor_newContiguous(output);
  float *data = THFloatTensor_data(output_);
  glReadPixels(0, 0, sz[0], sz[1], GL_RED, GL_FLOAT, data);
  if (vflip) {
    flipVInplace(data, sz[0], sz[1], 1);
  }
  THFloatTensor_freeCopyTo(output_, output);
}

XGLIMP(void, Camera, unprojectDepthImage)(Camera *camera, THFloatTensor *depthInput, THFloatTensor *xyzOutput, int outputStride) {
  THFloatTensor* input_ = THFloatTensor_newContiguous(depthInput);
  THFloatTensor* output_ = THFloatTensor_newContiguous(xyzOutput);
  float *inputData = THFloatTensor_data(input_);
  float *outputData = THFloatTensor_data(output_);
  camera->unprojectDepthImage(inputData, outputData, outputStride);
  THFloatTensor_freeCopyTo(output_, xyzOutput);
}

XGLIMP(void, Camera, swapBuffers)(Camera *camera) {
  auto sz = camera->getImageSize();
  camera->copyToNormalFrameBuffer();
  glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
  int width = 0, height = 0;
  glfwGetWindowSize(xgl_window, &width, &height);
  glBlitFramebuffer(0, 0, sz[0], sz[1], 0, 0, width, height, GL_COLOR_BUFFER_BIT, GL_NEAREST);
  glfwSwapBuffers(xgl_window);
}

XGLIMP(void, Camera, lookAt)(Camera *camera, THDoubleTensor *eye, THDoubleTensor *at, THDoubleTensor *up) {
  camera->lookAt(Tensor2vec3(eye), at != nullptr ? Tensor2vec3(at) : glm::vec3(0,0,0), up != nullptr ? Tensor2vec3(up) : glm::vec3(0,1,0));
}

XGLIMP(void, Camera, getViewMatrix)(Camera *camera, THDoubleTensor *output) {
  copyMatrix<glm::mat4, 4, 4>(camera->getViewMatrix(), output);
}

XGLIMP(void, Camera, setViewMatrix)(Camera *camera, THDoubleTensor *input) {
  camera->setViewMatrix(Tensor2mat4((input)));
}

XGLIMP(void, Camera, getProjectionMatrix)(Camera *camera, THDoubleTensor *output) {
  copyMatrix<glm::mat4, 4, 4>(camera->getProjectionMatrix(), output);
}

XGLIMP(void, Camera, setProjectionMatrix)(Camera *camera, THDoubleTensor *input) {
  camera->setProjectionMatrix(Tensor2mat4(input));
}

XGLIMP(void, Camera, getPosition)(Camera *camera, THDoubleTensor *output) {
  vec3ToTensor(camera->getPosition(), output);
}

XGLIMP(void, Camera, getPose)(Camera *camera, THDoubleTensor *output) {
  copyMatrix<glm::mat4, 4, 4>(camera->getPose(), output);
}

XGLIMP(void, Camera, setPose)(Camera *camera, THDoubleTensor *input) {
  camera->setPose(Tensor2mat4(input));
}

XGLIMP(void, Camera, getIntrinsicMatrix)(Camera *camera, THDoubleTensor *output) {
  copyMatrix<glm::mat3, 3, 3>(camera->getIntrinsicMatrix(), output);
}

XGLIMP(void, Camera, setIntrinsicMatrix)(Camera *camera, THDoubleTensor *input) {
  camera->setIntrinsicMatrix(Tensor2mat3(input));
}

XGLIMP(void, Camera, perspective)(float fov, float aspect, float near, float far, THDoubleTensor *output) {
  auto view = glm::perspectiveRH(fov, aspect, near, far);
  copyMatrix<glm::mat4, 4, 4>(view, output);
}


XGLIMP(ShaderHandle *, Shader, new)() {
  return new ShaderHandle();
}

XGLIMP(void, Shader, delete)(ShaderHandle *shader) {
  delete shader;
}

XGLIMP(void, Shader, release)(ShaderHandle *shader) {
  shader->reset();
}

XGLIMP(bool, Shader, isNull)(ShaderHandle *shader) {
  return shader != nullptr || *shader == nullptr;
}

XGLIMP(void, Shader, create)(ShaderHandle *shader, const char *vertexShaderSource, const char *fragmentShaderSource) {
  ShaderHandle shader_(new Shader());
  shader_->create(vertexShaderSource, fragmentShaderSource);
  *shader = shader_;
}

XGLIMP(void, Shader, load)(ShaderHandle *shader, const char *vertexShaderPath, const char *fragmentShaderPath) {
  ShaderHandle shader_(new Shader());
  shader_->load(vertexShaderPath, fragmentShaderPath);
  *shader = shader_;
}


XGLIMP(Model *, Model, new)(ShaderHandle *defaultShader) {
  return new Model(defaultShader != nullptr ? *defaultShader : ShaderHandle());
}

XGLIMP(void, Model, delete)(Model *model) {
  delete model;
}

XGLIMP(void, Model, loadModel)(Model *model, const char *filePath) {
  model->loadModel(filePath);
}

XGLIMP(void, Model, getPose)(Model *model, THDoubleTensor *output) {
  copyMatrix<glm::mat4, 4, 4>(model->getPose(), output);
}

XGLIMP(void, Model, setPose)(Model *model, THDoubleTensor *input) {
  model->setPose(Tensor2mat4(input));
}

void FloatTensorToVertices(THFloatTensor *tensor, std::vector<Vertex> &vertices) {
  if (tensor == NULL || tensor->nDimension != 2 || tensor->size[1] < 3) {
    throw XglException("Invalid tensor size");
  }

  tensor = THFloatTensor_newContiguous(tensor);
  float *data = THFloatTensor_data(tensor);

  const int rows = tensor->size[0];
  const int cols = tensor->size[1];
  vertices.resize(rows);

  for (int i = 0; i < rows; ++i) {
    Vertex &v = vertices[i];

    v.Position[0] = data[0];
    v.Position[1] = data[1];
    v.Position[2] = data[2];

    if (cols >= 6) {
      v.Normal = glm::vec3(data[3], data[4], data[5]);
    }

    if (cols >= 8) {
      v.TexCoords = glm::vec2(data[6], data[7]);
    }

    if (cols >= 12) {
      v.Color = glm::vec4(data[8], data[9], data[10], data[11]);
    }

    data += tensor->stride[0];
  }

  THFloatTensor_free(tensor);
}

void VerticesToFloatTensor(THFloatTensor *verticesToWrite,const std::vector<Vertex> *verticesFromMesh) {
  int numberOfVertices = verticesFromMesh->size();
  bool hasNormal = false;
  bool hasTexCoords = false;
  bool hasColor = false;
  int numRows = 3;

  if (numberOfVertices > 0) {
    if ((*verticesFromMesh)[0].Normal[0]) {
      hasNormal = true;
      numRows += 3;
    }

    if ((*verticesFromMesh)[0].TexCoords[0]) {
      hasTexCoords = true;
      numRows += 2;
    }

    if ((*verticesFromMesh)[0].Color[0]) {
      hasColor = true;
      numRows += 4;
    }

    //resize tensor to #numVertices x 3 for the three position arguments
    THFloatTensor_resize2d(verticesToWrite, numberOfVertices, numRows);

    //get pointer to data
    float *data = THFloatTensor_data(verticesToWrite);
    for (int i = 0; i < verticesFromMesh->size(); ++i) {

      data[0] = (*verticesFromMesh)[i].Position[0];
      data[1] = (*verticesFromMesh)[i].Position[1];
      data[2] = (*verticesFromMesh)[i].Position[2];

      if (hasNormal) {
        data[3] = (*verticesFromMesh)[i].Normal[0];
        data[4] = (*verticesFromMesh)[i].Normal[1];
        data[5] = (*verticesFromMesh)[i].Normal[2];
      }

      if (hasTexCoords) {
        data[6] = (*verticesFromMesh)[i].TexCoords[0];
        data[7] = (*verticesFromMesh)[i].TexCoords[1];
      }

      if (hasColor) {
        data[8] = (*verticesFromMesh)[i].Color[0];
        data[9] = (*verticesFromMesh)[i].Color[1];
        data[10] = (*verticesFromMesh)[i].Color[2];
        data[11] = (*verticesFromMesh)[i].Color[3];
      }

      data += verticesToWrite->stride[0];
    }
  }
}

XGLIMP(void, Mesh, getVertices)(MeshHandle *mesh, THFloatTensor *verticesToWrite) {
  std::vector<Vertex> *verticesFromMesh = (*mesh)->getVertices();

  VerticesToFloatTensor(verticesToWrite, verticesFromMesh);
}

XGLIMP(void, Model, addMesh_Tensor)(Model *model, THFloatTensor *vertices, THIntTensor *indices, ShaderHandle *shader, THFloatTensor *color) {
  auto material = std::make_shared<Material>();
  if (shader != nullptr) {
    material->setShader(*shader);
  }
  material->setDiffuseColor(Tensor2vec4(color));

  std::vector<Vertex> vertices_;
  FloatTensorToVertices(vertices, vertices_);

  std::vector<GLuint> indices_;
  IntTensorToIndices(indices, indices_);

  std::shared_ptr<Mesh> mesh(new Mesh(vertices_, indices_, material));
  model->addMesh(mesh);
}

XGLIMP(void, Model, addMesh)(Model *model, MeshHandle *mesh) {
  if (mesh != nullptr && *mesh) {
    model->addMesh(*mesh);
  }
}

XGLIMP(int, Model, getMeshCount)(Model *model) {
  return (int)model->getMeshCount();
}

XGLIMP(void, Model, getMeshAt)(Model *model, int index, MeshHandle *output) {
  *output = model->getMeshAt((size_t)index);
}


XGLIMP(MaterialHandle *, Material, new)() {
  return new MaterialHandle();
}

XGLIMP(void, Material, delete)(MaterialHandle *material) {
  delete material;
}

XGLIMP(void, Material, create)(MaterialHandle *material) {
  material->reset(new Material());
}

XGLIMP(void, Material, release)(MaterialHandle *material) {
  material->reset();
}

XGLIMP(bool, Material, isNull)(MaterialHandle *material) {
  return material != nullptr || *material == nullptr;
}

XGLIMP(void, Material, getDiffuseColor)(MaterialHandle *material, THFloatTensor *output) {
  auto color = (*material)->getDiffuseColor();
  vec4ToTensor(color, output);
}

XGLIMP(void, Material, setDuffuseColor)(MaterialHandle *material, THFloatTensor *input) {
  (*material)->setDiffuseColor(Tensor2vec4(input));
}

XGLIMP(void, Material, getShader)(MaterialHandle *material, ShaderHandle *output) {
  *output = (*material)->getShader();
}

XGLIMP(void, Material, setShader)(MaterialHandle *material, ShaderHandle *input) {
  (*material)->setShader(input != nullptr ? *input : ShaderHandle());
}

XGLIMP(float, Material, getShininess)(MaterialHandle *material) {
  return (*material)->getShininess();
}

XGLIMP(void, Material, setShininess)(MaterialHandle *material, float value) {
  (*material)->setShininess(value);
}

XGLIMP(float, Material, getOpacity)(MaterialHandle *material) {
  return (*material)->getOpacity();
}

XGLIMP(void, Material, setOpacity)(MaterialHandle *material, float value) {
  (*material)->setOpacity(value);
}

XGLIMP(bool, Material, getFacetCulling)(MaterialHandle *material) {
  return (*material)->getFacetCulling();
}

XGLIMP(void, Material, setFacetCulling)(MaterialHandle *material, bool value) {
  (*material)->setFacetCulling(value);
}

XGLIMP(bool, Material, getDepthTest)(MaterialHandle *material) {
  return (*material)->getDepthTest();
}

XGLIMP(void, Material, setDepthTest)(MaterialHandle *material, bool value) {
  (*material)->setDepthTest(value);
}

XGLIMP(bool, Material, getDepthWrite)(MaterialHandle *material) {
  return (*material)->getDepthWrite();
}

XGLIMP(void, Material, setDepthWrite)(MaterialHandle *material, bool value) {
  (*material)->setDepthWrite(value);
}

XGLIMP(void, Material, updateTextureRGB8)(MaterialHandle *material, int index, int width, int height, THByteTensor *image, bool flipV = true, bool generateMipmap = false) {
  THByteTensor *image_ = THByteTensor_newClone(image);
  uint8_t *data = THByteTensor_data(image_);
  flipVInplace(data, width, height, 3);
  (*material)->updateTextureRGB8(index, width, height, data, generateMipmap);
  THByteTensor_free(image_);
}


XGLIMP(MeshHandle *, Mesh, new)() {
  return new MeshHandle();
}

XGLIMP(void, Mesh, delete)(MeshHandle *mesh) {
  delete mesh;
}

XGLIMP(void, Mesh, create)(MeshHandle *mesh, THFloatTensor *vertices, THIntTensor *indices, MaterialHandle *material) {
  std::vector<Vertex> vertices_;
  FloatTensorToVertices(vertices, vertices_);

  std::vector<GLuint> indices_;
  IntTensorToIndices(indices, indices_);

  mesh->reset(new Mesh(vertices_, indices_, material != nullptr ? *material : MaterialHandle()));
}

XGLIMP(void, Mesh, release)(MeshHandle *mesh) {
  mesh->reset();
}

XGLIMP(bool, Mesh, isNull)(MeshHandle *material) {
  return material != nullptr || *material == nullptr;
}

XGLIMP(void, Mesh, getMaterial)(MeshHandle *mesh, MaterialHandle *output) {
  *output = (*mesh)->getMaterial();
}

XGLIMP(void, Mesh, setMaterial)(MeshHandle *mesh, MaterialHandle *input) {
  (*mesh)->setMaterial(*input);
}


XGLIMP(SimpleScene *, SimpleScene, new)() {
  return new SimpleScene();
}

XGLIMP(void, SimpleScene, delete)(SimpleScene *scene) {
  delete scene;
}

XGLIMP(void, SimpleScene, render)(SimpleScene *scene) {
  scene->render(RenderTargetType::MultiSampling);
}

XGLIMP(void, SimpleScene, renderDepth)(SimpleScene *scene) {
  scene->render(RenderTargetType::Depth);
}

XGLIMP(void, SimpleScene, setClearColor)(SimpleScene *scene, float r, float g, float b, float a) {
  scene->setClearColor(r, g, b, a);
}

XGLIMP(void, SimpleScene, getOverrideMaterial)(SimpleScene *scene, MaterialHandle *output) {
  *output = scene->getOverrideMaterial();
}

XGLIMP(void, SimpleScene, setOverrideMaterial)(SimpleScene *scene, MaterialHandle *input) {
  scene->setOverrideMaterial(input != nullptr ? *input : MaterialHandle());
}

XGLIMP(void, SimpleScene, setCamera)(SimpleScene *scene, Camera *camera) {
  scene->setCamera(camera);
}

XGLIMP(void, SimpleScene, addModel)(SimpleScene *scene, Model *model) {
  scene->addModel(model);
}

XGLIMP(void, SimpleScene, clearModels)(SimpleScene *scene) {
  scene->clearModels();
}

XGLIMP(void, SimpleScene, addQuad)(
  SimpleScene *scene,
  Model *model,
  float xdim,
  float ydim,
  ShaderHandle *shader,
  const char *textureFilename,
  float opacity = 1,
  bool depthWrite = true) {

  std::shared_ptr<Material> quadMaterial(new Material());
  std::shared_ptr<Mesh> quadMesh(Mesh::createQuadMesh(xdim, ydim));
  if (shader != nullptr) {
    quadMaterial->setShader(*shader);
  }
  quadMaterial->setOpacity(opacity);
  quadMaterial->setDepthWrite(depthWrite);

  if (textureFilename != nullptr) {
    Texture texture;
    texture.id = loadTextureFromFile(textureFilename, true);
    printf("texture id: %d (%s)\n", texture.id, textureFilename);
    texture.type = "texture_diffuse";
    texture.path = textureFilename;

    quadMaterial->addTexture(texture);
  }

  quadMesh->setMaterial(quadMaterial);
  model->addMesh(quadMesh);

  scene->addModel(model);
}


struct FrameBufferLimits {
  int maxColorAttachments;
  int maxWidth;
  int maxHeight;
  int maxSamples;
  int maxLayers;
};


XGLIMP(void, FrameBuffer, getLimits)(FrameBufferLimits *limits) {
  glGetIntegerv(GL_MAX_COLOR_ATTACHMENTS, &limits->maxColorAttachments);
  glGetIntegerv(GL_MAX_FRAMEBUFFER_WIDTH, &limits->maxWidth);
  glGetIntegerv(GL_MAX_FRAMEBUFFER_HEIGHT, &limits->maxHeight);
  glGetIntegerv(GL_MAX_FRAMEBUFFER_SAMPLES, &limits->maxSamples);
  glGetIntegerv(GL_MAX_FRAMEBUFFER_LAYERS, &limits->maxLayers);
}


/*

class SceneObjectBase  {
public:

protected:
  virtual draw() = 0;
};



template<typename T>
class Node {
public:


private:
  std::unique_ptr<T> object;
};*/


/*int main(int argc, char *argv[]) {
  xgl_RenderLooprender(nullptr);
}*/