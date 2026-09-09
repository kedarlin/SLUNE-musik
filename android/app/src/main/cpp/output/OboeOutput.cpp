#include "OboeOutput.h"

#include "./common/Logger.h"

OboeOutput::OboeOutput() = default;

OboeOutput::~OboeOutput()
{
    shutdown();
}

bool OboeOutput::initialize(EngineContext &context, AudioPipeline &pipeline)
{
    oboe::AudioStreamBuilder builder;

    builder.setDirection(oboe::Direction::Output);
    builder.setPerformanceMode(oboe::PerformanceMode::LowLatency);
    builder.setSharingMode(oboe::SharingMode::Exclusive);
    builder.setFormat(oboe::AudioFormat::Float);
    builder.setSampleRate(44100);

    callback_ = std::make_unique<AudioCallback>(context, pipeline);

    builder.setDataCallback(callback_.get());

    auto result = builder.openStream(stream_);


    result = stream_->requestStart();

    if (result != oboe::Result::OK)
    {
        LOGE("Failed to open Oboe stream.");
        return false;
    }

    return true;
}

void OboeOutput::shutdown()
{
    if (stream_)
    {
        stream_->requestStop();
        stream_->close();
        stream_.reset();

    }
}