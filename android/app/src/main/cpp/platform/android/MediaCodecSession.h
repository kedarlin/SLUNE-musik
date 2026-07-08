#pragma once

#include "../../datasource/IDataSource.h"
#include "CodecState.h"
#include "ExtractorState.h"

#include <media/NdkMediaExtractor.h>
#include <media/NdkMediaFormat.h>

class MediaCodecSession
{
public:
    MediaCodecSession() = default;
    ~MediaCodecSession() = default;

    IDataSource *source = nullptr;

    ExtractorState extractor;

    CodecState codec;
};