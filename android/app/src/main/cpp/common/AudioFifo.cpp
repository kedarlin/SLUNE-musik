#include "AudioFifo.h"

AudioFifo::AudioFifo(
    size_t capacityFrames,
    int32_t channels)
    : channels_(channels),
      capacityFrames_(capacityFrames),
      readCount_(0),
      writeCount_(0)
{
    buffer_.resize(capacityFrames_ * channels_);
}

size_t AudioFifo::freeFrames() const
{
    return capacityFrames_ - availableFrames();
}

void AudioFifo::clear()
{
    writeCount_.store(
        readCount_.load(std::memory_order_acquire),
        std::memory_order_release);
}

size_t AudioFifo::push(
    const int16_t *input,
    size_t frames)
{
    size_t writeCount = writeCount_.load(std::memory_order_relaxed);
    const size_t readCount = readCount_.load(std::memory_order_acquire);

    size_t written = 0;

    while (written < frames &&
           (writeCount - readCount) < capacityFrames_)
    {
        const size_t index = writeCount % capacityFrames_;

        for (int ch = 0; ch < channels_; ch++)
        {
            buffer_[index * channels_ + ch] =
                input[written * channels_ + ch];
        }

        writeCount++;
        written++;
    }

    writeCount_.store(writeCount, std::memory_order_release);

    return written;
}

size_t AudioFifo::pop(
    int16_t *output,
    size_t frames)
{
    size_t readCount = readCount_.load(std::memory_order_relaxed);
    const size_t writeCount = writeCount_.load(std::memory_order_acquire);

    size_t read = 0;

    while (read < frames &&
           (writeCount - readCount) > 0)
    {
        const size_t index = readCount % capacityFrames_;

        for (int ch = 0; ch < channels_; ch++)
        {
            output[read * channels_ + ch] =
                buffer_[index * channels_ + ch];
        }

        readCount++;
        read++;
    }

    readCount_.store(readCount, std::memory_order_release);

    return read;
}

size_t AudioFifo::availableFrames() const
{
    const size_t writeCount = writeCount_.load(std::memory_order_acquire);
    const size_t readCount = readCount_.load(std::memory_order_acquire);

    return writeCount - readCount;
}
