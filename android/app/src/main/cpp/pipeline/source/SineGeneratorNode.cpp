#include "SineGeneratorNode.h"

#include <cmath>

namespace
{
    constexpr float kFrequency = 880.0f;
    constexpr float kAmplitude = 0.25f;
    constexpr float kPi = 3.14159265358979323846f;
}

ProcessResult SineGeneratorNode::process(
    AudioBuffer &buffer)
{
    const float increment = 2.0f * kPi * kFrequency / buffer.sampleRate;

    float *samples =
        static_cast<float *>(buffer.data);

    for (int32_t frame = 0; frame < buffer.frames; frame++)
    {
        float sample =
            std::sin(phase_) * kAmplitude;

        phase_ += increment;

        if (phase_ > 2.0f * kPi)
        {
            phase_ -= 2.0f * kPi;
        }

        for (int32_t ch = 0; ch < buffer.channels; ch++)
        {
            samples[frame * buffer.channels + ch] = sample;
        }
    }

    return ProcessResult::Continue;
}