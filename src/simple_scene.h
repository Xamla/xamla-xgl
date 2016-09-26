#pragma once

#include "camera.h"
#include "light.h"


class SimpleScene {
public:
  SimpleScene()
    : camera(nullptr)
    , clearColor(0, 0, 0, 1) {
  }

  void render(RenderTargetType renderTarget = RenderTargetType::MultiSampling) {

    camera->activateRenderTarget(renderTarget);

    glClearColor(clearColor[0], clearColor[1], clearColor[2], clearColor[3]);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);   // set less or equal depth function for multi-pass rendering
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glm::mat4 view = camera->getViewMatrix();
    glm::mat4 projection = camera->getProjectionMatrix();

    if (lights.empty()) {
      // render with default light
      PointLight defaultLight(glm::vec3(3, -5, -2), glm::vec4(1, 1, 1, 1));
      for (auto m : models) {
        m->draw(view, projection, defaultLight, overrideMaterial.get());
      }
    }
    else {
      for (auto l : lights) {
        for (auto m : models) {
          m->draw(view, projection, *l, overrideMaterial.get());
        }
      }    
    }
  }

  void setCamera(Camera *camera) {
    this->camera = camera;
  }

  void addModel(Model *model) {
    models.push_back(model);
  }

  void clearModels() {
    models.clear();
  }

  void addLight(Light *light) {
    lights.push_back(light);
  }

  void clearLights() {
    lights.clear();
  }

  void setClearColor(float r, float g, float b, float a) {
    this->setClearColor(glm::vec4(r, g, b, a));
  }

  void setClearColor(const glm::vec4& rgba) {
    clearColor = rgba;
  }

  std::shared_ptr<Material> getOverrideMaterial() const {
    return overrideMaterial;
  }

  void setOverrideMaterial(const std::shared_ptr<Material>& value) {
    overrideMaterial = value;
  }

private:
  Camera *camera;
  std::vector<Model*> models;
  std::vector<Light*> lights;
  glm::vec4 clearColor;
  std::shared_ptr<Material> overrideMaterial;
};
