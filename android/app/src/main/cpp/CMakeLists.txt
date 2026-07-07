cmake_minimum_required(VERSION 3.22.1)

project(muxic_engine)

# -----------------------------------------------------------------------------
# Oboe
# -----------------------------------------------------------------------------

set(OBOE_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(OBOE_BUILD_TESTS OFF CACHE BOOL "" FORCE)

add_subdirectory(third_party/oboe)

# -----------------------------------------------------------------------------
# Muxic Engine
# -----------------------------------------------------------------------------

add_library(
    muxic_engine
    SHARED

    api/engine_api.cpp

    engine/AudioEngine.cpp

    modules/decoder/DecoderModule.cpp
    modules/output/OutputModule.cpp
    modules/dsp/DSPModule.cpp

    output/OboeOutput.cpp
    output/AudioCallback.cpp
    pipeline/AudioPipeline.cpp
    pipeline/source/SineGeneratorNode.cpp
)

target_include_directories(
    muxic_engine
    PRIVATE

    ${CMAKE_CURRENT_SOURCE_DIR}
)

find_library(log-lib log)

find_library(android-lib android)

target_link_libraries(
    muxic_engine

    oboe

    ${log-lib}
    ${android-lib}
)