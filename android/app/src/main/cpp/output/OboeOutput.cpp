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

    LOGI("Oboe Sample Rate : %d", stream_->getSampleRate());
    LOGI("Oboe Channel Count : %d", stream_->getChannelCount());
    LOGI("Oboe Format : %d", static_cast<int>(stream_->getFormat()));
    LOGI("Oboe Frames Per Callback : %d", stream_->getFramesPerDataCallback());
    LOGI(
        "Oboe format enum = %d",
        static_cast<int>(stream_->getFormat()));

    result = stream_->requestStart();

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
        stream_->requestStop();
        stream_->close();
        stream_.reset();

        LOGI("Oboe stream closed.");
    }
}