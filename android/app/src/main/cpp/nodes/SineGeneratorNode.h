#pragma once

#include "../pipeline/AudioNode.h"

#include <cmath>

class SineGeneratorNode : public AudioNode
{
public:
    void process(
        float *buffer,
        int32_t numFrames,
        int32_t channelCount,
        float sampleRate) override;

private:
    float phase_ = 0.0f;
};