#pragma once

#include <cmath>

class AudioNode
{
public:
    virtual ~AudioNode() = default;

    virtual void process(
        float *buffer,
        int32_t numFrames,
        int32_t channelCount,
        float sampleRate) = 0;
};