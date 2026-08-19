#pragma once

#include <cstdint>

struct PlaybackMetadata
{
    int sampleRate = 0;
    int channels = 0;
    int bitRate = 0;
    int64_t durationUs = 0;

    bool isValid() const
    {
        return sampleRate > 0 &&
               channels > 0 &&
               durationUs > 0;
    }

    double durationSeconds() const
    {
        return static_cast<double>(durationUs) / 1'000'000.0;
    }
};