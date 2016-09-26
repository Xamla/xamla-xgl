local ros = require 'ros'

local cv = require 'cv'

require 'cv.imgcodecs'
require 'cv.highgui'
require 'cv.imgproc'
require 'cv.calib3d'

local xgl = require 'xgl'


local CALIBRATION_DATA_FILENAME = 'data/rgb_camIntrinsics_v2.t7'
local GRIPPER_MODEL_FILENAME = 'data/xamla_jaw_weiss_w3.stl'
local GRIPPER_MARKER_OFFSET =  xgl.rotateAxis({0,0,1}, -0.5 * math.pi) * xgl.translate({-0.0125, -0.0050, 0.0})
local LEFT_UPPER_CORNER_TO_ORIGIN = xgl.translate({-0.00129, 0.00177, 12.375})
local MM_TO_M = xgl.scale(0.001)


local calibration_data = torch.load(CALIBRATION_DATA_FILENAME)
local pattern = { type = cv.CALIB_CB_ASYMMETRIC_GRID, geom = { height = 5, width = 4 }, point_size = 1.5 }
local im_width, im_height = calibration_data[5][1], calibration_data[5][2]
local camera_matrix = calibration_data[6]
local dist_coeffs = calibration_data[7]

-- Generate ground truth circle center points of the calibration pattern.
-- Z is set to 0 for all points.
function generatePatternPoints(points_X, points_Y, point_size)
  -- Input params:
  --  arg.pointsX   -- number of points in horizontal direction
  --  arg.pointsY   -- number of points in vertical direction
  --  arg.pointSize -- size of one point in mm

  -- calculates the groundtruth x, y, z positions of the points of the asymmetric circle pattern
  local corners = torch.FloatTensor(points_X * points_Y, 1, 3):zero()
  local i=1
  for y=1, points_X do
    for x=1, points_Y do
      corners[i][1][1] = (2*(x-1) + (y-1)%2) * point_size
      corners[i][1][2] = (y-1)*point_size
      corners[i][1][3] = 0
      i = i+1
    end
  end
  return corners
end

local function rotVectorToMat3x3(vec)
  -- transform a rotation vector as e.g. provided by solvePnP to a 3x3 rotation matrix using the Rodrigues' rotation formula
  -- see e.g. http://docs.opencv.org/2.4/modules/calib3d/doc/camera_calibration_and_3d_reconstruction.html#void%20Rodrigues%28InputArray%20src,%20OutputArray%20dst,%20OutputArray%20jacobian%29

  local theta = torch.norm(vec)
  local r = vec/theta
  r=torch.squeeze(r)
  local mat = torch.Tensor({{0, -1*r[3], r[2]}, {r[3], 0, -1*r[1]}, {-1*r[2], r[1], 0}})
  r = r:resize(3,1)

  local result = torch.eye(3)*math.cos(theta) + (r*r:t())*(1-math.cos(theta)) + mat*math.sin(theta)

  return result
end

local function generatePose(rot, pos)
  local pose = torch.eye(4)
  pose[{{1,3},{1,3}}] = rotVectorToMat3x3(rot)
  pose[{{1,3}, {4}}] = pos * 0.001    -- mm to m
  return pose
end

-- generate ground truth pattern
local circle_positions = generatePatternPoints(5, 4, 1.5)


local function undistort(img)
  local undistImage = cv.undistort { src = img, cameraMatrix = camera_matrix, distCoeffs = dist_coeffs }
  --cv.imwrite { 'undistorted_input.png', undistImage }
  return undistImage
end

local function RGBtoBGR(img)
  local out = img.new():resizeAs(img)
  cv.cvtColor{img, out, cv.COLOR_RGB2BGR}
  return out
end


