#pragma once

#include <media/NdkMediaCodec.h>
#include <media/NdkMediaExtractor.h>
#include <media/NdkMediaFormat.h>

struct ExtractorState
{
    AMediaExtractor *extractor = nullptr;
    AMediaFormat *format = nullptr;
    int32_t trackIndex = -1;
    int32_t sampleRate = 0;
    int32_t channelCount = 0;
    int32_t bitRate = 0;
    int64_t durationUs = 0;
};