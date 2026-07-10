#pragma once

#include <cstddef>
#include <cstdint>

class AudioConverter
{
public:
    static void int16ToFloat(
        const int16_t *input,
        float *output,
        size_t sampleCount);
};