#include "AudioFifo.h"

AudioFifo::AudioFifo(
    size_t capacityFrames,
    int32_t channels)
    : channels_(channels),
      capacityFrames_(capacityFrames),
      readFrame_(0),
      writeFrame_(0),
      availableFrames_(0)
{
    buffer_.resize(capacityFrames_ * channels_);
}

size_t AudioFifo::freeFrames() const
{
    return capacityFrames_ - availableFrames_;
}

void AudioFifo::clear()
{
    readFrame_ = 0;
    writeFrame_ = 0;
    availableFrames_ = 0;
}

size_t AudioFifo::push(
    const int16_t *input,
    size_t frames)
{
    size_t written = 0;

    while (written < frames &&
           availableFrames_ < capacityFrames_)
    {
        for (int ch = 0; ch < channels_; ch++)
        {
            buffer_[writeFrame_ * channels_ + ch] =
                input[written * channels_ + ch];
        }

        writeFrame_ =
            (writeFrame_ + 1) % capacityFrames_;

        availableFrames_++;
        written++;
    }

    return written;
}

size_t AudioFifo::pop(
    int16_t *output,
    size_t frames)
{
    size_t read = 0;

    while (read < frames &&
           availableFrames_ > 0)
    {
        for (int ch = 0; ch < channels_; ch++)
        {
            output[read * channels_ + ch] =
                buffer_[readFrame_ * channels_ + ch];
        }

        readFrame_ =
            (readFrame_ + 1) % capacityFrames_;

        availableFrames_--;
        read++;
    }

    return read;
}

size_t AudioFifo::availableFrames() const
{
    return availableFrames_;
}