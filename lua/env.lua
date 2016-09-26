local ffi = require 'ffi'

local xgl = {}

--[[
helper regex:
XGLIMP\((.+?), (\w+), (\w+)\)(.*)$
\1 xgl_\2_\3\4
]]

local xgl_cdef = [[
typedef struct FrameBufferLimits {
  int maxColorAttachments;
  int maxWidth;
  int maxHeight;
  int maxSamples;
  int maxLayers;
} FrameBufferLimits;

typedef struct Camera {} Camera;
typedef struct Model {} Model;
typedef struct Shader {} Shader;
typedef struct SimpleScene {} SimpleScene;
typedef struct MaterialHandle {} MaterialHandle;
typedef struct MeshHandle {} MeshHandle;
typedef struct ShaderHandle {} ShaderHandle;

void xgl___init(bool show_window, int window_width, int window_height);
void xgl___terminate();
void xgl___pollEvents();
bool xgl___windowShouldClose();

Camera *xgl_Camera_new();
void xgl_Camera_delete(Camera *camera);
void xgl_Camera_getImageSize(Camera *camera, THIntTensor *output);
void xgl_Camera_setImageSize(Camera *camera, int width, int height);
void xgl_Camera_getClipNearFar(Camera *camera, THDoubleTensor *output);
void xgl_Camera_setClipNearFar(Camera *camera, float near, float far);
float xgl_Camera_getAspectRatio(Camera *camera);
void xgl_Camera_getPrincipalPoint(Camera *camera, THDoubleTensor *output);
void xgl_Camera_getFocalLength(Camera *camera, THDoubleTensor *output);
void xgl_Camera_setIntrinsics(Camera *camera, float fx, float fy, float cx, float cy);
void xgl_Camera_copyRenderResult(Camera *camera, bool vflip, THByteTensor *output);
void xgl_Camera_copyRenderResultF32(Camera *camera, bool vflip, THFloatTensor *output);
void xgl_Camera_unprojectDepthImage(Camera *camera, THFloatTensor *depthInput, THFloatTensor *xyzOutput, int outputStride);
void xgl_Camera_swapBuffers(Camera *camera);
void xgl_Camera_lookAt(Camera *camera, THDoubleTensor *eye, THDoubleTensor *at, THDoubleTensor *up);
void xgl_Camera_getViewMatrix(Camera *camera, THDoubleTensor *output);
void xgl_Camera_setViewMatrix(Camera *camera, THDoubleTensor *input);
void xgl_Camera_getProjectionMatrix(Camera *camera, THDoubleTensor *output);
void xgl_Camera_setProjectionMatrix(Camera *camera, THDoubleTensor *input);
void xgl_Camera_getPosition(Camera *camera, THDoubleTensor *output);
void xgl_Camera_getPose(Camera *camera, THDoubleTensor *output);
void xgl_Camera_setPose(Camera *camera, THDoubleTensor *input);
void xgl_Camera_getIntrinsicMatrix(Camera *camera, THDoubleTensor *output);
void xgl_Camera_setIntrinsicMatrix(Camera *camera, THDoubleTensor *input);
void xgl_Camera_perspective(float fov, float aspect, float near, float far, THDoubleTensor *output);

ShaderHandle *xgl_Shader_new();
void xgl_Shader_delete(ShaderHandle *shader);
void xgl_Shader_release(ShaderHandle *shader);
bool xgl_Shader_isNull(ShaderHandle *shader);
void xgl_Shader_create(ShaderHandle *shader, const char *vertexShaderSources, const char *fragmentShaderSource);
void xgl_Shader_load(ShaderHandle *shader, const char *vertexShaderPath, const char *fragmenShaderPath);

Model *xgl_Model_new(ShaderHandle *defaultShader);
void xgl_Model_delete(Model *model);
void xgl_Model_loadModel(Model *model, const char *filePath);
void xgl_Model_getPose(Model *model, THDoubleTensor *output);
void xgl_Model_setPose(Model *model, THDoubleTensor *input);
void xgl_Model_addMesh(Model *model, MeshHandle *mesh);
void xgl_Model_addMesh_Tensor(Model *model, THFloatTensor *vertices, THIntTensor *indices, ShaderHandle *shader, THFloatTensor *color);
int xgl_Model_getMeshCount(Model *model);
void xgl_Model_getMeshAt(Model *model, int index, MeshHandle *output);

MaterialHandle * xgl_Material_new();
void xgl_Material_delete(MaterialHandle *material);
void xgl_Material_create(MaterialHandle *material);
void xgl_Material_release(MaterialHandle *material);
bool xgl_Material_isNull(MaterialHandle *material);
void xgl_Material_getDiffuseColor(MaterialHandle *material, THFloatTensor *output);
void xgl_Material_setDuffuseColor(MaterialHandle *material, THFloatTensor *input);
void xgl_Material_setShader(MaterialHandle *material, ShaderHandle *input);
void xgl_Material_getShader(MaterialHandle *material, ShaderHandle *output);
float xgl_Material_getShininess(MaterialHandle *material);
void xgl_Material_setShininess(MaterialHandle *material, float value);
float xgl_Material_getOpacity(MaterialHandle *material);
void xgl_Material_setOpacity(MaterialHandle *material, float value);
bool xgl_Material_getFacetCulling(MaterialHandle *material);
void xgl_Material_setFacetCulling(MaterialHandle *material, bool value);
bool xgl_Material_getDepthTest(MaterialHandle *material);
void xgl_Material_setDepthTest(MaterialHandle *material, bool value);
bool xgl_Material_getDepthWrite(MaterialHandle *material);
void xgl_Material_setDepthWrite(MaterialHandle *material, bool value);
void xgl_Material_updateTextureRGB8(MaterialHandle *material, int index, int width, int height, THByteTensor *image, bool flipV, bool generateMipmap);

MeshHandle * xgl_Mesh_new();
void xgl_Mesh_delete(MeshHandle *mesh);
void xgl_Mesh_create(MeshHandle *mesh, THFloatTensor *vertices, THIntTensor *indices, MaterialHandle *material);
void xgl_Mesh_release(MeshHandle *mesh);
bool xgl_Mesh_isNull(MeshHandle *mesh);
void xgl_Mesh_getMaterial(MeshHandle *mesh, MaterialHandle *output);
void xgl_Mesh_setMaterial(MeshHandle *mesh, MaterialHandle *input);

SimpleScene *xgl_SimpleScene_new();
void xgl_SimpleScene_delete(SimpleScene *scene);
void xgl_SimpleScene_render(SimpleScene *scene);
void xgl_SimpleScene_renderDepth(SimpleScene *scene);
void xgl_SimpleScene_setClearColor(SimpleScene *scene, float r, float g, float b, float a);
void xgl_SimpleScene_getOverrideMaterial(SimpleScene *scene, MaterialHandle *output);
void xgl_SimpleScene_setOverrideMaterial(SimpleScene *scene, MaterialHandle *input);
void xgl_SimpleScene_setCamera(SimpleScene *scene, Camera *camera);
void xgl_SimpleScene_addModel(SimpleScene *scene, Model *model);
void xgl_SimpleScene_clearModels(SimpleScene *scene);
void xgl_SimpleScene_addQuad(SimpleScene *scene, Model *model, float xdim, float ydim, ShaderHandle *shader, const char *textureFilename, float opacity, bool depthWrite);

void xgl_FrameBuffer_getLimits(FrameBufferLimits *limits);
]]

ffi.cdef(xgl_cdef)

xgl.lib = ffi.load(package.searchpath('libxgl', package.cpath))

return xgl
