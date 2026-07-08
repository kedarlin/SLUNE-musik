#pragma once

#include "../../datasource/IDataSource.h"

#include <media/NdkMediaExtractor.h>
#include <media/NdkMediaFormat.h>

class MediaCodecSession
{
public:
    MediaCodecSession() = default;
    ~MediaCodecSession() = default;

    IDataSource *source = nullptr;

    AMediaExtractor *extractor = nullptr;

    AMediaFormat *format = nullptr;

    int32_t trackIndex = -1;

    int32_t sampleRate = 0;

    int32_t channelCount = 0;

    int64_t durationUs = 0;
};