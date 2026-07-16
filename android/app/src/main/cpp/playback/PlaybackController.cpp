#include "PlaybackController.h"

#include "../common/AudioConverter.h"
#include "../common/Logger.h"

PlaybackController::PlaybackController()
{
    playbackBuffer_.resize(256 * 2);
}

bool PlaybackController::initialize(
    IDecoder &decoder)
{
    decoder_ = &decoder;

    return true;
}

ProcessResult PlaybackController::render(
    AudioBuffer &outputBuffer)
{
    if (playbackBuffer_.size() !=
        static_cast<size_t>(outputBuffer.sampleCount()))
    {
        playbackBuffer_.resize(
            outputBuffer.sampleCount());
    }

    const size_t framesRead =
        fifo_.pop(
            playbackBuffer_.data(),
            outputBuffer.frames);

    AudioConverter::int16ToFloat(
        playbackBuffer_.data(),
        outputBuffer.floatData(),
        framesRead * outputBuffer.channels);

    if (framesRead <
        static_cast<size_t>(outputBuffer.frames))
    {
        std::fill(
            outputBuffer.floatData() +
                framesRead * outputBuffer.channels,
            outputBuffer.floatData() +
                outputBuffer.sampleCount(),
            0.0f);
    }

    return ProcessResult::Continue;
}

void PlaybackController::clear()
{
    fifo_.clear();

    playbackBuffer_.clear();
    playbackBuffer_.resize(kDefaultCallbackFrames * 2);

    decodedBuffer_ = AudioBuffer();
}

bool PlaybackController::start()
{
    return worker_.start(*this);
}

void PlaybackController::stop()
{
    worker_.stop();
}

void PlaybackController::fillFifo()
{
    if (!decoder_)
    {
        return;
    }

    LOGI("PlaybackWorker filling FIFO...");

    while (needsMoreData())
    {
        auto result = decoder_->decode(decodedBuffer_);

        if (result != ProcessResult::Continue)
        {
            break;
        }

        const size_t written =
            fifo_.push(
                decodedBuffer_.int16Data(),
                decodedBuffer_.frames);

        if (written !=
            static_cast<size_t>(decodedBuffer_.frames))
        {
            LOGW(
                "FIFO full. Wrote %zu of %d frames.",
                written,
                decodedBuffer_.frames);

            break;
        }
    }
}

bool PlaybackController::isRunning() const
{
    return decoder_ != nullptr;
}

bool PlaybackController::needsMoreData() const
{
    return fifo_.availableFrames() < kLowWaterMarkFrames;
}