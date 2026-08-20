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

void PlaybackController::configureStretch(
    int sampleRate,
    int channels)
{
    stretcher_.setSampleRate(static_cast<uint>(sampleRate));
    stretcher_.setChannels(static_cast<uint>(channels));

    stretchConfigured_ = true;
}

void PlaybackController::setStretchTempo(float tempo)
{
    stretcher_.setTempo(tempo);
}

void PlaybackController::setStretchPitch(float pitch)
{
    stretcher_.setPitch(pitch);
}

ProcessResult PlaybackController::render(
    AudioBuffer &outputBuffer)
{
    const size_t neededFrames =
        static_cast<size_t>(outputBuffer.frames);

    if (!stretchConfigured_)
    {
        std::fill(
            outputBuffer.floatData(),
            outputBuffer.floatData() + outputBuffer.sampleCount(),
            0.0f);

        return ProcessResult::Continue;
    }

    size_t receivedFrames =
        stretcher_.receiveSamples(
            outputBuffer.floatData(),
            static_cast<uint>(neededFrames));

    size_t consumedFifoFrames = 0;

    while (receivedFrames < neededFrames)
    {
        if (playbackBuffer_.size() !=
            static_cast<size_t>(outputBuffer.sampleCount()))
        {
            playbackBuffer_.resize(
                outputBuffer.sampleCount());
        }

        const size_t pulledFrames =
            fifo_.pop(
                playbackBuffer_.data(),
                neededFrames);

        if (pulledFrames == 0)
        {
            break;
        }

        consumedFifoFrames += pulledFrames;

        if (stretchInputBuffer_.size() != playbackBuffer_.size())
        {
            stretchInputBuffer_.resize(playbackBuffer_.size());
        }

        AudioConverter::int16ToFloat(
            playbackBuffer_.data(),
            stretchInputBuffer_.data(),
            pulledFrames * outputBuffer.channels);

        stretcher_.putSamples(
            stretchInputBuffer_.data(),
            static_cast<uint>(pulledFrames));

        receivedFrames +=
            stretcher_.receiveSamples(
                outputBuffer.floatData() +
                    receivedFrames * outputBuffer.channels,
                static_cast<uint>(neededFrames - receivedFrames));
    }

    if (fifo_.availableFrames() < kLowWaterMarkFrames)
    {
        worker_.requestFill();
    }

    if (receivedFrames < neededFrames)
    {
        std::fill(
            outputBuffer.floatData() +
                receivedFrames * outputBuffer.channels,
            outputBuffer.floatData() +
                outputBuffer.sampleCount(),
            0.0f);
    }

    playbackState_.addRenderedFrames(consumedFifoFrames);

    return ProcessResult::Continue;
}

void PlaybackController::clear()
{
    fifo_.clear();

    playbackBuffer_.clear();
    playbackBuffer_.resize(kDefaultCallbackFrames * 2);

    decodedBuffer_ = AudioBuffer();

    stretcher_.clear();
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