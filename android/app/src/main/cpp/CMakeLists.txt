cmake_minimum_required(VERSION 3.22.1)

project(muxic_engine)

# -----------------------------------------------------------------------------
# Oboe
# -----------------------------------------------------------------------------

set(OBOE_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(OBOE_BUILD_TESTS OFF CACHE BOOL "" FORCE)

add_subdirectory(third_party/oboe)

# -----------------------------------------------------------------------------
# SoundTouch
# -----------------------------------------------------------------------------

add_subdirectory(third_party/soundtouch)

# -----------------------------------------------------------------------------
# Muxic Engine
# -----------------------------------------------------------------------------

add_library(
    muxic_engine
    SHARED

    api/engine_api.cpp

    engine/AudioEngine.cpp
    engine/PlaybackWorker.cpp
    engine/playback/PlaybackClock.cpp

    modules/decoder/DecoderModule.cpp
    modules/output/OutputModule.cpp
    modules/dsp/DSPModule.cpp

    output/OboeOutput.cpp
    output/AudioCallback.cpp

    pipeline/AudioPipeline.cpp
    pipeline/source/SineGeneratorNode.cpp
    pipeline/source/TrackSourceNode.cpp

    datasource/FileDataSource.cpp
    datasource/ContentDataSource.cpp

    platform/android/JniBridge.cpp
    platform/android/AndroidContext.cpp
    platform/android/AndroidBindings.cpp
    platform/android/MediaCodecAdapter.cpp
    platform/android/AndroidContentResolver.cpp
    platform/android/JniUtils.cpp

    decoder/MediaCodecDecoder.cpp
    decoder/controller/ExtractorController.cpp
    decoder/controller/CodecController.cpp

    playback/PlaybackController.cpp

    common/AudioConverter.cpp
    common/AudioFifo.cpp
)

target_include_directories(
    muxic_engine
    PRIVATE

    ${CMAKE_CURRENT_SOURCE_DIR}
)

find_library(log-lib log)

find_library(android-lib android)

find_library(media-ndk-lib mediandk)

target_link_libraries(
    muxic_engine

    oboe
    SoundTouch

    ${log-lib}
    ${android-lib}
    ${media-ndk-lib}
)