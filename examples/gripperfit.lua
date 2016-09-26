local cv = require 'cv'

require 'cv.imgcodecs'
require 'cv.highgui'
require 'cv.imgproc'
require 'cv.calib3d'

local xgl = require 'xgl'
local image = require 'image'


local CALIBRATION_DATA_FILENAME = 'data/rgb_camIntrinsics_v2.t7'
local PATTERN_FILENAME = 'data/gripper1.jpg'
local GRIPPER_MODEL_FILE = 'data/xamla_jaw_weiss_w3.stl'

-- rough estimate of marker offest
local GRIPPER_MARKER_OFFSET =  xgl.rotateAxis({0,0,1}, -0.5 * math.pi) * xgl.translate({-0.0125, -0.0050, 0.0})
local LEFT_UPPER_CORNER_TO_ORIGIN = xgl.translate({-0.00129, 0.00177, 12.375})
local MM_TO_M = xgl.scale(0.001)

--[[
{
  1 : 8
  2 : 21
  3 : 5
  4 : true
  5 :
    {
      1 : 2040
      2 : 1080
    }
  6 : DoubleTensor - size: 3x3
  7 : DoubleTensor - size: 1x5
}

Kameramatrix:

th> x[6]
 4905.4779     0.0000   965.8267
    0.0000  4898.6164   482.8961
    0.0000     0.0000     1.0000
[torch.DoubleTensor of size 3x3]
]]

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


-- generate ground truth pattern
local circle_positions = generatePatternPoints(5, 4, 1.5)

-- load image
local img = cv.imread { PATTERN_FILENAME }


-- undistort image
local undistImage = cv.undistort { src = img, cameraMatrix = camera_matrix, distCoeffs = dist_coeffs }
cv.imwrite { 'undistorted_input.png', undistImage }

-- find circle pattern
local ok, centers = cv.findCirclesGrid { image = undistImage, patternSize = pattern.geom, flags = pattern.type }
if not ok then
  error('Pattern not found!')
end

print('Found pattern center points:')
print(centers)

-- estimate pattern pose
local ok, target_rot, target_pos = cv.solvePnP { objectPoints = circle_positions, imagePoints = centers, cameraMatrix = camera_matrix, distCoeffs = torch.Tensor({0,0,0,0}) }
if not ok then
  error('Could not estimate pose: solvePnp failed!')
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

local marker_pose = generatePose(target_rot, target_pos)
print("Estimated Pose:")
print(marker_pose)


-- initialize xgl
local w,h = calibration_data[5][1], calibration_data[5][2]
xgl.init(true, w, h)


local scene = xgl.SimpleScene()

-- prepare camera
local camera = xgl.Camera()
local fx = camera_matrix[{1,1}]
local fy = camera_matrix[{2,2}]
local cx = camera_matrix[{1,3}]
local cy = camera_matrix[{2,3}]
camera:setIntrinsics(fx, fy, cx, h - cy, w, h)      -- (h - cy) inverts the vertical principal point center-offset
camera:lookAt({0,0,0}, {0,0,1}, {0,-1,0})
scene:setCamera(camera)

local fullScreenShader = xgl.Shader("../shaders/FullScreen.VertexShader.glsl", "../shaders/FullScreen.FragmentShader.glsl")
local overlayQuad = scene:addQuad(2,2, fullScreenShader, 'undistorted_input.png', 1, true)


local shader = xgl.getDefaultShader()
local model = xgl.Model(shader, GRIPPER_MODEL_FILE)
model:getMeshAt(1):getMaterial():setOpacity(0.5)
scene:addModel(model)

local s0 = xgl.geo.sphere(0.001, 1)
local s1 = xgl.geo.sphere(0.0005, 1)
local s2 = xgl.geo.sphere(0.0005, 1)
local s3 = xgl.geo.sphere(0.0005, 1)
s0:setPose(marker_pose)
s1:setPose(marker_pose * xgl.translate({ 0.01,    0,   0}))
s2:setPose(marker_pose * xgl.translate({    0, 0.01,   0}))
s3:setPose(marker_pose * xgl.translate({    0,    0, 0.01}))
scene:addModel(s0)
scene:addModel(s1)
scene:addModel(s2)
scene:addModel(s3)

model:setPose(marker_pose * GRIPPER_MARKER_OFFSET * MM_TO_M * LEFT_UPPER_CORNER_TO_ORIGIN)

while not xgl.windowShouldClose() do
  local t = sys.clock()

  scene:setClearColor(0,0,0,1)
  scene:render()
  camera:swapBuffers()
  xgl.pollEvents()
  sys.sleep(0.1)
end

main()
