cmake_minimum_required(VERSION 3.22.1)

project(SoundTouch VERSION 2.4.1 LANGUAGES CXX)

add_library(
    SoundTouch
    STATIC

    source/SoundTouch/AAFilter.cpp
    source/SoundTouch/BPMDetect.cpp
    source/SoundTouch/cpu_detect_x86.cpp
    source/SoundTouch/FIFOSampleBuffer.cpp
    source/SoundTouch/FIRFilter.cpp
    source/SoundTouch/InterpolateCubic.cpp
    source/SoundTouch/InterpolateLinear.cpp
    source/SoundTouch/InterpolateShannon.cpp
    source/SoundTouch/mmx_optimized.cpp
    source/SoundTouch/PeakFinder.cpp
    source/SoundTouch/RateTransposer.cpp
    source/SoundTouch/SoundTouch.cpp
    source/SoundTouch/sse_optimized.cpp
    source/SoundTouch/TDStretch.cpp
)

target_include_directories(
    SoundTouch
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_definitions(
    SoundTouch
    PRIVATE
    SOUNDTOUCH_FLOAT_SAMPLES=1
)

target_compile_options(
    SoundTouch
    PRIVATE
    -O3
    -ffast-math
)

if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(armv7.*|armv8.*|aarch64.*)$")
    target_compile_definitions(SoundTouch PRIVATE SOUNDTOUCH_USE_NEON)
    if(NOT CMAKE_SYSTEM_PROCESSOR MATCHES "^aarch64.*$")
        target_compile_options(SoundTouch PRIVATE -mfpu=neon)
    endif()
endif()
