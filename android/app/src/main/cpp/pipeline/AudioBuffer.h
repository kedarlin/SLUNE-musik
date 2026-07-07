#pragma once

#include <cstdint>

class AudioBuffer
{
public:
    AudioBuffer(
        float *samples,
        int32_t frames,
        int32_t channels,
        float sampleRate)
        : samples(samples),
          frames(frames),
          channels(channels),
          sampleRate(sampleRate)
    {
    }

    int32_t sampleCount() const
    {
        return frames * channels;
    }

    int32_t frameSize() const
    {
        return channels;
    }

public:
    float *samples;

    int32_t frames;

    int32_t channels;

    float sampleRate;
};