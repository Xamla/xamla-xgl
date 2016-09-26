#pragma once

class FrameBuffer {
public:
  FrameBuffer()
    : id(0) {
    glGenFramebuffers(1, &id);
  }

  ~FrameBuffer() {
    glDeleteFramebuffers(1, &id);
  }

  void bind(GLenum target = GL_FRAMEBUFFER) {
    glBindFramebuffer(target, id);
  }

  void unbind(GLenum target = GL_FRAMEBUFFER) {
    glBindFramebuffer(target, 0);
  }

  GLuint getId() const {
    return id;
  }

  static std::string getErrorMessage(GLenum status) {
     switch(status) {
      case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT: return "Incomplete Attachment";
      case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT: return "Missing Attachment";
      case GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER: return "Incomplete Draw Buffer";
      case GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER: return "Incomplete Read Buffer";
      case GL_FRAMEBUFFER_UNSUPPORTED: return "Unsupposed Configuration";
      default: return "Unknown Error";
    }
  }

  GLenum check(bool may_throw = false) const {
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE && may_throw) {
      throw std::runtime_error(getErrorMessage(status));
    }
    return status;
  }

  bool ready() {
    return check() == GL_FRAMEBUFFER_COMPLETE;
  }

private:
  GLuint id;
};


class RenderBuffer {
public:
  RenderBuffer() {
    glGenRenderbuffers(1, &id);
  }

  ~RenderBuffer() {
    glDeleteRenderbuffers(1, &id);
  }

  void bind() {
    glBindRenderbuffer(GL_RENDERBUFFER, id);
  }

  GLuint getId() const {
    return id;
  }

private:
  GLuint id;
};

enum class RenderTargetType {
  None = 0,
  MultiSampling = 1,
  Depth = 2
};


class Camera
{
public:
    Camera(
      const glm::vec3 &eye = glm::vec3(0.0f, 5.0f, 5.0f),
      const glm::vec3 &at = glm::vec3(0.0f, 0.0f, 0.0f),
      const glm::vec3 &up = glm::vec3(0.0f, 1.0f, 0.0f)
    )
      : fx(1000)
      , fy(1000)
      , cx(500)
      , cy(500)
      , im_height(1000)
      , im_width(1000)
      , near(0.01f)
      , far(10)
      , normalTextureId(0)
      , renderTargetTextureId(0)
      , depthTextureId(0)
      , renderTargetReady(false)
      , renderTarget(RenderTargetType::None)
      , view(1)
      , intrinsicsProjection(false)
      , projection(glm::perspectiveRH(1.0f, 1.0f, 0.1f, 100.f)) {
      this->lookAt(eye, at, up);
    }

    ~Camera() {
      destroyRenderTarget();
    }

    void setIntrinsics(float fx, float fy, float cx, float cy) {
      this->fx = fx;
      this->fy = fy;
      this->cx = cx;
      this->cy = cy;
      intrinsicsProjection = true;
      rebuildProjectionMatrix = true;
    }

    glm::mat3 getIntrinsicMatrix() const {
      return glm::mat3(   // open cv uses colmun major ordering
        fx,   0,  0,
        0,   fy,  0,
        cx,  cy,  1
      );
    }

    void setIntrinsicMatrix(const glm::mat3& intrinsic) {
      if (intrinsic[1][0] != 0) {
        throw XglException("Axis skew not supported.");
      }

      this->setIntrinsics(
        intrinsic[0][0], // fx
        intrinsic[1][1], // fy
        intrinsic[2][0], // cx
        intrinsic[2][1]  // cy
      );
    }

    glm::vec2 getPrincipalPoint() const {
      return glm::vec2(cx, cy);
    }

    glm::vec2 getFocalLength() const {
      return glm::vec2(fx, fy);
    }

    glm::ivec2 getImageSize() const {
      return glm::ivec2(im_width, im_height);
    }

    void setImageSize(int im_width, int im_height) {
      if (this->im_height != im_height || this->im_width != im_width) {
        this->im_height = im_height;
        this->im_width = im_width;
        destroyRenderTarget();      // ensure render target textures are resized
      }
    }

