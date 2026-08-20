#include "PlaybackController.h"

#include "../common/AudioConverter.h"
#include "../common/Logger.h"

PlaybackController::PlaybackController(
    MediaCodecDecoder &decoder,
    PlaybackState &playbackState)
    : decoder_(&decoder),
      playbackState_(playbackState)
{
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
    if (fifo_.availableFrames() < kLowWaterMarkFrames)
    {
        worker_.requestFill();
    }

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

    playbackState_.addRenderedFrames(framesRead);

    return ProcessResult::Continue;
}

void PlaybackController::clear()
{
    fifo_.clear();

    playbackBuffer_.clear();
    playbackBuffer_.resize(kDefaultCallbackFrames * 2);

    decodedBuffer_ = AudioBuffer();
}

ProcessResult PlaybackController::seek(int64_t positionUs)
{
    if (!decoder_)
    {
        return ProcessResult::Error;
    }

    std::lock_guard<std::mutex> lock(decoderMutex_);

    const ProcessResult result = decoder_->seek(positionUs);

    if (result != ProcessResult::Continue)
    {
        return result;
    }

    fifo_.clear();

    worker_.requestFill();

    return ProcessResult::Continue;
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

    std::lock_guard<std::mutex> lock(decoderMutex_);

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
    return fifo_.availableFrames() < kHighWaterMarkFrames;
}