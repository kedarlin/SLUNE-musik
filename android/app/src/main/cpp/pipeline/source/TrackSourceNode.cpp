#include "TrackSourceNode.h"

#include "../../common/Logger.h"
#include "../../common/AudioConverter.h"

namespace
{
    constexpr size_t kLowWaterMarkFrames = 1024;
}

TrackSourceNode::TrackSourceNode(
    IDecoder &decoder) : decoder_(decoder)
{
    playbackBuffer_.resize(256 * 2);
}

ProcessResult TrackSourceNode::process(
    AudioBuffer &outputBuffer)
{
    static bool logged = false;

    if (!logged)
    {
        LOGI("TrackSourceNode processing.");
        logged = true;
    }

    if (fifo_.availableFrames() < kLowWaterMarkFrames)
    {
        auto result =
            decoder_.decode(decodedBuffer_);

        if (result == ProcessResult::Continue)
        {
            fifo_.push(
                decodedBuffer_.int16Data(),
                decodedBuffer_.frames);
        }
    }

    LOGI(
        "FIFO contains %zu frames",
        fifo_.availableFrames());

    size_t framesRead = fifo_.pop(
        playbackBuffer_.data(),
        outputBuffer.frames);

    LOGI(
        "Frames requested : %d",
        outputBuffer.frames);

    LOGI(
        "Frames read : %zu",
        framesRead);

    LOGI(
        "FIFO remaining : %zu",
        fifo_.availableFrames());

    if (framesRead < static_cast<size_t>(outputBuffer.frames))
    {
        float *out = outputBuffer.floatData();

        std::fill(
            out + framesRead * outputBuffer.channels,
            out + outputBuffer.sampleCount(),
            0.0f);
    }

    LOGI(
        "FIFO read %zu frames, remaining %zu",
        framesRead,
        fifo_.availableFrames());

    AudioConverter::int16ToFloat(
        playbackBuffer_.data(),
        outputBuffer.floatData(),
        framesRead * outputBuffer.channels);

    float *samples =
        outputBuffer.floatData();

    return ProcessResult::Continue;
}