    void setImageSize(const glm::ivec2& sz) {
      this->setImageSize(sz[0], sz[1]);
    }

    glm::vec2 getClipNearFar() const {
      return glm::vec2(near, far);
    }

    void setClipNearFar(GLfloat near, GLfloat far) {
      this->near = near;
      this->far = far;
      rebuildProjectionMatrix = true;
    }

    void setClipNearFar(const glm::vec2& value) {
      this->setClipNearFar(value.x, value.y);
    }

    glm::mat4 getPose() const {
      return glm::inverse(view);
    }

    void setPose(const glm::mat4& pose) {
      view = glm::inverse(pose);
    }

    glm::vec3 getPosition() const {
      return glm::vec3(this->getPose()[3]);
    }

    float getAspectRatio() const {
      return static_cast<float>(im_width) / im_height;
    }

    void activateRenderTarget(RenderTargetType type = RenderTargetType::MultiSampling) {
      if (!renderTargetReady) {
        createRenderTarget();
      }

      if (type == RenderTargetType::MultiSampling) {
        multiSampleFrameBuffer.bind();
        renderTarget = RenderTargetType::MultiSampling;
        glViewport(0, 0, im_width, im_height);
        glEnable(GL_MULTISAMPLE);
        GLenum drawBuffers[1] = { GL_COLOR_ATTACHMENT0 };
        glDrawBuffers(1, drawBuffers);
      } else if (type == RenderTargetType::Depth) {
        depthFrameBuffer.bind();
        renderTarget = RenderTargetType::Depth;
        glViewport(0, 0, im_width, im_height);
        GLenum drawBuffers[1] = { GL_COLOR_ATTACHMENT0 };
        glDrawBuffers(1, drawBuffers);
      } else {
        glBindRenderbuffer(GL_RENDERBUFFER, 0);
        renderTarget = RenderTargetType::None;
      }
    }

    void copyToNormalFrameBuffer() {
      if (renderTarget == RenderTargetType::MultiSampling) {
        multiSampleFrameBuffer.bind(GL_READ_FRAMEBUFFER);       // Bind the FBO for reading
        normalFrameBuffer.bind(GL_DRAW_FRAMEBUFFER);            // Bind the normal FBO for drawing

        // Blit the multisampled FBO to the normal FBO
        glBlitFramebuffer(0, 0, im_width, im_height, 0, 0, im_width, im_height, GL_COLOR_BUFFER_BIT, GL_NEAREST);

        normalFrameBuffer.bind();       // Bind the normal FBO for reading
      }
    }

    void setProjectionMatrix(const glm::mat4& projection) {
      this->projection = projection;
      intrinsicsProjection = false;
    }

    glm::mat4 getProjectionMatrix() {
      updateProjectionMatrix();
      return projection;
    }

    glm::mat4 getViewMatrix() const {
      return view;
    }

    void setViewMatrix(const glm::mat4 &view) {
      this->view = view;
    }

    void lookAt(
      const glm::vec3 &eye,
      const glm::vec3 &at = glm::vec3(0,0,0),
      const glm::vec3 &up = glm::vec3(0.0f, 1.0f, 0.0f)
    ) {
       view = glm::lookAtRH(eye, at, up);
    }

    void unprojectDepthImage(float *depthInput, float *xyzOutput, int outputStride) {

      for (float y = im_height - 0.5f; y > 0; y -= 1.0f) {

        float ry_ = (y - im_height+cy) / fy;

        for (float x = 0.5f; x < im_width; x += 1.0f) {

          float rz = *depthInput++;
          float ry = rz * ry_;
          float rx = rz * (x - cx) / fx;

          xyzOutput[0] = rx;
          xyzOutput[1] = ry;
          xyzOutput[2] = rz;

          xyzOutput += outputStride;
        }
      }

    }

private:
  GLfloat fx;
  GLfloat fy;
  GLfloat cx;
  GLfloat cy;

  GLfloat im_width;
  GLfloat im_height;
  GLfloat near;
  GLfloat far;

  glm::mat4 view;
  glm::mat4 projection;

