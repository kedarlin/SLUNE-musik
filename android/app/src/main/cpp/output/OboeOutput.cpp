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
    // PerformanceMode::LowLatency was measured capping this device's buffer
    // capacity at 512 frames (2 bursts) regardless of SharingMode (tried
    // both Exclusive and Shared - same ceiling either way), which was not
    // enough headroom against scheduling jitter to avoid audible dropouts.
    // LowLatency exists for apps where the user triggers sounds and needs
    // near-instant feedback (games, DAWs) - a passive music player has no
    // such requirement, so there is nothing to trade it away for here.
    // PerformanceMode::None uses AudioFlinger's regular mixer path, which
    // allows a much larger buffer at the cost of some extra output latency
    // that is imperceptible for playback that isn't interactively triggered.
    builder.setPerformanceMode(oboe::PerformanceMode::None);
    builder.setSharingMode(oboe::SharingMode::Shared);
    builder.setFormat(oboe::AudioFormat::Float);
    builder.setSampleRate(44100);

    callback_ = std::make_unique<AudioCallback>(context, pipeline);

    builder.setDataCallback(callback_.get());

    auto result = builder.openStream(stream_);

    if (result != oboe::Result::OK || !stream_)
    {
        LOGE("Failed to open Oboe stream.");
        return false;
    }

    // Default post-open buffer size leaves no slack against scheduling
    // jitter, which is a common source of intermittent click/glitch. Oboe's
    // documented guidance is to size the buffer to a multiple of the burst
    // size once the stream is open. This is a handful of KB (frames * 4
    // channels * 4 bytes), not a memory-pressure concern - the real cost of
    // going higher is added output latency, not RAM.
    const int32_t framesPerBurst = stream_->getFramesPerBurst();
    const int32_t bufferCapacity = stream_->getBufferCapacityInFrames();

    if (framesPerBurst > 0)
    {
        int32_t requestedFrames = framesPerBurst * kBufferSizeBursts;

        if (bufferCapacity > 0 && requestedFrames > bufferCapacity)
        {
            requestedFrames = bufferCapacity;
        }

        stream_->setBufferSizeInFrames(requestedFrames);
    }

    LOGI(
        "Oboe buffer: burst=%d capacity=%d requested=%d actual=%d "
        "sharingMode=%d performanceMode=%d",
        framesPerBurst,
        bufferCapacity,
        framesPerBurst * kBufferSizeBursts,
        stream_->getBufferSizeInFrames(),
        static_cast<int>(stream_->getSharingMode()),
        static_cast<int>(stream_->getPerformanceMode()));

    result = stream_->requestStart();

    if (result != oboe::Result::OK)
    {
        LOGE("Failed to start Oboe stream.");
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