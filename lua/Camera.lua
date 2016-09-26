local torch = require 'torch'
local xgl = require 'xgl.env'
local utils = require 'xgl.utils'

local Camera = torch.class('xgl.Camera', xgl)

function init()
  local method_names = {
    'new',
    'delete',
    'getImageSize',
    'setImageSize',
    'getClipNearFar',
    'setClipNearFar',
    'getAspectRatio',
    'getPrincipalPoint',
    'getFocalLength',
    'setIntrinsics',
    'createRenderTarget',
    'copyRenderResultF32',
    'unprojectDepthImage',
    'copyRenderResult',
    'swapBuffers',
    'lookAt',
    'getViewMatrix',
    'setViewMatrix',
    'getProjectionMatrix',
    'setProjectionMatrix',
    'getPosition',
    'getPose',
    'setPose',
    'getIntrinsicMatrix',
    'perspective'
  }

  return utils.create_method_table('xgl_Camera_', method_names)
end

local f = init()

function Camera.perspective(fov, aspect, near, far, output)
  local view = output or torch.DoubleTensor()
  print(view)
  f.perspective(fov, aspect, near, far, view:cdata())
  return view
end

function Camera:__init()
  self.o = f.new()
end

function Camera:cdata()
  return self.o
end

function Camera:getImageSize()
  local sz = torch.IntTensor()
  f.getImageSize(self.o, sz:cdata())
  return sz
end

function Camera:getWidth()
  return self:getImageSize()[1]
end

function Camera:getHeight()
  return self:getImageSize()[2]
end

function Camera:setImageSize(_1, _2)
  local width, height
  if type(_1) == 'number' and type(_2) == 'number' then
    width,height = _1,_2
  elseif torch.isTensor(_1) then
    width,height = _1[1],_1[2]
  else
    error('Invalid size specified.')
  end
  f.setImageSize(self.o, width, height)
end

function Camera:getClipNearFar()
  local t = torch.DoubleTensor();
  f.getClipNearFar(self.o, t:cdata())
  return t
end

function Camera:setClipNearFar(_1, _2)
  local near, far
    if type(_1) == 'number' and type(_2) == 'number' then
    near,far = _1,_2
  elseif torch.isTensor(_1) then
    near,far = _1[1],_1[2]
  else
    error('Invalid arguments specified.')
  end
  f.setClipNearFar(self.o, near, far)
end

function Camera:getAspectRatio()
  return f.getAspectRatio(self.o)
end

function Camera:getPrincipalPoint()
  local p = torch.DoubleTensor()
  f.getPrincipalPoint(self.o, p:cdata())
  return p
end

function Camera:getFocalLength()
  local f = torch.DoubleTensor()
  f.getFocalLength(self.o, f:cdata())
  return f
end

function Camera:setIntrinsics(fx, fy, cx, cy, im_width, im_height)
  f.setIntrinsics(self.o, fx, fy, cx, cy)
  if im_width ~= nil and im_height ~= nil then
    self:setImageSize(im_width, im_height)
  end
end

function Camera:createRenderTarget()
  f.createRenderTarget(self.o)
end

function Camera:copyRenderResult(vflip, output)
  if vflip == nil then vflip = true end
  output = output or torch.ByteTensor()
  f.copyRenderResult(self.o, vflip, output:cdata())
  return output
end

function Camera:copyRenderResultF32(vflip, output)
  if vflip == nil then vflip = true end
  output = output or torch.FloatTensor()
  f.copyRenderResultF32(self.o, vflip, output:cdata())
  return output
end

function Camera:unprojectDepthImage(depth_input, xyz_output, output_stride)
  f.unprojectDepthImage(self.o, depth_input:cdata(), xyz_output:cdata(), output_stride)
end

function Camera:swapBuffers()
  f.swapBuffers(self.o)
end

function Camera:lookAt(eye, at, up)
  if type(eye) == 'table' then
    eye = torch.DoubleTensor(eye)
  end
  at = at or torch.DoubleTensor({0,0,0})
  if type(at) == 'table' then
    at = torch.DoubleTensor(at)
  end
  up = up or torch.DoubleTensor({0,1,0})
  if type(up) == 'table' then
    up = torch.DoubleTensor(up)
  end
  f.lookAt(self.o, eye:cdata(), at:cdata(), up:cdata())
end

function Camera:getViewMatrix(output)
  output = output or torch.DoubleTensor()
  f.getViewMatrix(self.o, output:cdata())
  return output
end

function Camera:setViewMatrix(viewMatrix)
  f.setViewMatrix(self.o, viewMatrix:cdata())
end

function Camera:getProjectionMatrix(output)
  output = output or torch.DoubleTensor()
  f.getProjectionMatrix(self.o, output:cdata())
  return output
end

function Camera:setProjectionMatrix(input)
  f.setProjectionMatrix(self.o, input:cdata())
end

function Camera:getPosition(output)
  output = output or torch.DoubleTensor()
  f.getPosition(self.o, output:cdata())
  return output
end

function Camera:getPose(output)
  output = output or torch.DoubleTensor()
  f.getPose(self.o, output:cdata())
  return output
end

function Camera:setPose(pose)
  f.setPose(self.o, pose:cdata())
end

function Camera:getIntrinsicMatrix(output)
  output = output or torch.DoubleTensor()
  f.getIntrinsicMatrix(self.o, output:cdata())
  return output
end

function Camera:setIntrinsicMatrix(intrinsic)
  f.setIntrinsicMatrix(self.o, intrinsic:cdata())
end
