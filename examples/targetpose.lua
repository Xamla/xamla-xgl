local cv = require 'cv'

require 'cv.imgcodecs'
require 'cv.highgui'
require 'cv.imgproc'
require 'cv.calib3d'

local xgl = require 'xgl'
local image = require 'image'

local CALIBRATION_DATA_FILENAME = 'data/intrinsic.t7'
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

th> a[6]
 4865.4528     0.0000   969.9290
    0.0000  4860.3122   502.7275
    0.0000     0.0000     1.0000
[torch.DoubleTensor of size 3x3]
]]

local PATTERN_FILENAME = 'data/pattern.jpg'


-- load calibration data
local calibration_data = torch.load(CALIBRATION_DATA_FILENAME)
local pattern = { type = cv.CALIB_CB_ASYMMETRIC_GRID, geom = { height = calibration_data[2], width = calibration_data[1] }, point_size = calibration_data[3] }
local im_width, im_height = calibration_data[5][1], calibration_data[5][2]
local camera_matrix = calibration_data[6] 
local dist_coeffs = calibration_data[7]


-- Generate ground truth circle center points of the calibration pattern.
-- Z is set to 0 for all points.
function generatePatternPoints(arg)
  -- Input params:
  --  arg.pointsX   -- number of points in horizontal direction
  --  arg.pointsY   -- number of points in vertical direction
  --  arg.pointSize -- size of one point in mm

  -- calculates the groundtruth x, y, z positions of the points of the asymmetric circle pattern
  local corners = torch.FloatTensor(arg.pointsX * arg.pointsY, 1, 3):zero()
  local i=1
  for y=1, arg.pointsY do
    for x=1, arg.pointsX do
      corners[i][1][1] = (2*(x-1) + (y-1)%2) * arg.pointSize
      corners[i][1][2] = (y-1)*arg.pointSize
      corners[i][1][3] = 0
      i = i+1
    end
  end
  return corners
end


print('Pattern parameters:')
print(pattern)

print('Camera matrix:')
print(camera_matrix)


-- generate ground truth pattern 
local circle_positions = generatePatternPoints { pointsX = pattern.geom.width, pointsY = pattern.geom.height, pointSize = pattern.point_size }

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

--print('Found pattern center points:')
--print(centers)

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


function render(pose, camera_matrix, w, h, output_filename)
  xgl.init(true, 2040, 1080)

  local w,h = 2040, 1080 
  local scene = xgl.SimpleScene()

  -- configure camera
  local camera = xgl.Camera()
  
  -- set camera intrinsics
  local fx = camera_matrix[{1,1}]
  local fy = camera_matrix[{2,2}]
  local cx = camera_matrix[{1,3}]
  local cy = camera_matrix[{2,3}]

  -- TODO: retry without '-2' after good cmarea calibration with many images
  camera:setIntrinsics(fx, fy, cx, h - cy - 2, w, h)      -- (h - cy) inverts the vertical principal point center-offset
  local proj = camera:getProjectionMatrix()
  print("Projection matrix:")
  print(proj)

  camera:lookAt({0,0,0}, {0,0,1}, {0,-1,0}) -- look along z-axis
  --camera:lookAt({0,0,1}, {0,0,-1}, {0,1,0}) -- open-gl standard with y-axis pointing upwards (looking towards negative Z)

  scene:setCamera(camera)

  local fullScreenShader = xgl.Shader("../shaders/FullScreen.VertexShader.glsl", "../shaders/FullScreen.FragmentShader.glsl")
  local overlayQuad = scene:addQuad(2,2, fullScreenShader, 'undistorted_input.png', 1, true)
  
  local texShader = xgl.Shader("../shaders/Basic.VertexShader.glsl", "../shaders/Paper.FragmentShader.glsl")
  local quad = scene:addQuad(0.21, 0.297, texShader, '../textures/pattern.png', 0.6)
  
  local translate = torch.eye(4)
  translate[{1,4}] = (0.21 * 0.5) - 0.0680193
  translate[{2,4}] = (0.297 * 0.5) - 0.193723

  local R = torch.eye(4)    -- rotate 180 degree around x-axis to convert into to openCV camera coordinate system (-y up, view along positive z)
  R[{2,2}] = -1
  R[{3,3}] = -1

  quad:setPose(pose * R * translate)

  scene:setClearColor(0,0,0,1)
  scene:render()

  camera:swapBuffers()

  local t = camera:copyRenderResult()
  image.savePNG(output_filename, t:permute(3,1,2))

  print('press return to continue ...')
  io.read()

  xgl.terminate()
end

local pose = generatePose(target_rot, target_pos)
render(pose, camera_matrix, im_width, im_height, 'result.png')
