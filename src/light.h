#pragma once


enum class LightType : int {
  Point = 1,
  Directional = 2,
  Spotlight = 3
};


class Light {
public:
  virtual LightType getType() const = 0;
};


class PointLight : public Light {
public:
  PointLight(const glm::vec3& position, const glm::vec4& color) 
    : position(position)
    , color(color) {
  }

  LightType getType() const override { return LightType::Point; }

  const glm::vec3& getPosition() const { return position; }
  void setPosition(const glm::vec3& position) { this->position = position; }

  const glm::vec4 getColor() const { return color; }
  void setColor(const glm::vec4& color) { this->color = color; }

private:
  glm::vec3 position;
  glm::vec4 color;
};
