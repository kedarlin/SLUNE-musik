#include "SineGeneratorNode.h"

#include <cmath>

namespace
{
    constexpr float kFrequency = 880.0f;
    constexpr float kAmplitude = 0.25f;
    constexpr float kPi = 3.14159265358979323846f;
}

void SineGeneratorNode::process(
    float *buffer,
    int32_t numFrames,
    int32_t channelCount,
    float sampleRate)
{
    const float incremenet = 2.0f * kPi * kFrequency / sampleRate;

    for (int32_t frame = 0; frame < numFrames; frame++)
    {
        float sample = std::sin(phase_ * kAmplitude);

        phase_ += incremenet;

        if (phase_ > 2.0f * kPi)
        {
            phase_ -= 2.0f * kPi;
        }

        for (int ch = 0; ch < channelCount; ch++)
        {
            *buffer++ = sample;
        }
    }
}