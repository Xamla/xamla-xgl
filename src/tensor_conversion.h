#pragma once

#include "xamla-gl.h"
#include <vector>


inline glm::vec3 Tensor2vec3(THDoubleTensor *tensor) {
  if (!tensor || THDoubleTensor_nElement(tensor) < 3)
    throw XglException("A tensor with at least 3 elements was expected.");
  THDoubleTensor *tensor_ = THDoubleTensor_newContiguous(tensor);
  double *data = THDoubleTensor_data(tensor_);
  glm::vec3 v(data[0], data[1], data[2]);
  THDoubleTensor_free(tensor_);
  return v;
}

inline glm::vec4 Tensor2vec4(THDoubleTensor *tensor) {
  if (!tensor || THDoubleTensor_nElement(tensor) < 4)
    throw XglException("A tensor with at least 4 elements was expected.");
  THDoubleTensor *tensor_ = THDoubleTensor_newContiguous(tensor);
  double *data = THDoubleTensor_data(tensor_);
  glm::vec4 v(data[0], data[1], data[2], data[3]);
  THDoubleTensor_free(tensor_);
  return v;
}

inline glm::vec4 Tensor2vec4(THFloatTensor *tensor) {
  if (!tensor || THFloatTensor_nElement(tensor) < 4)
    throw XglException("A tensor with at least 4 elements was expected.");
  THFloatTensor *tensor_ = THFloatTensor_newContiguous(tensor);
  float *data = THFloatTensor_data(tensor_);
  glm::vec4 v(data[0], data[1], data[2], data[3]);
  THFloatTensor_free(tensor_);
  return v;
}

void vec2ToTensor(const glm::ivec2& v, THIntTensor *output) {
  THIntTensor_resize1d(output, 2);
  THIntTensor_set1d(output, 0, v[0]);
  THIntTensor_set1d(output, 1, v[1]);
}

void vec2ToTensor(const glm::vec2& v, THDoubleTensor *output) {
  THDoubleTensor_resize1d(output, 2);
  THDoubleTensor_set1d(output, 0, v[0]);
  THDoubleTensor_set1d(output, 1, v[1]);
}

void vec3ToTensor(const glm::vec3& v, THDoubleTensor *output) {
  THDoubleTensor_resize1d(output, 3);
  THDoubleTensor_set1d(output, 0, v[0]);
  THDoubleTensor_set1d(output, 1, v[1]);
  THDoubleTensor_set1d(output, 2, v[2]);
}

void vec4ToTensor(const glm::vec4& v, THDoubleTensor *output) {
  THDoubleTensor_resize1d(output, 4);
  THDoubleTensor_set1d(output, 0, v[0]);
  THDoubleTensor_set1d(output, 1, v[1]);
  THDoubleTensor_set1d(output, 2, v[2]);
  THDoubleTensor_set1d(output, 3, v[3]);
}

void vec4ToTensor(const glm::vec4& v, THFloatTensor *output) {
  THFloatTensor_resize1d(output, 4);
  THFloatTensor_set1d(output, 0, v[0]);
  THFloatTensor_set1d(output, 1, v[1]);
  THFloatTensor_set1d(output, 2, v[2]);
  THFloatTensor_set1d(output, 3, v[3]);
}

template<typename TMat, int rows, int cols>
void copyMatrix(const TMat &m, THDoubleTensor *output) {
  THDoubleTensor_resize2d(output, rows, cols);
  THDoubleTensor* output_ = THDoubleTensor_newContiguous(output);
  double *data = THDoubleTensor_data(output_);
  for (int r = 0; r < rows; ++r) {
    for (int c = 0; c < cols; ++c) {
      *data++ = m[c][r];
    }
  }
  THDoubleTensor_freeCopyTo(output_, output);
}

template<typename TMat, int rows, int cols>
inline TMat Tensor2mat(THDoubleTensor *tensor) {
  if (tensor == NULL || tensor->nDimension != 2 || tensor->size[0] != rows && tensor->size[1] != cols)
    throw XglException("Invalid tensor size");

  TMat m;
  tensor = THDoubleTensor_newContiguous(tensor);
  double *data = THDoubleTensor_data(tensor);
  for (int r = 0; r < rows; ++r) {
    for (int c = 0; c < cols; ++c) {
      m[c][r] = *data++;
    }
  }
  THDoubleTensor_free(tensor);
  return m;
}

inline glm::mat4 Tensor2mat4(THDoubleTensor *tensor) {
  return Tensor2mat<glm::mat4, 4, 4>(tensor);
}

inline glm::mat3 Tensor2mat3(THDoubleTensor *tensor) {
  return Tensor2mat<glm::mat3, 3, 3>(tensor);
}

void IntTensorToIndices(THIntTensor *tensor, std::vector<GLuint>& indices) {
  tensor = THIntTensor_newContiguous(tensor);
  int *data = THIntTensor_data(tensor);
  const int n = THIntTensor_nElement(tensor);
  indices.resize(n);

  std::copy(data, data + n, indices.begin());

  THIntTensor_free(tensor);
}
