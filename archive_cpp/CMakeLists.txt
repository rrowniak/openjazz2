cmake_minimum_required(VERSION 2.8.11)

# Workspace name
project(OpenJazz)

# This setting is useful for providing JSON file used by CodeLite for code completion
set(CMAKE_EXPORT_COMPILE_COMMANDS 1)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++14 -Wno-deprecated-declarations -Wno-reorder")

# Set default locations
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

set(CONFIGURATION_NAME "Debug")

include_directories(./src)

# Projects
set(SRC 
    src/unixMain.cpp 
    src/main.cpp
    src/App.cpp
    src/CollisionEngine.cpp
    
    src/data/AnimationHelper.cpp
    src/data/Jazz2AnimFormat.cpp
    src/data/Jazz2LevelFormat.cpp
    src/data/Jazz2TileFormat.cpp
    src/data/JJ2LevelBuilder.cpp
    src/data/ResourceFactory.cpp
    
    src/game/events/BonusItem.cpp
    src/game/events/SpringEvent.cpp
    src/game/events/StandardEvent.cpp
    src/game/events/UnknownEvent.cpp
    
    src/game/physics/HeroPhysics.cpp
    src/game/physics/PhysicsCalcs.cpp
    
    src/game/Camera.cpp
    src/game/Event.cpp
    src/game/Game.cpp
    src/game/Hero.cpp
    src/game/Layer.cpp
    src/game/Level.cpp
    src/game/ResourceDbg.cpp
    src/game/Tile.cpp
    src/game/WorldTransformations.cpp
    
    src/gfx/Animation.cpp
    src/gfx/AnimationCalculator.cpp
    src/gfx/Color32.cpp
    src/gfx/GraphicsEngine.cpp
    src/gfx/Surface.cpp
    
    src/utils/GameConsoleWriter.cpp
    src/utils/SdlEventConsumer.cpp
    src/utils/Time.cpp
    src/utils/Utils.cpp
)

add_executable(OpenJazz ${SRC})
target_link_libraries(OpenJazz SDL2 SDL2_gfx SDL2main z)

# Top project
