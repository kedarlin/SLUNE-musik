#pragma once

#include <cstdint>
#include <vector>

#include "SampleFormat.h"

class AudioBuffer
{
public:
    AudioBuffer() = default;
    AudioBuffer(
        void *data,
        int32_t frames,
        int32_t channels,
        float sampleRate,
        SampleFormat format)

        : data(data),
          frames(frames),
          channels(channels),
          sampleRate(sampleRate),
          format(format)
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

    float *floatData()
    {
        return static_cast<float *>(data);
    }

    const float *floatData() const
    {
        return static_cast<const float *>(data);
    }

    int16_t *int16Data()
    {
        return static_cast<int16_t *>(data);
    }

    const int16_t *int16Data() const
    {
        return static_cast<const int16_t *>(data);
    }

    void setData(
        void *ptr,
        int32_t frames,
        int32_t channels,
        float sampleRate,
        SampleFormat format)
    {
        data = ptr;
        this->frames = frames;
        this->channels = channels;
        this->sampleRate = sampleRate;
        this->format = format;
    }

public:
    void *data;

    int32_t frames;

    int32_t channels;

    float sampleRate;

    SampleFormat format;
};