local function findTargetPose(img)
  -- find circle pattern
  local ok, centers = cv.findCirclesGrid { image = img, patternSize = pattern.geom, flags = pattern.type }
  if not ok then
    error('Pattern not found!')
  end

  --[[print('Found pattern center points:')
  print(centers)]]

  -- estimate pattern pose
  local ok, target_rot, target_pos = cv.solvePnP { objectPoints = circle_positions, imagePoints = centers, cameraMatrix = camera_matrix, distCoeffs = torch.Tensor({0,0,0,0}) }
  if not ok then
    error('Could not estimate pose: solvePnp failed!')
  end

  return generatePose(target_rot, target_pos)
end


local scene, camera, gripper_model, s0, s1, s2, s3, overlay, overlay_material


local function initGraphics()
  local w,h = calibration_data[5][1], calibration_data[5][2]
  xgl.init(true, w, h)

  scene = xgl.SimpleScene()

  camera = xgl.Camera()
  local fx = camera_matrix[{1,1}]
  local fy = camera_matrix[{2,2}]
  local cx = camera_matrix[{1,3}]
  local cy = camera_matrix[{2,3}]
  camera:setIntrinsics(fx, fy, cx, h - cy, w, h)    -- (h - cy) inverts the vertical principal point center-offset
  camera:lookAt({0,0,0}, {0,0,1}, {0,-1,0})         -- look along z-axis, negative y up
  scene:setCamera(camera)

  local fullscreen_Shader = xgl.Shader("../shaders/FullScreen.VertexShader.glsl", "../shaders/FullScreen.FragmentShader.glsl")
  overlay = scene:addQuad(2, 2, fullscreen_Shader, nil, 1, false)
  overlay_material = overlay:getMeshAt(1):getMaterial()

  local shader = xgl.Shader("../shaders/Basic.VertexShader.glsl", "../shaders/BasicLighting.FragmentShader.glsl")
  gripper_model = xgl.Model(shader, GRIPPER_MODEL_FILENAME)
  gripper_model:getMeshAt(1):getMaterial():setOpacity(0.5)
  scene:addModel(gripper_model)

  s0 = xgl.geo.sphere(0.001, 1)
  s1 = xgl.geo.sphere(0.0005, 1)
  s2 = xgl.geo.sphere(0.0005, 1)
  s3 = xgl.geo.sphere(0.0005, 1)

  scene:addModel(s0)
  scene:addModel(s1)
  scene:addModel(s2)
  scene:addModel(s3)
end


local function shutdownGraphics()
  xgl.terminate()
end


local function render()
  scene:setClearColor(0,0,0,1)
  scene:render()
  camera:swapBuffers()
  xgl.pollEvents()
end


local function processFrame(img)
  img = undistort(img)
  local marker_pose = findTargetPose(img)
  print(marker_pose)

  -- update 'dummy' coordinate system
  s0:setPose(marker_pose)
  s1:setPose(marker_pose * xgl.translate({ 0.01,    0,   0}))
  s2:setPose(marker_pose * xgl.translate({    0, 0.01,   0}))
  s3:setPose(marker_pose * xgl.translate({    0,    0, 0.01}))

  gripper_model:setPose(marker_pose * GRIPPER_MARKER_OFFSET * MM_TO_M * LEFT_UPPER_CORNER_TO_ORIGIN)

  overlay_material:updateTextureRGB8(0, img:size(2), img:size(1), RGBtoBGR(img), true, true)

  render()

  collectgarbage()
end


local function main()
  initGraphics()

  ros.init('griper_tracker')

  local nh = ros.NodeHandle()

  local subscriber = nh:subscribe("/ximea/image_raw", 'sensor_msgs/Image', 1)

  while ros.ok() do

    if subscriber:hasMessage() then
      local msg = subscriber:read()
      local w,h = msg.width,msg.height

      local image = msg.data
      image = image:reshape(h,w,3)
      processFrame(image)
    end

    ros.spinOnce()
    sys.sleep(0.05)
  end

  ros.shutdown()

  shutdownGraphics()
end


main()
