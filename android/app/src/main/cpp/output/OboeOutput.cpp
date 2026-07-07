#include "OboeOutput.h"

#include <android/log.h>

#define TAG "MuxicEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)

OboeOutput::OboeOutput() = default;

OboeOutput::~OboeOutput()
{
    shutdown();
}

bool OboeOutput::initialize()
{
    oboe::AudioStreamBuilder builder;

    builder.setDirection(oboe::Direction::Output);
    builder.setPerformanceMode(oboe::PerformanceMode::LowLatency);
    builder.setSharingMode(oboe::SharingMode::Exclusive);
    builder.setFormat(oboe::AudioFormat::Float);

    auto result = builder.openStream(stream_);

    if(result != oboe::Result::OK)
    {
        LOGI("Failed to open Oboe stream.");
        return false;
    }

    LOGI("Oboe stream opened.");
    return true;
}

void OboeOutput::shutdown()
{
    if(stream_)
    {
        stream_->close();
        stream_.reset();

        LOGI("Oboe stream closed.");
    }
}