  bool intrinsicsProjection;
  bool rebuildProjectionMatrix;

  bool renderTargetReady;
  FrameBuffer normalFrameBuffer;
  RenderBuffer normalColorBuffer;
  GLuint normalTextureId;

  FrameBuffer multiSampleFrameBuffer;
  RenderBuffer multiSampleColorBuffer;
  RenderBuffer multiSampleDepthBuffer;
  GLuint renderTargetTextureId;

  FrameBuffer depthFrameBuffer;
  RenderBuffer depthRenderBuffer;
  RenderBuffer depthDepthBuffer;
  GLuint depthTextureId;

  RenderTargetType renderTarget;

  void updateProjectionMatrix() {
    if (rebuildProjectionMatrix) {
      if (intrinsicsProjection) {
        // Using glm::ortho() to get the normalized device coordinates (NDC).
        // see http://ksimek.github.io/2013/06/03/calibrated_cameras_in_opengl/

        const float A = near + far;
        const float B = near * far;
        glm::mat4 persp(
           fx,    0,    0,     0,
            0,   fy,    0,     0,
          -cx,  -cy,    A, -1.0f,
            0,    0,    B,     0
        );

        // rebuild projection matrix
        glm::mat4 ndc = glm::ortho(0.0f, (float)im_width, 0.0f, (float)im_height, near, far);
        this->projection = ndc * persp;
      }

      rebuildProjectionMatrix = false;
    }
  }

  void createRenderTarget() {
    // create normal output texture
    glGenTextures(1, &normalTextureId);
    glBindTexture(GL_TEXTURE_2D, normalTextureId);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8, im_width, im_height, 0, GL_RGB, GL_UNSIGNED_BYTE, 0);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);

    // normal color buffer
    normalColorBuffer.bind();
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, im_width, im_height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, normalColorBuffer.getId());

    normalFrameBuffer.bind();
    glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, normalTextureId, 0);
    normalFrameBuffer.unbind();

    // === multi sampling rendertarget ===
    glGenTextures(1, &renderTargetTextureId);
    glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, renderTargetTextureId);
    glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE, 16, GL_RGB8, im_width, im_height, GL_TRUE);

    // create color buffer
    multiSampleColorBuffer.bind();
    glRenderbufferStorageMultisample(GL_RENDERBUFFER, 16, GL_RGB8, im_width, im_height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, multiSampleColorBuffer.getId());

    // create depth buffer
    multiSampleDepthBuffer.bind();
    glRenderbufferStorageMultisample(GL_RENDERBUFFER, 16, GL_DEPTH24_STENCIL8, im_width, im_height);

    multiSampleFrameBuffer.bind();
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, multiSampleDepthBuffer.getId());
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, multiSampleDepthBuffer.getId());
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D_MULTISAMPLE, renderTargetTextureId, 0);
    multiSampleFrameBuffer.check(true);
    multiSampleFrameBuffer.unbind();

    // ==== float depth rendering ====
    glGenTextures(1, &depthTextureId);
    glBindTexture(GL_TEXTURE_2D, depthTextureId);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB32F, im_width, im_height, 0, GL_RED, GL_FLOAT, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindTexture(GL_TEXTURE_2D, 0);

    depthRenderBuffer.bind();
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, im_width, im_height);

    depthDepthBuffer.bind();
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, im_width, im_height);

    depthFrameBuffer.bind();
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthDepthBuffer.getId());
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, depthDepthBuffer.getId());
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, depthFrameBuffer.getId());
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, depthTextureId, 0);
    depthFrameBuffer.check(true);
    depthFrameBuffer.unbind();

    renderTargetReady = true;
  }

  void destroyRenderTarget() {
    if (normalTextureId != 0) {
      glDeleteTextures(1, &normalTextureId);
      normalTextureId = 0;
    }

    if (renderTargetTextureId != 0) {
      glDeleteTextures(1, &renderTargetTextureId);
      renderTargetTextureId = 0;
    }

    if (depthTextureId != 0) {
      glDeleteTextures(1, &depthTextureId);
      depthTextureId = 0;
    }

    renderTargetReady = false;
  }
};
