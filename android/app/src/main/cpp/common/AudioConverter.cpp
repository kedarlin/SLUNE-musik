#include "AudioConverter.h"

void AudioConverter::int16ToFloat(
    const int16_t *input,
    float *output,
    size_t sampleCount)
{
    constexpr float scale = 1.0f / 32768.0f;

    for (size_t i = 0; i < sampleCount; ++i)
    {
        output[i] = static_cast<float>(input[i] * scale);
    }
}