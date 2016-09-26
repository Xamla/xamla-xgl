cmake_minimum_required(VERSION 2.8)

project(xgl)

find_package(Torch REQUIRED)
find_package(Boost 1.47.0 REQUIRED COMPONENTS program_options system)
find_package(PkgConfig REQUIRED)
pkg_search_module(GLFW3 REQUIRED glfw3) # sets GLFW3 as prefix for glfw vars
#find_package(OpenCV REQUIRED)

set(SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src")

include_directories(
  ${GLFW3_INCLUDE_DIR}
  #${OpenCV_INCLUDE_DIRS}
  ${Boost_INCLUDE_DIR}
)

set(src
  "${SOURCE_DIR}/xamla-gl.cpp"
)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
set(CMAKE_BUILD_TYPE Debug)

add_library(${PROJECT_NAME} MODULE ${src})
#add_executable(${PROJECT_NAME} ${src})
target_link_libraries(${PROJECT_NAME} TH GL GLU GLEW SOIL assimp ${GLFW3_STATIC_LIBRARIES} ${Boost_LIBRARIES}) # ${OpenCV_LIBS}

install(TARGETS ${PROJECT_NAME} LIBRARY DESTINATION ${Torch_INSTALL_LUA_CPATH_SUBDIR})
install(DIRECTORY "lua/" DESTINATION "${Torch_INSTALL_LUA_PATH_SUBDIR}/${PROJECT_NAME}" FILES_MATCHING PATTERN "*.lua")
