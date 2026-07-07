#include "OboeOutput.h"

#include "./common/Logger.h"

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

    if (result != oboe::Result::OK)
    {
        LOGE("Failed to open Oboe stream.");
        return false;
    }

    LOGI("Oboe stream opened.");
    return true;
}

void OboeOutput::shutdown()
{
    if (stream_)
    {
        stream_->close();
        stream_.reset();

        LOGI("Oboe stream closed.");
    }
}